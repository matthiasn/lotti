import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_workout_chart.dart';
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

    testWidgets('workout chart for running distance is rendered',
        (tester) async {
      when(
        () => mockJournalDb.watchWorkouts(
          rangeEnd: any(named: 'rangeEnd'),
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([
          [testWorkoutRunning],
        ]),
      );

      when(mockHealthImport.getWorkoutsHealthDataDelta)
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DashboardWorkoutChart(
            rangeStart: DateTime(2022),
            rangeEnd: DateTime(2023),
            chartConfig: DashboardWorkoutItem(
              valueType: WorkoutValueType.distance,
              color: '#00FF00',
              displayName: 'Running distance',
              workoutType: testWorkoutRunning.data.workoutType,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // chart displays expected title
      expect(
        find.text('Running distance'),
        findsOneWidget,
      );
    });

    testWidgets('workout chart for running energy is rendered', (tester) async {
      when(
        () => mockJournalDb.watchWorkouts(
          rangeEnd: any(named: 'rangeEnd'),
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([
          [testWorkoutRunning],
        ]),
      );

      when(mockHealthImport.getWorkoutsHealthDataDelta)
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DashboardWorkoutChart(
            rangeStart: DateTime(2022),
            rangeEnd: DateTime(2023),
            chartConfig: DashboardWorkoutItem(
              valueType: WorkoutValueType.energy,
              color: '#00FF00',
              displayName: 'Running calories',
              workoutType: testWorkoutRunning.data.workoutType,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // chart displays expected title
      expect(
        find.text('Running calories'),
        findsOneWidget,
      );
    });

    testWidgets('workout chart for running duration is rendered',
        (tester) async {
      when(
        () => mockJournalDb.watchWorkouts(
          rangeEnd: any(named: 'rangeEnd'),
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([
          [testWorkoutRunning],
        ]),
      );

      when(mockHealthImport.getWorkoutsHealthDataDelta)
          .thenAnswer((_) async {});

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          DashboardWorkoutChart(
            rangeStart: DateTime(2022),
            rangeEnd: DateTime(2023),
            chartConfig: DashboardWorkoutItem(
              valueType: WorkoutValueType.duration,
              color: '#00FF00',
              displayName: 'Running Duration',
              workoutType: testWorkoutRunning.data.workoutType,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // chart displays expected title
      expect(
        find.text('Running Duration'),
        findsOneWidget,
      );
    });
  });
}
