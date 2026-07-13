import 'dart:io';

import 'package:flutter/services.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

typedef AudioPathConverter =
    Future<bool> Function({
      required String inputPath,
      required String outputPath,
    });
typedef AudioScratchFileDeleter = void Function(File file);

/// Dart-side wrapper for native WAV/M4A audio conversion via a platform
/// channel.
///
/// On iOS and macOS, the native side uses `AVAudioFile` for AAC encoding and
/// PCM decoding. Platforms without a native implementation return `false` so
/// callers can preserve their source file or select a provider fallback.
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
      getIt<DomainLogger>().log(
        LogDomain.speech,
        'Native audio conversion failed: $e',
        subDomain: 'convertWavToM4a',
      );
      return false;
    }
  }

  /// Converts an M4A file at [inputPath] to PCM WAV at [outputPath].
  ///
  /// Apple platforms use AVFoundation. Platforms without a registered native
  /// implementation return `false`, allowing provider code to use its
  /// non-converting compatibility path.
  static Future<bool> convertM4aToWav({
    required String inputPath,
    required String outputPath,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('convertM4aToWav', {
        'inputPath': inputPath,
        'outputPath': outputPath,
      });
      return result ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      getIt<DomainLogger>().log(
        LogDomain.speech,
        'Native M4A-to-WAV conversion failed: $e',
        subDomain: 'convertM4aToWav',
      );
      return false;
    }
  }
}

/// Converts in-memory M4A bytes through temporary files, reads the result, then
/// removes each scratch file independently before returning.
///
/// The archived M4A is never changed. A `null` result means native conversion
/// was unavailable or failed, so callers can choose a provider-specific
/// fallback. Cleanup is best-effort so one filesystem deletion failure does
/// not leave the other scratch file behind.
Future<Uint8List?> convertM4aBytesToTemporaryWav(
  Uint8List m4aBytes, {
  AudioPathConverter? converter,
  AudioScratchFileDeleter? scratchFileDeleter,
  Directory? temporaryDirectory,
  String? fileStem,
}) async {
  final directory = temporaryDirectory ?? Directory.systemTemp;
  final stem = fileStem ?? 'lotti_melious_${const Uuid().v4()}';
  final inputFile = File(p.join(directory.path, '$stem.m4a'));
  final outputFile = File(p.join(directory.path, '$stem.wav'));
  final convert = converter ?? AudioConverterChannel.convertM4aToWav;
  final deleteScratchFile = scratchFileDeleter ?? (file) => file.deleteSync();

  try {
    await directory.create(recursive: true);
    await inputFile.writeAsBytes(m4aBytes, flush: true);
    final converted = await convert(
      inputPath: inputFile.path,
      outputPath: outputFile.path,
    );
    if (!converted || !outputFile.existsSync()) return null;
    return await outputFile.readAsBytes();
  } finally {
    for (final file in [inputFile, outputFile]) {
      try {
        if (file.existsSync()) deleteScratchFile(file);
      } on FileSystemException {
        // Scratch cleanup is best-effort, and one failure must not prevent the
        // other file from being removed.
      }
    }
  }
}
