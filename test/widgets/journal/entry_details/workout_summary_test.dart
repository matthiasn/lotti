import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/widgets/journal/entry_details/workout_summary.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  final mockHealthImport = MockHealthImport();

  group('WorkoutSummary Widget Tests - ', () {
    setUp(() {
      mockJournalDb = MockJournalDb();

      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<HealthImport>(mockHealthImport);
    });
    tearDown(getIt.reset);

    testWidgets('summary with workout chart for running distance is rendered',
        (tester) async {
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
          WorkoutSummary(testWorkoutRunning),
        ),
      );

      await tester.pumpAndSettle();

      // charts display expected titles
      expect(find.text('Running time'), findsOneWidget);
      expect(find.text('Running calories'), findsOneWidget);
      expect(find.text('Running distance/m'), findsOneWidget);
    });
  });
}
