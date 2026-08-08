import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_window.dart';

void main() {
  DateTime d(int year, int month, int day) => DateTime.utc(year, month, day);

  group('dayUtc', () {
    test('collapses instants to their calendar date at midnight UTC', () {
      expect(GoalWindow.dayUtc(DateTime(2026, 8, 8, 23, 45)), d(2026, 8, 8));
      expect(
        GoalWindow.dayUtc(DateTime.utc(2026, 8, 8, 0, 0, 1)),
        d(2026, 8, 8),
      );
      expect(GoalWindow.dayUtc(d(2026, 8, 8)), d(2026, 8, 8));
    });
  });

  group('periodRange', () {
    test('day window is a single day', () {
      final range = const GoalWindow.day().periodRange(d(2026, 8, 8));
      expect(range.start, d(2026, 8, 8));
      expect(range.end, d(2026, 8, 8));
    });

    test('rolling window trails inclusive of the reference day', () {
      final range = const GoalWindow.rollingDays(
        count: 7,
      ).periodRange(d(2026, 8, 8));
      expect(range.start, d(2026, 8, 2));
      expect(range.end, d(2026, 8, 8));
    });

    test('calendar week runs Monday through Sunday', () {
      // 2026-08-08 is a Saturday.
      final range = const GoalWindow.calendarWeek().periodRange(d(2026, 8, 8));
      expect(range.start, d(2026, 8, 3));
      expect(range.end, d(2026, 8, 9));
      expect(range.start.weekday, DateTime.monday);
      expect(range.end.weekday, DateTime.sunday);
    });

    test('calendar week referenced on a Monday starts that day', () {
      final range = const GoalWindow.calendarWeek().periodRange(d(2026, 8, 3));
      expect(range.start, d(2026, 8, 3));
    });

    test('calendar month handles short months and year end', () {
      final feb = const GoalWindow.calendarMonth().periodRange(d(2026, 2, 15));
      expect(feb.start, d(2026, 2, 1));
      expect(feb.end, d(2026, 2, 28));

      final dec = const GoalWindow.calendarMonth().periodRange(d(2026, 12, 31));
      expect(dec.start, d(2026, 12, 1));
      expect(dec.end, d(2026, 12, 31));
    });
  });

  group('lengthInDays / elapsedDays', () {
    test('week is 7 days, elapsed counts inclusively', () {
      const window = GoalWindow.calendarWeek();
      // 2026-08-05 is a Wednesday.
      expect(window.lengthInDays(d(2026, 8, 5)), 7);
      expect(window.elapsedDays(d(2026, 8, 5)), 3);
    });

    test('rolling window is always fully elapsed', () {
      const window = GoalWindow.rollingDays(count: 10);
      expect(window.lengthInDays(d(2026, 8, 8)), 10);
      expect(window.elapsedDays(d(2026, 8, 8)), 10);
    });

    test('month elapsed matches the day of month', () {
      const window = GoalWindow.calendarMonth();
      expect(window.lengthInDays(d(2026, 2, 10)), 28);
      expect(window.elapsedDays(d(2026, 2, 10)), 10);
    });
  });

  group('periodKey', () {
    test('day and rolling windows key on the reference date', () {
      expect(const GoalWindow.day().periodKey(d(2026, 8, 8)), '2026-08-08');
      expect(
        const GoalWindow.rollingDays(count: 7).periodKey(d(2026, 8, 8)),
        '2026-08-08',
      );
    });

    test('calendar week uses ISO week numbering', () {
      expect(
        const GoalWindow.calendarWeek().periodKey(d(2026, 8, 8)),
        '2026-W32',
      );
    });

    test('ISO week year boundaries attribute to the Thursday year', () {
      // 2025-12-31 is a Wednesday whose week's Thursday is 2026-01-01.
      expect(
        const GoalWindow.calendarWeek().periodKey(d(2025, 12, 31)),
        '2026-W01',
      );
      // 2027-01-01 is a Friday whose week's Thursday is 2026-12-31 — 2026
      // is a 53-week ISO year.
      expect(
        const GoalWindow.calendarWeek().periodKey(d(2027, 1, 1)),
        '2026-W53',
      );
    });

    test('calendar month key is zero-padded year-month', () {
      expect(
        const GoalWindow.calendarMonth().periodKey(d(2026, 8, 8)),
        '2026-08',
      );
      expect(
        const GoalWindow.calendarMonth().periodKey(d(2026, 1, 3)),
        '2026-01',
      );
    });
  });

  test('a non-positive rolling count fails loudly, not with a bad range', () {
    // Only malformed synced JSON can produce this; an inverted period must
    // never reach the evaluator.
    expect(
      () => const GoalWindow.rollingDays(count: 0).periodRange(d(2026, 8, 8)),
      throwsArgumentError,
    );
    expect(
      () => GoalWindow.fromJson(
        const {'runtimeType': 'rollingDays', 'count': -3},
      ).periodRange(d(2026, 8, 8)),
      throwsArgumentError,
    );
  });

  test('json round trip preserves the window', () {
    const windows = [
      GoalWindow.day(),
      GoalWindow.rollingDays(count: 7),
      GoalWindow.calendarWeek(),
      GoalWindow.calendarMonth(),
    ];
    for (final window in windows) {
      expect(GoalWindow.fromJson(window.toJson()), window);
    }
  });
}
