import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/insights/logic/range_presets.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';

import '../../../test_utils/glados_generators.dart';

void main() {
  // A fixed mid-year afternoon: 2026-06-07 16:30 local.
  final now = DateTime(2026, 6, 7, 16, 30);

  group('resolvePreset', () {
    test('d1 spans exactly today', () {
      final range = resolvePreset(InsightsRangePreset.d1, now);
      expect(range.dayCount, 1);
      expect(dayStart(range.startDay), DateTime(2026, 6, 7));
    });

    test('d7 spans 7 trailing days including today', () {
      final range = resolvePreset(InsightsRangePreset.d7, now);
      expect(range.dayCount, 7);
      expect(dayStart(range.startDay), DateTime(2026, 6));
      expect(dayStart(range.endDayExclusive), DateTime(2026, 6, 8));
    });

    test('d30 spans 30 trailing days including today', () {
      final range = resolvePreset(InsightsRangePreset.d30, now);
      expect(range.dayCount, 30);
      expect(dayStart(range.startDay), DateTime(2026, 5, 9));
    });

    test('mtd starts on the 1st of the current month', () {
      final range = resolvePreset(InsightsRangePreset.mtd, now);
      expect(dayStart(range.startDay), DateTime(2026, 6));
      expect(dayStart(range.endDayExclusive), DateTime(2026, 6, 8));
    });

    test('mtd on the 1st spans the single partial day', () {
      final firstOfMonth = DateTime(2026, 6, 1, 9);
      final range = resolvePreset(InsightsRangePreset.mtd, firstOfMonth);
      expect(range.dayCount, 1);
      expect(dayStart(range.startDay), DateTime(2026, 6));
    });

    test('ytd starts on January 1st', () {
      final range = resolvePreset(InsightsRangePreset.ytd, now);
      expect(dayStart(range.startDay), DateTime(2026));
      expect(dayStart(range.endDayExclusive), DateTime(2026, 6, 8));
    });

    test('lastMonth spans the full previous calendar month', () {
      final range = resolvePreset(InsightsRangePreset.lastMonth, now);
      expect(dayStart(range.startDay), DateTime(2026, 5));
      expect(dayStart(range.endDayExclusive), DateTime(2026, 6));
      expect(range.dayCount, 31);
    });

    test('lastMonth in January resolves to December of the prior year', () {
      final january = DateTime(2026, 1, 15);
      final range = resolvePreset(InsightsRangePreset.lastMonth, january);
      expect(dayStart(range.startDay), DateTime(2025, 12));
      expect(dayStart(range.endDayExclusive), DateTime(2026));
    });
  });

  group('customRange', () {
    test('is inclusive of both picked days, in either order', () {
      final a = DateTime(2026, 6, 3, 14);
      final b = DateTime(2026, 6, 1, 9);
      final range = customRange(a, b);
      expect(dayStart(range.startDay), DateTime(2026, 6));
      expect(dayStart(range.endDayExclusive), DateTime(2026, 6, 4));
      expect(range, customRange(b, a));
      expect(range.preset, isNull);
    });

    test('same day twice yields a one-day range', () {
      final range = customRange(DateTime(2026, 6, 3), DateTime(2026, 6, 3));
      expect(range.dayCount, 1);
    });
  });

  group('insightsWindowFor', () {
    test('current-year presets share one window key', () {
      final d7 = insightsWindowFor(resolvePreset(InsightsRangePreset.d7, now));
      final ytd = insightsWindowFor(
        resolvePreset(InsightsRangePreset.ytd, now),
      );
      expect(d7, ytd);
      expect(d7.endYear, 2026);
    });

    test('a past-year custom range is bounded to its own year', () {
      final window = insightsWindowFor(
        customRange(DateTime(2020, 5, 3), DateTime(2020, 5, 5)),
      );
      expect(dayStart(window.startDay), DateTime(2020));
      expect(window.endYear, 2020);
    });

    test('a multi-year custom range spans start year through end year', () {
      final window = insightsWindowFor(
        customRange(DateTime(2024, 12, 20), DateTime(2026, 1, 5)),
      );
      expect(dayStart(window.startDay), DateTime(2024));
      expect(window.endYear, 2026);
    });
  });

  group('timezone-agnostic helpers', () {
    test('epochDay reads only calendar fields — construction flavor is '
        'irrelevant', () {
      // Locks the property that makes resolvePreset's local-DateTime
      // helpers safe even for a UTC `now`: the epoch-day of a calendar
      // date is identical regardless of the intermediate's timezone.
      expect(epochDay(DateTime(2026, 6)), epochDay(DateTime.utc(2026, 6)));
      expect(
        epochDay(DateTime(2025, 12, 31)),
        epochDay(DateTime.utc(2025, 12, 31)),
      );
      expect(epochDay(DateTime(2024)), epochDay(DateTime.utc(2024)));
    });
  });

  group('windowStartDayFor', () {
    test('is January 1st of the range-start year', () {
      final range = resolvePreset(InsightsRangePreset.d7, now);
      expect(dayStart(windowStartDayFor(range)), DateTime(2026));
    });

    test('lastMonth in January widens the window to the prior year', () {
      final range = resolvePreset(
        InsightsRangePreset.lastMonth,
        DateTime(2026, 1, 15),
      );
      expect(dayStart(windowStartDayFor(range)), DateTime(2025));
    });
  });

  // ---------------------------------------------------------------------
  // Property-based tests (Glados)
  // ---------------------------------------------------------------------

  glados.Glados2<IsoDateComponents, int>(
    glados.any.isoDate,
    glados.any.intInRange(0, 24 * 60),
  ).test('every preset resolved at any instant is well-formed', (
    date,
    minuteOfDay,
  ) {
    final instant = DateTime(
      date.year,
      date.month,
      date.day,
      0,
      minuteOfDay,
    );
    for (final preset in InsightsRangePreset.values) {
      final range = resolvePreset(preset, instant);
      expect(range.startDay, lessThan(range.endDayExclusive));
      expect(range.preset, preset);
      // The serving window always contains the whole range.
      expect(windowStartDayFor(range), lessThanOrEqualTo(range.startDay));
      // Every non-lastMonth preset includes "today".
      if (preset != InsightsRangePreset.lastMonth) {
        expect(range.endDayExclusive, epochDay(instant) + 1);
        expect(range.startDay, lessThanOrEqualTo(epochDay(instant)));
      }
    }
  }, tags: 'glados');

  glados.Glados<IsoDateComponents>(glados.any.isoDate).test(
    'lastMonth always spans exactly one calendar month ending at the '
    'current month start',
    (date) {
      final instant = DateTime(date.year, date.month, date.day, 11);
      final range = resolvePreset(InsightsRangePreset.lastMonth, instant);
      final start = dayStart(range.startDay);
      final end = dayStart(range.endDayExclusive);
      expect(start.day, 1);
      expect(end, DateTime(instant.year, instant.month));
      expect(DateTime(start.year, start.month + 1), end);
    },
    tags: 'glados',
  );

  glados.Glados2<IsoDateComponents, IsoDateComponents>(
    glados.any.isoDate,
    glados.any.isoDate,
  ).test('customRange is symmetric, inclusive, and day-aligned', (a, b) {
    final range = customRange(a.dateTime, b.dateTime);
    expect(range, customRange(b.dateTime, a.dateTime));
    expect(range.startDay, lessThanOrEqualTo(epochDay(a.dateTime)));
    expect(range.startDay, lessThanOrEqualTo(epochDay(b.dateTime)));
    expect(range.endDayExclusive, greaterThan(epochDay(a.dateTime)));
    expect(range.endDayExclusive, greaterThan(epochDay(b.dateTime)));
    final span = epochDay(a.dateTime) - epochDay(b.dateTime);
    expect(range.dayCount, span.abs() + 1);
  }, tags: 'glados');
}
