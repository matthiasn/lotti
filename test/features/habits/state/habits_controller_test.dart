import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockJournalDb;
  late MockUpdateNotifications mockUpdateNotifications;
  late StreamController<List<HabitDefinition>> definitionsController;
  late StreamController<Set<String>> updateController;
  late ProviderContainer container;

  final now = DateTime.now();
  final lastWeek = now.subtract(const Duration(days: 7));

  final testHabit = HabitDefinition(
    id: 'habit-1',
    name: 'Test Habit',
    description: 'Description',
    createdAt: lastWeek,
    updatedAt: lastWeek,
    vectorClock: null,
    private: false,
    active: true,
    activeFrom: lastWeek,
    habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
  );

  final testCompletion = HabitCompletionEntry(
    meta: Metadata(
      id: 'completion-1',
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now,
      vectorClock: null,
      private: false,
    ),
    data: HabitCompletionData(
      dateFrom: now,
      dateTo: now,
      habitId: 'habit-1',
      completionType: HabitCompletionType.success,
    ),
  );

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockUpdateNotifications = MockUpdateNotifications();
    definitionsController = StreamController.broadcast();
    updateController = StreamController.broadcast();

    when(mockJournalDb.watchHabitDefinitions)
        .thenAnswer((_) => definitionsController.stream);

    when(
      () => mockJournalDb.getHabitCompletionsInRange(
        rangeStart: any(named: 'rangeStart'),
      ),
    ).thenAnswer((_) async => []);

    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => updateController.stream);

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);

    container = ProviderContainer();
  });

  tearDown(() async {
    await definitionsController.close();
    await updateController.close();
    container.dispose();
    await getIt.reset();
  });

  group('HabitsController', () {
    test('initial state is HabitsState.initial()', () {
      final state = container.read(habitsControllerProvider);

      expect(state.habitDefinitions, isEmpty);
      expect(state.completedToday, isEmpty);
      expect(state.displayFilter, HabitDisplayFilter.openNow);
    });

    test('setDisplayFilter updates displayFilter', () {
      final controller = container.read(habitsControllerProvider.notifier);

      controller.setDisplayFilter(HabitDisplayFilter.all);

      final state = container.read(habitsControllerProvider);
      expect(state.displayFilter, HabitDisplayFilter.all);
    });

    test('setDisplayFilter ignores null', () {
      final controller = container.read(habitsControllerProvider.notifier);

      controller
        ..setDisplayFilter(HabitDisplayFilter.completed)
        ..setDisplayFilter(null);

      final state = container.read(habitsControllerProvider);
      expect(state.displayFilter, HabitDisplayFilter.completed);
    });

    test('setSearchString updates searchString in lowercase', () {
      final controller = container.read(habitsControllerProvider.notifier);

      controller.setSearchString('TEST Search');

      final state = container.read(habitsControllerProvider);
      expect(state.searchString, 'test search');
    });

    test('toggleZeroBased toggles zeroBased', () {
      final controller = container.read(habitsControllerProvider.notifier);

      expect(container.read(habitsControllerProvider).zeroBased, false);

      controller.toggleZeroBased();
      expect(container.read(habitsControllerProvider).zeroBased, true);

      controller.toggleZeroBased();
      expect(container.read(habitsControllerProvider).zeroBased, false);
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
}
