import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_models.dart';

/// Sort option IDs used in [DesignSystemTaskFilterState.selectedSortId].
abstract final class TaskSortIds {
  static const dueDateSort = 'due-date';
  static const createdDateSort = 'created-date';
  static const prioritySort = 'priority';
}

/// Status filter IDs used in [DesignSystemTaskFilterFieldState.selectedIds].
abstract final class TaskStatusFilterIds {
  static const open = 'open';
  static const inProgress = 'in-progress';
  static const groomed = 'groomed';
  static const blocked = 'blocked';
  static const onHold = 'on-hold';
  static const done = 'done';
  static const rejected = 'rejected';
}

/// Priority filter IDs used in [DesignSystemTaskFilterState.selectedPriorityId].
abstract final class TaskPriorityFilterIds {
  static const p0 = 'p0';
  static const p1 = 'p1';
  static const p2 = 'p2';
  static const p3 = 'p3';
}

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
    final selectedStatuses = filterState.statusField?.selectedIds ?? const {};
    final selectedCategories =
        filterState.categoryField?.selectedIds ?? const {};
    final selectedLabels = filterState.labelField?.selectedIds ?? const {};
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
          if (sortId == TaskSortIds.prioritySort) {
            final priorityCompare = left.task.data.priority.rank.compareTo(
              right.task.data.priority.rank,
            );
            if (priorityCompare != 0) {
              return priorityCompare;
            }
          } else if (sortId == TaskSortIds.createdDateSort) {
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
