import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

  group('window properties', () {
    String dayKey(DateTime day) =>
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';

    glados.Glados2(
      glados.any.goalWindow,
      glados.any.goalReference,
      glados.ExploreConfig(numRuns: 400),
    ).test(
      'the reference day lies in a well-formed range of the right length',
      (window, reference) {
        final day = GoalWindow.dayUtc(reference);
        final range = window.periodRange(reference);

        expect(range.start.isUtc && range.end.isUtc, isTrue);
        expect(GoalWindow.dayUtc(range.start), range.start);
        expect(GoalWindow.dayUtc(range.end), range.end);
        expect(range.start.isAfter(range.end), isFalse);
        expect(day.isBefore(range.start), isFalse);
        expect(day.isAfter(range.end), isFalse);

        final length = window.lengthInDays(reference);
        switch (window) {
          case GoalWindowDay():
            expect(length, 1);
          case GoalWindowRollingDays(:final count):
            expect(length, count);
          case GoalWindowCalendarWeek():
            expect(length, 7);
            expect(range.start.weekday, DateTime.monday);
          case GoalWindowCalendarMonth():
            expect(length, DateTime.utc(day.year, day.month + 1, 0).day);
            expect(range.start.day, 1);
            expect(range.start.month, day.month);
            expect(range.end.month, day.month);
        }

        final elapsed = window.elapsedDays(reference);
        expect(elapsed, day.difference(range.start).inDays + 1);
        expect(elapsed, inInclusiveRange(1, length));
        expect(window.elapsedDays(range.end), length);
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.goalWindow,
      glados.any.goalReference,
      glados.ExploreConfig(numRuns: 400),
    ).test(
      'every day of a period shares its key and its neighbours do not',
      (window, reference) {
        final range = window.periodRange(reference);
        final key = window.periodKey(reference);

        switch (window) {
          case GoalWindowDay() || GoalWindowRollingDays():
            // Each day anchors its own trailing period.
            expect(key, dayKey(GoalWindow.dayUtc(reference)));
          case GoalWindowCalendarWeek() || GoalWindowCalendarMonth():
            for (
              var day = range.start;
              !day.isAfter(range.end);
              day = day.add(const Duration(days: 1))
            ) {
              expect(window.periodKey(day), key, reason: '$day');
            }
            expect(
              window.periodKey(range.start.subtract(const Duration(days: 1))),
              isNot(key),
            );
            expect(
              window.periodKey(range.end.add(const Duration(days: 1))),
              isNot(key),
            );
        }
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.goalReference,
      glados.ExploreConfig(numRuns: 400),
    ).test(
      'an ISO week is numbered 1–53 in a year at most one away',
      (reference) {
        final day = GoalWindow.dayUtc(reference);
        final match = RegExp(
          r'^(\d{4})-W(\d{2})$',
        ).firstMatch(const GoalWindow.calendarWeek().periodKey(reference))!;
        final isoYear = int.parse(match.group(1)!);
        final week = int.parse(match.group(2)!);

        expect(week, inInclusiveRange(1, 53));
        if (isoYear < day.year) {
          expect((day.month, week >= 52), (1, true));
        } else if (isoYear > day.year) {
          expect((day.month, week), (12, 1));
        } else {
          expect(isoYear, day.year);
        }
        // Week 53 exists only in a year whose 28 December is in it.
        if (week == 53) {
          expect(
            const GoalWindow.calendarWeek().periodKey(
              DateTime.utc(isoYear, 12, 28),
            ),
            '$isoYear-W53',
          );
        }
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.IntAnys(glados.any).intInRange(1, 4000),
      glados.IntAnys(glados.any).intInRange(0, 4),
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'a rolling phrase parses to its count up to a decade, null beyond',
      (count, style) {
        final phrase = switch (style) {
          0 => 'rolling $count days',
          1 => '  ROLLING   $count   DAYS ',
          2 => 'Rolling $count day',
          _ => 'a rolling $count days average',
        };
        expect(
          parseGoalWindowPhrase(phrase),
          count <= maxGoalRollingDays
              ? GoalWindow.rollingDays(count: count)
              : isNull,
        );
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.IntAnys(glados.any).intInRange(1, 1000000),
      glados.IntAnys(glados.any).intInRange(0, 5),
    ).test(
      'a positive cadence in any accepted spelling parses to itself',
      (count, style) {
        final cadence = switch (style) {
          0 => count,
          1 => '$count',
          2 => ' ${count}x ',
          3 => '$count times per week',
          _ => count.toDouble(),
        };
        expect(parseGoalCadenceCount(cadence), count);
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.stringOf('0123456789 .-xtimesprwk+'),
      glados.ExploreConfig(numRuns: 400),
    ).test(
      'a cadence is a positive whole count or null, never a throw',
      (cadence) {
        final count = parseGoalCadenceCount(cadence);
        if (count != null) {
          expect(count, greaterThan(0));
          expect(
            int.parse(RegExp(r'\d+').firstMatch(cadence)!.group(0)!),
            count,
          );
        }
      },
      tags: 'glados',
    );
  });
}

extension _AnyGoalWindow on glados.Any {
  glados.Generator<GoalWindow> get goalWindow =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(0, 4),
        glados.IntAnys(this).intInRange(1, maxGoalRollingDays + 1),
        (int kind, int count) => switch (kind) {
          0 => const GoalWindow.day(),
          1 => GoalWindow.rollingDays(count: count),
          2 => const GoalWindow.calendarWeek(),
          _ => const GoalWindow.calendarMonth(),
        },
      );

  /// A local instant between 1970 and 2100, snapped to a year's edge or a
  /// leap day a third of the time, at any hour.
  glados.Generator<DateTime> get goalReference =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 47847),
        glados.IntAnys(this).intInRange(0, 9),
        glados.IntAnys(this).intInRange(0, 24),
        (int dayIndex, int snap, int hour) {
          final day = DateTime.utc(1970).add(Duration(days: dayIndex));
          final leapYear = day.year - day.year % 4;
          final (y, m, d) = switch (snap) {
            0 => (day.year, 12, 31),
            1 => (day.year, 1, 1),
            2 when leapYear != 2100 && leapYear >= 1972 => (leapYear, 2, 29),
            _ => (day.year, day.month, day.day),
          };
          return DateTime(y, m, d, hour);
        },
      );
}
