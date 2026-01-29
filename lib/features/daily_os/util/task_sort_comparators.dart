import 'package:lotti/classes/task.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';

/// Comparators for sorting [TaskDayProgress] items in the Daily OS view.
///
/// These comparators provide consistent, testable sorting logic that can be
/// used across different parts of the application.
abstract final class TaskSortComparators {
  /// Compares tasks by priority, urgency, then title alphabetically.
  ///
  /// Sort order:
  /// 1. Priority (ascending rank: P0 < P1 < P2 < P3, so P0 comes first)
  /// 2. Urgency (descending index: overdue > dueToday > none)
  /// 3. Title (alphabetical, case-sensitive)
  ///
  /// This comparator is used when time spent is equal or not applicable,
  /// such as for tasks with no tracked time.
  ///
  /// Example usage:
  /// ```dart
  /// taskItems.sort(TaskSortComparators.byPriorityUrgencyTitle);
  /// ```
  static int byPriorityUrgencyTitle(TaskDayProgress a, TaskDayProgress b) {
    // Sort by priority first (lower rank = higher priority)
    final priorityCompare =
        a.task.data.priority.rank.compareTo(b.task.data.priority.rank);
    if (priorityCompare != 0) return priorityCompare;

    // Same priority: sort by urgency (overdue > dueToday > normal)
    final urgencyCompare =
        b.dueDateStatus.urgency.index.compareTo(a.dueDateStatus.urgency.index);
    if (urgencyCompare != 0) return urgencyCompare;

    // Same urgency: alphabetical by title
    return a.task.data.title.compareTo(b.task.data.title);
  }

  /// Compares tasks by time spent (descending), then falls back to
  /// [byPriorityUrgencyTitle] for tasks with equal or zero time.
  ///
  /// Sort order:
  /// 1. Time spent (descending: more time first)
  /// 2. Tasks with time come before tasks without time
  /// 3. For tasks with equal/zero time: priority, urgency, then title
  ///
  /// Example usage:
  /// ```dart
  /// taskItems.sort(TaskSortComparators.byTimeSpentThenPriority);
  /// ```
  static int byTimeSpentThenPriority(TaskDayProgress a, TaskDayProgress b) {
    final aHasTime = a.timeSpentOnDay > Duration.zero;
    final bHasTime = b.timeSpentOnDay > Duration.zero;

    // Both have time: sort by time descending, then fall back to priority
    if (aHasTime && bHasTime) {
      final timeCompare = b.timeSpentOnDay.compareTo(a.timeSpentOnDay);
      if (timeCompare != 0) return timeCompare;
      return byPriorityUrgencyTitle(a, b);
    }

    // One has time, one doesn't: time first
    if (aHasTime) return -1;
    if (bHasTime) return 1;

    // Both zero time: use priority/urgency/title ordering
    return byPriorityUrgencyTitle(a, b);
  }
}
