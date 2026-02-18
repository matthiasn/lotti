import 'package:flutter/services.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

/// Dart-side wrapper for native WAV-to-M4A audio conversion via a
/// platform channel.
///
/// On iOS and macOS, the native side uses `AVAudioFile` + `AVAudioConverter`
/// for hardware-accelerated AAC encoding. On platforms without a native
/// implementation (Linux, Windows, Android), [convertWavToM4a] returns
/// `false` so callers can fall back to keeping the WAV file.
class AudioConverterChannel {
  static const _channel = MethodChannel('com.matthiasn.lotti/audio_converter');

  /// Converts a WAV file at [inputPath] to M4A at [outputPath].
  ///
  /// Returns `true` on success, `false` if conversion is unsupported on this
  /// platform or if the native conversion fails. Callers should keep the
  /// original WAV as a fallback when this returns `false`.
  static Future<bool> convertWavToM4a({
    required String inputPath,
    required String outputPath,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('convertWavToM4a', {
        'inputPath': inputPath,
        'outputPath': outputPath,
      });
      return result ?? false;
    } on MissingPluginException {
      // Platform has no native implementation — fall back to WAV
      return false;
    } on PlatformException catch (e) {
      getIt<LoggingService>().captureEvent(
        'Native audio conversion failed: $e',
        domain: 'audio_converter_channel',
        subDomain: 'convertWavToM4a',
      );
      return false;
    }
  }
}
