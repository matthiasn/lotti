import 'package:freezed_annotation/freezed_annotation.dart';

part 'recorder_state.freezed.dart';

enum AudioRecorderStatus { initializing, initialized, recording, stopped }

@freezed
class AudioRecorderState with _$AudioRecorderState {
  factory AudioRecorderState({
    required AudioRecorderStatus status,
    required Duration progress,
    required double decibels,
  }) = _AudioRecorderState;
}
