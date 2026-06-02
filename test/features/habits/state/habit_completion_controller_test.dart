import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/features/habits/state/habit_completion_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/charts/habits/dashboard_habits_data.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const habitId = 'habit-1';
  final rangeStart = DateTime(2024, 3, 10);
  final rangeEnd = DateTime(2024, 3, 12);

  final habitDefinition = HabitDefinition(
    id: habitId,
    name: 'Test Habit',
    description: 'Description',
    createdAt: rangeStart,
    updatedAt: rangeStart,
    vectorClock: null,
    private: false,
    active: true,
    activeFrom: rangeStart,
    categoryId: 'cat-1',
    habitSchedule: const HabitSchedule.daily(requiredCompletions: 1),
  );

  HabitCompletionEntry completion({
    required String id,
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

  late MockHabitsRepository mockRepository;
  late MockEntitiesCacheService mockCache;
  late StreamController<Set<String>> updateController;
  late ProviderContainer container;

  setUp(() async {
    mockRepository = MockHabitsRepository();
    mockCache = MockEntitiesCacheService();
    updateController = StreamController<Set<String>>.broadcast();

    when(
      () => mockRepository.updateStream,
    ).thenAnswer((_) => updateController.stream);
    when(() => mockCache.getHabitById(habitId)).thenReturn(habitDefinition);

    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<EntitiesCacheService>(mockCache);
      },
    );

    container = ProviderContainer(
      overrides: [
        habitsRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await updateController.close();
    await tearDownTestGetIt();
  });

  void stubCompletions(List<JournalEntity> entities) {
    when(
      () => mockRepository.getHabitCompletionsByHabitId(
        habitId: habitId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
    ).thenAnswer((_) async => entities);
  }

  Future<List<HabitResult>> readResults() {
    return container.read(
      habitCompletionControllerProvider(
        habitId: habitId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ).future,
    );
  }

  group('HabitCompletionController.build', () {
    test('returns results mapped from repository completions', () async {
      stubCompletions([
        completion(
          id: 'c1',
          date: DateTime(2024, 3, 11),
          completionType: HabitCompletionType.success,
        ),
      ]);

      final results = await readResults();

      // One HabitResult per day in the inclusive range (10th, 11th, 12th).
      expect(results.map((r) => r.dayString), [
        '2024-03-10',
        '2024-03-11',
        '2024-03-12',
      ]);
      final byDay = {for (final r in results) r.dayString: r.completionType};
      expect(byDay['2024-03-11'], HabitCompletionType.success);
      expect(byDay['2024-03-10'], HabitCompletionType.open);
    });

    test('returns empty list when habit definition is missing', () async {
      // Covers the `habitDefinition == null` early return (line 64).
      when(() => mockCache.getHabitById(habitId)).thenReturn(null);
      stubCompletions([
        completion(
          id: 'c1',
          date: DateTime(2024, 3, 11),
          completionType: HabitCompletionType.success,
        ),
      ]);

      final results = await readResults();

      expect(results, isEmpty);
    });
  });

  group('HabitCompletionController.listen update stream', () {
    test(
      'refreshes state when an affecting id arrives and data changed',
      () async {
        // Initial fetch: no completions -> day is "open".
        stubCompletions([]);
        final initial = await readResults();
        final initialByDay = {
          for (final r in initial) r.dayString: r.completionType,
        };
        expect(initialByDay['2024-03-11'], HabitCompletionType.open);

        // Re-stub so the next fetch returns a success completion.
        stubCompletions([
          completion(
            id: 'c1',
            date: DateTime(2024, 3, 11),
            completionType: HabitCompletionType.success,
          ),
        ]);

        // Emit an update affecting this habit (lines 23-26).
        updateController.add({habitId});
        await pumpEventQueue();

        final updated = container
            .read(
              habitCompletionControllerProvider(
                habitId: habitId,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              ),
            )
            .value!;
        final updatedByDay = {
          for (final r in updated) r.dayString: r.completionType,
        };
        expect(updatedByDay['2024-03-11'], HabitCompletionType.success);
        // _fetch is called once for build and once for the matching update.
        verify(
          () => mockRepository.getHabitCompletionsByHabitId(
            habitId: habitId,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
        ).called(2);
      },
    );

    test('ignores updates that do not contain the habit id', () async {
      stubCompletions([]);
      await readResults();

      // Emit an update for a different habit; callback short-circuits at
      // line 23 (affectedIds.contains(_habitId) == false), so no refetch.
      updateController.add({'some-other-habit'});
      await pumpEventQueue();

      verify(
        () => mockRepository.getHabitCompletionsByHabitId(
          habitId: habitId,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
      ).called(1);
    });

    test(
      're-emits a fresh AsyncData on a matching update even when the '
      'content is unchanged',
      () async {
        // `_fetch()` returns a brand new List instance every call, and the
        // controller compares with `latest != state.value` (reference
        // equality on List), so the `state = AsyncData(latest)` assignment
        // (line 26) runs even though the element contents are identical.
        final entities = [
          completion(
            id: 'c1',
            date: DateTime(2024, 3, 11),
            completionType: HabitCompletionType.success,
          ),
        ];
        stubCompletions(entities);
        final initial = await readResults();

        var emissions = 0;
        List<HabitResult>? lastEmitted;
        container.listen(
          habitCompletionControllerProvider(
            habitId: habitId,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          (_, next) {
            emissions++;
            lastEmitted = next.value;
          },
        );

        updateController.add({habitId});
        await pumpEventQueue();

        expect(emissions, 1);
        // A new list instance was emitted...
        expect(identical(lastEmitted, initial), isFalse);
        // ...but with equal element contents (HabitResult is Equatable).
        expect(lastEmitted, equals(initial));
        verify(
          () => mockRepository.getHabitCompletionsByHabitId(
            habitId: habitId,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
        ).called(2);
      },
    );
  });
}
