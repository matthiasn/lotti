import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/speech/repository/audio_recorder_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

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

  /// Factory used to construct the MediaKit [Player] in [extractDuration].
  ///
  /// Production code uses the default ([Player.new]). Tests can override this
  /// to inject a fake player and exercise the duration-extraction logic without
  /// a real libmpv backend. Always restore it to [Player.new] in tearDown.
  @visibleForTesting
  static Player Function() playerFactory = Player.new;

  /// Parses timestamp from audio filename if it matches Lotti's format.
  ///
  /// Expected format: `yyyy-MM-dd_HH-mm-ss-S.extension`
  /// (e.g., `2025-10-20_16-49-32-203.m4a`)
  ///
  /// Returns the parsed DateTime if successful, null otherwise.
  /// The parsed timestamp is converted to local time.
  ///
  /// Parsing is **strict**: the whole name must be the timestamp. Lenient
  /// parsing accepts trailing characters, so `…-203 2.m4a` and
  /// `…-203-copy.m4a` both read back as the timestamp of `…-203.m4a` and
  /// therefore compute the same storage path — three different recordings
  /// overwriting one file. A name that is only *nearly* a Lotti timestamp is
  /// not one, and falls back to the file's modification time instead.
  ///
  /// Examples:
  /// - `2024-01-15_10-30-45-123.m4a` → DateTime(2024, 1, 15, 10, 30, 45, 123)
  /// - `invalid-format.m4a` → null
  /// - `2024-01-15.m4a` → null (missing time components)
  /// - `2024-01-15_10-30-45-123 2.m4a` → null (trailing characters)
  static DateTime? parseFilenameTimestamp(String filename) {
    try {
      // Remove file extension before parsing
      final nameWithoutExtension = filename.split('.').first;

      // Try to parse using Lotti's audio filename format
      return DateFormat(
        AudioRecorderConstants.fileNameDateFormat,
      ).parseStrict(nameWithoutExtension, true).toLocal();
    } on FormatException {
      // Return null if parsing fails (expected for non-Lotti filenames)
      return null;
    }
  }

  /// Computes the relative directory path for storing audio files.
  ///
  /// Returns a path like `/audio/2024-01-15/` based on the timestamp.
  static String computeRelativePath(DateTime timestamp) {
    final day = DateFormat(
      AudioRecorderConstants.directoryDateFormat,
    ).format(timestamp);
    return '${AudioRecorderConstants.audioDirectoryPrefix}$day/';
  }

  /// Computes the target filename for an audio file.
  ///
  /// Returns a filename like `2024-01-15_10-30-45-123.m4a` based on the
  /// timestamp and extension.
  static String computeTargetFileName(DateTime timestamp, String extension) {
    final base = DateFormat(
      AudioRecorderConstants.fileNameDateFormat,
    ).format(timestamp);
    return '$base.$extension';
  }

  /// Claims a free name under [directory], starting from [preferredFileName]
  /// and appending `-1`, `-2`, … before the extension until one is taken.
  ///
  /// **Creates the file**, empty, as it claims it — the caller is expected to
  /// write over it, and to delete it if the import then fails. Claiming is a
  /// single atomic `create(exclusive: true)` rather than an existence check
  /// followed by a copy, because two imports can overlap: duration extraction
  /// holds each one open for seconds, which is more than enough for a second
  /// drop to check the same name, find it free, and overwrite the first.
  ///
  /// Import target names are derived purely from the recording's timestamp,
  /// so two distinct sources can compute the same name — two recorders that
  /// stamped the same millisecond, or two files whose modification times
  /// agree because they were unpacked from the same archive. Copying over an
  /// occupied name destroys the earlier recording while its journal entry
  /// keeps pointing at the path, so that entry silently starts playing (and
  /// transcribing) the newer recording's audio.
  ///
  /// The loop terminates: every iteration probes a name no earlier iteration
  /// probed, and a directory holds finitely many files.
  static String claimAvailableFileName({
    required String directory,
    required String preferredFileName,
  }) {
    final extension = p.extension(preferredFileName);
    final base = p.basenameWithoutExtension(preferredFileName);
    var candidate = preferredFileName;
    var suffix = 0;
    while (!_claimFile(p.join(directory, candidate))) {
      suffix++;
      candidate = '$base-$suffix$extension';
    }
    return candidate;
  }

  /// Creates [path] and reports whether this caller is the one that made it.
  /// `false` means the name was already taken.
  ///
  /// `createSync(exclusive: true)` raises the same [FileSystemException] for
  /// an occupied name and for a failure that has nothing to do with the name
  /// — a read-only or full volume, a missing or unwritable directory. Only
  /// the first is a reason to try the next suffix; treating the rest as
  /// "taken" would spin [claimAvailableFileName] forever on a failure that
  /// repeats for every candidate, blocking the isolate outright. So anything
  /// that did not leave a file behind is rethrown, and `importAudioXFiles`
  /// logs it and moves on to the next file.
  ///
  /// This also keeps the loop finite: it only advances when the candidate
  /// really does exist, and a directory holds finitely many entries.
  static bool _claimFile(String path) {
    try {
      File(path).createSync(exclusive: true);
      return true;
    } on FileSystemException {
      if (!File(path).existsSync()) rethrow;
      return false;
    }
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
      player = playerFactory();
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
