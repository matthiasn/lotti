import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/habits/state/habit_signal_status_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../logic/signals/signal_test_fixtures.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  late MockJournalDb journalDb;
  late MockEntitiesCacheService cache;
  late UpdateNotifications updates;
  late ProviderContainer container;

  final now = DateTime(2026, 8, 8, 14, 30);
  final todayKey = DateTime.utc(2026, 8, 8);
  final habit = habitFlossing.copyWith(
    id: 'water-habit',
    autoCompleteRule: const AutoCompleteRule.measurable(
      dataTypeId: 'water',
      minimum: 500,
    ),
  );

  var measurements = <DateTime, num>{};

  setUp(() async {
    journalDb = MockJournalDb();
    cache = MockEntitiesCacheService();
    updates = UpdateNotifications();
    measurements = {DateTime(2026, 8, 8, 9): 250};
    when(() => cache.getHabitById(habit.id)).thenReturn(habit);
    when(() => cache.getHabitById('plain')).thenReturn(habitFlossing);
    when(
      () => journalDb.getMeasurementsByType(
        type: any(named: 'type'),
        rangeStart: any(named: 'rangeStart'),
        rangeEnd: any(named: 'rangeEnd'),
      ),
    ).thenAnswer(
      (_) async => [
        for (final e in measurements.entries) measurementEntity(e.key, e.value),
      ],
    );
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(journalDb)
          ..unregister<UpdateNotifications>()
          ..registerSingleton<UpdateNotifications>(updates)
          ..registerSingleton<EntitiesCacheService>(cache);
      },
    );
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await updates.dispose();
    await tearDownTestGetIt();
  });

  test('a habit without a rule has no status', () async {
    final status = await withClock(
      Clock.fixed(now),
      () => container.read(habitSignalStatusProvider('plain').future),
    );
    expect(status, isNull);
  });

  test('reads a two-week window and evaluates today', () async {
    final status = await withClock(
      Clock.fixed(now),
      () => container.read(habitSignalStatusProvider(habit.id).future),
    );
    expect(status, isNotNull);
    expect(status!.today, todayKey);
    expect(status.days, hasLength(14));
    expect(status.days.first, DateTime.utc(2026, 7, 26));
    expect(status.days.last, todayKey);
    expect(status.verdict.satisfied, isFalse);
    expect(status.verdict.leaves.single.value, 250);
  });

  test(
    'a converted choice measurable ignores its stale numeric bound',
    () async {
      when(() => cache.getDataTypeById('water')).thenReturn(
        measurableHydration.copyWith(id: 'water'),
      );
      measurements = {DateTime(2026, 8, 8, 9): 1};

      final status = await withClock(
        Clock.fixed(now),
        () => container.read(habitSignalStatusProvider(habit.id).future),
      );

      final rule = status!.rule as AutoCompleteRuleMeasurable;
      expect(rule.minimum, isNull);
      expect(rule.maximum, isNull);
      expect(status.verdict.satisfied, isTrue);
    },
  );

  test('a write to the measurable refreshes in place, never via loading', () {
    withClock(Clock.fixed(now), () {
      fakeAsync((async) {
        final sub = container.listen(
          habitSignalStatusProvider(habit.id),
          (_, _) {},
        );
        async.flushMicrotasks();
        expect(
          container.read(habitSignalStatusProvider(habit.id)).value,
          isNotNull,
        );
        measurements[DateTime(2026, 8, 8, 12)] = 500;
        updates.notify({'water'});
        // The batcher emits after 100 ms; then the reload lands.
        async.elapse(const Duration(milliseconds: 150));
        final state = container.read(habitSignalStatusProvider(habit.id));
        expect(state.isLoading, isFalse);
        expect(state.value!.verdict.satisfied, isTrue);
        expect(state.value!.verdict.leaves.single.value, 750);
        sub.close();
      }, initialTime: now);
    });
  });

  test('an unrelated write does not re-read', () {
    withClock(Clock.fixed(now), () {
      fakeAsync((async) {
        final sub = container.listen(
          habitSignalStatusProvider(habit.id),
          (_, _) {},
        );
        async.flushMicrotasks();
        clearInteractions(journalDb);
        updates.notify({'coffee'});
        async.elapse(const Duration(milliseconds: 150));
        verifyNever(
          () => journalDb.getMeasurementsByType(
            type: any(named: 'type'),
            rangeStart: any(named: 'rangeStart'),
            rangeEnd: any(named: 'rangeEnd'),
          ),
        );
        sub.close();
      }, initialTime: now);
    });
  });

  test('refresh after the rule was removed yields no status', () async {
    await withClock(Clock.fixed(now), () async {
      final sub = container.listen(
        habitSignalStatusProvider(habit.id),
        (_, _) {},
      );
      await container.read(habitSignalStatusProvider(habit.id).future);
      when(
        () => cache.getHabitById(habit.id),
      ).thenReturn(habit.copyWith(autoCompleteRule: null));
      await container
          .read(habitSignalStatusProvider(habit.id).notifier)
          .refresh();
      expect(container.read(habitSignalStatusProvider(habit.id)).value, isNull);
      sub.close();
    });
  });
}
