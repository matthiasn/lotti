import 'dart:io';
import 'dart:typed_data';

import 'package:lotti/features/ai/util/audio_converter_channel.dart';
import 'package:lotti/features/speech/services/pcm_wav.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

export 'package:lotti/features/speech/services/pcm_wav.dart'
    show buildWavHeader;

/// Signature of a WAV→M4A converter, matching
/// [AudioConverterChannel.convertWavToM4a]. Returns `true` on success;
/// `false` means the caller should keep the WAV as a fallback.
typedef WavToM4aConverter =
    Future<bool> Function({
      required String inputPath,
      required String outputPath,
    });

/// Persists captured realtime PCM audio as an audio file.
///
/// Writes the PCM to a temp WAV, attempts native M4A conversion via the
/// injected [WavToM4aConverter] (defaulting to
/// [AudioConverterChannel.convertWavToM4a]), and falls back to keeping the
/// WAV when conversion is unavailable or fails. Errors are logged via
/// `getIt<DomainLogger>()` and the best surviving file path is returned.
class RealtimeAudioWriter {
  RealtimeAudioWriter({
    WavToM4aConverter? convertWavToM4a,
    Directory? tempDirectory,
  }) : _convertWavToM4a =
           convertWavToM4a ?? AudioConverterChannel.convertWavToM4a,
       _tempDirectory = tempDirectory ?? Directory.systemTemp;

  final WavToM4aConverter _convertWavToM4a;
  final Directory _tempDirectory;

  /// Saves [pcm] (16-bit/16kHz/mono) to an audio file derived from
  /// [outputPath].
  ///
  /// Returns the path of the resulting file: `<outputPath>.m4a` on
  /// successful conversion, `<outputPath>.wav` as fallback, the temp WAV
  /// path if moving it failed, or `null` when [pcm] is empty or nothing
  /// could be written.
  Future<String?> saveAudio({
    required Uint8List pcm,
    required String outputPath,
  }) async {
    if (pcm.isEmpty) return null;

    final tempWavPath =
        '${_tempDirectory.path}/lotti_rt_'
        '${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      await _writeWav(tempWavPath, pcm);

      // Attempt M4A conversion
      final m4aPath = outputPath.endsWith('.m4a')
          ? outputPath
          : '$outputPath.m4a';

      final converted = await _convertWavToM4a(
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

  Future<void> _writeWav(String path, Uint8List pcm) async {
    final sink = File(path).openWrite()
      ..add(buildWavHeader(dataSize: pcm.length))
      ..add(pcm);
    await sink.flush();
    await sink.close();
  }
}
