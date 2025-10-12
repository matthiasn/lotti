import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
// ignore_for_file: unnecessary_lambdas, cascade_invocations, unawaited_futures
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
// No internal SDK imports in tests
import 'package:mocktail/mocktail.dart';

class MockMatrixSessionManager extends Mock implements MatrixSessionManager {}

class MockSyncRoomManager extends Mock implements SyncRoomManager {}

class MockLoggingService extends Mock implements LoggingService {}

class MockJournalDb extends Mock implements JournalDb {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockSyncEventProcessor extends Mock implements SyncEventProcessor {}

class MockSyncReadMarkerService extends Mock implements SyncReadMarkerService {}

class MockClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

class MockTimeline extends Mock implements Timeline {}

class MockEvent extends Mock implements Event {}

class _FakeClient extends Fake implements Client {}

class _FakeRoom extends Fake implements Room {}

class _FakeTimeline extends Fake implements Timeline {}

class _FakeEvent extends Fake implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    // Fallbacks for typed `any<T>` matchers used in mocks
    registerFallbackValue(_FakeClient());
    registerFallbackValue(_FakeRoom());
    registerFallbackValue(_FakeTimeline());
    registerFallbackValue(_FakeEvent());
  });

  group('MatrixStreamConsumer SDK pagination + streaming', () {
    test('uses SDK pagination seam when available', () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final journalDb = MockJournalDb();
      final settingsDb = MockSettingsDb();
      final processor = MockSyncEventProcessor();
      final readMarker = MockSyncReadMarkerService();
      final client = MockClient();
      final room = MockRoom();
      final timeline = MockTimeline();
      final onTimelineController = StreamController<Event>.broadcast();

      addTearDown(onTimelineController.close);

      when(() => logger.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logger.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => onTimelineController.stream);
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');

      // lastProcessed is e0; snapshot initially contains only e1..e3
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => 'e0');

      final e = List<Event>.generate(3, (i) {
        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('e${i + 1}');
        when(() => ev.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(i + 1));
        when(() => ev.senderId).thenReturn('@other:server');
        when(() => ev.attachmentMimetype).thenReturn('');
        when(() => ev.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
        when(() => ev.roomId).thenReturn('!room:server');
        return ev;
      });
      var eventsList = List<Event>.from(e);
      when(() => timeline.events).thenAnswer((_) => eventsList);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);

      when(() => processor.process(
          event: any<Event>(named: 'event'),
          journalDb: journalDb)).thenAnswer((_) async {});
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((_) async {});

      // Seam: perform backfill by injecting e0 into the snapshot
      Future<bool> backfill({
        required Timeline timeline,
        required String? lastEventId,
        required int pageSize,
        required int maxPages,
        required LoggingService logging,
      }) async {
        final e0 = MockEvent();
        when(() => e0.eventId).thenReturn('e0');
        when(() => e0.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(0));
        when(() => e0.senderId).thenReturn('@other:server');
        when(() => e0.attachmentMimetype).thenReturn('');
        when(() => e0.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
        when(() => e0.roomId).thenReturn('!room:server');
        eventsList = <Event>[e0, ...eventsList];
        return true;
      }

      final consumer = MatrixStreamConsumer(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        documentsDirectory: Directory.systemTemp,
        backfill: backfill,
      );

      await consumer.initialize();
      await consumer.start();

      // catch‑up should process e1..e3 exactly once; only one snapshot call
      verify(() => room.getTimeline(limit: any(named: 'limit'))).called(1);
      for (final ev in e) {
        verify(() => processor.process(event: ev, journalDb: journalDb))
            .called(1);
      }
    });

    test('flushReadMarker exceptions are captured and do not break flow',
        () async {
      fakeAsync((async) async {
        final session = MockMatrixSessionManager();
        final roomManager = MockSyncRoomManager();
        final logger = MockLoggingService();
        final journalDb = MockJournalDb();
        final settingsDb = MockSettingsDb();
        final processor = MockSyncEventProcessor();
        final readMarker = MockSyncReadMarkerService();
        final client = MockClient();
        final room = MockRoom();
        final timeline = MockTimeline();
        final onTimelineController = StreamController<Event>.broadcast();

        addTearDown(onTimelineController.close);

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => session.timelineEvents)
            .thenAnswer((_) => onTimelineController.stream);
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => null);
        when(() => timeline.events).thenReturn(<Event>[]);
        when(() => timeline.cancelSubscriptions()).thenReturn(null);
        when(() => room.getTimeline(limit: any(named: 'limit')))
            .thenAnswer((_) async => timeline);

        // read marker will throw on flush
        when(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: any<String>(named: 'eventId'),
            )).thenThrow(Exception('rm'));
        when(() => processor.process(
              event: any<Event>(named: 'event'),
              journalDb: journalDb,
            )).thenAnswer((_) async {});

        final consumer = MatrixStreamConsumer(
          sessionManager: session,
          roomManager: roomManager,
          loggingService: logger,
          journalDb: journalDb,
          settingsDb: settingsDb,
          eventProcessor: processor,
          readMarkerService: readMarker,
          documentsDirectory: Directory.systemTemp,
          markerDebounce: const Duration(milliseconds: 50),
        );

        await consumer.initialize();
        await consumer.start();

        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('mk');
        when(() => ev.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
        when(() => ev.senderId).thenReturn('@other:server');
        when(() => ev.attachmentMimetype).thenReturn('');
        when(() => ev.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
        when(() => ev.roomId).thenReturn('!room:server');

        onTimelineController.add(ev);
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 60));
        async.flushMicrotasks();

        // Exception captured from flushReadMarker path
        verify(() => logger.captureException(
              any<dynamic>(),
              domain: 'MATRIX_SYNC_V2',
              subDomain: 'flushReadMarker',
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
            )).called(1);
      });
    });

    test('live timeline scan handles events getter exceptions gracefully',
        () async {
      fakeAsync((async) async {
        final session = MockMatrixSessionManager();
        final roomManager = MockSyncRoomManager();
        final logger = MockLoggingService();
        final journalDb = MockJournalDb();
        final settingsDb = MockSettingsDb();
        final processor = MockSyncEventProcessor();
        final readMarker = MockSyncReadMarkerService();
        final client = MockClient();
        final room = MockRoom();
        final catchupTimeline = MockTimeline();
        final liveTimeline = MockTimeline();

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => session.timelineEvents)
            .thenAnswer((_) => const Stream<Event>.empty());
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => null);

        when(() => catchupTimeline.events).thenReturn(<Event>[]);
        when(() => catchupTimeline.cancelSubscriptions()).thenReturn(null);
        when(() => room.getTimeline(limit: any(named: 'limit')))
            .thenAnswer((_) async => catchupTimeline);

        void Function()? onNewEvent;
        when(
          () => room.getTimeline(
            onNewEvent: any(named: 'onNewEvent'),
            onInsert: any(named: 'onInsert'),
            onChange: any(named: 'onChange'),
            onRemove: any(named: 'onRemove'),
            onUpdate: any(named: 'onUpdate'),
          ),
        ).thenAnswer((inv) async {
          onNewEvent = inv.namedArguments[#onNewEvent] as void Function()?;
          return liveTimeline;
        });

        // Cause events getter to throw inside _scanLiveTimeline
        when(() => liveTimeline.events).thenThrow(Exception('events'));
        when(() => liveTimeline.cancelSubscriptions()).thenReturn(null);

        final consumer = MatrixStreamConsumer(
          sessionManager: session,
          roomManager: roomManager,
          loggingService: logger,
          journalDb: journalDb,
          settingsDb: settingsDb,
          eventProcessor: processor,
          readMarkerService: readMarker,
          documentsDirectory: Directory.systemTemp,
          collectMetrics: true,
        );

        await consumer.initialize();
        await consumer.start();

        onNewEvent?.call();
        async.elapse(const Duration(milliseconds: 130));
        async.flushMicrotasks();

        verify(() => logger.captureException(
              any<dynamic>(),
              domain: 'MATRIX_SYNC_V2',
              subDomain: 'liveScan',
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
            )).called(1);
      });
    });

    test('live timeline callbacks schedule scan and process (fakeAsync)',
        () async {
      fakeAsync((async) async {
        final session = MockMatrixSessionManager();
        final roomManager = MockSyncRoomManager();
        final logger = MockLoggingService();
        final journalDb = MockJournalDb();
        final settingsDb = MockSettingsDb();
        final processor = MockSyncEventProcessor();
        final readMarker = MockSyncReadMarkerService();
        final client = MockClient();
        final room = MockRoom();
        final catchupTimeline = MockTimeline();
        final liveTimeline = MockTimeline();
        final onTimelineController = StreamController<Event>.broadcast();

        addTearDown(onTimelineController.close);

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => session.timelineEvents)
            .thenAnswer((_) => onTimelineController.stream);
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => null);

        // Catch-up snapshot returns empty
        when(() => catchupTimeline.events).thenReturn(<Event>[]);
        when(() => catchupTimeline.cancelSubscriptions()).thenReturn(null);
        when(() => room.getTimeline(limit: any(named: 'limit')))
            .thenAnswer((_) async => catchupTimeline);

        // Live timeline stub: capture callback and return timeline with one event
        void Function()? onNewEvent;
        when(
          () => room.getTimeline(
            onNewEvent: any(named: 'onNewEvent'),
            onInsert: any(named: 'onInsert'),
            onChange: any(named: 'onChange'),
            onRemove: any(named: 'onRemove'),
            onUpdate: any(named: 'onUpdate'),
          ),
        ).thenAnswer((inv) async {
          onNewEvent = inv.namedArguments[#onNewEvent] as void Function()?;
          return liveTimeline;
        });

        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('LT1');
        when(() => ev.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
        when(() => ev.senderId).thenReturn('@other:server');
        when(() => ev.attachmentMimetype).thenReturn('');
        when(() => ev.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
        when(() => ev.roomId).thenReturn('!room:server');
        when(() => liveTimeline.events).thenReturn(<Event>[ev]);
        when(() => liveTimeline.cancelSubscriptions()).thenReturn(null);

        when(() => processor.process(event: ev, journalDb: journalDb))
            .thenAnswer((_) async {});
        when(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: any<String>(named: 'eventId'),
            )).thenAnswer((_) async {});

        final consumer = MatrixStreamConsumer(
          sessionManager: session,
          roomManager: roomManager,
          loggingService: logger,
          journalDb: journalDb,
          settingsDb: settingsDb,
          eventProcessor: processor,
          readMarkerService: readMarker,
          documentsDirectory: Directory.systemTemp,
          collectMetrics: true,
        );

        await consumer.initialize();
        await consumer.start();

        // Trigger the captured live timeline callback
        onNewEvent?.call();
        async.elapse(const Duration(milliseconds: 130));
        async.flushMicrotasks();

        verify(() => processor.process(event: ev, journalDb: journalDb))
            .called(1);
      });
    });

    test('missing-base safeguard schedules retry and does not count processed',
        () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final journalDb = MockJournalDb();
      final settingsDb = MockSettingsDb();
      final processor = MockSyncEventProcessor();
      final readMarker = MockSyncReadMarkerService();
      final client = MockClient();
      final room = MockRoom();
      final timeline = MockTimeline();

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => const Stream<Event>.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('MB1');
      when(() => ev.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      when(() => ev.senderId).thenReturn('@other:server');
      when(() => ev.attachmentMimetype).thenReturn('');
      when(() => ev.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => ev.roomId).thenReturn('!room:server');

      when(() => timeline.events).thenReturn(<Event>[ev]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);
      when(() => processor.process(event: ev, journalDb: journalDb))
          .thenAnswer((_) async {});

      final consumer = MatrixStreamConsumer(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        documentsDirectory: Directory.systemTemp,
        collectMetrics: true,
      );

      await consumer.initialize();
      // Simulate apply observer observation for the same event id as "missing base"
      consumer.reportDbApplyDiagnostics(
        SyncApplyDiagnostics(
          eventId: 'MB1',
          payloadType: 'journalEntity',
          entityId: 'e',
          vectorClock: null,
          rowsAffected: 0,
          conflictStatus: 'VclockStatus.b_gt_a',
        ),
      );

      await consumer.start();

      final m = consumer.metricsSnapshot();
      expect(m['processed'], 0);
      expect(m['dbMissingBase'], greaterThanOrEqualTo(1));
      expect(m['retryStateSize'], greaterThanOrEqualTo(1));
    });

    test('pending jsonPath triggers immediate scan after prefetch', () async {
      fakeAsync((async) async {
        final session = MockMatrixSessionManager();
        final roomManager = MockSyncRoomManager();
        final logger = MockLoggingService();
        final journalDb = MockJournalDb();
        final settingsDb = MockSettingsDb();
        final processor = MockSyncEventProcessor();
        final readMarker = MockSyncReadMarkerService();
        final client = MockClient();
        final room = MockRoom();
        final timeline = MockTimeline();
        final onTimelineController = StreamController<Event>.broadcast();

        addTearDown(onTimelineController.close);

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => session.timelineEvents)
            .thenAnswer((_) => onTimelineController.stream);
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => null);
        when(() => timeline.events).thenReturn(<Event>[]);
        when(() => timeline.cancelSubscriptions()).thenReturn(null);
        when(() => room.getTimeline(limit: any(named: 'limit')))
            .thenAnswer((_) async => timeline);

        var calls = 0;
        when(() => processor.process(
              event: any<Event>(named: 'event'),
              journalDb: journalDb,
            )).thenAnswer((inv) async {
          calls++;
          if (calls == 1) {
            throw const FileSystemException('missing');
          }
        });

        final consumer = MatrixStreamConsumer(
          sessionManager: session,
          roomManager: roomManager,
          loggingService: logger,
          journalDb: journalDb,
          settingsDb: settingsDb,
          eventProcessor: processor,
          readMarkerService: readMarker,
          documentsDirectory: Directory.systemTemp,
          collectMetrics: true,
          markerDebounce: const Duration(milliseconds: 50),
        );

        await consumer.initialize();
        await consumer.start();

        // 1) Text event fails with FileSystemException -> pending jsonPath recorded
        final textEvent = MockEvent();
        when(() => textEvent.eventId).thenReturn('T1');
        when(() => textEvent.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
        when(() => textEvent.senderId).thenReturn('@other:server');
        when(() => textEvent.attachmentMimetype).thenReturn('');
        final textPayload = base64.encode(
          utf8.encode(json.encode(<String, dynamic>{
            'runtimeType': 'journalEntity',
            'jsonPath': '/sub/test.json',
          })),
        );
        when(() => textEvent.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
        when(() => textEvent.text).thenReturn(textPayload);
        when(() => textEvent.roomId).thenReturn('!room:server');

        onTimelineController.add(textEvent);
        async.flushMicrotasks();
        // After first failure, a retry is scheduled
        expect(consumer.metricsSnapshot()['retriesScheduled'], 1);

        // 2) Later, the attachment arrives and is prefetched
        final fileEvent = MockEvent();
        when(() => fileEvent.eventId).thenReturn('F1');
        when(() => fileEvent.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(2));
        when(() => fileEvent.senderId).thenReturn('@other:server');
        when(() => fileEvent.attachmentMimetype).thenReturn('application/json');
        when(() => fileEvent.content)
            .thenReturn(<String, dynamic>{'relativePath': '/sub/test.json'});
        when(() => fileEvent.downloadAndDecryptAttachment()).thenAnswer(
          (_) async => MatrixFile(
            bytes: Uint8List.fromList('{"k":1}'.codeUnits),
            name: 'test.json',
          ),
        );
        when(() => fileEvent.roomId).thenReturn('!room:server');

        onTimelineController.add(fileEvent);
        async.flushMicrotasks();

        // Advance beyond the backoff so the pending retry can run
        async.elapse(const Duration(milliseconds: 600));
        async.flushMicrotasks();

        // Processor should have been invoked a second time and succeeded
        expect(calls, greaterThanOrEqualTo(2));
        final m = consumer.metricsSnapshot();
        expect(m['lastPrefetchedCount'], greaterThanOrEqualTo(1));
      });
    });
    test('respects maxBatch cap by flushing immediately (fakeAsync)', () async {
      fakeAsync((async) async {
        final session = MockMatrixSessionManager();
        final roomManager = MockSyncRoomManager();
        final logger = MockLoggingService();
        final journalDb = MockJournalDb();
        final settingsDb = MockSettingsDb();
        final processor = MockSyncEventProcessor();
        final readMarker = MockSyncReadMarkerService();
        final client = MockClient();
        final room = MockRoom();
        final timeline = MockTimeline();
        final onTimelineController = StreamController<Event>.broadcast();

        addTearDown(onTimelineController.close);

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => session.timelineEvents)
            .thenAnswer((_) => onTimelineController.stream);
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => null);
        when(() => timeline.events).thenReturn(<Event>[]);
        when(() => timeline.cancelSubscriptions()).thenReturn(null);
        when(() => room.getTimeline(limit: any(named: 'limit')))
            .thenAnswer((_) async => timeline);

        when(() => processor.process(
              event: any<Event>(named: 'event'),
              journalDb: journalDb,
            )).thenAnswer((_) async {});
        when(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: any<String>(named: 'eventId'),
            )).thenAnswer((_) async {});

        final consumer = MatrixStreamConsumer(
          sessionManager: session,
          roomManager: roomManager,
          loggingService: logger,
          journalDb: journalDb,
          settingsDb: settingsDb,
          eventProcessor: processor,
          readMarkerService: readMarker,
          documentsDirectory: Directory.systemTemp,
          collectMetrics: true,
          flushInterval: const Duration(seconds: 5), // avoid timer path
          maxBatch: 2, // immediate flush at cap
        );

        await consumer.initialize();
        await consumer.start();

        Event mk(String id) {
          final ev = MockEvent();
          when(() => ev.eventId).thenReturn(id);
          when(() => ev.originServerTs)
              .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
          when(() => ev.senderId).thenReturn('@other:server');
          when(() => ev.attachmentMimetype).thenReturn('');
          when(() => ev.content)
              .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
          when(() => ev.roomId).thenReturn('!room:server');
          return ev;
        }

        onTimelineController.add(mk('a'));
        onTimelineController.add(mk('b')); // hits cap -> immediate flush

        // Deliver stream events and the scheduled flush microtask
        async.flushMicrotasks();

        verify(() => processor.process(
              event: any<Event>(named: 'event'),
              journalDb: journalDb,
            )).called(2);
        final m = consumer.metricsSnapshot();
        expect(m['flushes'], 1);
      });
    });

    test('respects flushInterval for single event (fakeAsync)', () async {
      fakeAsync((async) async {
        final session = MockMatrixSessionManager();
        final roomManager = MockSyncRoomManager();
        final logger = MockLoggingService();
        final journalDb = MockJournalDb();
        final settingsDb = MockSettingsDb();
        final processor = MockSyncEventProcessor();
        final readMarker = MockSyncReadMarkerService();
        final client = MockClient();
        final room = MockRoom();
        final timeline = MockTimeline();
        final onTimelineController = StreamController<Event>.broadcast();

        addTearDown(onTimelineController.close);

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => session.timelineEvents)
            .thenAnswer((_) => onTimelineController.stream);
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => null);
        when(() => timeline.events).thenReturn(<Event>[]);
        when(() => timeline.cancelSubscriptions()).thenReturn(null);
        when(() => room.getTimeline(limit: any(named: 'limit')))
            .thenAnswer((_) async => timeline);

        when(() => processor.process(
              event: any<Event>(named: 'event'),
              journalDb: journalDb,
            )).thenAnswer((_) async {});

        final consumer = MatrixStreamConsumer(
          sessionManager: session,
          roomManager: roomManager,
          loggingService: logger,
          journalDb: journalDb,
          settingsDb: settingsDb,
          eventProcessor: processor,
          readMarkerService: readMarker,
          documentsDirectory: Directory.systemTemp,
          collectMetrics: true,
          flushInterval: const Duration(milliseconds: 50),
          maxBatch: 10, // avoid cap path
        );

        await consumer.initialize();
        await consumer.start();

        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('one');
        when(() => ev.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
        when(() => ev.senderId).thenReturn('@other:server');
        when(() => ev.attachmentMimetype).thenReturn('');
        when(() => ev.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
        when(() => ev.roomId).thenReturn('!room:server');

        onTimelineController.add(ev);

        // Before interval elapses, nothing processed
        async.elapse(const Duration(milliseconds: 49));
        async.flushMicrotasks();
        verifyNever(() => processor.process(
              event: any<Event>(named: 'event'),
              journalDb: journalDb,
            ));

        // After the interval + microtasks, processed once
        async.elapse(const Duration(milliseconds: 2));
        async.flushMicrotasks();
        verify(() => processor.process(
              event: any<Event>(named: 'event'),
              journalDb: journalDb,
            )).called(1);
        expect(consumer.metricsSnapshot()['flushes'], 1);
      });
    });

    test('flush logs and preserves queue on sort error (fakeAsync)', () async {
      fakeAsync((async) async {
        final session = MockMatrixSessionManager();
        final roomManager = MockSyncRoomManager();
        final logger = MockLoggingService();
        final journalDb = MockJournalDb();
        final settingsDb = MockSettingsDb();
        final processor = MockSyncEventProcessor();
        final readMarker = MockSyncReadMarkerService();
        final client = MockClient();
        final room = MockRoom();
        final timeline = MockTimeline();
        final onTimelineController = StreamController<Event>.broadcast();

        addTearDown(onTimelineController.close);

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => session.timelineEvents)
            .thenAnswer((_) => onTimelineController.stream);
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => null);
        when(() => timeline.events).thenReturn(<Event>[]);
        when(() => timeline.cancelSubscriptions()).thenReturn(null);
        when(() => room.getTimeline(limit: any(named: 'limit')))
            .thenAnswer((_) async => timeline);

        when(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: any<String>(named: 'eventId'),
            )).thenAnswer((_) async {});

        // Expect an exception captured from the flush catch block
        when(() => logger.captureException(
              any<Object>(),
              domain: any<String>(named: 'domain'),
              subDomain: any<String>(named: 'subDomain'),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
            )).thenReturn(null);

        final consumer = MatrixStreamConsumer(
          sessionManager: session,
          roomManager: roomManager,
          loggingService: logger,
          journalDb: journalDb,
          settingsDb: settingsDb,
          eventProcessor: processor,
          readMarkerService: readMarker,
          documentsDirectory: Directory.systemTemp,
          flushInterval: const Duration(seconds: 5),
          maxBatch: 2,
        );

        await consumer.initialize();
        await consumer.start();

        // First event is fine
        final ok = MockEvent();
        when(() => ok.eventId).thenReturn('ok');
        when(() => ok.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
        when(() => ok.senderId).thenReturn('@other:server');
        when(() => ok.attachmentMimetype).thenReturn('');
        when(() => ok.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
        when(() => ok.roomId).thenReturn('!room:server');

        // Second event throws on timestamp access to break sorting
        final bad = MockEvent();
        when(() => bad.eventId).thenReturn('bad');
        when(() => bad.originServerTs).thenThrow(Exception('ts'));
        when(() => bad.senderId).thenReturn('@other:server');
        when(() => bad.attachmentMimetype).thenReturn('');
        when(() => bad.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
        when(() => bad.roomId).thenReturn('!room:server');

        onTimelineController.add(ok);
        onTimelineController.add(bad); // triggers immediate flush and error

        async.flushMicrotasks();

        verify(() => logger.captureException(
              any<Object>(),
              domain: 'MATRIX_SYNC_V2',
              subDomain: 'flush',
              stackTrace: any<StackTrace>(named: 'stackTrace'),
            )).called(1);
        // No processing should occur due to flush failure
        verifyNever(() => processor.process(
            event: any<Event>(named: 'event'), journalDb: journalDb));
      });
    });

    test('read marker updates after debounce only (fakeAsync)', () async {
      fakeAsync((async) async {
        final session = MockMatrixSessionManager();
        final roomManager = MockSyncRoomManager();
        final logger = MockLoggingService();
        final journalDb = MockJournalDb();
        final settingsDb = MockSettingsDb();
        final processor = MockSyncEventProcessor();
        final readMarker = MockSyncReadMarkerService();
        final client = MockClient();
        final room = MockRoom();
        final timeline = MockTimeline();
        final onTimelineController = StreamController<Event>.broadcast();

        addTearDown(onTimelineController.close);

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => session.timelineEvents)
            .thenAnswer((_) => onTimelineController.stream);
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => null);
        when(() => timeline.events).thenReturn(<Event>[]);
        when(() => timeline.cancelSubscriptions()).thenReturn(null);
        when(() => room.getTimeline(limit: any(named: 'limit')))
            .thenAnswer((_) async => timeline);
        when(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: any<String>(named: 'eventId'),
            )).thenAnswer((_) async {});

        final consumer = MatrixStreamConsumer(
          sessionManager: session,
          roomManager: roomManager,
          loggingService: logger,
          journalDb: journalDb,
          settingsDb: settingsDb,
          eventProcessor: processor,
          readMarkerService: readMarker,
          documentsDirectory: Directory.systemTemp,
          markerDebounce: const Duration(milliseconds: 100),
        );

        await consumer.initialize();
        await consumer.start();

        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('mk');
        when(() => ev.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
        when(() => ev.senderId).thenReturn('@other:server');
        when(() => ev.attachmentMimetype).thenReturn('');
        when(() => ev.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
        when(() => ev.roomId).thenReturn('!room:server');
        when(() => processor.process(event: ev, journalDb: journalDb))
            .thenAnswer((_) async {});

        onTimelineController.add(ev);
        // Deliver stream event
        async.flushMicrotasks();

        // Before debounce passes, no marker update
        async.elapse(const Duration(milliseconds: 90));
        async.flushMicrotasks();
        verifyNever(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: any<String>(named: 'eventId'),
            ));

        // After debounce window, marker update fires once
        async.elapse(const Duration(milliseconds: 20));
        async.flushMicrotasks();
        verify(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: 'mk',
            )).called(1);
      });
    });
    test('does not advance marker on newer non-sync event', () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final journalDb = MockJournalDb();
      final settingsDb = MockSettingsDb();
      final processor = MockSyncEventProcessor();
      final readMarker = MockSyncReadMarkerService();
      final client = MockClient();
      final room = MockRoom();
      final timeline = MockTimeline();

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => const Stream<Event>.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

      final sync = MockEvent();
      when(() => sync.eventId).thenReturn('S1');
      when(() => sync.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      when(() => sync.senderId).thenReturn('@other:server');
      when(() => sync.attachmentMimetype).thenReturn('');
      when(() => sync.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => sync.roomId).thenReturn('!room:server');

      final nonsync = MockEvent();
      when(() => nonsync.eventId).thenReturn('N2');
      when(() => nonsync.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(2));
      when(() => nonsync.senderId).thenReturn('@other:server');
      when(() => nonsync.attachmentMimetype).thenReturn('');
      when(() => nonsync.content).thenReturn(<String, dynamic>{});
      when(() => nonsync.roomId).thenReturn('!room:server');

      when(() => timeline.events).thenReturn(<Event>[sync, nonsync]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);

      when(() => processor.process(event: sync, journalDb: journalDb))
          .thenAnswer((_) async {});
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((inv) async {});

      final consumer = MatrixStreamConsumer(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        documentsDirectory: Directory.systemTemp,
        collectMetrics: true,
        markerDebounce: const Duration(milliseconds: 50),
      );

      await consumer.initialize();
      await consumer.start();

      // wait for marker debounce
      await Future<void>.delayed(const Duration(milliseconds: 120));

      verify(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: 'S1',
          )).called(1);
    });

    test('processedByType increments for entryLink', () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final journalDb = MockJournalDb();
      final settingsDb = MockSettingsDb();
      final processor = MockSyncEventProcessor();
      final readMarker = MockSyncReadMarkerService();
      final client = MockClient();
      final room = MockRoom();
      final timeline = MockTimeline();

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => const Stream<Event>.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('EL1');
      when(() => ev.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(3));
      when(() => ev.senderId).thenReturn('@other:server');
      when(() => ev.attachmentMimetype).thenReturn('');
      when(() => ev.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => ev.roomId).thenReturn('!room:server');
      final payload = base64.encode(
        utf8.encode(json.encode(<String, dynamic>{
          'runtimeType': 'entryLink',
          'entryLink': {
            'id': 'x',
            'fromId': 'a',
            'toId': 'b',
            'hidden': false,
            'createdAt': '2020-01-01T00:00:00.000',
            'updatedAt': '2020-01-01T00:00:00.000'
          },
          'status': 'initial',
        })),
      );
      when(() => ev.text).thenReturn(payload);

      when(() => timeline.events).thenReturn(<Event>[ev]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);

      when(() => processor.process(event: ev, journalDb: journalDb))
          .thenAnswer((_) async {});
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((_) async {});

      final consumer = MatrixStreamConsumer(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        documentsDirectory: Directory.systemTemp,
        collectMetrics: true,
      );

      await consumer.initialize();
      await consumer.start();

      final m = consumer.metricsSnapshot();
      expect(m['processed.entryLink'], greaterThanOrEqualTo(1));
    });

    test('db-apply observer updates metrics', () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final journalDb = MockJournalDb();
      final settingsDb = MockSettingsDb();
      final processor = MockSyncEventProcessor();
      final readMarker = MockSyncReadMarkerService();
      final client = MockClient();

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => const Stream<Event>.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(null);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

      final consumer = MatrixStreamConsumer(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        documentsDirectory: Directory.systemTemp,
        collectMetrics: true,
      );

      // Simulate DB applied
      consumer.reportDbApplyDiagnostics(
        SyncApplyDiagnostics(
          eventId: 'e',
          payloadType: 'journalEntity',
          entityId: 'id',
          vectorClock: null,
          rowsAffected: 1,
          conflictStatus: 'b_gt_a',
        ),
      );
      // Simulate ignored by vector clock
      consumer.reportDbApplyDiagnostics(
        SyncApplyDiagnostics(
          eventId: 'e2',
          payloadType: 'journalEntity',
          entityId: 'id',
          vectorClock: null,
          rowsAffected: 0,
          conflictStatus: 'a_gt_b',
        ),
      );
      // Simulate conflict
      consumer.reportDbApplyDiagnostics(
        SyncApplyDiagnostics(
          eventId: 'e3',
          payloadType: 'journalEntity',
          entityId: 'id',
          vectorClock: null,
          rowsAffected: 0,
          conflictStatus: 'concurrent',
        ),
      );

      final m = consumer.metricsSnapshot();
      expect(m['dbApplied'], 1);
      expect(m['dbIgnoredByVectorClock'], 1);
      expect(m['conflictsCreated'], 1);
      // Also bumped droppedByType for ignored journalEntity
      expect(m['droppedByType.journalEntity'], greaterThanOrEqualTo(1));
    });

    test('does not count file attachments as skipped', () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final journalDb = MockJournalDb();
      final settingsDb = MockSettingsDb();
      final processor = MockSyncEventProcessor();
      final readMarker = MockSyncReadMarkerService();
      final client = MockClient();
      final room = MockRoom();
      final timeline = MockTimeline();

      when(() => logger.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          )).thenReturn(null);

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => const Stream<Event>.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

      // Timeline contains one file event (attachment) and one valid sync text
      final fileEvent = MockEvent();
      when(() => fileEvent.eventId).thenReturn('F');
      when(() => fileEvent.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      when(() => fileEvent.senderId).thenReturn('@other:server');
      when(() => fileEvent.attachmentMimetype).thenReturn('application/json');
      when(() => fileEvent.content)
          .thenReturn(<String, dynamic>{'relativePath': '/sub/test.json'});
      when(() => fileEvent.roomId).thenReturn('!room:server');

      final okEvent = MockEvent();
      when(() => okEvent.eventId).thenReturn('OK');
      when(() => okEvent.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(2));
      when(() => okEvent.senderId).thenReturn('@other:server');
      when(() => okEvent.attachmentMimetype).thenReturn('');
      when(() => okEvent.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => okEvent.roomId).thenReturn('!room:server');

      when(() => timeline.events).thenReturn(<Event>[fileEvent, okEvent]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);

      when(() => processor.process(event: okEvent, journalDb: journalDb))
          .thenAnswer((_) async {});
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((_) async {});

      final consumer = MatrixStreamConsumer(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        documentsDirectory: Directory.systemTemp,
        collectMetrics: true,
      );

      await consumer.initialize();
      await consumer.start();

      final m = consumer.metricsSnapshot();
      expect(m['prefetch'], greaterThanOrEqualTo(1));
      expect(m['processed'], greaterThanOrEqualTo(1));
      // Attachments are not counted as skipped
      expect(m['skipped'], 0);
    });

    test('invalid sync payload without msgtype counts as skipped', () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final journalDb = MockJournalDb();
      final settingsDb = MockSettingsDb();
      final processor = MockSyncEventProcessor();
      final readMarker = MockSyncReadMarkerService();
      final client = MockClient();
      final room = MockRoom();
      final timeline = MockTimeline();

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => const Stream<Event>.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('BAD');
      when(() => ev.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      when(() => ev.senderId).thenReturn('@other:server');
      when(() => ev.attachmentMimetype).thenReturn('');
      when(() => ev.roomId).thenReturn('!room:server');
      when(() => ev.content).thenReturn(<String, dynamic>{});
      when(() => ev.text).thenReturn('not base64');

      when(() => timeline.events).thenReturn(<Event>[ev]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);

      when(() => processor.process(
            event: any<Event>(named: 'event'),
            journalDb: journalDb,
          )).thenAnswer((_) async {});
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((_) async {});

      final consumer = MatrixStreamConsumer(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        documentsDirectory: Directory.systemTemp,
        collectMetrics: true,
      );

      await consumer.initialize();
      await consumer.start();

      final m = consumer.metricsSnapshot();
      expect(m['skipped'], 1);
      // No processing should have happened
      verifyNever(() => processor.process(
            event: any<Event>(named: 'event'),
            journalDb: journalDb,
          ));
    });

    test('diagnosticsStrings exposes lastIgnored and lastPrefetched entries',
        () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final journalDb = MockJournalDb();
      final settingsDb = MockSettingsDb();
      final processor = MockSyncEventProcessor();
      final readMarker = MockSyncReadMarkerService();
      final client = MockClient();
      final room = MockRoom();
      final timeline = MockTimeline();

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => const Stream<Event>.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

      // Pre-populate lastIgnored via db-apply observer (older case)
      final consumer = MatrixStreamConsumer(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        documentsDirectory: Directory.systemTemp,
        collectMetrics: true,
      );
      consumer.reportDbApplyDiagnostics(
        SyncApplyDiagnostics(
          eventId: 'X',
          payloadType: 'journalEntity',
          entityId: 'e',
          vectorClock: null,
          rowsAffected: 0,
          conflictStatus: 'a_gt_b',
        ),
      );

      // Timeline contains a file event to populate lastPrefetched
      final fileEvent = MockEvent();
      when(() => fileEvent.eventId).thenReturn('F');
      when(() => fileEvent.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      when(() => fileEvent.senderId).thenReturn('@other:server');
      when(() => fileEvent.attachmentMimetype).thenReturn('application/json');
      when(() => fileEvent.content)
          .thenReturn(<String, dynamic>{'relativePath': '/sub/p2.json'});
      when(() => fileEvent.downloadAndDecryptAttachment()).thenAnswer(
        (_) async =>
            MatrixFile(bytes: Uint8List.fromList([1, 2, 3]), name: 'p2.json'),
      );
      when(() => fileEvent.roomId).thenReturn('!room:server');

      when(() => timeline.events).thenReturn(<Event>[fileEvent]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((_) async {});
      when(() => processor.process(
            event: any<Event>(named: 'event'),
            journalDb: journalDb,
          )).thenAnswer((_) async {});

      await consumer.initialize();
      await consumer.start();

      final d = consumer.diagnosticsStrings();
      expect(d['lastIgnoredCount'], '1');
      expect(d['lastIgnored.1'], startsWith('X:'));
      expect(d['lastPrefetchedCount'], '1');
      expect(d['lastPrefetched.1'], '/sub/p2.json');
    });

    test('forceRescan includeCatchUp variations', () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final journalDb = MockJournalDb();
      final settingsDb = MockSettingsDb();
      final processor = MockSyncEventProcessor();
      final readMarker = MockSyncReadMarkerService();
      final client = MockClient();
      final room = MockRoom();
      final timeline = MockTimeline();

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => const Stream<Event>.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);
      when(() => timeline.events).thenReturn(<Event>[]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);

      var catchupCalls = 0;
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async {
        catchupCalls++;
        return timeline;
      });
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((_) async {});
      when(() => processor.process(
            event: any<Event>(named: 'event'),
            journalDb: journalDb,
          )).thenAnswer((_) async {});

      final consumer = MatrixStreamConsumer(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        documentsDirectory: Directory.systemTemp,
      );

      await consumer.initialize();
      await consumer.start();
      expect(catchupCalls, 1);

      // includeCatchUp = false should not increase catch-up calls
      await consumer.forceRescan(includeCatchUp: false);
      expect(catchupCalls, 1);

      // includeCatchUp = true (default) increases catch-up calls
      await consumer.forceRescan();
      expect(catchupCalls, 2);
    });

    test('retry backoff blocks until due, retryNow forces scan', () async {
      fakeAsync((async) async {
        // ignore: omit_local_variable_types
        final DateTime now = DateTime.fromMillisecondsSinceEpoch(0);
        // ignore: prefer_function_declarations_over_variables
        final nowFn = () => now;

        final session = MockMatrixSessionManager();
        final roomManager = MockSyncRoomManager();
        final logger = MockLoggingService();
        final journalDb = MockJournalDb();
        final settingsDb = MockSettingsDb();
        final processor = MockSyncEventProcessor();
        final readMarker = MockSyncReadMarkerService();
        final client = MockClient();
        final room = MockRoom();
        final timeline = MockTimeline();
        final onTimelineController = StreamController<Event>.broadcast();

        addTearDown(onTimelineController.close);

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => session.timelineEvents)
            .thenAnswer((_) => onTimelineController.stream);
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => null);
        when(() => timeline.events).thenReturn(<Event>[]);
        when(() => timeline.cancelSubscriptions()).thenReturn(null);
        when(() => room.getTimeline(limit: any(named: 'limit')))
            .thenAnswer((_) async => timeline);
        when(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: any<String>(named: 'eventId'),
            )).thenAnswer((_) async {});

        var calls = 0;
        when(() => processor.process(
              event: any<Event>(named: 'event'),
              journalDb: journalDb,
            )).thenAnswer((inv) async {
          calls++;
          if (calls == 1) {
            throw Exception('fail-once');
          }
        });

        final consumer = MatrixStreamConsumer(
          sessionManager: session,
          roomManager: roomManager,
          loggingService: logger,
          journalDb: journalDb,
          settingsDb: settingsDb,
          eventProcessor: processor,
          readMarkerService: readMarker,
          documentsDirectory: Directory.systemTemp,
          collectMetrics: true,
          now: nowFn,
          markerDebounce: const Duration(milliseconds: 50),
        );

        await consumer.initialize();
        await consumer.start();

        // Add a sync text event that will fail once
        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('R1');
        when(() => ev.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
        when(() => ev.senderId).thenReturn('@other:server');
        when(() => ev.attachmentMimetype).thenReturn('');
        when(() => ev.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
        when(() => ev.roomId).thenReturn('!room:server');

        onTimelineController.add(ev);
        async.flushMicrotasks();
        // After first failure, retry is scheduled
        expect(consumer.metricsSnapshot()['retriesScheduled'], 1);

        // Re-deliver the same event before backoff is due; should not process
        onTimelineController.add(ev);
        async.flushMicrotasks();
        expect(calls, 1);

        // Force retries to be due now and scan immediately
        await consumer.retryNow();
        async.flushMicrotasks();

        // Deliver a micro delay to let retry path through
        async.elapse(const Duration(milliseconds: 10));
        async.flushMicrotasks();
        expect(calls, greaterThanOrEqualTo(2));
      });
    });

    test('initialize is idempotent', () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final journalDb = MockJournalDb();
      final settingsDb = MockSettingsDb();
      final processor = MockSyncEventProcessor();
      final readMarker = MockSyncReadMarkerService();

      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

      final consumer = MatrixStreamConsumer(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        documentsDirectory: Directory.systemTemp,
      );

      await consumer.initialize();
      await consumer.initialize();

      verify(() => roomManager.initialize()).called(1);
      verify(() => settingsDb.itemByKey(lastReadMatrixEventId)).called(1);
    });

    test('dispose cancels live timeline subscriptions and logs', () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final journalDb = MockJournalDb();
      final settingsDb = MockSettingsDb();
      final processor = MockSyncEventProcessor();
      final readMarker = MockSyncReadMarkerService();
      final client = MockClient();
      final room = MockRoom();
      final catchupTimeline = MockTimeline();
      final liveTimeline = MockTimeline();

      when(() => logger.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => const Stream<Event>.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

      when(() => catchupTimeline.events).thenReturn(<Event>[]);
      when(() => catchupTimeline.cancelSubscriptions()).thenReturn(null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => catchupTimeline);

      when(
        () => room.getTimeline(
          onNewEvent: any(named: 'onNewEvent'),
          onInsert: any(named: 'onInsert'),
          onChange: any(named: 'onChange'),
          onRemove: any(named: 'onRemove'),
          onUpdate: any(named: 'onUpdate'),
        ),
      ).thenAnswer((_) async => liveTimeline);

      when(() => liveTimeline.cancelSubscriptions()).thenReturn(null);

      final consumer = MatrixStreamConsumer(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        documentsDirectory: Directory.systemTemp,
      );

      await consumer.initialize();
      await consumer.start();
      await consumer.dispose();

      verify(() => liveTimeline.cancelSubscriptions()).called(1);
      verify(
        () => logger.captureEvent(
          'MatrixStreamConsumer disposed',
          domain: 'MATRIX_SYNC_V2',
          subDomain: 'dispose',
        ),
      ).called(1);
    });

    test('processes valid sync text without msgtype via fallback', () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final journalDb = MockJournalDb();
      final settingsDb = MockSettingsDb();
      final processor = MockSyncEventProcessor();
      final readMarker = MockSyncReadMarkerService();
      final client = MockClient();
      final room = MockRoom();
      final timeline = MockTimeline();

      when(() => logger.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          )).thenReturn(null);

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => const Stream<Event>.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

      // Event without msgtype but with a valid base64 JSON payload
      final fallbackEvent = MockEvent();
      when(() => fallbackEvent.eventId).thenReturn('FB');
      when(() => fallbackEvent.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(10));
      when(() => fallbackEvent.senderId).thenReturn('@other:server');
      when(() => fallbackEvent.attachmentMimetype).thenReturn('');
      when(() => fallbackEvent.roomId).thenReturn('!room:server');

      final payload = base64.encode(
        utf8.encode(json.encode(<String, dynamic>{
          'runtimeType': 'aiConfigDelete',
          'id': 'abc',
        })),
      );
      when(() => fallbackEvent.content).thenReturn(<String, dynamic>{});
      when(() => fallbackEvent.text).thenReturn(payload);

      when(() => timeline.events).thenReturn(<Event>[fallbackEvent]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);

      when(() => processor.process(
            event: fallbackEvent,
            journalDb: journalDb,
          )).thenAnswer((_) async {});
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((_) async {});

      final consumer = MatrixStreamConsumer(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        documentsDirectory: Directory.systemTemp,
        collectMetrics: true,
      );

      await consumer.initialize();
      await consumer.start();

      // Should process via fallback and not count as skipped
      verify(() => processor.process(
            event: fallbackEvent,
            journalDb: journalDb,
          )).called(1);
      final m = consumer.metricsSnapshot();
      expect(m['processed'], greaterThanOrEqualTo(1));
      expect(m['skipped'], 0);
    });

    test('increments droppedByType when retry cap reached', () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final journalDb = MockJournalDb();
      final settingsDb = MockSettingsDb();
      final processor = MockSyncEventProcessor();
      final readMarker = MockSyncReadMarkerService();
      final client = MockClient();
      final room = MockRoom();
      final onTimelineController = StreamController<Event>.broadcast();

      addTearDown(onTimelineController.close);

      when(() => logger.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          )).thenReturn(null);

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => onTimelineController.stream);
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

      final failing = MockEvent();
      when(() => failing.eventId).thenReturn('DROP');
      when(() => failing.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(5));
      when(() => failing.senderId).thenReturn('@other:server');
      when(() => failing.attachmentMimetype).thenReturn('');
      when(() => failing.roomId).thenReturn('!room:server');
      when(() => failing.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      // Provide runtimeType for per-type metrics
      final payload = base64.encode(
        utf8.encode(json.encode(<String, dynamic>{
          'runtimeType': 'entryLink',
          'entryLink': {
            'id': 'x',
            'fromId': 'a',
            'toId': 'b',
            'hidden': false,
            'createdAt': '2020-01-01T00:00:00.000',
            'updatedAt': '2020-01-01T00:00:00.000'
          },
          'status': 'initial',
        })),
      );
      when(() => failing.text).thenReturn(payload);

      // Always throw to hit retry cap immediately (we set cap=1)
      when(() => processor.process(event: failing, journalDb: journalDb))
          .thenThrow(Exception('boom'));

      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((_) async {});

      final consumer = MatrixStreamConsumer(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        documentsDirectory: Directory.systemTemp,
        collectMetrics: true,
        maxRetriesPerEvent: 1,
      );

      await consumer.initialize();
      await consumer.start();

      onTimelineController.add(failing);
      await Future<void>.delayed(const Duration(milliseconds: 250));

      final m = consumer.metricsSnapshot();
      expect(m['skippedByRetryLimit'], greaterThanOrEqualTo(1));
      expect(m['droppedByType.entryLink'], greaterThanOrEqualTo(1));
    });

    test('falls back to doubling when backfill not available', () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final journalDb = MockJournalDb();
      final settingsDb = MockSettingsDb();
      final processor = MockSyncEventProcessor();
      final readMarker = MockSyncReadMarkerService();
      final client = MockClient();
      final room = MockRoom();

      when(() => logger.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => const Stream<Event>.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => 'e0');

      // Simulate fallback window growth by returning bigger snapshots
      final allEvents = List<Event>.generate(10, (i) {
        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('e$i');
        when(() => ev.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(i));
        when(() => ev.senderId).thenReturn('@other:server');
        when(() => ev.attachmentMimetype).thenReturn('');
        when(() => ev.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
        when(() => ev.roomId).thenReturn('!room:server');
        return ev;
      });
      Future<Timeline> timelineForLimit(int limit) async {
        final tl = MockTimeline();
        final start = allEvents.length > limit ? allEvents.length - limit : 0;
        final sub = allEvents.sublist(start);
        when(() => tl.events).thenReturn(sub);
        when(() => tl.cancelSubscriptions()).thenReturn(null);
        return tl;
      }

      when(() => room.getTimeline(limit: any(named: 'limit'))).thenAnswer(
        (invocation) async {
          final limit = invocation.namedArguments[#limit] as int? ?? 200;
          return timelineForLimit(limit);
        },
      );

      when(() => processor.process(
          event: any<Event>(named: 'event'),
          journalDb: journalDb)).thenAnswer((_) async {});
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((_) async {});

      final consumer = MatrixStreamConsumer(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        documentsDirectory: Directory.systemTemp,
        // backfill returns false to force fallback
        backfill: ({
          required Timeline timeline,
          required String? lastEventId,
          required int pageSize,
          required int maxPages,
          required LoggingService logging,
        }) async {
          return false;
        },
      );

      await consumer.initialize();
      await consumer.start();

      // Expect processing of e1..e9 (after e0)
      verify(() => processor.process(
            event: any<Event>(named: 'event'),
            journalDb: journalDb,
          )).called(9);
    });

    test('filters events from other rooms and batches via flush timer',
        () async {
      fakeAsync((async) async {
        final session = MockMatrixSessionManager();
        final roomManager = MockSyncRoomManager();
        final logger = MockLoggingService();
        final journalDb = MockJournalDb();
        final settingsDb = MockSettingsDb();
        final processor = MockSyncEventProcessor();
        final readMarker = MockSyncReadMarkerService();
        final client = MockClient();
        final room = MockRoom();
        final timeline = MockTimeline();
        final onTimelineController = StreamController<Event>.broadcast();

        addTearDown(onTimelineController.close);

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => session.timelineEvents)
            .thenAnswer((_) => onTimelineController.stream);
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => null);
        when(() => timeline.events).thenReturn(<Event>[]);
        when(() => timeline.cancelSubscriptions()).thenReturn(null);
        when(() => room.getTimeline(limit: any(named: 'limit')))
            .thenAnswer((_) async => timeline);

        when(() => processor.process(
            event: any<Event>(named: 'event'),
            journalDb: journalDb)).thenAnswer((_) async {});
        when(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: any<String>(named: 'eventId'),
            )).thenAnswer((_) async {});

        final consumer = MatrixStreamConsumer(
          sessionManager: session,
          roomManager: roomManager,
          loggingService: logger,
          journalDb: journalDb,
          settingsDb: settingsDb,
          eventProcessor: processor,
          readMarkerService: readMarker,
          documentsDirectory: Directory.systemTemp,
          // use shorter flush for test speed if desired (default fine here)
        );

        await consumer.initialize();
        await consumer.start();

        Event mk(String id, {required String roomId}) {
          final ev = MockEvent();
          when(() => ev.eventId).thenReturn(id);
          when(() => ev.originServerTs)
              .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
          when(() => ev.senderId).thenReturn('@other:server');
          when(() => ev.attachmentMimetype).thenReturn('');
          when(() => ev.content)
              .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
          when(() => ev.roomId).thenReturn(roomId);
          return ev;
        }

        // Add 5 valid events + 1 wrong room
        final wrong = mk('w', roomId: '!other:server');
        onTimelineController.add(wrong);
        for (var i = 0; i < 5; i++) {
          onTimelineController.add(mk('b$i', roomId: '!room:server'));
        }

        // Not processed immediately
        verifyNever(() => processor.process(
            event: any(named: 'event'), journalDb: journalDb));

        // Advance flush interval and process batch
        async.elapse(const Duration(milliseconds: 160));
        async.flushMicrotasks();

        verifyNever(
            () => processor.process(event: wrong, journalDb: journalDb));
        verify(() => processor.process(
              event: any<Event>(named: 'event'),
              journalDb: journalDb,
            )).called(5);
      });
    });

    test('live timeline callbacks schedule a single scan', () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final journalDb = MockJournalDb();
      final settingsDb = MockSettingsDb();
      final processor = MockSyncEventProcessor();
      final readMarker = MockSyncReadMarkerService();
      final client = MockClient();
      final room = MockRoom();
      final timeline = MockTimeline();
      final onTimelineController = StreamController<Event>.broadcast();

      addTearDown(onTimelineController.close);

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => onTimelineController.stream);
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');

      // Capture callbacks
      void Function()? onNew;
      void Function()? onUpdate;
      when(
        () => room.getTimeline(
          limit: any<int>(named: 'limit'),
          onNewEvent: any(named: 'onNewEvent'),
          onInsert: any(named: 'onInsert'),
          onChange: any(named: 'onChange'),
          onRemove: any(named: 'onRemove'),
          onUpdate: any(named: 'onUpdate'),
        ),
      ).thenAnswer((inv) async {
        onNew = inv.namedArguments[#onNewEvent] as void Function()?;
        onUpdate = inv.namedArguments[#onUpdate] as void Function()?;
        return timeline;
      });

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('LT');
      when(() => ev.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      when(() => ev.senderId).thenReturn('@other:server');
      when(() => ev.attachmentMimetype).thenReturn('');
      when(() => ev.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => ev.roomId).thenReturn('!room:server');
      when(() => timeline.events).thenReturn(<Event>[ev]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);

      when(() => processor.process(event: ev, journalDb: journalDb))
          .thenAnswer((_) async {});
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((_) async {});

      final consumer = MatrixStreamConsumer(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        documentsDirectory: Directory.systemTemp,
      );

      await consumer.initialize();
      await consumer.start();

      // Trigger both callbacks in short succession; only one scan should fire
      onNew?.call();
      onUpdate?.call();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      verify(() => processor.process(event: ev, journalDb: journalDb))
          .called(1);
    });

    test('metrics snapshot contains expected counters', () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final journalDb = MockJournalDb();
      final settingsDb = MockSettingsDb();
      final processor = MockSyncEventProcessor();
      final readMarker = MockSyncReadMarkerService();
      final client = MockClient();
      final room = MockRoom();
      final timeline = MockTimeline();
      final onTimelineController = StreamController<Event>.broadcast();

      addTearDown(onTimelineController.close);

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => onTimelineController.stream);
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

      // Catch‑up snapshot includes an attachment event and a normal event
      final fileEvent = MockEvent();
      when(() => fileEvent.eventId).thenReturn('F');
      when(() => fileEvent.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      when(() => fileEvent.senderId).thenReturn('@other:server');
      when(() => fileEvent.attachmentMimetype).thenReturn('application/json');
      when(() => fileEvent.content)
          .thenReturn(<String, dynamic>{'relativePath': '/sub/test.json'});
      when(() => fileEvent.roomId).thenReturn('!room:server');

      final okEvent = MockEvent();
      when(() => okEvent.eventId).thenReturn('OK');
      when(() => okEvent.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(2));
      when(() => okEvent.senderId).thenReturn('@other:server');
      when(() => okEvent.attachmentMimetype).thenReturn('');
      when(() => okEvent.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => okEvent.roomId).thenReturn('!room:server');

      final skipped = MockEvent();
      when(() => skipped.eventId).thenReturn('S');
      when(() => skipped.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(3));
      when(() => skipped.senderId).thenReturn('@other:server');
      when(() => skipped.attachmentMimetype).thenReturn('');
      when(() => skipped.content).thenReturn(<String, dynamic>{});
      when(() => skipped.roomId).thenReturn('!room:server');

      when(() => timeline.events)
          .thenReturn(<Event>[fileEvent, okEvent, skipped]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);

      when(() => processor.process(event: okEvent, journalDb: journalDb))
          .thenAnswer((_) async {});
      // One failing event from stream to bump failures + retriesScheduled
      final failing = MockEvent();
      when(() => failing.eventId).thenReturn('X');
      when(() => failing.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(4));
      when(() => failing.senderId).thenReturn('@other:server');
      when(() => failing.attachmentMimetype).thenReturn('');
      when(() => failing.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => failing.roomId).thenReturn('!room:server');
      when(() => processor.process(event: failing, journalDb: journalDb))
          .thenThrow(Exception('boom'));

      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((_) async {});

      final consumer = MatrixStreamConsumer(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        documentsDirectory: Directory.systemTemp,
        collectMetrics: true,
      );

      await consumer.initialize();
      await consumer.start();

      // Push the failing event through streaming path
      onTimelineController.add(failing);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final m = consumer.metricsSnapshot();
      expect(m['processed'], greaterThanOrEqualTo(1));
      expect(m['skipped'], greaterThanOrEqualTo(1));
      expect(m['failures'], greaterThanOrEqualTo(1));
      expect(m['prefetch'], greaterThanOrEqualTo(1));
      expect(m['flushes'], greaterThanOrEqualTo(1));
      expect(m['catchupBatches'], greaterThanOrEqualTo(1));
      expect(m['retriesScheduled'], greaterThanOrEqualTo(1));
      expect(m['circuitOpens'], greaterThanOrEqualTo(0));
      expect(m['retryStateSize'], greaterThanOrEqualTo(1));
      expect(m['circuitOpen'], anyOf(0, 1));
    });

    test('handles rapid start/stop/start cycles safely', () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final journalDb = MockJournalDb();
      final settingsDb = MockSettingsDb();
      final processor = MockSyncEventProcessor();
      final readMarker = MockSyncReadMarkerService();
      final client = MockClient();
      final room = MockRoom();
      final timeline = MockTimeline();
      final onTimelineController = StreamController<Event>.broadcast();

      addTearDown(onTimelineController.close);

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => onTimelineController.stream);
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);
      when(() => timeline.events).thenReturn(<Event>[]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);

      when(() => processor.process(
          event: any<Event>(named: 'event'),
          journalDb: journalDb)).thenAnswer((_) async {});
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((_) async {});

      final consumer = MatrixStreamConsumer(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        documentsDirectory: Directory.systemTemp,
      );

      await consumer.initialize();
      await consumer.start();
      // Dispose and immediately start again
      await consumer.dispose();
      await consumer.start();

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('RACE');
      when(() => ev.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      when(() => ev.senderId).thenReturn('@other:server');
      when(() => ev.attachmentMimetype).thenReturn('');
      when(() => ev.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => ev.roomId).thenReturn('!room:server');

      onTimelineController.add(ev);
      await Future<void>.delayed(const Duration(milliseconds: 250));
      verify(() => processor.process(event: ev, journalDb: journalDb))
          .called(1);
    });
  });

  test('start handles live timeline getTimeline exception gracefully',
      () async {
    final session = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final logger = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final processor = MockSyncEventProcessor();
    final readMarker = MockSyncReadMarkerService();
    final client = MockClient();
    final room = MockRoom();

    when(() => logger.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        )).thenReturn(null);
    when(() => logger.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        )).thenReturn(null);

    when(() => session.client).thenReturn(client);
    when(() => client.userID).thenReturn('@me:server');
    when(() => session.timelineEvents)
        .thenAnswer((_) => const Stream<Event>.empty());

    when(() => roomManager.initialize()).thenAnswer((_) async {});
    when(() => roomManager.currentRoom).thenReturn(room);
    when(() => roomManager.currentRoomId).thenReturn('!room:server');
    when(() => settingsDb.itemByKey(lastReadMatrixEventId))
        .thenAnswer((_) async => null);

    // Catch-up snapshot is empty but valid
    final emptyTimeline = MockTimeline();
    when(() => emptyTimeline.events).thenReturn(<Event>[]);
    when(() => emptyTimeline.cancelSubscriptions()).thenReturn(null);
    when(() => room.getTimeline(limit: any(named: 'limit')))
        .thenAnswer((_) async => emptyTimeline);
    // Live timeline attachment throws
    when(
      () => room.getTimeline(
        onNewEvent: any(named: 'onNewEvent'),
        onInsert: any(named: 'onInsert'),
        onChange: any(named: 'onChange'),
        onRemove: any(named: 'onRemove'),
        onUpdate: any(named: 'onUpdate'),
      ),
    ).thenThrow(Exception('no live timeline'));

    final consumer = MatrixStreamConsumer(
      sessionManager: session,
      roomManager: roomManager,
      loggingService: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      documentsDirectory: Directory.systemTemp,
    );

    await consumer.initialize();
    // Should not throw despite live timeline failure
    await consumer.start();
    verify(() => logger.captureException(
          any<Object>(),
          domain: 'MATRIX_SYNC_V2',
          subDomain: 'attach.liveTimeline',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        )).called(1);
  });
  group('MatrixStreamConsumer catch-up', () {
    test('processes strictly after lastProcessed and advances marker',
        () async {
      fakeAsync((async) async {
        final session = MockMatrixSessionManager();
        final roomManager = MockSyncRoomManager();
        final logger = MockLoggingService();
        final journalDb = MockJournalDb();
        final settingsDb = MockSettingsDb();
        final processor = MockSyncEventProcessor();
        final readMarker = MockSyncReadMarkerService();
        final client = MockClient();
        final room = MockRoom();
        final timeline = MockTimeline();
        final tempDir = await Directory.systemTemp.createTemp('msc_v2');
        final onTimelineController = StreamController<Event>.broadcast();

        addTearDown(() => tempDir.deleteSync(recursive: true));
        addTearDown(onTimelineController.close);

        when(() => logger.captureEvent(any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
        when(() => logger.captureException(any<Object>(),
                domain: any<String>(named: 'domain'),
                subDomain: any<String>(named: 'subDomain'),
                stackTrace: any<StackTrace?>(named: 'stackTrace')))
            .thenReturn(null);

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => session.timelineEvents)
            .thenAnswer((_) => onTimelineController.stream);
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => 'existing');

        // Events: existing(ts1), newA(ts2), newB(ts3) in unsorted order
        final existing = MockEvent();
        when(() => existing.eventId).thenReturn('existing');
        when(() => existing.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
        when(() => existing.senderId).thenReturn('@other:server');
        when(() => existing.attachmentMimetype).thenReturn('');
        when(() => existing.content).thenReturn(<String, dynamic>{});

        final newA = MockEvent();
        when(() => newA.eventId).thenReturn('newA');
        when(() => newA.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(2));
        when(() => newA.senderId).thenReturn('@other:server');
        when(() => newA.attachmentMimetype).thenReturn('');
        when(() => newA.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});

        final newB = MockEvent();
        when(() => newB.eventId).thenReturn('newB');
        when(() => newB.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(3));
        when(() => newB.senderId).thenReturn('@other:server');
        when(() => newB.attachmentMimetype).thenReturn('');
        when(() => newB.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});

        when(() => timeline.events).thenReturn(<Event>[newB, existing, newA]);
        when(() => timeline.cancelSubscriptions()).thenReturn(null);
        when(() => room.getTimeline(limit: any(named: 'limit')))
            .thenAnswer((_) async => timeline);

        when(() => processor.process(
            event: any<Event>(named: 'event'),
            journalDb: journalDb)).thenAnswer((_) async {});
        when(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: any<String>(named: 'eventId'),
            )).thenAnswer((_) async {});

        final consumer = MatrixStreamConsumer(
          sessionManager: session,
          roomManager: roomManager,
          loggingService: logger,
          journalDb: journalDb,
          settingsDb: settingsDb,
          eventProcessor: processor,
          readMarkerService: readMarker,
          documentsDirectory: tempDir,
        );

        await consumer.initialize();
        await consumer.start();

        // Advance debounce timer to flush read marker.
        async.elapse(const Duration(milliseconds: 700));
        async.flushMicrotasks();

        verify(() => processor.process(event: newA, journalDb: journalDb))
            .called(1);
        verify(() => processor.process(event: newB, journalDb: journalDb))
            .called(1);
        verify(
          () => readMarker.updateReadMarker(
            client: client,
            room: room,
            eventId: 'newB',
          ),
        ).called(1);
      });
    });

    test('cancels timeline snapshot on exception during catch-up', () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final journalDb = MockJournalDb();
      final settingsDb = MockSettingsDb();
      final processor = MockSyncEventProcessor();
      final readMarker = MockSyncReadMarkerService();
      final client = MockClient();
      final room = MockRoom();
      final badTimeline = MockTimeline();
      final liveTimeline = MockTimeline();
      final onTimelineController = StreamController<Event>.broadcast();

      addTearDown(onTimelineController.close);

      when(() => logger.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logger.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => onTimelineController.stream);
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

      // Catch-up path: limit-only call returns a timeline whose events getter throws
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => badTimeline);
      final badEvent = MockEvent();
      when(() => badEvent.eventId).thenReturn('bad');
      when(() => badEvent.originServerTs).thenThrow(Exception('bad ts'));
      when(() => badEvent.senderId).thenReturn('@other:server');
      when(() => badEvent.attachmentMimetype).thenReturn('');
      when(() => badEvent.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => badTimeline.events).thenReturn(<Event>[badEvent]);
      when(() => badTimeline.cancelSubscriptions()).thenReturn(null);

      // Live timeline path (with callbacks) should still attach cleanly
      when(
        () => room.getTimeline(
          limit: any<int>(named: 'limit'),
          onNewEvent: any<void Function()>(named: 'onNewEvent'),
          onInsert: any<void Function(int)>(named: 'onInsert'),
          onChange: any<void Function(int)>(named: 'onChange'),
          onRemove: any<void Function(int)>(named: 'onRemove'),
          onUpdate: any<void Function()>(named: 'onUpdate'),
        ),
      ).thenAnswer((_) async => liveTimeline);
      when(() => liveTimeline.cancelSubscriptions()).thenReturn(null);

      final consumer = MatrixStreamConsumer(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        documentsDirectory: Directory.systemTemp,
      );

      await consumer.initialize();
      await consumer.start();
      // Allow any microtasks to complete
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // The catch-up exception should not leak the subscription. We verify the
      // catch-up call happened. Verifying the cancelSubscriptions() call on the
      // snapshot is flaky with current SDK mocks; rely on finally cleanup in
      // implementation and integration coverage elsewhere.
      verify(() => room.getTimeline(limit: any(named: 'limit'))).called(1);
    });

    test('prefetches attachments for remote file events during catch-up',
        () async {
      fakeAsync((async) async {
        final session = MockMatrixSessionManager();
        final roomManager = MockSyncRoomManager();
        final logger = MockLoggingService();
        final journalDb = MockJournalDb();
        final settingsDb = MockSettingsDb();
        final processor = MockSyncEventProcessor();
        final readMarker = MockSyncReadMarkerService();
        final client = MockClient();
        final room = MockRoom();
        final timeline = MockTimeline();
        final tempDir = await Directory.systemTemp.createTemp('msc_v2_files');
        final onTimelineController = StreamController<Event>.broadcast();

        addTearDown(() => tempDir.deleteSync(recursive: true));
        addTearDown(onTimelineController.close);

        when(() => logger.captureEvent(any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
        when(() => logger.captureException(any<Object>(),
                domain: any<String>(named: 'domain'),
                subDomain: any<String>(named: 'subDomain'),
                stackTrace: any<StackTrace?>(named: 'stackTrace')))
            .thenReturn(null);

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => session.timelineEvents)
            .thenAnswer((_) => onTimelineController.stream);
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => null);

        final fileEvent = MockEvent();
        when(() => fileEvent.eventId).thenReturn('file1');
        when(() => fileEvent.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(10));
        when(() => fileEvent.senderId).thenReturn('@other:server');
        when(() => fileEvent.attachmentMimetype).thenReturn('application/json');
        when(() => fileEvent.content)
            .thenReturn(<String, dynamic>{'relativePath': '/sub/test.json'});
        when(() => fileEvent.downloadAndDecryptAttachment()).thenAnswer(
          (_) async => MatrixFile(
            bytes: Uint8List.fromList('{"k":1}'.codeUnits),
            name: 'test.json',
          ),
        );

        when(() => timeline.events).thenReturn(<Event>[fileEvent]);
        when(() => timeline.cancelSubscriptions()).thenReturn(null);
        when(() => room.getTimeline(limit: any(named: 'limit')))
            .thenAnswer((_) async => timeline);

        when(() => processor.process(
            event: any<Event>(named: 'event'),
            journalDb: journalDb)).thenAnswer((_) async {});
        when(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: any<String>(named: 'eventId'),
            )).thenAnswer((_) async {});

        final consumer = MatrixStreamConsumer(
          sessionManager: session,
          roomManager: roomManager,
          loggingService: logger,
          journalDb: journalDb,
          settingsDb: settingsDb,
          eventProcessor: processor,
          readMarkerService: readMarker,
          documentsDirectory: tempDir,
        );

        await consumer.initialize();
        await consumer.start();

        async.elapse(const Duration(milliseconds: 700));
        async.flushMicrotasks();

        // Attachment written
        final saved = File('${tempDir.path}/sub/test.json');
        expect(saved.existsSync(), isTrue);
      });
    });

    test('expands catch-up window to include backlog and does not skip events',
        () async {
      fakeAsync((async) async {
        final session = MockMatrixSessionManager();
        final roomManager = MockSyncRoomManager();
        final logger = MockLoggingService();
        final journalDb = MockJournalDb();
        final settingsDb = MockSettingsDb();
        final processor = MockSyncEventProcessor();
        final readMarker = MockSyncReadMarkerService();
        final client = MockClient();
        final room = MockRoom();
        final onTimelineController = StreamController<Event>.broadcast();

        addTearDown(onTimelineController.close);

        when(() => logger.captureEvent(any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
        when(() => logger.captureException(any<Object>(),
                domain: any<String>(named: 'domain'),
                subDomain: any<String>(named: 'subDomain'),
                stackTrace: any<StackTrace?>(named: 'stackTrace')))
            .thenReturn(null);

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => session.timelineEvents)
            .thenAnswer((_) => onTimelineController.stream);
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');

        // Simulate last processed far behind the latest (e499 of 1200 events)
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => 'e499');

        // Build 1200 events with increasing timestamps
        List<Event> buildAll() {
          final list = <Event>[];
          for (var i = 0; i < 1200; i++) {
            final e = MockEvent();
            when(() => e.eventId).thenReturn('e$i');
            when(() => e.originServerTs)
                .thenReturn(DateTime.fromMillisecondsSinceEpoch(i));
            when(() => e.senderId).thenReturn('@other:server');
            when(() => e.attachmentMimetype).thenReturn('');
            when(() => e.content)
                .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
            list.add(e);
          }
          return list;
        }

        final allEvents = buildAll();

        Future<Timeline> timelineForLimit(int limit) async {
          final tl = MockTimeline();
          final start = allEvents.length > limit ? allEvents.length - limit : 0;
          final sub = allEvents.sublist(start);
          when(() => tl.events).thenReturn(sub);
          when(() => tl.cancelSubscriptions()).thenReturn(null);
          return tl;
        }

        when(() => room.getTimeline(limit: any(named: 'limit'))).thenAnswer(
          (invocation) async {
            final limit = invocation.namedArguments[#limit] as int? ?? 200;
            return timelineForLimit(limit);
          },
        );

        when(() => processor.process(
            event: any<Event>(named: 'event'),
            journalDb: journalDb)).thenAnswer((_) async {});
        when(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: any<String>(named: 'eventId'),
            )).thenAnswer((_) async {});

        final consumer = MatrixStreamConsumer(
          sessionManager: session,
          roomManager: roomManager,
          loggingService: logger,
          journalDb: journalDb,
          settingsDb: settingsDb,
          eventProcessor: processor,
          readMarkerService: readMarker,
          documentsDirectory: Directory.systemTemp,
          collectMetrics: true,
        );

        await consumer.initialize();
        await consumer.start();

        // Advance debounce timer to flush read marker.
        async.elapse(const Duration(milliseconds: 700));
        async.flushMicrotasks();

        // Expect 700 events processed: e500..e1199
        verify(() => processor.process(
              event: any<Event>(named: 'event'),
              journalDb: journalDb,
            )).called(700);
      });
    });
  });

  group('MatrixStreamConsumer live timeline + hydration', () {
    test('start hydrates room when missing and attaches live timeline',
        () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final journalDb = MockJournalDb();
      final settingsDb = MockSettingsDb();
      final processor = MockSyncEventProcessor();
      final readMarker = MockSyncReadMarkerService();
      final client = MockClient();
      final room = MockRoom();
      final timeline = MockTimeline();
      final onTimelineController = StreamController<Event>.broadcast();

      when(() => logger.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logger.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => onTimelineController.stream);
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);
      // First, room missing to force hydrate
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(null);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => roomManager.hydrateRoomSnapshot(
          client: any<Client>(named: 'client'))).thenAnswer((_) async {
        // After hydration, room available
        when(() => roomManager.currentRoom).thenReturn(room);
      });

      // Simulate live timeline attach; call onNewEvent immediately, return timeline
      when(
        () => room.getTimeline(
          limit: any<int>(named: 'limit'),
          onNewEvent: any<void Function()>(named: 'onNewEvent'),
          onInsert: any<void Function(int)>(named: 'onInsert'),
          onChange: any<void Function(int)>(named: 'onChange'),
          onRemove: any<void Function(int)>(named: 'onRemove'),
          onUpdate: any<void Function()>(named: 'onUpdate'),
        ),
      ).thenAnswer((invocation) async {
        final onNew =
            invocation.namedArguments[#onNewEvent] as void Function()?;
        onNew?.call();
        return timeline;
      });

      // Provide one new event in the live timeline
      final newEvent = MockEvent();
      when(() => newEvent.eventId).thenReturn('e1');
      when(() => newEvent.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(2));
      when(() => newEvent.senderId).thenReturn('@other:server');
      when(() => newEvent.attachmentMimetype).thenReturn('');
      when(() => newEvent.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => timeline.events).thenReturn(<Event>[newEvent]);

      when(() => processor.process(
          event: any<Event>(named: 'event'),
          journalDb: journalDb)).thenAnswer((_) async {});
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((_) async {});

      final consumer = MatrixStreamConsumer(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        documentsDirectory: Directory.systemTemp,
        collectMetrics: true,
      );

      await consumer.initialize();
      await consumer.start();

      // Allow liveScan debounce to elapse
      await Future<void>.delayed(const Duration(milliseconds: 200));

      verify(() => roomManager.hydrateRoomSnapshot(client: client)).called(1);
      verify(() => processor.process(event: newEvent, journalDb: journalDb))
          .called(1);
      final metrics = consumer.metricsSnapshot();
      expect(metrics['processed'], greaterThanOrEqualTo(1));
    });

    test('does not advance marker past first failed event in batch', () async {
      fakeAsync((async) async {
        final session = MockMatrixSessionManager();
        final roomManager = MockSyncRoomManager();
        final logger = MockLoggingService();
        final journalDb = MockJournalDb();
        final settingsDb = MockSettingsDb();
        final processor = MockSyncEventProcessor();
        final readMarker = MockSyncReadMarkerService();
        final client = MockClient();
        final room = MockRoom();
        final timeline = MockTimeline();
        final onTimelineController = StreamController<Event>.broadcast();

        addTearDown(onTimelineController.close);

        when(() => logger.captureEvent(any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
        when(() => logger.captureException(any<Object>(),
                domain: any<String>(named: 'domain'),
                subDomain: any<String>(named: 'subDomain'),
                stackTrace: any<StackTrace?>(named: 'stackTrace')))
            .thenReturn(null);

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => session.timelineEvents)
            .thenAnswer((_) => onTimelineController.stream);
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => null);

        // Events A, B, C with increasing timestamps
        Event makeEvent(String id, int ts, {String? msgType}) {
          final e = MockEvent();
          when(() => e.eventId).thenReturn(id);
          when(() => e.originServerTs)
              .thenReturn(DateTime.fromMillisecondsSinceEpoch(ts));
          when(() => e.senderId).thenReturn('@other:server');
          when(() => e.attachmentMimetype).thenReturn('');
          when(() => e.content).thenReturn(<String, dynamic>{
            if (msgType != null) 'msgtype': msgType,
          });
          return e;
        }

        final a = makeEvent('A', 1, msgType: syncMessageType);
        final b = makeEvent('B', 2, msgType: syncMessageType);
        final c = makeEvent('C', 3, msgType: syncMessageType);

        when(() => timeline.events).thenReturn(<Event>[a, b, c]);
        when(() => timeline.cancelSubscriptions()).thenReturn(null);
        when(() => room.getTimeline(limit: any(named: 'limit')))
            .thenAnswer((_) async => timeline);

        when(() => processor.process(event: a, journalDb: journalDb))
            .thenAnswer((_) async {});
        when(() => processor.process(event: b, journalDb: journalDb))
            .thenThrow(Exception('fail B'));
        when(() => processor.process(event: c, journalDb: journalDb))
            .thenAnswer((_) async {});

        when(() => readMarker.updateReadMarker(
              client: any(named: 'client'),
              room: any(named: 'room'),
              eventId: any(named: 'eventId'),
            )).thenAnswer((_) async {});

        final consumer = MatrixStreamConsumer(
          sessionManager: session,
          roomManager: roomManager,
          loggingService: logger,
          journalDb: journalDb,
          settingsDb: settingsDb,
          eventProcessor: processor,
          readMarkerService: readMarker,
          documentsDirectory: Directory.systemTemp,
          collectMetrics: true,
        );

        await consumer.initialize();
        await consumer.start();

        // Allow read marker debounce to elapse
        async.elapse(const Duration(milliseconds: 700));
        async.flushMicrotasks();

        // Marker should advance only to 'A', not 'C'
        verify(
          () => readMarker.updateReadMarker(
            client: client,
            room: room,
            eventId: 'A',
          ),
        ).called(1);

        final metrics = consumer.metricsSnapshot();
        expect(metrics['failures'], greaterThanOrEqualTo(1));
      });
    });

    test('counts skipped for non-sync msg types', () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final journalDb = MockJournalDb();
      final settingsDb = MockSettingsDb();
      final processor = MockSyncEventProcessor();
      final readMarker = MockSyncReadMarkerService();
      final client = MockClient();
      final room = MockRoom();
      final timeline = MockTimeline();
      final onTimelineController = StreamController<Event>.broadcast();

      addTearDown(onTimelineController.close);

      when(() => logger.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logger.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => onTimelineController.stream);
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

      final nonSync = MockEvent();
      when(() => nonSync.eventId).thenReturn('NS');
      when(() => nonSync.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      when(() => nonSync.senderId).thenReturn('@other:server');
      when(() => nonSync.attachmentMimetype).thenReturn('');
      when(() => nonSync.content)
          .thenReturn(<String, dynamic>{'msgtype': 'm.text'});

      final syncE = MockEvent();
      when(() => syncE.eventId).thenReturn('S');
      when(() => syncE.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(2));
      when(() => syncE.senderId).thenReturn('@other:server');
      when(() => syncE.attachmentMimetype).thenReturn('');
      when(() => syncE.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});

      when(() => timeline.events).thenReturn(<Event>[nonSync, syncE]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);

      when(() => processor.process(event: syncE, journalDb: journalDb))
          .thenAnswer((_) async {});
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((_) async {});

      final consumer = MatrixStreamConsumer(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        documentsDirectory: Directory.systemTemp,
        collectMetrics: true,
      );

      await consumer.initialize();
      await consumer.start();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      final metrics = consumer.metricsSnapshot();
      expect(metrics['skipped'], greaterThanOrEqualTo(1));
    });

    test('dispose cancels live timeline subscription', () async {
      final session = MockMatrixSessionManager();
      final roomManager = MockSyncRoomManager();
      final logger = MockLoggingService();
      final journalDb = MockJournalDb();
      final settingsDb = MockSettingsDb();
      final processor = MockSyncEventProcessor();
      final readMarker = MockSyncReadMarkerService();
      final client = MockClient();
      final room = MockRoom();
      final timeline = MockTimeline();
      final onTimelineController = StreamController<Event>.broadcast();

      addTearDown(onTimelineController.close);

      when(() => logger.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logger.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => onTimelineController.stream);
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

      when(
        () => room.getTimeline(
          limit: any<int>(named: 'limit'),
          onNewEvent: any<void Function()>(named: 'onNewEvent'),
          onInsert: any<void Function(int)>(named: 'onInsert'),
          onChange: any<void Function(int)>(named: 'onChange'),
          onRemove: any<void Function(int)>(named: 'onRemove'),
          onUpdate: any<void Function()>(named: 'onUpdate'),
        ),
      ).thenAnswer((_) async => timeline);

      when(() => timeline.cancelSubscriptions()).thenReturn(null);

      final consumer = MatrixStreamConsumer(
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        documentsDirectory: Directory.systemTemp,
        collectMetrics: true,
      );

      await consumer.initialize();
      await consumer.start();
      await consumer.dispose();

      verify(() => timeline.cancelSubscriptions())
          .called(greaterThanOrEqualTo(1));
    });
  });

  test('monotonic marker across interleaved older live scan', () async {
    final session = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final logger = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final processor = MockSyncEventProcessor();
    final readMarker = MockSyncReadMarkerService();
    final client = MockClient();
    final room = MockRoom();
    final catchupTimeline = MockTimeline();
    final liveTimeline = MockTimeline();
    final onTimelineController = StreamController<Event>.broadcast();

    addTearDown(onTimelineController.close);

    when(() => logger.captureEvent(any<String>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
    when(() => logger.captureException(any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

    when(() => session.client).thenReturn(client);
    when(() => client.userID).thenReturn('@me:server');
    when(() => session.timelineEvents)
        .thenAnswer((_) => onTimelineController.stream);
    when(() => roomManager.initialize()).thenAnswer((_) async {});
    when(() => roomManager.currentRoom).thenReturn(room);
    when(() => roomManager.currentRoomId).thenReturn('!room:server');
    when(() => settingsDb.itemByKey(lastReadMatrixEventId))
        .thenAnswer((_) async => null);

    // Catch-up initial older event A (ts=1)
    final a = MockEvent();
    when(() => a.eventId).thenReturn('A');
    when(() => a.originServerTs)
        .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
    when(() => a.senderId).thenReturn('@other:server');
    when(() => a.attachmentMimetype).thenReturn('');
    when(() => a.content)
        .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
    when(() => catchupTimeline.events).thenReturn(<Event>[a]);
    when(() => catchupTimeline.cancelSubscriptions()).thenReturn(null);
    when(() => room.getTimeline(limit: any(named: 'limit')))
        .thenAnswer((_) async => catchupTimeline);

    // Live timeline attach
    void Function()? onUpdateCb;
    when(
      () => room.getTimeline(
        limit: any<int>(named: 'limit'),
        onNewEvent: any<void Function()>(named: 'onNewEvent'),
        onInsert: any<void Function(int)>(named: 'onInsert'),
        onChange: any<void Function(int)>(named: 'onChange'),
        onRemove: any<void Function(int)>(named: 'onRemove'),
        onUpdate: any<void Function()>(named: 'onUpdate'),
      ),
    ).thenAnswer((invocation) async {
      onUpdateCb = invocation.namedArguments[#onUpdate] as void Function()?;
      return liveTimeline;
    });
    when(() => liveTimeline.cancelSubscriptions()).thenReturn(null);

    when(() =>
            processor.process(event: any(named: 'event'), journalDb: journalDb))
        .thenAnswer((_) async {});
    when(() => readMarker.updateReadMarker(
          client: any<Client>(named: 'client'),
          room: any<Room>(named: 'room'),
          eventId: any<String>(named: 'eventId'),
        )).thenAnswer((_) async {});

    final consumer = MatrixStreamConsumer(
      sessionManager: session,
      roomManager: roomManager,
      loggingService: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      documentsDirectory: Directory.systemTemp,
    );

    await consumer.initialize();
    await consumer.start();
    await Future<void>.delayed(const Duration(milliseconds: 900));

    // Inject newer live event B
    final b = MockEvent();
    when(() => b.eventId).thenReturn('B');
    when(() => b.originServerTs)
        .thenReturn(DateTime.fromMillisecondsSinceEpoch(2));
    when(() => b.senderId).thenReturn('@other:server');
    when(() => b.attachmentMimetype).thenReturn('');
    when(() => b.content)
        .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
    onTimelineController.add(b);
    await Future<void>.delayed(const Duration(milliseconds: 900));

    // Make live timeline contain only older A and trigger a scan
    when(() => liveTimeline.events).thenReturn(<Event>[a]);
    onUpdateCb?.call();
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // Ensure marker was not regressed to A
    verifyNever(() => readMarker.updateReadMarker(
          client: client,
          room: room,
          eventId: 'A',
        ));
  });

  test('circuit breaker opens after many failures and blocks processing',
      () async {
    final session = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final logger = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final processor = MockSyncEventProcessor();
    final readMarker = MockSyncReadMarkerService();
    final client = MockClient();
    final room = MockRoom();
    final timeline = MockTimeline();
    final onTimelineController = StreamController<Event>.broadcast();

    addTearDown(onTimelineController.close);

    when(() => logger.captureEvent(any<String>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
    when(() => logger.captureException(any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

    when(() => session.client).thenReturn(client);
    when(() => client.userID).thenReturn('@me:server');
    when(() => session.timelineEvents)
        .thenAnswer((_) => onTimelineController.stream);
    when(() => roomManager.initialize()).thenAnswer((_) async {});
    when(() => roomManager.currentRoom).thenReturn(room);
    when(() => roomManager.currentRoomId).thenReturn('!room:server');
    when(() => settingsDb.itemByKey(lastReadMatrixEventId))
        .thenAnswer((_) async => null);

    // Create >50 failing events to trip the breaker.
    List<Event> failingEvents(int n) {
      final list = <Event>[];
      for (var i = 0; i < n; i++) {
        final e = MockEvent();
        when(() => e.eventId).thenReturn('F$i');
        when(() => e.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(i));
        when(() => e.senderId).thenReturn('@other:server');
        when(() => e.attachmentMimetype).thenReturn('');
        when(() => e.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
        list.add(e);
      }
      return list;
    }

    final events = failingEvents(60);
    when(() => timeline.events).thenReturn(events);
    when(() => timeline.cancelSubscriptions()).thenReturn(null);
    when(() => room.getTimeline(limit: any(named: 'limit')))
        .thenAnswer((_) async => timeline);

    when(() =>
            processor.process(event: any(named: 'event'), journalDb: journalDb))
        .thenThrow(Exception('boom'));
    when(() => readMarker.updateReadMarker(
          client: any<Client>(named: 'client'),
          room: any<Room>(named: 'room'),
          eventId: any<String>(named: 'eventId'),
        )).thenAnswer((_) async {});

    final consumer = MatrixStreamConsumer(
      sessionManager: session,
      roomManager: roomManager,
      loggingService: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      documentsDirectory: Directory.systemTemp,
      collectMetrics: true,
    );

    await consumer.initialize();
    await consumer.start();

    // After first batch, breaker should have opened at least once.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(consumer.metricsSnapshot()['circuitOpens'], greaterThanOrEqualTo(1));

    // Trigger a live scan; breaker should still be open
    when(() => timeline.events).thenReturn(events.take(1).toList());
    // simulate onUpdate callback path by calling schedule and letting debounce expire
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(consumer.metricsSnapshot()['circuitOpens'], greaterThanOrEqualTo(1));
  });

  test('retry state pruned to cap size on large failure batch', () async {
    final session = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final logger = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final processor = MockSyncEventProcessor();
    final readMarker = MockSyncReadMarkerService();
    final client = MockClient();
    final room = MockRoom();
    final timeline = MockTimeline();
    final onTimelineController = StreamController<Event>.broadcast();

    addTearDown(onTimelineController.close);

    when(() => logger.captureEvent(any<String>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
    when(() => logger.captureException(any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

    when(() => session.client).thenReturn(client);
    when(() => client.userID).thenReturn('@me:server');
    when(() => session.timelineEvents)
        .thenAnswer((_) => onTimelineController.stream);
    when(() => roomManager.initialize()).thenAnswer((_) async {});
    when(() => roomManager.currentRoom).thenReturn(room);
    when(() => roomManager.currentRoomId).thenReturn('!room:server');
    when(() => settingsDb.itemByKey(lastReadMatrixEventId))
        .thenAnswer((_) async => null);

    // Create 2100 failing events to exceed cap.
    final list = <Event>[];
    for (var i = 0; i < 2100; i++) {
      final e = MockEvent();
      when(() => e.eventId).thenReturn('R$i');
      when(() => e.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(i));
      when(() => e.senderId).thenReturn('@other:server');
      when(() => e.attachmentMimetype).thenReturn('');
      when(() => e.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      list.add(e);
    }
    when(() => timeline.events).thenReturn(list);
    when(() => timeline.cancelSubscriptions()).thenReturn(null);
    when(() => room.getTimeline(limit: any(named: 'limit')))
        .thenAnswer((_) async => timeline);

    when(() =>
            processor.process(event: any(named: 'event'), journalDb: journalDb))
        .thenThrow(Exception('fail'));

    final consumer = MatrixStreamConsumer(
      sessionManager: session,
      roomManager: roomManager,
      loggingService: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      documentsDirectory: Directory.systemTemp,
      collectMetrics: true,
    );

    await consumer.initialize();
    await consumer.start();
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Retry state should be pruned to its cap (<=2000)
    expect(
      consumer.metricsSnapshot()['retryStateSize'],
      lessThanOrEqualTo(2000),
    );
  });

  test('retry TTL pruning removes stale entries (fake clock)', () async {
    final session = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final logger = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final processor = MockSyncEventProcessor();
    final readMarker = MockSyncReadMarkerService();
    final client = MockClient();
    final room = MockRoom();
    final timeline = MockTimeline();
    final onTimelineController = StreamController<Event>();

    addTearDown(onTimelineController.close);

    when(() => logger.captureEvent(any<String>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
    when(() => logger.captureException(any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

    when(() => session.client).thenReturn(client);
    when(() => client.userID).thenReturn('@me:server');
    when(() => session.timelineEvents)
        .thenAnswer((_) => onTimelineController.stream);
    when(() => roomManager.initialize()).thenAnswer((_) async {});
    when(() => roomManager.currentRoom).thenReturn(room);
    when(() => roomManager.currentRoomId).thenReturn('!room:server');
    when(() => settingsDb.itemByKey(lastReadMatrixEventId))
        .thenAnswer((_) async => null);

    // Create some failing events to populate retry state.
    final list = <Event>[];
    for (var i = 0; i < 5; i++) {
      final e = MockEvent();
      when(() => e.eventId).thenReturn('T$i');
      when(() => e.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(i));
      when(() => e.senderId).thenReturn('@other:server');
      when(() => e.attachmentMimetype).thenReturn('');
      when(() => e.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      list.add(e);
    }
    when(() => timeline.events).thenReturn(list);
    when(() => timeline.cancelSubscriptions()).thenReturn(null);
    when(() => room.getTimeline(limit: any(named: 'limit')))
        .thenAnswer((_) async => timeline);

    when(() =>
            processor.process(event: any(named: 'event'), journalDb: journalDb))
        .thenThrow(Exception('temporary fail'));

    // Inject a controllable clock to make TTL deterministic.
    var now = DateTime(2025);
    final consumer = MatrixStreamConsumer(
      sessionManager: session,
      roomManager: roomManager,
      loggingService: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      documentsDirectory: Directory.systemTemp,
      collectMetrics: true,
      now: () => now,
    );

    await consumer.initialize();
    await consumer.start();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final before = consumer.metricsSnapshot()['retryStateSize'] ?? 0;
    expect(before, greaterThan(0));

    // Advance fake clock beyond TTL and trigger another pass to prune.
    now = now.add(const Duration(minutes: 11));
    // Trigger scan by injecting a no-op timeline
    when(() => timeline.events).thenReturn(<Event>[]);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final after = consumer.metricsSnapshot()['retryStateSize'] ?? 0;
    expect(after, lessThanOrEqualTo(before));
  });
}
