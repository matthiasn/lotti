import 'package:glados/glados.dart' show Any, CombinableAny, Generator, IntAnys;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
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

const hGeneratedCategoryIds = [
  'work',
  'study',
  'leisure',
  'meals',
  'household',
  'meeting',
];

const hGeneratedLabelIds = [
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

const hGeneratedQueries = [
  '',
  'payment',
  'device sync',
  'bug fix',
  'work',
  'meeting',
  'weekly',
  'missing-query',
];

class GeneratedTaskListScenario {
  const GeneratedTaskListScenario({
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

  String get query => hGeneratedQueries[queryIndex % hGeneratedQueries.length];

  Set<String> get selectedStatuses =>
      hSelectByMask(_generatedStatusIds, statusMask);

  Set<String> get selectedCategories =>
      hSelectByMask(hGeneratedCategoryIds, categoryMask);

  Set<String> get selectedLabels =>
      hSelectByMask(hGeneratedLabelIds, labelMask);

  Set<String> get selectedPriorities =>
      hSelectByMask(_generatedPriorityIds, priorityMask);

  String selectedTaskId(TaskListData data) {
    if (selectedTaskIndex >= data.tasks.length) return 'missing-task';
    return data.tasks[selectedTaskIndex].task.meta.id;
  }

  @override
  String toString() {
    return 'GeneratedTaskListScenario('
        'statuses: $selectedStatuses, '
        'categories: $selectedCategories, '
        'labels: $selectedLabels, '
        'priorities: $selectedPriorities, '
        'sortId: $sortId, '
        'query: $query, '
        'selectedTaskIndex: $selectedTaskIndex)';
  }
}

extension AnyTaskListScenario on Any {
  Generator<GeneratedTaskListScenario> get taskListScenario => combine7(
    intInRange(0, 1 << _generatedStatusIds.length),
    intInRange(0, 1 << hGeneratedCategoryIds.length),
    intInRange(0, 1 << hGeneratedLabelIds.length),
    intInRange(0, 1 << _generatedPriorityIds.length),
    intInRange(0, _generatedSortIds.length),
    intInRange(0, hGeneratedQueries.length),
    intInRange(0, 14),
    (
      int statusMask,
      int categoryMask,
      int labelMask,
      int priorityMask,
      int sortIndex,
      int queryIndex,
      int selectedTaskIndex,
    ) => GeneratedTaskListScenario(
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

Set<String> hSelectByMask(List<String> values, int mask) {
  return {
    for (final (index, value) in values.indexed)
      if ((mask & (1 << index)) != 0) value,
  };
}

DesignSystemTaskFilterState hFilterStateFor(
  GeneratedTaskListScenario scenario,
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

List<TaskRecord> hExpectedVisibleTasks(
  TaskListData data,
  GeneratedTaskListScenario scenario,
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
                hStatusFilterId(record.task.data.status),
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
                hPriorityFilterId(record.task.data.priority),
              );

          return matchesQuery &&
              matchesStatus &&
              matchesCategory &&
              matchesLabels &&
              matchesPriority;
        }).toList()
        ..sort((left, right) => hCompareExpectedTasks(left, right, scenario));

  return visible;
}

int hCompareExpectedTasks(
  TaskRecord left,
  TaskRecord right,
  GeneratedTaskListScenario scenario,
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

String hStatusFilterId(TaskStatus status) {
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

String hPriorityFilterId(TaskPriority priority) {
  return switch (priority) {
    TaskPriority.p0Urgent => TaskPriorityFilterIds.p0,
    TaskPriority.p1High => TaskPriorityFilterIds.p1,
    TaskPriority.p2Medium => TaskPriorityFilterIds.p2,
    TaskPriority.p3Low => TaskPriorityFilterIds.p3,
  };
}

/// Builds a minimal [TaskRecord] with directly controllable comparator inputs.
///
/// Used by the deterministic sorting/status tests below to force specific
/// branches in `TaskListDetailState._computeVisibleTasks` and `hStatusFilterId`
/// that the showcase mock data does not exercise.
TaskRecord hRecord({
  required String id,
  required String title,
  required DateTime sectionDate,
  required DateTime createdAt,
  required TaskStatus status,
  DateTime? due,
  TaskPriority priority = TaskPriority.p2Medium,
}) {
  final task =
      JournalEntity.task(
            meta: Metadata(
              id: id,
              createdAt: createdAt,
              updatedAt: createdAt,
              dateFrom: createdAt,
              dateTo: createdAt,
              categoryId: 'work',
            ),
            data: TaskData(
              status: status,
              statusHistory: const [],
              title: title,
              dateFrom: createdAt,
              dateTo: createdAt,
              due: due,
              priority: priority,
            ),
          )
          as Task;

  return TaskRecord(
    task: task,
    category:
        EntityDefinition.categoryDefinition(
              id: 'work',
              createdAt: createdAt,
              updatedAt: createdAt,
              name: 'Work',
              vectorClock: null,
              private: false,
              active: true,
            )
            as CategoryDefinition,
    sectionTitle: 'Section ${sectionDate.toIso8601String()}',
    sectionDate: sectionDate,
    projectTitle: 'Project',
    timeRange: '',
    labels: const [],
    aiSummary: '',
    description: '',
    trackedDurationLabel: '',
    trackerEntries: const [],
    checklistItems: const [],
    audioEntries: const [],
  );
}

TaskStatus hOpen(DateTime createdAt) =>
    TaskStatus.open(id: 'open-$createdAt', createdAt: createdAt, utcOffset: 0);

TaskListData hDataWith(List<TaskRecord> tasks) => TaskListData(
  categories: const [],
  tasks: tasks,
  currentTime: DateTime(2026, 4),
);

TaskListDetailState hStateWith(
  List<TaskRecord> tasks, {
  required String sortId,
}) {
  return TaskListDetailState(
    data: hDataWith(tasks),
    searchQuery: '',
    selectedTaskId: '',
    filterState: buildTaskShowcaseFilterState().copyWith(
      selectedSortId: sortId,
    ),
  );
}
