import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
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
}
