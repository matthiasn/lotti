import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/realtime_transcription_event.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/mistral_realtime_transcription_repository.dart';
import 'package:lotti/features/ai/util/audio_converter_channel.dart';
import 'package:lotti/features/ai/util/pcm_amplitude.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

/// Orchestrates real-time transcription: connects WebSocket, streams PCM
/// audio, accumulates audio for WAV/M4A file output, and computes amplitude.
///
/// This service bypasses `CloudInferenceRepository` entirely — real-time
/// WebSocket streaming is a different paradigm from the HTTP batch flow.
class RealtimeTranscriptionService {
  RealtimeTranscriptionService(
    this._ref, {
    MistralRealtimeTranscriptionRepository? repository,
  }) : _repository = repository ?? MistralRealtimeTranscriptionRepository();

  final Ref _ref;
  final MistralRealtimeTranscriptionRepository _repository;
  final _pcmBuffer = BytesBuilder(copy: false);
  final _amplitudeController = StreamController<double>.broadcast();
  final _deltaBuffer = StringBuffer();

  /// Maximum PCM buffer size: ~2 minutes at 16kHz × 16-bit × mono = ~3.84 MB.
  /// Beyond this, older audio is discarded (transcription still works via
  /// WebSocket streaming — the buffer is only for the saved audio file).
  static const _maxPcmBufferBytes = 3840000;

  StreamSubscription<Uint8List>? _pcmSubscription;
  StreamSubscription<String>? _deltaSubscription;
  bool _isActive = false;

  /// Stream of amplitude values (dBFS) computed from PCM chunks.
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  /// Whether a real-time transcription session is active.
  bool get isActive => _isActive;

  /// Resolves a Mistral provider with a configured real-time model.
  ///
  /// Returns the first matching model/provider pair found (iteration order
  /// is not guaranteed). Returns `null` if no real-time model is configured.
  Future<({AiConfigInferenceProvider provider, AiConfigModel model})?>
      resolveRealtimeConfig() async {
    final aiRepo = _ref.read(aiConfigRepositoryProvider);
    final modelsFuture = aiRepo.getConfigsByType(AiConfigType.model);
    final providersFuture =
        aiRepo.getConfigsByType(AiConfigType.inferenceProvider);
    final models = await modelsFuture;
    final providers = await providersFuture;

    final allProviders = providers.whereType<AiConfigInferenceProvider>();

    for (final model in models.whereType<AiConfigModel>()) {
      if (!model.inputModalities.contains(Modality.audio)) continue;
      if (!MistralRealtimeTranscriptionRepository.isRealtimeModel(
        model.providerModelId,
      )) {
        continue;
      }

      final provider = allProviders
          .where(
            (p) =>
                p.id == model.inferenceProviderId &&
                p.inferenceProviderType == InferenceProviderType.mistral,
          )
          .firstOrNull;

      if (provider != null) {
        return (provider: provider, model: model);
      }
    }
    return null;
  }

  /// Starts a real-time transcription session.
  ///
  /// Connects to the Mistral WebSocket and subscribes to the [pcmStream].
  /// [onDelta] is called for each text delta received from the server.
  /// Also subscribe to [amplitudeStream] for dBFS values.
  Future<void> startRealtimeTranscription({
    required Stream<Uint8List> pcmStream,
    required void Function(String delta) onDelta,
  }) async {
    final config = await resolveRealtimeConfig();
    if (config == null) {
      throw StateError('No Mistral realtime transcription model configured');
    }

    await _repository.connect(
      apiKey: config.provider.apiKey,
      baseUrl: config.provider.baseUrl,
      model: config.model.providerModelId,
    );

    _isActive = true;
    _pcmBuffer.clear();
    _deltaBuffer.clear();

    // Subscribe to PCM stream: send to WebSocket + accumulate + compute dBFS
    _pcmSubscription = pcmStream.listen(
      (chunk) {
        _repository.sendAudioChunk(chunk);

        // Cap buffer to prevent OOM on long recordings. The WebSocket still
        // receives all audio for transcription — the buffer is only used for
        // the saved audio file. When the buffer is full, trim oldest bytes
        // so the saved file contains the most recent audio.
        final newTotal = _pcmBuffer.length + chunk.length;
        if (newTotal > _maxPcmBufferBytes) {
          final excess = newTotal - _maxPcmBufferBytes;
          final existing = _pcmBuffer.takeBytes();
          final kept = existing.length - excess;
          final merged = Uint8List(kept + chunk.length)
            ..setRange(0, kept, existing, excess)
            ..setRange(kept, kept + chunk.length, chunk);
          _pcmBuffer.add(merged);
        } else {
          _pcmBuffer.add(chunk);
        }

        if (!_amplitudeController.isClosed) {
          final dbfs = computeDbfsFromPcm16(chunk);
          _amplitudeController.add(dbfs);
        }
      },
      onError: (Object error) {
        getIt<LoggingService>().captureException(
          error,
          domain: 'RealtimeTranscriptionService',
          subDomain: 'pcmStream.error',
        );
      },
    );

    // Single subscription: accumulate for final transcript + notify controller
    _deltaSubscription = _repository.transcriptionDeltas.listen(
      (delta) {
        _deltaBuffer.write(delta);
        onDelta(delta);
      },
    );
  }

  /// Stops the real-time transcription session.
  ///
  /// 1. Cancels PCM stream subscription (stops forwarding audio)
  /// 2. Calls [stopRecorder] — mic off immediately
  /// 3. Sends `input_audio.end` to the server
  /// 4. Awaits `transcription.done` (with 10s timeout)
  /// 5. Writes accumulated PCM to temp WAV, converts to M4A
  /// 6. Disconnects WebSocket
  /// 7. Returns [RealtimeStopResult]
  Future<RealtimeStopResult> stop({
    required Future<void> Function() stopRecorder,
    required String outputPath,
  }) async {
    // 1. Stop forwarding audio
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;

    // 2. Stop the recorder (mic off)
    await stopRecorder();

    // 3. Signal end of audio
    await _repository.endAudio();

    // 4. Wait for transcription.done
    var transcript = _deltaBuffer.toString();
    var usedFallback = false;

    try {
      final done = await _repository.transcriptionDone.first.timeout(
        const Duration(seconds: 10),
      );
      transcript = done.text;
    } on TimeoutException {
      usedFallback = true;
      getIt<LoggingService>().captureEvent(
        'transcription.done timed out, using accumulated deltas '
        '(${transcript.length} chars)',
        domain: 'RealtimeTranscriptionService',
        subDomain: 'stop.timeout',
      );
    }

    // 5. Write temp WAV and convert to M4A
    final audioFilePath = await _saveAudio(outputPath);

    // 6. Disconnect
    await _cleanup();

    return RealtimeStopResult(
      transcript: transcript,
      audioFilePath: audioFilePath,
      usedTranscriptFallback: usedFallback,
    );
  }

  /// Tears down resources without saving (used by cancel).
  Future<void> dispose() async {
    await _pcmSubscription?.cancel();
    _pcmSubscription = null;
    await _deltaSubscription?.cancel();
    _deltaSubscription = null;

    await _cleanup();
  }

  Future<String?> _saveAudio(String outputPath) async {
    if (_pcmBuffer.length == 0) return null;

    final tempWavPath = '${Directory.systemTemp.path}/lotti_rt_'
        '${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      await _writeTempWav(tempWavPath);

      // Attempt M4A conversion
      final m4aPath =
          outputPath.endsWith('.m4a') ? outputPath : '$outputPath.m4a';

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
        final wavOutputPath =
            outputPath.endsWith('.wav') ? outputPath : '$outputPath.wav';
        await File(tempWavPath).rename(wavOutputPath);
        return wavOutputPath;
      }
    } catch (e) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'RealtimeTranscriptionService',
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
    await _repository.disconnect();
  }
}

final Provider<RealtimeTranscriptionService>
    realtimeTranscriptionServiceProvider =
    Provider<RealtimeTranscriptionService>((ref) {
  return RealtimeTranscriptionService(ref);
});

/// Whether a real-time transcription model is configured and available.
///
/// Used by UI components (chat input area, audio recording modal) to decide
/// whether to show the realtime mode toggle.
// ignore: specify_nonobvious_property_types
final realtimeAvailableProvider = FutureProvider.autoDispose<bool>((ref) async {
  final service = ref.watch(realtimeTranscriptionServiceProvider);
  final config = await service.resolveRealtimeConfig();
  return config != null;
});
