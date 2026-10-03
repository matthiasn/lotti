import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/github/domain/distinct_pull_requests.dart';

import '../pull_request_fixtures.dart';

void main() {
  PullRequestEntry pr(
    String id, {
    int number = 42,
    String repo = 'lotti',
    bool deleted = false,
    DateTime? createdAt,
    bool observed = true,
  }) {
    final e = prEntry(
      clock: {'a': 1},
      id: id,
      deleted: deleted,
      snapshot: observed ? prSnapshot().copyWith(createdAt: createdAt) : null,
    );
    return e.copyWith(
      data: e.data.copyWith(number: number, repo: repo),
    );
  }

  List<String> ids(List<PullRequestEntry> entries) => [
    for (final e in entries) e.id,
  ];

  test(
    'keeps one entry per pull request, the lowest id, whichever order the '
    'entries arrive in',
    () {
      final a = pr('b-entry');
      final b = pr('a-entry');
      expect(ids(distinctPullRequests([a, b])), ['a-entry']);
      expect(ids(distinctPullRequests([b, a])), ['a-entry']);
    },
  );

  test('the same pull request in another case is still one', () {
    final upper = pr('b').copyWith(
      data: pr('b').data.copyWith(owner: 'MatthiasN'),
    );
    expect(ids(distinctPullRequests([upper, pr('a')])), ['a']);
  });

  test('unlinked entries are left out, so a live duplicate takes over', () {
    expect(
      ids(distinctPullRequests([pr('a', deleted: true), pr('b')])),
      ['b'],
    );
  });

  test(
    'newest first by when each was opened on GitHub, not by number: a '
    'pull request from another repository sits where its date puts it',
    () {
      expect(
        ids(
          distinctPullRequests([
            pr('old', number: 90, createdAt: DateTime.utc(2026, 3, 2)),
            pr('new', number: 12, createdAt: DateTime.utc(2026, 3, 9)),
            pr(
              'middle',
              number: 3,
              repo: 'zeta',
              createdAt: DateTime.utc(2026, 3, 5),
            ),
          ]),
        ),
        ['new', 'middle', 'old'],
      );
    },
  );

  test(
    'one whose opening is not known yet comes last, highest number first, '
    'then by repository',
    () {
      expect(
        ids(
          distinctPullRequests([
            pr('legacy-3-zeta', number: 3, repo: 'zeta'),
            pr('unread-9', number: 9, observed: false),
            pr('known', number: 1, createdAt: DateTime.utc(2026, 3, 2)),
            pr('legacy-3-alpha', number: 3, repo: 'alpha'),
          ]),
        ),
        ['known', 'unread-9', 'legacy-3-alpha', 'legacy-3-zeta'],
      );
    },
  );
}
