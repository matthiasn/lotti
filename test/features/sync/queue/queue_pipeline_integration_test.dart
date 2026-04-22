import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_ingestor.dart';
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
  // Integration tests inject events via the coordinator's live
  // timeline; `_handleLiveEvent` drops non-`synced` emissions as SDK
  // fake-sync artefacts.
  when(() => event.status).thenReturn(EventStatus.synced);
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
      when(() => encrypted.status).thenReturn(EventStatus.synced);
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

  test(
    'pendingAttachment → abandoned → AttachmentIndex.record → '
    'resurrection → apply: proves the end-to-end self-healing flow '
    'through real SyncDatabase + real coordinator + real AttachmentIndex',
    () async {
      // Use the real `Directory.systemTemp` as documentsDirectory so
      // the adapter's file reads have somewhere to land. The test
      // does not actually touch disk — the mocked processor handles
      // the simulated attachment race via a flag that flips after
      // the attachment "arrives".
      final prepared = _MockPreparedSyncEvent();
      var attachmentAvailable = false;
      when(() => processor.prepare(event: any(named: 'event'))).thenAnswer((
        _,
      ) async {
        if (!attachmentAvailable) {
          throw const FileSystemException(
            'attachment descriptor not yet available',
          );
        }
        return prepared;
      });
      when(
        () => processor.apply(
          prepared: any(named: 'prepared'),
          journalDb: journalDb,
        ),
      ).thenAnswer((_) async => null);

      final attachmentIndex = AttachmentIndex(logging: MockLoggingService());
      addTearDown(attachmentIndex.dispose);

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
        attachmentIndex: attachmentIndex,
      );
      await coordinator.start();
      addTearDown(() => coordinator.stop(drainFirst: true));

      // Emit a sync event referencing an attachment JSON path. The
      // coordinator's enqueue path reads `jsonPath` from the event
      // content and persists it on the queue row so the later
      // resurrection-by-path lookup has something to match.
      const path = '/audio/2026-04-21/pending.m4a.json';
      final event = _MockEvent();
      final content = <String, dynamic>{
        'msgtype': syncMessageType,
        'jsonPath': path,
      };
      when(() => event.eventId).thenReturn(r'$pendingAttach');
      when(() => event.roomId).thenReturn(roomId);
      when(() => event.type).thenReturn(EventTypes.Message);
      when(() => event.status).thenReturn(EventStatus.synced);
      when(() => event.content).thenReturn(content);
      when(() => event.text).thenReturn('stub');
      when(
        () => event.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(3000));
      when(event.toJson).thenReturn(<String, dynamic>{
        'event_id': r'$pendingAttach',
        'room_id': roomId,
        'origin_server_ts': 3000,
        'type': EventTypes.Message,
        'sender': '@tester:example.org',
        'content': content,
      });

      timelineCtl.add(event);

      // Phase 1 — wait for the row to hit the pendingAttachment cap
      // and land in `abandoned`. The worker's pendingAttachment
      // ladder is human-scale in production; we use a shorter cap
      // here by manually flipping the row to abandoned once we see
      // the first retry attempt, then `attemptsExhausted` mimics
      // the "worker gave up" terminal state. This keeps the test
      // deterministic and under the 10s budget.
      {
        final start = DateTime.now();
        while (DateTime.now().difference(start) < const Duration(seconds: 10)) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          final stats = await coordinator.queue.stats();
          if (stats.retrying > 0 || stats.abandoned > 0) break;
        }
        // Transition the retrying row straight to abandoned so we can
        // exercise resurrection without sleeping through the full
        // 30s → 10min ladder.
        final entries = await (syncDb.select(
          syncDb.inboundEventQueue,
        )..where((t) => t.eventId.equals(r'$pendingAttach'))).get();
        expect(entries, hasLength(1));
        await (syncDb.update(
          syncDb.inboundEventQueue,
        )..where((t) => t.queueId.equals(entries.first.queueId))).write(
          InboundEventQueueCompanion(
            status: const Value('abandoned'),
            abandonedAt: Value(
              DateTime.now().millisecondsSinceEpoch,
            ),
            lastErrorReason: const Value('maxAttempts(pendingAttachment)'),
          ),
        );
      }

      // Sanity check: the row is abandoned, the path column carries
      // our attachment key, no prepare/apply happened since the
      // pending race started.
      {
        final abandoned = await (syncDb.select(
          syncDb.inboundEventQueue,
        )..where((t) => t.eventId.equals(r'$pendingAttach'))).getSingle();
        expect(abandoned.status, 'abandoned');
        expect(abandoned.jsonPath, path);
      }

      // Phase 2 — simulate the attachment landing. We flip the
      // processor's retriable flag so the next prepare succeeds,
      // then record an attachment event for the matching path. The
      // coordinator's `pathRecorded` subscription fires, calls
      // `queue.resurrectByPath`, and the worker wakes.
      attachmentAvailable = true;

      final attachmentEvent = _MockEvent();
      when(() => attachmentEvent.content).thenReturn(<String, dynamic>{
        'relativePath': path,
      });
      when(() => attachmentEvent.eventId).thenReturn(r'$attachmentLanded');
      when(
        () => attachmentEvent.attachmentMimetype,
      ).thenReturn('application/json');
      attachmentIndex.record(attachmentEvent);

      // Phase 3 — wait for resurrection + apply + marker advance.
      {
        final start = DateTime.now();
        while (DateTime.now().difference(start) < const Duration(seconds: 10)) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          final stats = await coordinator.queue.stats();
          if (stats.applied > 0) break;
        }
      }

      verify(
        () => processor.apply(
          prepared: prepared,
          journalDb: journalDb,
        ),
      ).called(1);

      final applied = await (syncDb.select(
        syncDb.inboundEventQueue,
      )..where((t) => t.eventId.equals(r'$pendingAttach'))).getSingle();
      expect(applied.status, 'applied');
      expect(applied.resurrectionCount, 1);

      final marker = await (syncDb.select(
        syncDb.queueMarkers,
      )..where((t) => t.roomId.equals(roomId))).getSingle();
      expect(marker.lastAppliedTs, 3000);
    },
  );

  test(
    'live attachment descriptor event: coordinator runs it through '
    'AttachmentIngestor, which records it in AttachmentIndex, which '
    'fires pathRecorded, which resurrects the abandoned sync-payload '
    'row — full production chain with no manual index poking',
    () async {
      final prepared = _MockPreparedSyncEvent();
      var attachmentAvailable = false;
      when(() => processor.prepare(event: any(named: 'event'))).thenAnswer((
        _,
      ) async {
        if (!attachmentAvailable) {
          throw const FileSystemException(
            'attachment descriptor not yet available',
          );
        }
        return prepared;
      });
      when(
        () => processor.apply(
          prepared: any(named: 'prepared'),
          journalDb: journalDb,
        ),
      ).thenAnswer((_) async => null);

      final attachmentIndex = AttachmentIndex(logging: MockLoggingService());
      addTearDown(attachmentIndex.dispose);
      // documentsDirectory=null skips the download step — we only
      // need the ingestor's record() side effect, which runs before
      // any download work and fires `pathRecorded`. A real device
      // would pass its documents dir and actually save the JSON.
      final ingestor = AttachmentIngestor();
      addTearDown(ingestor.dispose);

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
        attachmentIndex: attachmentIndex,
        attachmentIngestor: ingestor,
      );
      await coordinator.start();
      addTearDown(() => coordinator.stop(drainFirst: true));

      // Phase 1 — a sync-payload event references an attachment
      // that has not landed yet. The worker retries once, we flip
      // it straight to abandoned to skip the real 30 s ladder.
      const path = '/audio/2026-04-21/descriptor-live.m4a.json';
      final syncEvent = _MockEvent();
      final syncContent = <String, dynamic>{
        'msgtype': syncMessageType,
        'jsonPath': path,
      };
      when(() => syncEvent.eventId).thenReturn(r'$liveSyncAwaiting');
      when(() => syncEvent.roomId).thenReturn(roomId);
      when(() => syncEvent.type).thenReturn(EventTypes.Message);
      when(() => syncEvent.status).thenReturn(EventStatus.synced);
      when(() => syncEvent.content).thenReturn(syncContent);
      when(() => syncEvent.text).thenReturn('stub');
      when(
        () => syncEvent.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(4000));
      when(syncEvent.toJson).thenReturn(<String, dynamic>{
        'event_id': r'$liveSyncAwaiting',
        'room_id': roomId,
        'origin_server_ts': 4000,
        'type': EventTypes.Message,
        'sender': '@tester:example.org',
        'content': syncContent,
      });

      timelineCtl.add(syncEvent);

      // Wait for the row to become retrying; then flip to abandoned
      // (shortcut past the production ladder).
      {
        final start = DateTime.now();
        while (DateTime.now().difference(start) < const Duration(seconds: 10)) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          final stats = await coordinator.queue.stats();
          if (stats.retrying > 0 || stats.abandoned > 0) break;
        }
        final entries = await (syncDb.select(
          syncDb.inboundEventQueue,
        )..where((t) => t.eventId.equals(r'$liveSyncAwaiting'))).get();
        expect(entries, hasLength(1));
        await (syncDb.update(
          syncDb.inboundEventQueue,
        )..where((t) => t.queueId.equals(entries.first.queueId))).write(
          InboundEventQueueCompanion(
            status: const Value('abandoned'),
            abandonedAt: Value(
              DateTime.now().millisecondsSinceEpoch,
            ),
            lastErrorReason: const Value('maxAttempts(pendingAttachment)'),
          ),
        );
      }

      // Phase 2 — the attachment descriptor event lands on the
      // coordinator's live stream. The coordinator runs it through
      // `AttachmentIngestor.process` which calls
      // `attachmentIndex.record(event)` synchronously. That fires
      // `pathRecorded` → the coordinator's own subscription calls
      // `queue.resurrectByPath(path)` → the row flips back to
      // `enqueued` and the next prepare succeeds (we flip the flag
      // right before emitting the event).
      attachmentAvailable = true;

      final attachmentEvent = _MockEvent();
      final attachmentContent = <String, dynamic>{
        'relativePath': path,
      };
      when(() => attachmentEvent.eventId).thenReturn(r'$descriptorLanded');
      when(() => attachmentEvent.roomId).thenReturn(roomId);
      when(() => attachmentEvent.type).thenReturn(EventTypes.Message);
      when(() => attachmentEvent.status).thenReturn(EventStatus.synced);
      when(() => attachmentEvent.content).thenReturn(attachmentContent);
      when(() => attachmentEvent.text).thenReturn('attachment');
      when(
        () => attachmentEvent.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(4500));
      when(
        () => attachmentEvent.attachmentMimetype,
      ).thenReturn('application/json');
      when(attachmentEvent.toJson).thenReturn(<String, dynamic>{
        'event_id': r'$descriptorLanded',
        'room_id': roomId,
        'origin_server_ts': 4500,
        'type': EventTypes.Message,
        'sender': '@tester:example.org',
        'content': attachmentContent,
      });

      timelineCtl.add(attachmentEvent);

      // Phase 3 — wait for resurrection + apply.
      {
        final start = DateTime.now();
        while (DateTime.now().difference(start) < const Duration(seconds: 10)) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          final stats = await coordinator.queue.stats();
          if (stats.applied > 0) break;
        }
      }

      verify(
        () => processor.apply(
          prepared: prepared,
          journalDb: journalDb,
        ),
      ).called(1);

      final applied = await (syncDb.select(
        syncDb.inboundEventQueue,
      )..where((t) => t.eventId.equals(r'$liveSyncAwaiting'))).getSingle();
      expect(applied.status, 'applied');
      expect(applied.resurrectionCount, 1);
    },
  );
}
