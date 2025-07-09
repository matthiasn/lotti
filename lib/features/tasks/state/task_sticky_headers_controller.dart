import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_sticky_headers_controller.freezed.dart';

@freezed
class TaskStickyHeadersState with _$TaskStickyHeadersState {
  const factory TaskStickyHeadersState({
    required bool isTaskHeaderVisible,
    required bool isAiSummaryVisible,
    required bool isChecklistsVisible,
    @Default(0.0) double scrollOffset,
  }) = _TaskStickyHeadersState;

  factory TaskStickyHeadersState.initial() => const TaskStickyHeadersState(
        isTaskHeaderVisible: false,
        isAiSummaryVisible: false,
        isChecklistsVisible: false,
        scrollOffset: 0.0,
      );
}

// Provider to manage sticky headers state
final StateNotifierProviderFamily<TaskStickyHeadersController,
        TaskStickyHeadersState, String> taskStickyHeadersControllerProvider =
    StateNotifierProvider.family<TaskStickyHeadersController,
        TaskStickyHeadersState, String>(
  (ref, taskId) => TaskStickyHeadersController(taskId: taskId),
);

class TaskStickyHeadersController
    extends StateNotifier<TaskStickyHeadersState> {
  TaskStickyHeadersController({required this.taskId})
      : super(TaskStickyHeadersState.initial());

  final String taskId;

  // Thresholds for when headers become visible
  static const double taskHeaderThreshold = 100.0;
  static const double aiSummaryThreshold = 300.0;
  static const double checklistsThreshold = 500.0;

  void updateScrollOffset(double offset) {
    // Calculate new visibility states based on thresholds
    final newTaskHeaderVisible = offset > taskHeaderThreshold;
    final newAiSummaryVisible = offset > aiSummaryThreshold;
    final newChecklistsVisible = offset > checklistsThreshold;

    // Only update state if visibility has changed
    if (state.isTaskHeaderVisible != newTaskHeaderVisible ||
        state.isAiSummaryVisible != newAiSummaryVisible ||
        state.isChecklistsVisible != newChecklistsVisible ||
        state.scrollOffset != offset) {
      state = state.copyWith(
        isTaskHeaderVisible: newTaskHeaderVisible,
        isAiSummaryVisible: newAiSummaryVisible,
        isChecklistsVisible: newChecklistsVisible,
        scrollOffset: offset,
      );
    }
  }

  void resetVisibility() {
    state = TaskStickyHeadersState.initial();
  }

  void setTaskHeaderVisible(bool visible) {
    if (state.isTaskHeaderVisible != visible) {
      state = state.copyWith(isTaskHeaderVisible: visible);
    }
  }

  void setAiSummaryVisible(bool visible) {
    if (state.isAiSummaryVisible != visible) {
      state = state.copyWith(isAiSummaryVisible: visible);
    }
  }

  void setChecklistsVisible(bool visible) {
    if (state.isChecklistsVisible != visible) {
      state = state.copyWith(isChecklistsVisible: visible);
    }
  }
}
