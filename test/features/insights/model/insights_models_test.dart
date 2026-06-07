import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/insights/model/insights_models.dart';

void main() {
  group('value equality', () {
    test('InsightsTimeRow equals by value', () {
      final a = InsightsTimeRow(
        dateFrom: DateTime(2024, 3, 1, 9),
        dateTo: DateTime(2024, 3, 1, 10),
        categoryId: 'work',
      );
      final b = InsightsTimeRow(
        dateFrom: DateTime(2024, 3, 1, 9),
        dateTo: DateTime(2024, 3, 1, 10),
        categoryId: 'work',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          InsightsTimeRow(
            dateFrom: DateTime(2024, 3, 1, 9),
            dateTo: DateTime(2024, 3, 1, 10),
            categoryId: null,
          ),
        ),
      );
    });

    test('InsightsDayBuckets equals deeply — unchanged refetch is a no-op', () {
      InsightsDayBuckets build() => InsightsDayBuckets(
        windowStartDay: 19000,
        days: {
          19000: {
            'work': InsightsDayCell(
              seconds: 3600,
              intervals: [
                TimeInterval(
                  DateTime(2024, 3, 1, 9),
                  DateTime(2024, 3, 1, 10),
                ),
              ],
            ),
          },
        },
      );
      // Two structurally identical instances built from scratch must be
      // equal so notification-driven refetches with identical data do not
      // rebuild the UI.
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });

    test('InsightsDayBuckets inequality on differing cells', () {
      const a = InsightsDayBuckets(
        windowStartDay: 19000,
        days: <int, Map<String?, InsightsDayCell>>{},
      );
      final b = InsightsDayBuckets(
        windowStartDay: 19000,
        days: {
          19000: {
            null: InsightsDayCell(
              seconds: 60,
              intervals: [
                TimeInterval(
                  DateTime(2024, 3, 1, 9),
                  DateTime(2024, 3, 1, 9, 1),
                ),
              ],
            ),
          },
        },
      );
      expect(a, isNot(b));
    });

    test('InsightsChartData equality and isEmpty semantics', () {
      const empty = InsightsChartData.empty;
      expect(empty.isEmpty, isTrue);

      final zeroFilled = InsightsChartData(
        granularity: InsightsGranularity.day,
        bucketStarts: [DateTime(2024, 3)],
        seriesKeys: const ['work'],
        values: const [
          [0],
        ],
      );
      expect(zeroFilled.isEmpty, isTrue);

      final withData = InsightsChartData(
        granularity: InsightsGranularity.day,
        bucketStarts: [DateTime(2024, 3)],
        seriesKeys: const ['work'],
        values: const [
          [60],
        ],
      );
      expect(withData.isEmpty, isFalse);
      expect(
        withData,
        InsightsChartData(
          granularity: InsightsGranularity.day,
          bucketStarts: [DateTime(2024, 3)],
          seriesKeys: const ['work'],
          values: const [
            [60],
          ],
        ),
      );
    });

    test('InsightsRange exposes dayCount and rejects empty spans', () {
      const range = InsightsRange(startDay: 10, endDayExclusive: 17);
      expect(range.dayCount, 7);
      expect(
        () => InsightsRange(startDay: 10, endDayExclusive: 10),
        throwsA(isA<AssertionError>()),
      );
    });

    test('TimeInterval duration and empty rejection', () {
      final interval = TimeInterval(
        DateTime(2024, 3, 1, 9),
        DateTime(2024, 3, 1, 10, 30),
      );
      expect(interval.duration, const Duration(minutes: 90));
      expect(
        () => TimeInterval(DateTime(2024, 3), DateTime(2024, 3)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('InsightsTableRow and InsightsKpis equal by value', () {
      const row = InsightsTableRow(
        categoryId: 'work',
        seconds: 3600,
        share: 0.5,
        avgSecondsPerDay: 514,
      );
      expect(
        row,
        const InsightsTableRow(
          categoryId: 'work',
          seconds: 3600,
          share: 0.5,
          avgSecondsPerDay: 514,
        ),
      );
      const kpis = InsightsKpis(
        totalSeconds: 7200,
        focusSeconds: 3600,
        otherSeconds: 3600,
      );
      expect(
        kpis,
        const InsightsKpis(
          totalSeconds: 7200,
          focusSeconds: 3600,
          otherSeconds: 3600,
        ),
      );
      expect(
        kpis,
        isNot(
          const InsightsKpis(
            totalSeconds: 7200,
            focusSeconds: null,
            otherSeconds: null,
          ),
        ),
      );
    });
  });

  group('hashCode and toString contracts', () {
    test('equal values hash equally across all model classes', () {
      const range = InsightsRange(startDay: 10, endDayExclusive: 17);
      expect(
        range.hashCode,
        const InsightsRange(startDay: 10, endDayExclusive: 17).hashCode,
      );
      const tableRow = InsightsTableRow(
        categoryId: 'a',
        seconds: 1,
        share: 0.5,
        avgSecondsPerDay: 1,
      );
      expect(
        tableRow.hashCode,
        const InsightsTableRow(
          categoryId: 'a',
          seconds: 1,
          share: 0.5,
          avgSecondsPerDay: 1,
        ).hashCode,
      );
      const kpis = InsightsKpis(
        totalSeconds: 1,
        focusSeconds: null,
        otherSeconds: null,
      );
      expect(
        kpis.hashCode,
        const InsightsKpis(
          totalSeconds: 1,
          focusSeconds: null,
          otherSeconds: null,
        ).hashCode,
      );
      final chart = InsightsChartData(
        granularity: InsightsGranularity.day,
        bucketStarts: [DateTime(2024)],
        seriesKeys: const ['a'],
        values: const [
          [1],
        ],
      );
      expect(
        chart.hashCode,
        InsightsChartData(
          granularity: InsightsGranularity.day,
          bucketStarts: [DateTime(2024)],
          seriesKeys: const ['a'],
          values: const [
            [1],
          ],
        ).hashCode,
      );
    });

    test('toString surfaces the identifying fields for debugging', () {
      final row = InsightsTimeRow(
        dateFrom: DateTime(2024, 3, 1, 9),
        dateTo: DateTime(2024, 3, 1, 10),
        categoryId: 'work',
      );
      expect(row.toString(), contains('work'));
      final interval = TimeInterval(
        DateTime(2024, 3, 1, 9),
        DateTime(2024, 3, 1, 10),
      );
      expect(interval.toString(), contains('TimeInterval'));
      const range = InsightsRange(
        startDay: 10,
        endDayExclusive: 17,
        preset: InsightsRangePreset.d7,
      );
      expect(range.toString(), contains('d7'));
      expect(range.toString(), contains('10'));
    });
  });

  test('kInsightsOtherCategoryKey cannot collide with category UUIDs', () {
    expect(kInsightsOtherCategoryKey, startsWith('__'));
  });
}
