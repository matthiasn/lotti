import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import '../test_data/test_data.dart';
import '../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TimeService Tests', () {
    late TimeService timeService;

    setUp(() {
      timeService = TimeService();
    });

    tearDown(() async {
      await timeService.stop();
    });

    test('getCurrent returns null initially', () {
      expect(timeService.getCurrent(), isNull);
    });

    test('start sets current entity and begins periodic updates', () async {
      final entity = testTextEntry;

      await timeService.start(entity, null);

      expect(timeService.getCurrent(), isNotNull);
      expect(timeService.getCurrent()?.id, entity.id);
    });

    test('start with linked entity stores linkedFrom', () async {
      final entity = testTextEntry;
      final linkedEntity = testImageEntry;

      await timeService.start(entity, linkedEntity);

      expect(timeService.linkedFrom, linkedEntity);
    });

    test('getStream emits periodic updates', () {
      fakeAsync((async) {
        final entity = testTextEntry;
        final stream = timeService.getStream();

        List<JournalEntity?>? emissions;
        stream.take(3).toList().then((e) => emissions = e);

        timeService.start(entity, null);

        // Drive three ticks of the 1s periodic timer.
        async
          ..elapse(const Duration(seconds: 3))
          ..flushMicrotasks();

        expect(emissions, isNotNull);
        expect(emissions, hasLength(3));
        for (final emission in emissions!) {
          expect(emission?.id, entity.id);
        }
      });
    });

    test('stream updates contain updated dateTo timestamp', () {
      fakeAsync((async) {
        final entity = testTextEntry;
        final stream = timeService.getStream();

        final startTime = DateTime(2026, 9, 19, 10, 30);
        List<JournalEntity?>? emissions;
        stream.take(2).toList().then((e) => emissions = e);

        withClock(Clock(() => startTime.add(async.elapsed)), () {
          timeService.start(entity, null);

          async
            ..elapse(const Duration(seconds: 2))
            ..flushMicrotasks();
        });

        expect(
          emissions?.map((emission) => emission?.meta.dateTo),
          [
            startTime.add(const Duration(seconds: 1)),
            startTime.add(const Duration(seconds: 2)),
          ],
        );
      });
    });

    test(
      'stop cancels periodic work and emits exactly one terminal null',
      () async {
        final emissions = <JournalEntity?>[];
        final start = DateTime(2026, 9, 20, 10);
        final async = FakeAsync(initialTime: start);
        late StreamSubscription<JournalEntity?> subscription;
        try {
          async
            ..run((_) {
              subscription = timeService.getStream().listen(emissions.add);
              unawaited(timeService.start(testTextEntry, testImageEntry));
            })
            ..elapse(const Duration(seconds: 1));
          expect(emissions, [
            testTextEntry.copyWith(
              meta: testTextEntry.meta.copyWith(
                dateTo: start.add(const Duration(seconds: 1)),
              ),
            ),
          ]);
          expect(async.periodicTimerCount, 1);
          // Stream.periodic cancellation uses an SDK-owned future. Await it
          // outside the fake zone; timer creation and ticks stay fake.
          await timeService.stop();
          async.flushMicrotasks();
          expect(timeService.getCurrent(), isNull);
          expect(timeService.linkedFrom, isNull);
          expect(emissions.last, isNull);
          expect(emissions, hasLength(2));
          expect(async.periodicTimerCount, 0);
          await timeService.stop();
          async.elapse(const Duration(seconds: 5));
          expect(emissions, hasLength(2));
        } finally {
          await timeService.stop();
          await subscription.cancel();
          async.flushMicrotasks();
        }
      },
    );

    test(
      'replacement cancels the old cadence and ticks only the new entry',
      () async {
        final emissions = <JournalEntity?>[];
        final start = DateTime(2026, 9, 20, 10);
        final async = FakeAsync(initialTime: start);
        late StreamSubscription<JournalEntity?> subscription;
        try {
          async
            ..run((_) {
              subscription = timeService.getStream().listen(emissions.add);
              unawaited(timeService.start(testTextEntry, testImageEntry));
            })
            ..elapse(const Duration(milliseconds: 1250));
          expect(emissions.map((entry) => entry?.id), [testTextEntry.id]);

          var replaced = false;
          async.run((_) {
            unawaited(
              timeService
                  .start(testImageEntry, testTextEntry)
                  .then((_) => replaced = true),
            );
            async.flushMicrotasks();
          });
          // Let the SDK's cancellation completion run, then drain the
          // replacement's fake-zone continuation without advancing time.
          await Future<void>.microtask(() {});
          async.flushMicrotasks();
          expect(replaced, isTrue);
          expect(timeService.getCurrent(), testImageEntry);
          expect(timeService.linkedFrom, testTextEntry);
          expect(emissions.map((entry) => entry?.id), [
            testTextEntry.id,
            null,
          ]);
          expect(async.periodicTimerCount, 1);
          emissions.clear();

          // Cross the old timer's next deadline, but stop just short of
          // the new timer's first tick at 2.250 seconds.
          async.elapse(const Duration(milliseconds: 999));
          expect(emissions, isEmpty);
          async
            ..elapse(const Duration(milliseconds: 1))
            ..elapse(const Duration(seconds: 2));
          expect(emissions, [
            for (final milliseconds in [2250, 3250, 4250])
              testImageEntry.copyWith(
                meta: testImageEntry.meta.copyWith(
                  dateTo: start.add(Duration(milliseconds: milliseconds)),
                ),
              ),
          ]);

          await timeService.stop();
          async.flushMicrotasks();
          expect(emissions.last, isNull);
          expect(emissions, hasLength(4));
          async.elapse(const Duration(seconds: 3));
          expect(emissions, hasLength(4));
          expect(async.periodicTimerCount, 0);
        } finally {
          await timeService.stop();
          await subscription.cancel();
          async.flushMicrotasks();
        }
      },
    );

    test('updateCurrent updates entity when IDs match', () async {
      final entity = testTextEntry;

      await timeService.start(entity, null);

      final updatedEntity = entity.copyWith(
        meta: entity.meta.copyWith(starred: true),
      );

      timeService.updateCurrent(updatedEntity);

      final current = timeService.getCurrent();
      expect(current?.meta.starred, true);
    });

    test('updateCurrent does not update when IDs do not match', () async {
      final entity1 = testTextEntry;
      final entity2 = testImageEntry;

      await timeService.start(entity1, null);

      timeService.updateCurrent(entity2);

      final current = timeService.getCurrent();
      expect(current?.id, entity1.id);
    });

    test('updateCurrent does nothing when current is null', () {
      final entity = testTextEntry;

      timeService.updateCurrent(entity);

      expect(timeService.getCurrent(), isNull);
    });

    test('stop does nothing when current is null', () async {
      await timeService.stop();

      expect(timeService.getCurrent(), isNull);
    });

    test('multiple start-stop cycles work correctly', () async {
      final entity = testTextEntry;

      // First cycle
      await timeService.start(entity, null);
      expect(timeService.getCurrent(), isNotNull);
      await timeService.stop();
      expect(timeService.getCurrent(), isNull);

      // Second cycle
      await timeService.start(entity, null);
      expect(timeService.getCurrent(), isNotNull);
      await timeService.stop();
      expect(timeService.getCurrent(), isNull);
    });

    test('getStream can be called multiple times', () {
      fakeAsync((async) {
        final stream1 = timeService.getStream();
        final stream2 = timeService.getStream();

        expect(stream1, isNotNull);
        expect(stream2, isNotNull);

        List<JournalEntity?>? emissions1;
        List<JournalEntity?>? emissions2;
        stream1.take(2).toList().then((e) => emissions1 = e);
        stream2.take(2).toList().then((e) => emissions2 = e);

        timeService.start(testTextEntry, null);

        async
          ..elapse(const Duration(seconds: 2))
          ..flushMicrotasks();

        // Both should have received 2 emissions
        expect(emissions1, isNotNull);
        expect(emissions2, isNotNull);
        expect(emissions1, hasLength(2));
        expect(emissions2, hasLength(2));

        timeService.stop();
      });
    });
  });

  // Starting a new timer while one is already running implicitly stops the
  // old one. The outgoing entry must be persisted with its real stop time,
  // otherwise it keeps the stale `dateTo` it was created with (≈ its start
  // time) and the whole elapsed span is lost.
  group('finalizes the outgoing timer when replaced', () {
    setUp(() async {
      // Registers a real DomainLogger so the finalize error path can log.
      await setUpTestGetIt();
    });

    tearDown(tearDownTestGetIt);

    test('persists the outgoing entry once when a new timer replaces a '
        'running one', () async {
      final finalized = <JournalEntity>[];
      final service = TimeService(
        persistTimerStop: (entry) async => finalized.add(entry),
      );
      addTearDown(service.stop);

      await service.start(testTextEntry, null);
      expect(finalized, isEmpty, reason: 'nothing to finalize on first start');

      await service.start(testImageEntry, null);

      expect(finalized.map((e) => e.id), [testTextEntry.id]);
      expect(service.getCurrent()?.id, testImageEntry.id);
    });

    test('does not persist when starting the very first timer', () async {
      final finalized = <JournalEntity>[];
      final service = TimeService(
        persistTimerStop: (entry) async => finalized.add(entry),
      );
      addTearDown(service.stop);

      await service.start(testTextEntry, null);

      expect(finalized, isEmpty);
    });

    test(
      'does not persist on an explicit stop (already saved by the caller)',
      () async {
        // The Stop button persists `dateTo = now` via EntryController.save
        // before calling stop(); finalizing again here would double-write.
        final finalized = <JournalEntity>[];
        final service = TimeService(
          persistTimerStop: (entry) async => finalized.add(entry),
        );

        await service.start(testTextEntry, null);
        await service.stop();

        expect(finalized, isEmpty);
      },
    );

    test('a failing finalize still starts the replacing timer', () async {
      final service = TimeService(
        persistTimerStop: (_) async => throw Exception('db unavailable'),
      );
      addTearDown(service.stop);

      await service.start(testTextEntry, null);
      await service.start(testImageEntry, null);

      expect(service.getCurrent()?.id, testImageEntry.id);
    });
  });

  // While a timer runs its entry is saved on a fixed cadence, so the
  // calendar shows the session growing instead of a gap until it stops.
  group('autosaves the running timer', () {
    late MockDomainLogger domainLogger;

    setUp(() async {
      domainLogger = MockDomainLogger();
      when(
        () => domainLogger.error(
          any(),
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});
      await setUpTestGetIt(
        additionalSetup: () => getIt
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(domainLogger),
      );
    });

    tearDown(tearDownTestGetIt);

    test('the default cadence is five minutes', () {
      expect(runningTimerAutosaveInterval, const Duration(minutes: 5));
    });

    test('saves the running entry once per default interval', () async {
      final autosaved = <String>[];
      final service = TimeService(
        autosave: (entry) async => autosaved.add(entry.meta.id),
      );
      final async = FakeAsync();
      try {
        async
          ..run((_) => unawaited(service.start(testTextEntry, testTask)))
          ..elapse(const Duration(minutes: 4, seconds: 59));
        expect(autosaved, isEmpty, reason: 'no save before the first interval');

        async.elapse(const Duration(seconds: 1));
        expect(autosaved, [testTextEntry.meta.id]);

        async.elapse(const Duration(minutes: 10));
        expect(autosaved, [
          testTextEntry.meta.id,
          testTextEntry.meta.id,
          testTextEntry.meta.id,
        ]);
      } finally {
        await service.stop();
        async.flushMicrotasks();
      }
    });

    test('honours an injected interval', () async {
      final autosaved = <String>[];
      final service = TimeService(
        autosave: (entry) async => autosaved.add(entry.meta.id),
        autosaveInterval: const Duration(seconds: 30),
      );
      final async = FakeAsync();
      try {
        async
          ..run((_) => unawaited(service.start(testTextEntry, null)))
          ..elapse(const Duration(seconds: 90));
        expect(autosaved, hasLength(3));
      } finally {
        await service.stop();
        async.flushMicrotasks();
      }
    });

    test('stop cancels the cadence, so a stopped timer is never saved '
        'again', () async {
      final autosaved = <String>[];
      final service = TimeService(
        autosave: (entry) async => autosaved.add(entry.meta.id),
      );
      final async = FakeAsync();
      try {
        async
          ..run((_) => unawaited(service.start(testTextEntry, null)))
          ..elapse(const Duration(minutes: 5));
        expect(autosaved, hasLength(1));
        expect(async.periodicTimerCount, 2, reason: 'ticker plus autosave');

        await service.stop();
        async.flushMicrotasks();
        expect(async.periodicTimerCount, 0);

        async.elapse(const Duration(minutes: 30));
        expect(autosaved, hasLength(1));
      } finally {
        await service.stop();
        async.flushMicrotasks();
      }
    });

    test(
      'a replacing timer restarts the cadence for the new entry only',
      () async {
        final autosaved = <String>[];
        final service = TimeService(
          autosave: (entry) async => autosaved.add(entry.meta.id),
        );
        final async = FakeAsync();
        try {
          async
            ..run((_) => unawaited(service.start(testTextEntry, null)))
            ..elapse(const Duration(minutes: 3));

          async.run((_) {
            unawaited(service.start(testImageEntry, null));
            async.flushMicrotasks();
          });
          // Let the SDK's cancellation of the old ticker complete, then drain
          // the replacement's continuation without advancing time.
          await Future<void>.microtask(() {});
          async.flushMicrotasks();
          expect(service.getCurrent()?.id, testImageEntry.id);
          expect(async.periodicTimerCount, 2);

          // The old cadence would have fired at minute 5; the new one is due
          // five minutes after the replacement, at minute 8.
          async.elapse(const Duration(minutes: 4, seconds: 59));
          expect(autosaved, isEmpty);
          async.elapse(const Duration(seconds: 1));
          expect(autosaved, [testImageEntry.meta.id]);
        } finally {
          await service.stop();
          async.flushMicrotasks();
        }
      },
    );

    test('a failing save is logged and the cadence keeps going', () async {
      var attempts = 0;
      final error = Exception('db unavailable');
      final service = TimeService(
        autosave: (_) async {
          attempts++;
          throw error;
        },
      );
      final async = FakeAsync();
      try {
        async
          ..run((_) => unawaited(service.start(testTextEntry, null)))
          ..elapse(const Duration(minutes: 5));

        verify(
          () => domainLogger.error(
            LogDomain.persistence,
            error,
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'autosaveRunningTimer',
          ),
        ).called(1);
        expect(service.getCurrent()?.id, testTextEntry.id);

        async.elapse(const Duration(minutes: 5));
        expect(attempts, 2);
      } finally {
        await service.stop();
        async.flushMicrotasks();
      }
    });

    test('schedules no cadence without an autosave callback', () async {
      final service = TimeService();
      final async = FakeAsync();
      try {
        async
          ..run((_) => unawaited(service.start(testTextEntry, null)))
          ..flushMicrotasks();
        expect(async.periodicTimerCount, 1, reason: 'only the 1s ticker');
      } finally {
        await service.stop();
        async.flushMicrotasks();
      }
    });
  });
}
