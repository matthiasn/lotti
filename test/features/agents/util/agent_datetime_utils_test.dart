import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/util/agent_datetime_utils.dart';

void main() {
  group('isSameDay', () {
    test('same calendar day with different times is true', () {
      expect(
        isSameDay(DateTime(2026, 3, 15, 8, 30), DateTime(2026, 3, 15, 23, 59)),
        isTrue,
      );
    });

    test('midnight boundaries of the same day are the same day', () {
      expect(
        isSameDay(DateTime(2026, 3, 15), DateTime(2026, 3, 15, 0, 0, 0, 0, 1)),
        isTrue,
      );
    });

    test('consecutive days are not the same day', () {
      expect(
        isSameDay(DateTime(2026, 3, 15, 23, 59), DateTime(2026, 3, 16, 0, 1)),
        isFalse,
      );
    });

    test('same day-of-month in different months is not the same day', () {
      expect(isSameDay(DateTime(2026, 3, 15), DateTime(2026, 4, 15)), isFalse);
    });

    test('same month/day in different years is not the same day', () {
      expect(isSameDay(DateTime(2025, 3, 15), DateTime(2026, 3, 15)), isFalse);
    });

    test('DST spring-forward day stays the same calendar day', () {
      // US spring-forward 2026-03-08: the 2:00–3:00 local hour is skipped, but
      // both timestamps are still on the same calendar day.
      expect(
        isSameDay(DateTime(2026, 3, 8, 1, 30), DateTime(2026, 3, 8, 4, 30)),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Property: same-day iff the calendar date matches, regardless of time of
  // day; reflexive, symmetric, and strict across a whole-day boundary.
  // ---------------------------------------------------------------------------
  group('isSameDay — properties', () {
    glados.Glados3(
      glados.IntAnys(glados.any).intInRange(0, 730),
      glados.IntAnys(glados.any).intInRange(0, 1440),
      glados.IntAnys(glados.any).intInRange(0, 1440),
      glados.ExploreConfig(numRuns: 120),
    ).test('same-day iff the calendar date matches, regardless of time', (
      dayOffset,
      minutesA,
      minutesB,
    ) {
      final base = DateTime(2026).add(Duration(days: dayOffset));
      final a = base.add(Duration(minutes: minutesA));
      final b = base.add(Duration(minutes: minutesB));

      final sameCalendarDay =
          a.year == b.year && a.month == b.month && a.day == b.day;
      expect(isSameDay(a, b), sameCalendarDay, reason: '$a vs $b');
      // Symmetry + reflexivity.
      expect(isSameDay(b, a), isSameDay(a, b));
      expect(isSameDay(a, a), isTrue);

      // Crossing a whole day always breaks the predicate.
      expect(isSameDay(a, a.add(const Duration(days: 1))), isFalse);
    }, tags: 'glados');
  });
}
