import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart'
    show Any, CombinableAny, ExploreConfig, Generator, Glados, IntAnys, any;
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_models.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_state.dart';
import 'package:lotti/features/tasks/widgetbook/task_list_detail_mock_data.dart';

const List<String> _generatedStatusIds = [
  TaskStatusFilterIds.open,
  TaskStatusFilterIds.inProgress,
  TaskStatusFilterIds.groomed,
  TaskStatusFilterIds.blocked,
  TaskStatusFilterIds.onHold,
  TaskStatusFilterIds.done,
  TaskStatusFilterIds.rejected,
];

const _generatedCategoryIds = [
  'work',
  'study',
  'leisure',
  'meals',
  'household',
  'meeting',
];

const _generatedLabelIds = [
  'bug-fix',
  'release-blocker',
  'qa',
];

const List<String> _generatedPriorityIds = [
  TaskPriorityFilterIds.p0,
  TaskPriorityFilterIds.p1,
  TaskPriorityFilterIds.p2,
  TaskPriorityFilterIds.p3,
];

const List<String> _generatedSortIds = [
  TaskSortIds.dueDateSort,
  TaskSortIds.createdDateSort,
  TaskSortIds.prioritySort,
];

const _generatedQueries = [
  '',
  'payment',
  'device sync',
  'bug fix',
  'work',
  'meeting',
  'weekly',
  'missing-query',
];

class _GeneratedTaskListScenario {
  const _GeneratedTaskListScenario({
    required this.statusMask,
    required this.categoryMask,
    required this.labelMask,
    required this.priorityMask,
    required this.sortIndex,
    required this.queryIndex,
    required this.selectedTaskIndex,
  });

  final int statusMask;
  final int categoryMask;
  final int labelMask;
  final int priorityMask;
  final int sortIndex;
  final int queryIndex;
  final int selectedTaskIndex;

  String get sortId => _generatedSortIds[sortIndex % _generatedSortIds.length];

  String get query => _generatedQueries[queryIndex % _generatedQueries.length];

  Set<String> get selectedStatuses =>
      _selectByMask(_generatedStatusIds, statusMask);

  Set<String> get selectedCategories =>
      _selectByMask(_generatedCategoryIds, categoryMask);

  Set<String> get selectedLabels =>
      _selectByMask(_generatedLabelIds, labelMask);

  Set<String> get selectedPriorities =>
      _selectByMask(_generatedPriorityIds, priorityMask);

  String selectedTaskId(TaskListData data) {
    if (selectedTaskIndex >= data.tasks.length) return 'missing-task';
    return data.tasks[selectedTaskIndex].task.meta.id;
  }

  @override
  String toString() {
    return '_GeneratedTaskListScenario('
        'statuses: $selectedStatuses, '
        'categories: $selectedCategories, '
        'labels: $selectedLabels, '
        'priorities: $selectedPriorities, '
        'sortId: $sortId, '
        'query: $query, '
        'selectedTaskIndex: $selectedTaskIndex)';
  }
}

extension _AnyTaskListScenario on Any {
  Generator<_GeneratedTaskListScenario> get taskListScenario => combine7(
    intInRange(0, 1 << _generatedStatusIds.length),
    intInRange(0, 1 << _generatedCategoryIds.length),
    intInRange(0, 1 << _generatedLabelIds.length),
    intInRange(0, 1 << _generatedPriorityIds.length),
    intInRange(0, _generatedSortIds.length),
    intInRange(0, _generatedQueries.length),
    intInRange(0, 14),
    (
      int statusMask,
      int categoryMask,
      int labelMask,
      int priorityMask,
      int sortIndex,
      int queryIndex,
      int selectedTaskIndex,
    ) => _GeneratedTaskListScenario(
      statusMask: statusMask,
      categoryMask: categoryMask,
      labelMask: labelMask,
      priorityMask: priorityMask,
      sortIndex: sortIndex,
      queryIndex: queryIndex,
      selectedTaskIndex: selectedTaskIndex,
    ),
  );
}

Set<String> _selectByMask(List<String> values, int mask) {
  return {
    for (final (index, value) in values.indexed)
      if ((mask & (1 << index)) != 0) value,
  };
}

DesignSystemTaskFilterState _filterStateFor(
  _GeneratedTaskListScenario scenario,
) {
  final base = buildTaskShowcaseFilterState();
  return base.copyWith(
    selectedSortId: scenario.sortId,
    selectedPriorityIds: scenario.selectedPriorities,
    statusField: base.statusField?.copyWith(
      selectedIds: scenario.selectedStatuses,
    ),
    categoryField: base.categoryField?.copyWith(
      selectedIds: scenario.selectedCategories,
    ),
    labelField: base.labelField?.copyWith(selectedIds: scenario.selectedLabels),
  );
}

List<TaskRecord> _expectedVisibleTasks(
  TaskListData data,
  _GeneratedTaskListScenario scenario,
) {
  final query = scenario.query.trim().toLowerCase();
  final visible =
      data.tasks.where((record) {
          final matchesQuery =
              query.isEmpty ||
              record.task.data.title.toLowerCase().contains(query) ||
              record.category.name.toLowerCase().contains(query) ||
              record.projectTitle.toLowerCase().contains(query) ||
              record.labels.any(
                (label) => label.label.toLowerCase().contains(query),
              );

          final matchesStatus =
              scenario.selectedStatuses.isEmpty ||
              scenario.selectedStatuses.contains(
                _statusFilterId(record.task.data.status),
              );

          final matchesCategory =
              scenario.selectedCategories.isEmpty ||
              scenario.selectedCategories.contains(record.category.id);

          final matchesLabels =
              scenario.selectedLabels.isEmpty ||
              record.labels.any(
                (label) => scenario.selectedLabels.contains(label.id),
              );

          final matchesPriority =
              scenario.selectedPriorities.isEmpty ||
              scenario.selectedPriorities.contains(
                _priorityFilterId(record.task.data.priority),
              );

          return matchesQuery &&
              matchesStatus &&
              matchesCategory &&
              matchesLabels &&
              matchesPriority;
        }).toList()
        ..sort((left, right) => _compareExpectedTasks(left, right, scenario));

  return visible;
}

int _compareExpectedTasks(
  TaskRecord left,
  TaskRecord right,
  _GeneratedTaskListScenario scenario,
) {
  final sectionCompare = right.sectionDate.compareTo(left.sectionDate);
  if (sectionCompare != 0) return sectionCompare;

  if (scenario.sortId == TaskSortIds.prioritySort) {
    final priorityCompare = left.task.data.priority.rank.compareTo(
      right.task.data.priority.rank,
    );
    if (priorityCompare != 0) return priorityCompare;
  } else if (scenario.sortId == TaskSortIds.createdDateSort) {
    final createdCompare = right.task.meta.createdAt.compareTo(
      left.task.meta.createdAt,
    );
    if (createdCompare != 0) return createdCompare;
  } else {
    final leftDue = left.task.data.due;
    final rightDue = right.task.data.due;
    if (leftDue != null && rightDue != null) {
      final dueCompare = leftDue.compareTo(rightDue);
      if (dueCompare != 0) return dueCompare;
    } else if (leftDue != null || rightDue != null) {
      return leftDue == null ? 1 : -1;
    }
  }

  return left.task.data.title.compareTo(right.task.data.title);
}

String _statusFilterId(TaskStatus status) {
  return switch (status) {
    TaskOpen() => TaskStatusFilterIds.open,
    TaskInProgress() => TaskStatusFilterIds.inProgress,
    TaskGroomed() => TaskStatusFilterIds.groomed,
    TaskBlocked() => TaskStatusFilterIds.blocked,
    TaskOnHold() => TaskStatusFilterIds.onHold,
    TaskDone() => TaskStatusFilterIds.done,
    TaskRejected() => TaskStatusFilterIds.rejected,
  };
}

String _priorityFilterId(TaskPriority priority) {
  return switch (priority) {
    TaskPriority.p0Urgent => TaskPriorityFilterIds.p0,
    TaskPriority.p1High => TaskPriorityFilterIds.p1,
    TaskPriority.p2Medium => TaskPriorityFilterIds.p2,
    TaskPriority.p3Low => TaskPriorityFilterIds.p3,
  };
}

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

    Glados(any.taskListScenario, ExploreConfig(numRuns: 180)).test(
      'matches the generated task filtering and sorting model',
      (scenario) {
        final data = buildTaskListDetailMockData();
        final state = TaskListDetailState(
          data: data,
          searchQuery: scenario.query,
          selectedTaskId: scenario.selectedTaskId(data),
          filterState: _filterStateFor(scenario),
        );
        final expected = _expectedVisibleTasks(data, scenario);

        expect(
          state.visibleTasks.map((record) => record.task.meta.id),
          expected.map((record) => record.task.meta.id),
          reason: 'visibleTasks should match the model for $scenario',
        );

        expect(
          state.visibleSections.expand((section) => section.tasks),
          state.visibleTasks,
          reason: 'visibleSections should flatten back to visibleTasks',
        );

        for (var i = 0; i < state.visibleSections.length - 1; i++) {
          expect(
            state.visibleSections[i].sectionDate.compareTo(
              state.visibleSections[i + 1].sectionDate,
            ),
            greaterThanOrEqualTo(0),
          );
        }

        final selectedTaskId = scenario.selectedTaskId(data);
        final expectedSelected =
            expected
                .where((record) => record.task.meta.id == selectedTaskId)
                .firstOrNull ??
            expected.firstOrNull;
        expect(state.selectedTask, expectedSelected);
      },
      tags: 'glados',
    );
  });
}
