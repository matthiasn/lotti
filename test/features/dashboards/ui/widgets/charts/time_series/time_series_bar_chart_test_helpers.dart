import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/widgets/charts/utils.dart';

import '../../../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a [TimeSeriesBarChart] inside a fixed-size surface so that
/// fl_chart's layout delegate fires and the widget tree is fully exercised.
/// Calls [addTearDown(tester.view.reset)] per the conventions.
Future<void> hPumpChart(
  WidgetTester tester, {
  required List<Observation> data,
  required DateTime rangeStart,
  required DateTime rangeEnd,
  String unit = '',
  bool valueInHours = false,
  ColorByValue? colorByValue,
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
          child: TimeSeriesBarChart(
            data: data,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            unit: unit,
            valueInHours: valueInHours,
            colorByValue: colorByValue ?? (_) => Colors.blue,
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
