import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/outbox/outbox_daily_volume.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/state/sync_activity_signaler.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

/// Stubs [MockSyncDatabase.getDailyOutboxVolume] with the given [volumes].
void _stubDailyVolumes(
  MockSyncDatabase mock, {
  required List<OutboxDailyVolume> volumes,
}) {
  when(
    () => mock.getDailyOutboxVolume(days: kOutboxVolumeDays),
  ).thenAnswer((_) async => volumes);
}

void main() {
  group('OutboxStateController', () {
    late MockJournalDb mockDb;
    late MockSyncDatabase mockSyncDb;
    late StreamController<bool> flagStreamController;
    late StreamController<int> countStreamController;
    late ProviderContainer container;

    setUp(() {
      mockDb = MockJournalDb();
      mockSyncDb = MockSyncDatabase();
      flagStreamController = StreamController<bool>.broadcast();
      countStreamController = StreamController<int>.broadcast();

      when(
        () => mockDb.watchConfigFlag(enableMatrixFlag),
      ).thenAnswer((_) => flagStreamController.stream);

      when(
        () => mockSyncDb.watchOutboxCount(),
      ).thenAnswer((_) => countStreamController.stream);

      container = ProviderContainer(
        overrides: [
          journalDbProvider.overrideWithValue(mockDb),
          syncDatabaseProvider.overrideWithValue(mockSyncDb),
        ],
      );
    });

    tearDown(() async {
      await flagStreamController.close();
      await countStreamController.close();
      container.dispose();
    });

    group('outboxConnectionStateProvider', () {
      test('initial state is loading', () {
        final state = container.read(outboxConnectionStateProvider);
        expect(
          state,
          const AsyncValue<OutboxConnectionState>.loading(),
        );
      });

      test('emits online when flag is true', () {
        fakeAsync((async) {
          final states = <AsyncValue<OutboxConnectionState>>[];
          container.listen(
            outboxConnectionStateProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          flagStreamController.add(true);
          async.flushMicrotasks();

          expect(states.last.hasValue, isTrue);
          expect(states.last.value, OutboxConnectionState.online);
        });
      });

      test('emits disabled when flag is false', () {
        fakeAsync((async) {
          final states = <AsyncValue<OutboxConnectionState>>[];
          container.listen(
            outboxConnectionStateProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          flagStreamController.add(false);
          async.flushMicrotasks();

          expect(states.last.hasValue, isTrue);
          expect(states.last.value, OutboxConnectionState.disabled);
        });
      });

      test('transitions from online to disabled', () {
        fakeAsync((async) {
          final states = <AsyncValue<OutboxConnectionState>>[];
          container.listen(
            outboxConnectionStateProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          // Start online
          flagStreamController.add(true);
          async.flushMicrotasks();
          expect(states.last.value, OutboxConnectionState.online);

          // Transition to disabled
          flagStreamController.add(false);
          async.flushMicrotasks();
          expect(states.last.value, OutboxConnectionState.disabled);
        });
      });

      test('transitions from disabled to online', () {
        fakeAsync((async) {
          final states = <AsyncValue<OutboxConnectionState>>[];
          container.listen(
            outboxConnectionStateProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          // Start disabled
          flagStreamController.add(false);
          async.flushMicrotasks();
          expect(states.last.value, OutboxConnectionState.disabled);

          // Transition to online
          flagStreamController.add(true);
          async.flushMicrotasks();
          expect(states.last.value, OutboxConnectionState.online);
        });
      });

      test('handles stream errors', () async {
        final error = Exception('Database error');
        final completer = Completer<void>();

        container.listen(
          outboxConnectionStateProvider,
          (_, next) {
            if (next.hasError && !completer.isCompleted) {
              completer.complete();
            }
          },
        );

        flagStreamController.addError(error);

        await completer.future.timeout(const Duration(milliseconds: 100));

        final state = container.read(outboxConnectionStateProvider);
        expect(state.hasError, isTrue);
      });
    });

    group('outboxPendingCountProvider', () {
      test('initial state is loading', () {
        final state = container.read(outboxPendingCountProvider);
        expect(state, const AsyncValue<int>.loading());
      });

      test('emits count from database stream', () {
        fakeAsync((async) {
          final states = <AsyncValue<int>>[];
          container.listen(
            outboxPendingCountProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          countStreamController.add(5);
          async.flushMicrotasks();

          expect(states.last.hasValue, isTrue);
          expect(states.last.value, 5);
        });
      });

      test('emits zero when no pending items', () {
        fakeAsync((async) {
          final states = <AsyncValue<int>>[];
          container.listen(
            outboxPendingCountProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          countStreamController.add(0);
          async.flushMicrotasks();

          expect(states.last.hasValue, isTrue);
          expect(states.last.value, 0);
        });
      });

      test('updates count when stream emits new value', () {
        fakeAsync((async) {
          final states = <AsyncValue<int>>[];
          container.listen(
            outboxPendingCountProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          countStreamController.add(5);
          async.flushMicrotasks();
          expect(states.last.value, 5);

          countStreamController.add(3);
          async.flushMicrotasks();
          expect(states.last.value, 3);

          countStreamController.add(0);
          async.flushMicrotasks();
          expect(states.last.value, 0);
        });
      });

      test('handles large count values', () {
        fakeAsync((async) {
          final states = <AsyncValue<int>>[];
          container.listen(
            outboxPendingCountProvider,
            (_, next) => states.add(next),
            fireImmediately: true,
          );

          async.flushMicrotasks();

          countStreamController.add(999999);
          async.flushMicrotasks();

          expect(states.last.hasValue, isTrue);
          expect(states.last.value, 999999);
        });
      });

      test('handles stream errors', () async {
        final error = Exception('Sync database error');
        final completer = Completer<void>();

        container.listen(
          outboxPendingCountProvider,
          (_, next) {
            if (next.hasError && !completer.isCompleted) {
              completer.complete();
            }
          },
        );

        countStreamController.addError(error);

        await completer.future.timeout(const Duration(milliseconds: 100));

        final state = container.read(outboxPendingCountProvider);
        expect(state.hasError, isTrue);
      });
    });

    group('outboxDailyVolumeProvider', () {
      test('maps OutboxDailyVolume to Observation with KB values', () async {
        final volumes = [
          OutboxDailyVolume(
            date: DateTime(2024, 3, 15),
            totalBytes: 1024,
            itemCount: 2,
          ),
          OutboxDailyVolume(
            date: DateTime(2024, 3, 16),
            totalBytes: 2048,
            itemCount: 5,
          ),
        ];

        _stubDailyVolumes(mockSyncDb, volumes: volumes);

        final result = await container.read(outboxDailyVolumeProvider.future);

        expect(result, hasLength(2));
        expect(result[0], Observation(DateTime(2024, 3, 15), 1));
        expect(result[1], Observation(DateTime(2024, 3, 16), 2));
      });

      test('converts bytes to KB correctly', () async {
        final volumes = [
          OutboxDailyVolume(
            date: DateTime(2024, 3, 15),
            totalBytes: 5120,
            itemCount: 1,
          ),
        ];

        _stubDailyVolumes(mockSyncDb, volumes: volumes);

        final result = await container.read(outboxDailyVolumeProvider.future);

        expect(result, hasLength(1));
        expect(result[0].value, 5);
        expect(result[0].dateTime, DateTime(2024, 3, 15));
      });

      test('returns empty list when no volume data', () async {
        _stubDailyVolumes(mockSyncDb, volumes: <OutboxDailyVolume>[]);

        final result = await container.read(outboxDailyVolumeProvider.future);

        expect(result, isEmpty);
      });

      test('handles fractional KB values', () async {
        final volumes = [
          OutboxDailyVolume(
            date: DateTime(2024, 3, 15),
            totalBytes: 512,
            itemCount: 1,
          ),
        ];

        _stubDailyVolumes(mockSyncDb, volumes: volumes);

        final result = await container.read(outboxDailyVolumeProvider.future);

        expect(result[0].value, 0.5);
      });
    });

    group('OutboxConnectionState enum', () {
      test('has all expected values', () {
        expect(OutboxConnectionState.values.length, 2);
        expect(
          OutboxConnectionState.values,
          containsAll([
            OutboxConnectionState.online,
            OutboxConnectionState.disabled,
          ]),
        );
      });
    });
  });

  group('Sync activity providers', () {
    late SyncActivitySignaler signaler;
    late ProviderContainer container;

    setUp(() {
      signaler = SyncActivitySignaler();
      // Reset getIt because the syncActivitySignalerProvider resolves
      // through it; the OutboxStateController group above doesn't
      // touch getIt so this is the first registration.
      if (GetIt.I.isRegistered<SyncActivitySignaler>()) {
        GetIt.I.unregister<SyncActivitySignaler>();
      }
      GetIt.I.registerSingleton<SyncActivitySignaler>(signaler);
      container = ProviderContainer();
    });

    tearDown(() async {
      container.dispose();
      await signaler.dispose();
      if (GetIt.I.isRegistered<SyncActivitySignaler>()) {
        GetIt.I.unregister<SyncActivitySignaler>();
      }
    });

    test('syncActivitySignalerProvider returns the getIt singleton', () {
      final resolved = container.read(syncActivitySignalerProvider);
      expect(identical(resolved, signaler), isTrue);
    });

    test('syncActivityTxPulsesProvider forwards every TX pulse', () async {
      final received = <DateTime>[];
      final sub = container.listen<AsyncValue<DateTime>>(
        syncActivityTxPulsesProvider,
        (
          _,
          next,
        ) {
          if (next is AsyncData<DateTime>) received.add(next.value);
        },
      );

      signaler
        ..pulseTx()
        ..pulseTx();
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(2));
      sub.close();
    });

    test('syncActivityRxPulsesProvider forwards every RX pulse', () async {
      final received = <DateTime>[];
      final sub = container.listen<AsyncValue<DateTime>>(
        syncActivityRxPulsesProvider,
        (
          _,
          next,
        ) {
          if (next is AsyncData<DateTime>) received.add(next.value);
        },
      );

      signaler.pulseRx();
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      sub.close();
    });
  });

  group('inboundQueueDepthProvider — _inboundQueueDepthStream', () {
    late SyncDatabase db;
    late MockLoggingService logging;
    late InboundQueue queue;

    setUpAll(() {
      registerFallbackValue(StackTrace.empty);
    });

    setUp(() {
      db = SyncDatabase(inMemoryDatabase: true);
      logging = MockLoggingService();
      queue = InboundQueue(
        db: db,
        logging: logging,
        leaseDuration: const Duration(seconds: 1),
      );
    });

    tearDown(() async {
      await queue.dispose();
      await db.close();
    });

    test(
      'seeds with the snapshot from queue.stats() — covers the '
      'subscribe-before-await ordering that prevents signals from being '
      'dropped during the initial snapshot computation',
      () async {
        const roomId = '!room:example.org';
        // Insert one active row so stats().total reports 1 on seed.
        await db
            .into(db.inboundEventQueue)
            .insert(
              InboundEventQueueCompanion.insert(
                eventId: r'$seed',
                roomId: roomId,
                originTs: 1000,
                producer: InboundEventProducer.live.name,
                rawJson: jsonEncode(<String, dynamic>{}),
                enqueuedAt: clock.now().millisecondsSinceEpoch,
                status: const Value('enqueued'),
              ),
            );

        // Synchronise on the first emission directly — `.first`
        // resolves the moment the snapshot is yielded, so we don't
        // have to guess at a wall-clock budget for `stats()`.
        final firstEmission = await inboundQueueDepthStream(queue).first;
        expect(firstEmission, 1);
      },
    );

    test(
      'forwards a live depthChanges signal that arrives after the '
      'snapshot — covers the steady-state `relay.add` path once the '
      'generator has switched into draining mode',
      () async {
        const roomId = '!room:example.org';
        final stream = inboundQueueDepthStream(queue);
        // expectLater + emitsThrough waits for the matched value
        // without polling — synchronises on the actual event we care
        // about (a depth change of `1`) and times out cleanly on
        // regression rather than hanging the test runner.
        final matched = expectLater(stream, emitsThrough(1));

        // Trigger a live depth signal by inserting an active row and
        // letting the queue emit through `_scheduleDepthEmit`.
        await db
            .into(db.inboundEventQueue)
            .insert(
              InboundEventQueueCompanion.insert(
                eventId: r'$live',
                roomId: roomId,
                originTs: 2000,
                producer: InboundEventProducer.live.name,
                rawJson: jsonEncode(<String, dynamic>{}),
                enqueuedAt: clock.now().millisecondsSinceEpoch,
                status: const Value('enqueued'),
              ),
            );
        // The queue's internal `_emitDepth` runs on a microtask boundary.
        // Nudge it so `expectLater` resolves without a wall-clock wait.
        await Future<void>.value();

        await matched.timeout(const Duration(seconds: 2));
      },
    );
  });
}
