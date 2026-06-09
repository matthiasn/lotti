import 'package:clock/clock.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/ui/widgets/insights_category_resolver.dart';
import 'package:lotti/features/insights/ui/widgets/insights_chart_card.dart';

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

  Future<void> pumpCard(
    WidgetTester tester, {
    InsightsChartData? data,
    List<int>? comparisonTotals,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        mediaQueryData: desktopMq,
        InsightsChartCard(
          chartData: data ?? chartData(),
          resolver: resolver,
          comparisonTotals: comparisonTotals,
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

    await tester.tap(find.text('Cumulative'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
    expect(find.text('Running total over the range'), findsOneWidget);

    await tester.tap(find.text('Daily'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(BarChart), findsOneWidget);
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
        await tester.tap(find.text('Cumulative'));
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

  group('comparison (grouped bars)', () {
    // Current bucket totals are 5400, 900, 7200, 5400, 900, 1800, 4500.
    const previousTotals = [2700, 1800, 7200, 0, 1800, 1800, 1800];

    testWidgets(
      'renders a ghost previous rod per group and hides the mode toggle',
      (tester) async {
        await pumpCard(tester, comparisonTotals: previousTotals);

        // The daily/cumulative toggle is meaningless when comparing.
        expect(find.text('Daily'), findsNothing);
        expect(find.text('Cumulative'), findsNothing);
        // Caption announces the comparison; legend gains a Previous swatch.
        expect(find.text('This period vs the previous'), findsOneWidget);
        expect(find.text('Previous'), findsOneWidget);

        final chart = tester.widget<BarChart>(find.byType(BarChart));
        // Every group now has two rods: current stack + previous ghost.
        for (final group in chart.data.barGroups) {
          expect(group.barRods, hasLength(2));
        }
        // The ghost rod (index 1) carries the previous-period total, with no
        // category stack of its own.
        final ghost = chart.data.barGroups[0].barRods[1];
        expect(ghost.toY, 2700.0);
        expect(ghost.rodStackItems, isEmpty);
      },
    );

    testWidgets('tooltip names the previous total and the percent delta', (
      tester,
    ) async {
      await pumpCard(tester, comparisonTotals: previousTotals);

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      final tooltipData = chart.data.barTouchData.touchTooltipData;
      final group = chart.data.barGroups[0];

      // Current rod (index 0): category rows plus a "Previous … +100%" footer
      // (5400 vs 2700).
      final current = tooltipData.getTooltipItem(
        group,
        0,
        group.barRods[0],
        0,
      )!;
      final currentText =
          current.text + current.children!.map((s) => s.toPlainText()).join();
      expect(currentText, contains('Client Work  1h'));
      expect(currentText, contains('Previous  45m'));
      expect(currentText, contains('+100%'));

      // Ghost rod (index 1): just the previous total, no breakdown.
      final ghost = tooltipData.getTooltipItem(group, 0, group.barRods[1], 1)!;
      expect(ghost.text, contains('Previous'));
      expect(ghost.text, contains('45m'));
      expect(ghost.children ?? const [], isEmpty);
    });

    testWidgets('a new previous baseline of zero reads as "new"', (
      tester,
    ) async {
      await pumpCard(tester, comparisonTotals: previousTotals);

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      final tooltipData = chart.data.barTouchData.touchTooltipData;
      // Bucket 3: current 5400 vs previous 0 → brand new, no percent.
      final group = chart.data.barGroups[3];
      final current = tooltipData.getTooltipItem(
        group,
        3,
        group.barRods[0],
        0,
      )!;
      final footer = current.children!.map((s) => s.toPlainText()).join();
      expect(footer, contains('new'));
    });
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
      await tester.tap(find.text('Cumulative'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(LineChart), findsOneWidget);
      // Thinned to every 5th label: May 9 shown, May 10 suppressed.
      expect(find.text('May 9'), findsOneWidget);
      expect(find.text('May 10'), findsNothing);
    });
  });
}
