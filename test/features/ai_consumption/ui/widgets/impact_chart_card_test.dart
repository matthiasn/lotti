import 'package:clock/clock.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/logic/impact_dashboard_data.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/model/impact_dashboard_models.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_chart_card.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart'
    show epochDay;
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/ui/widgets/insights_category_resolver.dart';

import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';

void main() {
  // Fixture week: Monday 2024-03-04 … Sunday 2024-03-10, viewed from a
  // fixed "now" after the whole range has elapsed.
  final day0 = epochDay(DateTime(2024, 3, 4));
  final fixedNow = DateTime(2024, 3, 15, 12);
  final range = InsightsRange(startDay: day0, endDayExclusive: day0 + 7);

  final resolver = InsightsCategoryResolver(
    categoriesById: {
      'cat-a': CategoryTestUtils.createTestCategory(
        id: 'cat-a',
        name: 'Agents',
        color: '#3B82F6',
      ),
      'cat-b': CategoryTestUtils.createTestCategory(
        id: 'cat-b',
        name: 'Research',
        color: '#EF4444',
      ),
    },
    uncategorizedLabel: 'Uncategorized',
    otherLabel: 'Other',
    deletedLabel: 'Deleted category',
  );

  ConsumptionDayBuckets bucketsWith(Map<int, Map<String?, double>> credits) =>
      ConsumptionDayBuckets(
        windowStartDay: day0,
        days: {
          for (final entry in credits.entries)
            day0 + entry.key: {
              for (final cell in entry.value.entries)
                cell.key: ConsumptionMetrics(
                  callCount: 1,
                  credits: cell.value,
                  energyKwh: cell.value / 100,
                ),
            },
        },
      );

  Future<void> pumpCard(
    WidgetTester tester, {
    required ImpactChartData chartData,
    ConsumptionMetric metric = ConsumptionMetric.cost,
  }) async {
    await withClock(Clock.fixed(fixedNow), () async {
      await tester.pumpWidget(
        makeTestableWidget(
          ImpactChartCard(
            chartData: chartData,
            resolver: resolver,
            metric: metric,
          ),
          mediaQueryData: const MediaQueryData(size: Size(900, 700)),
        ),
      );
      await tester.pump();
    });
  }

  testWidgets('renders metric title, bucket caption, bars, and legend', (
    tester,
  ) async {
    final chartData = buildImpactChartData(
      bucketsWith({
        0: {'cat-a': 2.0, 'cat-b': 1.0},
        2: {null: 0.5},
      }),
      range,
      ConsumptionMetric.cost,
    );
    await pumpCard(tester, chartData: chartData);

    expect(find.text('Cost by category'), findsOneWidget);
    expect(find.text('Per day'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
    // Legend names every series, including uncategorized.
    expect(find.text('Agents'), findsOneWidget);
    expect(find.text('Research'), findsOneWidget);
    expect(find.text('Uncategorized'), findsOneWidget);
  });

  testWidgets('title follows the selected metric', (tester) async {
    final chartData = buildImpactChartData(
      bucketsWith({
        0: {'cat-a': 2.0},
      }),
      range,
      ConsumptionMetric.energy,
    );
    await pumpCard(
      tester,
      chartData: chartData,
      metric: ConsumptionMetric.energy,
    );
    expect(find.text('Energy by category'), findsOneWidget);
    expect(find.text('Cost by category'), findsNothing);
    // Single series → the one-item legend is suppressed.
    expect(find.text('Agents'), findsNothing);
  });

  testWidgets('legend discloses the Other rollup count', (tester) async {
    final chartData = buildImpactChartData(
      bucketsWith({
        0: {for (var c = 1; c <= 8; c++) 'roll-$c': c.toDouble()},
      }),
      range,
      ConsumptionMetric.cost,
    );
    await pumpCard(tester, chartData: chartData);
    // 8 categories, day cap 6 → two folded into Other.
    expect(chartData.rolledUpCount, 2);
    expect(find.text('Other (+2)'), findsOneWidget);
  });

  testWidgets('empty data shows the placeholder instead of a chart', (
    tester,
  ) async {
    final chartData = buildImpactChartData(
      const ConsumptionDayBuckets(windowStartDay: 0, days: {}),
      range,
      ConsumptionMetric.cost,
    );
    await pumpCard(tester, chartData: chartData);
    expect(find.text('No data in this range'), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
  });
}
