import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_workout_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_chart.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  final mockHealthImport = MockHealthImport();

  group('DashboardWorkoutChart Widget Tests - ', () {
    setUp(() {
      mockJournalDb = MockJournalDb();

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<HealthImport>(mockHealthImport);
    });
    tearDown(getIt.reset);

    for (final testCase in [
      (WorkoutValueType.distance, 'Running distance'),
      (WorkoutValueType.energy, 'Running calories'),
      (WorkoutValueType.duration, 'Running Duration'),
    ]) {
      testWidgets(
          'renders chart with title and bar chart for ${testCase.$1.name}',
          (tester) async {
        when(
          () => mockJournalDb.getWorkouts(
            rangeEnd: any(named: 'rangeEnd'),
            rangeStart: any(named: 'rangeStart'),
          ),
        ).thenAnswer((_) async => [testWorkoutRunning]);

        when(mockHealthImport.getWorkoutsHealthDataDelta)
            .thenAnswer((_) async {});

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            DashboardWorkoutChart(
              rangeStart: DateTime(2022),
              rangeEnd: DateTime(2023),
              chartConfig: DashboardWorkoutItem(
                valueType: testCase.$1,
                color: '#00FF00',
                displayName: testCase.$2,
                workoutType: testWorkoutRunning.data.workoutType,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text(testCase.$2), findsOneWidget);
        expect(find.byType(TimeSeriesBarChart), findsOneWidget);
        expect(find.byType(WorkoutChartInfoWidget), findsOneWidget);
      });
    }
  });
}
