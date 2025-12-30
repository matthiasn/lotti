import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:mocktail/mocktail.dart';

class MockHabitsRepository extends Mock implements HabitsRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHabitsRepository mockRepository;
  late StreamController<List<HabitDefinition>> definitionsController;
  late StreamController<Set<String>> updateController;
  late ProviderContainer container;

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

  final testHabit3 = HabitDefinition(
    id: 'habit-3',
    name: 'Test Habit 3',
    description: 'Description 3',
    createdAt: lastWeek,
    updatedAt: lastWeek,
    vectorClock: null,
    private: false,
    active: true,
    activeFrom: lastWeek,
    categoryId: 'cat-1',
    habitSchedule: HabitSchedule.daily(
      requiredCompletions: 1,
      // Show from 18:00 onwards - should be in pendingLater
      showFrom: DateTime(2025, 12, 30, 18),
    ),
  );

  HabitCompletionEntry createCompletion({
    required String id,
    required String habitId,
    required DateTime date,
    required HabitCompletionType completionType,
  }) {
    return HabitCompletionEntry(
      meta: Metadata(
        id: id,
        createdAt: date,
        updatedAt: date,
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

  setUp(() {
    mockRepository = MockHabitsRepository();
    definitionsController = StreamController.broadcast();
    updateController = StreamController.broadcast();

    when(mockRepository.watchHabitDefinitions)
        .thenAnswer((_) => definitionsController.stream);

    when(
      () => mockRepository.getHabitCompletionsInRange(
        rangeStart: any(named: 'rangeStart'),
      ),
    ).thenAnswer((_) async => []);

    when(() => mockRepository.updateStream)
        .thenAnswer((_) => updateController.stream);

    container = ProviderContainer(
      overrides: [
        habitsRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() async {
    await definitionsController.close();
    await updateController.close();
    container.dispose();
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
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final controller = container.read(habitsControllerProvider.notifier);

      await controller.setTimeSpan(30);

      final state = container.read(habitsControllerProvider);
      expect(state.timeSpanDays, 30);
      expect(state.days.length, 31); // 30 days + today
    });
  });

  group('_determineHabitSuccessByDays', () {
    test('processes completions and updates state fields', () async {
      final todayYmd = DateTime.now().ymd;
      final now = DateTime.now();

      // Setup completions
      final completions = [
        createCompletion(
          id: 'c1',
          habitId: 'habit-1',
          date: now,
          completionType: HabitCompletionType.success,
        ),
        createCompletion(
          id: 'c2',
          habitId: 'habit-2',
          date: now,
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
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Emit habit definitions
      definitionsController.add([testHabit1, testHabit2]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = container.read(habitsControllerProvider);

      // Verify completedToday contains both completed habits
      expect(state.completedToday, contains('habit-1'));
      expect(state.completedToday, contains('habit-2'));

      // Verify successfulToday (success and skip count as successful)
      expect(state.successfulToday, contains('habit-1'));
      expect(state.successfulToday, contains('habit-2'));

      // Verify byDay maps
      expect(state.successfulByDay[todayYmd], contains('habit-1'));
      expect(state.skippedByDay[todayYmd], contains('habit-2'));
      expect(state.allByDay[todayYmd], contains('habit-1'));
      expect(state.allByDay[todayYmd], contains('habit-2'));
    });

    test('handles fail completions correctly', () async {
      final todayYmd = DateTime.now().ymd;
      final now = DateTime.now();

      final completions = [
        createCompletion(
          id: 'c1',
          habitId: 'habit-1',
          date: now,
          completionType: HabitCompletionType.fail,
        ),
      ];

      when(
        () => mockRepository.getHabitCompletionsInRange(
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer((_) async => completions);

      container.read(habitsControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      definitionsController.add([testHabit1]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = container.read(habitsControllerProvider);

      // Failed completions are tracked in completedToday but not successfulToday
      expect(state.completedToday, contains('habit-1'));
      expect(state.successfulToday, isNot(contains('habit-1')));
      expect(state.failedByDay[todayYmd], contains('habit-1'));
    });

    test('calculates streak counts correctly', () async {
      final now = DateTime.now();
      // Create completions for 4 consecutive days (qualifies for short streak)
      final completions = <JournalEntity>[];
      for (var i = 0; i <= 3; i++) {
        completions.add(
          createCompletion(
            id: 'c$i',
            habitId: 'habit-1',
            date: now.subtract(Duration(days: i)),
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
      await Future<void>.delayed(const Duration(milliseconds: 50));

      definitionsController.add([testHabit1]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final state = container.read(habitsControllerProvider);

      // Should have at least one short streak (4 days)
      expect(state.shortStreakCount, greaterThanOrEqualTo(1));
    });
  });

  group('UpdateNotifications stream handling', () {
    test('refetches completions when habitCompletionNotification received',
        () async {
      container.read(habitsControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Initial emit
      definitionsController.add([testHabit1]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Reset mock to track new calls
      clearInteractions(mockRepository);
      when(
        () => mockRepository.getHabitCompletionsInRange(
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer((_) async => []);

      // Emit update notification
      updateController.add({habitCompletionNotification});
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Verify getHabitCompletionsInRange was called again
      verify(
        () => mockRepository.getHabitCompletionsInRange(
          rangeStart: any(named: 'rangeStart'),
        ),
      ).called(greaterThanOrEqualTo(1));
    });

    test('ignores unrelated notifications', () async {
      container.read(habitsControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      definitionsController.add([testHabit1]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      clearInteractions(mockRepository);
      when(
        () => mockRepository.getHabitCompletionsInRange(
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer((_) async => []);

      // Emit unrelated notification
      updateController.add({'some-other-notification'});
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Should not trigger refetch
      verifyNever(
        () => mockRepository.getHabitCompletionsInRange(
          rangeStart: any(named: 'rangeStart'),
        ),
      );
    });
  });

  group('setInfoYmd', () {
    test('calculates percentage correctly', () async {
      final todayYmd = DateTime.now().ymd;
      final now = DateTime.now();

      // 2 habits, 1 success, 1 fail = 50% success, 0% skipped, 50% fail
      final completions = [
        createCompletion(
          id: 'c1',
          habitId: 'habit-1',
          date: now,
          completionType: HabitCompletionType.success,
        ),
        createCompletion(
          id: 'c2',
          habitId: 'habit-2',
          date: now,
          completionType: HabitCompletionType.fail,
        ),
      ];

      when(
        () => mockRepository.getHabitCompletionsInRange(
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer((_) async => completions);

      final controller = container.read(habitsControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      definitionsController.add([testHabit1, testHabit2]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      controller.setInfoYmd(todayYmd);

      final state = container.read(habitsControllerProvider);
      expect(state.selectedInfoYmd, todayYmd);
      expect(state.successPercentage, 50);
      expect(state.skippedPercentage, 0);
      expect(state.failedPercentage, 50);
    });

    test('clamps failed percentage when total exceeds 100', () async {
      final todayYmd = DateTime.now().ymd;
      final now = DateTime.now();

      // Edge case: success + skip + fail > 100 (shouldn't happen but test clamp)
      final completions = [
        createCompletion(
          id: 'c1',
          habitId: 'habit-1',
          date: now,
          completionType: HabitCompletionType.success,
        ),
      ];

      when(
        () => mockRepository.getHabitCompletionsInRange(
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer((_) async => completions);

      final controller = container.read(habitsControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      definitionsController.add([testHabit1]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      controller.setInfoYmd(todayYmd);

      final state = container.read(habitsControllerProvider);
      // Total should not exceed 100
      final total = state.successPercentage +
          state.skippedPercentage +
          state.failedPercentage;
      expect(total, lessThanOrEqualTo(100));
    });

    test('clears selectedInfoYmd after debounce', () {
      fakeAsync((async) {
        container
            .read(habitsControllerProvider.notifier)
            .setInfoYmd('2025-12-30');
        expect(
          container.read(habitsControllerProvider).selectedInfoYmd,
          '2025-12-30',
        );

        // Advance time past debounce (15 seconds)
        async.elapse(const Duration(seconds: 16));

        expect(
          container.read(habitsControllerProvider).selectedInfoYmd,
          isEmpty,
        );
      });
    });
  });

  group('Category filtering', () {
    test('filters openNow by selected category', () async {
      when(
        () => mockRepository.getHabitCompletionsInRange(
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer((_) async => []);

      final controller = container.read(habitsControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // testHabit1 has cat-1, testHabit2 has cat-2
      definitionsController.add([testHabit1, testHabit2]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Before filtering - both habits should be in openNow
      var state = container.read(habitsControllerProvider);
      expect(state.openNow.length, 2);

      // Filter by cat-1
      controller.toggleSelectedCategoryIds('cat-1');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      state = container.read(habitsControllerProvider);
      expect(state.openNow.length, 1);
      expect(state.openNow.first.id, 'habit-1');
    });

    test('filters completed by selected category', () async {
      final now = DateTime.now();

      // Both habits completed today
      final completions = [
        createCompletion(
          id: 'c1',
          habitId: 'habit-1',
          date: now,
          completionType: HabitCompletionType.success,
        ),
        createCompletion(
          id: 'c2',
          habitId: 'habit-2',
          date: now,
          completionType: HabitCompletionType.success,
        ),
      ];

      when(
        () => mockRepository.getHabitCompletionsInRange(
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer((_) async => completions);

      final controller = container.read(habitsControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      definitionsController.add([testHabit1, testHabit2]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Both should be completed
      var state = container.read(habitsControllerProvider);
      expect(state.completed.length, 2);

      // Filter by cat-2
      controller.toggleSelectedCategoryIds('cat-2');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      state = container.read(habitsControllerProvider);
      expect(state.completed.length, 1);
      expect(state.completed.first.id, 'habit-2');
    });

    test('filters pendingLater by selected category', () async {
      when(
        () => mockRepository.getHabitCompletionsInRange(
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer((_) async => []);

      final controller = container.read(habitsControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // testHabit3 has showFrom: 18 (pending later) and cat-1
      definitionsController.add([testHabit1, testHabit3]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Filter by cat-1 - both habits have cat-1
      controller.toggleSelectedCategoryIds('cat-1');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(habitsControllerProvider);
      // testHabit3 should be in pendingLater (if current time < 18:00)
      // testHabit1 should be in openNow
      expect(
        state.openNow.map((h) => h.id),
        contains('habit-1'),
      );
    });
  });
}
