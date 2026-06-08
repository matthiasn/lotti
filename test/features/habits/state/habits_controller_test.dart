import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/habits/habit_completion_resolution.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHabitsRepository mockRepository;
  late MockNavService mockNavService;
  late StreamController<List<HabitDefinition>> definitionsController;
  late StreamController<Set<String>> updateController;
  late StreamController<int> navIndexController;
  late ProviderContainer container;

  const habitsTabIndex = 3;

  // Use fixed dates for deterministic tests
  final lastWeek = DateTime(2025, 12, 23);

  final testHabit1 = HabitDefinition(
    id: 'habit-1',
    name: 'Test Habit 1',
    description: 'Description 1',
    createdAt: lastWeek,
    updatedAt: lastWeek,
    vectorClock: null,
    private: false,
    active: true,
    activeFrom: lastWeek,
    categoryId: 'cat-1',
    habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
  );

  final testHabit2 = HabitDefinition(
    id: 'habit-2',
    name: 'Test Habit 2',
    description: 'Description 2',
    createdAt: lastWeek,
    updatedAt: lastWeek,
    vectorClock: null,
    private: false,
    active: true,
    activeFrom: lastWeek,
    categoryId: 'cat-2',
    habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
  );

  HabitCompletionEntry createCompletion({
    required String id,
    required String habitId,
    required DateTime date,
    required HabitCompletionType completionType,
    DateTime? writtenAt,
  }) {
    final effectiveWrittenAt = writtenAt ?? date;
    return HabitCompletionEntry(
      meta: Metadata(
        id: id,
        createdAt: effectiveWrittenAt,
        updatedAt: effectiveWrittenAt,
        dateFrom: date,
        dateTo: date,
        private: false,
      ),
      data: HabitCompletionData(
        dateFrom: date,
        dateTo: date,
        habitId: habitId,
        completionType: completionType,
      ),
    );
  }

  setUp(() async {
    mockRepository = MockHabitsRepository();
    mockNavService = MockNavService();
    definitionsController = StreamController.broadcast();
    updateController = StreamController.broadcast();
    navIndexController = StreamController<int>.broadcast();

    when(
      mockRepository.watchHabitDefinitions,
    ).thenAnswer((_) => definitionsController.stream);

    when(
      () => mockRepository.getHabitCompletionsInRange(
        rangeStart: any(named: 'rangeStart'),
      ),
    ).thenAnswer((_) async => []);

    when(
      () => mockRepository.updateStream,
    ).thenAnswer((_) => updateController.stream);

    when(() => mockNavService.habitsIndex).thenReturn(habitsTabIndex);
    when(() => mockNavService.index).thenReturn(habitsTabIndex);
    when(
      mockNavService.getIndexStream,
    ).thenAnswer((_) => navIndexController.stream);

    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<NavService>(mockNavService);
      },
    );

    container = ProviderContainer(
      overrides: [
        habitsRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() async {
    await definitionsController.close();
    await updateController.close();
    await navIndexController.close();
    container.dispose();
    await tearDownTestGetIt();
  });

  group('HabitsController', () {
    test('initial state is HabitsState.initial()', () {
      final state = container.read(habitsControllerProvider);

      expect(state.habitDefinitions, isEmpty);
      expect(state.completedToday, isEmpty);
      expect(state.displayFilter, HabitDisplayFilter.openNow);
    });

    test('setDisplayFilter updates displayFilter', () {
      container
          .read(habitsControllerProvider.notifier)
          .setDisplayFilter(HabitDisplayFilter.all);

      final state = container.read(habitsControllerProvider);
      expect(state.displayFilter, HabitDisplayFilter.all);
    });

    test('setDisplayFilter ignores null', () {
      container.read(habitsControllerProvider.notifier)
        ..setDisplayFilter(HabitDisplayFilter.completed)
        ..setDisplayFilter(null);

      final state = container.read(habitsControllerProvider);
      expect(state.displayFilter, HabitDisplayFilter.completed);
    });

    test('setSearchString updates searchString in lowercase', () {
      container
          .read(habitsControllerProvider.notifier)
          .setSearchString('TEST Search');

      final state = container.read(habitsControllerProvider);
      expect(state.searchString, 'test search');
    });

    test('toggleZeroBased toggles zeroBased', () {
      final controller = container.read(habitsControllerProvider.notifier);

      // Default is true (matching prior cubit behavior after first emit)
      expect(container.read(habitsControllerProvider).zeroBased, true);

      controller.toggleZeroBased();
      expect(container.read(habitsControllerProvider).zeroBased, false);

      controller.toggleZeroBased();
      expect(container.read(habitsControllerProvider).zeroBased, true);
    });

    test('toggleShowSearch toggles showSearch', () {
      final controller = container.read(habitsControllerProvider.notifier);

      expect(container.read(habitsControllerProvider).showSearch, false);

      controller.toggleShowSearch();
      expect(container.read(habitsControllerProvider).showSearch, true);

      controller.toggleShowSearch();
      expect(container.read(habitsControllerProvider).showSearch, false);
    });

    test('toggleShowTimeSpan toggles showTimeSpan', () {
      final controller = container.read(habitsControllerProvider.notifier);

      expect(container.read(habitsControllerProvider).showTimeSpan, false);

      controller.toggleShowTimeSpan();
      expect(container.read(habitsControllerProvider).showTimeSpan, true);

      controller.toggleShowTimeSpan();
      expect(container.read(habitsControllerProvider).showTimeSpan, false);
    });

    test('toggleSelectedCategoryIds adds and removes category IDs', () {
      final controller = container.read(habitsControllerProvider.notifier);

      expect(
        container.read(habitsControllerProvider).selectedCategoryIds,
        isEmpty,
      );

      controller.toggleSelectedCategoryIds('cat-1');
      expect(
        container.read(habitsControllerProvider).selectedCategoryIds,
        {'cat-1'},
      );

      controller.toggleSelectedCategoryIds('cat-2');
      expect(
        container.read(habitsControllerProvider).selectedCategoryIds,
        {'cat-1', 'cat-2'},
      );

      controller.toggleSelectedCategoryIds('cat-1');
      expect(
        container.read(habitsControllerProvider).selectedCategoryIds,
        {'cat-2'},
      );
    });

    test('setTimeSpan updates timeSpanDays', () async {
      // Wait for initialization to complete
      await pumpEventQueue();

      final controller = container.read(habitsControllerProvider.notifier);

      await controller.setTimeSpan(30);

      final state = container.read(habitsControllerProvider);
      expect(state.timeSpanDays, 30);
      expect(state.days.length, 31); // 30 days + today
    });
  });

  group('_determineHabitSuccessByDays', () {
    // The controller internally uses DateTime.now() to determine "today",
    // so completion dates must match the real wall-clock date. We compute
    // it once here to keep individual tests free of DateTime.now() calls.
    late DateTime controllerToday;
    late String controllerTodayYmd;

    setUp(() {
      controllerToday = DateTime.now(); // ignore: avoid_DateTime_now
      controllerTodayYmd = controllerToday.ymd;
    });

    test('processes completions and updates state fields', () async {
      // Setup completions
      final completions = [
        createCompletion(
          id: 'c1',
          habitId: 'habit-1',
          date: controllerToday,
          completionType: HabitCompletionType.success,
        ),
        createCompletion(
          id: 'c2',
          habitId: 'habit-2',
          date: controllerToday,
          completionType: HabitCompletionType.skip,
        ),
      ];

      when(
        () => mockRepository.getHabitCompletionsInRange(
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer((_) async => completions);

      // Trigger initialization
      container.read(habitsControllerProvider);
      await pumpEventQueue();

      // Emit habit definitions
      definitionsController.add([testHabit1, testHabit2]);
      await pumpEventQueue();

      final state = container.read(habitsControllerProvider);

      // Verify completedToday contains both completed habits
      expect(state.completedToday, contains('habit-1'));
      expect(state.completedToday, contains('habit-2'));

      // Verify successfulToday (success and skip count as successful)
      expect(state.successfulToday, contains('habit-1'));
      expect(state.successfulToday, contains('habit-2'));

      // Verify byDay maps
      expect(state.successfulByDay[controllerTodayYmd], contains('habit-1'));
      expect(state.skippedByDay[controllerTodayYmd], contains('habit-2'));
      expect(state.allByDay[controllerTodayYmd], contains('habit-1'));
      expect(state.allByDay[controllerTodayYmd], contains('habit-2'));
    });

    test('handles fail completions correctly', () async {
      final completions = [
        createCompletion(
          id: 'c1',
          habitId: 'habit-1',
          date: controllerToday,
          completionType: HabitCompletionType.fail,
        ),
      ];

      when(
        () => mockRepository.getHabitCompletionsInRange(
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer((_) async => completions);

      container.read(habitsControllerProvider);
      await pumpEventQueue();

      definitionsController.add([testHabit1]);
      await pumpEventQueue();

      final state = container.read(habitsControllerProvider);

      // Failed completions are tracked in completedToday but not successfulToday
      expect(state.completedToday, contains('habit-1'));
      expect(state.successfulToday, isNot(contains('habit-1')));
      expect(state.failedByDay[controllerTodayYmd], contains('habit-1'));
    });

    test(
      'uses the latest write returned by the repository for repeated same-day completions',
      () async {
        final completions = [
          createCompletion(
            id: 'newer-fail',
            habitId: 'habit-1',
            date: controllerToday,
            writtenAt: DateTime(2025, 12, 30, 11),
            completionType: HabitCompletionType.fail,
          ),
          createCompletion(
            id: 'older-success',
            habitId: 'habit-1',
            date: controllerToday,
            writtenAt: DateTime(2025, 12, 30, 10),
            completionType: HabitCompletionType.success,
          ),
        ];

        when(
          () => mockRepository.getHabitCompletionsInRange(
            rangeStart: any(named: 'rangeStart'),
          ),
        ).thenAnswer((_) async => latestHabitCompletionsByDay(completions));

        container.read(habitsControllerProvider);
        await pumpEventQueue();

        definitionsController.add([testHabit1]);
        await pumpEventQueue();

        final state = container.read(habitsControllerProvider);

        expect(state.completedToday, contains('habit-1'));
        expect(state.successfulToday, isNot(contains('habit-1')));
        expect(
          state.successfulByDay[controllerTodayYmd],
          isNot(contains('habit-1')),
        );
        expect(state.failedByDay[controllerTodayYmd], contains('habit-1'));
      },
    );

    test('calculates streak counts correctly', () async {
      // Create completions for 4 consecutive days (qualifies for short streak)
      final completions = <JournalEntity>[];
      for (var i = 0; i <= 3; i++) {
        completions.add(
          createCompletion(
            id: 'c$i',
            habitId: 'habit-1',
            date: controllerToday.subtract(Duration(days: i)),
            completionType: HabitCompletionType.success,
          ),
        );
      }

      when(
        () => mockRepository.getHabitCompletionsInRange(
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer((_) async => completions);

      container.read(habitsControllerProvider);
      await pumpEventQueue();

      definitionsController.add([testHabit1]);
      await pumpEventQueue();

      final state = container.read(habitsControllerProvider);

      // Should have at least one short streak (4 days)
      expect(state.shortStreakCount, greaterThanOrEqualTo(1));
    });
  });

  group('UpdateNotifications stream handling', () {
    test('refetches completions when habitCompletionNotification received', () {
      fakeAsync((async) {
        container.read(habitsControllerProvider);
        async.flushMicrotasks();

        // Initial emit
        definitionsController.add([testHabit1]);
        async.flushMicrotasks();

        // Reset mock to track new calls
        clearInteractions(mockRepository);
        when(
          () => mockRepository.getHabitCompletionsInRange(
            rangeStart: any(named: 'rangeStart'),
          ),
        ).thenAnswer((_) async => []);

        // Emit update notification
        updateController.add({habitCompletionNotification});
        // Flush to deliver stream event + process async handler,
        // then elapse the 200ms production debounce inside the handler
        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 200))
          ..flushMicrotasks();

        // Verify getHabitCompletionsInRange was called again
        verify(
          () => mockRepository.getHabitCompletionsInRange(
            rangeStart: any(named: 'rangeStart'),
          ),
        ).called(greaterThanOrEqualTo(1));
      });
    });

    test('ignores unrelated notifications', () {
      fakeAsync((async) {
        container.read(habitsControllerProvider);
        async.flushMicrotasks();

        definitionsController.add([testHabit1]);
        async.flushMicrotasks();

        clearInteractions(mockRepository);
        when(
          () => mockRepository.getHabitCompletionsInRange(
            rangeStart: any(named: 'rangeStart'),
          ),
        ).thenAnswer((_) async => []);

        // Emit unrelated notification
        updateController.add({'some-other-notification'});
        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 200))
          ..flushMicrotasks();

        // Should not trigger refetch
        verifyNever(
          () => mockRepository.getHabitCompletionsInRange(
            rangeStart: any(named: 'rangeStart'),
          ),
        );
      });
    });
  });
}
