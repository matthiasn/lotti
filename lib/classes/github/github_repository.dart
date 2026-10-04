import 'package:meta/meta.dart';

// GitHub logins: alphanumerics and single inner hyphens, at most 39.
final _owner = RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9]|-(?=[A-Za-z0-9])){0,38}$');
final _repo = RegExp(r'^[A-Za-z0-9._-]{1,100}$');
final _scheme = RegExp('^[A-Za-z][A-Za-z0-9+.-]*://');

/// Whether [owner] is a valid GitHub user or organisation login.
bool isGitHubOwner(String owner) => _owner.hasMatch(owner);

/// Whether [repo] is a valid GitHub repository name.
bool isGitHubRepoName(String repo) =>
    _repo.hasMatch(repo) && repo != '.' && repo != '..';

/// A GitHub repository: `owner/repo`.
@immutable
class GitHubRepository {
  const GitHubRepository({required this.owner, required this.repo});

  final String owner;
  final String repo;

  @override
  bool operator ==(Object other) =>
      other is GitHubRepository &&
      other.owner.toLowerCase() == owner.toLowerCase() &&
      other.repo.toLowerCase() == repo.toLowerCase();

  @override
  int get hashCode => Object.hash(owner.toLowerCase(), repo.toLowerCase());

  /// `owner/repo`, as stored on a category.
  @override
  String toString() => '$owner/$repo';
}

/// Reads a repository from what a user types: `owner/repo`, or the
/// repository's page on github.com — with or without the scheme, `www.`, a
/// trailing `.git`, or a path below it (`…/tree/main`). Null when it is
/// neither.
GitHubRepository? parseGitHubRepository(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;

  final List<String> segments;
  if (_scheme.hasMatch(text) ||
      text.toLowerCase().startsWith('github.com/') ||
      text.toLowerCase().startsWith('www.github.com/')) {
    final uri = Uri.tryParse(_scheme.hasMatch(text) ? text : 'https://$text');
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        !{'github.com', 'www.github.com'}.contains(uri.host.toLowerCase())) {
      return null;
    }
    segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  } else {
    segments = text.split('/');
    if (segments.length != 2) return null;
  }
  if (segments.length < 2) return null;

  final owner = segments[0];
  var repo = segments[1];
  if (repo.toLowerCase().endsWith('.git')) {
    repo = repo.substring(0, repo.length - 4);
  }
  if (!isGitHubOwner(owner) || !isGitHubRepoName(repo)) return null;
  return GitHubRepository(owner: owner, repo: repo);
}
