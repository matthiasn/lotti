import 'package:meta/meta.dart';

/// A pull request's identity: `owner/repo#number`.
@immutable
class PullRequestRef {
  const PullRequestRef({
    required this.owner,
    required this.repo,
    required this.number,
  });

  final String owner;
  final String repo;
  final int number;

  /// `owner/repo#number`, lower-cased: GitHub names are case-insensitive, and
  /// this is the key a linked pull request is stored under.
  String get key => '${owner.toLowerCase()}/${repo.toLowerCase()}#$number';

  @override
  bool operator ==(Object other) => other is PullRequestRef && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => '$owner/$repo#$number';
}

/// Why a pasted text is not a pull request.
enum PullRequestRefRejection {
  /// Nothing was pasted.
  empty,

  /// A link, but not to github.com.
  notGitHub,

  /// A GitHub link or shorthand, but not to a pull request.
  notAPullRequest,
}

/// The outcome of [parsePullRequestRef]: a [PullRequestRef] or the reason.
sealed class PullRequestRefParse {
  const PullRequestRefParse();
}

final class PullRequestRefParsed extends PullRequestRefParse {
  const PullRequestRefParsed(this.ref);
  final PullRequestRef ref;
}

final class PullRequestRefRejected extends PullRequestRefParse {
  const PullRequestRefRejected(this.reason);
  final PullRequestRefRejection reason;
}

// GitHub logins: alphanumerics and single inner hyphens, at most 39.
final _owner = RegExp(r'^[A-Za-z0-9](?:[A-Za-z0-9]|-(?=[A-Za-z0-9])){0,38}$');
final _repo = RegExp(r'^[A-Za-z0-9._-]{1,100}$');
final _number = RegExp(r'^[1-9][0-9]{0,9}$');
final _shorthand = RegExp(r'^([^/\s#]+)/([^/\s#]+)#([0-9]+)$');
final _scheme = RegExp('^[A-Za-z][A-Za-z0-9+.-]*://');

/// Reads a pull request from what a user pastes.
///
/// Accepts a pull request page on github.com — with or without the scheme,
/// `www.`, and any tab, query or fragment after the number
/// (`https://github.com/o/r/pull/12/files#diff`) — the same pull request on
/// `api.github.com`, and the `owner/repo#12` shorthand. GitHub Enterprise
/// hosts are not accepted: the client only ever talks to `api.github.com`.
PullRequestRefParse parsePullRequestRef(String input) {
  final text = input.trim();
  if (text.isEmpty) {
    return const PullRequestRefRejected(PullRequestRefRejection.empty);
  }

  final short = _shorthand.firstMatch(text);
  if (short != null) {
    return _validated(short.group(1)!, short.group(2)!, short.group(3)!);
  }

  final uri = Uri.tryParse(_scheme.hasMatch(text) ? text : 'https://$text');
  if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
    return const PullRequestRefRejected(PullRequestRefRejection.notGitHub);
  }
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  switch (uri.host.toLowerCase()) {
    case 'github.com' || 'www.github.com':
      if (segments.length >= 4 && segments[2] == 'pull') {
        return _validated(segments[0], segments[1], segments[3]);
      }
    case 'api.github.com':
      if (segments.length >= 5 &&
          segments[0] == 'repos' &&
          segments[3] == 'pulls') {
        return _validated(segments[1], segments[2], segments[4]);
      }
    default:
      return const PullRequestRefRejected(PullRequestRefRejection.notGitHub);
  }
  return const PullRequestRefRejected(PullRequestRefRejection.notAPullRequest);
}

PullRequestRefParse _validated(String owner, String repo, String number) {
  if (!_owner.hasMatch(owner) ||
      !_repo.hasMatch(repo) ||
      repo == '.' ||
      repo == '..' ||
      !_number.hasMatch(number)) {
    return const PullRequestRefRejected(
      PullRequestRefRejection.notAPullRequest,
    );
  }
  return PullRequestRefParsed(
    PullRequestRef(owner: owner, repo: repo, number: int.parse(number)),
  );
}
