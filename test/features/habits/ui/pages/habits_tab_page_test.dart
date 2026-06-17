import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/state/heatmap/habit_heatmap_controller.dart';
import 'package:lotti/features/habits/state/heatmap/habit_heatmap_data.dart';
import 'package:lotti/features/habits/ui/habits_page.dart';
import 'package:lotti/features/habits/ui/widgets/habit_action_row.dart';
import 'package:lotti/features/habits/ui/widgets/habits_section_header.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/device_region.dart';
import 'package:lotti/widgets/misc/timespan_segmented_control.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

/// Serves a fixed [HabitHeatmapData] so the page's heatmap card renders without
/// the database-backed controller.
class _FakeHeatmapController extends HabitHeatmapController {
  @override
  HabitHeatmapData build() => HabitHeatmapData.empty();
}

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
        () => mockEntitiesCacheService.getHabitById(habitFlossing.id),
      ).thenAnswer((_) => habitFlossing);
      when(
        () => mockEntitiesCacheService.getHabitById(habitFlossingDueLater.id),
      ).thenAnswer((_) => habitFlossingDueLater);

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

    /// Pumps the [HabitsTabPage] with a [FakeHabitsController] serving [state],
    /// a fake heatmap controller and a fixed first day of week. Returns the fake
    /// habits controller so tests can assert on the mutation calls it records.
    Future<FakeHabitsController> pump(
      WidgetTester tester,
      HabitsState state, {
      MediaQueryData? mediaQueryData,
    }) async {
      final controller = FakeHabitsController(state);
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const HabitsTabPage(),
          mediaQueryData: mediaQueryData,
          overrides: [
            habitsControllerProvider.overrideWith(() => controller),
            habitHeatmapControllerProvider.overrideWith(
              _FakeHeatmapController.new,
            ),
            firstDayOfWeekIndexProvider.overrideWith((ref) => 1),
          ],
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

      expect(find.text(habitFlossing.name), findsOneWidget);

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

    testWidgets('renders an action row for openNow habits', (tester) async {
      final testState = HabitsState.initial().copyWith(
        habitDefinitions: [habitFlossing, habitFlossingDueLater],
        openNow: [habitFlossing],
        pendingLater: [habitFlossingDueLater],
        completed: [],
        displayFilter: HabitDisplayFilter.openNow,
      );

      await pump(tester, testState);

      expect(find.byType(HabitActionRow), findsOneWidget);
      expect(find.byKey(Key(habitFlossing.id)), findsOneWidget);
    });

    testWidgets('completing a habit lingers its row, then removes it', (
      tester,
    ) async {
      final controller = await pump(
        tester,
        HabitsState.initial().copyWith(
          habitDefinitions: [habitFlossing, habitFlossingDueLater],
          openNow: [habitFlossing],
          displayFilter: HabitDisplayFilter.openNow,
        ),
      );
      expect(find.byKey(Key(habitFlossing.id)), findsOneWidget);

      // Check it off: it leaves the openNow bucket — on the "due" filter it would
      // normally vanish instantly — but the page pins it through the linger so
      // its celebration can play.
      controller.emit(
        HabitsState.initial().copyWith(
          habitDefinitions: [habitFlossing, habitFlossingDueLater],
          openNow: const [],
          completed: [habitFlossing],
          completedToday: {habitFlossing.id},
          successfulToday: {habitFlossing.id},
          displayFilter: HabitDisplayFilter.openNow,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Still pinned mid-celebration.
      expect(find.byKey(Key(habitFlossing.id)), findsOneWidget);

      // After the linger window it leaves the due list.
      await tester.pump(const Duration(milliseconds: 1300));
      expect(find.byKey(Key(habitFlossing.id)), findsNothing);
    });

    testWidgets('renders an action row for completed habits', (tester) async {
      final testState = HabitsState.initial().copyWith(
        habitDefinitions: [habitFlossing, habitFlossingDueLater],
        openNow: [],
        pendingLater: [],
        completed: [habitFlossing],
        displayFilter: HabitDisplayFilter.completed,
      );

      await pump(tester, testState);

      expect(find.byType(HabitActionRow), findsOneWidget);
      expect(find.byKey(Key(habitFlossing.id)), findsOneWidget);
    });

    testWidgets('renders the Completed section header under the all filter', (
      tester,
    ) async {
      final testState = HabitsState.initial().copyWith(
        habitDefinitions: [habitFlossing],
        openNow: [],
        pendingLater: [],
        completed: [habitFlossing],
        displayFilter: HabitDisplayFilter.all,
      );

      await pump(tester, testState);

      expect(find.text('Completed'), findsOneWidget);
      expect(find.byType(HabitActionRow), findsOneWidget);
      expect(find.byKey(Key(habitFlossing.id)), findsOneWidget);
    });

    for (final width in [420.0, 800.0]) {
      testWidgets('habits stack in a single column (width $width)', (
        tester,
      ) async {
        // The list is single-column at every width (no orphan rows); the
        // heatmap band is what uses the extra width.
        final testState = HabitsState.initial().copyWith(
          habitDefinitions: [habitFlossing, habitFlossingDueLater],
          openNow: [habitFlossing, habitFlossingDueLater],
          displayFilter: HabitDisplayFilter.openNow,
        );

        await pump(
          tester,
          testState,
          mediaQueryData: MediaQueryData(size: Size(width, 1000)),
        );

        final aTop = tester.getTopLeft(find.byKey(Key(habitFlossing.id)));
        final bTop = tester.getTopLeft(
          find.byKey(Key(habitFlossingDueLater.id)),
        );
        // Stacked vertically, aligned on the same left edge.
        expect(aTop.dy, lessThan(bTop.dy));
        expect(aTop.dx, bTop.dx);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('renders an action row for pendingLater habits', (
      tester,
    ) async {
      final testState = HabitsState.initial().copyWith(
        habitDefinitions: [habitFlossing, habitFlossingDueLater],
        openNow: [],
        pendingLater: [habitFlossingDueLater],
        completed: [],
        displayFilter: HabitDisplayFilter.pendingLater,
      );

      await pump(tester, testState);

      expect(find.byType(HabitActionRow), findsOneWidget);
      expect(find.byKey(Key(habitFlossingDueLater.id)), findsOneWidget);
    });

    testWidgets('does not render rows for empty lists', (tester) async {
      final testState = HabitsState.initial().copyWith(
        habitDefinitions: [],
        openNow: [],
        pendingLater: [],
        completed: [],
        displayFilter: HabitDisplayFilter.all,
      );

      await pump(tester, testState);

      expect(find.byType(HabitActionRow), findsNothing);
    });

    testWidgets('chart card renders the time-span selector', (tester) async {
      // The time-span selector lives in HabitsChartCard at the bottom of the
      // page and is always rendered, independent of any showTimeSpan flag.
      final testState = HabitsState.initial().copyWith(
        habitDefinitions: [habitFlossing],
        openNow: [habitFlossing],
        displayFilter: HabitDisplayFilter.openNow,
      );

      await pump(tester, testState);

      expect(find.byType(TimeSpanSegmentedControl), findsOneWidget);
    });

    testWidgets('summary card surfaces the remaining "to go" count', (
      tester,
    ) async {
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
    });

    testWidgets(
      'summary card shows "All done today" when every habit is done',
      (
        tester,
      ) async {
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

    testWidgets('renders section headers with per-bucket counts under all', (
      tester,
    ) async {
      final testState = HabitsState.initial().copyWith(
        habitDefinitions: [habitFlossing, habitFlossingDueLater],
        openNow: [habitFlossing],
        pendingLater: [habitFlossingDueLater],
        completed: [],
        displayFilter: HabitDisplayFilter.all,
      );

      await pump(tester, testState);

      expect(find.byType(HabitsSectionHeader), findsNWidgets(2));
      expect(find.text('Due now'), findsOneWidget);
      expect(find.text('Later today'), findsOneWidget);
      expect(find.text('Completed'), findsNothing);
      expect(find.text('1'), findsNWidgets(2));
      expect(find.byKey(Key(habitFlossing.id)), findsOneWidget);
      expect(find.byKey(Key(habitFlossingDueLater.id)), findsOneWidget);
    });

    testWidgets('no section headers when a single-status filter is active', (
      tester,
    ) async {
      final testState = HabitsState.initial().copyWith(
        habitDefinitions: [habitFlossing, habitFlossingDueLater],
        openNow: [habitFlossing],
        pendingLater: [habitFlossingDueLater],
        displayFilter: HabitDisplayFilter.openNow,
      );

      await pump(tester, testState);

      expect(find.byType(HabitsSectionHeader), findsNothing);
      expect(find.byType(HabitActionRow), findsOneWidget);
      expect(find.byKey(Key(habitFlossing.id)), findsOneWidget);
    });

    testWidgets('searchString narrows the visible habit list', (tester) async {
      // 'later today' is a unique fragment of habitFlossingDueLater's name, so
      // the filter pass should drop habitFlossing.
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
    });

    testWidgets('empty searchString keeps every habit visible', (tester) async {
      final testState = HabitsState.initial().copyWith(
        habitDefinitions: [habitFlossing, habitFlossingDueLater],
        openNow: [habitFlossing, habitFlossingDueLater],
        showSearch: true,
        displayFilter: HabitDisplayFilter.openNow,
      );

      await pump(tester, testState);

      expect(find.byKey(Key(habitFlossing.id)), findsOneWidget);
      expect(find.byKey(Key(habitFlossingDueLater.id)), findsOneWidget);
    });

    testWidgets('lowercase searchString matches mixed-case names', (
      tester,
    ) async {
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
    });

    testWidgets('searchString matching the description keeps the habit', (
      tester,
    ) async {
      // 'gums' only appears in the shared description, not in either name.
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
    });

    testWidgets('non-matching searchString hides every habit', (tester) async {
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
      expect(find.byType(HabitActionRow), findsNothing);
    });
  });
}
