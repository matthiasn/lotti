import 'dart:async';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:media_kit/media_kit.dart';

/// Function type for reading audio duration from a file.
typedef AudioMetadataReader = Future<Duration> Function(String filePath);

/// Utility class for extracting and parsing audio file metadata.
///
/// Contains both pure parsing functions (timestamp, path computation) and
/// async operations for duration extraction via MediaKit.
///
/// ## Usage
///
/// ```dart
/// // Parse timestamp from filename
/// final timestamp = AudioMetadataExtractor.parseFilenameTimestamp(
///   '2024-01-15_10-30-45-123.m4a',
/// );
///
/// // Compute storage paths
/// final relativePath = AudioMetadataExtractor.computeRelativePath(timestamp);
/// final filename = AudioMetadataExtractor.computeTargetFileName(timestamp, 'm4a');
///
/// // Extract duration (async)
/// final duration = await AudioMetadataExtractor.extractDuration(filePath);
/// ```
class AudioMetadataExtractor {
  const AudioMetadataExtractor._();

  /// Supported audio file extensions for import.
  static const List<String> supportedExtensions = [
    'm4a',
    'aac',
    'mp3',
    'wav',
    'ogg',
  ];

  /// Timeout for MediaKit player initialization.
  static const Duration playerOpenTimeout = Duration(seconds: 3);

  /// Timeout for waiting for duration stream.
  static const Duration durationStreamTimeout = Duration(seconds: 5);

  /// Test bypass flag - when true, duration extraction returns Duration.zero
  /// without invoking MediaKit.
  ///
  /// This flag is exposed for backward compatibility with existing test code.
  /// In production, this should always be false.
  static bool bypassMediaKitInTests = false;

  /// Parses timestamp from audio filename if it matches Lotti's format.
  ///
  /// Expected format: `yyyy-MM-dd_HH-mm-ss-S.extension`
  /// (e.g., `2025-10-20_16-49-32-203.m4a`)
  ///
  /// Returns the parsed DateTime if successful, null otherwise.
  /// The parsed timestamp is converted to local time.
  ///
  /// Examples:
  /// - `2024-01-15_10-30-45-123.m4a` → DateTime(2024, 1, 15, 10, 30, 45, 123)
  /// - `invalid-format.m4a` → null
  /// - `2024-01-15.m4a` → null (missing time components)
  static DateTime? parseFilenameTimestamp(String filename) {
    try {
      // Remove file extension before parsing
      final nameWithoutExtension = filename.split('.').first;

      // Try to parse using Lotti's audio filename format
      return DateFormat(AudioRecorderConstants.fileNameDateFormat)
          .parse(nameWithoutExtension, true)
          .toLocal();
    } on FormatException {
      // Return null if parsing fails (expected for non-Lotti filenames)
      return null;
    }
  }

  /// Computes the relative directory path for storing audio files.
  ///
  /// Returns a path like `/audio/2024-01-15/` based on the timestamp.
  static String computeRelativePath(DateTime timestamp) {
    final day = DateFormat(AudioRecorderConstants.directoryDateFormat)
        .format(timestamp);
    return '${AudioRecorderConstants.audioDirectoryPrefix}$day/';
  }

  /// Computes the target filename for an audio file.
  ///
  /// Returns a filename like `2024-01-15_10-30-45-123.m4a` based on the
  /// timestamp and extension.
  static String computeTargetFileName(DateTime timestamp, String extension) {
    final base =
        DateFormat(AudioRecorderConstants.fileNameDateFormat).format(timestamp);
    return '$base.$extension';
  }

  /// Checks if a file extension is a supported audio format.
  ///
  /// The extension should be provided without the leading dot.
  static bool isSupported(String extension) {
    return supportedExtensions.contains(extension.toLowerCase());
  }

  /// Selects the appropriate audio metadata reader based on environment.
  ///
  /// In test environments (FLUTTER_TEST=true or [bypassMediaKitInTests]=true),
  /// returns a no-op reader that returns Duration.zero.
  ///
  /// If a custom [AudioMetadataReader] is registered via GetIt, uses that.
  /// Otherwise, uses [extractDuration] with MediaKit.
  static AudioMetadataReader selectReader({
    AudioMetadataReader? registeredReader,
  }) {
    // Use registered reader if provided (for dependency injection)
    if (registeredReader != null) {
      return registeredReader;
    }

    // Check if a reader is registered in GetIt (highest priority)
    if (getIt.isRegistered<AudioMetadataReader>()) {
      return getIt<AudioMetadataReader>();
    }

    // In headless/flutter test environments, prefer a no-op reader to avoid
    // invoking platform media backends that may hang or be unavailable.
    final isFlutterTestEnv = () {
      try {
        return Platform.environment['FLUTTER_TEST'] == 'true';
      } catch (_) {
        return false;
      }
    }();

    if (bypassMediaKitInTests || isFlutterTestEnv) {
      return (_) async => Duration.zero;
    }
    return extractDuration;
  }

  /// Extracts audio duration from file using MediaKit.
  ///
  /// Returns [Duration.zero] if:
  /// - [bypassMediaKitInTests] is true
  /// - The file cannot be opened
  /// - Duration extraction times out
  /// - Any error occurs during extraction
  ///
  /// This method is safe to call - it will not throw exceptions but will
  /// return Duration.zero on any failure.
  static Future<Duration> extractDuration(String filePath) async {
    Player? player;
    try {
      if (bypassMediaKitInTests) {
        return Duration.zero;
      }
      player = Player();
      try {
        // Guard against environments where media backends are unavailable.
        await player
            .open(Media(filePath), play: false)
            .timeout(playerOpenTimeout);
      } on TimeoutException {
        return Duration.zero;
      } catch (_) {
        // Opening failed – fall back to zero duration without failing import.
        return Duration.zero;
      }

      try {
        return await player.stream.duration
            .firstWhere((d) => d > Duration.zero, orElse: () => Duration.zero)
            .timeout(durationStreamTimeout, onTimeout: () => Duration.zero);
      } on TimeoutException {
        return Duration.zero;
      } catch (_) {
        return Duration.zero;
      }
    } finally {
      await player?.dispose();
    }
  }
}
