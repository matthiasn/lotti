// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_state.dart';
import 'package:lotti/features/tasks/widgetbook/task_list_detail_mock_data.dart';

final taskListDetailShowcaseControllerProvider =
    NotifierProvider.autoDispose<
      TaskListDetailShowcaseController,
      TaskListDetailState
    >(TaskListDetailShowcaseController.new);

class TaskListDetailShowcaseController extends Notifier<TaskListDetailState> {
  @override
  TaskListDetailState build() {
    final data = buildTaskListDetailMockData();
    return TaskListDetailState(
      data: data,
      searchQuery: '',
      selectedTaskId: 'payment-confirmation',
      filterState: buildTaskShowcaseFilterState(),
    );
  }

  void updateSearchQuery(String value) {
    if (value == state.searchQuery) {
      return;
    }

    final candidate = state.copyWith(searchQuery: value);
    state = candidate.copyWith(
      selectedTaskId: _resolveSelectedTaskId(candidate),
    );
  }

  void selectTask(String taskId) {
    if (taskId == state.selectedTaskId) {
      return;
    }

    final exists = state.data.tasks.any((task) => task.task.meta.id == taskId);
    if (!exists) {
      return;
    }

    state = state.copyWith(selectedTaskId: taskId);
  }

  void updateFilterState(DesignSystemTaskFilterState nextState) {
    final candidate = state.copyWith(filterState: nextState);
    state = candidate.copyWith(
      selectedTaskId: _resolveSelectedTaskId(candidate),
    );
  }

  String _resolveSelectedTaskId(TaskListDetailState candidate) {
    final visible = candidate.visibleTasks;
    final currentStillVisible = visible.any(
      (task) => task.task.meta.id == candidate.selectedTaskId,
    );

    if (currentStillVisible) {
      return candidate.selectedTaskId;
    }

    return visible.firstOrNull?.task.meta.id ?? candidate.selectedTaskId;
  }
}
