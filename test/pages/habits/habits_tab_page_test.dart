import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/habits/habits_page.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();

  group('HabitsTabPage Widget Tests - ', () {
    setUp(() {
      mockJournalDb = mockJournalDbWithHabits([
        habitFlossing,
        habitFlossingDueLater,
      ]);

      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<JournalDb>(mockJournalDb);

      when(
        () => mockJournalDb.watchHabitCompletionsByHabitId(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          habitId: habitFlossing.id,
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([
          [testHabitCompletionEntry]
        ]),
      );

      when(
        () => mockJournalDb.watchHabitCompletionsByHabitId(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          habitId: habitFlossingDueLater.id,
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([[]]),
      );

      when(
        () => mockJournalDb.watchHabitCompletionsInRange(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([[]]),
      );
    });
    tearDown(getIt.reset);

    testWidgets('habits page is rendered', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const HabitsTabPage(),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text(habitFlossing.name),
        findsOneWidget,
      );
    });
  });
}
