import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/isolate/isolate_inbound_queue_gateway.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_host.dart';
import 'package:lotti/features/sync/isolate/sync_isolate_protocol.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_worker.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../queue/test_utils.dart';

void main() {
  const roomId = '!room:example.org';
  late MockDomainLogger logger;
  late SyncDatabase db;
  late InboundQueue localQueue;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(const <InboundEntryOutcome>[]);
  });

  setUp(() {
    logger = MockDomainLogger();
    when(
      () => logger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
        level: any(named: 'level'),
      ),
    ).thenReturn(null);
    when(
      () => logger.error(
        any(),
        any<Object>(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
        message: any(named: 'message'),
      ),
    ).thenReturn(null);
  });

  InboundQueueEntry entry(String id) => InboundQueueEntry(
    queueId: 1,
    eventId: id,
    roomId: roomId,
    originTs: 1,
    enqueuedAt: 1,
    attempts: 0,
    rawJson: '{}',
  );

  group('against a mocked host', () {
    late MockSyncIsolateHost host;
    late StreamController<List<String>> tablesChanged;
    late StreamController<SyncIsolateState> states;
    late IsolateInboundQueueGateway gateway;

    setUp(() {
      db = SyncDatabase(inMemoryDatabase: true);
      localQueue = InboundQueue(
        trust: AdmittingSyncEventTrust(),
        db: db,
        logging: logger,
      );
      host = MockSyncIsolateHost();
      tablesChanged = StreamController<List<String>>.broadcast();
      states = StreamController<SyncIsolateState>.broadcast();
      when(() => host.tablesChanged).thenAnswer((_) => tablesChanged.stream);
      when(() => host.states).thenAnswer((_) => states.stream);
      when(() => host.state).thenReturn(SyncIsolateState.running);
      gateway = IsolateInboundQueueGateway(host: host, localQueue: localQueue);
    });

    tearDown(() async {
      await tablesChanged.close();
      await states.close();
      await localQueue.dispose();
      await db.close();
    });

    test('while the worker is not running a lease is empty and nothing is '
        'asked of the host', () async {
      when(() => host.state).thenReturn(SyncIsolateState.restarting);

      expect(await gateway.lease(maxBatch: 5), isEmpty);
      verifyNever(() => host.lease(maxBatch: any(named: 'maxBatch')));
    });

    test('a lease goes to the host', () async {
      final leased = [entry(r'$a')];
      when(() => host.lease(maxBatch: 5)).thenAnswer((_) async => leased);

      expect(await gateway.lease(maxBatch: 5), same(leased));
    });

    test('a queue write the worker reports tells the local depth '
        'subscribers, whether or not a request was waiting on it; other '
        'tables do not', () async {
      final depth = <QueueDepthSignal>[];
      final sub = localQueue.depthChanges.listen(depth.add);
      addTearDown(sub.cancel);

      tablesChanged.add(['outbox']);
      await pumpEventQueue();
      expect(depth, isEmpty);

      tablesChanged.add(['inbound_event_queue', 'queue_markers']);
      await pumpEventQueue();
      expect(depth, hasLength(1));
    });

    test('the next ready time is read on the local connection', () async {
      expect(await gateway.earliestReadyAt(), isNull);
      await localQueue.enqueueLive(
        buildSyncEvent(eventId: r'$a', roomId: roomId, originTsMs: 1),
      );

      expect(await gateway.earliestReadyAt(), isNotNull);
      verifyNever(() => host.lease(maxBatch: any(named: 'maxBatch')));
    });

    test('while the worker is not running a ready row reports no ready time, '
        'so the loop waits for the worker instead of polling', () async {
      await localQueue.enqueueLive(
        buildSyncEvent(eventId: r'$a', roomId: roomId, originTsMs: 1),
      );
      when(() => host.state).thenReturn(SyncIsolateState.restarting);

      expect(await gateway.earliestReadyAt(), isNull);

      when(() => host.state).thenReturn(SyncIsolateState.running);
      expect(await gateway.earliestReadyAt(), isNotNull);
    });

    test('a worker that goes away mid-lease yields an empty lease, not an '
        'error; a failure the worker reports propagates', () async {
      when(() => host.lease(maxBatch: 5)).thenThrow(
        const SyncIsolateFailure(SyncIsolateErrorCode.isolateExited, 'gone'),
      );
      expect(await gateway.lease(maxBatch: 5), isEmpty);

      when(() => host.lease(maxBatch: 5)).thenThrow(
        const SyncIsolateFailure(SyncIsolateErrorCode.timeout, 'slow'),
      );
      expect(await gateway.lease(maxBatch: 5), isEmpty);

      when(() => host.lease(maxBatch: 5)).thenThrow(
        const SyncIsolateFailure(SyncIsolateErrorCode.failed, 'db locked'),
      );
      await expectLater(
        gateway.lease(maxBatch: 5),
        throwsA(
          isA<SyncIsolateFailure>().having(
            (f) => f.code,
            'code',
            SyncIsolateErrorCode.failed,
          ),
        ),
      );
    });

    test('a settlement goes to the host and returns its count', () async {
      final outcomes = [
        InboundEntryOutcome(entry(r'$a'), ApplyOutcome.applied),
      ];
      when(() => host.settle(outcomes)).thenAnswer((_) async => 1);

      expect(await gateway.settle(outcomes), 1);
    });

    test(
      'a failed settlement propagates: the rows stay leased for redelivery',
      () {
        final outcomes = [
          InboundEntryOutcome(entry(r'$a'), ApplyOutcome.applied),
        ];
        when(() => host.settle(outcomes)).thenThrow(
          const SyncIsolateFailure(SyncIsolateErrorCode.isolateExited, 'gone'),
        );

        expect(gateway.settle(outcomes), throwsA(isA<SyncIsolateFailure>()));
      },
    );

    test(
      'changes fire once for a queue-table report, for the worker coming back, and '
      'local enqueues — not for other tables or states',
      () async {
        final seen = <void>[];
        final sub = gateway.changes.listen(seen.add);
        addTearDown(sub.cancel);

        tablesChanged.add(['outbox']);
        states.add(SyncIsolateState.restarting);
        await pumpEventQueue();
        expect(seen, isEmpty);

        tablesChanged.add(['inbound_event_queue', 'queue_markers']);
        states.add(SyncIsolateState.running);
        await localQueue.enqueueLive(
          buildSyncEvent(eventId: r'$a', roomId: roomId, originTsMs: 1),
        );
        await pumpEventQueue();
        expect(seen, hasLength(3));
      },
    );
  });

  group('end to end, the production worker owning a shared sync.sqlite', () {
    late Directory tempDir;
    late SyncIsolateHost host;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('isolate_gateway');
      db = SyncDatabase(
        background: false,
        documentsDirectoryProvider: () async => tempDir,
        tempDirectoryProvider: () async => tempDir,
      );
      localQueue = InboundQueue(
        trust: AdmittingSyncEventTrust(),
        db: db,
        logging: logger,
      );
      host = SyncIsolateHost(
        logger: logger,
        config: SyncIsolateConfig(
          documentsPath: tempDir.path,
          temporaryPath: tempDir.path,
        ),
      );
      final running = host.states.firstWhere(
        (s) => s == SyncIsolateState.running,
      );
      host.start();
      await running;
    });

    tearDown(() async {
      await host.dispose();
      await localQueue.dispose();
      await db.close();
      await tempDir.delete(recursive: true);
    });

    test("the UI isolate's worker drains a row the sync isolate leases and "
        'settles, and both connections agree on the outcome', () async {
      final sequence = SyncSequenceLogService(
        syncDatabase: db,
        vectorClockService: MockVectorClockService(),
        loggingService: logger,
      );
      final applied = <String>[];
      final worker = InboundWorker(
        queue: localQueue,
        gateway: IsolateInboundQueueGateway(host: host, localQueue: localQueue),
        sequenceLogService: sequence,
        apply: (entry) async {
          applied.add(entry.eventId);
          return entry.eventId == r'$skip'
              ? ApplyOutcome.permanentSkip
              : ApplyOutcome.applied;
        },
        logging: logger,
      );
      await localQueue.enqueueLive(
        buildSyncEvent(eventId: r'$one', roomId: roomId, originTsMs: 1),
      );
      await localQueue.enqueueLive(
        buildSyncEvent(eventId: r'$skip', roomId: roomId, originTsMs: 2),
      );
      await localQueue.enqueueLive(
        buildSyncEvent(eventId: r'$two', roomId: roomId, originTsMs: 3),
      );

      final count = await worker.drainToCompletion();

      expect(count, 2);
      expect(applied, [r'$one', r'$skip', r'$two']);
      final stats = await localQueue.stats();
      expect(stats.total, 0);
      expect(stats.applied, 2);
      expect(stats.abandoned, 1);
      final marker = await (db.select(
        db.queueMarkers,
      )..where((t) => t.roomId.equals(roomId))).getSingle();
      expect(marker.lastAppliedEventId, r'$two');
    });

    test('an unacknowledged lease stays leased while it holds, never dropped '
        'and never handed out twice', () async {
      await localQueue.enqueueLive(
        buildSyncEvent(eventId: r'$lost', roomId: roomId, originTsMs: 1),
      );
      // The worker leases for the production duration on its own clock;
      // the test's connection shows the row leased, and nobody acknowledges.
      final first = await host.lease(maxBatch: 5);
      expect(first.map((e) => e.eventId), [r'$lost']);
      expect((await localQueue.stats()).total, 1);

      // Nothing re-leases while the lease holds...
      expect(await host.lease(maxBatch: 5), isEmpty);
      // ...and the row is still active, never silently dropped.
      final rows = await db.select(db.inboundEventQueue).get();
      expect(rows.single.status, InboundQueueStatuses.leased);
      expect(rows.single.leaseUntil, greaterThan(0));
    });
  });
}
