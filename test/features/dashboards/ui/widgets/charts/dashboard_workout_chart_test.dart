import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/workout_chart_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_workout_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';

import '../../../../../helpers/fallbacks.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  const chartConfig =
      DashboardItem.workoutChart(
            workoutType: 'running',
            displayName: 'Running calories',
            color: '#0000FF',
            valueType: WorkoutValueType.energy,
          )
          as DashboardWorkoutItem;

  final rangeStart = DateTime(2024, 3);
  final rangeEnd = DateTime(2024, 3, 31);

  Future<void> pumpChart(
    WidgetTester tester, {
    required List<Observation> observations,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        DashboardWorkoutChart(
          chartConfig: chartConfig,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
        overrides: [
          workoutObservationsControllerProvider(
            chartConfig: chartConfig,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ).overrideWithBuild((ref, notifier) => observations),
        ],
      ),
    );
    await tester.pump();
  }

  group('DashboardWorkoutChart', () {
    testWidgets('renders a bar chart with the configured display name', (
      tester,
    ) async {
      await pumpChart(
        tester,
        observations: [
          Observation(rangeStart.add(const Duration(days: 1)), 320),
          Observation(rangeStart.add(const Duration(days: 2)), 450),
        ],
      );

      expect(find.byType(DashboardChart), findsOneWidget);
      final chart = tester.widget<TimeSeriesBarChart>(
        find.byType(TimeSeriesBarChart),
      );
      expect(chart.data, hasLength(2));
      expect(chart.unit, 'Running calories');
      expect(find.text('Running calories'), findsOneWidget);
    });

    testWidgets('renders an empty bar chart when there are no observations', (
      tester,
    ) async {
      await pumpChart(tester, observations: const []);

      expect(find.byType(TimeSeriesBarChart), findsOneWidget);
      expect(find.text('Running calories'), findsOneWidget);
    });
  });

  group('WorkoutChartInfoWidget', () {
    testWidgets('shows the configured display name', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const SizedBox(
            width: 1000,
            height: 600,
            child: Stack(
              children: [WorkoutChartInfoWidget(chartConfig)],
            ),
          ),
        ),
      );

      expect(find.text('Running calories'), findsOneWidget);
    });
  });
}
