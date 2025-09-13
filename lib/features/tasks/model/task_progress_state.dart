import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_progress_state.freezed.dart';

@freezed
abstract class TaskProgressState with _$TaskProgressState {
  const factory TaskProgressState({
    required Duration progress,
    required Duration estimate,
  }) = _TaskProgressState;
}
