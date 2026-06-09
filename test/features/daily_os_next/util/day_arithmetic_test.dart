import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/daily_os_next/util/day_arithmetic.dart';

void main() {
  group('daysBetween', () {
    test('same calendar day is zero regardless of time of day', () {
      expect(
        daysBetween(
          DateTime(2024, 3, 15, 9, 30),
          DateTime(2024, 3, 15, 22, 15),
        ),
        0,
      );
    });

    test('next day is +1, previous day is -1', () {
      expect(daysBetween(DateTime(2024, 3, 15), DateTime(2024, 3, 16)), 1);
      expect(daysBetween(DateTime(2024, 3, 16), DateTime(2024, 3, 15)), -1);
    });

    test('time of day does not affect the count across a day boundary', () {
      // 23:59 to 00:01 the next day is barely two minutes but one calendar day.
      expect(
        daysBetween(DateTime(2024, 3, 15, 23, 59), DateTime(2024, 3, 16, 0, 1)),
        1,
      );
    });

    test('counts across months and years', () {
      expect(daysBetween(DateTime(2024, 1, 31), DateTime(2024, 2)), 1);
      expect(daysBetween(DateTime(2023, 12, 31), DateTime(2024)), 1);
    });

    test('DST spring-forward is counted as a full calendar day', () {
      // US spring-forward: 2024-03-10 is only 23 local hours. A local
      // difference().inDays would under-count Jan 1 -> Apr 1 by one; UTC-date
      // math counts the full span.
      expect(daysBetween(DateTime(2024), DateTime(2024, 4)), 91);
    });
  });

  // ---------------------------------------------------------------------------
  // Property: antisymmetric, ignores time-of-day, and matches a calendar-day
  // oracle even across the DST spring-forward boundary.
  // ---------------------------------------------------------------------------
  group('daysBetween — properties', () {
    glados.Glados2(
      glados.any.intInRange(0, 365),
      glados.any.intInRange(0, 365),
      glados.ExploreConfig(numRuns: 120),
    ).test('antisymmetric and ignores time-of-day', (a, b) {
      // Date-only arithmetic on calendar days built from components is
      // DST-safe; mixing in hours proves the date-only truncation.
      final d1 = DateTime(2024, 1, 1 + a, 9, 30);
      final d2 = DateTime(2024, 1, 1 + b, 22, 15);

      final forward = daysBetween(d1, d2);
      final backward = daysBetween(d2, d1);

      expect(forward, -backward, reason: 'a=$a b=$b');
      expect(forward, b - a, reason: 'calendar-day oracle');
      // Same calendar day, any times -> zero.
      expect(
        daysBetween(
          DateTime(2024, 1, 1 + a),
          DateTime(2024, 1, 1 + a, 23, 59),
        ),
        0,
      );
    }, tags: 'glados');
  });
}
