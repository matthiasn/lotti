import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Result of an audio format conversion operation.
class AudioConversionResult {
  AudioConversionResult({
    required this.success,
    this.outputPath,
    this.error,
  });

  final bool success;
  final String? outputPath;
  final String? error;
}

/// Utility class for converting audio files between formats.
///
/// Uses FFmpeg under the hood:
/// - On Android, iOS, and macOS: Uses ffmpeg_kit_flutter_new_min package
/// - On Linux and Windows: Uses system-installed FFmpeg binary
///
/// Supports conversion from M4A/AAC to WAV format, which is required
/// by some cloud transcription services like Voxtral Cloud.
class AudioFormatConverter {
  /// Converts an M4A audio file to WAV format.
  ///
  /// The output file is created in the system's temporary directory
  /// with a unique name based on the input file name.
  ///
  /// Returns an [AudioConversionResult] with the path to the converted
  /// file on success, or an error message on failure.
  static Future<AudioConversionResult> convertM4aToWav(String inputPath) async {
    try {
      // Validate input file exists
      final inputFile = File(inputPath);
      if (!inputFile.existsSync()) {
        return AudioConversionResult(
          success: false,
          error: 'Input file does not exist: $inputPath',
        );
      }

      // Create output path in temp directory
      final tempDir = await getTemporaryDirectory();
      final inputFileName = p.basenameWithoutExtension(inputPath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath =
          p.join(tempDir.path, '${inputFileName}_$timestamp.wav');

      // Use system FFmpeg on Linux/Windows, FFmpegKit on mobile/macOS
      if (Platform.isLinux || Platform.isWindows) {
        return _convertWithSystemFfmpeg(inputPath, outputPath);
      } else {
        return _convertWithFfmpegKit(inputPath, outputPath);
      }
    } catch (e) {
      return AudioConversionResult(
        success: false,
        error: 'Audio conversion error: $e',
      );
    }
  }

  /// Converts using the system-installed FFmpeg binary (Linux/Windows).
  static Future<AudioConversionResult> _convertWithSystemFfmpeg(
    String inputPath,
    String outputPath,
  ) async {
    try {
      // FFmpeg command arguments for M4A to WAV conversion (16-bit PCM)
      // -i: input file
      // -acodec pcm_s16le: 16-bit little-endian PCM (standard WAV format)
      // -ar 8000: 8kHz sample rate (keeps file size under 20MB for long audio)
      // -ac 1: mono channel (sufficient for speech)
      // -y: overwrite output file if exists
      final result = await Process.run(
        'ffmpeg',
        [
          '-i',
          inputPath,
          '-acodec',
          'pcm_s16le',
          '-ar',
          '8000',
          '-ac',
          '1',
          '-y',
          outputPath,
        ],
      );

      if (result.exitCode == 0) {
        return AudioConversionResult(
          success: true,
          outputPath: outputPath,
        );
      } else {
        return AudioConversionResult(
          success: false,
          error: 'FFmpeg conversion failed (exit code ${result.exitCode}): '
              '${result.stderr}',
        );
      }
    } on ProcessException catch (e) {
      return AudioConversionResult(
        success: false,
        error: 'FFmpeg not found. Please install FFmpeg on your system: $e',
      );
    }
  }

  /// Converts using FFmpegKit library (Android/iOS/macOS).
  static Future<AudioConversionResult> _convertWithFfmpegKit(
    String inputPath,
    String outputPath,
  ) async {
    // FFmpeg command to convert M4A to WAV (16-bit PCM)
    // -i: input file
    // -acodec pcm_s16le: 16-bit little-endian PCM (standard WAV format)
    // -ar 8000: 8kHz sample rate (keeps file size under 20MB for long audio)
    // -ac 1: mono channel (sufficient for speech)
    // -y: overwrite output file if exists
    final command =
        '-i "$inputPath" -acodec pcm_s16le -ar 8000 -ac 1 -y "$outputPath"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      return AudioConversionResult(
        success: true,
        outputPath: outputPath,
      );
    } else {
      final logs = await session.getAllLogsAsString();
      return AudioConversionResult(
        success: false,
        error: 'FFmpeg conversion failed: $logs',
      );
    }
  }

  /// Deletes a temporary converted file.
  ///
  /// Call this after the converted file is no longer needed
  /// to clean up temporary storage.
  static Future<void> deleteConvertedFile(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore deletion errors - temp files will be cleaned up eventually
    }
  }

  /// Checks if a file path has an M4A extension.
  static bool isM4aFile(String path) {
    return p.extension(path).toLowerCase() == '.m4a';
  }

  /// Checks if a file path has a WAV extension.
  static bool isWavFile(String path) {
    return p.extension(path).toLowerCase() == '.wav';
  }
}
