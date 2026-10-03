import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';
import 'package:lotti/features/github/repository/github_token_storage.dart';
import 'package:lotti/features/github/repository/pull_request_repository.dart';

/// The outcome of a refresh.
sealed class PullRequestRefresh {
  const PullRequestRefresh();
}

/// GitHub answered: [observation] is the pull request as it is now. It was
/// stored if it changed; either way it is what a caller may call current.
final class PullRequestRefreshed extends PullRequestRefresh {
  const PullRequestRefreshed(this.observation);
  final PullRequestSnapshot observation;
}

/// Nothing was written; what is stored stays, labelled with its own age.
final class PullRequestRefreshFailed extends PullRequestRefresh {
  const PullRequestRefreshFailed(this.kind, {this.retryAt});
  final GitHubFailureKind kind;
  final DateTime? retryAt;
}

/// The outcome of linking a pasted pull request to a task.
sealed class PullRequestLinkResult {
  const PullRequestLinkResult();
}

final class PullRequestLinked extends PullRequestLinkResult {
  const PullRequestLinked(this.entry);
  final PullRequestEntry entry;
}

final class PullRequestAlreadyLinked extends PullRequestLinkResult {
  const PullRequestAlreadyLinked();
}

/// The pasted text is not a pull request.
final class PullRequestLinkRejected extends PullRequestLinkResult {
  const PullRequestLinkRejected(this.reason);
  final PullRequestRefRejection reason;
}

/// GitHub could not be asked, or refused: nothing was linked.
final class PullRequestLinkFailed extends PullRequestLinkResult {
  const PullRequestLinkFailed(this.kind, {this.retryAt});
  final GitHubFailureKind kind;
  final DateTime? retryAt;
}

/// Links pull requests to tasks and refreshes them from GitHub.
class PullRequestService {
  PullRequestService({
    required GitHubClient client,
    required GitHubTokenStorage tokenStorage,
    required PullRequestRepository repository,
  }) : _github = client,
       _tokens = tokenStorage,
       _entries = repository;

  final GitHubClient _github;
  final GitHubTokenStorage _tokens;
  final PullRequestRepository _entries;

  /// Links what the user pasted to [taskId]. The pull request is read first,
  /// so a typo, or a repository the token cannot see, links nothing.
  Future<PullRequestLinkResult> linkPasted({
    required String taskId,
    required String input,
  }) async {
    final PullRequestRef ref;
    switch (parsePullRequestRef(input)) {
      case PullRequestRefParsed(ref: final parsed):
        ref = parsed;
      case PullRequestRefRejected(:final reason):
        return PullRequestLinkRejected(reason);
    }
    if (await _entries.isLinked(taskId: taskId, ref: ref)) {
      return const PullRequestAlreadyLinked();
    }
    final observed = await _observe(ref);
    if (observed case PullRequestRefreshFailed(:final kind, :final retryAt)) {
      return PullRequestLinkFailed(kind, retryAt: retryAt);
    }
    final entry = await _entries.link(
      taskId: taskId,
      ref: ref,
      snapshot: (observed as PullRequestRefreshed).observation,
    );
    return entry == null
        ? const PullRequestAlreadyLinked()
        : PullRequestLinked(entry);
  }

  /// Reads [entry]'s pull request from GitHub and stores the observation if
  /// it changed (`Persist` in `specs/tla/PullRequestSnapshot.tla`).
  Future<PullRequestRefresh> refresh(PullRequestEntry entry) async {
    final observed = await _observe(entry.data.ref);
    if (observed is PullRequestRefreshed) {
      await _entries.persistObservation(entry.id, observed.observation);
    }
    return observed;
  }

  Future<PullRequestRefresh> _observe(PullRequestRef ref) async {
    final token = await _tokens.readToken();
    if (token == null || token.isEmpty) {
      return const PullRequestRefreshFailed(GitHubFailureKind.noToken);
    }
    try {
      return PullRequestRefreshed(
        await _github.fetchPullRequest(ref, token: token),
      );
    } on GitHubException catch (e) {
      return PullRequestRefreshFailed(e.kind, retryAt: e.retryAt);
    }
  }
}
