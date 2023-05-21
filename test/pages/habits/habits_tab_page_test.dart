import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/habits/habits_cubit.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/habits/habits_page.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/themes/themes_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../test_data/test_data.dart';
import '../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  final mockEntitiesCacheService = MockEntitiesCacheService();

  group('HabitsTabPage Widget Tests - ', () {
    setUp(() {
      mockJournalDb = mockJournalDbWithHabits([
        habitFlossing,
        habitFlossingDueLater,
      ]);

      when(mockJournalDb.watchCategories).thenAnswer(
        (_) => Stream<List<CategoryDefinition>>.fromIterable([
          [categoryMindfulness]
        ]),
      );

      when(
        () => mockEntitiesCacheService.getHabitById(
          habitFlossing.id,
        ),
      ).thenAnswer((_) => habitFlossing);

      getIt
        ..registerSingleton<ThemesService>(ThemesService(watch: false))
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
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
        ),
      ).thenAnswer(
        (_) => Stream<List<JournalEntity>>.fromIterable([
          [testHabitCompletionEntry]
        ]),
      );
    });
    tearDown(getIt.reset);

    testWidgets('habits page is rendered', (tester) async {
      final cubit = HabitsCubit()..setDisplayFilter(HabitDisplayFilter.all);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          BlocProvider<HabitsCubit>(
            lazy: false,
            create: (_) => cubit,
            child: const HabitsTabPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text(habitFlossing.name),
        findsOneWidget,
      );

      final searchButtonFinder = find.byIcon(Icons.search);
      expect(searchButtonFinder, findsOneWidget);

      await tester.tap(searchButtonFinder);
      await tester.pumpAndSettle();

      final timeSpanButtonFinder = find.byIcon(Icons.calendar_month);
      expect(timeSpanButtonFinder, findsOneWidget);

      await tester.tap(timeSpanButtonFinder);
      await tester.pumpAndSettle();

      final habitCategoryFilterFinder =
          find.byKey(const Key('habit_category_filter'));
      expect(habitCategoryFilterFinder, findsOneWidget);

      await tester.tap(habitCategoryFilterFinder);
      await tester.pumpAndSettle();
    });
  });
}
