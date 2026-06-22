import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/charts/utils.dart';

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

    testWidgets('disables the implicit data-swap animation', (tester) async {
      await hPumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 5)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      // The chart rebuilds on every span change and background data refresh;
      // a non-zero duration would replay fl_chart's grow-from-baseline tween
      // each time — unsolicited motion. It must be pinned to zero.
      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      expect(barChart.duration, Duration.zero);
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

  group('TimeSeriesBarChart — horizontal grid interval from nice axis', () {
    testWidgets('horizontalInterval matches the nice-axis tick interval', (
      tester,
    ) async {
      // maxData=10 → niceAxis(0, 10, zeroBased: true) yields interval 5.
      await hPumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 10)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final expected = niceAxis(0, 10, zeroBased: true).interval;
      expect(barChart.data.gridData.horizontalInterval, expected);
      // And the left-axis tick interval uses the same nice interval.
      expect(
        barChart.data.titlesData.leftTitles.sideTitles.interval,
        expected,
      );
    });

    testWidgets('horizontalInterval scales with larger data maxima', (
      tester,
    ) async {
      // maxData=2400 → compact-friendly nice interval.
      await hPumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 2400)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      final expected = niceAxis(0, 2400, zeroBased: true).interval;
      expect(barChart.data.gridData.horizontalInterval, expected);
      expect(barChart.data.gridData.horizontalInterval, greaterThan(0));
    });
  });

  group('TimeSeriesBarChart — grid line callbacks', () {
    testWidgets(
      'getDrawingHorizontalLine returns the tokenized chart gridline',
      (tester) async {
        await hPumpChart(
          tester,
          data: [],
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

        final element = tester.element(find.byType(BarChart));
        final tokens = element.designTokens;
        final barChart = tester.widget<BarChart>(find.byType(BarChart));
        final result = barChart.data.gridData.getDrawingHorizontalLine(0);
        expect(result.color, tokens.colors.decorative.level01);
        expect(result.strokeWidth, 1);
      },
    );

    testWidgets('vertical gridlines are disabled', (tester) async {
      await hPumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final barChart = tester.widget<BarChart>(find.byType(BarChart));
      expect(barChart.data.gridData.drawVerticalLine, isFalse);
    });
  });

  group('TimeSeriesBarChart — tooltip callbacks', () {
    testWidgets('getTooltipColor uses the level-03 design-system surface', (
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
      final tokens = tester.element(find.byType(BarChart)).designTokens;
      expect(color, tokens.colors.background.level03);
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
