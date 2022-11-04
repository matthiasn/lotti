import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/settings/habits/habit_create_page.dart';
import 'package:lotti/pages/settings/habits/habit_details_page.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();

  group('HabitDetailsPage Widget Tests - ', () {
    setUpAll(() {
      registerFallbackValue(FakeDashboardDefinition());
    });

    setUp(() {
      mockJournalDb = mockJournalDbWithHabits([habitFlossing]);
      mockPersistenceLogic = MockPersistenceLogic();

      when(() => mockJournalDb.watchConfigFlag(enableBeamerNavFlag)).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<ThemesService>(ThemesService(watch: false));
    });
    tearDown(getIt.reset);

    testWidgets('habit details page is displayed & updated', (tester) async {
      when(
        () => mockPersistenceLogic.upsertEntityDefinition(any()),
      ).thenAnswer((_) async => 1);

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: HabitDetailsPage(habitDefinition: habitFlossing),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final nameFieldFinder = find.byKey(const Key('habit_name_field'));
      final descriptionFieldFinder =
          find.byKey(const Key('habit_description_field'));
      final saveButtonFinder = find.byKey(const Key('habit_save'));

      expect(nameFieldFinder, findsOneWidget);
      expect(descriptionFieldFinder, findsOneWidget);

      // save button is invisible - no changes yet
      expect(saveButtonFinder, findsNothing);

      await tester.enterText(
        nameFieldFinder,
        'new name',
      );
      await tester.enterText(
        descriptionFieldFinder,
        'new description',
      );
      await tester.pumpAndSettle();

      // save button is now visible
      expect(saveButtonFinder, findsOneWidget);

      await tester.tap(saveButtonFinder);
    });

    testWidgets('habit details page is displayed & deleted', (tester) async {
      Future<int> mockUpsertEntity() {
        return mockPersistenceLogic.upsertEntityDefinition(any());
      }

      when(mockUpsertEntity).thenAnswer((_) async => 1);

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: HabitDetailsPage(habitDefinition: habitFlossing),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final trashIconFinder = find.byIcon(MdiIcons.trashCanOutline);
      await tester.tap(trashIconFinder);
      await tester.pumpAndSettle();

      final deleteQuestionFinder =
          find.text('Do you want to delete this habit?');
      final confirmDeleteFinder = find.text('YES, DELETE THIS HABIT');
      expect(deleteQuestionFinder, findsOneWidget);
      expect(confirmDeleteFinder, findsOneWidget);

      await tester.tap(confirmDeleteFinder);
      await tester.pumpAndSettle();

      // delete button calls mocked function
      verify(mockUpsertEntity).called(1);
    });

    testWidgets('habit details page is displayed & updated', (tester) async {
      when(
        () => mockPersistenceLogic.upsertEntityDefinition(any()),
      ).thenAnswer((_) async => 1);

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: CreateHabitPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final nameFieldFinder = find.byKey(const Key('habit_name_field'));
      final descriptionFieldFinder =
          find.byKey(const Key('habit_description_field'));
      final saveButtonFinder = find.byKey(const Key('habit_save'));

      expect(nameFieldFinder, findsOneWidget);
      expect(descriptionFieldFinder, findsOneWidget);

      // save button is invisible - no changes yet
      expect(saveButtonFinder, findsNothing);

      await tester.enterText(
        nameFieldFinder,
        'new name',
      );
      await tester.enterText(
        descriptionFieldFinder,
        'new description',
      );
      await tester.pumpAndSettle();

      // save button is now visible
      expect(saveButtonFinder, findsOneWidget);

      await tester.tap(saveButtonFinder);
    });

    testWidgets('habit details page is displayed & date updated',
        (tester) async {
      when(
        () => mockPersistenceLogic.upsertEntityDefinition(any()),
      ).thenAnswer((_) async => 1);

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: CreateHabitPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final activeFromFieldFinder = find.byKey(const Key('habit_active'));

      final saveButtonFinder = find.byKey(const Key('habit_save'));

      expect(activeFromFieldFinder, findsOneWidget);

      // save button is invisible - no changes yet
      expect(saveButtonFinder, findsNothing);

      await tester.tap(activeFromFieldFinder);

      await tester.pumpAndSettle();
    });

    testWidgets('habit edit page is displayed', (tester) async {
      when(
        () => mockPersistenceLogic.upsertEntityDefinition(any()),
      ).thenAnswer((_) async => 1);

      await tester.pumpWidget(
        makeTestableWidget(
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 1000,
              maxWidth: 1000,
            ),
            child: EditHabitPage(
              habitId: habitFlossing.id,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final nameFieldFinder = find.byKey(const Key('habit_name_field'));
      final descriptionFieldFinder =
          find.byKey(const Key('habit_description_field'));
      final saveButtonFinder = find.byKey(const Key('habit_save'));

      expect(nameFieldFinder, findsOneWidget);
      expect(descriptionFieldFinder, findsOneWidget);

      // save button is invisible - no changes yet
      expect(saveButtonFinder, findsNothing);

      await tester.enterText(
        nameFieldFinder,
        'new name',
      );
      await tester.enterText(
        descriptionFieldFinder,
        'new description',
      );
      await tester.pumpAndSettle();

      // save button is now visible
      expect(saveButtonFinder, findsOneWidget);

      await tester.tap(saveButtonFinder);
    });
  });
}
