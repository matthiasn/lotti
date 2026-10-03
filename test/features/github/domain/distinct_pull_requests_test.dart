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
  }) {
    final e = prEntry(clock: {'a': 1}, id: id, deleted: deleted);
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

  test('orders by number, then by repository', () {
    expect(
      ids(
        distinctPullRequests([
          pr('x', number: 9),
          pr('y', number: 3, repo: 'zeta'),
          pr('z', number: 3, repo: 'alpha'),
        ]),
      ),
      ['z', 'y', 'x'],
    );
  });
}
