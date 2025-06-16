import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';

part 'recorder_state.freezed.dart';

/// Represents the various states of the audio recorder.
enum AudioRecorderStatus {
  /// Recorder is being initialized (permissions, setup).
  initializing,

  /// Recorder is ready to start recording.
  initialized,

  /// Actively recording audio.
  recording,

  /// Recording has been stopped and saved.
  stopped,

  /// Recording is temporarily paused.
  paused
}

/// Immutable state model for the audio recording feature.
///
/// This state is managed by [AudioRecorderController] and consumed by
/// UI components to display recording status, audio levels, and controls.
@freezed
class AudioRecorderState with _$AudioRecorderState {
  factory AudioRecorderState({
    /// Current status of the recorder.
    required AudioRecorderStatus status,

    /// Duration of the current recording.
    required Duration progress,

    /// Current audio level in decibels (0-160 range).
    /// Used for VU meter visualization.
    required double decibels,

    /// Whether to show the floating recording indicator.
    /// Only relevant when recording and modal is not visible.
    required bool showIndicator,

    /// Whether the recording modal is currently visible.
    /// Used to coordinate with indicator display.
    required bool modalVisible,

    /// Selected language for transcription.
    /// Empty string means auto-detect.
    required String? language,

    /// Optional ID to link recording to existing journal entry.
    String? linkedId,
  }) = _AudioRecorderState;
}
