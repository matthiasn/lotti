import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/context/pull_request_context_renderer.dart';
import 'package:lotti/features/github/domain/pull_request_order.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';
import 'package:lotti/features/github/repository/pull_request_repository.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';

/// One linked pull request as a task context may present it.
class PullRequestContextItem {
  const PullRequestContextItem({
    required this.ref,
    required this.snapshot,
    required this.current,
    this.failure,
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
}

/// Refreshes a task's pull requests for a task context: the coding prompt
/// and the task agent's wake (`Request` and `Build` in
/// `specs/tla/PullRequestSnapshot.tla`).
class PullRequestContextService {
  PullRequestContextService({
    required PullRequestRepository repository,
    required PullRequestService service,
    required Future<bool> Function() isEnabled,
    this.refreshTimeout = const Duration(seconds: 8),
  }) : _entries = repository,
       _refresher = service,
       _enabled = isEnabled;

  final PullRequestRepository _entries;
  final PullRequestService _refresher;
  final Future<bool> Function() _enabled;

  /// How long one refresh may hold up the context; it finishes, and is
  /// stored, after the context has stopped waiting for it.
  final Duration refreshTimeout;

  /// The task's pull requests, refreshed now, rendered for [audience]; empty
  /// when the task has none or the feature is disabled.
  Future<String> contextFor(
    String taskId, {
    required PullRequestContextAudience audience,
  }) async =>
      renderPullRequestContext(await forTask(taskId), audience: audience);

  /// The task's pull requests, each refreshed now, in parallel. Empty while
  /// GitHub pull requests are disabled: then nothing is asked of GitHub.
  Future<List<PullRequestContextItem>> forTask(String taskId) async {
    if (!await _enabled()) return const [];
    final entries = await _entries.forTask(taskId);
    final items = await Future.wait(entries.map(_itemFor));
    return items.nonNulls.toList();
  }

  Future<PullRequestContextItem?> _itemFor(PullRequestEntry entry) async {
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
        );
    }
  }

  Future<PullRequestContextItem?> _notRefreshed(
    PullRequestEntry entry,
    GitHubFailureKind kind,
  ) async {
    final stored = await _entries.liveEntry(entry.id);
    if (stored == null) return null;
    return PullRequestContextItem(
      ref: entry.data.ref,
      snapshot: stored.data.snapshot,
      current: false,
      failure: kind,
    );
  }
}
