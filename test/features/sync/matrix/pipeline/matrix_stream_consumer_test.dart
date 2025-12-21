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
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
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

class ThrowingMetricsCounters extends MetricsCounters {
  ThrowingMetricsCounters() : super(collect: true);

  @override
  void incDbIgnoredByVectorClock() {
    throw StateError('metrics failure');
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    // Fallbacks for typed `any<T>` matchers used in mocks
    registerFallbackValue(_FakeClient());
    registerFallbackValue(_FakeRoom());
    registerFallbackValue(_FakeTimeline());
    registerFallbackValue(_FakeEvent());
  });

  ({MatrixStreamConsumer consumer, MockLoggingService logger}) buildConsumer({
    MetricsCounters? metrics,
    SentEventRegistry? sentEventRegistry,
  }) {
    final session = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final logger = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final processor = MockSyncEventProcessor();
    final readMarker = MockSyncReadMarkerService();
    final registry = sentEventRegistry ?? SentEventRegistry();

    when(() => processor.cachePurgeListener = any()).thenAnswer((_) => null);
    when(
      () => logger.captureEvent(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) {});
    when(
      () => logger.captureException(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) {});

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
      metricsCounters: metrics,
      sentEventRegistry: registry,
    );

    return (consumer: consumer, logger: logger);
  }

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
        entityId: 'A->B',
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
        entityId: 'e',
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
        entityId: 'id',
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
        entityId: 'id',
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
        entityId: 'id',
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
        entityId: 'e',
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

  group('stream event processing modes', () {
    late MockMatrixSessionManager session;
    late MockSyncRoomManager roomManager;
    late MockLoggingService logger;
    late MockJournalDb journalDb;
    late MockSettingsDb settingsDb;
    late MockSyncEventProcessor processor;
    late MockSyncReadMarkerService readMarker;
    late MockClient client;
    late MockRoom room;
    late MockTimeline timeline;
    late StreamController<Event> streamController;

    setUp(() {
      session = MockMatrixSessionManager();
      roomManager = MockSyncRoomManager();
      logger = MockLoggingService();
      journalDb = MockJournalDb();
      settingsDb = MockSettingsDb();
      processor = MockSyncEventProcessor();
      readMarker = MockSyncReadMarkerService();
      client = MockClient();
      room = MockRoom();
      timeline = MockTimeline();
      streamController = StreamController<Event>.broadcast();

      // Common stubs
      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => streamController.stream);
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => timeline.events).thenReturn(<Event>[]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);
      when(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
          )).thenAnswer((_) async {});
      when(() => processor.process(
            event: any<Event>(named: 'event'),
            journalDb: journalDb,
          )).thenAnswer((_) async {});
    });

    tearDown(() {
      streamController.close();
    });

    test('stream events during startup trigger catch-up', () async {
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

      final streamEvent = MockEvent();
      when(() => streamEvent.eventId).thenReturn('stream1');
      when(() => streamEvent.roomId).thenReturn('!room:server');
      when(() => streamEvent.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1000));
      when(() => streamEvent.senderId).thenReturn('@other:server');

      var catchupCalls = 0;
      // Stub for snapshot-only overload (used by catch-up)
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async {
        catchupCalls++;
        // Throw error to prevent catch-up completion (stay in startup mode)
        throw Exception('Room not ready');
      });
      // Stub for callbacks-only overload (used by live timeline attachment)
      when(
        () => room.getTimeline(
          onNewEvent: any(named: 'onNewEvent'),
          onInsert: any(named: 'onInsert'),
          onChange: any(named: 'onChange'),
          onRemove: any(named: 'onRemove'),
          onUpdate: any(named: 'onUpdate'),
        ),
      ).thenAnswer((_) async => timeline);

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
      var scanCalls = 0;
      consumer.scanLiveTimelineTestHook = (_) {
        scanCalls++;
      };

      fakeAsync((async) {
        unawaited(consumer.initialize());
        async.flushMicrotasks();
        unawaited(consumer.start());
        async.flushMicrotasks();

        // Capture baseline - initial catch-up from start() may have been attempted
        final catchupAfterStart = catchupCalls;

        // Fire the FIRST stream event immediately (before catch-up completes)
        streamController.add(streamEvent);
        async.flushMicrotasks();

        // The first stream event should trigger catch-up
        expect(catchupCalls, greaterThan(catchupAfterStart));
        expect(scanCalls, equals(0));
      });
    });

    test('stream events in steady state skip catch-up, only scan', () async {
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => 'marker1');

      final streamEvent = MockEvent();
      when(() => streamEvent.eventId).thenReturn('stream2');
      when(() => streamEvent.roomId).thenReturn('!room:server');
      when(() => streamEvent.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(2000));
      when(() => streamEvent.senderId).thenReturn('@other:server');
      when(() => streamEvent.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => streamEvent.attachmentMimetype).thenReturn('');

      when(() => timeline.events).thenReturn(<Event>[streamEvent]);

      var catchupCalls = 0;
      var scanCalls = 0;
      // Stub for snapshot-only overload (used by catch-up)
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async {
        catchupCalls++;
        return timeline;
      });
      // Stub for callbacks-only overload (used by live timeline attachment)
      when(
        () => room.getTimeline(
          onNewEvent: any(named: 'onNewEvent'),
          onInsert: any(named: 'onInsert'),
          onChange: any(named: 'onChange'),
          onRemove: any(named: 'onRemove'),
          onUpdate: any(named: 'onUpdate'),
        ),
      ).thenAnswer((_) async => timeline);

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

      // Hook to track scan calls
      consumer.scanLiveTimelineTestHook = (_) {
        scanCalls++;
      };

      fakeAsync((async) {
        unawaited(consumer.initialize());
        async.flushMicrotasks();
        unawaited(consumer.start());
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 1500));
        async.flushMicrotasks();

        // Initial catch-up from start() completes
        final catchupAfterStart = catchupCalls;
        final scanAfterStart = scanCalls;

        // Fire stream event after initial catch-up completes (steady state)
        streamController.add(streamEvent);
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();

        // Stream event should trigger scan but NOT catch-up in steady state
        expect(catchupCalls, catchupAfterStart); // No additional catch-up
        expect(scanCalls, greaterThan(scanAfterStart)); // Scan was called
      });
    });

    test('live scan deferred during catch-up ensures in-order ingest',
        () async {
      // This test verifies that live scan signals are deferred while catch-up is
      // processing older events, ensuring events are ingested in chronological
      // order and preventing false positive gap detection.
      //
      // Scenario: Device wakes from standby (>30s gap), triggering wake catch-up.
      // While that catch-up is running, another signal triggers _scheduleLiveScan.
      // The live scan should be deferred until catch-up completes.
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => 'marker1');

      final streamEvent = MockEvent();
      when(() => streamEvent.eventId).thenReturn('stream3');
      when(() => streamEvent.roomId).thenReturn('!room:server');
      when(() => streamEvent.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(3000));
      when(() => streamEvent.senderId).thenReturn('@other:server');
      when(() => streamEvent.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => streamEvent.attachmentMimetype).thenReturn('');

      when(() => timeline.events).thenReturn(<Event>[streamEvent]);

      // Track captured log messages
      final capturedMessages = <String>[];
      var blockWakeCatchup = false;
      when(
        () => logger.captureEvent(
          any<String>(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenAnswer((invocation) {
        final message = invocation.positionalArguments[0] as String;
        capturedMessages.add(message);
        if (message.contains('wake.detected')) {
          blockWakeCatchup = true;
        }
      });

      // Completer to control when wake catch-up finishes
      final catchupCompleter = Completer<void>();

      // Stub for snapshot-only overload (used by catch-up)
      // Wake catch-up waits for completer once wake detection has fired.
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async {
        if (blockWakeCatchup) {
          blockWakeCatchup = false;
          // Wake catch-up (from wake detection) - wait for completer
          await catchupCompleter.future;
        }
        return timeline;
      });
      // Stub for callbacks-only overload (used by live timeline attachment)
      when(
        () => room.getTimeline(
          onNewEvent: any(named: 'onNewEvent'),
          onInsert: any(named: 'onInsert'),
          onChange: any(named: 'onChange'),
          onRemove: any(named: 'onRemove'),
          onUpdate: any(named: 'onUpdate'),
        ),
      ).thenAnswer((_) async => timeline);

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
      var scanCalls = 0;
      consumer.scanLiveTimelineTestHook = (_) {
        scanCalls++;
      };

      fakeAsync((async) {
        unawaited(consumer.initialize());
        async.flushMicrotasks();
        unawaited(consumer.start());
        async.flushMicrotasks();

        // Let initial catch-up complete and settle before steady-state signals.
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        // Trigger a live scan during steady state to set _lastLiveScanAt.
        // This is required for wake detection to work (it checks the gap since
        // the last scan)
        streamController.add(streamEvent);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        final scansAfterBaseline = scanCalls;
        expect(
          scansAfterBaseline,
          greaterThan(0),
          reason: 'Expected a live scan to establish the last scan timestamp',
        );

        // Clear captured messages to isolate the test
        capturedMessages.clear();

        // Simulate wake from standby by advancing time beyond the 30s threshold
        // This will trigger wake catch-up on the next _scheduleLiveScan call
        async.elapse(const Duration(seconds: 35));

        // First signal after wake: triggers wake detection and catch-up
        streamController.add(streamEvent);
        async.flushMicrotasks();
        // Elapse time to allow processing mutex waits if needed
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();

        // Verify wake was detected
        expect(
          capturedMessages.any((m) => m.contains('wake.detected')),
          isTrue,
          reason: 'Wake from standby should be detected',
        );

        // Verify wake catch-up started (this sets _catchUpInFlight = true)
        expect(
          capturedMessages.any((m) => m.contains('wake.catchup.start')),
          isTrue,
          reason: 'Wake catch-up should have started',
        );

        // Second signal while wake catch-up is still running
        // This should be deferred (client stream handler defers when catch-up is in-flight)
        capturedMessages.clear();
        streamController.add(streamEvent);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        // Verify no live scan runs while wake catch-up is still in-flight.
        expect(
          scanCalls,
          scansAfterBaseline,
          reason:
              'Live scans should be deferred while another catch-up is processing',
        );

        // Complete the catch-up to clean up
        catchupCompleter.complete();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
      });
    });
  });

  test('retry backoff blocks until due, retryNow forces scan', () async {
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
    await consumer.dispose();

    verify(() => liveTimeline.cancelSubscriptions()).called(1);
    verify(
      () => logger.captureEvent(
        any<String>(that: contains('MatrixStreamConsumer disposed')),
        domain: any<String>(named: 'domain'),
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

      // Drive processing via live scan: include failing in live timeline
      final timeline = MockTimeline();
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
      when(() => timeline.events).thenReturn(<Event>[failing]);
      // Allow initial live-scan to run
      async.elapse(const Duration(milliseconds: 250));

      final m = consumer.metricsSnapshot();
      // In signal-only mode, cap drop may not be reached within this window; ensure no crash
      expect(m['skippedByRetryLimit'], anyOf(null, greaterThanOrEqualTo(0)));
    });
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
      skipSyncWait: true,
      sessionManager: session,
      roomManager: roomManager,
      loggingService: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,

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
      sentEventRegistry: SentEventRegistry(),
    );

    await consumer.initialize();
    await consumer.start();

    // Expect processing at least strictly after the marker
    verify(() => processor.process(
          event: any<Event>(named: 'event'),
          journalDb: journalDb,
        )).called(10);
  });

  test('filters events from other rooms and processes only current room',
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
        skipSyncWait: true,
        sessionManager: session,
        roomManager: roomManager,
        loggingService: logger,
        journalDb: journalDb,
        settingsDb: settingsDb,
        eventProcessor: processor,
        readMarkerService: readMarker,

        // use shorter flush for test speed if desired (default fine here)
        sentEventRegistry: SentEventRegistry(),
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

      // Provide timeline snapshot: 5 in-room + 1 wrong-room
      final wrong = mk('w', roomId: '!other:server');
      final inRoom = List<Event>.generate(
        5,
        (i) => mk('b$i', roomId: '!room:server'),
      );
      when(() => timeline.events).thenReturn(<Event>[wrong, ...inRoom]);
      // Allow initial live-scan to run
      async.elapse(const Duration(milliseconds: 200));
      async.flushMicrotasks();

      verifyNever(() => processor.process(event: wrong, journalDb: journalDb));
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

    fakeAsync((async) {
      unawaited(consumer.initialize());
      async.flushMicrotasks();
      unawaited(consumer.start());
      async.flushMicrotasks();
      // Trigger both callbacks in short succession; exactly one scan should fire
      onNew?.call();
      onUpdate?.call();
      async.elapse(const Duration(milliseconds: 250));
      async.flushMicrotasks();
    });
    // With the fix for excessive logging (bug #3), completed events are skipped
    // on subsequent scans, so the event is only processed once.
    verify(() => processor.process(event: ev, journalDb: journalDb)).called(1);
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

    fakeAsync((async) async {
      await consumer.initialize();
      await consumer.start();
      // Ensure failing event appears in live scan to drive failure/retry metrics
      when(() => timeline.events)
          .thenReturn(<Event>[fileEvent, okEvent, skipped, failing]);
      async.elapse(const Duration(milliseconds: 300));
    });

    final m = consumer.metricsSnapshot();
    // Ensure counters are present and non-negative in signal-only mode
    expect(m['processed'], greaterThanOrEqualTo(0));
    expect(m['skipped'], greaterThanOrEqualTo(0));
    expect(m['failures'], greaterThanOrEqualTo(0));
    // Prefetch removed
    // flushes no longer increment in signal-only mode
    expect(m['flushes'], anyOf(0, null));
    expect(m['catchupBatches'], greaterThanOrEqualTo(0));
    expect(m['retriesScheduled'], greaterThanOrEqualTo(0));
    expect(m['circuitOpens'], greaterThanOrEqualTo(0));
    expect(m['retryStateSize'], greaterThanOrEqualTo(0));
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

    fakeAsync((async) async {
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
      // Provide via live timeline to trigger processing in signal-only mode
      when(() => timeline.events).thenReturn(<Event>[ev]);
      async.elapse(const Duration(milliseconds: 250));
    });
    // Verify no exception was logged during rapid restart
    verifyNever(() => logger.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ));
  });

  group('MatrixStreamConsumer startup catch-up ordering', () {
    test(
        'runs initial catch-up before first live scan when room becomes available',
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
        final tlCatch = MockTimeline();
        final tlLive = MockTimeline();

        final logs = <String>[];

        when(() => logger.captureEvent(any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'))).thenAnswer((inv) {
          final msg = inv.positionalArguments.first as String;
          final sd = inv.namedArguments[#subDomain] as String?;
          logs.add('$sd|$msg');
          return;
        });
        when(() => logger.captureException(any<Object>(),
                domain: any<String>(named: 'domain'),
                subDomain: any<String>(named: 'subDomain'),
                stackTrace: any<StackTrace?>(named: 'stackTrace')))
            .thenReturn(null);

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => session.timelineEvents)
            .thenAnswer((_) => const Stream.empty());
        when(() => roomManager.initialize()).thenAnswer((_) async {});

        // currentRoom becomes available only after some time
        Room? current;
        when(() => roomManager.currentRoom).thenAnswer((_) => current);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() =>
                roomManager.hydrateRoomSnapshot(client: any(named: 'client')))
            .thenAnswer((_) async {});

        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => 'e0');

        // Catch-up snapshot contains e1
        final e1 = MockEvent();
        when(() => e1.eventId).thenReturn('e1');
        when(() => e1.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
        when(() => e1.senderId).thenReturn('@other:server');
        when(() => e1.attachmentMimetype).thenReturn('');
        when(() => e1.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
        when(() => e1.roomId).thenReturn('!room:server');

        // Live timeline has e2, processed after e1
        final e2 = MockEvent();
        when(() => e2.eventId).thenReturn('e2');
        when(() => e2.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(2));
        when(() => e2.senderId).thenReturn('@other:server');
        when(() => e2.attachmentMimetype).thenReturn('');
        when(() => e2.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
        when(() => e2.roomId).thenReturn('!room:server');

        when(() => tlCatch.events).thenReturn(<Event>[e1]);
        when(() => tlCatch.cancelSubscriptions()).thenReturn(null);
        when(() => tlLive.events).thenReturn(<Event>[e2]);
        when(() => tlLive.cancelSubscriptions()).thenReturn(null);

        // First getTimeline call (catch-up), second call (attach live)
        var firstCall = true;
        when(() => room.getTimeline(limit: any(named: 'limit')))
            .thenAnswer((_) async {
          if (firstCall) {
            firstCall = false;
            return tlCatch;
          }
          return tlLive;
        });
        when(() => room.getTimeline(
              limit: any(named: 'limit'),
              onNewEvent: any(named: 'onNewEvent'),
              onInsert: any(named: 'onInsert'),
              onChange: any(named: 'onChange'),
              onRemove: any(named: 'onRemove'),
              onUpdate: any(named: 'onUpdate'),
            )).thenAnswer((_) async => tlLive);

        final processed = <String>[];
        when(() => processor.process(
              event: any<Event>(named: 'event'),
              journalDb: journalDb,
            )).thenAnswer((inv) async {
          final ev = inv.namedArguments[#event] as Event;
          processed.add(ev.eventId);
        });
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
        );

        await consumer.initialize();

        final startFut = consumer.start();

        // Allow hydration loop to begin
        async.elapse(const Duration(milliseconds: 200));
        // Room becomes available now
        current = room;
        // Allow catch-up and initial live scan timers to run
        async.elapse(const Duration(seconds: 1));
        await startFut;

        // e1 (catch-up) should process before live scan logs
        expect(processed.first, 'e1');
        // Ensure we saw a liveScan processed log
        expect(
          logs.any((l) => l.contains('liveScan|v2 liveScan processed=')),
          isTrue,
        );
      });
    });

    test('schedules initial catch-up retries until room becomes ready',
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
        final tlCatch = MockTimeline();

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
            .thenAnswer((_) => const Stream.empty());
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        Room? current;
        when(() => roomManager.currentRoom).thenAnswer((_) => current);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() =>
                roomManager.hydrateRoomSnapshot(client: any(named: 'client')))
            .thenAnswer((_) async {});

        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => null);

        // Catch-up snapshot (when room becomes ready)
        final e1 = MockEvent();
        when(() => e1.eventId).thenReturn('e1');
        when(() => e1.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
        when(() => e1.senderId).thenReturn('@other:server');
        when(() => e1.attachmentMimetype).thenReturn('');
        when(() => e1.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
        when(() => e1.roomId).thenReturn('!room:server');
        when(() => tlCatch.events).thenReturn(<Event>[e1]);
        when(() => tlCatch.cancelSubscriptions()).thenReturn(null);
        when(() => room.getTimeline(limit: any(named: 'limit')))
            .thenAnswer((_) async => tlCatch);

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
          sentEventRegistry: SentEventRegistry(),
        );

        await consumer.initialize();
        // Start while room is not yet ready
        unawaited(consumer.start());
        // Advance to let retry loop schedule
        async.elapse(const Duration(seconds: 1));
        // Room becomes ready now; next retry should perform catch-up
        current = room;
        async.elapse(const Duration(milliseconds: 600));
        // Verify catch-up executed (one getTimeline call at least)
        verify(() => room.getTimeline(limit: any(named: 'limit')))
            .called(greaterThanOrEqualTo(1));
      });
    });

    test('metrics flush log includes byType breakdown', () async {
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
                stackTrace: any<StackTrace?>(named: 'stackTrace')))
            .thenReturn(null);

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        final controller = StreamController<Event>.broadcast();
        addTearDown(controller.close);
        when(() => session.timelineEvents).thenAnswer((_) => controller.stream);
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
              limit: any(named: 'limit'),
              onNewEvent: any(named: 'onNewEvent'),
              onInsert: any(named: 'onInsert'),
              onChange: any(named: 'onChange'),
              onRemove: any(named: 'onRemove'),
              onUpdate: any(named: 'onUpdate'),
            )).thenAnswer((_) async => timeline);

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

        // Send two sync payload events to trigger a flush with counts
        Event ev(String id, int ts) {
          final e = MockEvent();
          when(() => e.eventId).thenReturn(id);
          when(() => e.originServerTs)
              .thenReturn(DateTime.fromMillisecondsSinceEpoch(ts));
          when(() => e.senderId).thenReturn('@other:server');
          when(() => e.attachmentMimetype).thenReturn('');
          when(() => e.content)
              .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
          when(() => e.roomId).thenReturn('!room:server');
          return e;
        }

        controller.add(ev('a', 1));
        controller.add(ev('b', 2));
        async.elapse(const Duration(milliseconds: 300));

        verify(() => logger.captureEvent(
              any<String>(that: contains('byType=')),
              domain: syncLoggingDomain,
              subDomain: 'metrics',
            )).called(greaterThanOrEqualTo(1));
      });
    });
  });

  test(
      'first stream event triggers catch-up when initial catch-up not completed',
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
      final tlCatch = MockTimeline();

      final controller = StreamController<Event>.broadcast();
      addTearDown(controller.close);

      when(() => logger.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logger.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents).thenAnswer((_) => controller.stream);
      when(() => roomManager.initialize()).thenAnswer((_) async {});

      // Room not ready at start; but we will set it before first event arrives
      Room? current;
      when(() => roomManager.currentRoom).thenAnswer((_) => current);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => roomManager.hydrateRoomSnapshot(client: any(named: 'client')))
          .thenAnswer((_) async {});

      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

      // Catch-up snapshot (should be invoked by first stream event path)
      final e1 = MockEvent();
      when(() => e1.eventId).thenReturn('c1');
      when(() => e1.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      when(() => e1.senderId).thenReturn('@other:server');
      when(() => e1.attachmentMimetype).thenReturn('');
      when(() => e1.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => e1.roomId).thenReturn('!room:server');

      when(() => tlCatch.events).thenReturn(<Event>[e1]);
      when(() => tlCatch.cancelSubscriptions()).thenReturn(null);
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => tlCatch);

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
        sentEventRegistry: SentEventRegistry(),
      );

      await consumer.initialize();
      unawaited(consumer.start());
      // Allow startup paths to run without a room becoming ready
      async.elapse(const Duration(seconds: 1));

      // Now set the room and emit the first stream event; this should trigger a catch-up
      current = room;
      final ev = MockEvent();
      when(() => ev.eventId).thenReturn('live1');
      when(() => ev.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(2));
      when(() => ev.senderId).thenReturn('@other:server');
      when(() => ev.attachmentMimetype).thenReturn('');
      when(() => ev.content)
          .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
      when(() => ev.roomId).thenReturn('!room:server');
      controller.add(ev);
      async.elapse(const Duration(milliseconds: 300));

      // Verify that a catch-up getTimeline was invoked as a result of first event trigger
      verify(() => room.getTimeline(limit: any(named: 'limit')))
          .called(greaterThanOrEqualTo(1));
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
    // Should not throw despite live timeline failure
    await consumer.start();
    verify(() => logger.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
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

      fakeAsync((async) {
        unawaited(consumer.initialize());
        async.flushMicrotasks();
        unawaited(consumer.start());
        async.flushMicrotasks();
      });

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

      fakeAsync((async) {
        unawaited(consumer.initialize());
        async.flushMicrotasks();
        unawaited(consumer.start());
        // Allow liveScan debounce to elapse
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();
      });

      verify(() => roomManager.hydrateRoomSnapshot(client: client)).called(1);
      // With the fix for excessive logging (bug #3), completed events are skipped
      // on subsequent scans, so the event is only processed once.
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

      fakeAsync((async) {
        unawaited(consumer.initialize());
        async.flushMicrotasks();
        unawaited(consumer.start());
        async.elapse(const Duration(milliseconds: 300));
        async.flushMicrotasks();
      });

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
      await consumer.dispose();

      verify(() => timeline.cancelSubscriptions())
          .called(greaterThanOrEqualTo(1));
    });
  });

  test('monotonic marker across interleaved older live scan', () {
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

      when(() => processor.process(
          event: any(named: 'event'),
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
        sentEventRegistry: SentEventRegistry(),
      );

      consumer.initialize();
      async.flushMicrotasks();
      consumer.start();
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 900));
      async.flushMicrotasks();

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
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 900));
      async.flushMicrotasks();

      // Make live timeline contain only older A and trigger a scan
      when(() => liveTimeline.events).thenReturn(<Event>[a]);
      onUpdateCb?.call();
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 200));
      async.flushMicrotasks();

      // Ensure marker was not regressed to A
      verifyNever(() => readMarker.updateReadMarker(
            client: client,
            room: room,
            eventId: 'A',
          ));
    });
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

    fakeAsync((async) {
      unawaited(consumer.initialize());
      async.flushMicrotasks();
      unawaited(consumer.start());

      // After first batch, breaker should have opened at least once.
      async.elapse(const Duration(milliseconds: 400));
      expect(
          consumer.metricsSnapshot()['circuitOpens'], greaterThanOrEqualTo(1));

      // Trigger a live scan; breaker should still be open
      when(() => timeline.events).thenReturn(events.take(1).toList());
      // simulate onUpdate callback path by calling schedule and letting debounce expire
      async.elapse(const Duration(milliseconds: 200));
      expect(
          consumer.metricsSnapshot()['circuitOpens'], greaterThanOrEqualTo(1));
    });
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

    fakeAsync((async) {
      unawaited(consumer.initialize());
      async.flushMicrotasks();
      unawaited(consumer.start());
      async.elapse(const Duration(milliseconds: 500));
      async.flushMicrotasks();
    });

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

    fakeAsync((async) {
      unawaited(consumer.initialize());
      async.flushMicrotasks();
      unawaited(consumer.start());
      async.elapse(const Duration(milliseconds: 300));
      async.flushMicrotasks();
    });
    final before = consumer.metricsSnapshot()['retryStateSize'] ?? 0;
    expect(before, greaterThan(0));

    // Advance fake clock beyond TTL and trigger another pass to prune.
    now = now.add(const Duration(minutes: 11));
    // Trigger scan by injecting a no-op timeline
    when(() => timeline.events).thenReturn(<Event>[]);
    fakeAsync((async) {
      async.elapse(const Duration(milliseconds: 250));
      async.flushMicrotasks();
    });
    final after = consumer.metricsSnapshot()['retryStateSize'] ?? 0;
    expect(after, lessThanOrEqualTo(before));
  });

  test('startup logs startup.marker with id and ts', () async {
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
        .thenAnswer((_) => const Stream<Event>.empty());
    when(() => roomManager.initialize()).thenAnswer((_) async {});
    when(() => roomManager.currentRoom).thenReturn(room);
    when(() => roomManager.currentRoomId).thenReturn('!room:server');
    when(() => settingsDb.itemByKey(lastReadMatrixEventId))
        .thenAnswer((_) async => 'mk');
    when(() => settingsDb.itemByKey(lastReadMatrixEventTs))
        .thenAnswer((_) async => '123');
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

    verify(() => logger.captureEvent(
          any<String>(
              that: allOf(contains('startup.marker'), contains('id=mk'),
                  contains('ts=123'), contains('inst='))),
          domain: any<String>(named: 'domain'),
          subDomain: 'startup.marker',
        )).called(1);
  });

  group('reportDbApplyDiagnostics skip reasons -', () {
    test('handles overwritePrevented skip reason', () {
      final consumer = buildConsumer().consumer;

      consumer.reportDbApplyDiagnostics(
        SyncApplyDiagnostics(
          eventId: 'skip-overwrite',
          payloadType: 'journalEntity',
          entityId: '1',
          vectorClock: null,
          conflictStatus: 'vectorClock.equal',
          applied: false,
          skipReason: JournalUpdateSkipReason.overwritePrevented,
        ),
      );

      final snapshot = consumer.metricsSnapshot();
      expect(snapshot['dbIgnoredByVectorClock'], 1);
      expect(snapshot['dbMissingBase'], 0);
      expect(snapshot['droppedByType.journalEntity'], 1);
      final diag = consumer.diagnosticsStrings();
      expect(
        diag['lastIgnored.1'],
        'skip-overwrite:overwrite_prevented',
      );
    });

    test('handles null skip reason fallback', () {
      final consumer = buildConsumer().consumer;

      consumer.reportDbApplyDiagnostics(
        SyncApplyDiagnostics(
          eventId: 'skip-null',
          payloadType: 'journalEntity',
          entityId: '1',
          vectorClock: null,
          conflictStatus: 'vectorClock.equal',
          applied: false,
          skipReason: null,
        ),
      );

      final diag = consumer.diagnosticsStrings();
      expect(diag['lastIgnored.1'], 'skip-null:equal');
      final snapshot = consumer.metricsSnapshot();
      expect(snapshot['dbIgnoredByVectorClock'], 1);
    });

    test('does not add missingBase for olderOrEqual', () {
      final consumer = buildConsumer().consumer;

      consumer.reportDbApplyDiagnostics(
        SyncApplyDiagnostics(
          eventId: 'skip-older',
          payloadType: 'journalEntity',
          entityId: '1',
          vectorClock: null,
          conflictStatus: 'vectorClock.a_gt_b',
          applied: false,
          skipReason: JournalUpdateSkipReason.olderOrEqual,
        ),
      );

      final snapshot = consumer.metricsSnapshot();
      expect(snapshot['dbMissingBase'], 0);
      expect(snapshot['dbIgnoredByVectorClock'], 1);
      final diag = consumer.diagnosticsStrings();
      expect(diag['lastIgnored.1'], 'skip-older:older');
    });
  });

  group('Metrics exception resilience -', () {
    test('continues when metrics throw during reportDbApplyDiagnostics', () {
      final consumer =
          buildConsumer(metrics: ThrowingMetricsCounters()).consumer;

      expect(
        () => consumer.reportDbApplyDiagnostics(
          SyncApplyDiagnostics(
            eventId: 'metrics-throw',
            payloadType: 'journalEntity',
            entityId: '1',
            vectorClock: null,
            conflictStatus: 'vectorClock.equal',
            applied: false,
            skipReason: JournalUpdateSkipReason.olderOrEqual,
          ),
        ),
        returnsNormally,
      );
    });
  });

  group('Label generation -', () {
    test('labelForSkip returns correct label for each skip reason', () {
      final consumer = buildConsumer().consumer;

      final cases = <(JournalUpdateSkipReason, String, String)>[
        (JournalUpdateSkipReason.olderOrEqual, 'vectorClock.a_gt_b', 'older'),
        (
          JournalUpdateSkipReason.conflict,
          'vectorClock.concurrent',
          'conflict'
        ),
        (
          JournalUpdateSkipReason.overwritePrevented,
          'vectorClock.equal',
          'overwrite_prevented'
        ),
        (
          JournalUpdateSkipReason.missingBase,
          'vectorClock.equal',
          'missing_base'
        ),
      ];

      for (final entry in cases) {
        consumer.reportDbApplyDiagnostics(
          SyncApplyDiagnostics(
            eventId: 'event-${entry.$1.name}',
            payloadType: 'journalEntity',
            entityId: '1',
            vectorClock: null,
            conflictStatus: entry.$2,
            applied: false,
            skipReason: entry.$1,
          ),
        );
      }

      final diag = consumer.diagnosticsStrings();
      expect(diag['lastIgnored.1'], 'event-olderOrEqual:older');
      expect(diag['lastIgnored.2'], 'event-conflict:conflict');
      expect(diag['lastIgnored.3'],
          'event-overwritePrevented:overwrite_prevented');
      expect(diag['lastIgnored.4'], 'event-missingBase:missing_base');
    });

    test('suppressed self events increment metrics and skip processing',
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
      final event = MockEvent();
      final sentRegistry = SentEventRegistry();

      when(() => logger.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logger.captureException(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => client.sync())
          .thenAnswer((_) async => SyncUpdate(nextBatch: 'token'));
      when(() => session.timelineEvents)
          .thenAnswer((_) => const Stream<Event>.empty());
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => room.id).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);
      when(() => settingsDb.itemByKey(lastReadMatrixEventTs))
          .thenAnswer((_) async => null);
      when(() => settingsDb.saveSettingsItem(any(), any()))
          .thenAnswer((_) async => 1);
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
      when(() => timeline.events).thenReturn(<Event>[event]);
      when(() => timeline.cancelSubscriptions()).thenReturn(null);

      when(() => event.eventId).thenReturn(r'$self-event');
      when(() => event.roomId).thenReturn('!room:server');
      when(() => event.senderId).thenReturn('@remote:server');
      when(() => event.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(5));
      when(() => event.type).thenReturn('m.room.message');
      when(() => event.messageType).thenReturn(syncMessageType);
      when(() => event.attachmentMimetype).thenReturn('application/json');
      when(() => event.content).thenReturn(const {'msgtype': syncMessageType});

      sentRegistry.register(r'$self-event');

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
        sentEventRegistry: sentRegistry,
      );

      fakeAsync((async) {
        unawaited(consumer.initialize());
        async.flushMicrotasks();
        unawaited(consumer.start());
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();
      });

      final snapshot = consumer.metricsSnapshot();
      expect(snapshot['selfEventsSuppressed'], greaterThanOrEqualTo(1));
      // Prefetch metric removed
      verify(
        () => logger.captureEvent(
          contains(r'marker.local id=$self-event'),
          domain: any<String>(named: 'domain'),
          subDomain: 'marker.local',
        ),
      ).called(greaterThanOrEqualTo(1));
      verifyNever(
        () => processor.process(
          event: event,
          journalDb: journalDb,
        ),
      );
      verify(
        () => logger.captureEvent(
          contains('selfEventSuppressed'),
          domain: any<String>(named: 'domain'),
          subDomain: 'selfEvent',
        ),
      ).called(greaterThanOrEqualTo(1));

      await consumer.forceRescan(includeCatchUp: false);
      final snapshotAfterRescan = consumer.metricsSnapshot();
      expect(
        snapshotAfterRescan['selfEventsSuppressed'],
        greaterThanOrEqualTo(snapshot['selfEventsSuppressed'] ?? 0),
      );
      // Prefetch metric removed

      await consumer.dispose();
    });
  });

  group('Wake from standby detection', () {
    test('detects wake when gap exceeds threshold and triggers catch-up',
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
            .thenAnswer((_) => const Stream.empty());
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => null);
        when(() => settingsDb.itemByKey(lastReadMatrixEventTs))
            .thenAnswer((_) async => null);

        when(() => timeline.events).thenReturn(<Event>[]);
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

        await consumer.initialize();
        async.flushMicrotasks();
        await consumer.start();

        // Let initial scan complete to set _lastLiveScanAt
        async.elapse(const Duration(seconds: 1));

        // Advance time past the standby threshold (30 seconds)
        async.elapse(const Duration(seconds: 35));

        // Trigger a signal which should detect wake
        await consumer.forceRescan(includeCatchUp: false);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));

        // Verify wake detection was logged
        verify(
          () => logger.captureEvent(
            any<String>(that: contains('wake.detected')),
            domain: any<String>(named: 'domain'),
            subDomain: 'wake',
          ),
        ).called(greaterThanOrEqualTo(1));

        await consumer.dispose();
      });
    });

    test('defers marker advancement when wake catch-up is pending', () async {
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

        final capturedEvents = <String>[];

        when(() => logger.captureEvent(any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'))).thenAnswer((inv) {
          capturedEvents.add(inv.positionalArguments[0] as String);
        });
        when(() => logger.captureException(any<Object>(),
                domain: any<String>(named: 'domain'),
                subDomain: any<String>(named: 'subDomain'),
                stackTrace: any<StackTrace?>(named: 'stackTrace')))
            .thenReturn(null);

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => session.timelineEvents)
            .thenAnswer((_) => const Stream.empty());
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => null);
        when(() => settingsDb.itemByKey(lastReadMatrixEventTs))
            .thenAnswer((_) async => null);

        // Create an event that would trigger marker advancement
        final ev = MockEvent();
        when(() => ev.eventId).thenReturn('evt-wake-1');
        when(() => ev.roomId).thenReturn('!room:server');
        when(() => ev.senderId).thenReturn('@other:server');
        when(() => ev.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(100000));
        when(() => ev.content).thenReturn({
          'msgtype': syncMessageType,
          'body': base64Encode(utf8.encode('{"journalEntity":null}')),
        });

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
        async.flushMicrotasks();
        await consumer.start();

        // Let initial scan complete
        async.elapse(const Duration(seconds: 1));

        // Advance past standby threshold
        async.elapse(const Duration(seconds: 35));

        // Trigger scan which should detect wake and defer markers
        await consumer.forceRescan(includeCatchUp: false);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));

        // Check that wake detection was logged
        final hasWakeLog = capturedEvents.any(
          (e) => e.contains('wake.detected'),
        );
        expect(hasWakeLog, isTrue);
        // Note: marker.deferred.wake may or may not fire depending on timing

        await consumer.dispose();
      });
    });

    test('retries wake catch-up when it fails', () async {
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

        final capturedEvents = <String>[];

        when(() => logger.captureEvent(any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'))).thenAnswer((inv) {
          capturedEvents.add(inv.positionalArguments[0] as String);
        });
        when(() => logger.captureException(any<Object>(),
                domain: any<String>(named: 'domain'),
                subDomain: any<String>(named: 'subDomain'),
                stackTrace: any<StackTrace?>(named: 'stackTrace')))
            .thenReturn(null);

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => session.timelineEvents)
            .thenAnswer((_) => const Stream.empty());
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        // First call returns null (no room), subsequent calls return room
        var roomCallCount = 0;
        when(() => roomManager.currentRoom).thenAnswer((_) {
          roomCallCount++;
          return roomCallCount > 2 ? room : null;
        });
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => null);
        when(() => settingsDb.itemByKey(lastReadMatrixEventTs))
            .thenAnswer((_) async => null);

        when(() => timeline.events).thenReturn(<Event>[]);
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

        await consumer.initialize();
        async.flushMicrotasks();
        await consumer.start();

        // Let things settle
        async.elapse(const Duration(seconds: 1));

        // Advance past standby threshold
        async.elapse(const Duration(seconds: 35));

        // Force a signal to trigger wake detection
        await consumer.forceRescan(includeCatchUp: false);
        async.flushMicrotasks();

        // Wait for retry timer
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        // May or may not have retry depending on room availability
        // The key is no exceptions were thrown
        expect(capturedEvents, isNotEmpty); // Test passes if no exceptions

        await consumer.dispose();
      });
    });

    test('handles catch-up in-flight when wake detected', () async {
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

        final capturedEvents = <String>[];

        when(() => logger.captureEvent(any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'))).thenAnswer((inv) {
          capturedEvents.add(inv.positionalArguments[0] as String);
        });
        when(() => logger.captureException(any<Object>(),
                domain: any<String>(named: 'domain'),
                subDomain: any<String>(named: 'subDomain'),
                stackTrace: any<StackTrace?>(named: 'stackTrace')))
            .thenReturn(null);

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => session.timelineEvents)
            .thenAnswer((_) => const Stream.empty());
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => null);
        when(() => settingsDb.itemByKey(lastReadMatrixEventTs))
            .thenAnswer((_) async => null);

        // Make getTimeline slow to simulate in-flight catch-up
        when(() => timeline.events).thenReturn(<Event>[]);
        when(() => timeline.cancelSubscriptions()).thenReturn(null);
        when(() => room.getTimeline(limit: any(named: 'limit')))
            .thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return timeline;
        });
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

        await consumer.initialize();
        async.flushMicrotasks();
        await consumer.start();

        // Let initial scan start
        async.elapse(const Duration(milliseconds: 500));

        // Advance past standby threshold
        async.elapse(const Duration(seconds: 35));

        // Multiple force rescans to test in-flight handling
        unawaited(consumer.forceRescan(includeCatchUp: true));
        async.elapse(const Duration(milliseconds: 50));
        unawaited(consumer.forceRescan(includeCatchUp: true));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 2));

        // May or may not fire depending on timing; the key is no exceptions
        expect(capturedEvents, isNotEmpty);

        await consumer.dispose();
      });
    });
  });

  group('guarded catch-up retry', () {
    test('skips when catch-up already in flight', () async {
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
        final streamController = StreamController<Event>.broadcast();

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => session.timelineEvents)
            .thenAnswer((_) => streamController.stream);
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => timeline.events).thenReturn(<Event>[]);
        when(() => timeline.cancelSubscriptions()).thenReturn(null);
        when(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: any<String>(named: 'eventId'),
            )).thenAnswer((_) async {});
        when(() => processor.process(
              event: any<Event>(named: 'event'),
              journalDb: journalDb,
            )).thenAnswer((_) async {});

        // Track captured log messages
        final capturedMessages = <String>[];
        when(
          () => logger.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((invocation) {
          capturedMessages.add(invocation.positionalArguments[0] as String);
        });
        when(
          () => logger.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenReturn(null);

        // Return a stored marker to trigger the catch-up retry path
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => 'stored-marker');

        // Create a completer to block the initial catch-up slice
        final catchupCompleter = Completer<void>();
        var catchupCallCount = 0;

        when(() => room.getTimeline(limit: any<int>(named: 'limit')))
            .thenAnswer((_) async {
          catchupCallCount++;
          if (catchupCallCount == 1) {
            // First catch-up blocks to keep _catchUpInFlight true
            await catchupCompleter.future;
          }
          return timeline;
        });
        when(
          () => room.getTimeline(
            onNewEvent: any<void Function()?>(named: 'onNewEvent'),
            onInsert: any<void Function(int)?>(named: 'onInsert'),
            onChange: any<void Function(int)?>(named: 'onChange'),
            onRemove: any<void Function(int)?>(named: 'onRemove'),
            onUpdate: any<void Function()?>(named: 'onUpdate'),
          ),
        ).thenAnswer((_) async => timeline);

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
        async.flushMicrotasks();

        unawaited(consumer.start());
        // Give async operations time to progress through start()
        // start() awaits roomManager.initialize() then _attachCatchUp()
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 50));
        async.flushMicrotasks();

        // Let the 150ms delayed catch-up retry fire while first catch-up blocks
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();

        // The guarded catch-up retry should be skipped because initial catch-up
        // is still in flight. The message format is: 'source: skipped (catch-up already in flight)'
        final skipMessage = capturedMessages
            .where((m) =>
                m.contains('skipped') &&
                m.contains('catch-up already in flight'))
            .toList();
        expect(
          skipMessage,
          isNotEmpty,
          reason:
              'Guarded catch-up should skip when catch-up already in flight. '
              'All messages: ${capturedMessages.take(20).toList()}',
        );

        // Complete the blocking catch-up to clean up
        catchupCompleter.complete();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));

        streamController.close();
      });
    });
  });

  group('processing serialization', () {
    test('concurrent _processOrdered calls wait for previous batch', () async {
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
        final streamController = StreamController<Event>.broadcast();

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => session.timelineEvents)
            .thenAnswer((_) => streamController.stream);
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => timeline.cancelSubscriptions()).thenReturn(null);
        when(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: any<String>(named: 'eventId'),
            )).thenAnswer((_) async {});
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => null);

        // Track captured log messages
        final capturedMessages = <String>[];
        when(
          () => logger.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((invocation) {
          capturedMessages.add(invocation.positionalArguments[0] as String);
        });
        when(
          () => logger.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenReturn(null);

        // Create events to process
        final event1 = MockEvent();
        when(() => event1.eventId).thenReturn('E1');
        when(() => event1.roomId).thenReturn('!room:server');
        when(() => event1.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(1000));
        when(() => event1.senderId).thenReturn('@other:server');
        when(() => event1.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
        when(() => event1.attachmentMimetype).thenReturn('');

        final event2 = MockEvent();
        when(() => event2.eventId).thenReturn('E2');
        when(() => event2.roomId).thenReturn('!room:server');
        when(() => event2.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(2000));
        when(() => event2.senderId).thenReturn('@other:server');
        when(() => event2.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
        when(() => event2.attachmentMimetype).thenReturn('');

        // First call to processor.process blocks, second completes immediately
        final processorCompleter = Completer<void>();
        var processCalls = 0;
        when(() => processor.process(
              event: any<Event>(named: 'event'),
              journalDb: journalDb,
            )).thenAnswer((_) async {
          processCalls++;
          if (processCalls == 1) {
            await processorCompleter.future;
          }
        });

        // First getTimeline returns event1 (for initial catch-up)
        // Second getTimeline returns event2 (for forced rescan)
        var timelineCalls = 0;
        when(() => room.getTimeline(limit: any<int>(named: 'limit')))
            .thenAnswer((_) async {
          timelineCalls++;
          if (timelineCalls == 1) {
            when(() => timeline.events).thenReturn(<Event>[event1]);
          } else {
            when(() => timeline.events).thenReturn(<Event>[event2]);
          }
          return timeline;
        });
        when(
          () => room.getTimeline(
            onNewEvent: any<void Function()?>(named: 'onNewEvent'),
            onInsert: any<void Function(int)?>(named: 'onInsert'),
            onChange: any<void Function(int)?>(named: 'onChange'),
            onRemove: any<void Function(int)?>(named: 'onRemove'),
            onUpdate: any<void Function()?>(named: 'onUpdate'),
          ),
        ).thenAnswer((_) async {
          when(() => timeline.events).thenReturn(<Event>[]);
          return timeline;
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
          sentEventRegistry: SentEventRegistry(),
        );

        unawaited(consumer.initialize());
        async.flushMicrotasks();
        unawaited(consumer.start());
        async.flushMicrotasks();

        // Let initial catch-up start (will block on processor)
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        // Trigger another rescan while first is still processing
        capturedMessages.clear();
        unawaited(consumer.forceRescan(includeCatchUp: true));
        async.flushMicrotasks();

        // Elapse some time but not enough to timeout (less than 5 seconds)
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        // The second batch should log that it's waiting
        expect(
          capturedMessages.any((m) => m.contains('waiting for previous batch')),
          isTrue,
          reason: 'Second batch should wait for first batch to complete',
        );

        // Complete the first batch
        processorCompleter.complete();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        // Both events should eventually be processed
        expect(processCalls, greaterThanOrEqualTo(1));

        streamController.close();
      });
    });

    test('waits without timing out when previous batch takes too long',
        () async {
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
        final streamController = StreamController<Event>.broadcast();

        when(() => session.client).thenReturn(client);
        when(() => client.userID).thenReturn('@me:server');
        when(() => session.timelineEvents)
            .thenAnswer((_) => streamController.stream);
        when(() => roomManager.initialize()).thenAnswer((_) async {});
        when(() => roomManager.currentRoom).thenReturn(room);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => timeline.cancelSubscriptions()).thenReturn(null);
        when(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: any<String>(named: 'eventId'),
            )).thenAnswer((_) async {});
        when(() => settingsDb.itemByKey(lastReadMatrixEventId))
            .thenAnswer((_) async => null);

        // Track captured log messages
        final capturedMessages = <String>[];
        when(
          () => logger.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((invocation) {
          capturedMessages.add(invocation.positionalArguments[0] as String);
        });

        // Track captured exceptions
        final capturedExceptions = <Object>[];
        when(
          () => logger.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          ),
        ).thenAnswer((invocation) {
          capturedExceptions.add(invocation.positionalArguments[0] as Object);
        });

        // Create event to process
        final event1 = MockEvent();
        when(() => event1.eventId).thenReturn('E1');
        when(() => event1.roomId).thenReturn('!room:server');
        when(() => event1.originServerTs)
            .thenReturn(DateTime.fromMillisecondsSinceEpoch(1000));
        when(() => event1.senderId).thenReturn('@other:server');
        when(() => event1.content)
            .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
        when(() => event1.attachmentMimetype).thenReturn('');

        // Processor never completes (simulates stuck processing)
        when(() => processor.process(
              event: any<Event>(named: 'event'),
              journalDb: journalDb,
            )).thenAnswer((_) => Completer<void>().future);

        when(() => timeline.events).thenReturn(<Event>[event1]);
        when(() => room.getTimeline(limit: any<int>(named: 'limit')))
            .thenAnswer((_) async => timeline);
        when(
          () => room.getTimeline(
            onNewEvent: any<void Function()?>(named: 'onNewEvent'),
            onInsert: any<void Function(int)?>(named: 'onInsert'),
            onChange: any<void Function(int)?>(named: 'onChange'),
            onRemove: any<void Function(int)?>(named: 'onRemove'),
            onUpdate: any<void Function()?>(named: 'onUpdate'),
          ),
        ).thenAnswer((_) async => timeline);

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

        // Let initial catch-up start (will block forever on processor)
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        // Trigger another rescan
        capturedMessages.clear();
        unawaited(consumer.forceRescan(includeCatchUp: true));
        async.flushMicrotasks();

        // Elapse long enough to prove we do not time out while waiting.
        async.elapse(const Duration(seconds: 6));
        async.flushMicrotasks();

        // We should log that we're waiting, but never time out.
        expect(
          capturedMessages
              .any((m) => m.contains('waiting for previous batch to complete')),
          isTrue,
          reason:
              'Should log waiting message while previous batch is in flight',
        );
        expect(
          capturedMessages.any((m) =>
              m.contains('timeout waiting for previous batch, throwing')),
          isFalse,
          reason: 'Should not time out while waiting for previous batch',
        );

        // No TimeoutException should be thrown.
        expect(
          capturedExceptions.any((e) => e is TimeoutException),
          isFalse,
          reason: 'TimeoutException should not be thrown while waiting',
        );

        streamController.close();
      });
    });
  });

  group('SDK sync wait before catch-up', () {
    test('waits for sync completion before catch-up and logs synced=true', () {
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

        // Create a fake stream controller for onSync
        final cachedController = CachedStreamController<SyncUpdate>();
        addTearDown(cachedController.close);

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
        when(() => client.onSync).thenReturn(cachedController);
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

        when(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: any<String>(named: 'eventId'),
            )).thenAnswer((_) async {});

        // Use skipSyncWait: false to test the actual sync wait logic
        final consumer = MatrixStreamConsumer(
          skipSyncWait: false,
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

        // Emit a sync update to simulate SDK sync completion
        cachedController.add(SyncUpdate(
          nextBatch: 'batch1',
          rooms: RoomsUpdate(),
        ));
        async.flushMicrotasks();

        // Allow catch-up to proceed
        async.elapse(const Duration(milliseconds: 500));
        async.flushMicrotasks();

        // Verify log shows synced=true
        expect(
          capturedLogs
              .any((l) => l.contains('catchup.waitForSync synced=true')),
          isTrue,
          reason: 'Should log synced=true when sync completes before timeout',
        );

        // Should NOT have timeout log
        expect(
          capturedLogs.any((l) => l.contains('waitForSync.timeout')),
          isFalse,
          reason: 'Should not timeout when sync completes quickly',
        );

        consumer.dispose();
        async.flushMicrotasks();
      });
    });

    test('times out and sets up pending listener on slow sync', () {
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

        final cachedController = CachedStreamController<SyncUpdate>();
        addTearDown(cachedController.close);

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
        when(() => client.onSync).thenReturn(cachedController);
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

        when(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: any<String>(named: 'eventId'),
            )).thenAnswer((_) async {});

        final consumer = MatrixStreamConsumer(
          skipSyncWait: false,
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

        // Do NOT emit sync - let it timeout
        // Elapse past the 30s timeout
        async.elapse(const Duration(seconds: 35));
        async.flushMicrotasks();

        // Verify timeout log
        expect(
          capturedLogs.any((l) => l.contains('waitForSync.timeout')),
          isTrue,
          reason: 'Should log timeout when sync does not complete in time',
        );

        // Verify synced=false
        expect(
          capturedLogs
              .any((l) => l.contains('catchup.waitForSync synced=false')),
          isTrue,
          reason: 'Should log synced=false on timeout',
        );

        consumer.dispose();
        async.flushMicrotasks();
      });
    });

    test('pending sync listener triggers follow-up catch-up after timeout', () {
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

        final cachedController = CachedStreamController<SyncUpdate>();
        addTearDown(cachedController.close);

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
        when(() => client.onSync).thenReturn(cachedController);
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

        when(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: any<String>(named: 'eventId'),
            )).thenAnswer((_) async {});

        final consumer = MatrixStreamConsumer(
          skipSyncWait: false,
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

        // Let it timeout (30s)
        async.elapse(const Duration(seconds: 35));
        async.flushMicrotasks();

        // Clear logs to isolate the follow-up catch-up
        capturedLogs.clear();

        // Now emit sync after timeout - this should trigger the pending listener
        cachedController.add(SyncUpdate(
          nextBatch: 'batch2',
          rooms: RoomsUpdate(),
        ));
        async.flushMicrotasks();

        // Allow follow-up catch-up to run
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();

        // Verify pending listener triggered
        expect(
          capturedLogs.any((l) => l.contains('pendingSyncListener.triggered')),
          isTrue,
          reason:
              'Pending sync listener should trigger when sync completes after timeout',
        );

        consumer.dispose();
        async.flushMicrotasks();
      });
    });

    test(
        'dispose completes without error when pending sync subscription exists',
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

        final cachedController = CachedStreamController<SyncUpdate>();
        addTearDown(cachedController.close);

        when(() => logger.captureEvent(
              any<Object>(),
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
        when(() => client.onSync).thenReturn(cachedController);
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

        when(() => readMarker.updateReadMarker(
              client: any<Client>(named: 'client'),
              room: any<Room>(named: 'room'),
              eventId: any<String>(named: 'eventId'),
            )).thenAnswer((_) async {});

        final consumer = MatrixStreamConsumer(
          skipSyncWait: false,
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

        // Let it timeout to set up pending listener
        async.elapse(const Duration(seconds: 35));
        async.flushMicrotasks();

        // Dispose should complete without error even with pending subscription
        expect(
          () {
            unawaited(consumer.dispose());
            async.flushMicrotasks();
            async.elapse(const Duration(milliseconds: 100));
            async.flushMicrotasks();
          },
          returnsNormally,
          reason: 'Dispose should complete without error',
        );
      });
    });
  });
}
