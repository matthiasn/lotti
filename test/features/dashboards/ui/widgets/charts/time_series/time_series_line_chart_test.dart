import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/widgets/charts/utils.dart';

import '../../../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a [TimeSeriesLineChart] inside a fixed-size surface so that
/// fl_chart's layout delegate fires and the widget tree is fully exercised.
/// Calls [addTearDown(tester.view.reset)] per the conventions.
Future<void> _pumpChart(
  WidgetTester tester, {
  required List<Observation> data,
  required DateTime rangeStart,
  required DateTime rangeEnd,
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
          child: TimeSeriesLineChart(
            data: data,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Fixed range used across most tests (30 days).
  final rangeStart = DateTime(2024, 3);
  final rangeEnd = DateTime(2024, 3, 31);

  group('TimeSeriesLineChart — widget structure', () {
    testWidgets('renders a LineChart widget', (tester) async {
      await _pumpChart(
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
      await _pumpChart(
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

      await _pumpChart(
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
      await _pumpChart(
        tester,
        data: [],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.lineBarsData.first.spots, isEmpty);
    });

    testWidgets('minY is floor of minimum value minus 1', (tester) async {
      await _pumpChart(
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
      await _pumpChart(
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
      await _pumpChart(
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
      await _pumpChart(
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
      await _pumpChart(
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
        await _pumpChart(
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
      await _pumpChart(
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
      await _pumpChart(
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
      await _pumpChart(
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
      await _pumpChart(
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
      await _pumpChart(
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
      await _pumpChart(
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
      await _pumpChart(
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

  group('TimeSeriesLineChart — bottom title widgets', () {
    testWidgets('day=1 renders a SideTitleWidget with a date label', (
      tester,
    ) async {
      // Use a range ≥30 days so that only day=1 triggers the label.
      final start = DateTime(2024, 3);
      final end = DateTime(2024, 4, 30);
      await _pumpChart(
        tester,
        data: [],
        rangeStart: start,
        rangeEnd: end,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final getTitles =
          lineChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

      // day=1 of any month must show a label regardless of range.
      final day1 = DateTime(2024, 3).millisecondsSinceEpoch.toDouble();
      final widget = getTitles(day1, makeMeta());

      // Must be a SideTitleWidget wrapping a ChartLabel, not SizedBox.shrink.
      expect(widget, isA<SideTitleWidget>());
    });

    testWidgets(
      'non-label day (e.g., day 7) in >=30-day range returns SizedBox',
      (tester) async {
        final start = DateTime(2024, 3);
        final end = DateTime(2024, 4, 30);
        await _pumpChart(
          tester,
          data: [],
          rangeStart: start,
          rangeEnd: end,
        );

        final lineChart = tester.widget<LineChart>(find.byType(LineChart));
        final getTitles =
            lineChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

        // day=7 is NOT 1, 8, 15, or 22 — should return SizedBox.shrink.
        final day7 = DateTime(2024, 3, 7).millisecondsSinceEpoch.toDouble();
        final widget = getTitles(day7, makeMeta());

        expect(widget, isA<SizedBox>());
      },
    );

    testWidgets('day=15 shows label when rangeInDays < 90', (tester) async {
      // Short range (< 90 days): day=15 should render a label.
      final shortStart = DateTime(2024, 3);
      final shortEnd = DateTime(2024, 4, 30); // ~60 days

      await _pumpChart(
        tester,
        data: [],
        rangeStart: shortStart,
        rangeEnd: shortEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final getTitles =
          lineChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

      final day15 = DateTime(2024, 3, 15).millisecondsSinceEpoch.toDouble();
      final widgetShort = getTitles(day15, makeMeta());
      expect(
        widgetShort,
        isA<SideTitleWidget>(),
        reason: 'day=15 should show in <90-day range',
      );
    });

    testWidgets('day=15 returns SizedBox in a >=90-day range', (tester) async {
      // Long range (>=90 days): day=15 should NOT render a label.
      final longStart = DateTime(2024);
      final longEnd = DateTime(2024, 5, 15); // ~135 days

      await _pumpChart(
        tester,
        data: [],
        rangeStart: longStart,
        rangeEnd: longEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final getTitles =
          lineChart.data.titlesData.bottomTitles.sideTitles.getTitlesWidget;

      final day15 = DateTime(2024, 3, 15).millisecondsSinceEpoch.toDouble();
      final widgetLong = getTitles(day15, makeMeta());
      expect(
        widgetLong,
        isA<SizedBox>(),
        reason: 'day=15 should NOT show in >=90-day range',
      );
    });

    testWidgets('day=8 shows label when rangeInDays < 30', (tester) async {
      // Short range (< 30 days): day=8 should show a label.
      final start = DateTime(2024, 3);
      final end = DateTime(2024, 3, 20); // 19 days

      await _pumpChart(
        tester,
        data: [],
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
        data: [],
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
        data: [],
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

  group('TimeSeriesLineChart — bar data configuration', () {
    testWidgets('lineBarsData contains exactly one series', (tester) async {
      await _pumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 5)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      expect(lineChart.data.lineBarsData, hasLength(1));
    });

    testWidgets('dot data is hidden (show: false)', (tester) async {
      await _pumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 5)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final bar = lineChart.data.lineBarsData.first;
      expect(bar.dotData.show, isFalse);
    });

    testWidgets('belowBarData is visible (show: true)', (tester) async {
      await _pumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 5)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final bar = lineChart.data.lineBarsData.first;
      expect(bar.belowBarData.show, isTrue);
    });

    testWidgets('bar gradient uses gradientColors', (tester) async {
      await _pumpChart(
        tester,
        data: [Observation(DateTime(2024, 3, 10), 5)],
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final lineChart = tester.widget<LineChart>(find.byType(LineChart));
      final bar = lineChart.data.lineBarsData.first;
      expect(bar.gradient, isA<LinearGradient>());
      final grad = bar.gradient! as LinearGradient;
      expect(grad.colors, gradientColors);
    });

    testWidgets(
      'belowBarData gradient has same colour count as gradientColors',
      (tester) async {
        await _pumpChart(
          tester,
          data: [Observation(DateTime(2024, 3, 10), 5)],
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );

        final lineChart = tester.widget<LineChart>(find.byType(LineChart));
        final bar = lineChart.data.lineBarsData.first;
        final belowGrad = bar.belowBarData.gradient! as LinearGradient;
        expect(belowGrad.colors, hasLength(gradientColors.length));
      },
    );
  });
}
