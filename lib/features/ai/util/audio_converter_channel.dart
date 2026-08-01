import 'dart:io';

import 'package:audio_decoder/audio_decoder.dart';
import 'package:flutter/services.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

typedef AudioPathConverter =
    Future<void> Function({
      required String inputPath,
      required String outputPath,
    });
typedef AudioScratchFileDeleter = void Function(File file);

/// Dart-side wrapper for M4A-to-WAV audio conversion.
///
/// On Linux, conversion calls the native `convertM4aToWav` method channel.
/// Other supported platforms delegate to `audio_decoder` without bundling
/// FFmpeg.
class AudioConverterChannel {
  static const _channel = MethodChannel('com.matthiasn.lotti/audio_converter');

  /// Converts an M4A file at [inputPath] to PCM WAV at [outputPath].
  ///
  /// Uses Lotti's fail-fast GStreamer pipeline on Linux and `audio_decoder` on
  /// other platforms. Conversion failures are normalized and logged. The
  /// caller owns both paths and their cleanup.
  static Future<void> convertM4aToWav({
    required String inputPath,
    required String outputPath,
  }) async {
    try {
      if (Platform.isLinux) {
        await _channel.invokeMethod<bool>('convertM4aToWav', {
          'inputPath': inputPath,
          'outputPath': outputPath,
        });
      } else {
        await AudioDecoder.convertToWav(inputPath, outputPath);
      }
    } on PlatformException catch (error, stackTrace) {
      final conversionError = AudioConversionException(
        error.message ?? error.code,
        details: error.details?.toString(),
      );
      getIt<DomainLogger>().error(
        LogDomain.speech,
        conversionError,
        stackTrace: stackTrace,
        subDomain: 'convertM4aToWav',
        message: 'Native M4A-to-WAV conversion failed',
      );
      throw conversionError;
    } catch (error, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.speech,
        error,
        stackTrace: stackTrace,
        subDomain: 'convertM4aToWav',
        message: 'Native M4A-to-WAV conversion failed',
      );
      rethrow;
    }
  }
}

/// Converts in-memory M4A bytes through temporary files, reads the result, then
/// removes each scratch file independently before returning.
///
/// The archived M4A is never changed. Conversion failures propagate after
/// cleanup so callers can surface the decoder detail instead of silently
/// changing request semantics. Cleanup is best-effort so one filesystem
/// deletion failure does not leave the other scratch file behind.
Future<Uint8List> convertM4aBytesToTemporaryWav(
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
    await convert(
      inputPath: inputFile.path,
      outputPath: outputFile.path,
    );
    if (!outputFile.existsSync() || outputFile.lengthSync() == 0) {
      throw FileSystemException(
        'Native M4A-to-WAV conversion completed without a valid output file',
        outputFile.path,
      );
    }
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
