/// Screenshot harness for the dashboard chart cards.
///
/// Renders the representative chart types (measurement bar/line with the add
/// affordance, workout, health line/bar, blood pressure, BMI with its range
/// legend) stacked like a real dashboard, across dark + light themes and a
/// narrow desktop-detail-pane width. Writes PNGs to `screenshots/dashboards/`
/// (gitignored) for design review. Not a golden test — there are no stored
/// baselines; the assertions only guard that each scenario renders without
/// exceptions.
///
/// Opt-in (real-font loading leaks process-wide — see `main`). Run:
/// `LOTTI_SCREENSHOT_DIR=/tmp/dashboards fvm flutter test \
///   test/features/dashboards/ui/dashboard_charts_screenshots_test.dart`
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/health_chart_controller.dart';
import 'package:lotti/features/dashboards/state/measurables_controller.dart';
import 'package:lotti/features/dashboards/state/workout_chart_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_measurables_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_workout_chart.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import 'screenshot_fonts.dart';

const Size _desktopSize = Size(1280, 2400);
const ValueKey<String> _boundaryKey = ValueKey<String>('dashboard-screenshot');

final DateTime _rangeStart = DateTime(2026, 3);
final DateTime _rangeEnd = DateTime(2026, 3, 31);

const _measureBarId = 'screenshot-water';
const _measureLineId = 'screenshot-mood';

const _workoutConfig =
    DashboardItem.workoutChart(
          workoutType: 'running',
          displayName: 'Running calories',
          color: '#0000FF',
          valueType: WorkoutValueType.energy,
        )
        as DashboardWorkoutItem;
const _hrConfig =
    DashboardItem.healthChart(
          color: '#FF0000',
          healthType: 'HealthDataType.RESTING_HEART_RATE',
        )
        as DashboardHealthItem;
const _stepsConfig =
    DashboardItem.healthChart(
          color: '#00FF00',
          healthType: 'cumulative_step_count',
        )
        as DashboardHealthItem;
const _bpConfig =
    DashboardItem.healthChart(
          color: '#FF0000',
          healthType: 'BLOOD_PRESSURE',
        )
        as DashboardHealthItem;
const _bmiConfig =
    DashboardItem.healthChart(
          color: '#0000FF',
          healthType: 'BODY_MASS_INDEX',
        )
        as DashboardHealthItem;

MeasurableDataType _dataType({
  required String id,
  required String displayName,
  required String description,
  required String unitName,
  required AggregationType aggregationType,
}) {
  return MeasurableDataType(
    id: id,
    displayName: displayName,
    description: description,
    unitName: unitName,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
    vectorClock: const VectorClock({}),
    version: 1,
    aggregationType: aggregationType,
  );
}

/// A smooth, plausible-looking series across the range.
List<Observation> _series(
  double base,
  double amplitude, {
  int everyNthDay = 1,
}) {
  final days = _rangeEnd.difference(_rangeStart).inDays;
  return [
    for (var i = 0; i <= days; i += everyNthDay)
      Observation(
        _rangeStart.add(Duration(days: i)),
        base + amplitude * math.sin(i / 4.0) + (i % 5) * (amplitude / 6),
      ),
  ];
}

List<Override> _overrides() {
  AggregationType aggOf(String id) =>
      id == _measureBarId ? AggregationType.dailySum : AggregationType.none;

  return [
    // Measurement (bar, aggregated).
    measurableDataTypeControllerProvider(_measureBarId).overrideWithBuild(
      (ref, notifier) => _dataType(
        id: _measureBarId,
        displayName: 'Water',
        description: 'Daily water intake',
        unitName: 'ml',
        aggregationType: AggregationType.dailySum,
      ),
    ),
    aggregationTypeControllerProvider((
      measurableDataTypeId: _measureBarId,
      dashboardDefinedAggregationType: null,
    )).overrideWithBuild((ref, notifier) => AggregationType.dailySum),
    measurableObservationsControllerProvider((
      measurableDataTypeId: _measureBarId,
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
      dashboardDefinedAggregationType: aggOf(_measureBarId),
    )).overrideWithBuild((ref, notifier) => _series(1500, 600)),

    // Measurement (line, raw values).
    measurableDataTypeControllerProvider(_measureLineId).overrideWithBuild(
      (ref, notifier) => _dataType(
        id: _measureLineId,
        displayName: 'Mood',
        description: 'Self-reported mood, 1–10',
        unitName: '',
        aggregationType: AggregationType.none,
      ),
    ),
    aggregationTypeControllerProvider((
      measurableDataTypeId: _measureLineId,
      dashboardDefinedAggregationType: null,
    )).overrideWithBuild((ref, notifier) => AggregationType.none),
    measurableObservationsControllerProvider((
      measurableDataTypeId: _measureLineId,
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
      dashboardDefinedAggregationType: AggregationType.none,
    )).overrideWithBuild((ref, notifier) => _series(6, 2)),

    // Workout.
    workoutObservationsControllerProvider(
      chartConfig: _workoutConfig,
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
    ).overrideWithBuild((ref, notifier) => _series(350, 150)),

    // Health line (resting heart rate).
    healthObservationsControllerProvider(
      healthDataType: 'HealthDataType.RESTING_HEART_RATE',
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
    ).overrideWithBuild((ref, notifier) => _series(58, 6)),

    // Health bar (steps).
    healthObservationsControllerProvider(
      healthDataType: 'cumulative_step_count',
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
    ).overrideWithBuild((ref, notifier) => _series(9000, 3500)),

    // Blood pressure (systolic + diastolic).
    healthObservationsControllerProvider(
      healthDataType: 'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
    ).overrideWithBuild((ref, notifier) => _series(120, 8, everyNthDay: 3)),
    healthObservationsControllerProvider(
      healthDataType: 'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
    ).overrideWithBuild((ref, notifier) => _series(78, 6, everyNthDay: 3)),

    // BMI / weight.
    healthObservationsControllerProvider(
      healthDataType: 'HealthDataType.WEIGHT',
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
    ).overrideWithBuild((ref, notifier) => _series(74, 2)),
  ];
}

Widget _cards() {
  final cards = <Widget>[
    MeasurablesBarChart(
      measurableDataTypeId: _measureBarId,
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
      enableCreate: true,
    ),
    MeasurablesBarChart(
      measurableDataTypeId: _measureLineId,
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
      enableCreate: true,
    ),
    DashboardWorkoutChart(
      chartConfig: _workoutConfig,
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
    ),
    DashboardHealthChart(
      chartConfig: _hrConfig,
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
    ),
    DashboardHealthChart(
      chartConfig: _stepsConfig,
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
    ),
    DashboardHealthChart(
      chartConfig: _bpConfig,
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
    ),
    DashboardHealthChart(
      chartConfig: _bmiConfig,
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
    ),
  ];

  return Builder(
    builder: (context) {
      final tokens = context.designTokens;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final card in cards) ...[
            card,
            SizedBox(height: tokens.spacing.cardItemSpacing),
          ],
        ],
      );
    },
  );
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary =
      tester.element(find.byKey(_boundaryKey)).findRenderObject()!
          as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir =
        Platform.environment['LOTTI_SCREENSHOT_DIR'] ??
        p.join('screenshots', 'dashboards');
    final file = File(p.join(dir, '$name.png'));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      byteData!.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
      flush: true,
    );
    stdout.writeln('wrote screenshot: ${file.path}');
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Brightness brightness,
  double contentWidth = 760,
  Size viewport = _desktopSize,
}) async {
  tester.view
    ..physicalSize = viewport * 2
    ..devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundaryKey,
      child: ProviderScope(
        overrides: _overrides(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.dark
              ? DesignSystemTheme.dark()
              : DesignSystemTheme.light(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              // Match the real dashboard detail page's app-standard near-black
              // (level01) page surface so the level02 cards pop the same way
              // they do in production.
              backgroundColor: context.designTokens.colors.background.level01,
              body: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  // Vertical breathing room only; the horizontal inset comes
                  // from the centered, width-capped content column, mirroring
                  // the real page's SettingsContentArea max-width centering.
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: SizedBox(width: contentWidth, child: _cards()),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  // fl_chart animates data swaps (~150ms); settle so captures are not mid-lerp.
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  final captureEnabled =
      Platform.environment['LOTTI_CAPTURE_SCREENSHOTS'] == 'true' ||
      Platform.environment.containsKey('LOTTI_SCREENSHOT_DIR');
  if (!captureEnabled) {
    test(
      'screenshot harness (opt-in)',
      () {},
      skip:
          'Design-review screenshots are opt-in: run with '
          'LOTTI_SCREENSHOT_DIR=<dir> (or LOTTI_CAPTURE_SCREENSHOTS=true) '
          'because the real-font loading leaks process-wide.',
    );
    return;
  }

  setUpAll(loadScreenshotFonts);

  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        final healthImport = MockHealthImport();
        when(
          () => healthImport.fetchHealthDataDelta(any()),
        ).thenAnswer((_) async {});
        getIt.registerSingleton<HealthImport>(healthImport);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  testWidgets('dashboard charts — dark', (tester) async {
    await _pump(tester, brightness: Brightness.dark);
    expect(find.textContaining('Water'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsNWidgets(2));
    await _capture(tester, '01_dashboard_charts_dark');
  });

  testWidgets('dashboard charts — light', (tester) async {
    await _pump(tester, brightness: Brightness.light);
    expect(find.text('Mood'), findsOneWidget);
    await _capture(tester, '02_dashboard_charts_light');
  });

  testWidgets('dashboard charts — narrow desktop detail pane (dark)', (
    tester,
  ) async {
    // The add affordance must stay inside the card even when the chart is
    // rendered in a pane far narrower than the window — the desktop bug.
    await _pump(
      tester,
      brightness: Brightness.dark,
      contentWidth: 480,
    );
    expect(find.byIcon(Icons.add_rounded), findsNWidgets(2));
    await _capture(tester, '03_dashboard_charts_narrow_pane_dark');
  });
}
