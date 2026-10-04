import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/classes/github/github_repository.dart';
import 'package:lotti/classes/github/pull_request_ref.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/api/github_client.dart';

import '../github_fixtures.dart';

void main() {
  const token = 'ghp_test_token';
  const ref = PullRequestRef(owner: 'penguin', repo: 'colony', number: 12);
  final now = DateTime.utc(2024, 3, 15, 12);
  const serverDate = 'Fri, 15 Mar 2024 12:00:05 GMT';

  late List<http.Request> requests;

  GitHubClient clientWith(
    FutureOr<http.Response> Function(http.Request request) handler,
  ) {
    requests = [];
    final client = GitHubClient(
      httpClient: MockClient((request) async {
        requests.add(request);
        return handler(request);
      }),
    );
    addTearDown(client.close);
    return client;
  }

  http.Response json(
    Object body, {
    int status = 200,
    Map<String, String> headers = const {},
  }) => http.Response(
    jsonEncode(body),
    status,
    headers: {'date': serverDate, ...headers},
  );

  /// Answers every endpoint a refresh reads, the pull request with [pull].
  http.Response github(http.Request request, {Map<String, dynamic>? pull}) {
    final path = request.url.path;
    if (path.endsWith('/check-runs')) {
      return json(
        githubCheckRunsJson([
          githubCheckRunJson('build', conclusion: 'success'),
        ]),
      );
    }
    if (path.endsWith('/status')) return json(githubCombinedStatusJson([]));
    if (path.endsWith('/reviews')) {
      return json([githubReviewJson('emperor', 'APPROVED')]);
    }
    return json(pull ?? githubPullJson());
  }

  Future<GitHubFailureKind?> failureOf(Future<Object?> call) async {
    try {
      await call;
      return null;
    } on GitHubException catch (e) {
      return e.kind;
    }
  }

  group('fetchPullRequest', () {
    test(
      'reads the pull request, then its checks, statuses and reviews by '
      'head commit, stamped with the server time of the pull response',
      () async {
        final client = clientWith(github);

        final snapshot = await withClock(
          Clock.fixed(now),
          () => client.fetchPullRequest(ref, token: token),
        );

        expect(requests.map((r) => r.url.path), [
          '/repos/penguin/colony/pulls/12',
          '/repos/penguin/colony/commits/abc1234/check-runs',
          '/repos/penguin/colony/commits/abc1234/status',
          '/repos/penguin/colony/pulls/12/reviews',
        ]);
        expect(snapshot.observedAt, DateTime.utc(2024, 3, 15, 12, 0, 5));
        expect(snapshot.title, 'Waddle faster');
        expect(snapshot.checks.rollup, PullRequestCheckRollup.passing);
        expect(snapshot.reviews.decision, PullRequestReviewDecision.approved);
      },
    );

    test(
      'sends the token only to api.github.com, as a bearer token, and never '
      'follows a redirect',
      () async {
        final client = clientWith(github);
        await client.fetchPullRequest(ref, token: token);

        for (final request in requests) {
          expect(request.url.scheme, 'https');
          expect(request.url.host, 'api.github.com');
          expect(request.method, 'GET');
          expect(request.followRedirects, isFalse);
          expect(request.headers['Authorization'], 'Bearer $token');
          expect(request.headers['Accept'], 'application/vnd.github+json');
          expect(request.headers['X-GitHub-Api-Version'], '2022-11-28');
          expect(request.headers['User-Agent'], 'Lotti');
          expect(request.url.toString(), isNot(contains(token)));
        }
      },
    );

    test('falls back to the device clock when GitHub sends no Date', () async {
      final client = clientWith(
        (request) => http.Response(
          jsonEncode(
            request.url.path.endsWith('/reviews')
                ? <Object>[]
                : request.url.path.contains('/commits/')
                ? (request.url.path.endsWith('/status')
                      ? githubCombinedStatusJson([])
                      : githubCheckRunsJson([]))
                : githubPullJson(),
          ),
          200,
        ),
      );

      final snapshot = await withClock(
        Clock.fixed(now),
        () => client.fetchPullRequest(ref, token: token),
      );

      expect(snapshot.observedAt, now);
    });

    test(
      'an unchanged pull request answers 304 to its ETag: the cached body, '
      'stamped with the new response',
      () async {
        var pullReads = 0;
        final client = clientWith((request) {
          if (!request.url.path.endsWith('/pulls/12')) return github(request);
          pullReads++;
          if (pullReads == 1) {
            return json(githubPullJson(), headers: {'etag': '"v1"'});
          }
          expect(request.headers['If-None-Match'], '"v1"');
          return http.Response(
            '',
            304,
            headers: {'date': 'Fri, 15 Mar 2024 12:10:00 GMT'},
          );
        });

        await client.fetchPullRequest(ref, token: token);
        final second = await client.fetchPullRequest(ref, token: token);

        expect(second.title, 'Waddle faster');
        expect(second.observedAt, DateTime.utc(2024, 3, 15, 12, 10));
      },
    );

    test(
      'follows every page: a decision on the second page of reviews counts, '
      'and a list shorter than a page is not asked again',
      () async {
        final firstPage = [
          for (var i = 0; i < GitHubClient.pageSize; i++)
            githubReviewJson('reviewer$i', 'APPROVED'),
        ];
        final client = clientWith((request) {
          if (!request.url.path.endsWith('/reviews')) return github(request);
          return switch (request.url.queryParameters['page']) {
            '1' => json(firstPage),
            '2' => json([githubReviewJson('reviewer0', 'CHANGES_REQUESTED')]),
            final other => throw StateError('page $other'),
          };
        });

        final snapshot = await client.fetchPullRequest(ref, token: token);

        expect(
          snapshot.reviews.decision,
          PullRequestReviewDecision.changesRequested,
        );
        expect(snapshot.reviews.approvals, GitHubClient.pageSize - 1);
        final reviewPages = requests
            .where((r) => r.url.path.endsWith('/reviews'))
            .map((r) => r.url.queryParameters['page']);
        expect(reviewPages, ['1', '2']);
        // Lists that fit one page are read once.
        expect(
          requests.where((r) => r.url.path.endsWith('/check-runs')),
          hasLength(1),
        );
      },
    );

    test('check runs on a second page are counted', () async {
      final client = clientWith((request) {
        if (!request.url.path.endsWith('/check-runs')) return github(request);
        return switch (request.url.queryParameters['page']) {
          '1' => json(
            githubCheckRunsJson([
              for (var i = 0; i < GitHubClient.pageSize; i++)
                githubCheckRunJson('shard $i', conclusion: 'success'),
            ]),
          ),
          _ => json(
            githubCheckRunsJson([
              githubCheckRunJson('late', conclusion: 'failure'),
            ]),
          ),
        };
      });

      final snapshot = await client.fetchPullRequest(ref, token: token);

      expect(snapshot.checks.rollup, PullRequestCheckRollup.failing);
      expect(snapshot.checks.total, GitHubClient.pageSize + 1);
    });

    test('a page that is not a list is an invalid response', () async {
      final client = clientWith(
        (request) => request.url.path.endsWith('/reviews')
            ? json({'not': 'a list'})
            : github(request),
      );

      expect(
        await failureOf(client.fetchPullRequest(ref, token: token)),
        GitHubFailureKind.invalidResponse,
      );
    });

    test('a failing sub-read fails the whole refresh, as itself', () async {
      final client = clientWith(
        (request) => request.url.path.endsWith('/reviews')
            ? json({'message': 'Resource not accessible'}, status: 403)
            : github(request),
      );

      expect(
        await failureOf(client.fetchPullRequest(ref, token: token)),
        GitHubFailureKind.forbidden,
      );
    });

    test(
      'check runs refused to the token (a fine-grained token on a private '
      'repository) leave the rest of the pull request read, and CI counted '
      'from the commit statuses alone',
      () async {
        final client = clientWith((request) {
          final path = request.url.path;
          if (path.endsWith('/check-runs')) {
            return json({
              'message': 'Resource not accessible by personal access token',
            }, status: 403);
          }
          if (path.endsWith('/status')) {
            return json(
              githubCombinedStatusJson([
                githubStatusJson('ci/legacy', 'failure'),
              ]),
            );
          }
          return github(request);
        });

        final snapshot = await client.fetchPullRequest(ref, token: token);

        expect(snapshot.title, 'Waddle faster');
        expect(snapshot.reviews.decision, PullRequestReviewDecision.approved);
        expect(snapshot.checks.checkRunsHidden, isTrue);
        expect(snapshot.checks.rollup, PullRequestCheckRollup.failing);
        expect(snapshot.checks.failingNames, ['ci/legacy']);
      },
    );

    test('an exhausted rate limit on the check runs still fails', () async {
      final reset = now.add(const Duration(minutes: 10));
      final client = clientWith(
        (request) => request.url.path.endsWith('/check-runs')
            ? json(
                {'message': 'API rate limit exceeded'},
                status: 403,
                headers: {
                  'x-ratelimit-remaining': '0',
                  'x-ratelimit-reset':
                      '${reset.millisecondsSinceEpoch ~/ 1000}',
                },
              )
            : github(request),
      );

      expect(
        await failureOf(client.fetchPullRequest(ref, token: token)),
        GitHubFailureKind.rateLimited,
      );
    });

    test("a pull request response that is not GitHub's is invalid", () async {
      final client = clientWith(
        (request) => github(request, pull: githubPullJson()..remove('base')),
      );

      expect(
        await failureOf(client.fetchPullRequest(ref, token: token)),
        GitHubFailureKind.invalidResponse,
      );
    });
  });

  group('failures', () {
    Future<GitHubFailureKind?> answering(http.Response response) =>
        failureOf(clientWith((_) => response).fetchViewerLogin(token));

    test('map by status code', () async {
      expect(
        await answering(json({}, status: 401)),
        GitHubFailureKind.unauthorized,
      );
      expect(
        await answering(json({}, status: 403)),
        GitHubFailureKind.forbidden,
      );
      expect(
        await answering(json({}, status: 404)),
        GitHubFailureKind.notFound,
      );
      expect(
        await answering(json({}, status: 301)),
        GitHubFailureKind.notFound,
      );
      expect(await answering(json({}, status: 502)), GitHubFailureKind.server);
      expect(
        await answering(json({}, status: 418)),
        GitHubFailureKind.invalidResponse,
      );
      expect(
        await answering(http.Response('<html>', 200)),
        GitHubFailureKind.invalidResponse,
      );
      expect(
        await answering(json({'id': 1})),
        GitHubFailureKind.invalidResponse,
      );
    });

    test('no connection is offline', () async {
      expect(
        await failureOf(
          clientWith(
            (_) => throw const SocketException('down'),
          ).fetchViewerLogin(token),
        ),
        GitHubFailureKind.offline,
      );
      expect(
        await failureOf(
          clientWith(
            (_) => throw http.ClientException('reset'),
          ).fetchViewerLogin(token),
        ),
        GitHubFailureKind.offline,
      );
    });

    test('a response that never comes is offline after the timeout', () {
      fakeAsync((async) {
        GitHubFailureKind? kind;
        failureOf(
          clientWith(
            (_) => Completer<http.Response>().future,
          ).fetchViewerLogin(token),
        ).then((k) => kind = k);

        async.elapse(GitHubClient.timeout - const Duration(seconds: 1));
        expect(kind, isNull);
        async.elapse(const Duration(seconds: 2));
        expect(kind, GitHubFailureKind.offline);
      });
    });

    test(
      'an exhausted limit blocks every call until it resets, without '
      'asking GitHub',
      () async {
        final reset = now.add(const Duration(minutes: 30));
        final client = clientWith(
          (_) => json(
            {'message': 'API rate limit exceeded'},
            status: 403,
            headers: {
              'x-ratelimit-remaining': '0',
              'x-ratelimit-reset': '${reset.millisecondsSinceEpoch ~/ 1000}',
            },
          ),
        );

        await withClock(Clock.fixed(now), () async {
          try {
            await client.fetchViewerLogin(token);
            fail('expected a rate limit');
          } on GitHubException catch (e) {
            expect(e.kind, GitHubFailureKind.rateLimited);
            expect(e.retryAt, reset);
          }
          expect(
            await failureOf(client.fetchPullRequest(ref, token: token)),
            GitHubFailureKind.rateLimited,
          );
        });
        expect(requests, hasLength(1));

        await withClock(
          Clock.fixed(reset.add(const Duration(seconds: 1))),
          () => failureOf(client.fetchViewerLogin(token)),
        );
        expect(requests, hasLength(2));
      },
    );

    test('a secondary limit waits retry-after seconds', () async {
      final client = clientWith(
        (_) => json({}, status: 429, headers: {'retry-after': '60'}),
      );

      await withClock(Clock.fixed(now), () async {
        try {
          await client.fetchViewerLogin(token);
          fail('expected a rate limit');
        } on GitHubException catch (e) {
          expect(e.kind, GitHubFailureKind.rateLimited);
          expect(e.retryAt, now.add(const Duration(seconds: 60)));
          expect(e.toString(), contains('rateLimited'));
        }
      });
    });
  });

  group('listOpenPullRequests', () {
    const repository = GitHubRepository(owner: 'penguin', repo: 'colony');
    Map<String, dynamic> openJson(int number, {bool draft = false}) => {
      'number': number,
      'title': 'PR $number',
      'created_at': '2024-03-15T11:00:00Z',
      'user': {'login': 'pingu'},
      'draft': draft,
    };

    test(
      'lists open pull requests, asking GitHub for the newest first, every '
      'page',
      () async {
        final client = clientWith(
          (request) => switch (request.url.queryParameters['page']) {
            '1' => json([
              for (var i = 1; i <= GitHubClient.pageSize; i++) openJson(i),
            ]),
            _ => json([openJson(101, draft: true)]),
          },
        );

        final open = await client.listOpenPullRequests(
          repository,
          token: token,
        );

        expect(open, hasLength(GitHubClient.pageSize + 1));
        expect(open.first.ref.toString(), 'penguin/colony#1');
        expect(open.first.title, 'PR 1');
        expect(open.first.authorLogin, 'pingu');
        expect(open.first.createdAt, DateTime.utc(2024, 3, 15, 11));
        expect(open.last.draft, isTrue);
        final first = requests.first.url;
        expect(first.path, '/repos/penguin/colony/pulls');
        expect(first.queryParameters, {
          'state': 'open',
          'sort': 'created',
          'direction': 'desc',
          'per_page': '${GitHubClient.pageSize}',
          'page': '1',
        });
      },
    );

    test('an item that is not an open pull request is invalid', () async {
      for (final body in [
        <Object>[
          {'number': 'one'},
        ],
        <Object>['not an object'],
      ]) {
        expect(
          await failureOf(
            clientWith((_) => json(body)).listOpenPullRequests(
              repository,
              token: token,
            ),
          ),
          GitHubFailureKind.invalidResponse,
        );
      }
    });
  });

  test("fetchViewerLogin returns the token's login", () async {
    final client = clientWith((_) => json({'login': 'pingu', 'id': 7}));
    expect(await client.fetchViewerLogin(token), 'pingu');
    expect(requests.single.url.path, '/user');
  });

  group('fetchOpenPullRequestSizes', () {
    const repository = GitHubRepository(owner: 'penguin', repo: 'colony');

    Map<String, dynamic> sizes(List<Object?> nodes) => {
      'data': {
        'repository': {
          'pullRequests': {'nodes': nodes},
        },
      },
    };

    test(
      'posts one GraphQL query for the repository, with the token, and reads '
      'the sizes by number',
      () async {
        final client = clientWith(
          (_) => json(
            sizes([
              {'number': 214, 'additions': 86, 'deletions': 12},
              {'number': 212, 'additions': 1144, 'deletions': 105},
            ]),
          ),
        );

        final result = await client.fetchOpenPullRequestSizes(
          repository,
          token: token,
        );

        expect(result, {
          214: (additions: 86, deletions: 12),
          212: (additions: 1144, deletions: 105),
        });
        final request = requests.single;
        expect(request.method, 'POST');
        expect(request.url, Uri.https('api.github.com', '/graphql'));
        expect(request.headers['Authorization'], 'Bearer $token');
        expect(request.followRedirects, isFalse);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['variables'], {'owner': 'penguin', 'name': 'colony'});
        expect(body['query'], contains('additions deletions'));
      },
    );

    test('a node GitHub could not resolve is skipped', () async {
      final client = clientWith(
        (_) => json(
          sizes([
            null,
            {'number': 9, 'additions': 1, 'deletions': 0},
          ]),
        ),
      );

      expect(
        await client.fetchOpenPullRequestSizes(repository, token: token),
        {9: (additions: 1, deletions: 0)},
      );
    });

    test(
      'a GraphQL error, answered with a 200 and no data, is an invalid '
      'response',
      () async {
        final client = clientWith(
          (_) => json({
            'data': null,
            'errors': [
              {'type': 'FORBIDDEN'},
            ],
          }),
        );

        expect(
          await failureOf(
            client.fetchOpenPullRequestSizes(repository, token: token),
          ),
          GitHubFailureKind.invalidResponse,
        );
      },
    );

    test('a post is never answered from the cache', () async {
      final client = clientWith(
        (_) => json(sizes([]), headers: {'etag': '"same"'}),
      );

      await client.fetchOpenPullRequestSizes(repository, token: token);
      await client.fetchOpenPullRequestSizes(repository, token: token);

      expect(requests, hasLength(2));
      expect(requests.last.headers, isNot(contains('If-None-Match')));
    });

    test(
      'an exhausted GraphQL limit blocks GraphQL only: REST links and '
      'refreshes keep calling',
      () async {
        final reset = now.add(const Duration(minutes: 30));
        final client = clientWith(
          (request) => request.url.path == '/graphql'
              ? json(
                  {'message': 'API rate limit exceeded'},
                  status: 403,
                  headers: {
                    'x-ratelimit-remaining': '0',
                    'x-ratelimit-reset':
                        '${reset.millisecondsSinceEpoch ~/ 1000}',
                  },
                )
              : json({'login': 'pingu'}),
        );

        await withClock(Clock.fixed(now), () async {
          expect(
            await failureOf(
              client.fetchOpenPullRequestSizes(repository, token: token),
            ),
            GitHubFailureKind.rateLimited,
          );
          expect(await client.fetchViewerLogin(token), 'pingu');
          // GraphQL itself waits for its reset, without asking GitHub.
          expect(
            await failureOf(
              client.fetchOpenPullRequestSizes(repository, token: token),
            ),
            GitHubFailureKind.rateLimited,
          );
        });
        expect(requests.map((r) => r.url.path), ['/graphql', '/user']);
      },
    );

    test('an exhausted REST limit does not block the size query', () async {
      final reset = now.add(const Duration(minutes: 30));
      final client = clientWith(
        (request) => request.url.path == '/graphql'
            ? json(sizes([]))
            : json(
                {'message': 'API rate limit exceeded'},
                status: 403,
                headers: {
                  'x-ratelimit-remaining': '0',
                  'x-ratelimit-reset':
                      '${reset.millisecondsSinceEpoch ~/ 1000}',
                },
              ),
      );

      await withClock(Clock.fixed(now), () async {
        await failureOf(client.fetchViewerLogin(token));
        expect(
          await client.fetchOpenPullRequestSizes(repository, token: token),
          isEmpty,
        );
      });
    });
  });
}
