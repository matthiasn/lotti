import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/queue/bridge_coordinator.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_worker.dart';
import 'package:lotti/features/sync/queue/pending_decryption_pen.dart';
import 'package:lotti/features/sync/queue/queue_marker_seeder.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _MockSessionManager extends Mock implements MatrixSessionManager {}

class _MockRoomManager extends Mock implements SyncRoomManager {}

class _MockEventProcessor extends Mock implements SyncEventProcessor {}

class _MockSequenceLogService extends Mock implements SyncSequenceLogService {}

class _MockQueue extends Mock implements InboundQueue {}

class _MockWorker extends Mock implements InboundWorker {}

class _MockBridge extends Mock implements BridgeCoordinator {}

class _MockPen extends Mock implements PendingDecryptionPen {}

class _MockSeeder extends Mock implements QueueMarkerSeeder {}

class _MockEvent extends Mock implements Event {}

class _MockClient extends Mock implements Client {}

class _MockRoom extends Mock implements Room {}

class _MockTimeline extends Mock implements Timeline {}

void main() {
  late SyncDatabase syncDb;
  late JournalDb journalDb;
  late MockSettingsDb settingsDb;
  late _MockSessionManager sessionManager;
  late _MockRoomManager roomManager;
  late _MockEventProcessor processor;
  late _MockSequenceLogService sequenceLog;
  late MockLoggingService logging;
  late _MockQueue queue;
  late _MockWorker worker;
  late _MockBridge bridge;
  late _MockPen pen;
  late _MockSeeder seeder;
  late StreamController<Event> timelineCtl;
  late CachedStreamController<SyncUpdate> syncCtl;
  late _MockClient client;
  const roomId = '!roomA:example.org';

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(_MockEvent());
  });

  setUp(() {
    syncDb = SyncDatabase(inMemoryDatabase: true);
    journalDb = JournalDb(inMemoryDatabase: true);
    settingsDb = MockSettingsDb();
    sessionManager = _MockSessionManager();
    roomManager = _MockRoomManager();
    processor = _MockEventProcessor();
    sequenceLog = _MockSequenceLogService();
    logging = MockLoggingService();
    queue = _MockQueue();
    worker = _MockWorker();
    bridge = _MockBridge();
    pen = _MockPen();
    seeder = _MockSeeder();
    timelineCtl = StreamController<Event>.broadcast();
    syncCtl = CachedStreamController<SyncUpdate>();
    client = _MockClient();
    when(() => client.onSync).thenReturn(syncCtl);

    when(
      () => sessionManager.timelineEvents,
    ).thenAnswer((_) => timelineCtl.stream);
    when(() => sessionManager.client).thenReturn(client);
    when(() => roomManager.currentRoomId).thenReturn(roomId);
    when(() => roomManager.currentRoom).thenReturn(null);
    when(() => seeder.seedIfAbsent(any())).thenAnswer((_) async => true);
    when(() => queue.pruneStrandedEntries(any())).thenAnswer((_) async => 0);
    when(worker.start).thenAnswer((_) async {});
    when(() => worker.stop()).thenAnswer((_) async {});
    when(worker.drainToCompletion).thenAnswer((_) async => 0);
    when(bridge.start).thenReturn(null);
    when(bridge.stop).thenAnswer((_) async {});
    when(pen.stop).thenAnswer((_) async {});
    when(() => queue.dispose()).thenAnswer((_) async {});
    when(() => queue.enqueueLive(any())).thenAnswer(
      (_) async => EnqueueResult.empty,
    );
    when(() => pen.hold(any())).thenReturn(false);
  });

  tearDown(() async {
    await timelineCtl.close();
    await syncCtl.close();
    await syncDb.close();
    await journalDb.close();
  });

  QueuePipelineCoordinator build() => QueuePipelineCoordinator(
    syncDb: syncDb,
    settingsDb: settingsDb,
    journalDb: journalDb,
    sessionManager: sessionManager,
    roomManager: roomManager,
    eventProcessor: processor,
    sequenceLogService: sequenceLog,
    activityGate: null,
    logging: logging,
    queueOverride: queue,
    workerOverride: worker,
    bridgeOverride: bridge,
    penOverride: pen,
    seederOverride: seeder,
  );

  Event buildEvent(String type) {
    final e = _MockEvent();
    when(() => e.eventId).thenReturn(r'$a');
    when(() => e.roomId).thenReturn(roomId);
    when(() => e.type).thenReturn(type);
    return e;
  }

  test(
    'start seeds the marker, prunes strays, starts worker + bridge',
    () async {
      final coordinator = build();
      await coordinator.start();
      expect(coordinator.isRunning, isTrue);
      verify(() => seeder.seedIfAbsent(roomId)).called(1);
      verify(() => queue.pruneStrandedEntries(roomId)).called(1);
      verify(worker.start).called(1);
      verify(bridge.start).called(1);
      await coordinator.stop();
    },
  );

  test('encrypted live event is routed through the pen (F3)', () async {
    final coordinator = build();
    await coordinator.start();

    when(() => pen.hold(any())).thenReturn(true);
    timelineCtl.add(buildEvent(EventTypes.Encrypted));
    await Future<void>.delayed(Duration.zero);

    verifyNever(() => queue.enqueueLive(any()));
    verify(() => pen.hold(any())).called(1);
    await coordinator.stop();
  });

  test('plain live event bypasses pen and enters the queue', () async {
    final coordinator = build();
    await coordinator.start();

    timelineCtl.add(buildEvent(EventTypes.Message));
    await Future<void>.delayed(Duration.zero);

    verify(() => pen.hold(any())).called(1);
    verify(() => queue.enqueueLive(any())).called(1);
    await coordinator.stop();
  });

  test(
    'live event for a different room is ignored',
    () async {
      final coordinator = build();
      await coordinator.start();

      final foreign = _MockEvent();
      when(() => foreign.eventId).thenReturn(r'$other');
      when(() => foreign.roomId).thenReturn('!someOtherRoom:example.org');
      when(() => foreign.type).thenReturn(EventTypes.Message);
      timelineCtl.add(foreign);
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => pen.hold(any()));
      verifyNever(() => queue.enqueueLive(any()));
      await coordinator.stop();
    },
  );

  test('stop(drainFirst: true) drains before tearing down (F7)', () async {
    final coordinator = build();
    await coordinator.start();
    await coordinator.stop(drainFirst: true);

    verify(worker.drainToCompletion).called(1);
    verify(() => worker.stop()).called(1);
    verify(bridge.stop).called(1);
    verify(pen.stop).called(1);
    verify(() => queue.dispose()).called(1);
  });

  test('stop without drainFirst skips drainToCompletion', () async {
    final coordinator = build();
    await coordinator.start();
    await coordinator.stop();

    verifyNever(worker.drainToCompletion);
    verify(() => worker.stop()).called(1);
  });

  test('triggerBridge delegates to bridge.bridgeNow', () async {
    when(bridge.bridgeNow).thenAnswer((_) async {});
    final coordinator = build();
    await coordinator.triggerBridge();
    verify(bridge.bridgeNow).called(1);
  });

  test('start logs noRoom when there is no current room', () async {
    when(() => roomManager.currentRoomId).thenReturn(null);
    final coordinator = build();
    await coordinator.start();

    verifyNever(() => seeder.seedIfAbsent(any()));
    verify(
      () => logging.captureEvent(
        any<String>(that: contains('queue.coordinator.start.noRoom')),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).called(1);
    expect(coordinator.isRunning, isTrue);
    await coordinator.stop();
  });

  test('start swallows seeder errors and continues', () async {
    when(
      () => seeder.seedIfAbsent(any()),
    ).thenThrow(StateError('seed failed'));
    final coordinator = build();
    await coordinator.start();

    expect(coordinator.isRunning, isTrue);
    verify(
      () => logging.captureException(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(
          named: 'subDomain',
          that: contains('start.seed'),
        ),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
      ),
    ).called(1);
    await coordinator.stop();
  });

  test(
    'start unwinds when worker.start throws and leaves coordinator stopped',
    () async {
      when(worker.start).thenThrow(StateError('worker died'));
      final coordinator = build();

      await expectLater(coordinator.start(), throwsA(isA<StateError>()));
      expect(coordinator.isRunning, isFalse);
      verify(bridge.stop).called(1);
      verify(() => worker.stop()).called(1);
    },
  );

  test('handles onSync signal: postLoad called on partial room', () async {
    final room = _MockRoom();
    when(() => room.partial).thenReturn(true);
    when(room.postLoad).thenAnswer((_) async {});
    when(() => roomManager.currentRoom).thenReturn(room);

    final coordinator = build();
    await coordinator.start();

    syncCtl.add(SyncUpdate(nextBatch: 'x'));
    // Allow the async listener to fire and the follow-up postLoad future.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    verify(room.postLoad).called(1);
    await coordinator.stop();
  });

  test(
    'onSync does not call postLoad when room is already non-partial',
    () async {
      final room = _MockRoom();
      when(() => room.partial).thenReturn(false);
      when(room.postLoad).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);

      final coordinator = build();
      await coordinator.start();

      syncCtl.add(SyncUpdate(nextBatch: 'x'));
      await Future<void>.delayed(Duration.zero);

      verifyNever(room.postLoad);
      await coordinator.stop();
    },
  );

  test('safeEnqueue swallows errors from enqueueLive', () async {
    when(
      () => queue.enqueueLive(any()),
    ).thenThrow(StateError('queue closed'));
    final coordinator = build();
    await coordinator.start();

    timelineCtl.add(buildEvent(EventTypes.Message));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    verify(
      () => logging.captureException(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain', that: contains('enqueue')),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
      ),
    ).called(1);
    await coordinator.stop();
  });

  group('collectHistory', () {
    test('throws StateError when no current room', () async {
      when(() => roomManager.currentRoomId).thenReturn(null);
      final coordinator = build();
      await expectLater(
        coordinator.collectHistory(),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'exits immediately when the server has no history',
      () async {
        final room = _MockRoom();
        final timeline = _MockTimeline();
        when(() => roomManager.currentRoom).thenReturn(room);
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => timeline);
        when(() => timeline.events).thenReturn(<Event>[]);
        when(() => timeline.canRequestHistory).thenReturn(false);
        when(timeline.cancelSubscriptions).thenAnswer((_) {});

        final coordinator = build();
        final infos = <BootstrapPageInfo>[];
        final result = await coordinator.collectHistory(
          onProgress: infos.add,
        );

        expect(result.stopReason, BootstrapStopReason.serverExhausted);
        expect(result.totalEvents, 0);
        expect(infos, isEmpty);
        verify(timeline.cancelSubscriptions).called(1);
      },
    );

    test(
      'forwards progress info and appends pages to the real queue',
      () async {
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);

        final coordinator = QueuePipelineCoordinator(
          syncDb: syncDb,
          settingsDb: settingsDb,
          journalDb: journalDb,
          sessionManager: sessionManager,
          roomManager: roomManager,
          eventProcessor: processor,
          sequenceLogService: sequenceLog,
          activityGate: null,
          logging: logging,
          queueOverride: realQueue,
          workerOverride: worker,
          bridgeOverride: bridge,
          penOverride: pen,
          seederOverride: seeder,
        );

        final room = _MockRoom();
        final timeline = _MockTimeline();
        when(() => roomManager.currentRoom).thenReturn(room);
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => timeline);

        final event = _MockEvent();
        when(() => event.eventId).thenReturn(r'$bootstrap');
        when(() => event.roomId).thenReturn(roomId);
        when(() => event.type).thenReturn(EventTypes.Message);
        when(
          () => event.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(10));
        when(() => event.content).thenReturn(<String, dynamic>{
          'msgtype': 'org.matrix.lotti.sync',
        });
        when(event.toJson).thenReturn(<String, dynamic>{
          'event_id': r'$bootstrap',
          'room_id': roomId,
          'origin_server_ts': 10,
          'type': EventTypes.Message,
          'content': {'msgtype': 'org.matrix.lotti.sync'},
        });
        when(() => timeline.events).thenReturn(<Event>[event]);
        when(() => timeline.canRequestHistory).thenReturn(false);
        when(timeline.cancelSubscriptions).thenAnswer((_) {});

        final infos = <BootstrapPageInfo>[];
        final result = await coordinator.collectHistory(
          onProgress: infos.add,
        );

        expect(result.stopReason, BootstrapStopReason.serverExhausted);
        expect(infos, hasLength(1));
        expect(infos.single.totalEventsSoFar, 1);
      },
    );

    test(
      'onProgress exception does not abort the bootstrap',
      () async {
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);

        final coordinator = QueuePipelineCoordinator(
          syncDb: syncDb,
          settingsDb: settingsDb,
          journalDb: journalDb,
          sessionManager: sessionManager,
          roomManager: roomManager,
          eventProcessor: processor,
          sequenceLogService: sequenceLog,
          activityGate: null,
          logging: logging,
          queueOverride: realQueue,
          workerOverride: worker,
          bridgeOverride: bridge,
          penOverride: pen,
          seederOverride: seeder,
        );

        final room = _MockRoom();
        final timeline = _MockTimeline();
        when(() => roomManager.currentRoom).thenReturn(room);
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => timeline);

        final event = _MockEvent();
        when(() => event.eventId).thenReturn(r'$bootstrap2');
        when(() => event.roomId).thenReturn(roomId);
        when(() => event.type).thenReturn(EventTypes.Message);
        when(
          () => event.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(20));
        when(() => event.content).thenReturn(<String, dynamic>{
          'msgtype': 'org.matrix.lotti.sync',
        });
        when(event.toJson).thenReturn(<String, dynamic>{
          'event_id': r'$bootstrap2',
          'room_id': roomId,
          'origin_server_ts': 20,
          'type': EventTypes.Message,
          'content': {'msgtype': 'org.matrix.lotti.sync'},
        });
        when(() => timeline.events).thenReturn(<Event>[event]);
        when(() => timeline.canRequestHistory).thenReturn(false);
        when(timeline.cancelSubscriptions).thenAnswer((_) {});

        final result = await coordinator.collectHistory(
          onProgress: (_) => throw StateError('UI unmounted'),
        );

        expect(result.stopReason, BootstrapStopReason.serverExhausted);
      },
    );
  });

  test('queue + worker getters expose the collaborators', () {
    final coordinator = build();
    expect(coordinator.queue, same(queue));
    expect(coordinator.worker, same(worker));
  });

  test('postLoad error drops the marker so a later sync retries', () async {
    final room = _MockRoom();
    when(() => room.partial).thenReturn(true);
    when(room.postLoad).thenThrow(StateError('sdk down'));
    when(() => roomManager.currentRoom).thenReturn(room);

    final coordinator = build();
    await coordinator.start();

    syncCtl.add(SyncUpdate(nextBatch: 'x'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    verify(
      () => logging.captureException(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain', that: contains('postLoad')),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
      ),
    ).called(1);
    await coordinator.stop();
  });

  test('onSync error handler logs and does not crash', () async {
    final coordinator = build();
    await coordinator.start();

    syncCtl.addError(StateError('sync broke'), StackTrace.current);
    await Future<void>.delayed(Duration.zero);

    verify(
      () => logging.captureException(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain', that: contains('syncSub')),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
      ),
    ).called(1);
    await coordinator.stop();
  });

  test('stop swallows drainToCompletion errors and still tears down', () async {
    when(
      worker.drainToCompletion,
    ).thenThrow(StateError('drain blew up'));
    final coordinator = build();
    await coordinator.start();
    await coordinator.stop(drainFirst: true);

    verify(
      () => logging.captureException(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain', that: contains('drain')),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
      ),
    ).called(1);
    verify(() => worker.stop()).called(1);
    verify(pen.stop).called(1);
    verify(() => queue.dispose()).called(1);
  });

  test(
    'coordinator built without overrides wires default collaborators',
    () async {
      when(() => sessionManager.client).thenReturn(client);
      final coordinator = QueuePipelineCoordinator(
        syncDb: syncDb,
        settingsDb: settingsDb,
        journalDb: journalDb,
        sessionManager: sessionManager,
        roomManager: roomManager,
        eventProcessor: processor,
        sequenceLogService: sequenceLog,
        activityGate: null,
        logging: logging,
      );

      expect(coordinator.queue, isNotNull);
      expect(coordinator.worker, isNotNull);
      expect(coordinator.isRunning, isFalse);
    },
  );

  group('triggerBridge with real BridgeCoordinator', () {
    test(
      'reads queue_markers row and runs bootstrap against empty timeline',
      () async {
        // Seed a queue_markers row so _readMarkerTs hits the marker
        // branch instead of falling back to settingsDb.
        await syncDb
            .into(syncDb.queueMarkers)
            .insert(
              QueueMarkersCompanion.insert(
                roomId: roomId,
                lastAppliedTs: const Value(42),
              ),
            );

        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);

        final room = _MockRoom();
        when(() => room.id).thenReturn(roomId);
        final timeline = _MockTimeline();
        when(() => timeline.events).thenReturn(<Event>[]);
        when(() => timeline.canRequestHistory).thenReturn(false);
        when(timeline.cancelSubscriptions).thenAnswer((_) {});
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => timeline);

        // _resolveRoom tries currentRoom first, falls back to
        // client.getRoomById — exercise the fallback.
        when(() => roomManager.currentRoom).thenReturn(null);
        when(() => client.getRoomById(roomId)).thenReturn(room);

        final coordinator = QueuePipelineCoordinator(
          syncDb: syncDb,
          settingsDb: settingsDb,
          journalDb: journalDb,
          sessionManager: sessionManager,
          roomManager: roomManager,
          eventProcessor: processor,
          sequenceLogService: sequenceLog,
          activityGate: null,
          logging: logging,
          queueOverride: realQueue,
          workerOverride: worker,
          penOverride: pen,
          seederOverride: seeder,
        );

        await coordinator.triggerBridge();

        // The bridge should have resolved the room via client.getRoomById
        // and called getTimeline.
        verify(() => client.getRoomById(roomId)).called(1);
        verify(() => room.getTimeline(limit: any(named: 'limit'))).called(1);
      },
    );

    test(
      '_readMarkerTs falls back to settingsDb when no marker row exists',
      () async {
        when(
          () => settingsDb.itemByKey('LAST_READ_MATRIX_EVENT_TS'),
        ).thenAnswer((_) async => '999');

        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);

        final room = _MockRoom();
        when(() => room.id).thenReturn(roomId);
        final timeline = _MockTimeline();
        when(() => timeline.events).thenReturn(<Event>[]);
        when(() => timeline.canRequestHistory).thenReturn(false);
        when(timeline.cancelSubscriptions).thenAnswer((_) {});
        when(
          () => room.getTimeline(limit: any(named: 'limit')),
        ).thenAnswer((_) async => timeline);

        when(() => roomManager.currentRoom).thenReturn(room);

        final coordinator = QueuePipelineCoordinator(
          syncDb: syncDb,
          settingsDb: settingsDb,
          journalDb: journalDb,
          sessionManager: sessionManager,
          roomManager: roomManager,
          eventProcessor: processor,
          sequenceLogService: sequenceLog,
          activityGate: null,
          logging: logging,
          queueOverride: realQueue,
          workerOverride: worker,
          penOverride: pen,
          seederOverride: seeder,
        );

        await coordinator.triggerBridge();

        verify(
          () => settingsDb.itemByKey('LAST_READ_MATRIX_EVENT_TS'),
        ).called(1);
      },
    );

    test(
      'bridge logs noRoom when both cache and getRoomById return null',
      () async {
        final realQueue = InboundQueue(db: syncDb, logging: logging);
        addTearDown(realQueue.dispose);

        when(() => roomManager.currentRoom).thenReturn(null);
        when(() => client.getRoomById(any())).thenReturn(null);

        final coordinator = QueuePipelineCoordinator(
          syncDb: syncDb,
          settingsDb: settingsDb,
          journalDb: journalDb,
          sessionManager: sessionManager,
          roomManager: roomManager,
          eventProcessor: processor,
          sequenceLogService: sequenceLog,
          activityGate: null,
          logging: logging,
          queueOverride: realQueue,
          workerOverride: worker,
          penOverride: pen,
          seederOverride: seeder,
        );

        await coordinator.triggerBridge();

        verify(
          () => logging.captureEvent(
            any<String>(that: contains('queue.bridge.skip reason=noRoom')),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).called(1);
      },
    );
  });
}
