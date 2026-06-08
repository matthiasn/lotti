import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/ui/habits_page.dart';
import 'package:lotti/features/habits/ui/widgets/habit_completion_card.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  final mockEntitiesCacheService = MockEntitiesCacheService();
  final mockUpdateNotifications = MockUpdateNotifications();

  group('HabitsTabPage Widget Tests - ', () {
    setUp(() {
      mockJournalDb = mockJournalDbWithHabits([
        habitFlossing,
        habitFlossingDueLater,
      ]);

      when(
        () => mockEntitiesCacheService.getHabitById(
          habitFlossing.id,
        ),
      ).thenAnswer((_) => habitFlossing);

      getIt
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<UserActivityService>(UserActivityService())
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<JournalDb>(mockJournalDb);

      when(() => mockEntitiesCacheService.sortedCategories).thenAnswer(
        (_) => [categoryMindfulness],
      );

      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      when(
        () => mockJournalDb.getHabitCompletionsByHabitId(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          habitId: habitFlossing.id,
        ),
      ).thenAnswer((_) async => [testHabitCompletionEntry]);

      when(
        () => mockJournalDb.getHabitCompletionsByHabitId(
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
          habitId: habitFlossingDueLater.id,
        ),
      ).thenAnswer((_) async => []);

      when(
        () => mockJournalDb.getHabitCompletionsInRange(
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer((_) async => [testHabitCompletionEntry]);
    });

    tearDown(getIt.reset);

    testWidgets('habits page is rendered', (tester) async {
      final testState = HabitsState.initial().copyWith(
        habitDefinitions: [habitFlossing, habitFlossingDueLater],
        openNow: [habitFlossing],
        pendingLater: [habitFlossingDueLater],
        displayFilter: HabitDisplayFilter.all,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            habitsControllerProvider.overrideWith(
              () => FakeHabitsController(testState),
            ),
          ],
          child: makeTestableWidgetWithScaffold(
            const HabitsTabPage(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text(habitFlossing.name),
        findsOneWidget,
      );

      final searchButtonFinder = find.byIcon(Icons.search);
      expect(searchButtonFinder, findsOneWidget);

      await tester.tap(searchButtonFinder);
      await tester.pump(const Duration(milliseconds: 100));

      final timeSpanButtonFinder = find.byIcon(Icons.calendar_month);
      expect(timeSpanButtonFinder, findsOneWidget);

      await tester.tap(timeSpanButtonFinder);
      await tester.pump(const Duration(milliseconds: 100));

      final habitCategoryFilterFinder = find.byKey(
        const Key('habit_category_filter'),
      );
      expect(habitCategoryFilterFinder, findsOneWidget);

      await tester.tap(habitCategoryFilterFinder);
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets(
      'renders HabitCompletionCard for openNow habits with openNow filter',
      (tester) async {
        final testState = HabitsState.initial().copyWith(
          habitDefinitions: [habitFlossing, habitFlossingDueLater],
          openNow: [habitFlossing],
          pendingLater: [habitFlossingDueLater],
          completed: [],
          displayFilter: HabitDisplayFilter.openNow,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              habitsControllerProvider.overrideWith(
                () => FakeHabitsController(testState),
              ),
            ],
            child: makeTestableWidgetWithScaffold(
              const HabitsTabPage(),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Should have exactly 1 HabitCompletionCard for openNow habit
        expect(find.byType(HabitCompletionCard), findsOneWidget);
        // Verify the correct habit card by key
        expect(find.byKey(Key(habitFlossing.id)), findsOneWidget);
      },
    );

    testWidgets(
      'renders HabitCompletionCard for completed habits with completed filter',
      (tester) async {
        final testState = HabitsState.initial().copyWith(
          habitDefinitions: [habitFlossing, habitFlossingDueLater],
          openNow: [],
          pendingLater: [],
          completed: [habitFlossing],
          displayFilter: HabitDisplayFilter.completed,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              habitsControllerProvider.overrideWith(
                () => FakeHabitsController(testState),
              ),
            ],
            child: makeTestableWidgetWithScaffold(
              const HabitsTabPage(),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Should have exactly 1 HabitCompletionCard for completed habit
        expect(find.byType(HabitCompletionCard), findsOneWidget);
        expect(find.byKey(Key(habitFlossing.id)), findsOneWidget);
      },
    );

    testWidgets(
      'renders HabitCompletionCard for pendingLater habits with pendingLater filter',
      (tester) async {
        final testState = HabitsState.initial().copyWith(
          habitDefinitions: [habitFlossing, habitFlossingDueLater],
          openNow: [],
          pendingLater: [habitFlossingDueLater],
          completed: [],
          displayFilter: HabitDisplayFilter.pendingLater,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              habitsControllerProvider.overrideWith(
                () => FakeHabitsController(testState),
              ),
            ],
            child: makeTestableWidgetWithScaffold(
              const HabitsTabPage(),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        // Should have exactly 1 HabitCompletionCard for pendingLater habit
        expect(find.byType(HabitCompletionCard), findsOneWidget);
        expect(find.byKey(Key(habitFlossingDueLater.id)), findsOneWidget);
      },
    );

    testWidgets('does not render cards for empty lists', (tester) async {
      final testState = HabitsState.initial().copyWith(
        habitDefinitions: [],
        openNow: [],
        pendingLater: [],
        completed: [],
        displayFilter: HabitDisplayFilter.all,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            habitsControllerProvider.overrideWith(
              () => FakeHabitsController(testState),
            ),
          ],
          child: makeTestableWidgetWithScaffold(
            const HabitsTabPage(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // No HabitCompletionCards when all lists are empty
      expect(find.byType(HabitCompletionCard), findsNothing);
    });

    testWidgets(
      'renders TimeSpanSegmentedControl when showTimeSpan is true',
      (tester) async {
        final testState = HabitsState.initial().copyWith(
          habitDefinitions: [habitFlossing],
          openNow: [habitFlossing],
          showTimeSpan: true,
          displayFilter: HabitDisplayFilter.openNow,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              habitsControllerProvider.overrideWith(
                () => FakeHabitsController(testState),
              ),
            ],
            child: makeTestableWidgetWithScaffold(
              const HabitsTabPage(),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(TimeSpanSegmentedControl), findsOneWidget);
      },
    );

    testWidgets(
      'searchString narrows the visible habit list when showSearch is true',
      (tester) async {
        // habitFlossing.name = "Flossing"
        // habitFlossingDueLater.name = "Flossing later today"
        // searchString 'later today' is a unique fragment of the second
        // habit's name, so the filter pass should drop habitFlossing.
        final testState = HabitsState.initial().copyWith(
          habitDefinitions: [habitFlossing, habitFlossingDueLater],
          openNow: [habitFlossing, habitFlossingDueLater],
          showSearch: true,
          searchString: 'later today',
          displayFilter: HabitDisplayFilter.openNow,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              habitsControllerProvider.overrideWith(
                () => FakeHabitsController(testState),
              ),
            ],
            child: makeTestableWidgetWithScaffold(
              const HabitsTabPage(),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(Key(habitFlossingDueLater.id)), findsOneWidget);
        expect(find.byKey(Key(habitFlossing.id)), findsNothing);
      },
    );

    testWidgets(
      'empty searchString keeps every habit visible when showSearch is true',
      (tester) async {
        // An empty fragment is contained in every name, so the filter pass
        // must be a no-op and both cards remain rendered.
        final testState = HabitsState.initial().copyWith(
          habitDefinitions: [habitFlossing, habitFlossingDueLater],
          openNow: [habitFlossing, habitFlossingDueLater],
          showSearch: true,
          displayFilter: HabitDisplayFilter.openNow,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              habitsControllerProvider.overrideWith(
                () => FakeHabitsController(testState),
              ),
            ],
            child: makeTestableWidgetWithScaffold(
              const HabitsTabPage(),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(Key(habitFlossing.id)), findsOneWidget);
        expect(find.byKey(Key(habitFlossingDueLater.id)), findsOneWidget);
      },
    );

    testWidgets(
      'lowercase searchString matches mixed-case habit names',
      (tester) async {
        // The controller stores searchString lowercased; the page lowercases
        // each name before comparing. 'flossing' must therefore match the
        // capitalised "Flossing" / "Flossing later today" names.
        final testState = HabitsState.initial().copyWith(
          habitDefinitions: [habitFlossing, habitFlossingDueLater],
          openNow: [habitFlossing, habitFlossingDueLater],
          showSearch: true,
          searchString: 'flossing',
          displayFilter: HabitDisplayFilter.openNow,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              habitsControllerProvider.overrideWith(
                () => FakeHabitsController(testState),
              ),
            ],
            child: makeTestableWidgetWithScaffold(
              const HabitsTabPage(),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(Key(habitFlossing.id)), findsOneWidget);
        expect(find.byKey(Key(habitFlossingDueLater.id)), findsOneWidget);
      },
    );

    testWidgets(
      'searchString matching the description keeps the habit visible',
      (tester) async {
        // The filter also scans description text. 'gums' only appears in the
        // shared description, not in either name, so both habits survive.
        final testState = HabitsState.initial().copyWith(
          habitDefinitions: [habitFlossing, habitFlossingDueLater],
          openNow: [habitFlossing, habitFlossingDueLater],
          showSearch: true,
          searchString: 'gums',
          displayFilter: HabitDisplayFilter.openNow,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              habitsControllerProvider.overrideWith(
                () => FakeHabitsController(testState),
              ),
            ],
            child: makeTestableWidgetWithScaffold(
              const HabitsTabPage(),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(Key(habitFlossing.id)), findsOneWidget);
        expect(find.byKey(Key(habitFlossingDueLater.id)), findsOneWidget);
      },
    );

    testWidgets(
      'non-matching searchString hides every habit and renders no cards',
      (tester) async {
        // 'zzz' is absent from both names and the shared description, so the
        // filter drops every habit and no HabitCompletionCard is built.
        final testState = HabitsState.initial().copyWith(
          habitDefinitions: [habitFlossing, habitFlossingDueLater],
          openNow: [habitFlossing, habitFlossingDueLater],
          showSearch: true,
          searchString: 'zzz',
          displayFilter: HabitDisplayFilter.openNow,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              habitsControllerProvider.overrideWith(
                () => FakeHabitsController(testState),
              ),
            ],
            child: makeTestableWidgetWithScaffold(
              const HabitsTabPage(),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byKey(Key(habitFlossing.id)), findsNothing);
        expect(find.byKey(Key(habitFlossingDueLater.id)), findsNothing);
        expect(find.byType(HabitCompletionCard), findsNothing);
      },
    );
  });
}
