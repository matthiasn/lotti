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

  Finder toggle(String label) => find.text(label).last;

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
    expect(find.text('Per day'), findsWidgets);
    expect(toggle('Running total'), findsOneWidget);
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
    // Legend names every series, including uncategorized.
    expect(find.text('Agents'), findsOneWidget);
    expect(find.text('Research'), findsOneWidget);
    expect(find.text('Uncategorized'), findsOneWidget);
  });

  testWidgets('toggle switches to cumulative running totals', (tester) async {
    final chartData = buildImpactChartData(
      bucketsWith({
        0: {'cat-a': 2.0},
        1: {'cat-b': 1.0},
        2: {'cat-a': 3.0},
      }),
      range,
      ConsumptionMetric.cost,
    );
    await pumpCard(tester, chartData: chartData);

    await tester.tap(toggle('Running total'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
    expect(find.text('Running total over the range'), findsOneWidget);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final tooltipData = chart.data.lineTouchData.touchTooltipData;
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
    expect(items.skip(1), everyElement(isNull));
    final item = items.first!;
    expect(item.text, contains('Wed 6'));
    expect(item.text, contains('€6.00'));
    final rows = item.children!.map((span) => span.toPlainText()).join();
    expect(rows, contains('Agents  €5.00'));
    expect(rows, contains('Research  €1.00'));
    expect(rows.indexOf('Agents'), lessThan(rows.indexOf('Research')));
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

  testWidgets('carbon and token metrics title the chart in their own unit', (
    tester,
  ) async {
    final expectedTitles = {
      ConsumptionMetric.carbon: 'CO₂e by category',
      ConsumptionMetric.tokens: 'Tokens by category',
    };
    for (final MapEntry(key: metric, value: title) in expectedTitles.entries) {
      final chartData = buildImpactChartData(
        bucketsWith({
          0: {'cat-a': 2.0},
        }),
        range,
        metric,
      );
      await pumpCard(tester, chartData: chartData, metric: metric);
      expect(find.text(title), findsOneWidget);
    }
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

  testWidgets(
    'weekly chart captions per week, draws an all-future range in full, '
    'and labels only month-start weeks',
    (tester) async {
      // Four weekly buckets spanning a month boundary, all after the fixed
      // "now" (2024-03-15) — the all-future case draws every bucket.
      final chartData = ImpactChartData(
        granularity: InsightsGranularity.week,
        bucketStarts: [
          DateTime(2024, 3, 18),
          DateTime(2024, 3, 25),
          DateTime(2024, 4),
          DateTime(2024, 4, 8),
        ],
        seriesKeys: const ['cat-a'],
        values: const [
          [1, 2, 3, 4],
        ],
      );
      await pumpCard(tester, chartData: chartData);

      expect(find.text('Per week'), findsWidgets);
      expect(find.text('Per day'), findsNothing);
      // No elapsed bucket → the chart still draws the whole range.
      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.barGroups.length, 4);
      // Only the first week of each month is labeled; same-month
      // follow-up weeks stay blank so ticks land on month boundaries.
      expect(find.text('Mar'), findsOneWidget);
      expect(find.text('Apr'), findsOneWidget);
    },
  );

  testWidgets(
    'month-long daily chart stops at today, thins axis labels, '
    'and uses month-day format',
    (tester) async {
      final monthRange = InsightsRange(
        startDay: day0,
        endDayExclusive: day0 + 30,
      );
      final chartData = buildImpactChartData(
        bucketsWith({
          0: {'cat-a': 2.0},
          5: {'cat-b': 1.0},
        }),
        monthRange,
        ConsumptionMetric.cost,
      );
      await pumpCard(tester, chartData: chartData);

      // Mar 4 … Apr 2 viewed from Mar 15 → only the 12 elapsed days draw.
      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.barGroups.length, 12);
      // >7 buckets: weekday format gives way to MMM d, and only every
      // labelEvery-th (here: second) bucket is labeled.
      expect(find.text('Mar 4'), findsOneWidget);
      expect(find.text('Mar 5'), findsNothing);
      expect(find.text('Mar 14'), findsOneWidget);
      expect(find.textContaining('Mon'), findsNothing);
    },
  );

  group('tooltips', () {
    testWidgets(
      'bar tooltip lists series largest first in the metric unit; '
      'zero buckets get no tooltip',
      (tester) async {
        final chartData = buildImpactChartData(
          bucketsWith({
            0: {'cat-a': 2.0, 'cat-b': 1.0},
            2: {null: 0.5},
          }),
          range,
          ConsumptionMetric.cost,
        );
        await pumpCard(tester, chartData: chartData);

        final chart = tester.widget<BarChart>(find.byType(BarChart));
        final tooltipData = chart.data.barTouchData.touchTooltipData;
        // Bucket 0 (Mon Mar 4): cat-a €2 + cat-b €1 → header total €3,
        // rows descending.
        final group = chart.data.barGroups[0];
        final item = tooltipData.getTooltipItem(
          group,
          0,
          group.barRods.single,
          0,
        )!;
        expect(item.text, contains('Mon 4'));
        expect(item.text, contains('€3.00'));
        final rows = item.children!.map((span) => span.toPlainText()).join();
        expect(rows, contains('Agents  €2.00'));
        expect(rows, contains('Research  €1.00'));
        expect(rows.indexOf('Agents'), lessThan(rows.indexOf('Research')));
        // Bucket 1 has no consumption → the guard suppresses the tooltip.
        final emptyGroup = chart.data.barGroups[1];
        expect(
          tooltipData.getTooltipItem(
            emptyGroup,
            1,
            emptyGroup.barRods.single,
            0,
          ),
          isNull,
        );
        // Uncategorized rows resolve to their placeholder label.
        final uncategorized = chart.data.barGroups[2];
        final item2 = tooltipData.getTooltipItem(
          uncategorized,
          2,
          uncategorized.barRods.single,
          0,
        )!;
        expect(
          item2.children!.map((span) => span.toPlainText()).join(),
          contains('Uncategorized  €0.50'),
        );
        // Tooltip background resolves from tokens.
        expect(tooltipData.getTooltipColor(group), isA<Color>());
        // Defensive guards against fl_chart edge events: an out-of-range
        // group index is suppressed instead of throwing a RangeError…
        final outOfRange = BarChartGroupData(x: 99);
        expect(
          tooltipData.getTooltipItem(outOfRange, 0, BarChartRodData(toY: 0), 0),
          isNull,
        );
        expect(
          tooltipData.getTooltipItem(
            BarChartGroupData(x: -1),
            0,
            BarChartRodData(toY: 0),
            0,
          ),
          isNull,
        );
        // …and a non-finite axis value renders as an empty title instead of
        // crashing toInt().
        final bottomTitles =
            chart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;
        final meta = TitleMeta(
          min: 0,
          max: 1,
          parentAxisSize: 100,
          axisPosition: 0,
          appliedInterval: 1,
          sideTitles: chart.data.titlesData.bottomTitles.sideTitles,
          formattedValue: '',
          axisSide: AxisSide.bottom,
          rotationQuarterTurns: 0,
        );
        expect(bottomTitles(double.nan, meta), isA<SizedBox>());
        expect(bottomTitles(double.infinity, meta), isA<SizedBox>());
      },
    );

    testWidgets('weekly tooltip flags truncated edge weeks as partial', (
      tester,
    ) async {
      final chartData = ImpactChartData(
        granularity: InsightsGranularity.week,
        bucketStarts: [
          DateTime(2024, 2),
          DateTime(2024, 2, 5),
          DateTime(2024, 2, 12),
        ],
        seriesKeys: const ['cat-a'],
        values: const [
          [1, 2, 3],
        ],
        partialFirstBucket: true,
        partialLastBucket: true,
      );
      await pumpCard(tester, chartData: chartData);

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      final tooltipData = chart.data.barTouchData.touchTooltipData;
      String headerFor(int index) {
        final group = chart.data.barGroups[index];
        return tooltipData
            .getTooltipItem(group, index, group.barRods.single, 0)!
            .text;
      }

      // Truncated first and last weeks carry the flag; the full middle
      // week does not, and weekly headers read as month-day dates.
      expect(headerFor(0), contains('Feb 1'));
      expect(headerFor(0), contains('partial week'));
      expect(headerFor(1), contains('Feb 5'));
      expect(headerFor(1), isNot(contains('partial week')));
      expect(headerFor(2), contains('partial week'));
    });
  });
}
