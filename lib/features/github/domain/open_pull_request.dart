import 'package:lotti/classes/github/github_repository.dart';
import 'package:lotti/classes/github/pull_request_ref.dart';
import 'package:meta/meta.dart';

/// An open pull request as the picker lists it.
@immutable
class OpenPullRequest {
  const OpenPullRequest({
    required this.ref,
    required this.title,
    required this.createdAt,
    this.authorLogin,
    this.draft = false,
  });

  final PullRequestRef ref;
  final String title;

  /// When the pull request was opened, in UTC: the picker's order and age.
  final DateTime createdAt;
  final String? authorLogin;
  final bool draft;
}

/// One item of `GET /repos/{o}/{r}/pulls` in [repository]. Throws
/// [FormatException] when a field the picker shows is missing.
OpenPullRequest openPullRequestFrom(
  Map<String, dynamic> json,
  GitHubRepository repository,
) {
  final number = json['number'];
  final title = json['title'];
  final createdAtText = json['created_at'];
  final createdAt = createdAtText is String
      ? DateTime.tryParse(createdAtText)
      : null;
  if (number is! int || title is! String || createdAt == null) {
    throw const FormatException('not an open pull request');
  }
  final user = json['user'];
  final login = user is Map<String, dynamic> ? user['login'] : null;
  return OpenPullRequest(
    ref: PullRequestRef(
      owner: repository.owner,
      repo: repository.repo,
      number: number,
    ),
    title: title,
    createdAt: createdAt.toUtc(),
    authorLogin: login is String ? login : null,
    draft: json['draft'] == true,
  );
}

/// How much a pull request changes: the lines it adds and removes.
typedef PullRequestSize = ({int additions, int deletions});

/// The sizes in a response to the open pull request size query, by number.
///
/// Nodes GitHub could not resolve come back null, and are skipped. Throws
/// [FormatException] when the response does not carry the list at all —
/// a GraphQL error is answered with a 200 and `errors` in place of `data`.
Map<int, PullRequestSize> openPullRequestSizesFrom(Object? json) {
  final nodes = switch (json) {
    {
      'data': {
        'repository': {'pullRequests': {'nodes': final List<dynamic> nodes}},
      },
    } =>
      nodes,
    _ => throw const FormatException('no pull request sizes'),
  };
  return {
    for (final node in nodes)
      if (node case {
        'number': final int number,
        'additions': final int additions,
        'deletions': final int deletions,
      })
        number: (additions: additions, deletions: deletions),
  };
}
