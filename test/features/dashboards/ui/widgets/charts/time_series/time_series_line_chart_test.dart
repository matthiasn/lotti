import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/widgets/charts/utils.dart';

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

    testWidgets('minY is floor of minimum value minus 1', (tester) async {
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
      // floor(7.3) - 1 = 7 - 1 = 6
      expect(lineChart.data.minY, 6.0);
    });

    testWidgets('maxY is ceil of maximum value plus 1', (tester) async {
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
      // ceil(12.8) + 1 = 13 + 1 = 14
      expect(lineChart.data.maxY, 14.0);
    });

    testWidgets('empty data uses fallback minY=-1 and maxY=2', (tester) async {
      await hPumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      // minY = 0 - 1 = -1, maxY = 1 + 1 = 2
      expect(lineChart.data.minY, -1.0);
      expect(lineChart.data.maxY, 2.0);
    });

    testWidgets('single observation: minY = floor-1 and maxY = ceil+1', (
      tester,
    ) async {
      await hPumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 50)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      // floor(50) - 1 = 49; ceil(50) + 1 = 51
      expect(lineChart.data.minY, 49.0);
      expect(lineChart.data.maxY, 51.0);
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

  group('TimeSeriesLineChart — grid interval by range length', () {
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

        final lineChart = tester.widget<LineChart>(find.byType(LineChart));
        final expectedInterval =
            Duration.millisecondsPerDay.toDouble() * testCase.expectedFactor;
        expect(
          lineChart.data.gridData.verticalInterval,
          expectedInterval,
          reason: testCase.label,
        );
      });
    }
  });

  group('TimeSeriesLineChart — grid line callbacks', () {
    testWidgets('getDrawingHorizontalLine returns gridLine', (tester) async {
      await hPumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final result = lineChart.data.gridData.getDrawingHorizontalLine(0);
      expect(result, equals(gridLine));
    });

    testWidgets('getDrawingVerticalLine returns gridLine', (tester) async {
      await hPumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final result = lineChart.data.gridData.getDrawingVerticalLine(0);
      expect(result, equals(gridLine));
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
      // The first child TextSpan contains the formatted value + unit.
      final valueSpan = item.children!.first;
      expect(valueSpan.toPlainText(), contains('1,234.5'));
      expect(valueSpan.toPlainText(), contains('kg'));
    });

    testWidgets('getTooltipItems second TextSpan contains formatted date', (
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
      final dateSpan = item.children![1];
      // chartDateFormatterFull produces "MMM dd, HH:mm"
      expect(dateSpan.toPlainText(), contains('Mar 15'));
      expect(dateSpan.toPlainText(), contains('14:30'));
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
  });
}
