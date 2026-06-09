import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/notifications/model/notification_merge.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'notification_merge_test_helpers.dart';

void main() {
  group('NotificationMerge', () {
    test('mergeState preserves vector clock when patch clock is null', () {
      final base = buildNotification(
        id: 'state-null-clock',
      );

      final merged = NotificationMerge.mergeState(
        base,
        seenAt: DateTime.utc(2026, 5, 17, 10),
      );

      expect(merged.meta.vectorClock, const VectorClock({'base': 1}));
      expect(merged.meta.seenAt, DateTime.utc(2026, 5, 17, 10));
    });

    glados.Glados(
      glados.any.notificationStateMergeScenario,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'mergeState keeps earliest state fields and merged clocks',
      (scenario) {
        final firstThenSecond = NotificationMerge.mergeState(
          NotificationMerge.mergeState(
            scenario.base,
            seenAt: scenario.first.seenAt,
            actedOnAt: scenario.first.actedOnAt,
            deletedAt: scenario.first.deletedAt,
            vectorClock: scenario.first.vectorClock,
            originatingHostId: scenario.first.originatingHostId,
          ),
          seenAt: scenario.second.seenAt,
          actedOnAt: scenario.second.actedOnAt,
          deletedAt: scenario.second.deletedAt,
          vectorClock: scenario.second.vectorClock,
          originatingHostId: scenario.second.originatingHostId,
        );
        final secondThenFirst = NotificationMerge.mergeState(
          NotificationMerge.mergeState(
            scenario.base,
            seenAt: scenario.second.seenAt,
            actedOnAt: scenario.second.actedOnAt,
            deletedAt: scenario.second.deletedAt,
            vectorClock: scenario.second.vectorClock,
            originatingHostId: scenario.second.originatingHostId,
          ),
          seenAt: scenario.first.seenAt,
          actedOnAt: scenario.first.actedOnAt,
          deletedAt: scenario.first.deletedAt,
          vectorClock: scenario.first.vectorClock,
          originatingHostId: scenario.first.originatingHostId,
        );
        final firstOnce = NotificationMerge.mergeState(
          scenario.base,
          seenAt: scenario.first.seenAt,
          actedOnAt: scenario.first.actedOnAt,
          deletedAt: scenario.first.deletedAt,
          vectorClock: scenario.first.vectorClock,
          originatingHostId: scenario.first.originatingHostId,
        );
        final firstTwice = NotificationMerge.mergeState(
          firstOnce,
          seenAt: scenario.first.seenAt,
          actedOnAt: scenario.first.actedOnAt,
          deletedAt: scenario.first.deletedAt,
          vectorClock: scenario.first.vectorClock,
          originatingHostId: scenario.first.originatingHostId,
        );

        expectStateAndClock(
          firstThenSecond,
          scenario.expectedSeenAt,
          scenario.expectedActedOnAt,
          scenario.expectedDeletedAt,
          scenario.expectedStateVectorClock,
          reason: '$scenario',
        );
        expectStateAndClock(
          secondThenFirst,
          scenario.expectedSeenAt,
          scenario.expectedActedOnAt,
          scenario.expectedDeletedAt,
          scenario.expectedStateVectorClock,
          reason: '$scenario',
        );
        expectContentMatches(firstThenSecond, scenario.base);
        expectContentMatches(secondThenFirst, scenario.base);
        expect(
          NotificationMerge.same(firstOnce, firstTwice),
          isTrue,
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.notificationFullMergeScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test(
      'mergeFull is deterministic and merges independent state',
      (scenario) {
        final forward = NotificationMerge.mergeFull(
          scenario.existing,
          scenario.incoming,
        );
        final reverse = NotificationMerge.mergeFull(
          scenario.incoming,
          scenario.existing,
        );
        final idempotent = NotificationMerge.mergeFull(
          forward,
          scenario.incoming,
        );

        expect(
          NotificationMerge.same(forward, reverse),
          isTrue,
          reason: '$scenario',
        );
        expect(
          NotificationMerge.same(forward, idempotent),
          isTrue,
          reason: '$scenario',
        );
        expectStateAndClock(
          forward,
          scenario.expectedSeenAt,
          scenario.expectedActedOnAt,
          scenario.expectedDeletedAt,
          scenario.expectedFullVectorClock,
          reason: '$scenario',
        );

        final expectedWinner = scenario.updatedAtWinner;
        if (expectedWinner != null) {
          expectContentMatches(forward, expectedWinner);
          expect(
            forward.meta.originatingHostId,
            expectedWinner.meta.originatingHostId,
            reason: '$scenario',
          );
        }
      },
      tags: 'glados',
    );

    group('earliestNonNull — algebraic properties', () {
      DateTime? fromSlot(int slot) =>
          slot == 0 ? null : DateTime.utc(2026, 5, 17, 9, slot % 60);

      glados.Glados2<int, int>(
        glados.IntAnys(glados.any).intInRange(0, 60),
        glados.IntAnys(glados.any).intInRange(0, 60),
        glados.ExploreConfig(numRuns: 150),
      ).test(
        'commutative, idempotent, null-identity, and result-membership',
        (slotA, slotB) {
          final a = fromSlot(slotA);
          final b = fromSlot(slotB);

          final ab = NotificationMerge.earliestNonNull(a, b);
          final ba = NotificationMerge.earliestNonNull(b, a);
          expect(ab, ba, reason: 'commutativity a=$a b=$b');

          expect(NotificationMerge.earliestNonNull(a, a), a, reason: 'idem');
          expect(NotificationMerge.earliestNonNull(a, null), a);
          expect(NotificationMerge.earliestNonNull(null, b), b);

          // Result is always one of the inputs, and ≤ each non-null input.
          expect(ab == a || ab == b, isTrue);
          if (ab != null) {
            if (a != null) expect(ab.isAfter(a), isFalse);
            if (b != null) expect(ab.isAfter(b), isFalse);
          }
        },
        tags: 'glados',
      );

      glados.Glados3<int, int, int>(
        glados.IntAnys(glados.any).intInRange(0, 60),
        glados.IntAnys(glados.any).intInRange(0, 60),
        glados.IntAnys(glados.any).intInRange(0, 60),
        glados.ExploreConfig(numRuns: 150),
      ).test(
        'associative across three operands',
        (slotA, slotB, slotC) {
          final a = fromSlot(slotA);
          final b = fromSlot(slotB);
          final c = fromSlot(slotC);

          expect(
            NotificationMerge.earliestNonNull(
              NotificationMerge.earliestNonNull(a, b),
              c,
            ),
            NotificationMerge.earliestNonNull(
              a,
              NotificationMerge.earliestNonNull(b, c),
            ),
            reason: 'a=$a b=$b c=$c',
          );
        },
        tags: 'glados',
      );
    });
  });
}
