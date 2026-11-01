import 'package:meta/meta.dart';

/// An open pull request of a task's repository that no task holds yet: what
/// the task agent may suggest linking to its task.
@immutable
class UnlinkedPullRequest {
  const UnlinkedPullRequest({
    required this.owner,
    required this.repo,
    required this.number,
    required this.title,
    required this.createdAt,
    this.body = '',
    this.labels = const [],
    this.headRef,
    this.authorLogin,
    this.draft = false,
  });

  final String owner;
  final String repo;
  final int number;
  final String title;

  /// When it was opened, in UTC.
  final DateTime createdAt;

  /// The description, Markdown; empty when it has none.
  final String body;
  final List<String> labels;

  /// The branch it merges from, when known.
  final String? headRef;
  final String? authorLogin;
  final bool draft;
}

/// What listing a task's unlinked pull requests came to.
sealed class UnlinkedPullRequestsResult {
  const UnlinkedPullRequestsResult();
}

/// The open pull requests of [repository] (`owner/repo`) that no task holds,
/// newest first.
final class UnlinkedPullRequestsListed extends UnlinkedPullRequestsResult {
  const UnlinkedPullRequestsListed(this.repository, this.pullRequests);

  final String repository;
  final List<UnlinkedPullRequest> pullRequests;
}

/// Why nothing could be listed: no repository, no token, or GitHub failing.
/// [reason] is an English sentence for the agent and the log.
final class UnlinkedPullRequestsUnavailable extends UnlinkedPullRequestsResult {
  const UnlinkedPullRequestsUnavailable(this.reason);

  final String reason;
}

/// What a confirmed link came to.
sealed class PullRequestLinkConfirmation {
  const PullRequestLinkConfirmation();
}

/// The pull request is linked to the task: by this attempt, or before it.
final class PullRequestLinkSucceeded extends PullRequestLinkConfirmation {
  const PullRequestLinkSucceeded({this.alreadyLinked = false});

  final bool alreadyLinked;
}

/// Nothing was linked. [reason] is an English sentence for the change
/// history and the log.
final class PullRequestLinkRefused extends PullRequestLinkConfirmation {
  const PullRequestLinkRefused(this.reason);

  final String reason;
}

/// The pull requests a task agent may suggest linking, and the link a user
/// confirmed.
///
/// The port the task agent depends on; the github feature, which ranks above
/// agents, implements it, and the composition root wires it. Unwired, the
/// agent is never offered the pull request tools.
abstract interface class PullRequestLinkSource {
  /// Whether [taskId]'s pull requests can be listed at all: its category
  /// names a repository and this device holds a GitHub token. Local reads
  /// only — GitHub is not asked.
  Future<bool> canListFor(String taskId);

  /// The open pull requests of [taskId]'s repository that no task holds.
  /// Only the repository is sent to GitHub, never anything of the task.
  Future<UnlinkedPullRequestsResult> unlinkedFor(String taskId);

  /// Links pull request [number] of `owner/repo` to [taskId], as the user
  /// confirmed. One another task holds by now is refused, not linked twice.
  Future<PullRequestLinkConfirmation> link({
    required String taskId,
    required String owner,
    required String repo,
    required int number,
  });
}
