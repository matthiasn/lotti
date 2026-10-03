import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/github/domain/github_repository.dart';
import 'package:lotti/features/github/domain/open_pull_request.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';

void main() {
  const repository = GitHubRepository(owner: 'penguin', repo: 'colony');

  Map<String, dynamic> item({
    Object? updatedAt = '2024-03-15T12:00:00+01:00',
    Object? user = const {'login': 'pingu'},
  }) => {
    'number': 7,
    'title': 'Waddle faster',
    'updated_at': updatedAt,
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
    expect(pr.updatedAt, DateTime.utc(2024, 3, 15, 11));
    expect(pr.updatedAt.isUtc, isTrue);
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

  for (final updatedAt in ['yesterday', 1710500000, null]) {
    test('an update time of $updatedAt is not an open pull request', () {
      expect(
        () => openPullRequestFrom(item(updatedAt: updatedAt), repository),
        throwsFormatException,
      );
    });
  }
}
