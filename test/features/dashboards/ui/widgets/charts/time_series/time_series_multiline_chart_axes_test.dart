import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'time_series_multiline_chart_test_helpers.dart';

void main() {
  // Fixed 30-day range used across most tests.
  final rangeStart = DateTime(2024, 3);
  final rangeEnd = DateTime(2024, 3, 31);

  group('TimeSeriesMultiLineChart — tooltip callbacks', () {
    testWidgets('getTooltipColor returns a Color', (tester) async {
      final bar = makeBarData([
        (DateTime(2024, 3, 10).millisecondsSinceEpoch.toDouble(), 5),
      ]);

      await hPumpChart(
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

      await hPumpChart(
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

      await hPumpChart(
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

      await hPumpChart(
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
      await hPumpChart(
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

      await hPumpChart(
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

      await hPumpChart(
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

      await hPumpChart(
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

        await hPumpChart(
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

      await hPumpChart(
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

      await hPumpChart(
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

      await hPumpChart(
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

      await hPumpChart(
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

      await hPumpChart(
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

      await hPumpChart(
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
