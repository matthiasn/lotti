import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/utils/date_utils_extension.dart';

/// The category of a section header in the browsable task list. Which kind a
/// task falls into is determined by the active [TaskSortOption]: created-date
/// buckets, due-date buckets (today/tomorrow/yesterday/dated/none), or
/// priority buckets.
enum TaskBrowseSectionKind {
  createdDate,
  dueDate,
  dueToday,
  dueTomorrow,
  dueYesterday,
  noDueDate,
  priority,
}

/// Identifies the section a task belongs to and produces a [stableKey] used to
/// detect section boundaries and aggregate counts.
///
/// Constructed via the named factories (one per [TaskBrowseSectionKind]); the
/// [date]/[priority] payload depends on the kind. Day-based keys are normalized
/// to midnight so two tasks on the same calendar day share one section.
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

/// A task paired with its rendering context in the browse list: which section
/// it belongs to, whether a section header should precede it, and where it
/// sits within the section (first/last, total count when known). The list
/// builder uses these flags to draw grouped cards and section headers without
/// re-deriving boundaries in the widget tree.
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

/// Turns a flat, already-sorted [items] list into [TaskBrowseEntry]s annotated
/// with section boundaries and per-section counts for [sortOption].
///
/// Non-task entities are dropped. Section headers are emitted at each boundary;
/// the count is suppressed for the trailing section when [hasNextPage] is true,
/// since that section may be incomplete and a wrong count would be misleading.
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
  // Use UTC to avoid DST boundary issues where local midnight differences
  // can be 23 or 25 hours instead of 24.
  final dayOffset = DateTime.utc(
    normalizedDueDate.year,
    normalizedDueDate.month,
    normalizedDueDate.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;

  return switch (dayOffset) {
    0 => const TaskBrowseSectionKey.dueToday(),
    1 => const TaskBrowseSectionKey.dueTomorrow(),
    -1 => const TaskBrowseSectionKey.dueYesterday(),
    _ => TaskBrowseSectionKey.dueDate(normalizedDueDate),
  };
}
