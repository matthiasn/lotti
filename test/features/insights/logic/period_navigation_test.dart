import 'package:flutter_test/flutter_test.dart';
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
  });
}
