import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/habits/service/habit_auto_completion_service.dart';
import 'package:lotti/logic/signals/habit_rule_evaluator.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../logic/signals/signal_test_fixtures.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockJournalDb journalDb;
  late MockPersistenceLogic persistenceLogic;
  late MockEntitiesCacheService entitiesCache;
  late MockDomainLogger logger;
  late UpdateNotifications updateNotifications;
  late HabitAutoCompletionService service;

  // A Saturday afternoon; "yesterday" is Friday 2026-08-07.
  final now = DateTime(2026, 8, 8, 14, 30);
  final todayKey = DateTime.utc(2026, 8, 8);
  final yesterdayKey = DateTime.utc(2026, 8, 7);

  final waterHabit = habitFlossing.copyWith(
    id: 'habit-water',
    name: 'Drink water',
    autoCompleteRule: const AutoCompleteRule.measurable(
      dataTypeId: 'water',
      minimum: 500,
    ),
  );

  final written = <HabitCompletionData>[];
  final emitted = <HabitAutoCompletion>[];

  /// Completions already stored per habit id and day key, which the
  /// idempotency guard reads. The persistence stub appends what it writes.
  final stored = <String, Map<DateTime, JournalEntity>>{};
  var measurementReadCount = 0;

  void stubHabits(List<HabitDefinition> habits) => when(
    journalDb.getAllHabitDefinitions,
  ).thenAnswer((_) async => habits);

  void stubMeasurements(List<JournalEntity> entities) =>
      when(
        () => journalDb.getMeasurementsByType(
          type: any(named: 'type'),
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((invocation) async {
        measurementReadCount++;
        final start = invocation.namedArguments[#rangeStart] as DateTime;
        final end = invocation.namedArguments[#rangeEnd] as DateTime;
        return entities
            .where(
              (e) =>
                  !e.meta.dateFrom.isBefore(start) &&
                  e.meta.dateFrom.isBefore(end),
            )
            .toList();
      });

  setUp(() {
    journalDb = MockJournalDb();
    persistenceLogic = MockPersistenceLogic();
    entitiesCache = MockEntitiesCacheService();
    logger = MockDomainLogger();
    updateNotifications = UpdateNotifications();
    written.clear();
    emitted.clear();
    stored.clear();
    measurementReadCount = 0;

    when(() => entitiesCache.getDataTypeById('water')).thenReturn(
      measurableWater.copyWith(id: 'water', displayName: 'Water'),
    );
    when(() => entitiesCache.getHabitById(any())).thenReturn(null);
    when(
      () => journalDb.getHabitCompletionsByHabitId(
        habitId: any(named: 'habitId'),
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer((invocation) async {
      final habitId = invocation.namedArguments[#habitId] as String;
      final start = invocation.namedArguments[#rangeStart] as DateTime;
      final key = DateTime.utc(start.year, start.month, start.day);
      final entry = stored[habitId]?[key];
      return [?entry];
    });
    when(
      () => persistenceLogic.createHabitCompletionEntry(
        data: any(named: 'data'),
        habitDefinition: any(named: 'habitDefinition'),
      ),
    ).thenAnswer((invocation) async {
      final data = invocation.namedArguments[#data] as HabitCompletionData;
      written.add(data);
      final entry = JournalEntity.habitCompletion(
        meta: signalMeta(data.dateFrom),
        data: data,
      );
      stored.putIfAbsent(data.habitId, () => {})[DateTime.utc(
            data.dateFrom.year,
            data.dateFrom.month,
            data.dateFrom.day,
          )] =
          entry;
      return entry as HabitCompletionEntry;
    });
    stubMeasurements(const []);

    service = HabitAutoCompletionService(
      journalDb: journalDb,
      persistenceLogic: persistenceLogic,
      updateNotifications: updateNotifications,
      entitiesCache: entitiesCache,
      logger: logger,
    );
    service.completions.listen(emitted.add);
  });

  tearDown(() {
    service.dispose();
    updateNotifications.dispose();
  });

  /// Runs [body] under a fixed clock and fake time, flushing the service's
  /// async work before returning.
  void run(void Function(FakeAsync async) body, {DateTime? at}) {
    withClock(Clock.fixed(at ?? now), () {
      fakeAsync((async) {
        body(async);
        async.flushMicrotasks();
      }, initialTime: at ?? now);
    });
  }

  group('start', () {
    test('checks a satisfied habit off on launch as an auto completion', () {
      stubHabits([waterHabit]);
      stubMeasurements([measurementEntity(DateTime(2026, 8, 8, 9), 750)]);

      run((async) {
        service.start();
        async.flushMicrotasks();
        expect(service.autoCompletedToday, {'habit-water'});
      });

      expect(written, hasLength(1));
      final data = written.single;
      expect(data.habitId, 'habit-water');
      expect(data.completionType, HabitCompletionType.success);
      expect(data.source, HabitCompletionSource.auto);
      expect(data.autoCompleteReason, 'Water · 750');
      // Today is evaluated as of now, not at the end of the day.
      expect(data.dateFrom, now);

      expect(emitted.single.habit.id, 'habit-water');
      expect(emitted.single.day, todayKey);
      expect(emitted.single.isLate(now), isFalse);
    });

    test('an unmet threshold writes nothing', () {
      stubHabits([waterHabit]);
      stubMeasurements([measurementEntity(DateTime(2026, 8, 8, 9), 250)]);
      run((async) {
        service.start();
        async.flushMicrotasks();
        expect(service.autoCompletedToday, isEmpty);
      });
      expect(written, isEmpty);
      expect(emitted, isEmpty);
    });

    test('a converted choice measurable ignores its stale numeric bound', () {
      when(() => entitiesCache.getDataTypeById('water')).thenReturn(
        measurableHydration.copyWith(id: 'water'),
      );
      stubHabits([waterHabit]);
      final entry =
          measurementEntity(DateTime(2026, 8, 8, 9), 1) as MeasurementEntry;
      stubMeasurements([
        entry.copyWith(
          data: entry.data.copyWith(choiceId: hydrationClear.id),
        ),
      ]);

      run((async) => service.start());

      expect(written, hasLength(1));
      expect(written.single.autoCompleteReason, 'Hydration');
    });

    test('inactive habits and habits without a rule are not candidates', () {
      stubHabits([
        waterHabit.copyWith(active: false),
        waterHabit.copyWith(id: 'no-rule', autoCompleteRule: null),
        waterHabit.copyWith(id: 'deleted', deletedAt: DateTime(2026)),
      ]);
      stubMeasurements([measurementEntity(DateTime(2026, 8, 8, 9), 750)]);
      run((async) => service.start());
      expect(written, isEmpty);
      expect(measurementReadCount, 0);
    });
  });

  group('the existing-entry guard', () {
    test(
      'a day with a manual skip is left alone even when the data says done',
      () {
        stubHabits([waterHabit]);
        stubMeasurements([measurementEntity(DateTime(2026, 8, 8, 9), 750)]);
        stored['habit-water'] = {
          todayKey: habitCompletionEntity(
            DateTime(2026, 8, 8, 7),
            HabitCompletionType.skip,
            habitId: 'habit-water',
          ),
          yesterdayKey: habitCompletionEntity(
            DateTime(2026, 8, 7, 7),
            HabitCompletionType.success,
            habitId: 'habit-water',
          ),
        };
        run((async) => service.start());
        expect(written, isEmpty);
        // Nothing was even read: the guard runs before the window.
        expect(measurementReadCount, 0);
      },
    );

    test('the engine does not re-complete a day it already completed', () {
      stubHabits([waterHabit]);
      stubMeasurements([measurementEntity(DateTime(2026, 8, 8, 9), 750)]);
      run((async) {
        service.start();
        async.flushMicrotasks();
        // Its own write emits the habit id; a second relevant write follows.
        updateNotifications.notify({'water'});
        async.elapse(const Duration(seconds: 3));
      });
      expect(written, hasLength(1));
    });
  });

  group('journal updates', () {
    test(
      'a write to a series the rule reads re-evaluates after the debounce',
      () {
        stubHabits([waterHabit]);
        run((async) {
          service.start();
          async.flushMicrotasks();
          expect(written, isEmpty);

          stubMeasurements([measurementEntity(DateTime(2026, 8, 8, 12), 750)]);
          updateNotifications.notify({'water'});
          async.elapse(const Duration(milliseconds: 1500));
          expect(written, isEmpty, reason: 'still inside the debounce');
          async.elapse(const Duration(seconds: 1));
        });
        expect(written, hasLength(1));
      },
    );

    test('a burst of writes evaluates once', () {
      stubHabits([waterHabit]);
      run((async) {
        service.start();
        async.flushMicrotasks();
        final readsAfterStart = measurementReadCount;
        for (var i = 0; i < 5; i++) {
          updateNotifications.notify({'water'});
          async.elapse(const Duration(milliseconds: 500));
        }
        async.elapse(const Duration(seconds: 3));
        // One evaluation → two window reads (yesterday, today).
        expect(measurementReadCount - readsAfterStart, 2);
      });
    });

    test('a write to an unrelated series is ignored', () {
      stubHabits([waterHabit]);
      run((async) {
        service.start();
        async.flushMicrotasks();
        final readsAfterStart = measurementReadCount;
        updateNotifications.notify({'coffee', textEntryNotification});
        async.elapse(const Duration(seconds: 5));
        expect(measurementReadCount - readsAfterStart, 0);
      });
    });

    test('disposing mid-evaluation aborts before the write', () {
      stubHabits([waterHabit]);
      stubMeasurements([measurementEntity(DateTime(2026, 8, 8, 9), 750)]);
      run((async) {
        // start() kicks off the pass; dispose lands while its reads are
        // still pending microtasks.
        service
          ..start()
          ..dispose();
      });
      expect(written, isEmpty);
      expect(emitted, isEmpty);
    });

    test('nothing happens after dispose', () {
      stubHabits([waterHabit]);
      run((async) {
        service.start();
        async.flushMicrotasks();
        service.dispose();
        stubMeasurements([measurementEntity(DateTime(2026, 8, 8, 12), 750)]);
        updateNotifications.notify({'water'});
        async.elapse(const Duration(seconds: 5));
      });
      expect(written, isEmpty);
    });
  });

  group('late imports', () {
    test('data that arrives for yesterday completes yesterday, as late', () {
      stubHabits([waterHabit]);
      stubMeasurements([measurementEntity(DateTime(2026, 8, 7, 21), 900)]);
      run((async) {
        service.start();
        async.flushMicrotasks();
        // Yesterday's completion is not "today's" for the celebration guard.
        expect(service.autoCompletedToday, isEmpty);
      });

      expect(written, hasLength(1));
      // Written at the last instant of the day it counts for.
      expect(written.single.dateFrom, DateTime(2026, 8, 7, 23, 59, 59, 999));
      expect(emitted.single.day, yesterdayKey);
      expect(emitted.single.isLate(now), isTrue);
    });
  });

  group('midnight', () {
    test(
      'the day rolls over: a new pass runs and autoCompletedToday resets',
      () {
        stubHabits([waterHabit]);
        stubMeasurements([measurementEntity(DateTime(2026, 8, 8, 9), 750)]);
        final tomorrow = DateTime(2026, 8, 9, 0, 0, 2);
        run((async) {
          service.start();
          async.flushMicrotasks();
          expect(service.autoCompletedToday, {'habit-water'});
          final readsBefore = measurementReadCount;
          withClock(Clock.fixed(tomorrow), () {
            async
              ..elapse(const Duration(hours: 10))
              ..flushMicrotasks();
            expect(measurementReadCount, greaterThan(readsBefore));
            expect(service.autoCompletedToday, isEmpty);
          });
        });
      },
    );
  });

  group('describeReason', () {
    HabitLeafVerdict leaf(AutoCompleteRule rule, {num? value}) =>
        HabitLeafVerdict(
          rule: rule,
          satisfied: true,
          present: true,
          value: value,
        );

    test('names measurables from the cache, health types from the config, '
        'workouts by type, and joins several', () {
      final verdict = HabitRuleVerdict(
        satisfied: true,
        leaves: [
          leaf(
            const AutoCompleteRule.measurable(dataTypeId: 'water'),
            value: 750,
          ),
          leaf(
            const AutoCompleteRule.health(dataType: 'cumulative_step_count'),
            value: 7412,
          ),
          leaf(const AutoCompleteRule.workout(dataType: 'running')),
          const HabitLeafVerdict(
            rule: AutoCompleteRule.measurable(dataTypeId: 'skipped'),
            satisfied: false,
            present: false,
          ),
        ],
      );
      expect(
        service.describeReason(verdict),
        'Water · 750 · Steps · 7412 · running',
      );
    });

    test('a habit leaf resolves the habit name, falling back to its id', () {
      when(() => entitiesCache.getHabitById('habit-known')).thenReturn(
        habitFlossing.copyWith(id: 'habit-known', name: 'Floss'),
      );
      final verdict = HabitRuleVerdict(
        satisfied: true,
        leaves: [
          leaf(const AutoCompleteRule.habit(habitId: 'habit-known')),
          leaf(const AutoCompleteRule.habit(habitId: 'habit-gone')),
          // A composite never carries a value; if one ever ends up in the
          // leaf list it is skipped rather than named.
          leaf(const AutoCompleteRule.and(rules: [])),
          leaf(const AutoCompleteRule.or(rules: [])),
          leaf(const AutoCompleteRule.multiple(rules: [], successes: 1)),
        ],
      );
      expect(service.describeReason(verdict), 'Floss · habit-gone');
    });

    test('a choice measurable is named without its occurrence count', () {
      when(
        () => entitiesCache.getDataTypeById('hydration'),
      ).thenReturn(measurableHydration.copyWith(id: 'hydration'));
      final verdict = HabitRuleVerdict(
        satisfied: true,
        leaves: [
          leaf(
            const AutoCompleteRule.measurable(dataTypeId: 'hydration'),
            value: 1,
          ),
          leaf(
            const AutoCompleteRule.measurable(
              dataTypeId: 'hydration',
              title: 'Pee check',
            ),
            value: 2,
          ),
        ],
      );
      expect(service.describeReason(verdict), 'Hydration · Pee check');
    });

    test('an authored title wins over the resolved name', () {
      final verdict = HabitRuleVerdict(
        satisfied: true,
        leaves: [
          leaf(
            const AutoCompleteRule.measurable(
              dataTypeId: 'water',
              title: 'H₂O',
            ),
            value: 1.5,
          ),
        ],
      );
      expect(service.describeReason(verdict), 'H₂O · 1.5');
    });
  });

  test('a failing candidate lookup on an update is logged, not thrown', () {
    stubHabits([waterHabit]);
    run((async) {
      service.start();
      async.flushMicrotasks();
      when(journalDb.getAllHabitDefinitions).thenThrow(StateError('closed'));
      updateNotifications.notify({'water'});
      async.elapse(const Duration(seconds: 3));
      verify(
        () => logger.error(
          any(),
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'autoCompletion.onUpdate',
        ),
      ).called(1);
    });
    expect(written, isEmpty);
  });

  test('a failing read is logged, not thrown, and later runs still work', () {
    stubHabits([waterHabit]);
    when(
      () => journalDb.getMeasurementsByType(
        type: any(named: 'type'),
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenThrow(StateError('db closed'));
    run((async) {
      service.start();
      async.flushMicrotasks();
      verify(
        () => logger.error(
          any(),
          any<Object>(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'autoCompletion.run',
        ),
      ).called(1);
      stubMeasurements([measurementEntity(DateTime(2026, 8, 8, 12), 750)]);
      updateNotifications.notify({'water'});
      async.elapse(const Duration(seconds: 3));
    });
    expect(written, hasLength(1));
  });

  test('SignalWindow-level evaluation is what decides, not the raw read', () {
    // Two entries under the threshold individually but over it together.
    stubHabits([waterHabit]);
    stubMeasurements([
      measurementEntity(DateTime(2026, 8, 8, 9), 300),
      measurementEntity(DateTime(2026, 8, 8, 11), 300),
    ]);
    run((async) => service.start());
    expect(written, hasLength(1));
    expect(written.single.autoCompleteReason, 'Water · 600');
  });

  test('the evaluator receives a one-day window for the evaluated day', () {
    // Sanity check on the reader contract the engine relies on.
    stubHabits([waterHabit]);
    run((async) => service.start());
    final captured = verify(
      () => journalDb.getMeasurementsByType(
        type: 'water',
        rangeStart: captureAny(named: 'rangeStart'),
        rangeEnd: captureAny(named: 'rangeEnd'),
      ),
    ).captured;
    expect(captured, [
      DateTime(2026, 8, 7),
      DateTime(2026, 8, 8),
      DateTime(2026, 8, 8),
      DateTime(2026, 8, 9),
    ]);
  });

  test('HabitAutoCompletion carries the verdict', () {
    stubHabits([waterHabit]);
    stubMeasurements([measurementEntity(DateTime(2026, 8, 8, 9), 750)]);
    run((async) => service.start());
    expect(emitted.single.verdict.satisfied, isTrue);
    expect(emitted.single.verdict.leaves.single.value, 750);
    expect(emitted.single.entry.data.source, HabitCompletionSource.auto);
  });
}
