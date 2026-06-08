import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:tinycolor2/tinycolor2.dart';

import 'time_series_bar_chart_test_helpers.dart';

void main() {
  // Fixed 30-day range used across most tests.
  final rangeStart = DateTime(2024, 3);
  final rangeEnd = DateTime(2024, 3, 31);

  group('TimeSeriesBarChart — widget structure', () {
    testWidgets('renders a BarChart widget', (tester) async {
      await hPumpChart(
        tester,
        data: [
          Observation(DateTime(2024, 3, 10), 5),
          Observation(DateTime(2024, 3, 20), 10),
        ],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(find.byType(BarChart), findsOneWidget);
      // Both observations land as rendered bar groups, not just a frame.
      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final byX = {
        for (final g in barChart.data.barGroups) g.x: g.barRods.first.toY,
      };
      expect(byX[DateTime(2024, 3, 10).millisecondsSinceEpoch], 5.0);
      expect(byX[DateTime(2024, 3, 20).millisecondsSinceEpoch], 10.0);
    });

    testWidgets('wraps chart in a Padding widget', (tester) async {
      await hPumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(find.byType(Padding), findsWidgets);
    });
  });

  group('TimeSeriesBarChart — bar group mapping', () {
    testWidgets('maps each observation to a BarChartGroupData with correct x', (
      tester,
    ) async {
      final obs1 = Observation(DateTime(2024, 3, 5), 42);
      final obs2 = Observation(DateTime(2024, 3, 15), 88);

      await hPumpChart(
        tester,
        data: [obs1, obs2],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final groups = barChart.data.barGroups;

      // The range fills in empty days; obs1 and obs2 must appear in the groups.
      final xs = groups.map((g) => g.x).toSet();
      expect(
        xs,
        contains(obs1.dateTime.millisecondsSinceEpoch),
        reason: 'obs1 x must be present',
      );
      expect(
        xs,
        contains(obs2.dateTime.millisecondsSinceEpoch),
        reason: 'obs2 x must be present',
      );
    });

    testWidgets('each bar group has exactly one rod', (tester) async {
      await hPumpChart(
        tester,
        data: [
          Observation(DateTime(2024, 3, 10), 7),
        ],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      for (final group in barChart.data.barGroups) {
        expect(
          group.barRods,
          hasLength(1),
          reason: 'every group must have exactly one rod',
        );
      }
    });

    testWidgets('bar rod toY matches the observation value', (tester) async {
      final obs = Observation(DateTime(2024, 3, 10), 99);
      await hPumpChart(
        tester,
        data: [obs],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final targetX = obs.dateTime.millisecondsSinceEpoch;
      final group = barChart.data.barGroups.firstWhere((g) => g.x == targetX);
      expect(group.barRods.first.toY, 99.0);
    });

    testWidgets('colorByValue callback is applied to each rod', (tester) async {
      const redColor = Colors.red;
      await hPumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 5)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        colorByValue: (_) => redColor,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final targetX = DateTime(2024, 3, 10).millisecondsSinceEpoch;
      final group = barChart.data.barGroups.firstWhere((g) => g.x == targetX);
      expect(group.barRods.first.color, redColor);
    });

    testWidgets('empty data yields bar groups only for in-range empty days', (
      tester,
    ) async {
      // A 30-day range with no real observations still generates a group for
      // every day in range (filled with value=0).
      await hPumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      // 31 days in [Mar 1, Mar 31] inclusive.
      expect(barChart.data.barGroups, hasLength(31));
    });

    testWidgets('empty-day placeholder has rod value 0', (tester) async {
      // With no real data every rod should have toY == 0.
      await hPumpChart(
        tester,
        data: [],
        rangeStart: DateTime(2024, 3),
        rangeEnd: DateTime(2024, 3, 5),
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      for (final group in barChart.data.barGroups) {
        expect(
          group.barRods.first.toY,
          0.0,
          reason: 'placeholder bar rod must be 0',
        );
      }
    });
  });

  group('TimeSeriesBarChart — grid interval by range length', () {
    for (final testCase in [
      (
        label: '>182 days → gridInterval=30',
        start: DateTime(2024),
        end: DateTime(2024, 8), // ~213 days
        expectedFactor: 30,
      ),
      (
        label: '93–182 days → gridInterval=14',
        start: DateTime(2024),
        end: DateTime(2024, 4, 15), // ~105 days
        expectedFactor: 14,
      ),
      (
        label: '31–92 days → gridInterval=7',
        start: DateTime(2024),
        end: DateTime(2024, 3), // ~60 days
        expectedFactor: 7,
      ),
      (
        label: '<=30 days → gridInterval=1',
        start: DateTime(2024, 3),
        end: DateTime(2024, 3, 15), // 14 days
        expectedFactor: 1,
      ),
    ]) {
      testWidgets(testCase.label, (tester) async {
        await hPumpChart(
          tester,
          data: [],
          rangeStart: testCase.start,
          rangeEnd: testCase.end,
        );

        final barChart = tester.widget<BarChart>(find.byType(BarChart));
        final expectedInterval =
            Duration.millisecondsPerDay.toDouble() * testCase.expectedFactor;
        expect(
          barChart.data.gridData.verticalInterval,
          expectedInterval,
          reason: testCase.label,
        );
      });
    }
  });

  group('TimeSeriesBarChart — grid line callbacks', () {
    testWidgets('getDrawingHorizontalLine returns gridLine', (tester) async {
      await hPumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final result = barChart.data.gridData.getDrawingHorizontalLine(0);
      expect(result, equals(gridLine));
    });

    testWidgets('getDrawingVerticalLine returns gridLine', (tester) async {
      await hPumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final result = barChart.data.gridData.getDrawingVerticalLine(0);
      expect(result, equals(gridLine));
    });
  });

  group('TimeSeriesBarChart — tooltip callbacks', () {
    testWidgets('getTooltipColor derives from the desaturated theme primary', (
      tester,
    ) async {
      await hPumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 5)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final tooltipData = barChart.data.barTouchData.touchTooltipData;

      // Pass a BarChartGroupData to satisfy the callback signature.
      final group = barChart.data.barGroups.first;
      final color = tooltipData.getTooltipColor(group);
      final theme = Theme.of(tester.element(find.byType(BarChart)));
      expect(color, theme.primaryColor.desaturate());
    });

    testWidgets('getTooltipItem formats numeric value with unit', (
      tester,
    ) async {
      final obs = Observation(DateTime(2024, 3, 10), 1234.5);
      await hPumpChart(
        tester,
        data: [obs],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        unit: 'kg',
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final tooltipData = barChart.data.barTouchData.touchTooltipData;

      final targetX = obs.dateTime.millisecondsSinceEpoch;
      final group = barChart.data.barGroups.firstWhere((g) => g.x == targetX);
      final rod = group.barRods.first;

      final item = tooltipData.getTooltipItem(group, 0, rod, 0);

      expect(item, isNotNull);
      expect(item!.text, contains('1,234.5'));
      expect(item.text, contains('kg'));
    });

    testWidgets('getTooltipItem includes formatted date', (tester) async {
      final obs = Observation(DateTime(2024, 3, 15), 42);
      await hPumpChart(
        tester,
        data: [obs],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final tooltipData = barChart.data.barTouchData.touchTooltipData;

      final targetX = obs.dateTime.millisecondsSinceEpoch;
      final group = barChart.data.barGroups.firstWhere((g) => g.x == targetX);
      final rod = group.barRods.first;

      final item = tooltipData.getTooltipItem(group, 0, rod, 0);

      expect(item, isNotNull);
      // chartDateFormatterYMD uses DateFormat.yMMMd() → e.g. "Mar 15, 2024"
      expect(item!.text, contains('Mar'));
      expect(item.text, contains('15'));
    });

    testWidgets(
      'getTooltipItem formats hours as HH:MM when valueInHours is true',
      (
        tester,
      ) async {
        // 1.5 hours → "01:30"
        final obs = Observation(DateTime(2024, 3, 10), 1.5);
        await hPumpChart(
          tester,
          data: [obs],
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          valueInHours: true,
          unit: 'h',
        );

        final barChart = tester.widget<BarChart>(find.byType(BarChart));
        final tooltipData = barChart.data.barTouchData.touchTooltipData;

        final targetX = obs.dateTime.millisecondsSinceEpoch;
        final group = barChart.data.barGroups.firstWhere((g) => g.x == targetX);
        final rod = group.barRods.first;

        final item = tooltipData.getTooltipItem(group, 0, rod, 0);

        expect(item, isNotNull);
        // hoursToHhMm(1.5) == "01:30"
        expect(item!.text, contains('01:30'));
      },
    );
  });
}
