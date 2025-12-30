import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/ui/habits_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

class MockHabitsController extends HabitsController {
  MockHabitsController(this._state);

  final HabitsState _state;

  @override
  HabitsState build() => _state;

  @override
  void setDisplayFilter(HabitDisplayFilter? displayFilter) {}

  @override
  void toggleShowSearch() {}

  @override
  void toggleShowTimeSpan() {}

  @override
  void toggleSelectedCategoryIds(String categoryId) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var mockJournalDb = MockJournalDb();
  final mockEntitiesCacheService = MockEntitiesCacheService();
  final mockUpdateNotifications = MockUpdateNotifications();

  group('HabitsTabPage Widget Tests - ', () {
    setUp(() {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;

      mockJournalDb = mockJournalDbWithHabits([
        habitFlossing,
        habitFlossingDueLater,
      ]);

      when(mockJournalDb.watchCategories).thenAnswer(
        (_) => Stream<List<CategoryDefinition>>.fromIterable([
          [categoryMindfulness],
        ]),
      );

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
            habitsControllerProvider
                .overrideWith(() => MockHabitsController(testState)),
          ],
          child: makeTestableWidgetWithScaffold(
            const HabitsTabPage(),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(
        find.text(habitFlossing.name),
        findsOneWidget,
      );

      final searchButtonFinder = find.byIcon(Icons.search);
      expect(searchButtonFinder, findsOneWidget);

      await tester.tap(searchButtonFinder);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final timeSpanButtonFinder = find.byIcon(Icons.calendar_month);
      expect(timeSpanButtonFinder, findsOneWidget);

      await tester.tap(timeSpanButtonFinder);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final habitCategoryFilterFinder =
          find.byKey(const Key('habit_category_filter'));
      expect(habitCategoryFilterFinder, findsOneWidget);

      await tester.tap(habitCategoryFilterFinder);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    });
  });
}
