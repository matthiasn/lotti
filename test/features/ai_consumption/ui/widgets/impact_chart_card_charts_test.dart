import 'package:clock/clock.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_consumption/model/impact_dashboard_models.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/impact_chart_card_charts.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/series_resolver.dart';
import 'package:lotti/features/insights/model/insights_models.dart'
    show InsightsGranularity;

import '../../../../widget_test_utils.dart';

void main() {
  // Two elapsed daily buckets, viewed after both have passed.
  final fixedNow = DateTime(2024, 3, 10, 12);
  final data = ImpactChartData(
    granularity: InsightsGranularity.day,
    bucketStarts: [DateTime(2024, 3, 4), DateTime(2024, 3, 5)],
    seriesKeys: const ['a', 'b'],
    values: const [
      [2, 1],
      [1, 3],
    ],
  );
  final resolver = PaletteSeriesResolver(
    orderedKeys: const ['a', 'b'],
    unknownLabel: 'Unknown',
    otherLabel: 'Other',
  );

  Future<void> pumpBars(
    WidgetTester tester, {
    bool shareMode = false,
    String? isolatedKey,
    int? selectedBucketIndex,
    ValueChanged<int>? onBucketTap,
  }) async {
    await withClock(Clock.fixed(fixedNow), () async {
      await tester.pumpWidget(
        makeTestableWidget(
          SizedBox(
            width: 600,
            height: 260,
            child: ImpactStackedBars(
              data: data,
              resolver: resolver,
              metric: ConsumptionMetric.cost,
              shareMode: shareMode,
              isolatedKey: isolatedKey,
              selectedBucketIndex: selectedBucketIndex,
              onBucketTap: onBucketTap,
            ),
          ),
        ),
      );
      await tester.pump();
    });
  }

  BarChart readChart(WidgetTester tester) =>
      tester.widget<BarChart>(find.byType(BarChart));

  group('firstFutureBucket / elapsedImpactBucketCount', () {
    test('counts buckets that start on or before today', () {
      withClock(Clock.fixed(fixedNow), () {
        // Both 3/4 and 3/5 are before "today" 3/10 → all elapsed.
        expect(elapsedImpactBucketCount(data), 2);
        // A future bucket is excluded.
        final withFuture = ImpactChartData(
          granularity: InsightsGranularity.day,
          bucketStarts: [DateTime(2024, 3, 4), DateTime(2024, 3, 20)],
          seriesKeys: const ['a'],
          values: const [
            [1, 1],
          ],
        );
        expect(elapsedImpactBucketCount(withFuture), 1);
      });
    });
  });

  group('share mode', () {
    testWidgets('normalizes each bar to 100% (axis maxY 1)', (tester) async {
      await pumpBars(tester, shareMode: true);
      final chart = readChart(tester);
      expect(chart.data.maxY, 1.0);
      // Every non-empty bar's stacked top reaches 1.0.
      for (final group in chart.data.barGroups) {
        expect(group.barRods.single.toY, closeTo(1.0, 1e-9));
      }
      // Bucket 0: a=2/3 sits below b=1/3 (stacked, largest first at baseline).
      final rods = chart.data.barGroups[0].barRods.single.rodStackItems;
      expect(rods.first.toY, closeTo(2 / 3, 1e-9));
    });
  });

  group('legend isolation re-baselines to a single series', () {
    testWidgets('isolating draws only that series from the baseline', (
      tester,
    ) async {
      await pumpBars(tester, isolatedKey: 'a');
      final chart = readChart(tester);
      // Only the isolated series is drawn — siblings are hidden, not dimmed,
      // so its own trajectory reads from y=0.
      final rods = chart.data.barGroups[0].barRods.single.rodStackItems;
      expect(rods, hasLength(1));
      expect(rods[0].color?.a, 1.0);
      // Axis rescales to the isolated series' own ceiling (a's max is 2).
      expect(chart.data.maxY, 2.0);
    });

    testWidgets('no isolation stacks every series at full alpha', (
      tester,
    ) async {
      await pumpBars(tester);
      final rods = readChart(
        tester,
      ).data.barGroups[0].barRods.single.rodStackItems;
      expect(rods, hasLength(2));
      expect(rods[0].color?.a, 1.0);
      expect(rods[1].color?.a, 1.0);
    });
  });

  group('drilled-bucket highlight', () {
    testWidgets('the selected bar keeps full alpha + accent edge; others dim', (
      tester,
    ) async {
      await pumpBars(tester, selectedBucketIndex: 0);
      final groups = readChart(tester).data.barGroups;
      // Bucket 0 selected: an accent outline and full-alpha fill.
      expect(groups[0].barRods.single.borderSide.width, 1.5);
      expect(groups[0].barRods.single.rodStackItems[0].color?.a, 1.0);
      // Bucket 1 (not selected) recedes.
      expect(
        groups[1].barRods.single.rodStackItems[0].color?.a,
        lessThan(1.0),
      );
    });
  });

  group('bucket tap', () {
    testWidgets('a real tap on a bar reports its index (drill hook)', (
      tester,
    ) async {
      int? tapped;
      await pumpBars(tester, onBucketTap: (i) => tapped = i);
      // spaceAround leaves a gap dead-centre, so aim at the left bar column.
      final rect = tester.getRect(find.byType(BarChart));
      await tester.tapAt(Offset(rect.left + rect.width * 0.28, rect.center.dy));
      await tester.pump();
      expect(tapped, isNotNull);
    });
  });

  group('ImpactChartLegend', () {
    testWidgets('tapping an entry reports its key; isolation flags selection', (
      tester,
    ) async {
      String? toggled;
      var called = false;
      await tester.pumpWidget(
        makeTestableWidget(
          ImpactChartLegend(
            seriesKeys: const ['a', 'b'],
            rolledUpCount: 0,
            resolver: resolver,
            isolatedKey: 'a',
            onToggle: (key) {
              toggled = key;
              called = true;
            },
          ),
        ),
      );

      // Both entries render (isolation is a visual state, not a filter).
      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);

      await tester.tap(find.text('b'));
      await tester.pump();
      expect(called, isTrue);
      expect(toggled, 'b');
    });
  });
}
