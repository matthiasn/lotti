import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_multiline_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';

import '../../../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a [TimeSeriesMultiLineChart] inside a fixed-size surface so that
/// fl_chart's layout delegate fires and the widget tree is fully exercised.
/// Calls [addTearDown(tester.view.reset)] per the conventions.
Future<void> _pumpChart(
  WidgetTester tester, {
  required List<LineChartBarData> lineBarsData,
  required DateTime rangeStart,
  required DateTime rangeEnd,
  num minVal = 0,
  num maxVal = 100,
  String unit = '',
  Size physicalSize = const Size(800, 600),
}) async {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Scaffold(
        body: SizedBox(
          width: physicalSize.width,
          height: physicalSize.height,
          child: TimeSeriesMultiLineChart(
            lineBarsData: lineBarsData,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            minVal: minVal,
            maxVal: maxVal,
            unit: unit,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Returns a minimal [TitleMeta] for testing bottom title widget callbacks.
TitleMeta makeMeta() {
  return TitleMeta(
    min: 0,
    max: 100,
    appliedInterval: 1,
    axisPosition: 0,
    formattedValue: '',
    parentAxisSize: 400,
    sideTitles: const SideTitles(showTitles: true),
    axisSide: AxisSide.bottom,
    rotationQuarterTurns: 0,
  );
}

/// Builds a simple [LineChartBarData] from a list of (x, y) pairs.
LineChartBarData makeBarData(
  List<(double, double)> points, {
  Color color = Colors.blue,
}) {
  return LineChartBarData(
    spots: points.map((p) => FlSpot(p.$1, p.$2)).toList(),
    color: color,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Fixed 30-day range used across most tests.
  final rangeStart = DateTime(2024, 3);
  final rangeEnd = DateTime(2024, 3, 31);

  group('TimeSeriesMultiLineChart — widget structure', () {
    testWidgets('renders a LineChart widget', (tester) async {
      await _pumpChart(
        tester,
        lineBarsData: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('wraps chart in a Padding widget', (tester) async {
      await _pumpChart(
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
      await _pumpChart(
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

      await _pumpChart(
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

      await _pumpChart(
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

      await _pumpChart(
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

      await _pumpChart(
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
      await _pumpChart(
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
      await _pumpChart(
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
      await _pumpChart(
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
      await _pumpChart(
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
      await _pumpChart(
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
        await _pumpChart(
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
      await _pumpChart(
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
      await _pumpChart(
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

  group('TimeSeriesMultiLineChart — tooltip callbacks', () {
    testWidgets('getTooltipColor returns a Color', (tester) async {
      final bar = makeBarData([
        (DateTime(2024, 3, 10).millisecondsSinceEpoch.toDouble(), 5),
      ]);

      await _pumpChart(
        tester,
        lineBarsData: [bar],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final tooltipData = lineChart.data.lineTouchData.touchTooltipData;

      final barData = LineChartBarData(spots: const [FlSpot(0, 5)]);
      final spot = LineBarSpot(barData, 0, const FlSpot(0, 5));
      final color = tooltipData.getTooltipColor(spot);
      expect(color, isA<Color>());
    });

    testWidgets('getTooltipItems returns one item per spot', (tester) async {
      final bar = makeBarData([
        (DateTime(2024, 3, 10).millisecondsSinceEpoch.toDouble(), 12),
        (DateTime(2024, 3, 15).millisecondsSinceEpoch.toDouble(), 25),
      ]);

      await _pumpChart(
        tester,
        lineBarsData: [bar],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final tooltipData = lineChart.data.lineTouchData.touchTooltipData;

      final barData = LineChartBarData(
        spots: const [FlSpot(0, 12), FlSpot(1, 25)],
      );
      final spots = [
        LineBarSpot(barData, 0, const FlSpot(0, 12)),
        LineBarSpot(barData, 0, const FlSpot(1, 25)),
      ];
      final items = tooltipData.getTooltipItems(spots);
      expect(items, hasLength(2));
    });

    testWidgets('getTooltipItems formats value as integer with unit', (
      tester,
    ) async {
      final bar = makeBarData([
        (DateTime(2024, 3, 10).millisecondsSinceEpoch.toDouble(), 1234),
      ]);

      await _pumpChart(
        tester,
        lineBarsData: [bar],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        unit: 'kg',
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final tooltipData = lineChart.data.lineTouchData.touchTooltipData;

      final barData = LineChartBarData(spots: const [FlSpot(0, 1234)]);
      final spots = [LineBarSpot(barData, 0, const FlSpot(0, 1234))];
      final items = tooltipData.getTooltipItems(spots);

      expect(items, hasLength(1));
      final item = items.first!;
      // First child TextSpan contains the integer value + unit
      final valueSpan = item.children!.first;
      expect(valueSpan.toPlainText(), contains('1234'));
      expect(valueSpan.toPlainText(), contains('kg'));
    });

    testWidgets('getTooltipItems second TextSpan contains formatted date', (
      tester,
    ) async {
      final obsTime = DateTime(2024, 3, 15, 14, 30);
      final xMs = obsTime.millisecondsSinceEpoch.toDouble();

      final bar = makeBarData([(xMs, 7)]);

      await _pumpChart(
        tester,
        lineBarsData: [bar],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final tooltipData = lineChart.data.lineTouchData.touchTooltipData;

      final barData = LineChartBarData(spots: [FlSpot(xMs, 7)]);
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
      await _pumpChart(
        tester,
        lineBarsData: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final tooltipData = lineChart.data.lineTouchData.touchTooltipData;

      final items = tooltipData.getTooltipItems([]);
      expect(items, isEmpty);
    });

    testWidgets('tooltip item uses empty string as base text', (tester) async {
      final bar = makeBarData([
        (DateTime(2024, 3, 10).millisecondsSinceEpoch.toDouble(), 99),
      ]);

      await _pumpChart(
        tester,
        lineBarsData: [bar],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final tooltipData = lineChart.data.lineTouchData.touchTooltipData;

      final barData = LineChartBarData(spots: const [FlSpot(0, 99)]);
      final spots = [LineBarSpot(barData, 0, const FlSpot(0, 99))];
      final items = tooltipData.getTooltipItems(spots);

      // Root text of the LineTooltipItem should be empty string
      expect(items.first!.text, '');
    });

    testWidgets('tooltip item has two children TextSpans', (tester) async {
      final bar = makeBarData([
        (DateTime(2024, 3, 10).millisecondsSinceEpoch.toDouble(), 42),
      ]);

      await _pumpChart(
        tester,
        lineBarsData: [bar],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        unit: 'bpm',
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final tooltipData = lineChart.data.lineTouchData.touchTooltipData;

      final barData = LineChartBarData(spots: const [FlSpot(0, 42)]);
      final spots = [LineBarSpot(barData, 0, const FlSpot(0, 42))];
      final items = tooltipData.getTooltipItems(spots);

      final item = items.first!;
      // children: [value+unit TextSpan, date TextSpan]
      expect(item.children, hasLength(2));
      expect(item.children!.first.toPlainText(), contains('42'));
      expect(item.children!.first.toPlainText(), contains('bpm'));
    });
  });

  group('TimeSeriesMultiLineChart — bottom title widgets', () {
    testWidgets('day=1 renders a SideTitleWidget', (tester) async {
      final start = DateTime(2024, 3);
      final end = DateTime(2024, 4, 30);

      await _pumpChart(
        tester,
        lineBarsData: [],
        rangeStart: start,
        rangeEnd: end,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final getTitles =
          lineChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

      final day1 = DateTime(2024, 3).millisecondsSinceEpoch.toDouble();
      final widget = getTitles(day1, makeMeta());
      expect(widget, isA<SideTitleWidget>());
    });

    testWidgets(
      'non-label day (e.g., day 7) in >=30-day range returns SizedBox',
      (tester) async {
        final start = DateTime(2024, 3);
        final end = DateTime(2024, 4, 30);

        await _pumpChart(
          tester,
          lineBarsData: [],
          rangeStart: start,
          rangeEnd: end,
        );

        final lineChart = tester.widget<LineChart>(find.byType(LineChart));
        final getTitles =
            lineChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

        final day7 = DateTime(2024, 3, 7).millisecondsSinceEpoch.toDouble();
        final widget = getTitles(day7, makeMeta());
        expect(widget, isA<SizedBox>());
      },
    );

    testWidgets('day=15 shows label when rangeInDays < 90', (tester) async {
      final start = DateTime(2024, 3);
      final end = DateTime(2024, 4, 30); // ~60 days

      await _pumpChart(
        tester,
        lineBarsData: [],
        rangeStart: start,
        rangeEnd: end,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final getTitles =
          lineChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

      final day15 = DateTime(2024, 3, 15).millisecondsSinceEpoch.toDouble();
      final widget = getTitles(day15, makeMeta());
      expect(
        widget,
        isA<SideTitleWidget>(),
        reason: 'day=15 should show in <90-day range',
      );
    });

    testWidgets('day=15 returns SizedBox in a >=90-day range', (tester) async {
      final start = DateTime(2024);
      final end = DateTime(2024, 5, 15); // ~135 days

      await _pumpChart(
        tester,
        lineBarsData: [],
        rangeStart: start,
        rangeEnd: end,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final getTitles =
          lineChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

      final day15 = DateTime(2024, 3, 15).millisecondsSinceEpoch.toDouble();
      final widget = getTitles(day15, makeMeta());
      expect(
        widget,
        isA<SizedBox>(),
        reason: 'day=15 should NOT show in >=90-day range',
      );
    });

    testWidgets('day=8 shows label when rangeInDays < 30', (tester) async {
      final start = DateTime(2024, 3);
      final end = DateTime(2024, 3, 20); // 19 days

      await _pumpChart(
        tester,
        lineBarsData: [],
        rangeStart: start,
        rangeEnd: end,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final getTitles =
          lineChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

      final day8 = DateTime(2024, 3, 8).millisecondsSinceEpoch.toDouble();
      final widget = getTitles(day8, makeMeta());
      expect(
        widget,
        isA<SideTitleWidget>(),
        reason: 'day=8 should show in <30-day range',
      );
    });

    testWidgets('day=8 returns SizedBox when rangeInDays >= 30', (
      tester,
    ) async {
      final start = DateTime(2024, 3);
      final end = DateTime(2024, 4, 15); // 45 days

      await _pumpChart(
        tester,
        lineBarsData: [],
        rangeStart: start,
        rangeEnd: end,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final getTitles =
          lineChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

      final day8 = DateTime(2024, 3, 8).millisecondsSinceEpoch.toDouble();
      final widget = getTitles(day8, makeMeta());
      expect(
        widget,
        isA<SizedBox>(),
        reason: 'day=8 should NOT show in >=30-day range',
      );
    });

    testWidgets('day=22 shows label when rangeInDays < 30', (tester) async {
      final start = DateTime(2024, 3);
      final end = DateTime(2024, 3, 20); // 19 days

      await _pumpChart(
        tester,
        lineBarsData: [],
        rangeStart: start,
        rangeEnd: end,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final getTitles =
          lineChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

      final day22 = DateTime(2024, 3, 22).millisecondsSinceEpoch.toDouble();
      final widget = getTitles(day22, makeMeta());
      expect(
        widget,
        isA<SideTitleWidget>(),
        reason: 'day=22 should show in <30-day range',
      );
    });
  });

  group('TimeSeriesMultiLineChart — multiple series spot mapping', () {
    testWidgets('each series has its own independent spots', (tester) async {
      final bar1 = makeBarData([
        (DateTime(2024, 3, 5).millisecondsSinceEpoch.toDouble(), 10),
        (DateTime(2024, 3, 10).millisecondsSinceEpoch.toDouble(), 20),
      ], color: Colors.red);
      final bar2 = makeBarData([
        (DateTime(2024, 3, 12).millisecondsSinceEpoch.toDouble(), 50),
        (DateTime(2024, 3, 18).millisecondsSinceEpoch.toDouble(), 60),
        (DateTime(2024, 3, 25).millisecondsSinceEpoch.toDouble(), 70),
      ], color: Colors.green);

      await _pumpChart(
        tester,
        lineBarsData: [bar1, bar2],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        minVal: 10,
        maxVal: 70,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.lineBarsData, hasLength(2));
      expect(lineChart.data.lineBarsData[0].spots, hasLength(2));
      expect(lineChart.data.lineBarsData[1].spots, hasLength(3));

      // Verify spot values per series
      expect(lineChart.data.lineBarsData[0].spots[0].y, 10.0);
      expect(lineChart.data.lineBarsData[0].spots[1].y, 20.0);
      expect(lineChart.data.lineBarsData[1].spots[0].y, 50.0);
      expect(lineChart.data.lineBarsData[1].spots[2].y, 70.0);
    });
  });
}
