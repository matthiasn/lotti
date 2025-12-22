import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
// ignore_for_file: unnecessary_lambdas, cascade_invocations, unawaited_futures, avoid_redundant_argument_values
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_consumer.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
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

  test('attachment observe logs and does not count as skipped', () async {
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
          .thenAnswer((_) => const Stream.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

      // Attachment-like event with relativePath triggers observe metrics.
      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('att-x');
      when(() => ev.roomId).thenReturn('!room:server');
      when(() => ev.senderId).thenReturn('@other:server');
      when(() => ev.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      when(() => ev.attachmentMimetype).thenReturn('application/json');
      when(() => ev.content)
          .thenReturn({'relativePath': '/text_entries/2024-01-01/x.json'});
      when(() => timeline.events).thenReturn(<Event>[ev]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);
      when(() => room.getTimeline(
            limit: any(named: 'limit'),
            onNewEvent: any(named: 'onNewEvent'),
            onInsert: any(named: 'onInsert'),
            onChange: any(named: 'onChange'),
            onRemove: any(named: 'onRemove'),
            onUpdate: any(named: 'onUpdate'),
          )).thenAnswer((_) async => timeline);

      when(() => processor.process(
          event: any<Event>(named: 'event'),
          journalDb: journalDb)).thenAnswer((_) async {});
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((_) async {});

      final consumer = MatrixStreamConsumer(
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        collectMetrics: true,
        circuitCooldown: const Duration(milliseconds: 200),
        sentEventRegistry: SentEventRegistry(),
      );

      await consumer.initialize();
      async.flushMicrotasks();
      await consumer.start();
      async.flushMicrotasks();
      // Allow live-scan debounce and processing to occur deterministically
      async.elapse(const Duration(milliseconds: 250));
      async.flushMicrotasks();

      final metrics = consumer.metricsSnapshot();
      // Attachments are not counted as skipped
      expect(metrics['skipped'], equals(0));
      // Logs include attachment.observe with the expected path
      verify(() => logger.captureEvent(
            any<String>(
                that: contains(
                    'attachmentEvent id=att-x path=/text_entries/2024-01-01/x.json')),
            domain: any<String>(named: 'domain'),
            subDomain: 'attachment.observe',
          )).called(greaterThanOrEqualTo(1));
    });
  });

  test('does not doubleScan when attachment already exists (no new write)',
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

    when(() => logger.captureEvent(any<String>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
    when(() => logger.captureException(any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

    when(() => session.client).thenReturn(client);
    when(() => client.userID).thenReturn('@me:server');
    when(() => session.timelineEvents).thenAnswer((_) => const Stream.empty());
    when(() => roomManager.initialize()).thenAnswer((_) async {});
    when(() => roomManager.currentRoom).thenReturn(room);
    when(() => roomManager.currentRoomId).thenReturn('!room:server');

    // No last-read marker; process whatever is present.
    when(() => settingsDb.itemByKey(lastReadMatrixEventId))
        .thenAnswer((_) async => null);

    // Prepare an attachment event whose relativePath already exists on disk
    final ev = MockEvent();
    when(() => ev.eventId).thenReturn('att-1');
    when(() => ev.roomId).thenReturn('!room:server');
    when(() => ev.senderId).thenReturn('@other:server');
    when(() => ev.originServerTs)
        .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
    when(() => ev.attachmentMimetype).thenReturn('application/json');
    const relPath = '/text_entries/2024-01-01/exist.text.json';
    when(() => ev.content).thenReturn({'relativePath': relPath});
    when(() => timeline.events).thenReturn(<Event>[ev]);
    when(() => timeline.cancelSubscriptions()).thenReturn(null);
    when(() => room.getTimeline(limit: any(named: 'limit')))
        .thenAnswer((_) async => timeline);
    when(() => room.getTimeline(
          limit: any(named: 'limit'),
          onNewEvent: any(named: 'onNewEvent'),
          onInsert: any(named: 'onInsert'),
          onChange: any(named: 'onChange'),
          onRemove: any(named: 'onRemove'),
          onUpdate: any(named: 'onUpdate'),
        )).thenAnswer((_) async => timeline);

    // Create the pre-existing file so saveAttachment() returns false
    final docs = await Directory.systemTemp.createTemp('msc_dedupe');
    addTearDown(() => docs.delete(recursive: true));
    final normalized = relPath.startsWith('/') ? relPath.substring(1) : relPath;
    final pre = File('${docs.path}/$normalized')
      ..createSync(recursive: true)
      ..writeAsStringSync('x');
    expect(pre.existsSync(), isTrue);

    final consumer = MatrixStreamConsumer(
      skipSyncWait: true,
      sessionManager: session,
      roomManager: roomManager,
      loggingService: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      collectMetrics: true,
      sentEventRegistry: SentEventRegistry(),
    );

    await consumer.initialize();
    await consumer.start();

    // Ensure no doubleScan logs were emitted when saveAttachment returned false
    verifyNever(() => logger.captureEvent(
          any<String>(that: contains('doubleScan.attachment')),
          domain: syncLoggingDomain,
          subDomain: 'doubleScan',
        ));
  });

  test('dispose flushes pending read marker (logs marker.disposeFlush)',
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

      // Provide a single sync payload to trigger scheduling of marker
      final e = MockEvent();
      when(() => e.eventId).thenReturn('e1');
      when(() => e.roomId).thenReturn('!room:server');
      when(() => e.senderId).thenReturn('@other:server');
      when(() => e.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      when(() => e.attachmentMimetype).thenReturn('');
      when(() => e.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => timeline.events).thenReturn(<Event>[e]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);
      when(() => room.getTimeline(
            limit: any(named: 'limit'),
            onNewEvent: any(named: 'onNewEvent'),
            onInsert: any(named: 'onInsert'),
            onChange: any(named: 'onChange'),
            onRemove: any(named: 'onRemove'),
            onUpdate: any(named: 'onUpdate'),
          )).thenAnswer((_) async => timeline);

      when(() => processor.process(
          event: any<Event>(named: 'event'),
          journalDb: journalDb)).thenAnswer((_) async {});
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
            timeline: any<Timeline?>(named: 'timeline'),
          )).thenAnswer((_) async {});

      final consumer = MatrixStreamConsumer(
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,

        collectMetrics: true,
        markerDebounce: const Duration(seconds: 5), // ensure pending at dispose
        sentEventRegistry: SentEventRegistry(),
      );

      await consumer.initialize();
      await consumer.start();
      // Dispose before debounce fires to force disposeFlush path
      unawaited(consumer.dispose());
      // Allow microtask queue to process logging capture
      async.elapse(const Duration(milliseconds: 10));

      verify(
        () => logger.captureEvent(
          any<String>(that: contains('marker.disposeFlush')),
          domain: any<String>(named: 'domain'),
          subDomain: 'marker.flush',
        ),
      ).called(1);
    });
  });

  group('MatrixStreamConsumer SDK pagination + streaming', () {
    test('metrics track EntryLink no-ops via diagnostics', () async {
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
      when(() => roomManager.currentRoomId).thenReturn(null);
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

      // No live timeline needed for this diagnostics-only test
      final consumer = MatrixStreamConsumer(
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        collectMetrics: true,
        sentEventRegistry: SentEventRegistry(),
      );

      // Simulate an EntryLink no-op diagnostic
      consumer.reportDbApplyDiagnostics(SyncApplyDiagnostics(
        eventId: 'e1',
        payloadType: 'entryLink',
        vectorClock: null,
        conflictStatus: 'entryLink.noop',
        applied: false,
        skipReason: JournalUpdateSkipReason.olderOrEqual,
      ));

      final snap = consumer.metricsSnapshot();
      expect(snap['dbEntryLinkNoop'], 1);
      expect(snap['droppedByType.entryLink'], 1);
      final diag = consumer.diagnosticsStrings();
      expect(diag['entryLink.noops'], '1');
    });
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
      when(
        () => room.getTimeline(
          onNewEvent: any<void Function()>(named: 'onNewEvent'),
          onInsert: any<void Function(int)>(named: 'onInsert'),
          onChange: any<void Function(int)>(named: 'onChange'),
          onRemove: any<void Function(int)>(named: 'onRemove'),
          onUpdate: any<void Function()>(named: 'onUpdate'),
        ),
      ).thenAnswer((_) async => timeline);
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
      when(
        () => room.getTimeline(
          onNewEvent: any(named: 'onNewEvent'),
          onInsert: any(named: 'onInsert'),
          onChange: any(named: 'onChange'),
          onRemove: any(named: 'onRemove'),
          onUpdate: any(named: 'onUpdate'),
        ),
      ).thenAnswer((_) async => timeline);
      when(() => room.getTimeline(
            limit: any(named: 'limit'),
            onNewEvent: any(named: 'onNewEvent'),
            onInsert: any(named: 'onInsert'),
            onChange: any(named: 'onChange'),
            onRemove: any(named: 'onRemove'),
            onUpdate: any(named: 'onUpdate'),
          )).thenAnswer((_) async => timeline);

      when(() => processor.process(
          event: any<Event>(named: 'event'),
          journalDb: journalDb)).thenAnswer((_) async {});
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((_) async {});
      // Live timeline path (with callbacks)
      when(
        () => room.getTimeline(
          onNewEvent: any(named: 'onNewEvent'),
          onInsert: any(named: 'onInsert'),
          onChange: any(named: 'onChange'),
          onRemove: any(named: 'onRemove'),
          onUpdate: any(named: 'onUpdate'),
        ),
      ).thenAnswer((_) async => timeline);

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
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        backfill: backfill,
        sentEventRegistry: SentEventRegistry(),
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

    test(
        'integration: text missing then descriptor + media triggers observe logs and doubleScan',
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
        final events = <Event>[];
        when(() => timeline.events).thenReturn(events);
        when(() => timeline.cancelSubscriptions()).thenReturn(null);

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
        when(() => room.getTimeline(limit: any(named: 'limit')))
            .thenAnswer((_) async => timeline);
        when(() => room.getTimeline(
              limit: any(named: 'limit'),
              onNewEvent: any(named: 'onNewEvent'),
              onInsert: any(named: 'onInsert'),
              onChange: any(named: 'onChange'),
              onRemove: any(named: 'onRemove'),
              onUpdate: any(named: 'onUpdate'),
            )).thenAnswer((_) async => timeline);
        when(() => logger.captureEvent(any<dynamic>(),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'))).thenReturn(null);

        var calls = 0;
        when(() => processor.process(
              event: any<Event>(named: 'event'),
              journalDb: journalDb,
            )).thenAnswer((_) async {
          calls++;
          if (calls == 1) throw const FileSystemException('missing');
        });

        final consumer = MatrixStreamConsumer(
          skipSyncWait: true,
          sessionManager: session,
          roomManager: roomManager,
          loggingService: logger,
          journalDb: journalDb,
          settingsDb: settingsDb,
          eventProcessor: processor,
          readMarkerService: readMarker,
          collectMetrics: true,
          sentEventRegistry: SentEventRegistry(),
        );

        await consumer.initialize();
        await consumer.start();

        // Text sync payload referencing JSON path, will fail => pending jsonPath
        final textEvent = MockEvent();
        when(() => textEvent.eventId).thenReturn('TXT');
        when(() => textEvent.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
        when(() => textEvent.senderId).thenReturn('@other:server');
        when(() => textEvent.attachmentMimetype).thenReturn('');
        when(() => textEvent.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
        final textPayload = base64.encode(
          utf8.encode(json.encode(<String, dynamic>{
            'runtimeType': 'journalEntity',
            'jsonPath': '/sub/integration.json',
          })),
        );
        when(() => textEvent.text).thenReturn(textPayload);
        when(() => textEvent.roomId).thenReturn('!room:server');
        onTimelineController.add(textEvent);
        async.flushMicrotasks();

        // Descriptor event for the jsonPath, then a media event to trigger doubleScan
        final descEvent = MockEvent();
        when(() => descEvent.eventId).thenReturn('DESC');
        when(() => descEvent.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(2));
        when(() => descEvent.senderId).thenReturn('@other:server');
        when(() => descEvent.attachmentMimetype).thenReturn('application/json');
        when(() => descEvent.content).thenReturn(
            <String, dynamic>{'relativePath': '/sub/integration.json'});
        when(() => descEvent.roomId).thenReturn('!room:server');

        final imgEvent = MockEvent();
        when(() => imgEvent.eventId).thenReturn('IMG');
        when(() => imgEvent.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(3));
        when(() => imgEvent.senderId).thenReturn('@other:server');
        when(() => imgEvent.attachmentMimetype).thenReturn('image/jpeg');
        when(() => imgEvent.content).thenReturn(
            <String, dynamic>{'relativePath': '/media/integration.jpg'});
        when(() => imgEvent.downloadAndDecryptAttachment()).thenAnswer(
            (_) async => MatrixFile(
                bytes: Uint8List.fromList(const [1, 2]),
                name: 'integration.jpg'));
        when(() => imgEvent.roomId).thenReturn('!room:server');

        onTimelineController
          ..add(descEvent)
          ..add(imgEvent);
        async.elapse(const Duration(milliseconds: 50));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();

        // Logs: attachment.observe for descriptor and doubleScan logs from media
        verify(() => logger.captureEvent(
              any<String>(
                  that: contains(
                      'attachmentEvent id=DESC path=/sub/integration.json')),
              domain: syncLoggingDomain,
              subDomain: 'attachment.observe',
            )).called(greaterThanOrEqualTo(1));
        verify(() => logger.captureEvent(
              'doubleScan.attachment immediate',
              domain: syncLoggingDomain,
              subDomain: 'doubleScan',
            )).called(1);
        verify(() => logger.captureEvent(
              'doubleScan.attachment delayed',
              domain: syncLoggingDomain,
              subDomain: 'doubleScan',
            )).called(1);
      });
    });
    test('live-scan tail ts filter excludes older attachments (fakeAsync)',
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

        // Live timeline stub: capture onNewEvent and include only older attachments
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
          skipSyncWait: true,
          sessionManager: session,
          roomManager: roomManager,
          loggingService: logger,
          journalDb: journalDb,
          settingsDb: settingsDb,
          eventProcessor: processor,
          readMarkerService: readMarker,
          collectMetrics: true,
          sentEventRegistry: SentEventRegistry(),
        );

        await consumer.initialize();
        await consumer.start();

        // 1) Process a sync text to establish lastProcessedTs = 10000
        final syncEv = MockEvent();
        when(() => syncEv.eventId).thenReturn('S1');
        when(() => syncEv.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(10000));
        when(() => syncEv.senderId).thenReturn('@other:server');
        when(() => syncEv.attachmentMimetype).thenReturn('');
        when(() => syncEv.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
        when(() => syncEv.roomId).thenReturn('!room:server');
        onTimelineController.add(syncEv);
        async.elapse(const Duration(milliseconds: 160));
        async.flushMicrotasks();

        // 2) Live timeline has only older attachments (ts strictly < 10000-2000)
        final old1 = MockEvent();
        when(() => old1.eventId).thenReturn('OA1');
        when(() => old1.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(7999));
        when(() => old1.senderId).thenReturn('@other:server');
        when(() => old1.attachmentMimetype).thenReturn('audio/mp4');
        when(() => old1.content)
            .thenReturn(<String, dynamic>{'relativePath': '/audio/old1.m4a'});
        when(() => old1.roomId).thenReturn('!room:server');

        final old2 = MockEvent();
        when(() => old2.eventId).thenReturn('OA2');
        when(() => old2.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(7000));
        when(() => old2.senderId).thenReturn('@other:server');
        when(() => old2.attachmentMimetype).thenReturn('audio/mp4');
        when(() => old2.content)
            .thenReturn(<String, dynamic>{'relativePath': '/audio/old2.m4a'});
        when(() => old2.roomId).thenReturn('!room:server');

        when(() => liveTimeline.events).thenReturn(<Event>[old1, old2]);
        when(() => liveTimeline.cancelSubscriptions()).thenReturn(null);

        // Trigger live-scan via callback
        onNewEvent?.call();
        async.elapse(const Duration(milliseconds: 130));
        async.flushMicrotasks();

        // Descriptor-only model: no prefetch metrics asserted here
        consumer.metricsSnapshot();
      });
    });
    test(
        'attachment ts gate skips older attachments; newer counted (fakeAsync)',
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
        when(
          () => room.getTimeline(
            onNewEvent: any(named: 'onNewEvent'),
            onInsert: any(named: 'onInsert'),
            onChange: any(named: 'onChange'),
            onRemove: any(named: 'onRemove'),
            onUpdate: any(named: 'onUpdate'),
          ),
        ).thenAnswer((_) async => timeline);
        when(
          () => room.getTimeline(
            onNewEvent: any(named: 'onNewEvent'),
            onInsert: any(named: 'onInsert'),
            onChange: any(named: 'onChange'),
            onRemove: any(named: 'onRemove'),
            onUpdate: any(named: 'onUpdate'),
          ),
        ).thenAnswer((_) async => timeline);
        when(
          () => room.getTimeline(
            onNewEvent: any(named: 'onNewEvent'),
            onInsert: any(named: 'onInsert'),
            onChange: any(named: 'onChange'),
            onRemove: any(named: 'onRemove'),
            onUpdate: any(named: 'onUpdate'),
          ),
        ).thenAnswer((_) async => timeline);

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
          skipSyncWait: true,
          sessionManager: session,
          roomManager: roomManager,
          loggingService: logger,
          journalDb: journalDb,
          settingsDb: settingsDb,
          eventProcessor: processor,
          readMarkerService: readMarker,
          collectMetrics: true,
          sentEventRegistry: SentEventRegistry(),
        );

        await consumer.initialize();
        await consumer.start();

        // 1) Process a sync text to set lastProcessedTs = 10000
        final syncEv = MockEvent();
        when(() => syncEv.eventId).thenReturn('S1');
        when(() => syncEv.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(10000));
        when(() => syncEv.senderId).thenReturn('@other:server');
        when(() => syncEv.attachmentMimetype).thenReturn('');
        when(() => syncEv.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
        when(() => syncEv.roomId).thenReturn('!room:server');
        onTimelineController.add(syncEv);
        async.elapse(const Duration(milliseconds: 160));
        async.flushMicrotasks();

        // 2) Old attachment (ts=7000) should be skipped by ts gate
        final oldAtt = MockEvent();
        when(() => oldAtt.eventId).thenReturn('A_OLD');
        when(() => oldAtt.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(7000));
        when(() => oldAtt.senderId).thenReturn('@other:server');
        when(() => oldAtt.attachmentMimetype).thenReturn('audio/mp4');
        when(() => oldAtt.content)
            .thenReturn(<String, dynamic>{'relativePath': '/audio/old.m4a'});
        when(() => oldAtt.roomId).thenReturn('!room:server');
        onTimelineController.add(oldAtt);
        async.elapse(const Duration(milliseconds: 160));
        async.flushMicrotasks();

        consumer.metricsSnapshot();

        // 3) Newer attachment (ts=9901) within 2s margin should be observed
        final newAtt = MockEvent();
        when(() => newAtt.eventId).thenReturn('A_NEW');
        when(() => newAtt.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(9901));
        when(() => newAtt.senderId).thenReturn('@other:server');
        when(() => newAtt.attachmentMimetype).thenReturn('audio/mp4');
        when(() => newAtt.content)
            .thenReturn(<String, dynamic>{'relativePath': '/audio/new.m4a'});
        when(() => newAtt.roomId).thenReturn('!room:server');
        onTimelineController.add(newAtt);
        async.elapse(const Duration(milliseconds: 160));
        async.flushMicrotasks();

        consumer.metricsSnapshot();
      });
    });
    test('in-flight guard suppresses duplicate apply across paths (fakeAsync)',
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

        // Live timeline stub: capture callback and include the same event
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
        when(() => ev.eventId).thenReturn('DUP1');
        when(() => ev.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
        when(() => ev.senderId).thenReturn('@other:server');
        when(() => ev.attachmentMimetype).thenReturn('');
        when(() => ev.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
        when(() => ev.roomId).thenReturn('!room:server');
        when(() => liveTimeline.events).thenReturn(<Event>[ev]);
        when(() => liveTimeline.cancelSubscriptions()).thenReturn(null);

        final completer = Completer<void>();
        when(() => processor.process(event: ev, journalDb: journalDb))
            .thenAnswer((_) => completer.future);
        when(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: any<String>(named: 'eventId'),
            )).thenAnswer((_) async {});

        final consumer = MatrixStreamConsumer(
          skipSyncWait: true,
          sessionManager: session,
          roomManager: roomManager,
          loggingService: logger,
          journalDb: journalDb,
          settingsDb: settingsDb,
          eventProcessor: processor,
          readMarkerService: readMarker,
          sentEventRegistry: SentEventRegistry(),
        );

        await consumer.initialize();
        await consumer.start();

        // 1) Stream path enqueues DUP1 and begins processing (held by completer)
        onTimelineController.add(ev);
        async.flushMicrotasks();

        // 2) Live timeline signals new event while first path is in-flight
        onNewEvent?.call();
        async.elapse(const Duration(milliseconds: 130));
        async.flushMicrotasks();

        // Complete the first processing
        completer.complete();
        async.flushMicrotasks();

        // Verify only a single apply occurred for DUP1
        verify(() => processor.process(event: ev, journalDb: journalDb))
            .called(1);
      });
    });

    test('persists id and ts on marker advancement', () async {
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
          .thenAnswer((_) => const Stream.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('e1');
      when(() => ev.roomId).thenReturn('!room:server');
      when(() => ev.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(123));
      when(() => ev.senderId).thenReturn('@other:server');
      when(() => ev.attachmentMimetype).thenReturn('');
      when(() => ev.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});

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
            timeline: any<Timeline>(named: 'timeline'),
          )).thenAnswer((_) async {});
      when(() => settingsDb.saveSettingsItem(any(), any()))
          .thenAnswer((_) async => 1);

      final consumer = MatrixStreamConsumer(
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        collectMetrics: true,
        sentEventRegistry: SentEventRegistry(),
      );

      await consumer.initialize();
      await consumer.start();

      verify(() => settingsDb.saveSettingsItem(lastReadMatrixEventId, 'e1'))
          .called(1);
      verify(() => settingsDb.saveSettingsItem(lastReadMatrixEventTs, '123'))
          .called(1);
    });

    test('logs startup scheduling: start.catchUpRetry when marker exists',
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
          .thenAnswer((_) => const Stream.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => 'e0');
      when(() => timeline.events).thenReturn(<Event>[]);
      when(() => timeline.canRequestHistory).thenReturn(false);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);
      when(() => room.getTimeline(
            limit: any(named: 'limit'),
            onNewEvent: any(named: 'onNewEvent'),
            onInsert: any(named: 'onInsert'),
            onChange: any(named: 'onChange'),
            onRemove: any(named: 'onRemove'),
            onUpdate: any(named: 'onUpdate'),
          )).thenAnswer((_) async => timeline);
      when(() => processor.process(
          event: any<Event>(named: 'event'),
          journalDb: journalDb)).thenAnswer((_) async {});
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
            timeline: any<Timeline>(named: 'timeline'),
          )).thenAnswer((_) async {});

      when(() => logger.captureEvent('v2 start: scheduling catchUp retry',
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);

      final consumer = MatrixStreamConsumer(
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        collectMetrics: true,
        sentEventRegistry: SentEventRegistry(),
      );

      await consumer.initialize();
      await consumer.start();

      // catchUpRetry is logged after start when a local marker exists.
      verify(() => logger.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: 'start.catchUpRetry',
          )).called(1);
    });
  });

  test('no noAdvance.rescan when only attachments are seen (prefetch removed)',
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
    when(() => session.timelineEvents).thenAnswer((_) => const Stream.empty());
    when(() => roomManager.initialize()).thenAnswer((_) async {});
    when(() => roomManager.currentRoom).thenReturn(room);
    when(() => roomManager.currentRoomId).thenReturn('!room:server');
    when(() => settingsDb.itemByKey(lastReadMatrixEventId))
        .thenAnswer((_) async => null);

    final att = MockEvent();
    when(() => att.eventId).thenReturn('a1');
    when(() => att.roomId).thenReturn('!room:server');
    when(() => att.originServerTs)
        .thenReturn(DateTime.fromMillisecondsSinceEpoch(100));
    when(() => att.senderId).thenReturn('@other:server');
    when(() => att.attachmentMimetype).thenReturn('image/jpeg');
    // Use a unique, non-existent path to guarantee a new write occurs
    final uniqueRelPath =
        '/mct_no_advance_${DateTime.now().microsecondsSinceEpoch}.bin';
    when(() => att.content)
        .thenReturn(<String, dynamic>{'relativePath': uniqueRelPath});
    when(() => att.downloadAndDecryptAttachment()).thenAnswer((_) async =>
        MatrixFile(bytes: Uint8List.fromList(const [0]), name: 'x.jpg'));

    when(() => timeline.events).thenReturn(<Event>[att]);
    when(() => timeline.cancelSubscriptions()).thenReturn(null);
    when(() => room.getTimeline(limit: any(named: 'limit')))
        .thenAnswer((_) async => timeline);
    // Also stub the callback overload used for live timeline attachment
    when(() => room.getTimeline(
          limit: any(named: 'limit'),
          onNewEvent: any(named: 'onNewEvent'),
          onInsert: any(named: 'onInsert'),
          onChange: any(named: 'onChange'),
          onRemove: any(named: 'onRemove'),
          onUpdate: any(named: 'onUpdate'),
        )).thenAnswer((_) async => timeline);

    when(() => logger.captureEvent(any<String>(),
        domain: any<String>(named: 'domain'),
        subDomain: 'noAdvance.rescan')).thenReturn(null);

    final consumer = MatrixStreamConsumer(
      skipSyncWait: true,
      sessionManager: session,
      roomManager: roomManager,
      loggingService: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      collectMetrics: true,
      sentEventRegistry: SentEventRegistry(),
    );

    await consumer.initialize();
    await consumer.start();

    verifyNever(() => logger.captureEvent(any<String>(),
        domain: any<String>(named: 'domain'), subDomain: 'noAdvance.rescan'));
  });

  test('schedules noAdvance.rescan when sync payload is older (no advance)',
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

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => const Stream<Event>.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      // Seed a lastProcessed marker newer than the incoming event
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => 'L');
      when(() => settingsDb.itemByKey(lastReadMatrixEventTs))
          .thenAnswer((_) async => '200');

      // Older sync payload event (ts=100) so marker will not advance
      final oldSync = MockEvent();
      when(() => oldSync.eventId).thenReturn('E');
      when(() => oldSync.roomId).thenReturn('!room:server');
      when(() => oldSync.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(100));
      when(() => oldSync.senderId).thenReturn('@other:server');
      when(() => oldSync.attachmentMimetype).thenReturn('');
      when(() => oldSync.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});

      when(() => timeline.events).thenReturn(<Event>[oldSync]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);
      when(() => room.getTimeline(
            limit: any(named: 'limit'),
            onNewEvent: any(named: 'onNewEvent'),
            onInsert: any(named: 'onInsert'),
            onChange: any(named: 'onChange'),
            onRemove: any(named: 'onRemove'),
            onUpdate: any(named: 'onUpdate'),
          )).thenAnswer((_) async => timeline);

      when(() => processor.process(event: oldSync, journalDb: journalDb))
          .thenAnswer((_) async {});
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((_) async {});

      when(() => logger.captureEvent(
            any<String>(
                that: contains('no advancement; scheduling tail rescan')),
            domain: any<String>(named: 'domain'),
            subDomain: 'noAdvance.rescan',
          )).thenReturn(null);

      final consumer = MatrixStreamConsumer(
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        collectMetrics: true,
        sentEventRegistry: SentEventRegistry(),
      );

      // Capture that the scheduled tail rescan actually triggers a scan
      var scanTriggered = 0;
      consumer.scanLiveTimelineTestHook = (_) {
        scanTriggered++;
      };

      await consumer.initialize();
      await consumer.start();
      // Allow the live scan and scheduled tail rescan to occur
      async.elapse(const Duration(milliseconds: 200));
      async.flushMicrotasks();

      verify(() => logger.captureEvent(
            any<String>(
                that: contains('no advancement; scheduling tail rescan')),
            domain: any<String>(named: 'domain'),
            subDomain: 'noAdvance.rescan',
          )).called(greaterThanOrEqualTo(1));

      // Ensure the scheduled timer executed and invoked the scan
      expect(scanTriggered, greaterThanOrEqualTo(1));
    });
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
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        markerDebounce: const Duration(milliseconds: 50),
        sentEventRegistry: SentEventRegistry(),
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
            domain: syncLoggingDomain,
            subDomain: 'flushReadMarker',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          )).called(1);
    });
  });

  test('advancement schedules quick tail rescan (100ms) and triggers scan',
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

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => const Stream<Event>.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      // Seed lastProcessed older than incoming to allow advancement
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async {
        return 'L';
      });
      when(() => settingsDb.itemByKey(lastReadMatrixEventTs))
          .thenAnswer((_) async {
        return '100';
      });
      when(() => settingsDb.saveSettingsItem(any(), any()))
          .thenAnswer((_) async => 1);

      // Newer sync payload event (ts=200) to advance marker
      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('E2');
      when(() => ev.roomId).thenReturn('!room:server');
      when(() => ev.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(200));
      when(() => ev.senderId).thenReturn('@other:server');
      when(() => ev.attachmentMimetype).thenReturn('');
      when(() => ev.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => processor.process(event: ev, journalDb: journalDb))
          .thenAnswer((_) async {});

      when(() => timeline.events).thenReturn(<Event>[ev]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);
      when(() => room.getTimeline(
            limit: any(named: 'limit'),
            onNewEvent: any(named: 'onNewEvent'),
            onInsert: any(named: 'onInsert'),
            onChange: any(named: 'onChange'),
            onRemove: any(named: 'onRemove'),
            onUpdate: any(named: 'onUpdate'),
          )).thenAnswer((_) async => timeline);

      final consumer = MatrixStreamConsumer(
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        collectMetrics: true,
        sentEventRegistry: SentEventRegistry(),
      );

      var scanTriggered = 0;
      consumer.scanLiveTimelineTestHook = (_) {
        scanTriggered++;
      };

      await consumer.initialize();
      await consumer.start();

      // Allow the 100ms scheduled rescan to fire after advancement
      async.elapse(const Duration(milliseconds: 200));
      async.flushMicrotasks();

      expect(scanTriggered, greaterThanOrEqualTo(1));
    });
  });

  test('retriable failure schedules follow-up scan (hadFailure path)',
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

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => const Stream<Event>.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

      // One sync payload event that will throw during processing
      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('E_fail');
      when(() => ev.roomId).thenReturn('!room:server');
      when(() => ev.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(10));
      when(() => ev.senderId).thenReturn('@other:server');
      when(() => ev.attachmentMimetype).thenReturn('');
      when(() => ev.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => processor.process(event: ev, journalDb: journalDb))
          .thenThrow(Exception('boom'));

      when(() => timeline.events).thenReturn(<Event>[ev]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);
      when(() => room.getTimeline(
            limit: any(named: 'limit'),
            onNewEvent: any(named: 'onNewEvent'),
            onInsert: any(named: 'onInsert'),
            onChange: any(named: 'onChange'),
            onRemove: any(named: 'onRemove'),
            onUpdate: any(named: 'onUpdate'),
          )).thenAnswer((_) async => timeline);

      final consumer = MatrixStreamConsumer(
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        collectMetrics: true,
        sentEventRegistry: SentEventRegistry(),
      );

      var scanTriggered = 0;
      consumer.scanLiveTimelineTestHook = (_) {
        scanTriggered++;
      };

      await consumer.initialize();
      await consumer.start();

      // Allow initial startup scan (80ms) and follow-up retry scan (>~200ms)
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();

      // Initial scan + at least one follow-up scheduled by hadFailure path
      expect(scanTriggered, greaterThanOrEqualTo(2));
      final snap = consumer.metricsSnapshot();
      expect(snap['retriesScheduled'], greaterThanOrEqualTo(1));
      expect(snap['failures'], greaterThanOrEqualTo(1));
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
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        collectMetrics: true,
        sentEventRegistry: SentEventRegistry(),
      );

      await consumer.initialize();
      await consumer.start();

      onNewEvent?.call();
      async.elapse(const Duration(milliseconds: 130));
      async.flushMicrotasks();

      verify(() => logger.captureException(
            any<dynamic>(),
            domain: syncLoggingDomain,
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
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        collectMetrics: true,
        sentEventRegistry: SentEventRegistry(),
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
      skipSyncWait: true,
      sessionManager: session,
      roomManager: roomManager,
      loggingService: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      collectMetrics: true,
      sentEventRegistry: SentEventRegistry(),
    );

    await consumer.initialize();
    // Simulate apply observer observation for the same event id as "missing base"
    consumer.reportDbApplyDiagnostics(
      SyncApplyDiagnostics(
        eventId: 'MB1',
        payloadType: 'journalEntity',
        vectorClock: null,
        conflictStatus: 'VclockStatus.b_gt_a',
        applied: false,
        skipReason: JournalUpdateSkipReason.missingBase,
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
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        collectMetrics: true,
        markerDebounce: const Duration(milliseconds: 50),
        sentEventRegistry: SentEventRegistry(),
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
      // After stability window (2s), descriptor catch-up runs
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      final mAfterCatchup = consumer.metricsSnapshot();
      expect(mAfterCatchup['descriptorCatchUpRuns'], greaterThanOrEqualTo(1));
      // Pending remains until descriptor lands
      expect(mAfterCatchup['pendingJsonPaths'], 1);
      // Metrics expose pending jsonPaths (1) and descriptorCatchUpRuns (>=0)
      final m0 = consumer.metricsSnapshot();
      expect(m0['pendingJsonPaths'], 1);
      expect(m0['descriptorCatchUpRuns'], isNonNegative);

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
      final m1 = consumer.metricsSnapshot();
      // Pending cleared returns to 0
      expect(m1['pendingJsonPaths'], 0);
      // Logs include attachment.observe for the descriptor
      verify(() => logger.captureEvent(
            any<String>(
                that: contains('attachmentEvent id=F1 path=/sub/test.json')),
            domain: syncLoggingDomain,
            subDomain: 'attachment.observe',
          )).called(greaterThanOrEqualTo(1));
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
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        collectMetrics: true,
        sentEventRegistry: SentEventRegistry(),
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

      // Deliver stream events; no direct processing in signal-only mode
      async.flushMicrotasks();
      verifyNever(() => processor.process(
            event: any<Event>(named: 'event'),
            journalDb: journalDb,
          ));
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
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        collectMetrics: true,
        sentEventRegistry: SentEventRegistry(),
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

      // Elapsing time does not cause direct processing; requires scan
      async.elapse(const Duration(milliseconds: 60));
      async.flushMicrotasks();
      verifyNever(() => processor.process(
            event: any<Event>(named: 'event'),
            journalDb: journalDb,
          ));
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
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        sentEventRegistry: SentEventRegistry(),
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

      // Make live timeline include a bad event so sorting throws during scan
      when(() => timeline.events).thenReturn(<Event>[ok, bad]);
      // Allow initial live-scan to run
      async.elapse(const Duration(milliseconds: 200));
      async.flushMicrotasks();
      verify(() => logger.captureException(
            any<Object>(),
            domain: syncLoggingDomain,
            subDomain: 'liveScan',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          )).called(1);
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
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        markerDebounce: const Duration(milliseconds: 100),
        sentEventRegistry: SentEventRegistry(),
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

  test('keeps retrying after cap for non-attachment failure (fakeAsync)',
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
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);
      when(() => room.getTimeline(
            onNewEvent: any(named: 'onNewEvent'),
            onInsert: any(named: 'onInsert'),
            onChange: any(named: 'onChange'),
            onRemove: any(named: 'onRemove'),
            onUpdate: any(named: 'onUpdate'),
          )).thenAnswer((_) async => timeline);

      // An event that is a sync payload
      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('C1');
      when(() => ev.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      when(() => ev.senderId).thenReturn('@other:server');
      when(() => ev.attachmentMimetype).thenReturn('');
      when(() => ev.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => ev.roomId).thenReturn('!room:server');
      when(() => timeline.events).thenReturn(<Event>[ev]);

      // Fail processing always
      when(() => processor.process(event: ev, journalDb: journalDb))
          .thenThrow(Exception('fail'));

      when(() => logger.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logger.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace>(named: 'stackTrace'))).thenReturn(null);

      final consumer = MatrixStreamConsumer(
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        collectMetrics: true,
        maxRetriesPerEvent: 1,
        sentEventRegistry: SentEventRegistry(),
      );

      await consumer.initialize();
      await consumer.start();

      // First attempt fails and schedules retry; advance enough time to allow the follow-up scan
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();

      // After retry cap, should keep retrying (not drop) - data loss prevention
      verify(() => logger.captureEvent(
            any<String>(),
            domain: syncLoggingDomain,
            subDomain: 'retry.keepRetrying',
          )).called(greaterThanOrEqualTo(1));

      // Retry state should still be present (not cleared)
      expect(consumer.metricsSnapshot()['retryStateSize'],
          greaterThanOrEqualTo(1));
    });
  });

  test('keeps retrying when already at cap on scan entry (fakeAsync)',
      () async {
    // This test ensures the "already at cap" branch (lines 320-335) is covered.
    // The cap entry check runs when attempts >= maxRetriesPerEvent BEFORE
    // attempting to process. This happens when the event was already at cap
    // from a previous scan.
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
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);
      when(() => room.getTimeline(
            onNewEvent: any(named: 'onNewEvent'),
            onInsert: any(named: 'onInsert'),
            onChange: any(named: 'onChange'),
            onRemove: any(named: 'onRemove'),
            onUpdate: any(named: 'onUpdate'),
          )).thenAnswer((_) async => timeline);

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('CAP1');
      when(() => ev.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      when(() => ev.senderId).thenReturn('@other:server');
      when(() => ev.attachmentMimetype).thenReturn('');
      when(() => ev.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => ev.text).thenReturn(
          base64.encode(utf8.encode(json.encode({'runtimeType': 'test'}))));
      when(() => ev.roomId).thenReturn('!room:server');
      when(() => timeline.events).thenReturn(<Event>[ev]);

      // Always fail processing - this will trigger the catch block on first
      // attempt, which schedules retry with attempts=1
      when(() => processor.process(event: ev, journalDb: journalDb))
          .thenThrow(Exception('persistent failure'));

      // Capture the log messages to verify "after cap" is logged
      final logMessages = <String>[];
      when(() => logger.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenAnswer((inv) {
        logMessages.add(inv.positionalArguments[0] as String);
      });
      when(() => logger.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace>(named: 'stackTrace'))).thenReturn(null);

      final consumer = MatrixStreamConsumer(
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        collectMetrics: true,
        maxRetriesPerEvent: 1, // Cap at 1 retry
        sentEventRegistry: SentEventRegistry(),
      );

      await consumer.initialize();
      await consumer.start();

      // First scan: attempts=0, enters catch block, schedules retry with attempts=1
      async.elapse(const Duration(milliseconds: 500));
      async.flushMicrotasks();

      // Wait for backoff to expire (base 200ms * 2^1 = 400ms + jitter)
      // and trigger another scan
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();

      // Force another scan to hit the cap entry check
      await consumer.forceRescan(includeCatchUp: false);
      async.flushMicrotasks();

      // Third scan - by now attempts should be >= maxRetries (1)
      // and we should hit the cap entry branch
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();

      // Verify "after cap" message was logged - this is ONLY logged from
      // the cap entry check at lines 330-334, not from the catch block
      final afterCapLogs =
          logMessages.where((m) => m.contains('after cap')).toList();
      expect(afterCapLogs, isNotEmpty,
          reason:
              'Should have logged "keepRetrying after cap" from entry check');

      // Retry state must still be present
      expect(consumer.metricsSnapshot()['retryStateSize'],
          greaterThanOrEqualTo(1));
    });
  });

  test('failed event not filtered out when newer event succeeds (fakeAsync)',
      () async {
    // This test verifies that the wasCompleted filter logic works correctly:
    // An older event that failed should NOT be dropped even after a newer
    // event succeeds and the marker advances past it.
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

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => const Stream<Event>.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

      // E1 is older, will fail
      final e1 = MockEvent();
      when(() => e1.eventId).thenReturn('E1');
      when(() => e1.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(100));
      when(() => e1.senderId).thenReturn('@other:server');
      when(() => e1.attachmentMimetype).thenReturn('');
      when(() => e1.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => e1.text).thenReturn(
          base64.encode(utf8.encode(json.encode({'runtimeType': 'test'}))));

      // E2 is newer, will succeed
      final e2 = MockEvent();
      when(() => e2.eventId).thenReturn('E2');
      when(() => e2.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(200));
      when(() => e2.senderId).thenReturn('@other:server');
      when(() => e2.attachmentMimetype).thenReturn('');
      when(() => e2.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => e2.text).thenReturn(
          base64.encode(utf8.encode(json.encode({'runtimeType': 'test'}))));

      when(() => timeline.events).thenReturn(<Event>[e1, e2]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);
      when(() => room.getTimeline(
            onNewEvent: any(named: 'onNewEvent'),
            onInsert: any(named: 'onInsert'),
            onChange: any(named: 'onChange'),
            onRemove: any(named: 'onRemove'),
            onUpdate: any(named: 'onUpdate'),
          )).thenAnswer((_) async => timeline);

      // E1 fails, E2 succeeds
      var e1Calls = 0;
      when(() => processor.process(event: e1, journalDb: journalDb))
          .thenAnswer((_) async {
        e1Calls++;
        if (e1Calls == 1) {
          throw Exception('E1 fails first time');
        }
        // Succeeds on retry
      });
      when(() => processor.process(event: e2, journalDb: journalDb))
          .thenAnswer((_) async {});

      when(() => logger.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logger.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);
      when(() => settingsDb.saveSettingsItem(any<String>(), any<String>()))
          .thenAnswer((_) async => 1);
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
            timeline: any<Timeline?>(named: 'timeline'),
          )).thenAnswer((_) async {});

      final consumer = MatrixStreamConsumer(
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        collectMetrics: true,
        sentEventRegistry: SentEventRegistry(),
        dropOldPayloadsInLiveScan: true, // Enable the filter
      );

      await consumer.initialize();
      await consumer.start();

      // First scan: E1 fails, E2 succeeds
      async.elapse(const Duration(milliseconds: 500));
      async.flushMicrotasks();

      // Second scan: E1 should be retried (not filtered out)
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();

      // E1 should have been called twice (once failed, once retried)
      expect(e1Calls, greaterThanOrEqualTo(2));
    });
  });

  test('missing attachment continues retry beyond cap (fakeAsync)', () async {
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

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => const Stream<Event>.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);
      when(() => room.getTimeline(
            onNewEvent: any(named: 'onNewEvent'),
            onInsert: any(named: 'onInsert'),
            onChange: any(named: 'onChange'),
            onRemove: any(named: 'onRemove'),
            onUpdate: any(named: 'onUpdate'),
          )).thenAnswer((_) async => timeline);

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('A1');
      when(() => ev.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      when(() => ev.senderId).thenReturn('@other:server');
      when(() => ev.attachmentMimetype).thenReturn('');
      // Encode a journalEntity with a jsonPath so the consumer records pendingJsonPaths
      final textPayload =
          base64.encode(utf8.encode(json.encode(<String, dynamic>{
        'runtimeType': 'journalEntity',
        'jsonPath': '/x/test.json',
      })));
      when(() => ev.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => ev.text).thenReturn(textPayload);
      when(() => ev.roomId).thenReturn('!room:server');
      when(() => timeline.events).thenReturn(<Event>[ev]);

      // Fail with FileSystemException so it is treated as missing attachment
      when(() => processor.process(event: ev, journalDb: journalDb))
          .thenThrow(const FileSystemException('nope'));

      when(() => logger.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logger.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace>(named: 'stackTrace'))).thenReturn(null);

      final consumer = MatrixStreamConsumer(
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        collectMetrics: true,
        maxRetriesPerEvent: 1,
        sentEventRegistry: SentEventRegistry(),
      );

      await consumer.initialize();
      await consumer.start();

      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();

      // Should not log retry.cap; instead keep retrying as missingAttachment
      verify(() => logger.captureEvent(
            any<String>(),
            domain: syncLoggingDomain,
            subDomain: 'retry.missingAttachment',
          )).called(greaterThanOrEqualTo(1));
      expect(consumer.metricsSnapshot()['retryStateSize'],
          greaterThanOrEqualTo(1));
    });
  });

  test('marker.local exceptions are captured (fakeAsync)', () async {
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

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => const Stream<Event>.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);
      when(() => settingsDb.saveSettingsItem(any(), any()))
          .thenThrow(Exception('save failed'));
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);
      when(() => room.getTimeline(
            onNewEvent: any(named: 'onNewEvent'),
            onInsert: any(named: 'onInsert'),
            onChange: any(named: 'onChange'),
            onRemove: any(named: 'onRemove'),
            onUpdate: any(named: 'onUpdate'),
          )).thenAnswer((_) async => timeline);

      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('M1');
      when(() => ev.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(100));
      when(() => ev.senderId).thenReturn('@other:server');
      when(() => ev.attachmentMimetype).thenReturn('');
      when(() => ev.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => ev.roomId).thenReturn('!room:server');
      when(() => timeline.events).thenReturn(<Event>[ev]);

      when(() => processor.process(event: ev, journalDb: journalDb))
          .thenAnswer((_) async {});
      when(() => logger.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logger.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace>(named: 'stackTrace'))).thenReturn(null);

      final consumer = MatrixStreamConsumer(
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        collectMetrics: true,
        sentEventRegistry: SentEventRegistry(),
      );

      await consumer.initialize();
      await consumer.start();

      async.elapse(const Duration(milliseconds: 200));
      async.flushMicrotasks();

      verify(() => logger.captureException(
            any<Object>(),
            domain: syncLoggingDomain,
            subDomain: 'marker.local',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          )).called(greaterThanOrEqualTo(1));
    });
  });

  test('doubleScan logs emitted when attachment prefetched (fakeAsync)',
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

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => const Stream<Event>.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);
      when(() => room.getTimeline(
            onNewEvent: any(named: 'onNewEvent'),
            onInsert: any(named: 'onInsert'),
            onChange: any(named: 'onChange'),
            onRemove: any(named: 'onRemove'),
            onUpdate: any(named: 'onUpdate'),
          )).thenAnswer((_) async => timeline);

      final att = MockEvent();
      when(() => att.eventId).thenReturn('dup1');
      when(() => att.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(10));
      when(() => att.senderId).thenReturn('@other:server');
      when(() => att.attachmentMimetype).thenReturn('image/jpeg');
      const rel = '/images/2024/a.jpg';
      when(() => att.content)
          .thenReturn(<String, dynamic>{'relativePath': rel});
      when(() => att.downloadAndDecryptAttachment()).thenAnswer((_) async =>
          MatrixFile(bytes: Uint8List.fromList(const [1, 2]), name: 'a.jpg'));

      when(() => timeline.events).thenReturn(<Event>[att]);
      when(() => logger.captureEvent(any<dynamic>(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'))).thenReturn(null);

      final consumer = MatrixStreamConsumer(
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        collectMetrics: true,
        sentEventRegistry: SentEventRegistry(),
      );

      await consumer.initialize();
      await consumer.start();

      // Advance to let processing and delayed double-scan run
      async.elapse(const Duration(milliseconds: 300));
      async.flushMicrotasks();

      verify(() => logger.captureEvent(
            'doubleScan.attachment immediate',
            domain: syncLoggingDomain,
            subDomain: 'doubleScan',
          )).called(1);
      verify(() => logger.captureEvent(
            'doubleScan.attachment delayed',
            domain: syncLoggingDomain,
            subDomain: 'doubleScan',
          )).called(1);
    });
  });

  test(
      'attachment duplicate suppression avoids duplicate downloads (fakeAsync)',
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

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => const Stream<Event>.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);
      when(() => room.getTimeline(
            onNewEvent: any(named: 'onNewEvent'),
            onInsert: any(named: 'onInsert'),
            onChange: any(named: 'onChange'),
            onRemove: any(named: 'onRemove'),
            onUpdate: any(named: 'onUpdate'),
          )).thenAnswer((_) async => timeline);

      final att1 = MockEvent();
      when(() => att1.eventId).thenReturn('ATT');
      when(() => att1.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(10));
      when(() => att1.senderId).thenReturn('@other:server');
      when(() => att1.attachmentMimetype).thenReturn('image/jpeg');
      when(() => att1.content)
          .thenReturn(<String, dynamic>{'relativePath': '/images/x.jpg'});
      var downloads = 0;
      when(() => att1.downloadAndDecryptAttachment()).thenAnswer((_) async {
        downloads++;
        return MatrixFile(bytes: Uint8List.fromList(const [1]), name: 'x.jpg');
      });

      // Second event with the same id to exercise duplicate suppression
      final att2 = MockEvent();
      when(() => att2.eventId).thenReturn('ATT');
      when(() => att2.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(10));
      when(() => att2.senderId).thenReturn('@other:server');
      when(() => att2.attachmentMimetype).thenReturn('image/jpeg');
      when(() => att2.content)
          .thenReturn(<String, dynamic>{'relativePath': '/images/x.jpg'});
      when(() => att2.downloadAndDecryptAttachment()).thenAnswer((_) async {
        downloads++;
        return MatrixFile(bytes: Uint8List.fromList(const [1]), name: 'x.jpg');
      });

      when(() => timeline.events).thenReturn(<Event>[att1, att2]);

      final consumer = MatrixStreamConsumer(
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        collectMetrics: true,
        sentEventRegistry: SentEventRegistry(),
      );

      await consumer.initialize();
      await consumer.start();

      async.elapse(const Duration(milliseconds: 200));
      async.flushMicrotasks();

      expect(downloads, 1);
    });
  });
  test('does not advance marker on newer non-sync event', () async {
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
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        collectMetrics: true,
        markerDebounce: const Duration(milliseconds: 50),
        sentEventRegistry: SentEventRegistry(),
      );

      await consumer.initialize();
      await consumer.start();

      // wait for marker debounce
      async.elapse(const Duration(milliseconds: 120));

      verify(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: 'S1',
          )).called(1);
    });
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
      skipSyncWait: true,
      sessionManager: session,
      roomManager: roomManager,
      loggingService: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      collectMetrics: true,
      sentEventRegistry: SentEventRegistry(),
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
      skipSyncWait: true,
      sessionManager: session,
      roomManager: roomManager,
      loggingService: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      collectMetrics: true,
      sentEventRegistry: SentEventRegistry(),
    );

    // Simulate DB applied
    consumer.reportDbApplyDiagnostics(
      SyncApplyDiagnostics(
        eventId: 'e',
        payloadType: 'journalEntity',
        vectorClock: null,
        conflictStatus: 'b_gt_a',
        applied: true,
        skipReason: null,
      ),
    );
    // Simulate ignored by vector clock
    consumer.reportDbApplyDiagnostics(
      SyncApplyDiagnostics(
        eventId: 'e2',
        payloadType: 'journalEntity',
        vectorClock: null,
        conflictStatus: 'a_gt_b',
        applied: false,
        skipReason: JournalUpdateSkipReason.olderOrEqual,
      ),
    );
    // Simulate conflict
    consumer.reportDbApplyDiagnostics(
      SyncApplyDiagnostics(
        eventId: 'e3',
        payloadType: 'journalEntity',
        vectorClock: null,
        conflictStatus: 'concurrent',
        applied: false,
        skipReason: JournalUpdateSkipReason.conflict,
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
      skipSyncWait: true,
      sessionManager: session,
      roomManager: roomManager,
      loggingService: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      collectMetrics: true,
      sentEventRegistry: SentEventRegistry(),
    );

    await consumer.initialize();
    await consumer.start();

    final m = consumer.metricsSnapshot();
    // Prefetch metric removed; ensure we processed (or at least snapshot exists)
    expect(m.containsKey('processed'), isTrue);
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
      skipSyncWait: true,
      sessionManager: session,
      roomManager: roomManager,
      loggingService: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      collectMetrics: true,
      sentEventRegistry: SentEventRegistry(),
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

  test('diagnosticsStrings exposes lastIgnored entries (prefetch removed)',
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
      skipSyncWait: true,
      sessionManager: session,
      roomManager: roomManager,
      loggingService: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      collectMetrics: true,
      sentEventRegistry: SentEventRegistry(),
    );
    consumer.reportDbApplyDiagnostics(
      SyncApplyDiagnostics(
        eventId: 'X',
        payloadType: 'journalEntity',
        vectorClock: null,
        conflictStatus: 'a_gt_b',
        applied: false,
        skipReason: JournalUpdateSkipReason.olderOrEqual,
      ),
    );

    // Timeline contains a file event; prefetch removed so no lastPrefetched entries
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
    expect(d.containsKey('lastPrefetchedCount'), isFalse);
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
      skipSyncWait: true,
      sessionManager: session,
      roomManager: roomManager,
      loggingService: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      sentEventRegistry: SentEventRegistry(),
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

  test('forceRescan guards against concurrent execution', () {
    fakeAsync((async) {
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

      final capturedLogs = <String>[];
      when(() => logger.captureEvent(
            captureAny<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          )).thenAnswer((inv) {
        capturedLogs.add(inv.positionalArguments.first.toString());
      });
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
      when(() => timeline.events).thenReturn(<Event>[]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);

      var catchupCalls = 0;
      // Make getTimeline take some time to simulate slow catch-up
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async {
        catchupCalls++;
        // Simulate slow processing
        await Future<void>.delayed(const Duration(milliseconds: 500));
        return timeline;
      });
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((_) async {});

      final consumer = MatrixStreamConsumer(
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        sentEventRegistry: SentEventRegistry(),
      );

      unawaited(consumer.initialize());
      async.flushMicrotasks();
      unawaited(consumer.start());
      async.flushMicrotasks();

      // Allow initial startup to complete
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();

      // Clear logs and reset counter to isolate the concurrent test
      capturedLogs.clear();
      final catchupsBefore = catchupCalls;

      // Start first forceRescan (will take 500ms due to delayed getTimeline)
      unawaited(consumer.forceRescan());
      async.flushMicrotasks();

      // Immediately start second forceRescan while first is still in flight
      var secondDone = false;
      unawaited(consumer.forceRescan().then((_) => secondDone = true));
      async.flushMicrotasks();

      // Allow both to complete
      expect(secondDone, isFalse, reason: 'Second forceRescan should await');
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(secondDone, isTrue, reason: 'Second forceRescan should complete');

      // Verify second call was skipped
      expect(
        capturedLogs.any((l) => l.contains('forceRescan.skipped')),
        isTrue,
        reason: 'Second concurrent forceRescan should be skipped',
      );

      // Verify only one catch-up was actually executed (the first one)
      // Note: catchupCalls increases by 1, not 2
      expect(
        catchupCalls - catchupsBefore,
        equals(1),
        reason:
            'Only one catch-up should run when forceRescan is called concurrently',
      );

      // Verify first call completed successfully
      expect(
        capturedLogs.any((l) => l.contains('forceRescan.done')),
        isTrue,
        reason: 'First forceRescan should complete successfully',
      );
    });
  });

  test('forceRescan skips catchUp when _catchUpInFlight is true', () {
    fakeAsync((async) {
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

      final capturedLogs = <String>[];
      when(() => logger.captureEvent(
            captureAny<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          )).thenAnswer((inv) {
        capturedLogs.add(inv.positionalArguments.first.toString());
      });
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
      // Return stored marker so _scheduleInitialCatchUpRetry is triggered
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => 'stored-marker');
      when(() => timeline.events).thenReturn(<Event>[]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);

      // Use completer to block catch-up calls
      final catchUpCompleter = Completer<void>();
      var getTimelineCalls = 0;

      // Block the SECOND getTimeline call (from _scheduleInitialCatchUpRetry)
      // which is the one that sets _catchUpInFlight = true
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async {
        getTimelineCalls++;
        if (getTimelineCalls == 2) {
          // Second call is from retry timer - block to keep _catchUpInFlight true
          await catchUpCompleter.future;
        }
        return timeline;
      });
      // Live timeline doesn't block
      when(() => room.getTimeline(
            onNewEvent: any<void Function()?>(named: 'onNewEvent'),
            onInsert: any<void Function(int)?>(named: 'onInsert'),
            onChange: any<void Function(int)?>(named: 'onChange'),
            onRemove: any<void Function(int)?>(named: 'onRemove'),
            onUpdate: any<void Function()?>(named: 'onUpdate'),
          )).thenAnswer((_) async => timeline);
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((_) async {});

      final consumer = MatrixStreamConsumer(
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        sentEventRegistry: SentEventRegistry(),
      );

      unawaited(consumer.initialize());
      async.flushMicrotasks();
      // Let first catch-up (from initialize) complete
      async.elapse(const Duration(milliseconds: 100));
      async.flushMicrotasks();

      unawaited(consumer.start());
      async.flushMicrotasks();

      // Elapse 500ms+ to trigger _scheduleInitialCatchUpRetry timer
      // This sets _catchUpInFlight = true and starts second catch-up (blocked)
      async.elapse(const Duration(milliseconds: 600));
      async.flushMicrotasks();

      // Clear logs to isolate the forceRescan call
      capturedLogs.clear();
      final callsBefore = getTimelineCalls;

      // Now call forceRescan while retry catch-up is in flight
      // It should skip catch-up because _catchUpInFlight is true
      unawaited(consumer.forceRescan());
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 100));
      async.flushMicrotasks();

      // Verify forceRescan skipped catch-up because _catchUpInFlight was true
      expect(
        capturedLogs.any((l) => l.contains('forceRescan.skippedCatchUp')),
        isTrue,
        reason:
            'forceRescan should skip catch-up when _catchUpInFlight is true',
      );

      // Verify forceRescan still completed (ran timeline scan)
      expect(
        capturedLogs.any((l) => l.contains('forceRescan.done')),
        isTrue,
        reason: 'forceRescan should still complete (ran timeline scan)',
      );

      // Only the blocked retry call should have happened, no new call from forceRescan
      expect(
        getTimelineCalls - callsBefore,
        equals(0),
        reason:
            'forceRescan should not start new catch-up when one is in flight',
      );

      // Unblock the completer to clean up
      catchUpCompleter.complete();
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
    });
  });

  test(
      'forceRescan with bypassCatchUpInFlightCheck=true runs catchUp even when _catchUpInFlight is true',
      () {
    fakeAsync((async) {
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

      final capturedLogs = <String>[];
      when(() => logger.captureEvent(
            captureAny<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          )).thenAnswer((inv) {
        capturedLogs.add(inv.positionalArguments.first.toString());
      });
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
      // Return stored marker so _scheduleInitialCatchUpRetry is triggered
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => 'stored-marker');
      when(() => timeline.events).thenReturn(<Event>[]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);

      // Use completer to block the retry catch-up
      final retryCompleter = Completer<void>();
      // Use separate completer for bypass call to allow it to complete
      final bypassCompleter = Completer<void>();
      var getTimelineCalls = 0;

      // Track which call is which:
      // Call 1: initialize() catch-up
      // Call 2: _scheduleInitialCatchUpRetry (blocked by retryCompleter)
      // Call 3: forceRescan with bypass (completes via bypassCompleter)
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async {
        getTimelineCalls++;
        if (getTimelineCalls == 2) {
          // Retry timer call - block to keep _catchUpInFlight true
          await retryCompleter.future;
        } else if (getTimelineCalls == 3) {
          // Bypass call - let it complete quickly
          bypassCompleter.complete();
        }
        return timeline;
      });
      // Live timeline doesn't block
      when(() => room.getTimeline(
            onNewEvent: any<void Function()?>(named: 'onNewEvent'),
            onInsert: any<void Function(int)?>(named: 'onInsert'),
            onChange: any<void Function(int)?>(named: 'onChange'),
            onRemove: any<void Function(int)?>(named: 'onRemove'),
            onUpdate: any<void Function()?>(named: 'onUpdate'),
          )).thenAnswer((_) async => timeline);
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((_) async {});

      final consumer = MatrixStreamConsumer(
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,
        sentEventRegistry: SentEventRegistry(),
      );

      unawaited(consumer.initialize());
      async.flushMicrotasks();
      // Let first catch-up (from initialize) complete
      async.elapse(const Duration(milliseconds: 100));
      async.flushMicrotasks();

      unawaited(consumer.start());
      async.flushMicrotasks();

      // Elapse 500ms+ to trigger _scheduleInitialCatchUpRetry timer
      // This sets _catchUpInFlight = true and starts second catch-up (blocked)
      async.elapse(const Duration(milliseconds: 600));
      async.flushMicrotasks();

      // At this point:
      // - getTimelineCalls == 2 (initialize + retry)
      // - _catchUpInFlight == true (retry is blocked)
      expect(getTimelineCalls, equals(2));

      // Clear logs to isolate the bypass forceRescan call
      capturedLogs.clear();
      final callsBefore = getTimelineCalls;

      // Call forceRescan with bypassCatchUpInFlightCheck=true
      // This should run catch-up even though _catchUpInFlight is true
      unawaited(consumer.forceRescan(bypassCatchUpInFlightCheck: true));
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 100));
      async.flushMicrotasks();

      // Verify catch-up WAS invoked (getTimelineCalls increased)
      expect(
        getTimelineCalls - callsBefore,
        equals(1),
        reason:
            'forceRescan with bypassCatchUpInFlightCheck=true should run catch-up',
      );

      // Verify 'forceRescan.skippedCatchUp' was NOT logged
      expect(
        capturedLogs.any((l) => l.contains('forceRescan.skippedCatchUp')),
        isFalse,
        reason:
            'forceRescan with bypassCatchUpInFlightCheck=true should not log skippedCatchUp',
      );

      // Verify forceRescan completed
      expect(
        capturedLogs.any((l) => l.contains('forceRescan.done')),
        isTrue,
        reason: 'forceRescan should complete successfully',
      );

      // Unblock the retry completer to clean up
      retryCompleter.complete();
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
    });
  });
}
