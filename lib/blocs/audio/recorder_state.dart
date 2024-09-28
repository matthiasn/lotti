import 'package:freezed_annotation/freezed_annotation.dart';

part 'recorder_state.freezed.dart';

enum AudioRecorderStatus {
  initializing,
  initialized,
  recording,
  stopped,
  paused
}

@freezed
class AudioRecorderState with _$AudioRecorderState {
  factory AudioRecorderState({
    required AudioRecorderStatus status,
    required Duration progress,
    required double decibels,
    required bool showIndicator,
    required String? language,
    String? linkedId,
  }) = _AudioRecorderState;
}
