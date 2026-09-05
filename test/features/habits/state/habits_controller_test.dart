import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/habits/model/habit_completion_record.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/lockdown/domain/lockdown_state.dart';
import 'package:lotti/features/lockdown/state/lockdown_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/habits/habit_completion_resolution.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../lockdown/lockdown_test_utils.dart';
import '../habit_completion_record_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHabitsRepository mockRepository;
  late MockNavService mockNavService;
  late StreamController<List<HabitDefinition>> definitionsController;
  late StreamController<Set<String>> updateController;
  late StreamController<int> navIndexController;
  late ProviderContainer container;

  const habitsTabIndex = 3;
  final controllerNow = DateTime(2025, 12, 30, 10);

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
    HabitCompletionSource source = HabitCompletionSource.manual,
    String? autoCompleteReason,
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
        source: source,
        autoCompleteReason: autoCompleteReason,
      ),
    );
  }

  late TestLockdownController lockdown;

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
    // The unified Goals tab is absent in these harnesses; a disabled tab's
    // index getter reports -1 (delegate not in the enabled list).
    when(() => mockNavService.goalsIndex).thenReturn(-1);
    when(() => mockNavService.index).thenReturn(habitsTabIndex);
    when(
      mockNavService.getIndexStream,
    ).thenAnswer((_) => navIndexController.stream);

    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<NavService>(mockNavService);
      },
    );

    lockdown = TestLockdownController();
    container = ProviderContainer(
      overrides: [
        habitsRepositoryProvider.overrideWithValue(mockRepository),
        habitsNowProvider.overrideWithValue(() => controllerNow),
        lockdownControllerProvider.overrideWith(() => lockdown),
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

    test(
      'setSelectedCategoryIds replaces the whole selection in one write',
      () {
        final controller = container.read(habitsControllerProvider.notifier);
        expect(
          container.read(habitsControllerProvider).selectedCategoryIds,
          isEmpty,
        );

        controller.setSelectedCategoryIds({'cat-1'});
        expect(
          container.read(habitsControllerProvider).selectedCategoryIds,
          {'cat-1'},
        );

        // The deferred picker commits the full edited set, replacing (not
        // merging) the previous one.
        controller.setSelectedCategoryIds({'cat-2', 'cat-3'});
        expect(
          container.read(habitsControllerProvider).selectedCategoryIds,
          {'cat-2', 'cat-3'},
        );

        controller.setSelectedCategoryIds(<String>{});
        expect(
          container.read(habitsControllerProvider).selectedCategoryIds,
          isEmpty,
        );
      },
    );

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
    final controllerToday = controllerNow;
    final controllerTodayYmd = controllerNow.ymd;

    test(
      'autoCompletedToday names the engine-written habits with reasons',
      () async {
        final completions = [
          createCompletion(
            id: 'auto',
            habitId: 'habit-1',
            date: controllerToday,
            completionType: HabitCompletionType.success,
            source: HabitCompletionSource.auto,
            autoCompleteReason: 'Steps · 7412',
          ),
          createCompletion(
            id: 'manual',
            habitId: 'habit-2',
            date: controllerToday,
            completionType: HabitCompletionType.success,
          ),
          // Yesterday's auto completion is history, not today's pill.
          createCompletion(
            id: 'auto-yesterday',
            habitId: 'habit-2',
            date: controllerToday.subtract(const Duration(days: 1)),
            completionType: HabitCompletionType.success,
            source: HabitCompletionSource.auto,
            autoCompleteReason: 'Steps · 6001',
          ),
        ];
        when(
          () => mockRepository.getHabitCompletionsInRange(
            rangeStart: any(named: 'rangeStart'),
          ),
        ).thenAnswer((_) async => habitCompletionRecordsFrom(completions));

        container.read(habitsControllerProvider);
        await pumpEventQueue();
        definitionsController.add([testHabit1, testHabit2]);
        await pumpEventQueue();

        final state = container.read(habitsControllerProvider);
        expect(state.autoCompletedToday, {'habit-1': 'Steps · 7412'});
        expect(state.completedToday, {'habit-1', 'habit-2'});
      },
    );

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
      ).thenAnswer((_) async => habitCompletionRecordsFrom(completions));

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
      ).thenAnswer((_) async => habitCompletionRecordsFrom(completions));

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
        ).thenAnswer(
          (_) async => habitCompletionRecordsFrom(
            latestHabitCompletionsByDay(completions),
          ),
        );

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
      ).thenAnswer((_) async => habitCompletionRecordsFrom(completions));

      container.read(habitsControllerProvider);
      await pumpEventQueue();

      definitionsController.add([testHabit1]);
      await pumpEventQueue();

      final state = container.read(habitsControllerProvider);

      // Should have at least one short streak (4 days)
      expect(state.shortStreakCount, greaterThanOrEqualTo(1));
    });

    test('a skip prevents a habit from qualifying for a streak', () async {
      final completions = <JournalEntity>[
        for (var i = 0; i <= 3; i++)
          createCompletion(
            id: 'c$i',
            habitId: 'habit-1',
            date: controllerToday.subtract(Duration(days: i)),
            completionType: i == 1
                ? HabitCompletionType.skip
                : HabitCompletionType.success,
          ),
      ];

      when(
        () => mockRepository.getHabitCompletionsInRange(
          rangeStart: any(named: 'rangeStart'),
        ),
      ).thenAnswer((_) async => habitCompletionRecordsFrom(completions));

      container.read(habitsControllerProvider);
      await pumpEventQueue();
      definitionsController.add([testHabit1]);
      await pumpEventQueue();

      final state = container.read(habitsControllerProvider);
      expect(state.shortStreakCount, 0);
      expect(state.longStreakCount, 0);
    });
  });

  group('UpdateNotifications stream handling', () {
    test('a completion burst debounces the query itself', () {
      fakeAsync((async) {
        container.read(habitsControllerProvider);
        async.flushMicrotasks();
        clearInteractions(mockRepository);
        for (var i = 0; i < 100; i++) {
          updateController.add({habitCompletionNotification});
        }
        async.flushMicrotasks();
        verifyNever(
          () => mockRepository.getHabitCompletionsInRange(
            rangeStart: any(named: 'rangeStart'),
          ),
        );
        async.elapse(const Duration(milliseconds: 200));
        verify(
          () => mockRepository.getHabitCompletionsInRange(
            rangeStart: any(named: 'rangeStart'),
          ),
        ).called(1);
      });
    });

    test(
      'overlapping refreshes share one trailing read of the latest range',
      () {
        fakeAsync((async) {
          final controller = container.read(habitsControllerProvider.notifier);
          async.flushMicrotasks();
          definitionsController.add([testHabit1]);
          async.flushMicrotasks();
          final pending = <Completer<List<HabitCompletionRecord>>>[];
          final ranges = <DateTime>[];
          when(
            () => mockRepository.getHabitCompletionsInRange(
              rangeStart: any(named: 'rangeStart'),
            ),
          ).thenAnswer((call) {
            ranges.add(call.namedArguments[#rangeStart] as DateTime);
            final next = Completer<List<HabitCompletionRecord>>();
            pending.add(next);
            return next.future;
          });
          var finished = 0;
          controller.refreshNow().then((_) => finished++);
          for (var i = 0; i < 20; i++) {
            controller.setTimeSpan(30 + i).then((_) => finished++);
          }
          async.flushMicrotasks();
          expect(pending, hasLength(1), reason: 'only one SQLite read may run');
          pending.first.complete([
            HabitCompletionRecord(
              habitId: testHabit1.id,
              dateFrom: controllerNow,
              completionType: HabitCompletionType.success,
            ),
          ]);
          async.flushMicrotasks();
          expect(pending, hasLength(2));
          expect(
            ranges.last,
            controllerNow.dayAtMidnight.subtract(const Duration(days: 49)),
          );
          expect(
            finished,
            0,
            reason: 'callers wait until the latest request lands',
          );
          expect(
            container.read(habitsControllerProvider).successfulToday,
            isEmpty,
            reason:
                'an obsolete result must not publish during the trailing read',
          );
          pending.last.complete([
            HabitCompletionRecord(
              habitId: testHabit1.id,
              dateFrom: controllerNow,
              completionType: HabitCompletionType.fail,
            ),
          ]);
          async.flushMicrotasks();
          expect(finished, 21);
          expect(
            container
                .read(habitsControllerProvider)
                .failedByDay[controllerNow.ymd],
            {testHabit1.id},
          );
          expect(container.read(habitsControllerProvider).timeSpanDays, 49);
        });
      },
    );

    test('a notification during the initial read is not lost', () {
      fakeAsync((async) {
        final pending = <Completer<List<HabitCompletionRecord>>>[];
        when(
          () => mockRepository.getHabitCompletionsInRange(
            rangeStart: any(named: 'rangeStart'),
          ),
        ).thenAnswer((_) {
          final next = Completer<List<HabitCompletionRecord>>();
          pending.add(next);
          return next.future;
        });
        container.read(habitsControllerProvider);
        async.flushMicrotasks();
        updateController.add({habitCompletionNotification});
        async.elapse(const Duration(milliseconds: 200));
        expect(pending, hasLength(1));
        pending.first.complete([]);
        async.flushMicrotasks();
        expect(pending, hasLength(2));
        pending.last.complete([]);
        async.flushMicrotasks();
      });
    });

    test('a failed read releases the drain for a later refresh', () {
      fakeAsync((async) {
        final controller = container.read(habitsControllerProvider.notifier);
        async.flushMicrotasks();
        final failure = StateError('database unavailable');
        var attempts = 0;
        when(
          () => mockRepository.getHabitCompletionsInRange(
            rangeStart: any(named: 'rangeStart'),
          ),
        ).thenAnswer((_) async {
          if (attempts++ == 0) throw failure;
          return [];
        });
        Object? caught;
        controller.refreshNow().then<void>(
          (_) {},
          onError: (Object error) {
            caught = error;
          },
        );
        async.flushMicrotasks();
        expect(caught, same(failure));
        var recovered = false;
        controller.refreshNow().then((_) => recovered = true);
        async.flushMicrotasks();
        expect(recovered, isTrue);
        expect(attempts, 2);
      });
    });

    test('an invalidated drain cannot overwrite its replacement', () {
      fakeAsync((async) {
        final controller = container.read(habitsControllerProvider.notifier);
        async.flushMicrotasks();
        final pending = <Completer<List<HabitCompletionRecord>>>[];
        when(
          () => mockRepository.getHabitCompletionsInRange(
            rangeStart: any(named: 'rangeStart'),
          ),
        ).thenAnswer((_) {
          final next = Completer<List<HabitCompletionRecord>>();
          pending.add(next);
          return next.future;
        });
        controller.refreshNow();
        updateController.add({habitCompletionNotification});
        async.flushMicrotasks();
        container
          ..invalidate(habitsControllerProvider)
          ..read(habitsControllerProvider);
        async.flushMicrotasks();
        definitionsController.add([testHabit1]);
        async.flushMicrotasks();
        expect(pending, hasLength(2));
        pending.last.complete([]);
        async.flushMicrotasks();
        pending.first.complete([
          HabitCompletionRecord(
            habitId: testHabit1.id,
            dateFrom: controllerNow,
            completionType: HabitCompletionType.success,
          ),
        ]);
        async.flushMicrotasks();
        expect(
          container.read(habitsControllerProvider).successfulToday,
          isEmpty,
        );
        expect(
          async.pendingTimers,
          isEmpty,
          reason: 'invalidation cancels the queued notification debounce',
        );
      });
    });

    test(
      'invalidation before startup does not duplicate the update listener',
      () {
        fakeAsync((async) {
          container
            ..read(habitsControllerProvider)
            ..invalidate(habitsControllerProvider)
            ..read(habitsControllerProvider);
          async.flushMicrotasks();
          verify(() => mockRepository.updateStream).called(1);
          verify(
            () => mockRepository.getHabitCompletionsInRange(
              rangeStart: any(named: 'rangeStart'),
            ),
          ).called(1);
        });
      },
    );

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

    test('a DIRECT switch between the Habits and Goals tabs refetches, '
        'even though both are habits-rendering surfaces', () {
      const goalsTabIndex = 2;
      when(() => mockNavService.goalsIndex).thenReturn(goalsTabIndex);
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

        // The controller booted with the Habits tab active
        // (index == habitsIndex), so `_wasHabitsActive` is already true —
        // without the last-index tracking, jumping straight to the Goals
        // tab would be swallowed as "still active" and midnight/showFrom
        // boundaries crossed while parked on Habits would go stale.
        navIndexController.add(goalsTabIndex);
        async.flushMicrotasks();

        verify(
          () => mockRepository.getHabitCompletionsInRange(
            rangeStart: any(named: 'rangeStart'),
          ),
        ).called(greaterThanOrEqualTo(1));

        // A repeat emission of the SAME index (emitState fires on every tab
        // tap) must NOT refetch again.
        clearInteractions(mockRepository);
        navIndexController.add(goalsTabIndex);
        async.flushMicrotasks();
        verifyNever(
          () => mockRepository.getHabitCompletionsInRange(
            rangeStart: any(named: 'rangeStart'),
          ),
        );
      });
    });

    test('refreshNow refetches completions and rebuckets on demand — the '
        'day-boundary hook for mounted habits surfaces', () {
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

        container.read(habitsControllerProvider.notifier).refreshNow();
        async.flushMicrotasks();

        verify(
          () => mockRepository.getHabitCompletionsInRange(
            rangeStart: any(named: 'rangeStart'),
          ),
        ).called(1);
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

  group('lockdown', () {
    test('clamps the category filter to the locked set and recomputes on '
        'enter and exit', () async {
      container.read(habitsControllerProvider);
      await pumpEventQueue();
      definitionsController.add([testHabit1, testHabit2]);
      await pumpEventQueue();

      Set<String> visibleIds() {
        final state = container.read(habitsControllerProvider);
        return {
          ...state.openNow.map((h) => h.id),
          ...state.pendingLater.map((h) => h.id),
          ...state.completed.map((h) => h.id),
        };
      }

      expect(visibleIds(), {'habit-1', 'habit-2'});

      // An empty user filter under lockdown is the locked set, never "all".
      lockdown.current = const LockdownState(categoryIds: {'cat-2'});
      await pumpEventQueue();
      expect(visibleIds(), {'habit-2'});

      // A user filter outside the lock cannot widen it either, and the raw
      // selection is left as the user set it.
      container.read(habitsControllerProvider.notifier).setSelectedCategoryIds({
        'cat-1',
      });
      await pumpEventQueue();
      expect(visibleIds(), {'habit-2'});
      expect(
        container.read(habitsControllerProvider).selectedCategoryIds,
        {'cat-1'},
      );

      lockdown.current = LockdownState.inactive;
      await pumpEventQueue();
      expect(visibleIds(), {'habit-1'});
    });
  });
}
