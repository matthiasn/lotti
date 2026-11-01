import 'package:lotti/classes/github/pull_request_ref.dart';
import 'package:lotti/features/agents/model/pull_request_link_source.dart';
import 'package:lotti/features/github/api/github_client.dart';
import 'package:lotti/features/github/repository/pull_request_repository.dart';
import 'package:lotti/features/github/service/pull_request_service.dart';

/// The task agent's view of the pull requests it may suggest linking: the
/// open pull requests of the task's repository that no task holds — the
/// picker's list — and the link the user confirms, through the same
/// [PullRequestService.link] the picker uses, so a pull request another task
/// took meanwhile is refused (`specs/tla/PullRequestAssignment.tla`).
class PullRequestLinkSuggestions implements PullRequestLinkSource {
  PullRequestLinkSuggestions({
    required PullRequestRepository repository,
    required this._service,
    required Future<bool> Function() hasToken,
  }) : _entries = repository,
       _tokenStored = hasToken;

  final PullRequestRepository _entries;
  final PullRequestService _service;
  final Future<bool> Function() _tokenStored;

  @override
  Future<bool> canListFor(String taskId) async =>
      await _tokenStored() && await _entries.repositoryOfTask(taskId) != null;

  @override
  Future<UnlinkedPullRequestsResult> unlinkedFor(String taskId) async {
    final repository = await _entries.repositoryOfTask(taskId);
    if (repository == null) {
      return const UnlinkedPullRequestsUnavailable(
        "The task's category names no GitHub repository.",
      );
    }
    switch (await _service.openPullRequests(repository)) {
      case OpenPullRequestsFailed(:final kind, :final retryAt):
        return UnlinkedPullRequestsUnavailable(_failure(kind, retryAt));
      case OpenPullRequestsListed(:final available):
        return UnlinkedPullRequestsListed(repository.toString(), [
          for (final pr in available)
            UnlinkedPullRequest(
              owner: pr.ref.owner,
              repo: pr.ref.repo,
              number: pr.ref.number,
              title: pr.title,
              createdAt: pr.createdAt,
              body: pr.body,
              labels: pr.labels,
              headRef: pr.headRef,
              authorLogin: pr.authorLogin,
              draft: pr.draft,
            ),
        ]);
    }
  }

  @override
  Future<PullRequestLinkConfirmation> link({
    required String taskId,
    required String owner,
    required String repo,
    required int number,
  }) async {
    final ref = PullRequestRef(owner: owner, repo: repo, number: number);
    return switch (await _service.link(taskId: taskId, ref: ref)) {
      PullRequestLinked() => const PullRequestLinkSucceeded(),
      PullRequestAlreadyLinked() => const PullRequestLinkSucceeded(
        alreadyLinked: true,
      ),
      PullRequestLinkedElsewhere() => PullRequestLinkRefused(
        "$ref is linked to another task by now. Link it from the task's "
        'Pull requests card to have it serve both.',
      ),
      PullRequestLinkFailed(:final kind, :final retryAt) =>
        PullRequestLinkRefused(_failure(kind, retryAt)),
      PullRequestLinkRejected() || PullRequestLinkNotStored() =>
        PullRequestLinkRefused('$ref could not be linked.'),
    };
  }

  static String _failure(GitHubFailureKind kind, DateTime? retryAt) =>
      switch (kind) {
        GitHubFailureKind.noToken => 'This device holds no GitHub token.',
        GitHubFailureKind.offline => 'GitHub cannot be reached right now.',
        GitHubFailureKind.unauthorized => 'GitHub rejected the token.',
        GitHubFailureKind.forbidden =>
          'The token may not read this repository.',
        GitHubFailureKind.rateLimited =>
          retryAt == null
              ? 'GitHub rate-limited this device.'
              : 'GitHub rate-limited this device until '
                    '${retryAt.toUtc().toIso8601String()}.',
        GitHubFailureKind.notFound =>
          'The repository or pull request was not found, or the token cannot '
              'see it.',
        GitHubFailureKind.server => 'GitHub answered with a server error.',
        GitHubFailureKind.invalidResponse =>
          'GitHub answered with something unreadable.',
      };
}
