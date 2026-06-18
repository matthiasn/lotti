import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/habits/state/heatmap/habit_heatmap_controller.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

/// A [HabitsController] stand-in whose category filter can be driven from the
/// test, so the heatmap's "recompute on filter change" path is exercisable.
class _FilterController extends HabitsController {
  @override
  HabitsState build() => HabitsState.initial();

  void emitCategories(Set<String> ids) {
    state = state.copyWith(selectedCategoryIds: ids);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Today, pinned via fakeAsync's initialTime so clock.now() is deterministic.
  final fixedNow = DateTime(2026, 6, 17, 12);

  late MockHabitsRepository mockRepository;
  late StreamController<List<HabitDefinition>> definitionsController;
  late StreamController<Set<String>> updateController;

  HabitDefinition habit({
    required String id,
    String categoryId = 'cat-1',
    DateTime? activeFrom,
  }) {
    return HabitDefinition(
      id: id,
      name: id,
      description: '',
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
      vectorClock: null,
      private: false,
      active: true,
      activeFrom: activeFrom,
      categoryId: categoryId,
      habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
    );
  }

  HabitCompletionEntry completion({
    required String habitId,
    required DateTime date,
    HabitCompletionType type = HabitCompletionType.success,
  }) {
    return HabitCompletionEntry(
      meta: Metadata(
        id: '$habitId-${date.ymd}',
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
        completionType: type,
      ),
    );
  }

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
        habitsRepositoryProvider.overrideWithValue(mockRepository),
        habitsControllerProvider.overrideWith(_FilterController.new),
      ],
    );
  }

  setUp(() {
    mockRepository = MockHabitsRepository();
    definitionsController = StreamController.broadcast();
    updateController = StreamController.broadcast();

    when(
      mockRepository.watchHabitDefinitions,
    ).thenAnswer((_) => definitionsController.stream);
    when(
      () => mockRepository.getHabitCompletionsInRange(
        rangeStart: any(named: 'rangeStart'),
      ),
    ).thenAnswer((_) async => <JournalEntity>[]);
    when(
      () => mockRepository.updateStream,
    ).thenAnswer((_) => updateController.stream);
  });

  tearDown(() async {
    await definitionsController.close();
    await updateController.close();
  });

  test('initial state is the empty/loading placeholder', () {
    fakeAsync((async) {
      final container = makeContainer();
      addTearDown(container.dispose);

      final state = container.read(habitHeatmapControllerProvider);
      expect(state.isLoading, isTrue);
      expect(state.days, isEmpty);
      expect(state.hasHabits, isFalse);
    }, initialTime: fixedNow);
  });

  test('builds the day series after definitions and completions load', () {
    fakeAsync((async) {
      when(
        () => mockRepository.getHabitCompletionsInRange(
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer(
        (_) async => [completion(habitId: 'h1', date: DateTime(2026, 6, 16))],
      );

      final container = makeContainer();
      addTearDown(container.dispose);
      container.read(habitHeatmapControllerProvider);
      async.flushMicrotasks();

      definitionsController.add([habit(id: 'h1', activeFrom: DateTime(2026))]);
      async.flushMicrotasks();

      final state = container.read(habitHeatmapControllerProvider);
      expect(state.isLoading, isFalse);
      expect(state.hasHabits, isTrue);
      expect(state.days, isNotEmpty);
      // Yesterday's success is reflected.
      expect(
        state.days.firstWhere((d) => d.ymd == '2026-06-16').successCount,
        1,
      );
      // Today is flagged.
      expect(state.days.where((d) => d.isToday).map((d) => d.ymd), [
        '2026-06-17',
      ]);
    }, initialTime: fixedNow);
  });

  test('empty habit list → hasHabits false, neutral grid', () {
    fakeAsync((async) {
      final container = makeContainer();
      addTearDown(container.dispose);
      container.read(habitHeatmapControllerProvider);
      async.flushMicrotasks();

      definitionsController.add([]);
      async.flushMicrotasks();

      final state = container.read(habitHeatmapControllerProvider);
      expect(state.hasHabits, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.days.every((d) => d.activeCount == 0), isTrue);
    }, initialTime: fixedNow);
  });

  group('range start', () {
    DateTime capturedRangeStart() {
      final captured = verify(
        () => mockRepository.getHabitCompletionsInRange(
          rangeStart: captureAny(named: 'rangeStart'),
        ),
      ).captured;
      return captured.last as DateTime;
    }

    test('recent habit → one-year floor', () {
      fakeAsync((async) {
        final container = makeContainer();
        addTearDown(container.dispose);
        container.read(habitHeatmapControllerProvider);
        async.flushMicrotasks();
        definitionsController.add([
          habit(id: 'h1', activeFrom: DateTime(2025, 12, 23)),
        ]);
        async.flushMicrotasks();
        expect(capturedRangeStart(), DateTime(2025, 6, 17));
      }, initialTime: fixedNow);
    });

    test('old habit → uses its activeFrom', () {
      fakeAsync((async) {
        final container = makeContainer();
        addTearDown(container.dispose);
        container.read(habitHeatmapControllerProvider);
        async.flushMicrotasks();
        definitionsController.add([
          habit(id: 'h1', activeFrom: DateTime(2023)),
        ]);
        async.flushMicrotasks();
        expect(capturedRangeStart(), DateTime(2023));
      }, initialTime: fixedNow);
    });

    test('range start uses the earliest activeFrom across habits', () {
      fakeAsync((async) {
        final container = makeContainer();
        addTearDown(container.dispose);
        container.read(habitHeatmapControllerProvider);
        async.flushMicrotasks();
        // h1 seeds `earliest`; h2 is earlier, so it wins via from.isBefore().
        definitionsController.add([
          habit(id: 'h1', activeFrom: DateTime(2024, 6)),
          habit(id: 'h2', activeFrom: DateTime(2023, 3)),
        ]);
        async.flushMicrotasks();
        expect(capturedRangeStart(), DateTime(2023, 3));
      }, initialTime: fixedNow);
    });

    test('ancient habit → clamped to the five-year cap', () {
      fakeAsync((async) {
        final container = makeContainer();
        addTearDown(container.dispose);
        container.read(habitHeatmapControllerProvider);
        async.flushMicrotasks();
        definitionsController.add([
          habit(id: 'h1', activeFrom: DateTime(2010)),
        ]);
        async.flushMicrotasks();
        expect(capturedRangeStart(), DateTime(2021, 6, 17));
      }, initialTime: fixedNow);
    });
  });

  test('habitCompletionNotification refetches and recomputes', () {
    fakeAsync((async) {
      final container = makeContainer();
      addTearDown(container.dispose);
      container.read(habitHeatmapControllerProvider);
      async.flushMicrotasks();
      definitionsController.add([habit(id: 'h1', activeFrom: DateTime(2026))]);
      async.flushMicrotasks();

      clearInteractions(mockRepository);
      when(
        () => mockRepository.getHabitCompletionsInRange(
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer(
        (_) async => [completion(habitId: 'h1', date: DateTime(2026, 6, 17))],
      );

      updateController.add({habitCompletionNotification});
      async.flushMicrotasks();

      verify(
        () => mockRepository.getHabitCompletionsInRange(
          rangeStart: any(named: 'rangeStart'),
        ),
      ).called(1);
      final state = container.read(habitHeatmapControllerProvider);
      expect(
        state.days.firstWhere((d) => d.ymd == '2026-06-17').successCount,
        1,
      );
    }, initialTime: fixedNow);
  });

  test('unrelated notification does not refetch', () {
    fakeAsync((async) {
      final container = makeContainer();
      addTearDown(container.dispose);
      container.read(habitHeatmapControllerProvider);
      async.flushMicrotasks();
      definitionsController.add([habit(id: 'h1', activeFrom: DateTime(2026))]);
      async.flushMicrotasks();

      clearInteractions(mockRepository);
      updateController.add({'some-other-notification'});
      async.flushMicrotasks();

      verifyNever(
        () => mockRepository.getHabitCompletionsInRange(
          rangeStart: any(named: 'rangeStart'),
        ),
      );
    }, initialTime: fixedNow);
  });

  test('category filter change recomputes without refetching', () {
    fakeAsync((async) {
      when(
        () => mockRepository.getHabitCompletionsInRange(
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer(
        (_) async => [
          completion(habitId: 'h1', date: DateTime(2026, 6, 16)),
        ],
      );

      final container = makeContainer();
      addTearDown(container.dispose);
      container.read(habitHeatmapControllerProvider);
      async.flushMicrotasks();
      definitionsController.add([
        habit(id: 'h1', activeFrom: DateTime(2026)),
      ]);
      async.flushMicrotasks();

      clearInteractions(mockRepository);

      // Filter to a category that excludes h1 → day goes neutral, no refetch.
      (container.read(habitsControllerProvider.notifier) as _FilterController)
          .emitCategories({'cat-other'});
      async.flushMicrotasks();

      verifyNever(
        () => mockRepository.getHabitCompletionsInRange(
          rangeStart: any(named: 'rangeStart'),
        ),
      );
      final state = container.read(habitHeatmapControllerProvider);
      expect(
        state.days.firstWhere((d) => d.ymd == '2026-06-16').successCount,
        0,
      );
    }, initialTime: fixedNow);
  });

  test('never republishes a loading state after the first success', () {
    fakeAsync((async) {
      final container = makeContainer();
      addTearDown(container.dispose);
      final loadingFlags = <bool>[];
      container.listen(
        habitHeatmapControllerProvider,
        (_, next) => loadingFlags.add(next.isLoading),
        fireImmediately: true,
      );
      async.flushMicrotasks();
      definitionsController.add([habit(id: 'h1', activeFrom: DateTime(2026))]);
      async.flushMicrotasks();
      updateController.add({habitCompletionNotification});
      async.flushMicrotasks();

      // Once loading flips false it must never flip back to true.
      final firstResolved = loadingFlags.indexOf(false);
      expect(firstResolved, greaterThanOrEqualTo(0));
      expect(
        loadingFlags.sublist(firstResolved).any((loading) => loading),
        isFalse,
      );
    }, initialTime: fixedNow);
  });

  test('disposal stops further updates', () {
    fakeAsync((async) {
      final container = makeContainer()..read(habitHeatmapControllerProvider);
      async.flushMicrotasks();
      container.dispose();

      // Late stream events after disposal must not throw.
      definitionsController.add([habit(id: 'h1', activeFrom: DateTime(2026))]);
      updateController.add({habitCompletionNotification});
      expect(() => async.flushMicrotasks(), returnsNormally);
    }, initialTime: fixedNow);
  });
}
