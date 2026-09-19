import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/insights/logic/period_navigation.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';

void main() {
  DateTime startOf(InsightsRange r) => dayStart(r.startDay);
  DateTime endOf(InsightsRange r) => dayStart(r.endDayExclusive); // exclusive

  group('periodContaining', () {
    test('day snaps to the single calendar day', () {
      final r = periodContaining(
        InsightsPeriodUnit.day,
        DateTime(2026, 6, 7, 16),
      );
      expect(startOf(r), DateTime(2026, 6, 7));
      expect(r.dayCount, 1);
    });

    test('week snaps to its Monday — a Sunday belongs to the prior Monday', () {
      // 2026-06-07 is a Sunday; its Monday is 2026-06-01.
      final r = periodContaining(InsightsPeriodUnit.week, DateTime(2026, 6, 7));
      expect(startOf(r), DateTime(2026, 6)); // Mon Jun 1
      expect(r.dayCount, 7);
      expect(endOf(r), DateTime(2026, 6, 8)); // next Mon (exclusive)
    });

    test('a week anchored on a Monday starts on that Monday', () {
      final r = periodContaining(InsightsPeriodUnit.week, DateTime(2026, 6));
      expect(startOf(r), DateTime(2026, 6));
    });

    test('a Sunday-first week (US region) snaps to its Sunday', () {
      // 2026-06-07 is a Sunday; with Sunday-start weeks it begins that day,
      // and a following Tuesday belongs to the same week.
      final sunday = periodContaining(
        InsightsPeriodUnit.week,
        DateTime(2026, 6, 7),
        firstDayOfWeekIndex: DateTime.sunday % 7,
      );
      expect(startOf(sunday), DateTime(2026, 6, 7));
      expect(endOf(sunday), DateTime(2026, 6, 14));

      final tuesday = periodContaining(
        InsightsPeriodUnit.week,
        DateTime(2026, 6, 9),
        firstDayOfWeekIndex: DateTime.sunday % 7,
      );
      expect(startOf(tuesday), DateTime(2026, 6, 7));
    });

    test('month snaps to calendar-month bounds', () {
      final r = periodContaining(
        InsightsPeriodUnit.month,
        DateTime(2026, 2, 14),
      );
      expect(startOf(r), DateTime(2026, 2));
      expect(endOf(r), DateTime(2026, 3));
      expect(r.dayCount, 28); // 2026 is not a leap year
    });

    test('quarter snaps to its three-month bounds', () {
      final r = periodContaining(
        InsightsPeriodUnit.quarter,
        DateTime(2026, 5, 20),
      );
      expect(startOf(r), DateTime(2026, 4)); // Q2 = Apr–Jun
      expect(endOf(r), DateTime(2026, 7));
    });

    test('year snaps to the calendar year', () {
      final r = periodContaining(
        InsightsPeriodUnit.year,
        DateTime(2026, 8, 9),
      );
      expect(startOf(r), DateTime(2026));
      expect(endOf(r), DateTime(2027));
    });
  });

  group('periodToDate', () {
    test('month-to-date spans from the 1st through today inclusive', () {
      final r = periodToDate(
        InsightsPeriodUnit.month,
        DateTime(2026, 6, 7, 16),
      );
      expect(startOf(r), DateTime(2026, 6));
      expect(endOf(r), DateTime(2026, 6, 8)); // today is included
      expect(r.dayCount, 7);
    });

    test('year-to-date spans from January 1st through today inclusive', () {
      final r = periodToDate(InsightsPeriodUnit.year, DateTime(2026, 6, 7));
      expect(startOf(r), DateTime(2026));
      expect(endOf(r), DateTime(2026, 6, 8));
    });

    test('on the period first day it is a single-day range', () {
      final r = periodToDate(InsightsPeriodUnit.month, DateTime(2026, 6, 1, 9));
      expect(startOf(r), DateTime(2026, 6));
      expect(r.dayCount, 1);
    });

    test('on the period last day it equals the full period', () {
      final lastOfJune = DateTime(2026, 6, 30, 12);
      expect(
        periodToDate(InsightsPeriodUnit.month, lastOfJune),
        periodContaining(InsightsPeriodUnit.month, lastOfJune),
      );
    });

    test('week-to-date honors the first weekday', () {
      // Tue 2026-06-09 in a Sunday-first region → Sun Jun 7 through Tue.
      final r = periodToDate(
        InsightsPeriodUnit.week,
        DateTime(2026, 6, 9),
        firstDayOfWeekIndex: DateTime.sunday % 7,
      );
      expect(startOf(r), DateTime(2026, 6, 7));
      expect(endOf(r), DateTime(2026, 6, 10));
    });
  });

  group('shiftPeriod / previousPeriod', () {
    test('week steps by seven days in either direction', () {
      final week = periodContaining(
        InsightsPeriodUnit.week,
        DateTime(2026, 6, 3),
      );
      expect(
        startOf(previousPeriod(week, InsightsPeriodUnit.week)),
        DateTime(2026, 5, 25),
      );
      expect(
        startOf(shiftPeriod(week, InsightsPeriodUnit.week, 1)),
        DateTime(2026, 6, 8),
      );
    });

    test('week shift preserves any start weekday (index-independent)', () {
      // A Sunday-aligned week (US region). previousPeriod/shiftPeriod move the
      // bounds by whole weeks without re-snapping, so the result stays
      // Sunday-aligned regardless of the default first weekday — this is what
      // keeps the comparison window from drifting when the device-region
      // first weekday resolves after the range was built.
      final sundayWeek = periodContaining(
        InsightsPeriodUnit.week,
        DateTime(2026, 6, 7),
        firstDayOfWeekIndex: DateTime.sunday % 7,
      );
      expect(startOf(sundayWeek), DateTime(2026, 6, 7));

      final prev = previousPeriod(sundayWeek, InsightsPeriodUnit.week);
      expect(startOf(prev), DateTime(2026, 5, 31));
      expect(endOf(prev), DateTime(2026, 6, 7));

      final next = shiftPeriod(sundayWeek, InsightsPeriodUnit.week, 1);
      expect(startOf(next), DateTime(2026, 6, 14));
    });

    test('month steps across the year boundary', () {
      final jan = periodContaining(
        InsightsPeriodUnit.month,
        DateTime(2026, 1, 15),
      );
      final dec = previousPeriod(jan, InsightsPeriodUnit.month);
      expect(startOf(dec), DateTime(2025, 12));
      expect(endOf(dec), DateTime(2026));
    });

    test('quarter steps by three months', () {
      final q2 = periodContaining(
        InsightsPeriodUnit.quarter,
        DateTime(2026, 5),
      );
      expect(
        startOf(previousPeriod(q2, InsightsPeriodUnit.quarter)),
        DateTime(2026), // Q1 starts in January
      );
      expect(
        startOf(shiftPeriod(q2, InsightsPeriodUnit.quarter, 1)),
        DateTime(2026, 7),
      );
    });

    test('year steps by whole years', () {
      final y = periodContaining(InsightsPeriodUnit.year, DateTime(2026, 6));
      expect(
        startOf(previousPeriod(y, InsightsPeriodUnit.year)),
        DateTime(2025),
      );
      expect(
        startOf(shiftPeriod(y, InsightsPeriodUnit.year, 2)),
        DateTime(2028),
      );
    });

    test('day steps across a month boundary', () {
      final d = periodContaining(InsightsPeriodUnit.day, DateTime(2026, 3));
      expect(
        startOf(previousPeriod(d, InsightsPeriodUnit.day)),
        DateTime(2026, 2, 28),
      );
    });

    test(
      'a partial month-to-date compares against the same days last month',
      () {
        final mtd = periodToDate(
          InsightsPeriodUnit.month,
          DateTime(2026, 6, 10),
        );
        final prev = previousPeriod(mtd, InsightsPeriodUnit.month);
        expect(startOf(prev), DateTime(2026, 5));
        expect(endOf(prev), DateTime(2026, 5, 11)); // same 10 elapsed days
      },
    );

    test(
      'a partial year-to-date compares against the same days last year',
      () {
        final ytd = periodToDate(
          InsightsPeriodUnit.year,
          DateTime(2026, 6, 10),
        );
        final prev = previousPeriod(ytd, InsightsPeriodUnit.year);
        expect(startOf(prev), DateTime(2025));
        expect(prev.dayCount, ytd.dayCount);
      },
    );

    test('a full month keeps the shorter previous month untruncated', () {
      final march = periodContaining(
        InsightsPeriodUnit.month,
        DateTime(2026, 3, 15),
      );
      final feb = previousPeriod(march, InsightsPeriodUnit.month);
      expect(startOf(feb), DateTime(2026, 2));
      expect(endOf(feb), DateTime(2026, 3)); // all 28 days, no truncation
    });

    test(
      'month-to-date longer than the previous month keeps that full month',
      () {
        // MTD on May 31 spans 31 days; April only has 30 — no truncation.
        final mtd = periodToDate(
          InsightsPeriodUnit.month,
          DateTime(2026, 5, 31),
        );
        final prev = previousPeriod(mtd, InsightsPeriodUnit.month);
        expect(startOf(prev), DateTime(2026, 4));
        expect(endOf(prev), DateTime(2026, 5));
      },
    );
  });

  group('elapsedPortion', () {
    final now = DateTime(2026, 6, 15);

    test('a fully-past period is returned unchanged', () {
      final may = periodContaining(InsightsPeriodUnit.month, DateTime(2026, 5));
      expect(elapsedPortion(may, now), may);
    });

    test('an in-progress period is clipped to today inclusive', () {
      final june = periodContaining(
        InsightsPeriodUnit.month,
        DateTime(2026, 6),
      );
      final elapsed = elapsedPortion(june, now);
      expect(startOf(elapsed), DateTime(2026, 6));
      // Exclusive end of Jun 16 → through Jun 15 (today), i.e. 15 elapsed days.
      expect(endOf(elapsed), DateTime(2026, 6, 16));
      expect(elapsed.dayCount, 15);
    });

    test('a fully-future period clamps to a single day, never empty', () {
      // Reachable by jumping the calendar to a future month. The slice must
      // stay non-empty (InsightsRange requires ≥ 1 day) rather than collapsing
      // to [start, start) and tripping the invariant.
      final july = periodContaining(
        InsightsPeriodUnit.month,
        DateTime(2026, 7),
      );
      final elapsed = elapsedPortion(july, now);
      expect(elapsed.dayCount, 1);
      expect(startOf(elapsed), DateTime(2026, 7));
    });
  });

  group('navigation properties', () {
    bool contains(InsightsRange r, int day) =>
        r.startDay <= day && day < r.endDayExclusive;

    glados.Glados3(
      glados.any.insightsUnit,
      glados.any.insightsAnchor,
      glados.IntAnys(glados.any).intInRange(0, 7),
      glados.ExploreConfig(numRuns: 400),
    ).test(
      'the period holds its anchor and snaps to the unit boundaries',
      (unit, anchor, firstDay) {
        final r = periodContaining(unit, anchor, firstDayOfWeekIndex: firstDay);
        final start = startOf(r);

        expect(contains(r, epochDay(anchor)), isTrue);
        switch (unit) {
          case InsightsPeriodUnit.day:
            expect(r.dayCount, 1);
          case InsightsPeriodUnit.week:
            expect(r.dayCount, 7);
            expect(start.weekday % 7, firstDay);
          case InsightsPeriodUnit.month:
            expect(r.dayCount, inInclusiveRange(28, 31));
            expect((start.day, start.month), (1, anchor.month));
          case InsightsPeriodUnit.quarter:
            expect(r.dayCount, inInclusiveRange(90, 92));
            expect((start.day, (start.month - 1) % 3), (1, 0));
          case InsightsPeriodUnit.year:
            expect(r.dayCount, inInclusiveRange(365, 366));
            expect((start.day, start.month, start.year), (1, 1, anchor.year));
        }
      },
      tags: 'glados',
    );

    glados.Glados3(
      glados.any.insightsUnit,
      glados.any.insightsAnchor,
      glados.any.insightsShift,
      glados.ExploreConfig(numRuns: 400),
    ).test(
      'shifting is reversible, stays aligned and tiles without gaps',
      (unit, anchor, shift) {
        final (delta, firstDay) = shift;
        final r = periodContaining(unit, anchor, firstDayOfWeekIndex: firstDay);
        final shifted = shiftPeriod(r, unit, delta);
        final next = shiftPeriod(r, unit, delta + 1);

        expect(shiftPeriod(shifted, unit, -delta), r);
        expect(
          periodContaining(
            unit,
            startOf(shifted),
            firstDayOfWeekIndex: firstDay,
          ),
          shifted,
        );
        expect(next.startDay, shifted.endDayExclusive);
        // The previous period is the one before, cut to no more days than
        // this one has — so a 29-day February compares with January 1–29.
        if (delta == -1) {
          final previous = previousPeriod(r, unit);
          expect(previous.startDay, shifted.startDay);
          expect(
            previous.dayCount,
            r.dayCount < shifted.dayCount ? r.dayCount : shifted.dayCount,
          );
        }
      },
      tags: 'glados',
    );

    glados.Glados3(
      glados.any.insightsUnit,
      glados.any.insightsAnchor,
      glados.any.insightsShift,
      glados.ExploreConfig(numRuns: 400),
    ).test(
      'the elapsed portion is a non-empty prefix ending by today',
      (unit, now, shift) {
        final (delta, firstDay) = shift;
        final today = epochDay(now);
        final range = shiftPeriod(
          periodContaining(unit, now, firstDayOfWeekIndex: firstDay),
          unit,
          delta,
        );
        final elapsed = elapsedPortion(range, now);

        expect(elapsed.startDay, range.startDay);
        expect(
          elapsed.endDayExclusive,
          lessThanOrEqualTo(range.endDayExclusive),
        );
        expect(elapsed.dayCount, greaterThanOrEqualTo(1));
        if (range.startDay <= today) {
          expect(elapsed.endDayExclusive, lessThanOrEqualTo(today + 1));
        } else {
          expect(elapsed.dayCount, 1);
        }
        expect(isInProgress(range, now), contains(range, today));
        expect(isInProgress(range, now), delta == 0);
      },
      tags: 'glados',
    );

    glados.Glados3(
      glados.any.insightsUnit,
      glados.any.insightsAnchor,
      glados.IntAnys(glados.any).intInRange(0, 7),
      glados.ExploreConfig(numRuns: 400),
    ).test(
      'the previous to-date period is as long and ends before it starts',
      (unit, now, firstDay) {
        final toDate = periodToDate(unit, now, firstDayOfWeekIndex: firstDay);
        final full = periodContaining(
          unit,
          now,
          firstDayOfWeekIndex: firstDay,
        );
        final previous = previousPeriod(toDate, unit);

        expect(toDate.startDay, full.startDay);
        expect(toDate.endDayExclusive, epochDay(now) + 1);
        expect(previous.startDay, shiftPeriod(full, unit, -1).startDay);
        expect(previous.endDayExclusive, lessThanOrEqualTo(toDate.startDay));
        expect(previous.dayCount, lessThanOrEqualTo(toDate.dayCount));
      },
      tags: 'glados',
    );
  });
}

/// Days on which clocks change in Europe or North America, where day
/// arithmetic done in hours would drift.
final _dstDays = [
  DateTime(2024, 3, 10),
  DateTime(2024, 3, 31),
  DateTime(2024, 10, 27),
  DateTime(2024, 11, 3),
  DateTime(2026, 3, 29),
  DateTime(2026, 10, 25),
  DateTime(2031, 3, 30),
];

extension _AnyInsights on glados.Any {
  glados.Generator<InsightsPeriodUnit> get insightsUnit =>
      glados.AnyUtils(this).choose(InsightsPeriodUnit.values);

  /// A local instant between 1971 and 2099 at any hour; a quarter of the time
  /// a clock-change day, a year's last day or a leap day.
  glados.Generator<DateTime> get insightsAnchor =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(365, 47100),
        glados.IntAnys(this).intInRange(0, 12),
        glados.IntAnys(this).intInRange(0, 24),
        (int dayIndex, int snap, int hour) {
          final day = DateTime.utc(1970).add(Duration(days: dayIndex));
          final leapYear = day.year - day.year % 4;
          final date = switch (snap) {
            0 => _dstDays[dayIndex % _dstDays.length],
            1 => DateTime(day.year, 12, 31),
            2 when leapYear >= 1972 => DateTime(leapYear, 2, 29),
            _ => DateTime(day.year, day.month, day.day),
          };
          return DateTime(date.year, date.month, date.day, hour);
        },
      );

  /// A period delta of −50…50 and a first weekday of 0…6.
  glados.Generator<(int, int)> get insightsShift =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(-50, 51),
        glados.IntAnys(this).intInRange(0, 7),
        (int delta, int firstDay) => (delta, firstDay),
      );
}
