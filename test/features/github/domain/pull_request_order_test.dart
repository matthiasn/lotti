import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/features/github/domain/pull_request_order.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import '../pull_request_fixtures.dart';

void main() {
  group('pullRequestSnapshotDigest -', () {
    test('ignores when the state was observed', () {
      expect(
        pullRequestSnapshotDigest(prSnapshot()),
        pullRequestSnapshotDigest(prSnapshot(second: 90)),
      );
    });

    test(
      'ignores when the pull request was opened, so a version that does not '
      'know the field orders observations the same way',
      () {
        final legacy = prSnapshot().copyWith(createdAt: null);
        expect(
          pullRequestSnapshotDigest(prSnapshot()),
          pullRequestSnapshotDigest(legacy),
        );
        expect(
          pullRequestSnapshotDigest(
            prSnapshot(createdAt: DateTime.utc(2020)),
          ),
          pullRequestSnapshotDigest(legacy),
        );
      },
    );

    test(
      'ignores the comment counts, so a version that does not know them '
      'orders observations the same way, and a new comment alone is no '
      'change',
      () {
        final counted = prSnapshot().copyWith(comments: 7, reviewComments: 23);
        expect(
          pullRequestSnapshotDigest(counted),
          pullRequestSnapshotDigest(prSnapshot()),
        );
        expect(
          pullRequestSnapshotDigest(counted.copyWith(comments: 8)),
          pullRequestSnapshotDigest(counted),
        );
      },
    );

    test(
      'a snapshot stored before it carried the comment counts reads them as '
      'unknown, and an unknown count is no field at all',
      () {
        Map<String, dynamic> stored(PullRequestSnapshot s) =>
            jsonDecode(jsonEncode(s)) as Map<String, dynamic>;
        final legacy = stored(prSnapshot());
        expect(legacy.containsKey('comments'), isFalse);
        expect(legacy.containsKey('reviewComments'), isFalse);
        final read = PullRequestSnapshot.fromJson(legacy);
        expect((read.comments, read.reviewComments), (null, null));

        final counted = stored(
          prSnapshot().copyWith(comments: 7, reviewComments: 23),
        );
        final readCounted = PullRequestSnapshot.fromJson(counted);
        expect((readCounted.comments, readCounted.reviewComments), (7, 23));
      },
    );

    test(
      'a snapshot stored before it carried the opening reads it as unknown, '
      'and writes no field for it',
      () {
        // As the entry is stored: JSON text, nested objects and all.
        Map<String, dynamic> stored(PullRequestSnapshot s) =>
            jsonDecode(jsonEncode(s)) as Map<String, dynamic>;
        final legacy = stored(prSnapshot().copyWith(createdAt: null));
        expect(legacy.containsKey('createdAt'), isFalse);

        final read = PullRequestSnapshot.fromJson(legacy);
        expect(read.createdAt, isNull);
        expect(read.title, 'Track pull requests');
        expect(
          PullRequestSnapshot.fromJson(stored(prSnapshot())).createdAt,
          prFixtureEpoch,
        );
      },
    );

    test('changes with any part of the state, nested ones included', () {
      final base = pullRequestSnapshotDigest(prSnapshot());
      expect(
        {
          pullRequestSnapshotDigest(prSnapshot(title: 'Other')),
          pullRequestSnapshotDigest(prSnapshot(headSha: 'bbbbbbb')),
          pullRequestSnapshotDigest(
            prSnapshot(checks: PullRequestCheckRollup.passing),
          ),
          pullRequestSnapshotDigest(
            prSnapshot(status: PullRequestStatus.merged),
          ),
        },
        hasLength(4),
      );
      expect(
        pullRequestSnapshotDigest(prSnapshot(title: 'Other')),
        isNot(base),
      );
      expect(
        pullRequestSnapshotDigest(
          prSnapshot(checks: PullRequestCheckRollup.failing),
        ),
        isNot(base),
      );
    });

    test('is a SHA-256 in hex', () {
      expect(
        pullRequestSnapshotDigest(prSnapshot()),
        matches(RegExp(r'^[0-9a-f]{64}$')),
      );
    });
  });

  group('comparePullRequestObservations -', () {
    test('a later server stamp is newer, whatever it shows', () {
      final merged = prSnapshot(status: PullRequestStatus.merged);
      final laterOpen = prSnapshot(second: 1);
      expect(comparePullRequestObservations(laterOpen, merged), greaterThan(0));
      expect(comparePullRequestObservations(merged, laterOpen), lessThan(0));
    });

    test(
      'within one stamp, merged is newer: a merge is final, so the read '
      'that saw it came after the one that did not',
      () {
        final open = prSnapshot();
        final merged = prSnapshot(status: PullRequestStatus.merged);
        // The digest alone would order these one way or the other; the merged
        // rank must decide before it does.
        expect(comparePullRequestObservations(merged, open), greaterThan(0));
        expect(comparePullRequestObservations(open, merged), lessThan(0));
      },
    );

    test('same stamp and rank: the digest decides, the same both ways', () {
      final a = prSnapshot(checks: PullRequestCheckRollup.passing);
      final b = prSnapshot(checks: PullRequestCheckRollup.failing);
      final ab = comparePullRequestObservations(a, b);
      expect(ab, isNot(0));
      expect(comparePullRequestObservations(b, a), -ab.sign);
      expect(
        ab.sign,
        pullRequestSnapshotDigest(a).compareTo(pullRequestSnapshotDigest(b)),
      );
    });

    test('the same observation is equal to itself', () {
      expect(comparePullRequestObservations(prSnapshot(), prSnapshot()), 0);
    });

    test('no observation is older than any', () {
      expect(comparePullRequestObservations(null, prSnapshot()), lessThan(0));
      expect(
        comparePullRequestObservations(prSnapshot(), null),
        greaterThan(0),
      );
      expect(comparePullRequestObservations(null, null), 0);
    });
  });

  group('isProvablyLaterObservation -', () {
    test('a later second of the server clock is later', () {
      expect(
        isProvablyLaterObservation(
          prSnapshot(second: 2),
          prSnapshot(second: 1),
        ),
        isTrue,
      );
      expect(
        isProvablyLaterObservation(
          prSnapshot(second: 1),
          prSnapshot(second: 2),
        ),
        isFalse,
      );
    });

    test(
      'within one second only a merge proves order, never the digest',
      () {
        final open = prSnapshot(checks: PullRequestCheckRollup.failing);
        final otherOpen = prSnapshot(checks: PullRequestCheckRollup.passing);
        final merged = prSnapshot(status: PullRequestStatus.merged);
        expect(isProvablyLaterObservation(merged, open), isTrue);
        expect(isProvablyLaterObservation(open, merged), isFalse);
        expect(isProvablyLaterObservation(otherOpen, open), isFalse);
        expect(isProvablyLaterObservation(open, otherOpen), isFalse);
      },
    );

    test('milliseconds within one second do not count', () {
      final early = prSnapshot();
      final late = early.copyWith(
        observedAt: early.observedAt.add(const Duration(milliseconds: 900)),
      );
      expect(isProvablyLaterObservation(late, early), isFalse);
    });
  });

  group('mergeConcurrentPullRequestVersions -', () {
    test('keeps the newer observation under the join of both clocks', () {
      final older = prEntry(clock: {'a': 2}, snapshot: prSnapshot());
      final newer = prEntry(
        clock: {'b': 1},
        snapshot: prSnapshot(second: 5, checks: PullRequestCheckRollup.failing),
      );

      final merged = mergeConcurrentPullRequestVersions(older, newer);

      expect(merged.data.snapshot, newer.data.snapshot);
      expect(merged.meta.vectorClock, const VectorClock({'a': 2, 'b': 1}));
      expect(merged.meta.deletedAt, isNull);
    });

    test(
      'an unlink beats a newer concurrent refresh: the entry stays deleted, '
      'with the newer snapshot',
      () {
        final unlinked = prEntry(
          clock: {'a': 2},
          snapshot: prSnapshot(),
          deleted: true,
        );
        final refreshed = prEntry(
          clock: {'b': 1},
          snapshot: prSnapshot(second: 5),
        );

        for (final merged in [
          mergeConcurrentPullRequestVersions(unlinked, refreshed),
          mergeConcurrentPullRequestVersions(refreshed, unlinked),
        ]) {
          expect(merged.meta.deletedAt, unlinked.meta.deletedAt);
          expect(merged.data.snapshot, refreshed.data.snapshot);
        }
      },
    );

    test('a first observation beats a version that has none', () {
      final linked = prEntry(clock: {'a': 1});
      final observed = prEntry(clock: {'b': 1}, snapshot: prSnapshot());
      expect(
        mergeConcurrentPullRequestVersions(linked, observed).data.snapshot,
        observed.data.snapshot,
      );
    });

    test('the same observation on both sides: the clock key decides', () {
      final a = prEntry(clock: {'a': 1}, snapshot: prSnapshot());
      final b = prEntry(clock: {'b': 1}, snapshot: prSnapshot());
      final ab = mergeConcurrentPullRequestVersions(a, b);
      final ba = mergeConcurrentPullRequestVersions(b, a);
      expect(ab, ba);
      expect(ab.meta.vectorClock, const VectorClock({'a': 1, 'b': 1}));
    });

    glados.Glados2<int, int>(
      glados.any.intInRange(0, 64),
      glados.any.intInRange(0, 64),
    ).test(
      'every device computes the same row, whichever version it held first',
      (left, right) {
        PullRequestEntry version(int seed, String host) => prEntry(
          clock: {host: 1 + seed % 3},
          snapshot: seed % 5 == 0
              ? null
              : prSnapshot(
                  second: seed % 4,
                  status: PullRequestStatus.values[seed % 3],
                  checks: PullRequestCheckRollup.values[seed % 4],
                ),
          deleted: seed % 7 == 0,
        );
        final a = version(left, 'a');
        final b = version(right, 'b');

        final ab = mergeConcurrentPullRequestVersions(a, b);
        final ba = mergeConcurrentPullRequestVersions(b, a);

        expect(ab, ba);
        // The newer observation, never the older (NoRegression).
        expect(
          comparePullRequestObservations(ab.data.snapshot, a.data.snapshot),
          greaterThanOrEqualTo(0),
        );
        expect(
          comparePullRequestObservations(ab.data.snapshot, b.data.snapshot),
          greaterThanOrEqualTo(0),
        );
        // An unlink on either side survives (UnlinkIsFinal).
        expect(ab.isDeleted, a.isDeleted || b.isDeleted);
      },
      tags: 'glados',
    );
  });
}
