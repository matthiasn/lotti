/// Recording configuration constants shared by `AudioRecorderRepository` and
/// the media import paths.
///
/// Holds the on-disk layout (`/audio/<day>/` grouping, file-name timestamp
/// format) and the per-method `LogDomain.speech` sub-domain strings used so
/// log lines can be filtered by operation.
class AudioRecorderConstants {
  const AudioRecorderConstants._();

  // Recording configuration
  static const String audioDirectoryPrefix = '/audio/';

  // Date formats
  static const String fileNameDateFormat = 'yyyy-MM-dd_HH-mm-ss-S';
  static const String directoryDateFormat = 'yyyy-MM-dd';

  // Domain names for logging
  static const String hasPermissionSubdomain = 'hasPermission';
  static const String isPausedSubdomain = 'isPaused';
  static const String isRecordingSubdomain = 'isRecording';
  static const String startRecordingSubdomain = 'startRecording';
  static const String stopRecordingSubdomain = 'stopRecording';
  static const String deleteRecordingSubdomain = 'deleteRecording';
  static const String pauseRecordingSubdomain = 'pauseRecording';
  static const String resumeRecordingSubdomain = 'resumeRecording';
  static const String disposeSubdomain = 'dispose';
}
