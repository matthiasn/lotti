import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_progress_state.freezed.dart';

/// Snapshot of a task's time tracking: [progress] is the recorded time spent
/// (union of all counting entries) and [estimate] is the planned duration.
/// Both default to [Duration.zero] when unknown; the progress bar renders the
/// ratio of the two.
@freezed
abstract class TaskProgressState with _$TaskProgressState {
  const factory TaskProgressState({
    required Duration progress,
    required Duration estimate,
  }) = _TaskProgressState;
}
