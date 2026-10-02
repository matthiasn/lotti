import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/api/pull_request_mapper.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';

/// Why a GitHub call failed.
enum GitHubFailureKind {
  /// No token is stored on this device.
  noToken,

  /// No connection, a timeout, or a TLS failure.
  offline,

  /// 401: the token is invalid, expired or revoked.
  unauthorized,

  /// 403 without an exhausted limit: the token lacks a permission, or the
  /// organisation requires SSO authorisation for it.
  forbidden,

  /// 403 or 429 with an exhausted limit; [GitHubException.retryAt] says when
  /// calls may resume.
  rateLimited,

  /// 404, which is also what a private repository answers a token that
  /// cannot see it; or a redirect, which the client never follows.
  notFound,

  /// 5xx.
  server,

  /// A response that does not look like GitHub's.
  invalidResponse,
}

class GitHubException implements Exception {
  const GitHubException(this.kind, {this.retryAt});

  final GitHubFailureKind kind;

  /// When a rate-limited client will call again.
  final DateTime? retryAt;

  @override
  String toString() =>
      'GitHubException(${kind.name}${retryAt == null ? '' : ', $retryAt'})';
}

/// The GitHub REST API, authenticated with the user's token.
///
/// It talks to `https://api.github.com` and nothing else: the host is a
/// constant and redirects are not followed, so no response can send the
/// token to another host. Pull request web pages are never fetched.
///
/// Reads send `If-None-Match` with the last `ETag` of the same URL, kept in
/// memory: a 304 costs no rate limit and reuses the cached body. Once rate
/// limited, the client refuses calls until the limit resets instead of
/// spending requests GitHub will refuse anyway.
class GitHubClient {
  GitHubClient({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  static const host = 'api.github.com';
  static const timeout = Duration(seconds: 10);
  static const _maxCached = 256;

  final http.Client _http;
  final _cache = <Uri, _CachedResponse>{};
  DateTime? _blockedUntil;

  /// The login [token] belongs to: `GET /user`. Used to check a token
  /// before it is saved.
  Future<String> fetchViewerLogin(String token) async {
    final response = await _get('/user', token: token);
    return switch (response.json) {
      {'login': final String login} => login,
      _ => throw const GitHubException(GitHubFailureKind.invalidResponse),
    };
  }

  /// The pull request [ref] as GitHub reports it now, with its checks and
  /// reviews, stamped with the server time of the pull request read.
  Future<PullRequestSnapshot> fetchPullRequest(
    PullRequestRef ref, {
    required String token,
  }) async {
    final repo = '/repos/${ref.owner}/${ref.repo}';
    final pull = await _get('$repo/pulls/${ref.number}', token: token);
    final pullJson = _object(pull.json);
    final sha = switch (pullJson['head']) {
      {'sha': final String sha} => sha,
      _ => throw const GitHubException(GitHubFailureKind.invalidResponse),
    };
    const page = {'per_page': '100'};
    // The first failure fails the refresh as it is, unwrapped.
    final [checkRuns, status, reviews] = await Future.wait(
      [
        _get('$repo/commits/$sha/check-runs', token: token, query: page),
        _get('$repo/commits/$sha/status', token: token, query: page),
        _get('$repo/pulls/${ref.number}/reviews', token: token, query: page),
      ],
      eagerError: true,
    );
    try {
      return pullRequestSnapshotFrom(
        pull: pullJson,
        checkRuns: _object(checkRuns.json),
        combinedStatus: _object(status.json),
        reviews: switch (reviews.json) {
          final List<dynamic> list => list,
          _ => throw const FormatException('reviews is not a list'),
        },
        observedAt: pull.date,
      );
    } on FormatException {
      throw const GitHubException(GitHubFailureKind.invalidResponse);
    }
  }

  void close() => _http.close();

  Future<_Response> _get(
    String path, {
    required String token,
    Map<String, String>? query,
  }) async {
    final blockedUntil = _blockedUntil;
    if (blockedUntil != null && clock.now().isBefore(blockedUntil)) {
      throw GitHubException(
        GitHubFailureKind.rateLimited,
        retryAt: blockedUntil,
      );
    }
    final uri = Uri.https(host, path, query);
    final cached = _cache[uri];
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers.addAll({
        'Accept': 'application/vnd.github+json',
        'Authorization': 'Bearer $token',
        'User-Agent': 'Lotti',
        'X-GitHub-Api-Version': '2022-11-28',
        if (cached != null) 'If-None-Match': cached.etag,
      });

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw const GitHubException(GitHubFailureKind.offline);
    } on SocketException {
      throw const GitHubException(GitHubFailureKind.offline);
    } on HandshakeException {
      throw const GitHubException(GitHubFailureKind.offline);
    } on http.ClientException {
      throw const GitHubException(GitHubFailureKind.offline);
    }

    final date = _serverDate(response.headers);
    switch (response.statusCode) {
      case 200:
        final Object? json;
        try {
          json = jsonDecode(response.body);
        } on FormatException {
          throw const GitHubException(GitHubFailureKind.invalidResponse);
        }
        final etag = response.headers['etag'];
        if (etag != null) _remember(uri, _CachedResponse(etag, json));
        return _Response(json, date);
      case 304 when cached != null:
        _remember(uri, cached);
        return _Response(cached.json, date);
      case 401:
        throw const GitHubException(GitHubFailureKind.unauthorized);
      case 403 || 429:
        final retryAt = _retryAt(response.headers);
        if (retryAt == null) {
          throw const GitHubException(GitHubFailureKind.forbidden);
        }
        _blockedUntil = retryAt;
        throw GitHubException(GitHubFailureKind.rateLimited, retryAt: retryAt);
      case 404 || 301 || 302 || 307 || 308:
        throw const GitHubException(GitHubFailureKind.notFound);
      case >= 500:
        throw const GitHubException(GitHubFailureKind.server);
      default:
        throw const GitHubException(GitHubFailureKind.invalidResponse);
    }
  }

  void _remember(Uri uri, _CachedResponse response) {
    _cache
      ..remove(uri)
      ..[uri] = response;
    if (_cache.length > _maxCached) _cache.remove(_cache.keys.first);
  }

  /// The server's clock: every device shares it, unlike their own. The
  /// device clock is only the fallback for a response without `Date`.
  static DateTime _serverDate(Map<String, String> headers) {
    final date = headers['date'];
    if (date != null) {
      try {
        return HttpDate.parse(date).toUtc();
      } on HttpException {
        // Fall through to the device clock.
      }
    }
    return clock.now().toUtc();
  }

  /// When an exhausted limit resets: `retry-after` seconds for a secondary
  /// limit, else `x-ratelimit-reset` once `x-ratelimit-remaining` is 0.
  /// Null when the 403 is not about limits at all.
  static DateTime? _retryAt(Map<String, String> headers) {
    final retryAfter = int.tryParse(headers['retry-after'] ?? '');
    if (retryAfter != null) {
      return clock.now().add(Duration(seconds: retryAfter));
    }
    final reset = int.tryParse(headers['x-ratelimit-reset'] ?? '');
    if (headers['x-ratelimit-remaining'] == '0' && reset != null) {
      return DateTime.fromMillisecondsSinceEpoch(reset * 1000, isUtc: true);
    }
    return null;
  }

  static Map<String, dynamic> _object(Object? json) => switch (json) {
    final Map<String, dynamic> map => map,
    _ => throw const GitHubException(GitHubFailureKind.invalidResponse),
  };
}

class _Response {
  const _Response(this.json, this.date);
  final Object? json;
  final DateTime date;
}

class _CachedResponse {
  const _CachedResponse(this.etag, this.json);
  final String etag;
  final Object? json;
}
