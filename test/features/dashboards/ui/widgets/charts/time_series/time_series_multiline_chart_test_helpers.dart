import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_multiline_chart.dart';

import '../../../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a [TimeSeriesMultiLineChart] inside a fixed-size surface so that
/// fl_chart's layout delegate fires and the widget tree is fully exercised.
/// Calls [addTearDown(tester.view.reset)] per the conventions.
Future<void> hPumpChart(
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
