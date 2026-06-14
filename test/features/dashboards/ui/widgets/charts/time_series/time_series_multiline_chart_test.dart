import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

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
    testWidgets('minY/maxY are the nice-axis bounds of minVal..maxVal', (
      tester,
    ) async {
      await hPumpChart(
        tester,
        lineBarsData: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        minVal: 10,
        maxVal: 20,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final axis = niceAxis(10, 20);
      expect(lineChart.data.minY, axis.min);
      expect(lineChart.data.maxY, axis.max);
      // Nice bounds wrap the supplied data range.
      expect(lineChart.data.minY, lessThanOrEqualTo(10));
      expect(lineChart.data.maxY, greaterThanOrEqualTo(20));
    });

    testWidgets('nice bounds round outward for a wide range', (tester) async {
      await hPumpChart(
        tester,
        lineBarsData: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        minVal: 0, // ignore: avoid_redundant_argument_values
        maxVal: 100, // ignore: avoid_redundant_argument_values
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final axis = niceAxis(0, 100);
      expect(lineChart.data.minY, axis.min);
      expect(lineChart.data.maxY, axis.max);
      // Tick interval is the same nice interval used by the left axis.
      expect(
        lineChart.data.titlesData.leftTitles.sideTitles.interval,
        axis.interval,
      );
    });

    testWidgets('non-zero-based range keeps a tight nice window', (
      tester,
    ) async {
      await hPumpChart(
        tester,
        lineBarsData: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        minVal: 50,
        maxVal: 150,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final axis = niceAxis(50, 150);
      expect(lineChart.data.minY, axis.min);
      expect(lineChart.data.maxY, axis.max);
      // The window does not start at zero for an offset data range.
      expect(lineChart.data.minY, greaterThan(0));
      expect(lineChart.data.minY, lessThanOrEqualTo(50));
      expect(lineChart.data.maxY, greaterThanOrEqualTo(150));
    });
  });

  group('TimeSeriesMultiLineChart — grid line callbacks', () {
    testWidgets(
      'getDrawingHorizontalLine returns the tokenized chart gridline',
      (tester) async {
        await hPumpChart(
          tester,
          lineBarsData: [],
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
        lineBarsData: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        minVal: 0, // ignore: avoid_redundant_argument_values
        maxVal: 100, // ignore: avoid_redundant_argument_values
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.gridData.drawVerticalLine, isFalse);
      expect(
        lineChart.data.gridData.horizontalInterval,
        niceAxis(0, 100).interval,
      );
      expect(lineChart.data.gridData.horizontalInterval, greaterThan(0));
    });
  });
}
