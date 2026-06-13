import 'package:intl/intl.dart';

/// Date format for the per-recording file-name stem, e.g.
/// `2026-02-17_09-31-04-7`.
const audioFileNameDateFormat = 'yyyy-MM-dd_HH-mm-ss-S';

/// Date format for the per-day audio sub-directory, e.g. `2026-02-17`.
const audioDayDateFormat = 'yyyy-MM-dd';

/// Prefix under the documents directory where audio is grouped by day.
const audioDirectoryPrefix = '/audio/';

/// Pure, deterministic mapping from a recording timestamp to the on-disk
/// layout shared by every audio entry: a per-day directory plus a
/// timestamped file stem.
///
/// Owns no IO — directory creation and recorder wiring stay in the caller.
/// Holding the date math here keeps the layout identical across the realtime
/// and batch recording paths and makes it unit-testable without a recorder.
class AudioRecordingPath {
  AudioRecordingPath._({
    required this.fileNameStem,
    required this.relativeDirectory,
  });

  /// Builds the layout for a recording [created] at the given instant.
  factory AudioRecordingPath.forTimestamp(DateTime created) {
    final day = DateFormat(audioDayDateFormat).format(created);
    return AudioRecordingPath._(
      fileNameStem: DateFormat(audioFileNameDateFormat).format(created),
      relativeDirectory: '$audioDirectoryPrefix$day/',
    );
  }

  /// Timestamped file stem without an extension, e.g.
  /// `2026-02-17_09-31-04-7`.
  final String fileNameStem;

  /// Per-day relative directory, e.g. `/audio/2026-02-17/`.
  final String relativeDirectory;

  /// File name with the `.m4a` extension applied.
  String get m4aFileName => '$fileNameStem.m4a';

  /// Joins the stem onto an already-resolved absolute [directory] to form the
  /// extension-less output path handed to the realtime service (which appends
  /// the final container extension itself).
  String outputPathIn(String directory) => '$directory$fileNameStem';
}
