import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_workout_chart.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/workout_summary.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  final mockHealthImport = MockHealthImport();

  group('WorkoutSummary Widget Tests - ', () {
    setUp(() {
      mockJournalDb = MockJournalDb();

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<HealthImport>(mockHealthImport);
    });
    tearDown(getIt.reset);

    testWidgets('summary with workout chart for running distance is rendered', (
      tester,
    ) async {
      when(
        () => mockJournalDb.getWorkouts(
          rangeEnd: any(named: 'rangeEnd'),
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer((_) async => [testWorkoutRunning]);

      when(
        mockHealthImport.getWorkoutsHealthDataDelta,
      ).thenAnswer((_) async => const HealthImportResult.imported(0));

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          WorkoutSummary(testWorkoutRunning),
        ),
      );

      await tester.pumpAndSettle();

      // charts display expected titles
      expect(find.text('Running (time)'), findsOneWidget);
      expect(find.text('Running (calories)'), findsOneWidget);
      expect(find.text('Running distance (m)'), findsOneWidget);
    });

    Future<void> pumpSummaryFor(WidgetTester tester, String workoutType) async {
      when(
        () => mockJournalDb.getWorkouts(
          rangeEnd: any(named: 'rangeEnd'),
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer((_) async => [testWorkoutRunning]);
      when(
        mockHealthImport.getWorkoutsHealthDataDelta,
      ).thenAnswer((_) async => const HealthImportResult.imported(0));

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          WorkoutSummary(
            testWorkoutRunning.copyWith(
              data: testWorkoutRunning.data.copyWith(workoutType: workoutType),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // A row imported by the upstream plugin says `RUNNING`; the catalogue that
    // provides the trend charts says `running`. The detail card used to show
    // no charts at all for such a row.
    testWidgets('finds the charts for a workout in the plugin spelling', (
      tester,
    ) async {
      await pumpSummaryFor(tester, 'RUNNING');

      expect(find.byType(DashboardWorkoutChart), findsNWidgets(3));
      expect(find.text('Running (time)'), findsOneWidget);
    });

    testWidgets('does not pick a catalogue series by key substring', (
      tester,
    ) async {
      // `walk` is a prefix of every `walking.*` key; it is not a walking row.
      await pumpSummaryFor(tester, 'walk');

      expect(find.byType(DashboardWorkoutChart), findsNothing);
      expect(find.textContaining('Duration: 60 min'), findsOneWidget);
    });

    testWidgets('renders no charts for an activity outside the catalogue', (
      tester,
    ) async {
      await pumpSummaryFor(tester, 'yoga');

      expect(find.byType(DashboardWorkoutChart), findsNothing);
    });
  });
}
