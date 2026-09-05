import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a [TimeSeriesLineChart] inside a fixed-size surface so that
/// fl_chart's layout delegate fires and the widget tree is fully exercised.
/// Calls [addTearDown(tester.view.reset)] per the conventions.
Future<void> hPumpChart(
  WidgetTester tester, {
  required List<Observation> data,
  required DateTime rangeStart,
  required DateTime rangeEnd,
  String unit = '',
  bool dateOnly = false,
  List<HorizontalLine> horizontalLines = const [],
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
            dateOnly: dateOnly,
            horizontalLines: horizontalLines,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
