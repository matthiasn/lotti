import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';

import 'time_series_multiline_chart_test_helpers.dart';

void main() {
  // Fixed 30-day range used across most tests.
  final rangeStart = DateTime(2024, 3);
  final rangeEnd = DateTime(2024, 3, 31);

  group('TimeSeriesMultiLineChart — widget structure', () {
    testWidgets('renders a LineChart widget', (tester) async {
      await hPumpChart(
        tester,
        lineBarsData: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('wraps chart in a Padding widget', (tester) async {
      await hPumpChart(
        tester,
        lineBarsData: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(find.byType(Padding), findsWidgets);
    });
  });

  group('TimeSeriesMultiLineChart — lineBarsData passthrough', () {
    testWidgets('empty lineBarsData yields zero series in LineChart', (
      tester,
    ) async {
      await hPumpChart(
        tester,
        lineBarsData: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.lineBarsData, isEmpty);
    });

    testWidgets('single series is passed through unchanged', (tester) async {
      final bar = makeBarData([
        (DateTime(2024, 3, 5).millisecondsSinceEpoch.toDouble(), 42),
        (DateTime(2024, 3, 15).millisecondsSinceEpoch.toDouble(), 88),
      ]);

      await hPumpChart(
        tester,
        lineBarsData: [bar],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.lineBarsData, hasLength(1));
      final spots = lineChart.data.lineBarsData.first.spots;
      expect(spots, hasLength(2));
      expect(spots[0].y, 42.0);
      expect(spots[1].y, 88.0);
    });

    testWidgets('multiple series are all passed through', (tester) async {
      final bar1 = makeBarData([
        (DateTime(2024, 3, 5).millisecondsSinceEpoch.toDouble(), 10),
      ], color: Colors.red);
      final bar2 = makeBarData([
        (DateTime(2024, 3, 10).millisecondsSinceEpoch.toDouble(), 20),
      ], color: Colors.green);
      final bar3 = makeBarData([
        (DateTime(2024, 3, 20).millisecondsSinceEpoch.toDouble(), 30),
      ], color: Colors.blue); // ignore: avoid_redundant_argument_values

      await hPumpChart(
        tester,
        lineBarsData: [bar1, bar2, bar3],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.lineBarsData, hasLength(3));
    });

    testWidgets('per-series colors are preserved for each bar', (tester) async {
      final bar1 = makeBarData([
        (DateTime(2024, 3, 5).millisecondsSinceEpoch.toDouble(), 10),
      ], color: Colors.red);
      final bar2 = makeBarData([
        (DateTime(2024, 3, 10).millisecondsSinceEpoch.toDouble(), 20),
      ], color: Colors.green);

      await hPumpChart(
        tester,
        lineBarsData: [bar1, bar2],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.lineBarsData[0].color, Colors.red);
      expect(lineChart.data.lineBarsData[1].color, Colors.green);
    });

    testWidgets('spot x values match the millisecondsSinceEpoch timestamps', (
      tester,
    ) async {
      final obs1 = DateTime(2024, 3, 5);
      final obs2 = DateTime(2024, 3, 20);

      final bar = makeBarData([
        (obs1.millisecondsSinceEpoch.toDouble(), 55),
        (obs2.millisecondsSinceEpoch.toDouble(), 77),
      ]);

      await hPumpChart(
        tester,
        lineBarsData: [bar],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final spots = lineChart.data.lineBarsData.first.spots;
      expect(spots[0].x, obs1.millisecondsSinceEpoch.toDouble());
      expect(spots[1].x, obs2.millisecondsSinceEpoch.toDouble());
    });
  });

  group('TimeSeriesMultiLineChart — x-axis range', () {
    testWidgets('minX and maxX match rangeStart and rangeEnd', (tester) async {
      await hPumpChart(
        tester,
        lineBarsData: [],
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

  group('TimeSeriesMultiLineChart — min/max Y values', () {
    testWidgets('minY accounts for 20% padding below minVal', (tester) async {
      // minVal=10, maxVal=20: valRange=10, minY = max(10 - 10*0.2, 0) = 8
      await hPumpChart(
        tester,
        lineBarsData: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        minVal: 10,
        maxVal: 20,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.minY, 8.0);
    });

    testWidgets('minY is clamped to 0 when padding would go negative', (
      tester,
    ) async {
      // minVal=1, maxVal=11: valRange=10, minY = max(1 - 10*0.2, 0) = max(-1, 0) = 0
      await hPumpChart(
        tester,
        lineBarsData: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        minVal: 1,
        maxVal: 11,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.minY, 0.0);
    });

    testWidgets('maxY adds 20% of value range above maxVal', (tester) async {
      // minVal=0, maxVal=100: valRange=100, maxY = 100 + 100*0.2 = 120
      await hPumpChart(
        tester,
        lineBarsData: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        minVal: 0, // ignore: avoid_redundant_argument_values
        maxVal: 100, // ignore: avoid_redundant_argument_values
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.maxY, 120.0);
    });

    testWidgets('both minY and maxY computed from provided minVal/maxVal', (
      tester,
    ) async {
      // minVal=50, maxVal=150: valRange=100
      // minY = max(50 - 20, 0) = 30
      // maxY = 150 + 20 = 170
      await hPumpChart(
        tester,
        lineBarsData: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        minVal: 50,
        maxVal: 150,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.minY, 30.0);
      expect(lineChart.data.maxY, 170.0);
    });
  });

  group('TimeSeriesMultiLineChart — grid interval by range length', () {
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
          lineBarsData: [],
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

  group('TimeSeriesMultiLineChart — grid line callbacks', () {
    testWidgets('getDrawingHorizontalLine returns gridLine', (tester) async {
      await hPumpChart(
        tester,
        lineBarsData: [],
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
        lineBarsData: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final result = lineChart.data.gridData.getDrawingVerticalLine(0);
      expect(result, equals(gridLine));
    });
  });
}
