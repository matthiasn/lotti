import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/github/pull_request_ref.dart';
import 'package:lotti/classes/journal_page_state.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_query_runner.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_activator.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_provider.dart';
import 'package:lotti/features/tasks/state/task_due_day_provider.dart';
import 'package:lotti/features/tasks/state/task_due_view_counts.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/providers/service_providers.dart';

/// Live counts for the "Overdue" and "Due today" smart views.
///
/// Each count is the live filter with its due clause swapped for that view's
/// — precisely what tapping the view would list, so the number on the pill
/// and the rows below it never disagree. The other view stays countable while
/// one is active, since switching between them keeps every other clause.
///
/// An active search narrows the counts the way it narrows the list: to the
/// tasks a pasted pull request link is linked to, the full-text matches, or
/// in semantic mode the vector result set, so a pill never counts tasks that
/// tapping it would not show.
///
/// Both views come from one `dueViewCounts` call — one due-window read and
/// one id list.
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
  // A pull request lookup keeps only the category and due clauses
  // (`JournalQueryRunner.runPullRequestSearch`), so its counts drop the rest.
  final effective = pullRequestSearchRef(pageState.match) != null
      ? live.copyWith(
          selectedTaskStatuses: {...allTaskStatuses},
          selectedLabelIds: const {},
          selectedPriorities: const {},
          selectedProjectIds: const {},
          agentAssignmentFilter: AgentAssignmentFilter.all,
        )
      : live.selectedTaskStatuses.isEmpty
      ? live.copyWith(selectedTaskStatuses: {...allTaskStatuses})
      : live;

  invalidateOnTaskNotifications(ref);

  final searchIds = await _searchRestriction(ref, pageState);
  final repo = ref.watch(savedTaskFilterCountRepositoryProvider);
  return repo.dueViewCounts(effective, restrictToIds: searchIds);
}

/// The task ids the live search admits, or null when no search is active.
///
/// Follows `JournalPageController`'s own branch: a pasted pull request link
/// reads the tasks linked to it; semantic mode with vector search enabled
/// reads the vector result set the page already holds; any other query runs
/// the same FTS5 match the list ran.
Future<Set<String>?> _searchRestriction(
  Ref ref,
  JournalPageState pageState,
) async {
  if (pageState.match.isEmpty) return null;
  final pullRequest = pullRequestSearchRef(pageState.match);
  if (pullRequest != null) {
    return ref
        .read(journalDbProvider)
        .taskIdsHoldingPullRequest(pullRequest.key);
  }
  if (pageState.enableVectorSearch &&
      pageState.searchMode == SearchMode.vector) {
    return pageState.vectorSearchDistances.keys.toSet();
  }
  final fts = ref.read(fts5DbProvider);
  if (fts == null) return null;
  final hits = await taskFullTextHits(
    fts5Db: fts,
    journalDb: ref.read(journalDbProvider),
    query: pageState.match,
    selectedCategoryIds: pageState.selectedCategoryIds,
  );
  return {for (final hit in hits) hit.taskId};
}
