import 'dart:async';

import 'package:lotti/classes/github/pull_request_order.dart';
import 'package:lotti/classes/github/pull_request_ref.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/ai/model/pull_request_context_source.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/context/pull_request_context_renderer.dart';
import 'package:lotti/features/github/domain/pull_request_summary.dart';
import 'package:lotti/features/github/repository/pull_request_repository.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';

/// One linked pull request as a task context may present it.
class PullRequestContextItem {
  const PullRequestContextItem({
    required this.ref,
    required this.snapshot,
    required this.current,
    this.failure,
    this.summary,
  });

  final PullRequestRef ref;

  /// What the context may show; null when nothing was ever observed.
  final PullRequestSnapshot? snapshot;

  /// Whether [snapshot] was read after this context was requested: by its
  /// own refresh, or provably later than that (`Build` in the model). Only a
  /// current pull request may back a checklist suggestion.
  final bool current;

  /// Why the refresh failed, when it did.
  final GitHubFailureKind? failure;

  /// The summary of exactly [snapshot]'s content; null while none is
  /// written.
  final PullRequestSummary? summary;
}

/// Refreshes a task's pull requests for a task context: the coding prompt
/// and the task agent's wake (`Request` and `Build` in
/// `specs/tla/PullRequestSnapshot.tla`).
class PullRequestContextService implements PullRequestContextSource {
  PullRequestContextService({
    required PullRequestRepository repository,
    required PullRequestService service,
    required Future<bool> Function() hasToken,
    this.refreshTimeout = const Duration(seconds: 8),
    this.summaryTimeout = const Duration(seconds: 90),
  }) : _entries = repository,
       _refresher = service,
       _tokenStored = hasToken;

  final PullRequestRepository _entries;
  final PullRequestService _refresher;

  /// Whether this device holds a GitHub token. A token GitHub has since
  /// rejected still counts: the pull requests linked meanwhile keep their
  /// place in the context, as not refreshed and labelled with why.
  final Future<bool> Function() _tokenStored;

  /// How long one refresh may hold up the context; it finishes, and is
  /// stored, after the context has stopped waiting for it.
  final Duration refreshTimeout;

  /// The task's pull requests, refreshed now, rendered for [audience]; empty
  /// when the task has none or this device holds no GitHub token.
  @override
  Future<String> contextFor(
    String taskId, {
    required PullRequestContextAudience audience,
  }) async =>
      renderPullRequestContext(await forTask(taskId), audience: audience);

  @override
  Future<String> refreshOpenFor(String taskId) async =>
      renderPullRequestContext(
        await forTask(taskId, agentRefresh: true),
        audience: PullRequestContextAudience.taskAgent,
      );

  /// The task's pull requests, each refreshed now, in parallel. Empty while
  /// this device holds no GitHub token: then nothing is asked of GitHub.
  ///
  /// With [agentRefresh] — the task agent's `refresh_pull_requests` — one
  /// stored as merged is not read again but shown as stored, and as current:
  /// a merge is final, so no later read can differ. And for every one merged
  /// or closed, the item waits until its summary is settled
  /// ([PullRequestService.settleSummary]), at most [summaryTimeout], so the
  /// agent decides from what the pull request did, not from its title.
  Future<List<PullRequestContextItem>> forTask(
    String taskId, {
    bool agentRefresh = false,
  }) async {
    if (!await _tokenStored()) return const [];
    final entries = await _entries.forTask(taskId);
    final items = await Future.wait(
      entries.map(
        (entry) => agentRefresh && _isMerged(entry.data.snapshot)
            ? _merged(entry)
            : _itemFor(entry, settleSummary: agentRefresh),
      ),
    );
    return items.nonNulls.toList();
  }

  static bool _isMerged(PullRequestSnapshot? snapshot) =>
      snapshot?.status == PullRequestStatus.merged;

  /// How long the agent's refresh waits for a merged or closed pull
  /// request's summary; past it, the item goes without one.
  final Duration summaryTimeout;

  /// Waits until [entry]'s summary is settled, at most [summaryTimeout].
  Future<void> _settle(PullRequestEntry entry) => _refresher
      .settleSummary(entry.id)
      .timeout(summaryTimeout, onTimeout: () {});

  /// A pull request stored as merged, current without asking GitHub, with
  /// its summary settled first.
  Future<PullRequestContextItem?> _merged(PullRequestEntry entry) async {
    await _settle(entry);
    final stored = await _entries.liveEntry(entry.id);
    final snapshot = stored?.data.snapshot;
    if (stored == null || snapshot == null) return null;
    return PullRequestContextItem(
      ref: entry.data.ref,
      snapshot: snapshot,
      current: true,
      summary: await _summaryOf(entry, snapshot),
    );
  }

  Future<PullRequestContextItem?> _itemFor(
    PullRequestEntry entry, {
    bool settleSummary = false,
  }) async {
    final PullRequestRefresh result;
    try {
      result = await _refresher.refresh(entry).timeout(refreshTimeout);
    } on TimeoutException {
      return _notRefreshed(entry, GitHubFailureKind.offline);
    }
    switch (result) {
      case PullRequestRefreshFailed(:final kind):
        return _notRefreshed(entry, kind);
      case PullRequestRefreshed(:final observation):
        if (settleSummary && observation.status != PullRequestStatus.open) {
          await _settle(entry);
        }
        // Read again: the pull request may have been unlinked, or a later
        // observation may have synced in, while the refresh ran.
        final stored = await _entries.liveEntry(entry.id);
        if (stored == null) return null;
        final storedSnapshot = stored.data.snapshot;
        final use =
            storedSnapshot != null &&
                isProvablyLaterObservation(storedSnapshot, observation)
            ? storedSnapshot
            : observation;
        return PullRequestContextItem(
          ref: entry.data.ref,
          snapshot: use,
          current: true,
          summary: await _summaryOf(entry, use),
        );
    }
  }

  Future<PullRequestContextItem?> _notRefreshed(
    PullRequestEntry entry,
    GitHubFailureKind kind,
  ) async {
    final stored = await _entries.liveEntry(entry.id);
    if (stored == null) return null;
    final snapshot = stored.data.snapshot;
    return PullRequestContextItem(
      ref: entry.data.ref,
      snapshot: snapshot,
      current: false,
      failure: kind,
      summary: snapshot == null ? null : await _summaryOf(entry, snapshot),
    );
  }

  /// The summary of [snapshot]'s content, if one was written: a context
  /// never waits for one.
  Future<PullRequestSummary?> _summaryOf(
    PullRequestEntry entry,
    PullRequestSnapshot snapshot,
  ) => _entries.summaryOf(
    entry.id,
    pullRequestSummaryInput(entry.data.ref, snapshot),
  );
}
