import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_models.dart';

class TaskListDetailState {
  TaskListDetailState({
    required this.data,
    required this.searchQuery,
    required this.selectedTaskId,
    required this.filterState,
  });

  final TaskListData data;
  final String searchQuery;
  final String selectedTaskId;
  final DesignSystemTaskFilterState filterState;

  late final List<TaskRecord> visibleTasks = _computeVisibleTasks();

  late final TaskRecord? selectedTask =
      visibleTasks
          .where((task) => task.task.meta.id == selectedTaskId)
          .firstOrNull ??
      visibleTasks.firstOrNull;

  late final List<TaskListSection> visibleSections = _computeVisibleSections();

  List<TaskRecord> _computeVisibleTasks() {
    final query = searchQuery.trim().toLowerCase();
    final selectedStatuses = filterState.statusField.selectedIds;
    final selectedCategories = filterState.categoryField.selectedIds;
    final selectedLabels = filterState.labelField.selectedIds;
    final selectedPriorityId = filterState.selectedPriorityId;

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
              selectedStatuses.isEmpty ||
              selectedStatuses.contains(
                _statusFilterId(record.task.data.status),
              );

          final matchesCategory =
              selectedCategories.isEmpty ||
              selectedCategories.contains(record.category.id);

          final matchesLabels =
              selectedLabels.isEmpty ||
              record.labels.any((label) => selectedLabels.contains(label.id));

          final matchesPriority =
              selectedPriorityId == DesignSystemTaskFilterState.allPriorityId ||
              selectedPriorityId ==
                  _priorityFilterId(record.task.data.priority);

          return matchesQuery &&
              matchesStatus &&
              matchesCategory &&
              matchesLabels &&
              matchesPriority;
        }).toList()..sort((left, right) {
          final sectionCompare = right.sectionDate.compareTo(left.sectionDate);
          if (sectionCompare != 0) {
            return sectionCompare;
          }

          final sortId = filterState.selectedSortId;
          if (sortId == 'priority') {
            final priorityCompare = left.task.data.priority.rank.compareTo(
              right.task.data.priority.rank,
            );
            if (priorityCompare != 0) {
              return priorityCompare;
            }
          } else if (sortId == 'created-date') {
            final createdCompare = right.task.meta.createdAt.compareTo(
              left.task.meta.createdAt,
            );
            if (createdCompare != 0) {
              return createdCompare;
            }
          } else {
            final leftDue = left.task.data.due;
            final rightDue = right.task.data.due;
            if (leftDue != null && rightDue != null) {
              final dueCompare = leftDue.compareTo(rightDue);
              if (dueCompare != 0) {
                return dueCompare;
              }
            } else if (leftDue != null || rightDue != null) {
              return leftDue == null ? 1 : -1;
            }
          }

          return left.task.data.title.compareTo(right.task.data.title);
        });

    return visible;
  }

  List<TaskListSection> _computeVisibleSections() {
    final sections = <String, List<TaskRecord>>{};

    for (final record in visibleTasks) {
      (sections[record.sectionTitle] ??= []).add(record);
    }

    final grouped =
        sections.entries
            .map(
              (entry) => TaskListSection(
                title: entry.key,
                sectionDate: entry.value.first.sectionDate,
                tasks: entry.value,
              ),
            )
            .toList()
          ..sort(
            (left, right) => right.sectionDate.compareTo(left.sectionDate),
          );
    return grouped;
  }

  TaskListDetailState copyWith({
    TaskListData? data,
    String? searchQuery,
    String? selectedTaskId,
    DesignSystemTaskFilterState? filterState,
  }) {
    return TaskListDetailState(
      data: data ?? this.data,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTaskId: selectedTaskId ?? this.selectedTaskId,
      filterState: filterState ?? this.filterState,
    );
  }
}

String _statusFilterId(TaskStatus status) {
  return switch (status) {
    TaskOpen() => 'open',
    TaskInProgress() => 'in-progress',
    TaskGroomed() => 'groomed',
    TaskBlocked() => 'blocked',
    TaskOnHold() => 'on-hold',
    TaskDone() => 'done',
    TaskRejected() => 'rejected',
  };
}

String _priorityFilterId(TaskPriority priority) {
  return switch (priority) {
    TaskPriority.p0Urgent => 'p0',
    TaskPriority.p1High => 'p1',
    TaskPriority.p2Medium => 'p2',
    TaskPriority.p3Low => 'p3',
  };
}
