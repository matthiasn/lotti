import 'package:flutter/foundation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/model/project_task_list_options.dart';

/// The due-date buckets the project task list can group by.
enum ProjectDueWindow { overdue, thisWeek, later, none }

/// What a group of project tasks is keyed on. The key names the group's
/// header and is stable across rebuilds, so a collapsed group stays
/// collapsed while its tasks change underneath it.
sealed class ProjectTaskGroupKey {
  const ProjectTaskGroupKey();

  /// A string stable enough to remember collapse state by.
  String get id;
}

/// One calendar month of task creation.
@immutable
final class ProjectTaskMonthKey extends ProjectTaskGroupKey {
  const ProjectTaskMonthKey(this.year, this.month);

  final int year;
  final int month;

  DateTime get firstDay => DateTime(year, month);

  @override
  String get id => 'month:$year-$month';

  @override
  bool operator ==(Object other) =>
      other is ProjectTaskMonthKey &&
      other.year == year &&
      other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

/// Tasks sharing one status; [status] is a representative for labelling.
@immutable
final class ProjectTaskStatusKey extends ProjectTaskGroupKey {
  const ProjectTaskStatusKey(this.status);

  final TaskStatus status;

  @override
  String get id => 'status:${taskStatusRank(status)}';

  @override
  bool operator ==(Object other) =>
      other is ProjectTaskStatusKey &&
      taskStatusRank(other.status) == taskStatusRank(status);

  @override
  int get hashCode => taskStatusRank(status);
}

@immutable
final class ProjectTaskPriorityKey extends ProjectTaskGroupKey {
  const ProjectTaskPriorityKey(this.priority);

  final TaskPriority priority;

  @override
  String get id => 'priority:${priority.name}';

  @override
  bool operator ==(Object other) =>
      other is ProjectTaskPriorityKey && other.priority == priority;

  @override
  int get hashCode => priority.hashCode;
}

@immutable
final class ProjectTaskDueWindowKey extends ProjectTaskGroupKey {
  const ProjectTaskDueWindowKey(this.window);

  final ProjectDueWindow window;

  @override
  String get id => 'due:${window.name}';

  @override
  bool operator ==(Object other) =>
      other is ProjectTaskDueWindowKey && other.window == window;

  @override
  int get hashCode => window.hashCode;
}

/// The single, header-less group of an ungrouped list.
@immutable
final class ProjectTaskAllKey extends ProjectTaskGroupKey {
  const ProjectTaskAllKey();

  @override
  String get id => 'all';

  @override
  bool operator ==(Object other) => other is ProjectTaskAllKey;

  @override
  int get hashCode => id.hashCode;
}

/// The trailing group finished tasks fold into while they are kept out of
/// their own groups.
@immutable
final class ProjectTaskDoneKey extends ProjectTaskGroupKey {
  const ProjectTaskDoneKey();

  @override
  String get id => 'done';

  @override
  bool operator ==(Object other) => other is ProjectTaskDoneKey;

  @override
  int get hashCode => id.hashCode;
}

class ProjectTaskGroup {
  const ProjectTaskGroup({required this.key, required this.tasks});

  final ProjectTaskGroupKey key;
  final List<TaskSummary> tasks;

  Duration get totalDuration => tasks.fold(
    Duration.zero,
    (sum, summary) => sum + summary.estimatedDuration,
  );

  /// The ungrouped list renders its rows without a header.
  bool get hasHeader => key is! ProjectTaskAllKey;
}

/// Actionability order of task statuses — what needs a person first.
int taskStatusRank(TaskStatus status) => switch (status) {
  TaskBlocked() => 0,
  TaskOnHold() => 1,
  TaskInProgress() => 2,
  TaskOpen() => 3,
  TaskGroomed() => 4,
  TaskDone() => 5,
  TaskRejected() => 6,
};

/// The default order of a project's tasks: status rank, then due date
/// (undated last), then the larger estimate, then title.
int compareTasksByActionability(Task left, Task right) {
  final statusOrder = taskStatusRank(
    left.data.status,
  ).compareTo(taskStatusRank(right.data.status));
  if (statusOrder != 0) return statusOrder;

  final dueOrder = _compareNullableDates(left.data.due, right.data.due);
  if (dueOrder != 0) return dueOrder;

  final leftEstimate = left.data.estimate ?? Duration.zero;
  final rightEstimate = right.data.estimate ?? Duration.zero;
  final estimateOrder = rightEstimate.compareTo(leftEstimate);
  if (estimateOrder != 0) return estimateOrder;

  return left.data.title.toLowerCase().compareTo(
    right.data.title.toLowerCase(),
  );
}

/// Ascending, with a missing date sorting last.
int _compareNullableDates(DateTime? left, DateTime? right) {
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  return left.compareTo(right);
}

/// Orders two summaries by [sortBy]; ties break on title, then id, so the
/// result never depends on input order.
int compareProjectTaskSummaries(
  TaskSummary a,
  TaskSummary b,
  ProjectTaskSortBy sortBy,
) {
  final order = switch (sortBy) {
    ProjectTaskSortBy.actionability => compareTasksByActionability(
      a.task,
      b.task,
    ),
    ProjectTaskSortBy.created => b.task.meta.createdAt.compareTo(
      a.task.meta.createdAt,
    ),
    ProjectTaskSortBy.dueDate => _compareNullableDates(
      a.task.data.due,
      b.task.data.due,
    ),
    ProjectTaskSortBy.estimate => b.estimatedDuration.compareTo(
      a.estimatedDuration,
    ),
    ProjectTaskSortBy.priority => a.task.data.priority.rank.compareTo(
      b.task.data.priority.rank,
    ),
    ProjectTaskSortBy.recentlyUpdated => b.task.meta.updatedAt.compareTo(
      a.task.meta.updatedAt,
    ),
    ProjectTaskSortBy.title => a.task.data.title.toLowerCase().compareTo(
      b.task.data.title.toLowerCase(),
    ),
  };
  if (order != 0) return order;
  final title = a.task.data.title.toLowerCase().compareTo(
    b.task.data.title.toLowerCase(),
  );
  return title != 0 ? title : a.task.meta.id.compareTo(b.task.meta.id);
}

/// The due-date bucket of [due] relative to [now]: before today is overdue,
/// within the next seven days is this week, anything after is later.
ProjectDueWindow projectDueWindow(DateTime? due, DateTime now) {
  if (due == null) return ProjectDueWindow.none;
  final today = DateTime(now.year, now.month, now.day);
  if (due.isBefore(today)) return ProjectDueWindow.overdue;
  if (due.isBefore(today.add(const Duration(days: 7)))) {
    return ProjectDueWindow.thisWeek;
  }
  return ProjectDueWindow.later;
}

/// Done and rejected are both terminal for the task subsystem, so both fold.
bool _isClosed(TaskSummary summary) => switch (summary.task.data.status) {
  TaskDone() || TaskRejected() => true,
  _ => false,
};

/// Groups and orders a project's tasks the way [options] asks, relative to
/// [now] for due windows.
///
/// Groups come back in display order — newest month first, statuses by
/// actionability, priorities highest first, due windows overdue first — and
/// empty groups are omitted. With `keepDoneInGroups` off, finished tasks —
/// done or rejected — leave their groups for one trailing [ProjectTaskDoneKey]
/// group; with it on they sort among their peers. Grouping by nothing yields a
/// single header-less group.
List<ProjectTaskGroup> groupProjectTasks(
  List<TaskSummary> summaries, {
  required ProjectTaskListOptions options,
  required DateTime now,
}) {
  final grouped = <ProjectTaskGroupKey, List<TaskSummary>>{};
  final done = <TaskSummary>[];
  for (final summary in summaries) {
    if (!options.keepDoneInGroups && _isClosed(summary)) {
      done.add(summary);
      continue;
    }
    final key = switch (options.groupBy) {
      ProjectTaskGroupBy.creationMonth => ProjectTaskMonthKey(
        summary.task.meta.createdAt.year,
        summary.task.meta.createdAt.month,
      ),
      ProjectTaskGroupBy.status => ProjectTaskStatusKey(
        summary.task.data.status,
      ),
      ProjectTaskGroupBy.priority => ProjectTaskPriorityKey(
        summary.task.data.priority,
      ),
      ProjectTaskGroupBy.dueWindow => ProjectTaskDueWindowKey(
        projectDueWindow(summary.task.data.due, now),
      ),
      ProjectTaskGroupBy.none => const ProjectTaskAllKey(),
    };
    grouped.putIfAbsent(key, () => []).add(summary);
  }

  int compare(TaskSummary a, TaskSummary b) =>
      compareProjectTaskSummaries(a, b, options.sortBy);
  final groups = [
    for (final entry in grouped.entries)
      ProjectTaskGroup(key: entry.key, tasks: entry.value..sort(compare)),
  ]..sort((a, b) => _compareGroupKeys(a.key, b.key));
  if (done.isNotEmpty) {
    groups.add(
      ProjectTaskGroup(
        key: const ProjectTaskDoneKey(),
        tasks: done..sort(compare),
      ),
    );
  }
  return groups;
}

int _compareGroupKeys(ProjectTaskGroupKey a, ProjectTaskGroupKey b) =>
    switch ((a, b)) {
      (
        ProjectTaskMonthKey(firstDay: final left),
        ProjectTaskMonthKey(firstDay: final right),
      ) =>
        right.compareTo(left),
      (
        ProjectTaskStatusKey(status: final left),
        ProjectTaskStatusKey(status: final right),
      ) =>
        taskStatusRank(left).compareTo(taskStatusRank(right)),
      (
        ProjectTaskPriorityKey(priority: final left),
        ProjectTaskPriorityKey(priority: final right),
      ) =>
        left.rank.compareTo(right.rank),
      (
        ProjectTaskDueWindowKey(window: final left),
        ProjectTaskDueWindowKey(window: final right),
      ) =>
        left.index.compareTo(right.index),
      _ => 0,
    };
