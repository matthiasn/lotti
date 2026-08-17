import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/charts/utils.dart';

import '../../../../../../helpers/chart_tooltip_text.dart';

import 'time_series_line_chart_test_helpers.dart';

void main() {
  // Fixed range used across most tests (30 days).
  final rangeStart = DateTime(2024, 3);
  final rangeEnd = DateTime(2024, 3, 31);

  group('TimeSeriesLineChart — widget structure', () {
    testWidgets('renders a LineChart widget', (tester) async {
      await hPumpChart(
        tester,
        data: [
          Observation(DateTime(2024, 3, 10), 5),
          Observation(DateTime(2024, 3, 20), 10),
        ],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(find.byType(LineChart), findsOneWidget);
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

  group('TimeSeriesLineChart — spots and min/max', () {
    testWidgets('maps observations to FlSpots with correct x and y values', (
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

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final spots = lineChart.data.lineBarsData.first.spots;

      expect(spots, hasLength(2));
      expect(spots[0].x, obs1.dateTime.millisecondsSinceEpoch.toDouble());
      expect(spots[0].y, 42.0);
      expect(spots[1].x, obs2.dateTime.millisecondsSinceEpoch.toDouble());
      expect(spots[1].y, 88.0);
    });

    testWidgets('empty data yields empty spots list', (tester) async {
      await hPumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.lineBarsData.first.spots, isEmpty);
    });

    testWidgets('minY/maxY are nice-axis bounds around the data', (
      tester,
    ) async {
      await hPumpChart(
        tester,
        data: [
          Observation(DateTime(2024, 3, 5), 7.3),
          Observation(DateTime(2024, 3, 15), 12.8),
        ],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      // Data spans floor(7.3)=7 .. ceil(12.8)=13 → niceAxis(7, 13).
      final axis = niceAxis(7, 13);
      expect(lineChart.data.minY, axis.min);
      expect(lineChart.data.maxY, axis.max);
      // Nice bounds wrap the data without clipping it.
      expect(lineChart.data.minY, lessThanOrEqualTo(7.3));
      expect(lineChart.data.maxY, greaterThanOrEqualTo(12.8));
      // Left-axis tick interval is the same nice interval.
      expect(
        lineChart.data.titlesData.leftTitles.sideTitles.interval,
        axis.interval,
      );
    });

    testWidgets('empty data uses nice-axis bounds of the 0..1 fallback', (
      tester,
    ) async {
      await hPumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      // Empty data falls back to minY=0, maxY=1 → niceAxis(0, 1).
      final axis = niceAxis(0, 1);
      expect(lineChart.data.minY, axis.min);
      expect(lineChart.data.maxY, axis.max);
    });

    testWidgets('single observation: nice bounds wrap the value', (
      tester,
    ) async {
      await hPumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 50)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      // floor(50)=50, ceil(50)=50 → niceAxis(50, 50).
      final axis = niceAxis(50, 50);
      expect(lineChart.data.minY, axis.min);
      expect(lineChart.data.maxY, axis.max);
      expect(lineChart.data.maxY, greaterThan(lineChart.data.minY));
      expect(lineChart.data.lineBarsData.single.dotData.show, isTrue);
    });

    testWidgets('multiple observations keep point markers hidden', (
      tester,
    ) async {
      await hPumpChart(
        tester,
        data: [
          Observation(DateTime(2024, 3, 10), 50),
          Observation(DateTime(2024, 3, 11), 51),
        ],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.lineBarsData.single.dotData.show, isFalse);
    });

    testWidgets('reference lines render and participate in axis bounds', (
      tester,
    ) async {
      final reference = HorizontalLine(y: 5);
      await hPumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 10)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        horizontalLines: [reference],
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.extraLinesData.horizontalLines, [reference]);
      expect(lineChart.data.minY, lessThanOrEqualTo(reference.y));
      expect(lineChart.data.maxY, greaterThanOrEqualTo(10));
    });
  });

  group('TimeSeriesLineChart — x-axis range', () {
    testWidgets('minX and maxX match rangeStart and rangeEnd', (tester) async {
      await hPumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(
        lineChart.data.minX,
        rangeStart.millisecondsSinceEpoch.toDouble(),
      );
      expect(
        lineChart.data.maxX,
        rangeEnd.millisecondsSinceEpoch.toDouble(),
      );
    });
  });

  group('TimeSeriesLineChart — grid line callbacks', () {
    testWidgets(
      'getDrawingHorizontalLine returns the tokenized chart gridline',
      (tester) async {
        await hPumpChart(
          tester,
          data: [Observation(DateTime(2024, 3, 10), 5)],
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

        final tokens = tester.element(find.byType(LineChart)).designTokens;
        final lineChart = tester.widget<LineChart>(find.byType(LineChart));
        final result = lineChart.data.gridData.getDrawingHorizontalLine(0);
        expect(result.color, tokens.colors.decorative.level01);
        expect(result.strokeWidth, 1);
      },
    );

    testWidgets('vertical gridlines are disabled and interval is nice', (
      tester,
    ) async {
      await hPumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 12.8)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.gridData.drawVerticalLine, isFalse);
      // Horizontal interval is the nice-axis tick interval, finite & positive.
      expect(
        lineChart.data.gridData.horizontalInterval,
        isNot(double.maxFinite),
      );
      expect(lineChart.data.gridData.horizontalInterval, greaterThan(0));
    });
  });

  group('TimeSeriesLineChart — tooltip callbacks', () {
    testWidgets('getTooltipColor returns a Color', (tester) async {
      await hPumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 5)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final tooltipData = lineChart.data.lineTouchData.touchTooltipData;

      // Build a minimal bar data to satisfy LineBarSpot constructor.
      final barData = LineChartBarData(
        spots: const [FlSpot(0, 5)],
      );
      final spot = LineBarSpot(barData, 0, const FlSpot(0, 5));
      final color = tooltipData.getTooltipColor(spot);
      expect(color, isA<Color>());
    });

    testWidgets('getTooltipItems returns one item per spot', (tester) async {
      await hPumpChart(
        tester,
        data: [
          Observation(DateTime(2024, 3, 10), 12.5),
          Observation(DateTime(2024, 3, 15), 25),
        ],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final tooltipData = lineChart.data.lineTouchData.touchTooltipData;

      final barData = LineChartBarData(
        spots: const [FlSpot(0, 12.5), FlSpot(1, 25)],
      );
      final spots = [
        LineBarSpot(barData, 0, const FlSpot(0, 12.5)),
        LineBarSpot(barData, 0, const FlSpot(1, 25)),
      ];
      final items = tooltipData.getTooltipItems(spots);

      expect(items, hasLength(2));
    });

    testWidgets('getTooltipItems formats value with unit in first TextSpan', (
      tester,
    ) async {
      await hPumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 1234.5)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        unit: 'kg',
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final tooltipData = lineChart.data.lineTouchData.touchTooltipData;

      final barData = LineChartBarData(
        spots: const [FlSpot(0, 1234.5)],
      );
      final spots = [LineBarSpot(barData, 0, const FlSpot(0, 1234.5))];
      final items = tooltipData.getTooltipItems(spots);

      expect(items, hasLength(1));
      final item = items.first!;
      // The value rides UNDER the date header now, so it is the second span.
      final valueSpan = item.children![1];
      expect(valueSpan.toPlainText(), contains('1,234.5'));
      expect(valueSpan.toPlainText(), contains('kg'));
    });

    testWidgets('getTooltipItems leads with the formatted date header', (
      tester,
    ) async {
      final obsTime = DateTime(2024, 3, 15, 14, 30);
      await hPumpChart(
        tester,
        data: [Observation(obsTime, 7)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final tooltipData = lineChart.data.lineTouchData.touchTooltipData;

      final xMs = obsTime.millisecondsSinceEpoch.toDouble();
      final barData = LineChartBarData(
        spots: [FlSpot(xMs, 7)],
      );
      final spots = [LineBarSpot(barData, 0, FlSpot(xMs, 7))];
      final items = tooltipData.getTooltipItems(spots);

      final item = items.first!;
      final dateSpan = item.children!.first;
      // chartDateFormatterFull renders the month in the app's language and
      // the clock on the device's setting — this harness is a 12-hour device,
      // where the old hard-wired `HH:mm` would still have said "14:30".
      expect(dateSpan.toPlainText(), contains('Mar 15'));
      expect(dateSpan.toPlainText(), contains('2:30'));
      expect(dateSpan.toPlainText(), contains('PM'));
    });

    testWidgets('getTooltipItems with empty spots list returns empty list', (
      tester,
    ) async {
      await hPumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final tooltipData = lineChart.data.lineTouchData.touchTooltipData;

      final items = tooltipData.getTooltipItems([]);
      expect(items, isEmpty);
    });

    testWidgets('date-only tooltip preserves a canonical UTC day key', (
      tester,
    ) async {
      final obsTime = DateTime.utc(2024, 3, 15);
      await hPumpChart(
        tester,
        data: [Observation(obsTime, 7)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        dateOnly: true,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final tooltipData = lineChart.data.lineTouchData.touchTooltipData;
      final spot = FlSpot(obsTime.millisecondsSinceEpoch.toDouble(), 7);
      final barData = LineChartBarData(spots: [spot]);
      final items = tooltipData.getTooltipItems([
        LineBarSpot(barData, 0, spot),
      ]);

      // The date is the tooltip's HEADER — one line naming the day, above the
      // value it frames — not a trailing line under each value.
      expect(items.single!.children!.first.toPlainText(), 'Mar 15\n');
      expect(lineTooltipText(items.single!), 'Mar 15\n7');
    });
  });
}
