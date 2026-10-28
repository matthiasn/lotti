import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_page_state.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_activator.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_provider.dart';
import 'package:lotti/features/tasks/state/task_due_day_provider.dart';
import 'package:lotti/features/tasks/ui/utils.dart';

/// How many open tasks each smart view would show right now.
class TaskDueViewCounts {
  const TaskDueViewCounts({required this.overdue, required this.dueToday});

  final int overdue;
  final int dueToday;

  /// The count for one smart [view]; [TaskDueFilter.all] is not a view.
  int of(TaskDueFilter view) => switch (view) {
    TaskDueFilter.overdue => overdue,
    TaskDueFilter.dueToday => dueToday,
    TaskDueFilter.all => throw ArgumentError.value(view, 'view', 'not a view'),
  };
}

/// Live counts for the "Overdue" and "Due today" smart views.
///
/// Each count is the live filter with its due clause swapped for that view's
/// — precisely what tapping the view would list, so the number on the pill
/// and the rows below it never disagree. The other view stays countable while
/// one is active, since switching between them keeps every other clause.
///
/// Mirrors the live list's empty-status expansion (see
/// `currentTasksFilterCountProvider`), recomputes on task notifications, and
/// recomputes at local midnight, when due-today tasks turn overdue.
final FutureProvider<TaskDueViewCounts> taskDueViewCountsProvider =
    FutureProvider.autoDispose<TaskDueViewCounts>(
      taskDueViewCounts,
      name: 'taskDueViewCountsProvider',
    );
Future<TaskDueViewCounts> taskDueViewCounts(Ref ref) async {
  final pageState = ref.watch(journalPageControllerProvider(true));
  ref.watch(taskDueDayProvider);
  final live = liveTasksFilterFor(pageState);
  final effective = live.selectedTaskStatuses.isEmpty
      ? live.copyWith(selectedTaskStatuses: {...allTaskStatuses})
      : live;

  invalidateOnTaskNotifications(ref);

  final repo = ref.watch(savedTaskFilterCountRepositoryProvider);
  final counts = await Future.wait([
    repo.count(effective.copyWith(dueFilter: TaskDueFilter.overdue)),
    repo.count(effective.copyWith(dueFilter: TaskDueFilter.dueToday)),
  ]);
  return TaskDueViewCounts(overdue: counts[0], dueToday: counts[1]);
}
