part of 'realtime_transcription_service.dart';

/// Text-delta merging and audio capture/persistence helpers for
/// [RealtimeTranscriptionService]: confirmed-delta diffing, PCM buffering,
/// WAV writing and cleanup. Split from the main file for size; all private.
extension RealtimeTranscriptionTextAudio on RealtimeTranscriptionService {
  String _confirmedTextDelta({
    required String previous,
    required String next,
  }) {
    if (previous.isEmpty || next.startsWith(previous)) {
      return next.substring(previous.length);
    }
    if (previous.startsWith(next)) {
      return '';
    }

    final overlapLength = _suffixPrefixOverlapLength(previous, next);
    if (overlapLength > 0) {
      return next.substring(overlapLength);
    }

    return next.substring(_commonPrefixLength(previous, next));
  }

  int _suffixPrefixOverlapLength(String previous, String next) {
    final maxLength = previous.length < next.length
        ? previous.length
        : next.length;
    for (var length = maxLength; length > 0; length--) {
      if (previous.endsWith(next.substring(0, length))) {
        return length;
      }
    }
    return 0;
  }

  int _commonPrefixLength(String a, String b) {
    final maxLength = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < maxLength; i++) {
      if (a.codeUnitAt(i) != b.codeUnitAt(i)) {
        return i;
      }
    }
    return maxLength;
  }

  void _bufferPcmAndAmplitude(Uint8List chunk) {
    final newTotal = _pcmBuffer.length + chunk.length;
    if (newTotal > _maxPcmBufferBytes) {
      final existing = _pcmBuffer.takeBytes();
      if (chunk.length >= _maxPcmBufferBytes) {
        _pcmBuffer.add(
          chunk.sublist(chunk.length - _maxPcmBufferBytes),
        );
      } else {
        final excess = newTotal - _maxPcmBufferBytes;
        final kept = existing.length - excess;
        final merged = Uint8List(kept + chunk.length)
          ..setRange(0, kept, existing, excess)
          ..setRange(kept, kept + chunk.length, chunk);
        _pcmBuffer.add(merged);
      }
    } else {
      _pcmBuffer.add(chunk);
    }

    if (!_amplitudeController.isClosed) {
      final dbfs = computeDbfsFromPcm16(chunk);
      _amplitudeController.add(dbfs);
    }
  }

  Future<String?> _saveAudio(String outputPath) async {
    if (_pcmBuffer.length == 0) return null;

    final tempWavPath =
        '${Directory.systemTemp.path}/lotti_rt_'
        '${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      await _writeTempWav(tempWavPath);

      // Attempt M4A conversion
      final m4aPath = outputPath.endsWith('.m4a')
          ? outputPath
          : '$outputPath.m4a';

      final converted = await AudioConverterChannel.convertWavToM4a(
        inputPath: tempWavPath,
        outputPath: m4aPath,
      );

      if (converted) {
        // Delete temp WAV on successful conversion
        try {
          await File(tempWavPath).delete();
        } catch (_) {}
        return m4aPath;
      } else {
        // Move WAV to final location as fallback
        final wavOutputPath = outputPath.endsWith('.wav')
            ? outputPath
            : '$outputPath.wav';
        await File(tempWavPath).rename(wavOutputPath);
        return wavOutputPath;
      }
    } catch (e) {
      getIt<DomainLogger>().error(
        LogDomain.speech,
        e,
        subDomain: 'saveAudio',
      );
      // Try to keep the WAV if it exists
      if (File(tempWavPath).existsSync()) {
        return tempWavPath;
      }
      return null;
    }
  }

  Future<void> _writeTempWav(String path) async {
    final pcmData = _pcmBuffer.toBytes();
    final dataSize = pcmData.length;

    // WAV header: 44 bytes
    // PCM 16-bit signed LE, 16kHz, mono
    const sampleRate = 16000;
    const channels = 1;
    const bitsPerSample = 16;
    const byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    const blockAlign = channels * bitsPerSample ~/ 8;

    final header = ByteData(44)
      // RIFF header
      ..setUint32(0, 0x52494646) // 'RIFF'
      ..setUint32(4, 36 + dataSize, Endian.little) // file size - 8
      ..setUint32(8, 0x57415645) // 'WAVE'
      // fmt chunk
      ..setUint32(12, 0x666D7420) // 'fmt '
      ..setUint32(16, 16, Endian.little) // chunk size
      ..setUint16(20, 1, Endian.little) // PCM format
      ..setUint16(22, channels, Endian.little)
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(28, byteRate, Endian.little)
      ..setUint16(32, blockAlign, Endian.little)
      ..setUint16(34, bitsPerSample, Endian.little)
      // data chunk
      ..setUint32(36, 0x64617461) // 'data'
      ..setUint32(40, dataSize, Endian.little);

    final file = File(path);
    final sink = file.openWrite()
      ..add(header.buffer.asUint8List())
      ..add(pcmData);
    await sink.flush();
    await sink.close();
  }

  Future<void> _cleanup() async {
    _isActive = false;
    await _deltaSubscription?.cancel();
    _deltaSubscription = null;
    await _languageSubscription?.cancel();
    _languageSubscription = null;
    await _mlxEventSubscription?.cancel();
    _mlxEventSubscription = null;
    _mlxDoneCompleter = null;
    _lastMlxConfirmedText = '';
    _detectedLanguage = null;
    _deltaBuffer.clear();
    if (_activeBackend == _RealtimeBackendKind.mlxAudio) {
      await _mlxAudioChannel.cancelRealtimeTranscription();
    } else {
      await _repository.disconnect();
    }
    _activeBackend = null;
  }
}
