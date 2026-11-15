import 'package:collection/collection.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/service/front_pull_request_reader.dart';
import 'package:lotti/features/front_agent/service/front_routing_index_builder.dart';
import 'package:lotti/features/github/context/pull_request_context_renderer.dart';
import 'package:lotti/features/github/context/pull_request_context_service.dart';
import 'package:lotti/features/github/domain/pull_request_summary.dart';
import 'package:lotti/features/insights/model/insights_models.dart';

/// What one `find_pull_requests` reads before anything is filtered: the
/// days it covered and every pull request opened or merged in them that the
/// turn may see, newest opened first.
typedef FrontPullRequestCandidates = ({
  InsightsRange range,
  List<FrontFoundPullRequest> pullRequests,
});

/// Reads pull requests for her answers from what the device stores: GitHub
/// is never asked at question time.
extension FrontPullRequestFinding on FrontRoutingIndexBuilder {
  /// The candidates of a `find_pull_requests` in one window of [now]'s
  /// days: those [readFrontPullRequests] counts in [scope] — the user's own
  /// when their login is known — each with its task and the one-liner of
  /// its summary, at most [frontPullRequestFilterMaxCandidates]. With
  /// `largest`, only those opened in the window, largest first by lines
  /// changed — added and deleted — the newer first on a tie. Null when no
  /// pull request repository is wired.
  Future<FrontPullRequestCandidates> Function(
    FrontPullRequestQuery query, {
    bool largest,
  })?
  pullRequestFinder(FrontRoutingScope scope, {required DateTime now}) {
    if (pullRequestRepository == null) return null;
    return (query, {largest = false}) async {
      final range = await rangeOf(query, now);
      final chart = FrontPullRequestChart(
        range: range,
        categoryIds: scope.categoryIds,
        authorLogin: await githubLogin?.call(),
      );
      final (:pullRequests, undated: _) = await readFrontPullRequests(
        journalDb,
        chart,
      );
      var candidates = pullRequests;
      if (largest) {
        candidates = FrontPullRequests(
          chart: chart,
          pullRequests: pullRequests,
        ).opened;
        // Stable, so a tie keeps the newest opened first.
        mergeSort(
          candidates,
          compare: (a, b) =>
              (b.additions + b.deletions).compareTo(a.additions + a.deletions),
        );
      }
      final found = await pullRequestsOf([
        for (final pr in candidates.take(
          frontPullRequestFilterMaxCandidates,
        ))
          if (pr.taskId case final taskId?) (key: pr.key, taskId: taskId),
      ], scope);
      // The size each was counted and ranked by, not a later read of its
      // snapshot — a refresh in between, or another device's entry of the
      // same pull request, would list sizes out of their order.
      final counted = {for (final pr in candidates) pr.key: pr};
      return (
        range: range,
        pullRequests: [
          for (final pr in found)
            // A size never stored stays unknown, never a counted zero.
            if ((pr.additions, counted[pr.key]) case (_?, final size?))
              FrontFoundPullRequest(
                key: pr.key,
                title: pr.title,
                task: pr.task,
                oneLiner: pr.oneLiner,
                createdAt: pr.createdAt,
                mergedAt: pr.mergedAt,
                additions: size.additions,
                deletions: size.deletions,
              )
            else
              pr,
        ],
      );
    };
  }

  /// The pull requests [cards] name, in their order, as [scope] lets her
  /// see them now: one whose task is gone, hidden or outside the scope, or
  /// that the task no longer holds, is left out.
  Future<List<FrontFoundPullRequest>> pullRequestsOf(
    List<FrontPullRequestCard> cards,
    FrontRoutingScope scope,
  ) async {
    final repository = pullRequestRepository;
    if (repository == null || cards.isEmpty) return const [];
    final tasks = {
      for (final row in await conversationTasks([
        ...{for (final card in cards) card.taskId},
      ], scope))
        row.id: row,
    };
    final entries = await _entriesOf(cards, tasks.keys.toSet());
    return [
      for (final card in cards)
        if ((tasks[card.taskId], entries[card]) case (
          final task?,
          final entry?,
        ))
          FrontFoundPullRequest(
            key: card.key,
            title: entry.data.snapshot?.title ?? card.key,
            task: task,
            oneLiner: (await _summaryOf(entry))?.oneLiner,
            createdAt: entry.data.snapshot?.createdAt,
            mergedAt: entry.data.snapshot?.mergedAt,
            additions: entry.data.snapshot?.additions,
            deletions: entry.data.snapshot?.deletions,
          ),
    ];
  }

  /// What `read_pull_requests` answers for [pullRequests]: each as last
  /// stored, in full, with its summary's TL;DR (`companion` audience).
  Future<String> pullRequestDetails(
    List<FrontFoundPullRequest> pullRequests,
  ) async {
    final entries = await _entriesOf(
      [
        for (final pr in pullRequests) pr.card,
      ],
      {for (final pr in pullRequests) pr.task.id},
    );
    final items = <PullRequestContextItem>[];
    for (final pr in pullRequests) {
      final entry = entries[pr.card];
      if (entry == null) continue;
      items.add(
        PullRequestContextItem(
          ref: entry.data.ref,
          snapshot: entry.data.snapshot,
          current: false,
          summary: await _summaryOf(entry),
        ),
      );
    }
    return renderPullRequestContext(
      items,
      audience: PullRequestContextAudience.companion,
    );
  }

  /// The entry of each of [cards] whose task is one of [taskIds], read once
  /// per task.
  Future<Map<FrontPullRequestCard, PullRequestEntry>> _entriesOf(
    List<FrontPullRequestCard> cards,
    Set<String> taskIds,
  ) async {
    final repository = pullRequestRepository!;
    final byTask = {
      for (final taskId in taskIds)
        taskId: {
          for (final entry in await repository.forTask(taskId))
            entry.data.key: entry,
        },
    };
    return {
      for (final card in cards) card: ?byTask[card.taskId]?[card.key],
    };
  }

  Future<PullRequestSummary?> _summaryOf(PullRequestEntry entry) async {
    final snapshot = entry.data.snapshot;
    if (snapshot == null) return null;
    return pullRequestRepository!.summaryOf(
      entry.id,
      pullRequestSummaryInput(entry.data.ref, snapshot),
    );
  }
}

/// [rows] by `owner/repo#number`, for checking the ids she names.
Map<String, FrontFoundPullRequest> frontPullRequestsByKey(
  Iterable<FrontFoundPullRequest> rows,
) => {for (final row in rows) row.key: row};

/// The task rows [pullRequests] are held by, each once: what her words may
/// link and her cards may show once she has seen the pull requests.
List<FrontIndexRow> frontPullRequestTasks(
  Iterable<FrontFoundPullRequest> pullRequests,
) => [
  ...{for (final pr in pullRequests) pr.task.id: pr.task}.values,
];
