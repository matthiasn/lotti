import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/state/health_chart_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_bp_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';

import '../../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Shared pump helper
// ---------------------------------------------------------------------------

/// Pumps a [DashboardHealthBpChart] with the given observation overrides.
/// Calls [addTearDown(tester.view.reset)] per the conventions.
///
/// The card now renders an empty-state message (and no [LineChart]) when both
/// series are empty, so when the caller supplies no observations this helper
/// seeds a single systolic reading. That keeps the chart mounted for axis,
/// gridline, and tooltip-callback tests that don't care about specific data.
Future<LineChart> hPumpBpChart(
  WidgetTester tester, {
  required DateTime rangeStart,
  required DateTime rangeEnd,
  List<Observation> systolicObservations = const [],
  List<Observation> diastolicObservations = const [],
}) async {
  tester.view.physicalSize = const Size(1000, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final effectiveSystolic =
      systolicObservations.isEmpty && diastolicObservations.isEmpty
      ? [Observation(rangeStart, 120)]
      : systolicObservations;

  await tester.pumpWidget(
    makeTestableWidget(
      DashboardHealthBpChart(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
      overrides: [
        healthObservationsControllerProvider((
          healthDataType: 'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        )).overrideWithBuild((ref, notifier) => effectiveSystolic),
        healthObservationsControllerProvider((
          healthDataType: 'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        )).overrideWithBuild((ref, notifier) => diastolicObservations),
      ],
    ),
  );
  await tester.pump();
  return tester.widget<LineChart>(find.byType(LineChart));
}
