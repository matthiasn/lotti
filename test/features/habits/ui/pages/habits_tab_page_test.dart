import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/ui/habits_page.dart';
import 'package:lotti/features/habits/ui/widgets/habit_completion_card.dart';
import 'package:lotti/features/habits/ui/widgets/habits_section_header.dart';
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

    /// Pumps the [HabitsTabPage] with a [FakeHabitsController] serving [state]
    /// and lets the page's async card providers settle. Returns the fake so
    /// individual tests can assert on the mutation calls it records.
    Future<FakeHabitsController> pump(
      WidgetTester tester,
      HabitsState state,
    ) async {
      final controller = FakeHabitsController(state);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            habitsControllerProvider.overrideWith(() => controller),
          ],
          child: makeTestableWidgetWithScaffold(
            const HabitsTabPage(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      return controller;
    }

    testWidgets('habits page is rendered', (tester) async {
      final testState = HabitsState.initial().copyWith(
        habitDefinitions: [habitFlossing, habitFlossingDueLater],
        openNow: [habitFlossing],
        pendingLater: [habitFlossingDueLater],
        displayFilter: HabitDisplayFilter.all,
      );

      final controller = await pump(tester, testState);

      expect(
        find.text(habitFlossing.name),
        findsOneWidget,
      );

      // The header carries the search tool button and the category filter; the
      // old calendar/time-span button moved into the chart card and is gone.
      final searchButtonFinder = find.byIcon(Icons.search);
      expect(searchButtonFinder, findsOneWidget);
      expect(find.byIcon(Icons.calendar_month), findsNothing);

      // Tapping search toggles the in-page search affordance via the controller.
      await tester.tap(searchButtonFinder);
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.toggleShowSearchCalls, 1);

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

        await pump(tester, testState);

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

        await pump(tester, testState);

        // Should have exactly 1 HabitCompletionCard for completed habit
        expect(find.byType(HabitCompletionCard), findsOneWidget);
        expect(find.byKey(Key(habitFlossing.id)), findsOneWidget);
      },
    );

    testWidgets(
      'renders the Completed section header under the all filter',
      (tester) async {
        // The "all" filter renders a grouping header for every non-empty
        // bucket. With only the completed bucket populated, the page must build
        // the Completed section header and the card beneath it.
        final testState = HabitsState.initial().copyWith(
          habitDefinitions: [habitFlossing],
          openNow: [],
          pendingLater: [],
          completed: [habitFlossing],
          displayFilter: HabitDisplayFilter.all,
        );

        await pump(tester, testState);

        // The localized habitsCompletedHeader == 'Completed'.
        expect(find.text('Completed'), findsOneWidget);
        expect(find.byType(HabitCompletionCard), findsOneWidget);
        expect(find.byKey(Key(habitFlossing.id)), findsOneWidget);
      },
    );

    testWidgets(
      'centres content within a max width on wide windows',
      (tester) async {
        // A window wider than 720 + step6*2 (768) takes the responsive
        // horizontal-padding branch that centres the reading column instead of
        // letting rows stretch edge-to-edge. 800 clears the threshold while
        // still fitting the harness's 800px ConstrainedBox (no overflow).
        final testState = HabitsState.initial().copyWith(
          habitDefinitions: [habitFlossing],
          openNow: [habitFlossing],
          displayFilter: HabitDisplayFilter.all,
        );

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const HabitsTabPage(),
            overrides: [
              habitsControllerProvider.overrideWith(
                () => FakeHabitsController(testState),
              ),
            ],
            mediaQueryData: const MediaQueryData(size: Size(800, 800)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // The wide-screen padding branch lays out without overflowing and still
        // renders the habit row.
        expect(find.text(habitFlossing.name), findsOneWidget);
        expect(tester.takeException(), isNull);
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

        await pump(tester, testState);

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

      await pump(tester, testState);

      // No HabitCompletionCards when all lists are empty
      expect(find.byType(HabitCompletionCard), findsNothing);
    });

    testWidgets(
      'chart card renders the time-span selector',
      (tester) async {
        // The time-span selector now lives in HabitsChartCard at the bottom of
        // the page and is always rendered, independent of any showTimeSpan flag.
        final testState = HabitsState.initial().copyWith(
          habitDefinitions: [habitFlossing],
          openNow: [habitFlossing],
          displayFilter: HabitDisplayFilter.openNow,
        );

        await pump(tester, testState);

        expect(find.byType(TimeSpanSegmentedControl), findsOneWidget);
      },
    );

    testWidgets(
      'summary card surfaces the remaining "to go" count from state',
      (tester) async {
        // total = habitDefinitions.length (2), done = completedToday.length (1),
        // so the gain-framed caption should read "1 to go".
        final testState = HabitsState.initial().copyWith(
          habitDefinitions: [habitFlossing, habitFlossingDueLater],
          completedToday: {habitFlossing.id},
          openNow: [habitFlossingDueLater],
          displayFilter: HabitDisplayFilter.openNow,
        );

        await pump(tester, testState);

        expect(find.text('1 to go'), findsOneWidget);
      },
    );

    testWidgets(
      'summary card shows "All done today" once every habit is completed',
      (tester) async {
        // done == total, so remaining is 0 and the caption flips to the
        // all-done message instead of a "to go" count.
        final testState = HabitsState.initial().copyWith(
          habitDefinitions: [habitFlossing, habitFlossingDueLater],
          completedToday: {habitFlossing.id, habitFlossingDueLater.id},
          completed: [habitFlossing, habitFlossingDueLater],
          displayFilter: HabitDisplayFilter.completed,
        );

        await pump(tester, testState);

        expect(find.text('All done today'), findsOneWidget);
        expect(find.textContaining('to go'), findsNothing);
      },
    );

    testWidgets(
      'renders section headers with per-bucket counts when filter is all',
      (tester) async {
        // With the "all" filter every non-empty bucket gets a section header
        // whose count equals that bucket's length.
        final testState = HabitsState.initial().copyWith(
          habitDefinitions: [habitFlossing, habitFlossingDueLater],
          openNow: [habitFlossing],
          pendingLater: [habitFlossingDueLater],
          completed: [],
          displayFilter: HabitDisplayFilter.all,
        );

        await pump(tester, testState);

        // Only the two non-empty buckets render headers (completed is empty).
        expect(find.byType(HabitsSectionHeader), findsNWidgets(2));
        // "Due now" / "Later today" labels with a count of 1 each.
        expect(find.text('Due now'), findsOneWidget);
        expect(find.text('Later today'), findsOneWidget);
        expect(find.text('Completed'), findsNothing);
        // Each non-empty bucket holds a single habit, so the count pills read 1.
        expect(find.text('1'), findsNWidgets(2));
        expect(find.byKey(Key(habitFlossing.id)), findsOneWidget);
        expect(find.byKey(Key(habitFlossingDueLater.id)), findsOneWidget);
      },
    );

    testWidgets(
      'does not render section headers when a single-status filter is active',
      (tester) async {
        // Section headers are gated on the "all" filter; a focused filter shows
        // the bucket's cards without the grouping header.
        final testState = HabitsState.initial().copyWith(
          habitDefinitions: [habitFlossing, habitFlossingDueLater],
          openNow: [habitFlossing],
          pendingLater: [habitFlossingDueLater],
          displayFilter: HabitDisplayFilter.openNow,
        );

        await pump(tester, testState);

        expect(find.byType(HabitsSectionHeader), findsNothing);
        expect(find.byType(HabitCompletionCard), findsOneWidget);
        expect(find.byKey(Key(habitFlossing.id)), findsOneWidget);
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

        await pump(tester, testState);

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

        await pump(tester, testState);

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

        await pump(tester, testState);

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

        await pump(tester, testState);

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

        await pump(tester, testState);

        expect(find.byKey(Key(habitFlossing.id)), findsNothing);
        expect(find.byKey(Key(habitFlossingDueLater.id)), findsNothing);
        expect(find.byType(HabitCompletionCard), findsNothing);
      },
    );
  });
}
