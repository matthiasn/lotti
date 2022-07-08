import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/charts/dashboard_workout_chart.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';
import '../../test_data.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  final mockHealthImport = MockHealthImport();

  group('DashboardWorkoutChart Widget Tests - ', () {
    setUp(() {
      mockJournalDb = MockJournalDb();

      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<HealthImport>(mockHealthImport);
    });
    tearDown(getIt.reset);

    testWidgets('workout chart is rendered', (tester) async {
      when(
        () => mockJournalDb.watchWorkouts(
          rangeEnd: any(named: 'rangeEnd'),
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([
          [testWorkoutRunning]
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
              displayName: 'Running',
              workoutType: testWorkoutRunning.data.workoutType,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // chart displays expected title
      expect(
        find.text('Running'),
        findsOneWidget,
      );
    });
  });
}
