import 'package:clock/clock.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/ui/widgets/insights_category_resolver.dart';
import 'package:lotti/features/insights/ui/widgets/insights_chart_card.dart';
import 'package:lotti/features/insights/ui/widgets/insights_chart_card_charts.dart';

import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';

void main() {
  const desktopMq = MediaQueryData(size: Size(1280, 900));

  final resolver = InsightsCategoryResolver(
    categoriesById: {
      'cat-a': CategoryTestUtils.createTestCategory(
        id: 'cat-a',
        name: 'Client Work',
        color: '#3B82F6',
      ),
      'cat-b': CategoryTestUtils.createTestCategory(
        id: 'cat-b',
        name: 'Admin',
        color: '#F59E0B',
      ),
    },
    uncategorizedLabel: 'Uncategorized',
    otherLabel: 'Other',
    deletedLabel: 'Deleted category',
  );

  InsightsChartData chartData({
    int rolledUpCount = 0,
    bool partialFirstBucket = false,
  }) => InsightsChartData(
    granularity: InsightsGranularity.day,
    bucketStarts: [for (var d = 1; d <= 7; d++) DateTime(2026, 6, d)],
    seriesKeys: const ['cat-a', 'cat-b'],
    values: const [
      [3600, 0, 7200, 3600, 0, 1800, 3600],
      [1800, 900, 0, 1800, 900, 0, 900],
    ],
    rolledUpCount: rolledUpCount,
    partialFirstBucket: partialFirstBucket,
  );

  // The shared segmented toggle stacks an invisible bold "ghost" under each
  // visible label to reserve width, so a plain find.text matches two Texts —
  // the visible one is the Stack's last child.
  Finder toggle(String label) => find.text(label).last;

  Future<void> pumpCard(
    WidgetTester tester, {
    InsightsChartData? data,
    bool comparing = false,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        mediaQueryData: desktopMq,
        InsightsChartCard(
          chartData: data ?? chartData(),
          resolver: resolver,
          comparing: comparing,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('daily mode renders a stacked bar chart with weekday labels', (
    tester,
  ) async {
    await pumpCard(tester);

    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('Time per day'), findsOneWidget);
    // ≤7 buckets → every bar labeled with weekday + day.
    expect(find.text('Mon 1'), findsOneWidget);
    expect(find.text('Sun 7'), findsOneWidget);
    // Legend lists both series.
    expect(find.text('Client Work'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
  });

  testWidgets('toggle switches to the cumulative area chart and back', (
    tester,
  ) async {
    await pumpCard(tester);

    await tester.tap(toggle('Running total'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
    expect(find.text('Running total over the range'), findsOneWidget);

    await tester.tap(toggle('Per day'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(BarChart), findsOneWidget);
  });

  group('elapsedBucketCount', () {
    InsightsChartData days(List<DateTime> starts) => InsightsChartData(
      granularity: InsightsGranularity.day,
      bucketStarts: starts,
      seriesKeys: const ['cat-a'],
      values: [
        [for (final _ in starts) 600],
      ],
    );

    test('counts elapsed buckets; future-only collapses to zero', () {
      final now = DateTime(2026, 6, 15);
      withClock(Clock.fixed(now), () {
        // Whole period in the past → every bucket has elapsed.
        expect(
          elapsedBucketCount(
            days([DateTime(2026, 6, 10), DateTime(2026, 6, 11)]),
          ),
          2,
        );
        // In progress → only the buckets up to today.
        expect(
          elapsedBucketCount(
            days([
              DateTime(2026, 6, 14),
              DateTime(2026, 6, 15),
              DateTime(2026, 6, 16),
            ]),
          ),
          2,
        );
        // Whole period still in the future → nothing has elapsed (was wrongly
        // reported as fully elapsed, which drew a flat cumulative line).
        expect(
          elapsedBucketCount(
            days([DateTime(2026, 6, 20), DateTime(2026, 6, 21)]),
          ),
          0,
        );
      });
    });
  });

  testWidgets('the per-bucket toggle label names the actual bucket', (
    tester,
  ) async {
    // Day granularity (default) → "Per day".
    await pumpCard(tester);
    expect(toggle('Per day'), findsOneWidget);
    expect(toggle('Running total'), findsOneWidget);

    // Weekly buckets → "Per week", never a wrong fixed "Daily".
    await pumpCard(
      tester,
      data: InsightsChartData(
        granularity: InsightsGranularity.week,
        bucketStarts: [DateTime(2026), DateTime(2026, 1, 5)],
        seriesKeys: const ['cat-a'],
        values: const [
          [3600, 7200],
        ],
      ),
    );
    expect(toggle('Per week'), findsOneWidget);
    expect(find.text('Per day'), findsNothing);

    // Hourly buckets → "Per hour".
    await pumpCard(
      tester,
      data: InsightsChartData(
        granularity: InsightsGranularity.hour,
        bucketStarts: [for (var h = 0; h < 24; h++) DateTime(2026, 6, 7, h)],
        seriesKeys: const ['cat-a'],
        values: [
          [for (var h = 0; h < 24; h++) 600],
        ],
      ),
    );
    expect(toggle('Per hour'), findsOneWidget);
  });

  testWidgets('legend discloses the Other rollup count', (tester) async {
    final data = InsightsChartData(
      granularity: InsightsGranularity.day,
      bucketStarts: [DateTime(2026, 6)],
      seriesKeys: const ['cat-a', kInsightsOtherCategoryKey],
      values: const [
        [3600],
        [1800],
      ],
      rolledUpCount: 4,
    );
    await pumpCard(tester, data: data);

    expect(find.text('Other (+4)'), findsOneWidget);
  });

  testWidgets('single-series charts suppress the redundant legend', (
    tester,
  ) async {
    final data = InsightsChartData(
      granularity: InsightsGranularity.day,
      bucketStarts: [for (var d = 1; d <= 3; d++) DateTime(2026, 6, d)],
      seriesKeys: const ['cat-a'],
      values: const [
        [3600, 1800, 900],
      ],
    );
    await pumpCard(tester, data: data);

    expect(find.byType(BarChart), findsOneWidget);
    // No one-item legend row restating the only category — instead the
    // caption names the sole series so mono-color bars read as intended.
    expect(find.text('Client Work'), findsNothing);
    expect(find.text('Time per day · Client Work'), findsOneWidget);
  });

  testWidgets('empty data renders the no-data message instead of axes', (
    tester,
  ) async {
    await pumpCard(tester, data: InsightsChartData.empty);

    expect(find.text('No data in this range'), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('long ranges thin labels to MMM-d format', (tester) async {
    final data = InsightsChartData(
      granularity: InsightsGranularity.day,
      bucketStarts: [
        for (var d = 0; d < 30; d++) DateTime(2026, 5, 9 + d),
      ],
      seriesKeys: const ['cat-a'],
      values: [
        [for (var d = 0; d < 30; d++) 1800],
      ],
    );
    await pumpCard(tester, data: data);

    // >7 buckets: weekday format gives way to MMM d, and only every
    // labelEvery-th bucket is labeled.
    expect(find.text('May 9'), findsOneWidget);
    expect(find.text('May 10'), findsNothing);
    expect(find.textContaining('Sat'), findsNothing);
  });

  testWidgets("today's bar carries the marker border", (tester) async {
    final today = DateTime(2026, 6, 7);
    final data = InsightsChartData(
      granularity: InsightsGranularity.day,
      bucketStarts: [
        for (var d = 6; d >= 0; d--)
          DateTime(today.year, today.month, today.day - d),
      ],
      seriesKeys: const ['cat-a'],
      values: const [
        [3600, 3600, 3600, 3600, 3600, 3600, 3600],
      ],
    );
    await withClock(Clock.fixed(DateTime(2026, 6, 7, 15)), () async {
      await pumpCard(tester, data: data);
    });

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    final borders = [
      for (final group in chart.data.barGroups)
        group.barRods.single.borderSide.width,
    ];
    // Exactly one bar — the last (today) — has the marker border.
    expect(borders.sublist(0, 6), everyElement(0.0));
    expect(borders.last, greaterThan(0.0));
  });

  testWidgets(
    'every stacked band carries the divider edge, so the bar is one width',
    (tester) async {
      // Two bands in one bucket. The baseline band used to skip the hairline
      // edge while the band above carried it; because fl_chart strokes a stack
      // item's whole rectangle (sides included), that left the baseline band a
      // hair wider than the rest. Now every band carries the same edge.
      final data = InsightsChartData(
        granularity: InsightsGranularity.day,
        bucketStarts: [DateTime(2026, 6)],
        seriesKeys: const ['cat-a', 'cat-b'],
        values: const [
          [3600],
          [1800],
        ],
      );
      await withClock(Clock.fixed(DateTime(2026, 6, 7, 15)), () async {
        await pumpCard(tester, data: data);
      });

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      final stack = chart.data.barGroups.single.barRods.single.rodStackItems;
      expect(stack.length, 2);
      expect(stack.every((item) => item.borderSide.width > 0), isTrue);
    },
  );

  group('tooltips', () {
    testWidgets(
      'bar tooltip reads out every band for the bucket, largest first',
      (tester) async {
        await pumpCard(tester);

        final chart = tester.widget<BarChart>(find.byType(BarChart));
        final tooltipData = chart.data.barTouchData.touchTooltipData;
        // Bucket 0: cat-a 1h, cat-b 30m → header total 1h 30m, rows desc.
        final group = chart.data.barGroups[0];
        final item = tooltipData.getTooltipItem(
          group,
          0,
          group.barRods.single,
          0,
        )!;
        expect(item.text, contains('Mon 1'));
        expect(item.text, contains('1h 30m'));
        final rows = item.children!.map((span) => span.toPlainText()).join();
        expect(rows, contains('Client Work  1h'));
        expect(rows, contains('Admin  30m'));
        expect(
          rows.indexOf('Client Work'),
          lessThan(rows.indexOf('Admin')),
        );
        // Zero-value bands are skipped: bucket 1 has no cat-a.
        final group1 = chart.data.barGroups[1];
        final item1 = tooltipData.getTooltipItem(
          group1,
          1,
          group1.barRods.single,
          0,
        )!;
        expect(
          item1.children!.map((s) => s.toPlainText()).join(),
          isNot(contains('Client Work')),
        );
        // Tooltip background resolves from tokens.
        expect(tooltipData.getTooltipColor(group), isA<Color>());
      },
    );

    testWidgets('weekly tooltip flags a truncated first week as partial', (
      tester,
    ) async {
      final data = InsightsChartData(
        granularity: InsightsGranularity.week,
        bucketStarts: [DateTime(2026), DateTime(2026, 1, 5)],
        seriesKeys: const ['cat-a'],
        values: const [
          [3600, 7200],
        ],
        partialFirstBucket: true,
      );
      await pumpCard(tester, data: data);

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      final tooltipData = chart.data.barTouchData.touchTooltipData;
      final first = chart.data.barGroups[0];
      final item = tooltipData.getTooltipItem(
        first,
        0,
        first.barRods.single,
        0,
      )!;
      expect(item.text, contains('partial week'));
      // The full second week carries no flag.
      final second = chart.data.barGroups[1];
      final item1 = tooltipData.getTooltipItem(
        second,
        1,
        second.barRods.single,
        0,
      )!;
      expect(item1.text, isNot(contains('partial week')));
    });

    testWidgets(
      'cumulative tooltip de-stacks to running per-series totals',
      (tester) async {
        await pumpCard(tester);
        await tester.tap(toggle('Running total'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));

        final chart = tester.widget<LineChart>(find.byType(LineChart));
        final tooltipData = chart.data.lineTouchData.touchTooltipData;
        // Hover bucket index 2: cat-a cumulative 1h+0+2h = 3h,
        // cat-b 30m+15m+0 = 45m → grand total 3h 45m.
        final spots = [
          for (
            var barIndex = 0;
            barIndex < chart.data.lineBarsData.length;
            barIndex++
          )
            LineBarSpot(
              chart.data.lineBarsData[barIndex],
              barIndex,
              chart.data.lineBarsData[barIndex].spots[2],
            ),
        ];
        final items = tooltipData.getTooltipItems(spots);
        expect(items, hasLength(spots.length));
        // One combined readout on the first spot, nulls for the rest.
        expect(items.skip(1), everyElement(isNull));
        final item = items.first!;
        expect(item.text, contains('Wed 3'));
        expect(item.text, contains('3h 45m'));
        final rows = item.children!.map((s) => s.toPlainText()).join();
        expect(rows, contains('Client Work  3h'));
        expect(rows, contains('Admin  45m'));
        expect(tooltipData.getTooltipColor(spots.first), isA<Color>());
      },
    );
  });

  // Period comparison is no longer drawn in the chart (it reads as a
  // loading/empty reference series). It is surfaced in the KPI deltas and the
  // table's Δ% / Previous columns instead — covered by insights_kpi_row_test
  // and insights_table_test. The chart only signposts where it lives:
  testWidgets('compare mode points the eye to the table; off-mode stays quiet', (
    tester,
  ) async {
    await pumpCard(tester);
    expect(find.text('Comparison shown in the table below'), findsNothing);

    await pumpCard(tester, comparing: true);
    // Still a single-series chart — the comparison itself is not drawn — but a
    // muted subtitle routes the reader to the table where the deltas are.
    expect(find.text('Comparison shown in the table below'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
  });

  group('axis edge cases', () {
    testWidgets('absurdly large totals fall back to the coarsest interval', (
      tester,
    ) async {
      final data = InsightsChartData(
        granularity: InsightsGranularity.day,
        bucketStarts: [DateTime(2026, 6)],
        seriesKeys: const ['cat-a'],
        values: const [
          // ~8000h in one bucket — beyond the largest nice step.
          [28800000],
        ],
      );
      await pumpCard(tester, data: data);
      // Renders without exceptions using the fallback interval.
      expect(find.byType(BarChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cumulative mode thins labels for long ranges too', (
      tester,
    ) async {
      final data = InsightsChartData(
        granularity: InsightsGranularity.day,
        bucketStarts: [
          for (var d = 0; d < 30; d++) DateTime(2026, 5, 9 + d),
        ],
        seriesKeys: const ['cat-a'],
        values: [
          [for (var d = 0; d < 30; d++) 1800],
        ],
      );
      await pumpCard(tester, data: data);
      await tester.tap(toggle('Running total'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(LineChart), findsOneWidget);
      // Thinned to every 5th label: May 9 shown, May 10 suppressed.
      expect(find.text('May 9'), findsOneWidget);
      expect(find.text('May 10'), findsNothing);
    });

    testWidgets('y-axis labels stay in whole hours, never days', (
      tester,
    ) async {
      // 24h in one bucket lands a gridline exactly at 24h. The axis used to
      // roll anything >= 24h into days ("1d"); it now reads plain hours so it
      // speaks the same unit as the KPI summary.
      final data = InsightsChartData(
        granularity: InsightsGranularity.day,
        bucketStarts: [DateTime(2026, 6)],
        seriesKeys: const ['cat-a'],
        values: const [
          [86400],
        ],
      );
      await withClock(Clock.fixed(DateTime(2026, 6, 7, 15)), () async {
        await pumpCard(tester, data: data);
      });
      expect(find.text('24h'), findsOneWidget);
      expect(find.text('1d'), findsNothing);
    });
  });
}
