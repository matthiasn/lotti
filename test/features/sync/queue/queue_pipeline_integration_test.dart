import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/queue/bridge_coordinator.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _MockSessionManager extends Mock implements MatrixSessionManager {}

class _MockRoomManager extends Mock implements SyncRoomManager {}

class _MockSyncEventProcessor extends Mock implements SyncEventProcessor {}

class _MockVectorClockService extends Mock implements VectorClockService {}

class _MockBridge extends Mock implements BridgeCoordinator {}

class _MockClient extends Mock implements Client {}

class _MockRoom extends Mock implements Room {}

class _MockPreparedSyncEvent extends Mock implements PreparedSyncEvent {}

class _MockEvent extends Mock implements Event {}

Event _buildSyncEvent({
  required String eventId,
  required String roomId,
  required int originTsMs,
}) {
  final event = _MockEvent();
  final content = <String, dynamic>{'msgtype': syncMessageType};
  when(() => event.eventId).thenReturn(eventId);
  when(() => event.roomId).thenReturn(roomId);
  when(() => event.type).thenReturn(EventTypes.Message);
  when(() => event.content).thenReturn(content);
  when(() => event.text).thenReturn('stub');
  when(
    () => event.originServerTs,
  ).thenReturn(DateTime.fromMillisecondsSinceEpoch(originTsMs));
  when(event.toJson).thenReturn(<String, dynamic>{
    'event_id': eventId,
    'room_id': roomId,
    'origin_server_ts': originTsMs,
    'type': EventTypes.Message,
    'sender': '@tester:example.org',
    'content': content,
  });
  return event;
}

void main() {
  late SyncDatabase syncDb;
  late JournalDb journalDb;
  late MockSettingsDb settingsDb;
  late _MockSessionManager sessionManager;
  late _MockRoomManager roomManager;
  late _MockSyncEventProcessor processor;
  late SyncSequenceLogService sequenceLog;
  late MockLoggingService logging;
  late _MockBridge bridge;
  late _MockRoom room;
  late StreamController<Event> timelineCtl;
  late CachedStreamController<SyncUpdate> syncCtl;
  late _MockClient client;
  const roomId = '!roomA:example.org';

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(_MockEvent());
    registerFallbackValue(_MockPreparedSyncEvent());
  });

  setUp(() async {
    syncDb = SyncDatabase(inMemoryDatabase: true);
    journalDb = JournalDb(inMemoryDatabase: true);
    settingsDb = MockSettingsDb();
    sessionManager = _MockSessionManager();
    roomManager = _MockRoomManager();
    processor = _MockSyncEventProcessor();
    sequenceLog = SyncSequenceLogService(
      syncDatabase: syncDb,
      vectorClockService: _MockVectorClockService(),
      loggingService: MockLoggingService(),
    );
    logging = MockLoggingService();
    bridge = _MockBridge();
    room = _MockRoom();
    timelineCtl = StreamController<Event>.broadcast();
    syncCtl = CachedStreamController<SyncUpdate>();
    client = _MockClient();
    when(() => client.onSync).thenReturn(syncCtl);

    when(
      () => sessionManager.timelineEvents,
    ).thenAnswer((_) => timelineCtl.stream);
    when(() => sessionManager.client).thenReturn(client);
    when(() => roomManager.currentRoomId).thenReturn(roomId);
    when(() => roomManager.currentRoom).thenReturn(room);
    when(() => room.id).thenReturn(roomId);
    // Non-partial so the coordinator's _maybePostLoadCurrentRoom
    // short-circuits instead of trying to call room.postLoad() on a
    // bare mock.
    when(() => room.partial).thenReturn(false);
    when(
      () => settingsDb.itemByKey(lastReadMatrixEventId),
    ).thenAnswer((_) async => null);
    when(
      () => settingsDb.itemByKey(lastReadMatrixEventTs),
    ).thenAnswer((_) async => null);
    when(bridge.start).thenReturn(null);
    when(bridge.stop).thenAnswer((_) async {});
  });

  tearDown(() async {
    await timelineCtl.close();
    await syncCtl.close();
    await syncDb.close();
    await journalDb.close();
  });

  test(
    'flag-on path: live event flows through pen → queue → worker → apply',
    () async {
      final prepared = _MockPreparedSyncEvent();
      when(
        () => processor.prepare(event: any(named: 'event')),
      ).thenAnswer((_) async => prepared);
      when(
        () => processor.apply(
          prepared: any(named: 'prepared'),
          journalDb: journalDb,
        ),
      ).thenAnswer((_) async => null);

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
        bridgeOverride: bridge,
      );

      await coordinator.start();
      addTearDown(() => coordinator.stop(drainFirst: true));

      // Emit a live event. The coordinator's subscription routes it
      // through the pen (not encrypted) → enqueueLive → queue row.
      // The running worker loop wakes on the depth signal and applies.
      final event = _buildSyncEvent(
        eventId: r'$live1',
        roomId: roomId,
        originTsMs: 1000,
      );
      timelineCtl.add(event);

      // Let the pipeline finish: enqueue → depth signal → worker
      // wakeup → apply. Pump until the queue empties or the budget
      // expires so the test stays deterministic on slow machines.
      // Budget is generous because a real-timer worker on a loaded
      // CI runner can take multiple seconds to wake + apply; ending
      // assertions should still race ahead once the queue is empty.
      final start = DateTime.now();
      while (DateTime.now().difference(start) < const Duration(seconds: 10)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final stats = await coordinator.queue.stats();
        if (stats.total == 0) break;
      }

      verify(() => processor.prepare(event: any(named: 'event'))).called(1);
      verify(
        () => processor.apply(
          prepared: prepared,
          journalDb: journalDb,
        ),
      ).called(1);

      // Queue is empty post-apply.
      final stats = await coordinator.queue.stats();
      expect(stats.total, 0);

      // Marker advanced under the monotonic guard (F2).
      final marker = await (syncDb.select(
        syncDb.queueMarkers,
      )..where((t) => t.roomId.equals(roomId))).getSingle();
      expect(marker.lastAppliedTs, 1000);
    },
  );

  test(
    'encrypted-then-decrypted event eventually applies via the pen',
    () async {
      final prepared = _MockPreparedSyncEvent();
      when(
        () => processor.prepare(event: any(named: 'event')),
      ).thenAnswer((_) async => prepared);
      when(
        () => processor.apply(
          prepared: any(named: 'prepared'),
          journalDb: journalDb,
        ),
      ).thenAnswer((_) async => null);

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
        bridgeOverride: bridge,
      );
      await coordinator.start();
      addTearDown(() => coordinator.stop(drainFirst: true));

      // Build an encrypted event and a decrypted variant that the SDK
      // would return from `room.getEventById` once the Megolm session
      // key arrives.
      final encrypted = _MockEvent();
      final encryptedContent = <String, dynamic>{
        'msgtype': syncMessageType,
        'algorithm': 'm.megolm.v1.aes-sha2',
      };
      when(() => encrypted.eventId).thenReturn(r'$enc');
      when(() => encrypted.roomId).thenReturn(roomId);
      when(() => encrypted.type).thenReturn(EventTypes.Encrypted);
      when(() => encrypted.content).thenReturn(encryptedContent);
      when(() => encrypted.text).thenReturn('cipher');
      when(
        () => encrypted.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(2000));
      when(encrypted.toJson).thenReturn(<String, dynamic>{
        'event_id': r'$enc',
        'room_id': roomId,
        'origin_server_ts': 2000,
        'type': EventTypes.Encrypted,
        'sender': '@tester:example.org',
        'content': encryptedContent,
      });

      final decrypted = _buildSyncEvent(
        eventId: r'$enc',
        roomId: roomId,
        originTsMs: 2000,
      );
      when(() => room.getEventById(r'$enc')).thenAnswer((_) async => decrypted);

      // Step 1: encrypted event arrives — pen holds it, queue stays empty.
      timelineCtl.add(encrypted);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      final statsAfterHold = await coordinator.queue.stats();
      expect(statsAfterHold.total, 0);

      // Step 2: let the worker loop tick through its pen-flush. The
      // loop's idleTick is 5s, so we trigger another depth-change
      // event to wake it — any plain event routed into the queue
      // triggers the wake.
      final wakeEvent = _buildSyncEvent(
        eventId: r'$wake',
        roomId: roomId,
        originTsMs: 1500,
      );
      timelineCtl.add(wakeEvent);

      final start = DateTime.now();
      while (DateTime.now().difference(start) < const Duration(seconds: 10)) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        final stats = await coordinator.queue.stats();
        if (stats.total == 0) break;
      }

      // Both the wake event and the now-decrypted event applied.
      verify(
        () => processor.apply(
          prepared: prepared,
          journalDb: journalDb,
        ),
      ).called(2);
    },
  );
}
