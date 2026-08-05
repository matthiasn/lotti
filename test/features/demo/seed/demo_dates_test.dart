import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/demo/seed/demo_dates.dart';

void main() {
  group('DemoDates', () {
    // A Friday at 23:10 — the hostile case the helper exists for: any
    // fixture expressed as "now + a few hours" would spill into tomorrow.
    final lateFriday = DateTime(2026, 7, 17, 23, 10);

    test('today/tomorrow snap to the anchor day, not to the anchor time', () {
      final dates = DemoDates(lateFriday);

      expect(dates.today(17), DateTime(2026, 7, 17, 17));
      expect(dates.today(14, 30), DateTime(2026, 7, 17, 14, 30));
      expect(dates.tomorrow(9), DateTime(2026, 7, 18, 9));
      // The point of snapping: a due-today value stays on today's date even
      // when the world is built ten minutes before midnight.
      expect(dates.today(17).day, lateFriday.day);
    });

    test('inDays rolls across month and year boundaries', () {
      final dates = DemoDates(DateTime(2026, 12, 30, 8));

      expect(dates.inDays(3, 9), DateTime(2027, 1, 2, 9));
      expect(dates.inDays(-31, 9), DateTime(2026, 11, 29, 9));
    });

    test('overdue and daysAgo land whole days back, never on today', () {
      final dates = DemoDates(lateFriday);

      expect(dates.overdue(2), DateTime(2026, 7, 15, 17));
      expect(dates.overdue(5, 12), DateTime(2026, 7, 12, 12));
      expect(dates.daysAgo(6), DateTime(2026, 7, 11, 9));
      expect(dates.overdue(1).isBefore(lateFriday), isTrue);
    });

    test('overdue asserts its stated minimum rather than silently returning '
        'today or a future date', () {
      final dates = DemoDates(lateFriday);

      // overdue(0) would be today at 17:00 and overdue(-1) tomorrow — both
      // read as "not overdue" in the UI, which is the one thing the helper
      // promises can never happen.
      expect(() => dates.overdue(0), throwsA(isA<AssertionError>()));
      expect(() => dates.overdue(-1), throwsA(isA<AssertionError>()));
      expect(dates.overdue(1), isNot(throwsA(anything)));
    });

    test('nextMonday is the Monday strictly after today, on every weekday', () {
      // Monday 2026-07-13 through Sunday 2026-07-19.
      const expected = {
        13: 20, // Monday -> the following Monday, never today
        14: 20,
        15: 20,
        16: 20,
        17: 20,
        18: 20,
        19: 20,
      };
      for (final entry in expected.entries) {
        final dates = DemoDates(DateTime(2026, 7, entry.key, 10));
        final monday = dates.nextMonday(9);
        expect(monday.weekday, DateTime.monday, reason: 'day ${entry.key}');
        expect(monday, DateTime(2026, 7, entry.value, 9));
        expect(monday.isAfter(dates.now), isTrue);
      }
    });

    test('nextMonday(plusDays:) stays inside the following week', () {
      final dates = DemoDates(DateTime(2026, 7, 17, 10));

      expect(dates.nextMonday(12, plusDays: 2), DateTime(2026, 7, 22, 12));
    });

    test('pastWeekday skips weekends', () {
      // Monday 2026-07-20: the three previous weekdays are Fri/Thu/Wed.
      final dates = DemoDates(DateTime(2026, 7, 20, 10));

      expect(dates.pastWeekday(1), DateTime(2026, 7, 17, 9));
      expect(dates.pastWeekday(2), DateTime(2026, 7, 16, 9));
      expect(dates.pastWeekday(3), DateTime(2026, 7, 15, 9));
      expect(dates.pastWeekday(4, 14), DateTime(2026, 7, 14, 14));
    });

    test('pastWeekday returns only weekdays, however far back it counts', () {
      final dates = DemoDates(DateTime(2026, 7, 19, 10)); // a Sunday

      for (var n = 1; n <= 20; n++) {
        final day = dates.pastWeekday(n);
        expect(
          day.weekday,
          lessThanOrEqualTo(DateTime.friday),
          reason: 'pastWeekday($n) landed on a weekend',
        );
        expect(day.isBefore(dates.now), isTrue);
      }
      // Strictly decreasing: each step goes one weekday further back.
      expect(dates.pastWeekday(20).isBefore(dates.pastWeekday(19)), isTrue);
    });
  });
}
