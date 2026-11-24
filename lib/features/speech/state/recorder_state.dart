import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/speech/state/recording_origin.dart';

part 'recorder_state.freezed.dart';

/// Represents the various states of the audio recorder.
enum AudioRecorderStatus {
  /// Actively recording audio.
  recording,

  /// Recording has been stopped and saved.
  stopped,

  /// Recording is temporarily paused.
  paused,
}

/// Immutable state model for the audio recording feature.
///
/// This state is managed by [AudioRecorderController] and consumed by
/// UI components to display recording status, audio levels, and controls.
@freezed
abstract class AudioRecorderState with _$AudioRecorderState {
  factory AudioRecorderState({
    /// Current status of the recorder.
    required AudioRecorderStatus status,

    /// Duration of the current recording.
    required Duration progress,

    /// Current audio level in dBFS, as the level line draws it.
    required double dBFS,

    /// Whether a check-in screen is drawing this take in place. The
    /// recording strip stays hidden while it is: the take already has a
    /// recorder on screen.
    required bool inlineHostVisible,

    /// Optional ID to link recording to existing journal entry.
    String? linkedId,

    /// Where the running take was started; null while nothing records.
    RecordingOrigin? origin,

    /// Whether to trigger speech recognition after recording.
    /// If null, uses category default settings.
    bool? enableSpeechRecognition,
  }) = _AudioRecorderState;
}

/// Session-scoped reads on [AudioRecorderState] that more than one surface
/// asks, kept here so "an active session linked to X" has one definition.
extension AudioRecorderSession on AudioRecorderState {
  /// True while a take is in flight — recording or paused — whatever it is
  /// linked to.
  bool get isTakeActive =>
      status == AudioRecorderStatus.recording ||
      status == AudioRecorderStatus.paused;

  /// True while a recording session is in flight — recording or paused — for
  /// the task or entry [linkedId]. A stopped session, or one linked to
  /// another entry or to nothing, is not this one's.
  bool isActiveSessionFor(String linkedId) {
    return isTakeActive && this.linkedId == linkedId;
  }
}
