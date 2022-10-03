import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/create/complete_habit_dialog.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();

  group('HabitDialog Widget Tests - ', () {
    setUpAll(() {
      registerFallbackValue(FakeHabitCompletionData());
    });

    setUp(() {
      mockJournalDb = mockJournalDbWithHabits([
        habitFlossing,
      ]);
      mockPersistenceLogic = MockPersistenceLogic();

      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      when(() => mockJournalDb.watchConfigFlag(enableBeamerNavFlag)).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );
    });
    tearDown(getIt.reset);

    testWidgets('Habit completion can be recorded', (tester) async {
      final delegate = BeamerDelegate(
        locationBuilder: RoutesLocationBuilder(
          routes: {
            '/': (context, state, data) => Container(),
          },
        ),
      );

      Future<HabitCompletionEntry?> mockCompleteHabitEntry() {
        return mockPersistenceLogic.createHabitCompletionEntry(
          data: any(named: 'data'),
          comment: any(named: 'comment'),
          private: false,
        );
      }

      when(mockCompleteHabitEntry).thenAnswer((_) async => null);

      await tester.pumpWidget(
        makeTestableWidget(
          BeamerProvider(
            routerDelegate: delegate,
            child: Material(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 800,
                  maxWidth: 800,
                ),
                child: HabitDialog(
                  habitId: habitFlossing.id,
                  beamerDelegate: delegate,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(habitFlossing.name), findsOneWidget);

      final commentFieldFinder = find.byKey(const Key('habit_comment_field'));
      final saveButtonFinder = find.byKey(const Key('habit_save'));

      expect(commentFieldFinder, findsOneWidget);
      expect(saveButtonFinder, findsOneWidget);

      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();
    });
  });
}
