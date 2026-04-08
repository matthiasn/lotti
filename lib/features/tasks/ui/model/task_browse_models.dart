import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/utils/date_utils_extension.dart';

enum TaskBrowseSectionKind {
  createdDate,
  dueDate,
  dueToday,
  dueTomorrow,
  dueYesterday,
  noDueDate,
  priority,
}

class TaskBrowseSectionKey {
  const TaskBrowseSectionKey._({
    required this.kind,
    this.date,
    this.priority,
  });

  TaskBrowseSectionKey.createdDate(DateTime date)
    : this._(
        kind: TaskBrowseSectionKind.createdDate,
        date: DateTime(date.year, date.month, date.day),
      );

  TaskBrowseSectionKey.dueDate(DateTime date)
    : this._(
        kind: TaskBrowseSectionKind.dueDate,
        date: DateTime(date.year, date.month, date.day),
      );

  const TaskBrowseSectionKey.dueToday()
    : this._(kind: TaskBrowseSectionKind.dueToday);

  const TaskBrowseSectionKey.dueTomorrow()
    : this._(kind: TaskBrowseSectionKind.dueTomorrow);

  const TaskBrowseSectionKey.dueYesterday()
    : this._(kind: TaskBrowseSectionKind.dueYesterday);

  const TaskBrowseSectionKey.noDueDate()
    : this._(kind: TaskBrowseSectionKind.noDueDate);

  const TaskBrowseSectionKey.priority(TaskPriority priority)
    : this._(
        kind: TaskBrowseSectionKind.priority,
        priority: priority,
      );

  final TaskBrowseSectionKind kind;
  final DateTime? date;
  final TaskPriority? priority;

  String get stableKey => switch (kind) {
    TaskBrowseSectionKind.createdDate => 'created:${date!.ymd}',
    TaskBrowseSectionKind.dueDate => 'due:${date!.ymd}',
    TaskBrowseSectionKind.dueToday => 'due:today',
    TaskBrowseSectionKind.dueTomorrow => 'due:tomorrow',
    TaskBrowseSectionKind.dueYesterday => 'due:yesterday',
    TaskBrowseSectionKind.noDueDate => 'due:none',
    TaskBrowseSectionKind.priority => 'priority:${priority!.short}',
  };
}

class TaskBrowseEntry {
  const TaskBrowseEntry({
    required this.task,
    required this.sectionKey,
    required this.showSectionHeader,
    required this.isFirstInSection,
    required this.isLastInSection,
    this.sectionCount,
  });

  final Task task;
  final TaskBrowseSectionKey sectionKey;
  final bool showSectionHeader;
  final bool isFirstInSection;
  final bool isLastInSection;
  final int? sectionCount;
}

List<TaskBrowseEntry> buildTaskBrowseEntries({
  required List<JournalEntity> items,
  required TaskSortOption sortOption,
  required DateTime now,
  required bool hasNextPage,
}) {
  final tasks = items.whereType<Task>().toList(growable: false);
  if (tasks.isEmpty) {
    return const <TaskBrowseEntry>[];
  }

  final sectionKeys = tasks
      .map((task) => _sectionKeyForTask(task, sortOption: sortOption, now: now))
      .toList(growable: false);
  final counts = <String, int>{};
  for (final sectionKey in sectionKeys) {
    counts.update(
      sectionKey.stableKey,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
  }

  final lastVisibleSectionKey = sectionKeys.last.stableKey;

  return List<TaskBrowseEntry>.generate(tasks.length, (index) {
    final sectionKey = sectionKeys[index];
    final previousSectionKey = index > 0
        ? sectionKeys[index - 1].stableKey
        : null;
    final nextSectionKey = index < tasks.length - 1
        ? sectionKeys[index + 1].stableKey
        : null;
    final isFirstInSection = previousSectionKey != sectionKey.stableKey;
    final isLastInSection = nextSectionKey != sectionKey.stableKey;
    final showSectionHeader = isFirstInSection;
    final isPartialTrailingSection =
        hasNextPage && sectionKey.stableKey == lastVisibleSectionKey;

    return TaskBrowseEntry(
      task: tasks[index],
      sectionKey: sectionKey,
      showSectionHeader: showSectionHeader,
      isFirstInSection: isFirstInSection,
      isLastInSection: isLastInSection,
      sectionCount: showSectionHeader && !isPartialTrailingSection
          ? counts[sectionKey.stableKey]
          : null,
    );
  }, growable: false);
}

TaskBrowseSectionKey _sectionKeyForTask(
  Task task, {
  required TaskSortOption sortOption,
  required DateTime now,
}) {
  return switch (sortOption) {
    TaskSortOption.byDueDate => _dueSectionKeyForTask(task, now: now),
    TaskSortOption.byDate => TaskBrowseSectionKey.createdDate(
      task.meta.dateFrom,
    ),
    TaskSortOption.byPriority => TaskBrowseSectionKey.priority(
      task.data.priority,
    ),
  };
}

TaskBrowseSectionKey _dueSectionKeyForTask(
  Task task, {
  required DateTime now,
}) {
  final dueDate = task.data.due;
  if (dueDate == null) {
    return const TaskBrowseSectionKey.noDueDate();
  }

  final today = now.dayAtMidnight;
  final normalizedDueDate = dueDate.dayAtMidnight;
  final dayOffset = normalizedDueDate.difference(today).inDays;

  return switch (dayOffset) {
    0 => const TaskBrowseSectionKey.dueToday(),
    1 => const TaskBrowseSectionKey.dueTomorrow(),
    -1 => const TaskBrowseSectionKey.dueYesterday(),
    _ => TaskBrowseSectionKey.dueDate(normalizedDueDate),
  };
}
