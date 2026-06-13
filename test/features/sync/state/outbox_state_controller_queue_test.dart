import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/state/sync_activity_signaler.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'outbox_state_controller_test_helpers.dart';

void main() {
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
      await pumpEventQueue();

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
      await pumpEventQueue();

      expect(received, hasLength(1));
      sub.close();
    });
  });

  group('inboundQueueDepthProvider — _inboundQueueDepthStream', () {
    late SyncDatabase db;
    late MockDomainLogger logging;
    late InboundQueue queue;

    setUpAll(() {
      registerFallbackValue(StackTrace.empty);
    });

    setUp(() {
      db = SyncDatabase(inMemoryDatabase: true);
      logging = MockDomainLogger();
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
      'consumer is listening',
      () async {
        const roomA = '!a:example.org';
        const roomB = '!b:example.org';
        // Insert one row in roomA so the snapshot reports total: 1.
        await db
            .into(db.inboundEventQueue)
            .insert(
              InboundEventQueueCompanion.insert(
                eventId: r'$seed',
                roomId: roomA,
                originTs: 1000,
                producer: InboundEventProducer.live.name,
                rawJson: jsonEncode(<String, dynamic>{}),
                enqueuedAt: clock.now().millisecondsSinceEpoch,
                status: const Value('enqueued'),
              ),
            );

        // `emitsInOrder` waits for the snapshot (1) and then a live
        // depth signal of (0). The live signal fires when we prune the
        // stranded row in roomA — `pruneStrandedEntries(roomB)` flips
        // every active row that doesn't belong to roomB to abandoned
        // and calls `_scheduleDepthEmit`, exercising the
        // `relay.hasListener → relay.add(value)` branch.
        final stream = inboundQueueDepthStream(queue);
        final matched = expectLater(stream, emitsInOrder(<int>[1, 0]));

        // Yield once so the generator has time to subscribe AND run
        // its initial `stats()` fetch before we trigger the live emit.
        await Future<void>.value();
        await Future<void>.value();
        await queue.pruneStrandedEntries(roomB);

        await matched.timeout(
          // In-memory SQLite resolves in <5 ms; 200 ms is hang-failure
          // headroom, not a wait — it costs nothing on the happy path.
          const Duration(milliseconds: 200),
        );
      },
    );

    test(
      'replays buffered live signals in arrival order when they beat the '
      '`stats()` snapshot — covers the `else` branch of the '
      'buffered/snapshot decision in `inboundQueueDepthStream`',
      () async {
        // Insert two rows so a future prune emits a depth-of-zero
        // signal that lands during the generator's `stats()` await.
        const roomA = '!a:example.org';
        const roomB = '!b:example.org';
        for (var i = 0; i < 2; i++) {
          await db
              .into(db.inboundEventQueue)
              .insert(
                InboundEventQueueCompanion.insert(
                  eventId: '\$row-$i',
                  roomId: roomA,
                  originTs: 1000 + i,
                  producer: InboundEventProducer.live.name,
                  rawJson: jsonEncode(<String, dynamic>{}),
                  enqueuedAt: clock.now().millisecondsSinceEpoch,
                  status: const Value('enqueued'),
                ),
              );
        }

        // Subscribe to the stream and IMMEDIATELY trigger a depth emit
        // before the generator's `stats()` await resolves. The signal
        // lands while the consumer hasn't started listening to the
        // relay yet (`relay.hasListener == false`), so the value is
        // captured into the `buffered` list. Once `stats()` settles,
        // the snapshot branch is skipped (`buffered.isEmpty == false`)
        // and the buffered values are replayed instead.
        final received = <int>[];
        final completer = Completer<void>();
        final sub = inboundQueueDepthStream(queue).listen((value) {
          received.add(value);
          if (received.contains(0) && !completer.isCompleted) {
            completer.complete();
          }
        });

        // Fire the live signal synchronously (no `await` between the
        // listen() call and the prune) so it races the generator's
        // `stats()` await.
        unawaited(queue.pruneStrandedEntries(roomB));

        await completer.future.timeout(
          // In-memory SQLite resolves in <5 ms; 200 ms is hang-failure
          // headroom, not a wait — it costs nothing on the happy path.
          const Duration(milliseconds: 200),
        );
        await sub.cancel();
        // The replay path emitted `0` (the post-prune depth). A
        // regression that emitted `2` (the stale snapshot) before
        // `0` would still pass `received.contains(0)`, so we also
        // assert there is no stale `2` ahead of the `0`.
        expect(received, contains(0));
        final indexOfZero = received.indexOf(0);
        expect(received.sublist(0, indexOfZero), isNot(contains(2)));
      },
    );

    test(
      'inboundQueueDepthProvider resolves the queue via MatrixService and '
      'streams the seeded depth — covers the provider entry point',
      () async {
        final mockMatrix = MockMatrixService();
        final mockCoordinator = MockQueueCoordinator();
        when(() => mockMatrix.queueCoordinator).thenReturn(mockCoordinator);
        when(() => mockCoordinator.queue).thenReturn(queue);

        final container = ProviderContainer(
          overrides: [matrixServiceProvider.overrideWithValue(mockMatrix)],
        );
        addTearDown(container.dispose);

        final completer = Completer<int>();
        container.listen<AsyncValue<int>>(inboundQueueDepthProvider, (
          _,
          next,
        ) {
          if (next is AsyncData<int> && !completer.isCompleted) {
            completer.complete(next.value);
          }
        }, fireImmediately: true);

        final value = await completer.future.timeout(
          const Duration(seconds: 2),
        );
        expect(value, 0);
      },
    );
  });

  // Deterministic coverage for the buffer/replay/error branches of
  // `inboundQueueDepthStream`. The real in-memory `InboundQueue.stats()`
  // resolves too fast to reliably land a `depthChanges` signal inside the
  // generator's `stats()` await, so these tests drive a `MockInboundQueue`
  // with a manually-controlled `stats()` completer and a hand-fed
  // `depthChanges` controller. That lets us force the exact interleaving
  // where a live signal arrives BEFORE the consumer subscribes to the
  // internal relay (`relay.hasListener == false`) so the value is captured
  // in the `buffered` list and replayed once `stats()` resolves.
  group('inboundQueueDepthStream — buffered/error branches (mocked queue)', () {
    late MockInboundQueue queue;
    late StreamController<QueueDepthSignal> depthCtl;
    late Completer<QueueStats> statsCompleter;

    QueueDepthSignal signal(int total) => QueueDepthSignal(
      total: total,
      byProducer: const <InboundEventProducer, int>{},
      oldestEnqueuedAt: null,
    );

    QueueStats stats(int total) => QueueStats(
      total: total,
      byProducer: const <InboundEventProducer, int>{},
      readyNow: 0,
      oldestEnqueuedAt: null,
    );

    setUpAll(() {
      registerFallbackValue(StackTrace.empty);
    });

    setUp(() {
      queue = MockInboundQueue();
      depthCtl = StreamController<QueueDepthSignal>.broadcast();
      statsCompleter = Completer<QueueStats>();
      when(() => queue.depthChanges).thenAnswer((_) => depthCtl.stream);
      when(queue.stats).thenAnswer((_) => statsCompleter.future);
    });

    tearDown(() async {
      if (!depthCtl.isClosed) await depthCtl.close();
    });

    test(
      'a live signal that lands while stats() is still awaiting is buffered '
      'and replayed in arrival order, skipping the stale snapshot — covers '
      'buffered.add, the replay loop, and buffered.clear',
      () async {
        final received = <int>[];
        final firstTwo = Completer<void>();
        final sub = inboundQueueDepthStream(queue).listen((value) {
          received.add(value);
          if (received.length == 2 && !firstTwo.isCompleted) {
            firstTwo.complete();
          }
        });
        addTearDown(sub.cancel);

        // Let the generator subscribe to depthChanges and park on the
        // (still-pending) stats() future. At this point the consumer has
        // not yet reached `yield* relay.stream`, so `relay.hasListener`
        // is false and any depth signal is captured into `buffered`.
        await Future<void>.value();
        await Future<void>.value();

        // Two live signals arrive DURING the stats() await -> buffered.add
        // is hit twice (covers line 131).
        depthCtl
          ..add(signal(7))
          ..add(signal(3));
        await Future<void>.value();
        await Future<void>.value();

        // Now resolve the snapshot. Because `buffered` is non-empty the
        // generator takes the else branch: it replays the buffered values
        // in arrival order (the for-loop) and then clears the buffer
        // (covers lines 154 + 157) instead of yielding the stale snapshot.
        statsCompleter.complete(stats(99));

        await firstTwo.future.timeout(
          // In-memory SQLite resolves in <5 ms; 200 ms is hang-failure
          // headroom, not a wait — it costs nothing on the happy path.
          const Duration(milliseconds: 200),
        );

        // The stale snapshot (99) must never appear: the buffered live
        // sequence [7, 3] is emitted in arrival order instead.
        expect(received, [7, 3]);
        expect(received, isNot(contains(99)));
      },
    );

    test(
      'after the snapshot is yielded and the consumer is forwarding the '
      'relay, a depthChanges error is forwarded through relay.addError — '
      'covers the onError branch',
      () async {
        final received = <int>[];
        Object? receivedError;
        final errored = Completer<void>();
        final sub = inboundQueueDepthStream(queue).listen(
          received.add,
          onError: (Object e, StackTrace s) {
            receivedError ??= e;
            if (!errored.isCompleted) errored.complete();
          },
        );
        addTearDown(sub.cancel);

        // Resolve stats() with an empty snapshot. With no buffered values
        // the generator yields the snapshot (0) and then enters
        // `yield* relay.stream`, so the relay now HAS a listener.
        statsCompleter.complete(stats(0));
        await Future<void>.value();
        await Future<void>.value();
        expect(received, [0]);

        // An error on depthChanges while the relay has a listener is
        // forwarded through relay.addError (covers lines 134-135). The
        // consumer surfaces it as a stream error.
        final boom = Exception('depth stream failed');
        depthCtl.addError(boom);

        await errored.future.timeout(
          // In-memory SQLite resolves in <5 ms; 200 ms is hang-failure
          // headroom, not a wait — it costs nothing on the happy path.
          const Duration(milliseconds: 200),
        );
        expect(receivedError, same(boom));
      },
    );
  });
}
