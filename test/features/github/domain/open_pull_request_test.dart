import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/github/github_repository.dart';
import 'package:lotti/classes/github/pull_request_ref.dart';
import 'package:lotti/features/github/domain/open_pull_request.dart';

void main() {
  const repository = GitHubRepository(owner: 'penguin', repo: 'colony');

  Map<String, dynamic> item({
    Object? createdAt = '2024-03-15T12:00:00+01:00',
    Object? user = const {'login': 'pingu'},
  }) => {
    'number': 7,
    'title': 'Waddle faster',
    'created_at': createdAt,
    'user': user,
    'draft': true,
  };

  test('reads an item of the repository, its time in UTC', () {
    final pr = openPullRequestFrom(item(), repository);

    expect(
      pr.ref,
      const PullRequestRef(owner: 'penguin', repo: 'colony', number: 7),
    );
    expect(pr.title, 'Waddle faster');
    expect(pr.createdAt, DateTime.utc(2024, 3, 15, 11));
    expect(pr.createdAt.isUtc, isTrue);
    expect(pr.authorLogin, 'pingu');
    expect(pr.draft, isTrue);
  });

  test('an author that is not a login reads as none', () {
    expect(
      openPullRequestFrom(item(user: {'login': 42}), repository).authorLogin,
      isNull,
    );
    expect(
      openPullRequestFrom(item(user: null), repository).authorLogin,
      isNull,
    );
  });

  for (final createdAt in ['yesterday', 1710500000, null]) {
    test('an opening time of $createdAt is not an open pull request', () {
      expect(
        () => openPullRequestFrom(item(createdAt: createdAt), repository),
        throwsFormatException,
      );
    });
  }

  group('openPullRequestSizesFrom', () {
    test(
      'reads each node by number, skipping one GitHub could not resolve or '
      'that lacks a count',
      () {
        expect(
          openPullRequestSizesFrom({
            'data': {
              'repository': {
                'pullRequests': {
                  'nodes': [
                    {'number': 1, 'additions': 10, 'deletions': 2},
                    null,
                    {'number': 2, 'additions': 5},
                  ],
                },
              },
            },
          }),
          {1: (additions: 10, deletions: 2)},
        );
      },
    );

    test('a response without the list is not one', () {
      expect(
        () => openPullRequestSizesFrom({'data': null, 'errors': <Object>[]}),
        throwsFormatException,
      );
      expect(
        () => openPullRequestSizesFrom({
          'data': {'repository': null},
        }),
        throwsFormatException,
      );
    });
  });
}
