import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/insights/logic/period_navigation.dart';
import 'package:lotti/features/insights/logic/range_presets.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';

void main() {
  InsightsRange rangeFor(DateTime startInclusive, DateTime endExclusive) =>
      InsightsRange(
        startDay: epochDay(startInclusive),
        endDayExclusive: epochDay(endExclusive),
      );

  group('windowStartDayFor', () {
    test('is January 1st of the range-start year', () {
      final range = periodContaining(
        InsightsPeriodUnit.week,
        DateTime(2026, 6, 7),
      );
      expect(dayStart(windowStartDayFor(range)), DateTime(2026));
    });

    test('uses the start year for a week that crosses into January', () {
      // The week containing 30 Dec 2025 starts on Mon 29 Dec 2025.
      final range = periodContaining(
        InsightsPeriodUnit.week,
        DateTime(2025, 12, 30),
      );
      expect(dayStart(range.startDay).year, 2025);
      expect(dayStart(windowStartDayFor(range)), DateTime(2025));
    });
  });

  group('insightsWindowFor', () {
    test('periods within one year share a single window key', () {
      final week = insightsWindowFor(
        periodContaining(InsightsPeriodUnit.week, DateTime(2026, 3, 10)),
      );
      final month = insightsWindowFor(
        periodContaining(InsightsPeriodUnit.month, DateTime(2026, 9, 5)),
      );
      expect(week, month);
      expect(week.endYear, 2026);
    });

    test('a past-year range is bounded to its own year', () {
      final window = insightsWindowFor(
        rangeFor(DateTime(2020, 5, 3), DateTime(2020, 5, 6)),
      );
      expect(dayStart(window.startDay), DateTime(2020));
      expect(window.endYear, 2020);
    });

    test('a multi-year range spans start year through end year', () {
      final window = insightsWindowFor(
        rangeFor(DateTime(2024, 12, 20), DateTime(2026, 1, 6)),
      );
      expect(dayStart(window.startDay), DateTime(2024));
      expect(window.endYear, 2026);
    });
  });

  group('epochDay is timezone-agnostic', () {
    test('reads only calendar fields, ignoring construction flavor', () {
      expect(epochDay(DateTime(2026, 6)), epochDay(DateTime.utc(2026, 6)));
      expect(
        epochDay(DateTime(2025, 12, 31)),
        epochDay(DateTime.utc(2025, 12, 31)),
      );
      expect(epochDay(DateTime(2024)), epochDay(DateTime.utc(2024)));
    });
  });
}
