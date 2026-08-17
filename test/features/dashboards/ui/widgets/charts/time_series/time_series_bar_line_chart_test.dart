import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_line_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';

import '../../../../../../helpers/chart_tooltip_text.dart';

import '../../../../../../widget_test_utils.dart';

void main() {
  final start = DateTime.utc(2026, 8);
  final end = DateTime.utc(2026, 8, 3);

  Future<void> pumpChart(
    WidgetTester tester, {
    List<Observation>? bars,
    List<Observation>? line,
    Locale? locale,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: SizedBox(
            width: 480,
            height: 240,
            child: TimeSeriesBarLineChart(
              barData:
                  bars ??
                  [
                    Observation(start, 6000),
                    Observation(end, 9000),
                  ],
              lineData: line ?? [Observation(end, 7500)],
              rangeStart: start,
              rangeEnd: end,
              maxVal: 10000,
              barColor: Colors.teal,
              lineColor: Colors.blue,
              barLabel: 'Steps per day',
              lineLabel: '7-day average',
              unit: 'steps',
              dateOnly: true,
              horizontalLines: [HorizontalLine(y: 10000)],
            ),
          ),
        ),
        locale: locale,
      ),
    );
    await tester.pump();
  }

  testWidgets('maps actual days to bars and leaves missing days empty', (
    tester,
  ) async {
    await pumpChart(tester);

    final bars = tester.widget<BarChart>(find.byType(BarChart));
    expect(bars.data.barGroups, hasLength(3));
    expect(
      bars.data.barGroups.map((group) => group.barRods.single.toY),
      [6000, bars.data.minY, 9000],
    );
    expect(bars.data.barGroups[1].barRods.single.color!.a, 0);

    final overlay = tester.widget<LineChart>(find.byType(LineChart));
    expect(overlay.data.lineBarsData, hasLength(2));
    expect(overlay.data.lineBarsData.first.spots.map((spot) => spot.x), [0, 2]);
    expect(overlay.data.lineBarsData.last.spots.single, const FlSpot(2, 7500));
    expect(overlay.data.lineBarsData.last.dashArray, isNotEmpty);
    expect(overlay.data.extraLinesData.horizontalLines.single.y, 10000);
  });

  testWidgets('shared overlay tooltip identifies actual and average values', (
    tester,
  ) async {
    await pumpChart(
      tester,
      bars: [Observation(end, 9000)],
      line: [Observation(end, 7500)],
    );

    final overlay = tester.widget<LineChart>(find.byType(LineChart));
    final tooltip = overlay.data.lineTouchData.touchTooltipData;
    final actualBar = LineChartBarData(spots: const [FlSpot(2, 9000)]);
    final averageBar = LineChartBarData(spots: const [FlSpot(2, 7500)]);
    final items = tooltip.getTooltipItems([
      LineBarSpot(actualBar, 0, const FlSpot(2, 9000)),
      LineBarSpot(averageBar, 1, const FlSpot(2, 7500)),
    ]);

    // ONE date for the whole tooltip, as a header above the value rows —
    // repeating it under each series printed "Aug 3" twice for one reading.
    expect(lineTooltipText(items[0]!), 'Aug 3\nSteps per day\n9,000 steps');
    expect(lineTooltipText(items[1]!), '7-day average\n7,500 steps');
    expect(
      'Aug 3'.allMatches(items.map((i) => lineTooltipText(i!)).join()).length,
      1,
    );
  });

  testWidgets('shared overlay tooltip uses the active app locale', (
    tester,
  ) async {
    await pumpChart(
      tester,
      bars: [Observation(end, 1234.5)],
      locale: const Locale('de'),
    );

    final overlay = tester.widget<LineChart>(find.byType(LineChart));
    final tooltip = overlay.data.lineTouchData.touchTooltipData;
    final actualBar = LineChartBarData(spots: const [FlSpot(2, 1234.5)]);
    final items = tooltip.getTooltipItems([
      LineBarSpot(actualBar, 0, const FlSpot(2, 1234.5)),
    ]);

    expect(lineTooltipText(items.single!), contains('1.234,5 steps'));
  });
}
