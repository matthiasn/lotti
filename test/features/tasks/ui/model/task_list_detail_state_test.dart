import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_state.dart';
import 'package:lotti/features/tasks/widgetbook/task_list_detail_mock_data.dart';

void main() {
  group('TaskListDetailState', () {
    test('selects the matching task when visible', () {
      final state = TaskListDetailState(
        data: buildTaskListDetailMockData(),
        searchQuery: '',
        selectedTaskId: 'payment-confirmation',
        filterState: buildTaskShowcaseFilterState(),
      );

      expect(state.selectedTask?.task.meta.id, 'payment-confirmation');
      expect(state.visibleSections.first.title, 'Today');
      expect(state.visibleSections.first.tasks.length, 3);
    });

    test('filters visible tasks by search query across title and project', () {
      final state = TaskListDetailState(
        data: buildTaskListDetailMockData(),
        searchQuery: 'device sync',
        selectedTaskId: 'payment-confirmation',
        filterState: buildTaskShowcaseFilterState(),
      );

      expect(
        state.visibleTasks.map((record) => record.task.meta.id),
        ['payment-confirmation'],
      );
    });

    test('filters visible tasks by selected priority', () {
      final state = TaskListDetailState(
        data: buildTaskListDetailMockData(),
        searchQuery: '',
        selectedTaskId: 'payment-confirmation',
        filterState: buildTaskShowcaseFilterState().copyWith(
          selectedPriorityIds: const {TaskPriorityFilterIds.p1},
        ),
      );

      expect(
        state.visibleTasks.every(
          (record) => record.task.data.priority.short == 'P1',
        ),
        isTrue,
      );
      expect(
        state.visibleTasks.map((record) => record.task.meta.id),
        containsAll([
          'payment-confirmation',
          'sprint-planning',
          'customer-onboarding',
          'marketing-campaign',
        ]),
      );
    });

    test('filters visible tasks by selected label', () {
      final state = TaskListDetailState(
        data: buildTaskListDetailMockData(),
        searchQuery: '',
        selectedTaskId: 'payment-confirmation',
        filterState: buildTaskShowcaseFilterState().copyWith(
          labelField: const DesignSystemTaskFilterFieldState(
            label: 'Labels',
            options: [
              DesignSystemTaskFilterOption(id: 'bug-fix', label: 'Bug fix'),
              DesignSystemTaskFilterOption(
                id: 'release-blocker',
                label: 'Release blocker',
              ),
            ],
            selectedIds: {'release-blocker'},
          ),
        ),
      );

      expect(
        state.visibleTasks.map((record) => record.task.meta.id),
        ['payment-confirmation'],
      );
    });
  });
}
