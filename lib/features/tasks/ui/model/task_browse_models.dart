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
    this.isShowMore = false,
    this.hiddenCount = 0,
  });

  final Task task;
  final TaskBrowseSectionKey sectionKey;
  final bool showSectionHeader;
  final bool isFirstInSection;
  final bool isLastInSection;
  final int? sectionCount;

  /// When true this entry is not a task card but the collapsed-section
  /// "+N more" affordance that sits as the last row of a capped group; it
  /// renders [hiddenCount] and toggles the section open on tap. [task] is the
  /// first hidden task — retained only so the row keys against its paging item.
  final bool isShowMore;

  /// Number of cards hidden below the cap in a collapsed section (the "+N").
  final int hiddenCount;
}

/// Turns a flat, already-ordered [items] list into [TaskBrowseEntry]s annotated
/// with section boundaries and per-section counts for [sortOption].
///
/// Non-task entities are dropped. Section headers are emitted at each boundary;
/// the count is suppressed for the trailing section when [hasNextPage] is true,
/// since that section may be incomplete and a wrong count would be misleading.
///
/// A section the user has not [expandedSections] and that holds more than
/// [collapsedVisibleCount] tasks is *capped*: only the first few cards are
/// emitted, followed by one `isShowMore` entry; the remaining tasks get no
/// entry (their paging items render empty). The trailing partial section is
/// never capped since its true size is still unknown. The caller must feed the
/// list view items in the SAME order as [items] so the capped/skip positions
/// line up with the rendered rows.
List<TaskBrowseEntry> buildTaskBrowseEntries({
  required List<JournalEntity> items,
  required TaskSortOption sortOption,
  required DateTime now,
  required bool hasNextPage,
  Set<String> expandedSections = const <String>{},
  int collapsedVisibleCount = 3,
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

  final entries = <TaskBrowseEntry>[];
  final positionInSection = <String, int>{};
  for (var index = 0; index < tasks.length; index++) {
    final sectionKey = sectionKeys[index];
    final stableKey = sectionKey.stableKey;
    final previousSectionKey = index > 0
        ? sectionKeys[index - 1].stableKey
        : null;
    final nextSectionKey = index < tasks.length - 1
        ? sectionKeys[index + 1].stableKey
        : null;
    final isFirstInSection = previousSectionKey != stableKey;
    final isLastInSectionRaw = nextSectionKey != stableKey;
    final isPartialTrailingSection =
        hasNextPage && stableKey == lastVisibleSectionKey;
    final sectionCount = counts[stableKey]!;

    final position = positionInSection[stableKey] ?? 0;
    positionInSection[stableKey] = position + 1;

    final isCapped =
        !expandedSections.contains(stableKey) &&
        !isPartialTrailingSection &&
        sectionCount > collapsedVisibleCount;

    if (isCapped && position > collapsedVisibleCount) {
      // Hidden below the cap — emit no entry; its paging item renders empty.
      continue;
    }

    if (isCapped && position == collapsedVisibleCount) {
      entries.add(
        TaskBrowseEntry(
          task: tasks[index],
          sectionKey: sectionKey,
          showSectionHeader: false,
          isFirstInSection: false,
          isLastInSection: true,
          isShowMore: true,
          hiddenCount: sectionCount - collapsedVisibleCount,
        ),
      );
      continue;
    }

    entries.add(
      TaskBrowseEntry(
        task: tasks[index],
        sectionKey: sectionKey,
        showSectionHeader: isFirstInSection,
        isFirstInSection: isFirstInSection,
        isLastInSection: !isCapped && isLastInSectionRaw,
        sectionCount: isFirstInSection && !isPartialTrailingSection
            ? sectionCount
            : null,
      ),
    );
  }

  return List<TaskBrowseEntry>.unmodifiable(entries);
}

/// Stable-sorts [tasks] within each priority bucket by due-date urgency
/// (overdue first, then today, then soonest future, then no due date) while
/// preserving the buckets' existing priority order. Ties keep their original
/// order so the reorder is deterministic and minimises reflow. The browse list
/// applies this for priority sort so the visible (and capped) few in a bucket
/// are the most time-critical.
List<Task> sortTasksWithinPriorityBuckets(List<Task> tasks, DateTime now) {
  // Compare calendar days via UTC midnights: the elapsed time between two
  // *local* midnights can be 23h or 25h across a DST transition, which would
  // truncate `inDays` and misorder a due-tomorrow task next to due-today.
  // UTC midnights are always exactly 24h apart, so the day delta is exact.
  final today = DateTime.utc(now.year, now.month, now.day);
  int dueKey(Task task) {
    final due = task.data.due;
    if (due == null) {
      return 1 << 30; // no due date sinks to the bottom of its bucket
    }
    final day = DateTime.utc(due.year, due.month, due.day);
    return day.difference(today).inDays; // overdue < 0, today 0, future > 0
  }

  final bucketOrder = <TaskPriority>[];
  final buckets = <TaskPriority, List<MapEntry<int, Task>>>{};
  for (var i = 0; i < tasks.length; i++) {
    final priority = tasks[i].data.priority;
    buckets
        .putIfAbsent(priority, () {
          bucketOrder.add(priority);
          return <MapEntry<int, Task>>[];
        })
        .add(MapEntry(i, tasks[i]));
  }

  final result = <Task>[];
  for (final priority in bucketOrder) {
    final bucket = buckets[priority]!
      ..sort((a, b) {
        final byDue = dueKey(a.value).compareTo(dueKey(b.value));
        return byDue != 0 ? byDue : a.key.compareTo(b.key);
      });
    result.addAll(bucket.map((e) => e.value));
  }
  return result;
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
