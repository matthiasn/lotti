import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
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

    testWidgets('summary with workout chart for running distance is rendered',
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
          WorkoutSummary(testWorkoutRunning),
        ),
      );

      await tester.pumpAndSettle();

      // charts display expected titles
      expect(find.text('Running (time)'), findsOneWidget);
      expect(find.text('Running (calories)'), findsOneWidget);
      expect(find.text('Running distance (m)'), findsOneWidget);
    });
  });
}
