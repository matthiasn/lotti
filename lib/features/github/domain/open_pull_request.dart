import 'package:lotti/features/github/domain/github_repository.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';
import 'package:meta/meta.dart';

/// An open pull request as the picker lists it.
@immutable
class OpenPullRequest {
  const OpenPullRequest({
    required this.ref,
    required this.title,
    required this.updatedAt,
    this.authorLogin,
    this.draft = false,
  });

  final PullRequestRef ref;
  final String title;
  final DateTime updatedAt;
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
  final updatedAt = json['updated_at'];
  if (number is! int || title is! String || updatedAt is! String) {
    throw const FormatException('not an open pull request');
  }
  final user = json['user'];
  return OpenPullRequest(
    ref: PullRequestRef(
      owner: repository.owner,
      repo: repository.repo,
      number: number,
    ),
    title: title,
    updatedAt: DateTime.parse(updatedAt).toUtc(),
    authorLogin: user is Map<String, dynamic> ? user['login'] as String? : null,
    draft: json['draft'] == true,
  );
}
