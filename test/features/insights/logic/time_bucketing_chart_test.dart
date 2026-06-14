import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'time_bucketing_test_helpers.dart';

void main() {
  group('accumulate', () {
    test('produces running sums per series', () {
      expect(
        accumulate([
          [1, 2, 3],
          [0, 0, 5],
        ]),
        [
          [1, 3, 6],
          [0, 0, 5],
        ],
      );
    });
  });

  group('bucketTotal', () {
    InsightsChartData chart(List<List<int>> values, int buckets) =>
        InsightsChartData(
          granularity: InsightsGranularity.day,
          bucketStarts: [
            for (var i = 0; i < buckets; i++) DateTime(2024, 3, i + 1),
          ],
          seriesKeys: [for (var s = 0; s < values.length; s++) 'cat-$s'],
          values: values,
        );

    test('sums every series in a bucket', () {
      final data = chart([
        [3600, 0, 1800],
        [900, 1800, 0],
      ], 3);
      expect(bucketTotal(data, 0), 4500);
      expect(bucketTotal(data, 1), 1800);
      expect(bucketTotal(data, 2), 1800);
    });
  });

  group('series cap', () {
    test('the dense weekly view caps tighter than day/hour', () {
      expect(
        maxChartSeriesFor(InsightsGranularity.week),
        kInsightsMaxChartSeriesDense,
      );
      expect(
        maxChartSeriesFor(InsightsGranularity.day),
        kInsightsMaxChartSeries,
      );
      expect(
        maxChartSeriesFor(InsightsGranularity.hour),
        kInsightsMaxChartSeries,
      );
      expect(kInsightsMaxChartSeriesDense, lessThan(kInsightsMaxChartSeries));
    });

    test('buildChartData folds one extra category into Other on a year', () {
      // 8 categories with descending totals, all on the window's first day.
      final start = epochDay(DateTime(2024, 3));
      final rows = [
        for (var c = 1; c <= 8; c++)
          InsightsTimeRow(
            dateFrom: DateTime(2024, 3),
            dateTo: DateTime(2024, 3).add(Duration(minutes: (9 - c) * 20)),
            categoryId: 'cat-$c',
          ),
      ];
      final buckets = bucketize(rows, windowStartDay: start);

      int visible(InsightsChartData d) =>
          d.seriesKeys.where((k) => k != kInsightsOtherCategoryKey).length;

      // A 30-day (daily) range keeps the full 6 visible series + Other.
      final dayChart = buildChartData(
        buckets,
        InsightsRange(startDay: start, endDayExclusive: start + 30),
      );
      expect(visible(dayChart), kInsightsMaxChartSeries);
      expect(dayChart.seriesKeys, contains(kInsightsOtherCategoryKey));

      // A 200-day (weekly) range folds one more in, leaving 5 + Other so the
      // narrow stacked bars stay decodable.
      final weekChart = buildChartData(
        buckets,
        InsightsRange(startDay: start, endDayExclusive: start + 200),
      );
      expect(visible(weekChart), kInsightsMaxChartSeriesDense);
      expect(weekChart.seriesKeys, contains(kInsightsOtherCategoryKey));
    });
  });

  group('buildTableRows', () {
    test('computes share and avg over days in range', () {
      final day = DateTime(2024, 3);
      final buckets = bucketize(
        [
          InsightsTimeRow(
            dateFrom: DateTime(2024, 3, 1, 9),
            dateTo: DateTime(2024, 3, 1, 12),
            categoryId: 'work',
          ),
          InsightsTimeRow(
            dateFrom: DateTime(2024, 3, 1, 13),
            dateTo: DateTime(2024, 3, 1, 14),
            categoryId: null,
          ),
        ],
        windowStartDay: epochDay(day),
      );
      final rows = buildTableRows(
        buckets,
        InsightsRange(
          startDay: epochDay(day),
          endDayExclusive: epochDay(day) + 4,
        ),
      );
      expect(rows, hasLength(2));
      expect(rows[0].categoryId, 'work');
      expect(rows[0].seconds, 3 * 3600);
      expect(rows[0].share, closeTo(0.75, 1e-9));
      expect(rows[0].avgSecondsPerDay, 3 * 3600 ~/ 4);
      expect(rows[1].categoryId, isNull);
      expect(rows[1].share, closeTo(0.25, 1e-9));
    });

    test('returns empty for ranges without data', () {
      expect(
        buildTableRows(
          InsightsDayBuckets.empty,
          const InsightsRange(startDay: 19000, endDayExclusive: 19007),
        ),
        isEmpty,
      );
    });
  });

  group('buildKpis', () {
    final day = DateTime(2024, 3);
    final buckets = bucketize(
      [
        InsightsTimeRow(
          dateFrom: DateTime(2024, 3, 1, 9),
          dateTo: DateTime(2024, 3, 1, 12),
          categoryId: 'work',
        ),
        InsightsTimeRow(
          dateFrom: DateTime(2024, 3, 1, 13),
          dateTo: DateTime(2024, 3, 1, 14),
          categoryId: 'errands',
        ),
      ],
      windowStartDay: epochDay(day),
    );
    final range = InsightsRange(
      startDay: epochDay(day),
      endDayExclusive: epochDay(day) + 7,
    );

    test('without focus configuration only total is reported', () {
      final kpis = buildKpis(buckets, range, focusCategoryIds: const {});
      expect(kpis.totalSeconds, 4 * 3600);
      expect(kpis.focusSeconds, isNull);
      expect(kpis.otherSeconds, isNull);
    });

    test('with focus categories, focus + other partition the total', () {
      final kpis = buildKpis(buckets, range, focusCategoryIds: const {'work'});
      expect(kpis.totalSeconds, 4 * 3600);
      expect(kpis.focusSeconds, 3 * 3600);
      expect(kpis.otherSeconds, 3600);
    });
  });

  // ---------------------------------------------------------------------
  // Property-based tests (Glados)
  // ---------------------------------------------------------------------

  glados.Glados<List<EntrySpec>>(
    glados.any.entrySpecs,
  ).test('bucketize conserves per-row duration when no same-category rows '
      'overlap (midnight/DST splits lose nothing)', (specs) {
    // De-overlap by giving every row its own category, isolating the
    // split logic from the (separately tested) union-merge.
    final rows = [
      for (var i = 0; i < specs.length; i++)
        InsightsTimeRow(
          dateFrom: specs[i].start,
          dateTo: specs[i].end,
          categoryId: 'unique-$i',
        ),
    ];
    final buckets = bucketize(rows, windowStartDay: hWindowStartDay());
    final bucketTotal = buckets.days.values
        .expand((cells) => cells.values)
        .fold<int>(0, (sum, cell) => sum + cell.seconds);
    final rowTotal = rows.fold<int>(
      0,
      (sum, r) => sum + r.dateTo.difference(r.dateFrom).inSeconds,
    );
    expect(bucketTotal, rowTotal);
  }, tags: 'glados');

  glados.Glados<List<EntrySpec>>(
    glados.any.entrySpecs,
  ).test('every bucketized segment lies within its day and within the '
      'window', (specs) {
    final windowStartDay = hWindowStartDay();
    final buckets = bucketize(
      [for (final s in specs) s.row],
      windowStartDay: windowStartDay,
    );
    buckets.days.forEach((day, cells) {
      expect(day, greaterThanOrEqualTo(windowStartDay));
      final start = dayStart(day);
      final end = nextLocalMidnight(start);
      for (final cell in cells.values) {
        for (final interval in cell.intervals) {
          expect(interval.start.isBefore(start), isFalse);
          expect(interval.end.isAfter(end), isFalse);
        }
      }
    });
  }, tags: 'glados');

  glados.Glados<List<EntrySpec>>(
    glados.any.entrySpecs,
  ).test('union-merged cells never exceed naive sums and merging is '
      'idempotent', (specs) {
    final buckets = bucketize(
      [for (final s in specs) s.row],
      windowStartDay: hWindowStartDay(),
    );
    for (final cells in buckets.days.values) {
      for (final cell in cells.values) {
        // Idempotence: merging an already-merged list is a no-op.
        expect(mergeIntervals(cell.intervals), cell.intervals);
        // Disjoint and sorted.
        for (var i = 1; i < cell.intervals.length; i++) {
          expect(
            cell.intervals[i].start.isAfter(cell.intervals[i - 1].end),
            isTrue,
          );
        }
        expect(cell.seconds, intervalSeconds(cell.intervals));
      }
    }
  }, tags: 'glados');

  glados.Glados<List<EntrySpec>>(
    glados.any.entrySpecs,
  ).test('chart totals equal table totals equal KPI total for any data', (
    specs,
  ) {
    final buckets = bucketize(
      [for (final s in specs) s.row],
      windowStartDay: hWindowStartDay(),
    );
    final range = InsightsRange(
      startDay: hWindowStartDay(),
      // Wide enough to cover every generated span (40 days + 3-day max
      // duration + slack).
      endDayExclusive: hWindowStartDay() + 50,
    );
    final chartTotal = buildChartData(
      buckets,
      range,
    ).values.expand((row) => row).fold<int>(0, (a, b) => a + b);
    final tableTotal = buildTableRows(
      buckets,
      range,
    ).fold<int>(0, (sum, row) => sum + row.seconds);
    final kpiTotal = buildKpis(
      buckets,
      range,
      focusCategoryIds: const {},
    ).totalSeconds;
    expect(chartTotal, tableTotal);
    expect(tableTotal, kpiTotal);
  }, tags: 'glados');

  glados.Glados<List<EntrySpec>>(
    glados.any.entrySpecs,
  ).test('table shares sum to 1 and rows are ranked descending', (specs) {
    final buckets = bucketize(
      [for (final s in specs) s.row],
      windowStartDay: hWindowStartDay(),
    );
    final range = InsightsRange(
      startDay: hWindowStartDay(),
      endDayExclusive: hWindowStartDay() + 50,
    );
    final rows = buildTableRows(buckets, range);
    if (rows.isEmpty) return;
    final shareSum = rows.fold<double>(0, (sum, row) => sum + row.share);
    expect(shareSum, closeTo(1, 1e-9));
    for (var i = 1; i < rows.length; i++) {
      expect(rows[i].seconds, lessThanOrEqualTo(rows[i - 1].seconds));
    }
  }, tags: 'glados');

  glados.Glados<int>(
    glados.any.intInRange(-100000, 100000),
  ).test('weekStartDay maps every day onto the Monday at or before it', (
    day,
  ) {
    final monday = weekStartDay(day);
    expect(monday, lessThanOrEqualTo(day));
    expect(day - monday, lessThan(7));
    // Anchor: epoch day 4 (1970-01-05) was a Monday; Mondays are ≡ 4 mod 7.
    final remainder = monday % 7;
    expect(remainder < 0 ? remainder + 7 : remainder, 4);
    // Idempotence: a Monday maps to itself.
    expect(weekStartDay(monday), monday);
  }, tags: 'glados');

  glados.Glados<List<EntrySpec>>(
    glados.any.entrySpecs,
  ).test('cumulative series are monotone non-decreasing', (specs) {
    final buckets = bucketize(
      [for (final s in specs) s.row],
      windowStartDay: hWindowStartDay(),
    );
    final chart = buildChartData(
      buckets,
      InsightsRange(
        startDay: hWindowStartDay(),
        endDayExclusive: hWindowStartDay() + 50,
      ),
    );
    for (final row in accumulate(chart.values)) {
      for (var i = 1; i < row.length; i++) {
        expect(row[i], greaterThanOrEqualTo(row[i - 1]));
      }
    }
  }, tags: 'glados');

  glados.Glados<List<EntrySpec>>(
    glados.any.entrySpecs,
  ).test("hourly totals for a day sum to that day's daily total", (specs) {
    final buckets = bucketize(
      [for (final s in specs) s.row],
      windowStartDay: hWindowStartDay(),
    );
    for (final day in buckets.days.keys) {
      final hourlySum = hourlyTotals(
        buckets,
        day,
      ).expand((bucket) => bucket.values).fold<int>(0, (a, b) => a + b);
      final dailySum = buckets.days[day]!.values.fold<int>(
        0,
        (sum, cell) => sum + cell.seconds,
      );
      expect(hourlySum, dailySum);
    }
  }, tags: 'glados');
}
