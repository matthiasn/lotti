import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/settings/habits/habit_settings_cubit.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/settings/habits/habit_create_page.dart';
import 'package:lotti/pages/settings/habits/habit_details_page.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  // ignore: deprecated_member_use
  binding.window.physicalSizeTestValue = const Size(1000, 1000);
  // ignore: deprecated_member_use
  binding.window.devicePixelRatioTestValue = 1.0;

  var mockJournalDb = MockJournalDb();
  var mockPersistenceLogic = MockPersistenceLogic();

  group('HabitDetailsPage Widget Tests - ', () {
    setUpAll(() {
      registerFallbackValue(FakeDashboardDefinition());
    });

    setUp(() {
      mockJournalDb = mockJournalDbWithHabits([habitFlossing]);

      when(mockJournalDb.watchCategories).thenAnswer(
        (_) => Stream<List<CategoryDefinition>>.fromIterable([
          [categoryMindfulness]
        ]),
      );

      when(mockJournalDb.watchDashboards).thenAnswer(
        (_) => Stream<List<DashboardDefinition>>.fromIterable([
          [testDashboardConfig]
        ]),
      );

      mockPersistenceLogic = MockPersistenceLogic();

      final mockTagsService = mockTagsServiceWithTags([]);

      when(mockTagsService.watchTags).thenAnswer(
        (_) => Stream<List<TagEntity>>.fromIterable([
          [
            testStoryTag1,
            testPersonTag1,
            testTag1,
          ]
        ]),
      );

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<TagsService>(mockTagsService)
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
            child: BlocProvider(
              create: (_) => HabitSettingsCubit(habitFlossing),
              child: const HabitDetailsPage(),
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
            child: BlocProvider(
              create: (_) => HabitSettingsCubit(habitFlossing),
              child: const HabitDetailsPage(),
            ),
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

      final activeFromFieldFinder = find.byKey(const Key('habit_archived'));

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
