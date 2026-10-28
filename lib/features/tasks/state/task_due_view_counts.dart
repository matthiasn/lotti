import 'package:lotti/classes/journal_page_state.dart';

/// How many open tasks each smart view would show right now.
class TaskDueViewCounts {
  const TaskDueViewCounts({required this.overdue, required this.dueToday});

  static const TaskDueViewCounts zero = TaskDueViewCounts(
    overdue: 0,
    dueToday: 0,
  );

  final int overdue;
  final int dueToday;

  /// The count for one smart [view]; [TaskDueFilter.all] is not a view.
  int of(TaskDueFilter view) => switch (view) {
    TaskDueFilter.overdue => overdue,
    TaskDueFilter.dueToday => dueToday,
    TaskDueFilter.all => throw ArgumentError.value(view, 'view', 'not a view'),
  };
}
