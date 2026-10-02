import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/domain/pull_request_write_rule.dart';

import '../pull_request_fixtures.dart';

void main() {
  final restampSeconds = pullRequestRestampAfter.inSeconds;

  bool writes({
    required PullRequestSnapshot observation,
    PullRequestSnapshot? stored,
    bool deleted = false,
  }) => shouldWritePullRequestObservation(
    prEntry(clock: {'a': 1}, snapshot: stored, deleted: deleted),
    observation,
  );

  test('the first observation is always written', () {
    expect(writes(observation: prSnapshot()), isTrue);
  });

  test('a newer, changed observation is written', () {
    expect(
      writes(
        stored: prSnapshot(),
        observation: prSnapshot(
          second: 5,
          checks: PullRequestCheckRollup.failing,
        ),
      ),
      isTrue,
    );
  });

  test(
    'an unchanged observation is not written until the stored stamp is '
    'old: every write notifies the task, and would wake its agent',
    () {
      expect(
        writes(
          stored: prSnapshot(),
          observation: prSnapshot(second: restampSeconds - 1),
        ),
        isFalse,
      );
      expect(
        writes(
          stored: prSnapshot(),
          observation: prSnapshot(second: restampSeconds),
        ),
        isTrue,
      );
    },
  );

  test('an older or equal observation is never written (GuardNewer)', () {
    final stored = prSnapshot(second: 10, status: PullRequestStatus.merged);
    expect(writes(stored: stored, observation: prSnapshot()), isFalse);
    expect(writes(stored: stored, observation: stored), isFalse);
    // Same second: merged is the later state, so open never replaces it.
    expect(
      writes(stored: stored, observation: prSnapshot(second: 10)),
      isFalse,
    );
  });

  test('an unlinked entry is never written (GuardDeleted)', () {
    expect(
      writes(
        stored: prSnapshot(),
        observation: prSnapshot(second: 5, title: 'Changed'),
        deleted: true,
      ),
      isFalse,
    );
  });
}
