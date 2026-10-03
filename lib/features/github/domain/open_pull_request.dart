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
  final updatedAtText = json['updated_at'];
  final updatedAt = updatedAtText is String
      ? DateTime.tryParse(updatedAtText)
      : null;
  if (number is! int || title is! String || updatedAt == null) {
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
    updatedAt: updatedAt.toUtc(),
    authorLogin: login is String ? login : null,
    draft: json['draft'] == true,
  );
}
