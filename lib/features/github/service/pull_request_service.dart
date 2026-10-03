import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/domain/github_repository.dart';
import 'package:lotti/features/github/domain/open_pull_request.dart';
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

/// Other tasks hold the pull request, so nothing was linked yet: a pull
/// request may serve more than one task, but only on purpose. Linking [ref]
/// again with `alsoElsewhere` is the user's confirmation.
final class PullRequestLinkedElsewhere extends PullRequestLinkResult {
  const PullRequestLinkedElsewhere(this.taskIds, this.ref);

  /// The other tasks that hold it, never the one being linked.
  final Set<String> taskIds;
  final PullRequestRef ref;
}

/// The entry could not be stored: nothing was linked.
final class PullRequestLinkNotStored extends PullRequestLinkResult {
  const PullRequestLinkNotStored();
}

/// GitHub could not be asked, or refused: nothing was linked.
final class PullRequestLinkFailed extends PullRequestLinkResult {
  const PullRequestLinkFailed(this.kind, {this.retryAt});
  final GitHubFailureKind kind;
  final DateTime? retryAt;
}

/// What the picker may offer a task.
sealed class OpenPullRequestsResult {
  const OpenPullRequestsResult();
}

/// The repository's open pull requests that no task holds yet.
final class OpenPullRequestsListed extends OpenPullRequestsResult {
  const OpenPullRequestsListed(this.available);
  final List<OpenPullRequest> available;
}

final class OpenPullRequestsFailed extends OpenPullRequestsResult {
  const OpenPullRequestsFailed(this.kind, {this.retryAt});
  final GitHubFailureKind kind;
  final DateTime? retryAt;
}

/// What a call made with the stored token says about it: GitHub [accepted]
/// it — the call succeeded — or rejected it with a 401.
typedef GitHubTokenVerdict =
    void Function(String token, {required bool accepted});

/// Links pull requests to tasks and refreshes them from GitHub.
class PullRequestService {
  PullRequestService({
    required GitHubClient client,
    required GitHubTokenStorage tokenStorage,
    required PullRequestRepository repository,
    GitHubTokenVerdict? onTokenVerdict,
  }) : _github = client,
       _tokens = tokenStorage,
       _entries = repository,
       _verdict = onTokenVerdict;

  final GitHubClient _github;
  final GitHubTokenStorage _tokens;
  final PullRequestRepository _entries;

  /// Told what each call with the stored token says about it. Only a
  /// success and a 401 do: offline, rate limited, forbidden or not found
  /// say nothing about whether GitHub still accepts the token.
  final GitHubTokenVerdict? _verdict;

  /// Calls [read] with the stored token, telling [_verdict] what GitHub
  /// answered.
  Future<T> _withToken<T>(String token, Future<T> Function() read) async {
    try {
      final result = await read();
      _verdict?.call(token, accepted: true);
      return result;
    } on GitHubException catch (e) {
      if (e.kind == GitHubFailureKind.unauthorized) {
        _verdict?.call(token, accepted: false);
      }
      rethrow;
    }
  }

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
    return link(taskId: taskId, ref: ref);
  }

  /// Links [ref] to [taskId], picked or pasted.
  ///
  /// A pull request this task holds is refused, and one another task holds
  /// is asked about ([PullRequestLinkedElsewhere]) — both before GitHub is
  /// asked — unless [alsoElsewhere] says the user confirmed linking it here
  /// as well. Then it is read, so a pull request the token cannot see links
  /// nothing, and the repository links it, checking again
  /// (`specs/tla/PullRequestAssignment.tla`).
  Future<PullRequestLinkResult> link({
    required String taskId,
    required PullRequestRef ref,
    bool alsoElsewhere = false,
  }) async {
    final holders = (await _entries.holdersOf([ref]))[ref.key];
    if (holders != null && (!alsoElsewhere || holders.contains(taskId))) {
      return _held(taskId, holders, ref);
    }
    final observed = await _observe(ref);
    if (observed case PullRequestRefreshFailed(:final kind, :final retryAt)) {
      return PullRequestLinkFailed(kind, retryAt: retryAt);
    }
    final attempt = await _entries.link(
      taskId: taskId,
      ref: ref,
      snapshot: (observed as PullRequestRefreshed).observation,
      alsoElsewhere: alsoElsewhere,
    );
    final linked = attempt.linked;
    if (linked != null) return PullRequestLinked(linked);
    if (attempt.heldBy.isNotEmpty) return _held(taskId, attempt.heldBy, ref);
    return const PullRequestLinkNotStored();
  }

  static PullRequestLinkResult _held(
    String taskId,
    Set<String> holders,
    PullRequestRef ref,
  ) => holders.contains(taskId)
      ? const PullRequestAlreadyLinked()
      : PullRequestLinkedElsewhere(holders, ref);

  /// The open pull requests of [repository] that no task holds, for the
  /// picker, newest first as GitHub lists them. What it shows can be stale
  /// by the time the user picks; [link] decides.
  Future<OpenPullRequestsResult> openPullRequests(
    GitHubRepository repository,
  ) async {
    final token = await _tokens.readToken();
    if (token == null || token.isEmpty) {
      return const OpenPullRequestsFailed(GitHubFailureKind.noToken);
    }
    final List<OpenPullRequest> open;
    try {
      open = await _withToken(
        token,
        () => _github.listOpenPullRequests(repository, token: token),
      );
    } on GitHubException catch (e) {
      return OpenPullRequestsFailed(e.kind, retryAt: e.retryAt);
    }
    final held = await _entries.holdersOf(open.map((pr) => pr.ref));
    return OpenPullRequestsListed(
      [
        for (final pr in open)
          if (!held.containsKey(pr.ref.key)) pr,
      ]..sort((a, b) {
        final byCreated = b.createdAt.compareTo(a.createdAt);
        return byCreated != 0
            ? byCreated
            : b.ref.number.compareTo(a.ref.number);
      }),
    );
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
        await _withToken(
          token,
          () => _github.fetchPullRequest(ref, token: token),
        ),
      );
    } on GitHubException catch (e) {
      return PullRequestRefreshFailed(e.kind, retryAt: e.retryAt);
    }
  }
}
