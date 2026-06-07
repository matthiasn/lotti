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
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        mediaQueryData: desktopMq,
        InsightsChartCard(chartData: data ?? chartData(), resolver: resolver),
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
    // No one-item legend row restating the only category.
    expect(find.text('Client Work'), findsNothing);
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
}
