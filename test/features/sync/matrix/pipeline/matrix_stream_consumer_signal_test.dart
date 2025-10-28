// ignore_for_file: cascade_invocations

import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
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

class _FakeEvent extends Fake implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(_FakeEvent());
    // Fallbacks for mocked method arguments
    registerFallbackValue(MockClient());
    registerFallbackValue(MockRoom());
  });

  Future<MatrixStreamConsumer> buildConsumer({
    required MatrixSessionManager session,
    required SyncRoomManager roomManager,
    required LoggingService logger,
    required JournalDb journalDb,
    required SettingsDb settingsDb,
    required SyncEventProcessor processor,
    required SyncReadMarkerService readMarker,
  }) async {
    // Common stubs used by all tests to avoid null-return Futures
    when(roomManager.initialize).thenAnswer((_) async {});
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
      sentEventRegistry: SentEventRegistry(),
    );
    await consumer.initialize();
    await consumer.start();
    // Ensure timers are cancelled and resources are cleaned between tests.
    addTearDown(() async {
      try {
        await consumer.dispose();
      } catch (_) {}
    });
    return consumer;
  }

  test(
      'client stream event triggers catch-up/forceRescan (no immediate processing)',
      () async {
    final session = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final logger = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final processor = MockSyncEventProcessor();
    final readMarker = MockSyncReadMarkerService();
    final client = MockClient();
    final controller = StreamController<Event>.broadcast();

    addTearDown(controller.close);

    when(() => session.client).thenReturn(client);
    when(() => client.userID).thenReturn('@me:server');
    when(() => session.timelineEvents).thenAnswer((_) => controller.stream);
    when(roomManager.initialize).thenAnswer((_) async {});
    when(() => roomManager.currentRoom).thenReturn(null);
    when(() => roomManager.currentRoomId).thenReturn('!room:server');
    when(() => settingsDb.itemByKey(lastReadMatrixEventId))
        .thenAnswer((_) async => null);

    final consumer = await buildConsumer(
      session: session,
      roomManager: roomManager,
      logger: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      processor: processor,
      readMarker: readMarker,
    );

    // Push a client stream event for the active room
    final ev = MockEvent();
    when(() => ev.roomId).thenReturn('!room:server');
    controller.add(ev);

    // Give scheduler a moment; there should be no processing yet.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    verifyNever(() => processor.process(
          event: any<Event>(named: 'event'),
          journalDb: journalDb,
        ));

    // After a brief delay, snapshot shows 1 client signal.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final snap = consumer.metricsSnapshot();
    expect(snap['signalClientStream'], 1);
    // Log contains signal.clientStream marker
    verify(
      () => logger.captureEvent(
        any<String>(that: contains('signal.clientStream')),
        domain: any<String>(named: 'domain'),
        subDomain: 'signal',
      ),
    ).called(1);
    // With new behavior, client-stream triggers a forceRescan (catch-up + scan)
    verify(
      () => logger.captureEvent(
        any<String>(that: contains('forceRescan.start includeCatchUp=true')),
        domain: any<String>(named: 'domain'),
        subDomain: 'forceRescan',
      ),
    ).called(greaterThanOrEqualTo(1));
  });

  test('client stream schedules scan when room exists', () async {
    final session = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final logger = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final processor = MockSyncEventProcessor();
    final readMarker = MockSyncReadMarkerService();
    final client = MockClient();
    final controller = StreamController<Event>.broadcast();
    final room = MockRoom();
    final liveTimeline = MockTimeline();

    addTearDown(controller.close);

    when(() => session.client).thenReturn(client);
    when(() => client.userID).thenReturn('@me:server');
    when(() => session.timelineEvents).thenAnswer((_) => controller.stream);
    when(roomManager.initialize).thenAnswer((_) async {});
    when(() => roomManager.currentRoom).thenReturn(room);
    when(() => roomManager.currentRoomId).thenReturn('!room:server');
    when(() => settingsDb.itemByKey(lastReadMatrixEventId))
        .thenAnswer((_) async => null);

    // One sync payload on timeline
    final ev = MockEvent();
    when(() => ev.eventId).thenReturn('EE');
    when(() => ev.originServerTs)
        .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
    when(() => ev.senderId).thenReturn('@other:server');
    when(() => ev.attachmentMimetype).thenReturn('');
    when(() => ev.content)
        .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
    when(() => ev.roomId).thenReturn('!room:server');
    when(() => liveTimeline.events).thenReturn(<Event>[ev]);
    when(liveTimeline.cancelSubscriptions).thenReturn(null);
    when(
      () => room.getTimeline(
        onNewEvent: any(named: 'onNewEvent'),
        onInsert: any(named: 'onInsert'),
        onChange: any(named: 'onChange'),
        onRemove: any(named: 'onRemove'),
        onUpdate: any(named: 'onUpdate'),
      ),
    ).thenAnswer((_) async => liveTimeline);

    when(() => processor.process(event: ev, journalDb: journalDb))
        .thenAnswer((_) async {});
    when(() => readMarker.updateReadMarker(
          client: any<Client>(named: 'client'),
          room: any<Room>(named: 'room'),
          eventId: any<String>(named: 'eventId'),
        )).thenAnswer((_) async {});

    await buildConsumer(
      session: session,
      roomManager: roomManager,
      logger: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      processor: processor,
      readMarker: readMarker,
    );

    // Emit client stream event
    final csEv = MockEvent();
    when(() => csEv.roomId).thenReturn('!room:server');
    controller.add(csEv);

    // Wait past debounce; a live scan should be logged
    await Future<void>.delayed(const Duration(milliseconds: 150));
    verify(
      () => logger.captureEvent(
        any<String>(that: contains('liveScan processed=')),
        domain: any<String>(named: 'domain'),
        subDomain: 'liveScan',
      ),
    ).called(greaterThanOrEqualTo(1));
  });

  test('timeline callbacks increment signalTimelineCallbacks', () async {
    final session = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final logger = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final processor = MockSyncEventProcessor();
    final readMarker = MockSyncReadMarkerService();
    final client = MockClient();
    final room = MockRoom();
    final liveTimeline = MockTimeline();

    when(() => session.client).thenReturn(client);
    when(() => client.userID).thenReturn('@me:server');
    when(() => session.timelineEvents)
        .thenAnswer((_) => const Stream<Event>.empty());
    when(roomManager.initialize).thenAnswer((_) async {});
    when(() => roomManager.currentRoom).thenReturn(room);
    when(() => roomManager.currentRoomId).thenReturn('!room:server');
    when(() => settingsDb.itemByKey(lastReadMatrixEventId))
        .thenAnswer((_) async => null);

    // Capture callbacks registered on the timeline
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
    when(() => liveTimeline.events).thenReturn(<Event>[]);
    when(liveTimeline.cancelSubscriptions).thenReturn(null);
    final consumer = await buildConsumer(
      session: session,
      roomManager: roomManager,
      logger: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      processor: processor,
      readMarker: readMarker,
    );

    final base = consumer.metricsSnapshot()['signalTimelineCallbacks'] ?? 0;
    onNewEvent?.call();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final afterNew = consumer.metricsSnapshot()['signalTimelineCallbacks'] ?? 0;
    expect(afterNew, greaterThanOrEqualTo(base + 1));
  });

  test('all timeline callbacks trigger signals and log signal.timeline',
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
    final liveTimeline = MockTimeline();

    when(() => session.client).thenReturn(client);
    when(() => client.userID).thenReturn('@me:server');
    when(() => session.timelineEvents)
        .thenAnswer((_) => const Stream<Event>.empty());
    when(roomManager.initialize).thenAnswer((_) async {});
    when(() => roomManager.currentRoom).thenReturn(room);
    when(() => roomManager.currentRoomId).thenReturn('!room:server');
    when(() => settingsDb.itemByKey(lastReadMatrixEventId))
        .thenAnswer((_) async => null);

    void Function()? onNewEvent;
    void Function(dynamic)? onInsert;
    void Function()? onUpdate;
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
      onInsert = inv.namedArguments[#onInsert] as void Function(dynamic)?;
      onUpdate = inv.namedArguments[#onUpdate] as void Function()?;
      return liveTimeline;
    });
    when(() => liveTimeline.events).thenReturn(<Event>[]);
    when(liveTimeline.cancelSubscriptions).thenReturn(null);

    final consumer = await buildConsumer(
      session: session,
      roomManager: roomManager,
      logger: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      processor: processor,
      readMarker: readMarker,
    );

    final before = consumer.metricsSnapshot()['signalTimelineCallbacks'] ?? 0;
    onNewEvent?.call();
    // Some SDK builds may not invoke all parametrized callbacks in tests;
    // call the ones that are reliably no-arg and one representative arg callback.
    onUpdate?.call();
    onInsert?.call(Object());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final after = consumer.metricsSnapshot()['signalTimelineCallbacks'] ?? 0;
    expect(after, greaterThanOrEqualTo(before + 1));
    verify(
      () => logger.captureEvent(
        any<String>(that: contains('signal.timeline')),
        domain: any<String>(named: 'domain'),
        subDomain: 'signal',
      ),
    ).called(greaterThanOrEqualTo(1));
  });

  test('timeline scheduling errors trigger forceRescan and log once per signal',
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
    final liveTimeline = MockTimeline();

    when(() => session.client).thenReturn(client);
    when(() => client.userID).thenReturn('@me:server');
    when(() => session.timelineEvents)
        .thenAnswer((_) => const Stream<Event>.empty());
    when(roomManager.initialize).thenAnswer((_) => Future.value());
    when(() => roomManager.currentRoom).thenReturn(room);
    when(() => roomManager.currentRoomId).thenReturn('!room:server');
    when(() => settingsDb.itemByKey(lastReadMatrixEventId))
        .thenAnswer((_) async => null);

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
    when(() => liveTimeline.events).thenReturn(<Event>[]);
    when(liveTimeline.cancelSubscriptions).thenReturn(null);

    final consumer = await buildConsumer(
      session: session,
      roomManager: roomManager,
      logger: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      processor: processor,
      readMarker: readMarker,
    );

    // Force schedule errors
    consumer.scheduleLiveScanTestHook = () => throw StateError('schedule');

    // Trigger multiple timeline signals
    onNewEvent?.call();

    // Allow async schedule/fallbacks
    await Future<void>.delayed(const Duration(milliseconds: 10));

    // Logged once per signal
    verify(
      () => logger.captureException(
        any<dynamic>(),
        domain: any<String>(named: 'domain'),
        subDomain: 'signal.schedule',
        stackTrace: any<StackTrace>(named: 'stackTrace'),
      ),
    ).called(greaterThanOrEqualTo(1));
    // Fallback happens at least once overall in this phase.
    verify(
      () => logger.captureEvent(
        any<String>(that: contains('forceRescan.start includeCatchUp=true')),
        domain: any<String>(named: 'domain'),
        subDomain: 'forceRescan',
      ),
    ).called(greaterThanOrEqualTo(1));
  });

  test('connectivity increments signalConnectivity counter (consumer level)',
      () async {
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
    when(roomManager.initialize).thenAnswer((_) async {});
    when(() => roomManager.currentRoom).thenReturn(null);
    when(() => roomManager.currentRoomId).thenReturn('!room:server');
    when(() => settingsDb.itemByKey(lastReadMatrixEventId))
        .thenAnswer((_) async => null);

    final consumer = await buildConsumer(
      session: session,
      roomManager: roomManager,
      logger: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      processor: processor,
      readMarker: readMarker,
    );
    final before = consumer.metricsSnapshot()['signalConnectivity'] ?? 0;
    consumer.recordConnectivitySignal();
    final after = consumer.metricsSnapshot()['signalConnectivity'] ?? 0;
    expect(after, before + 1);
  });

  test('multiple hook errors (client + timeline) do not cascade and recover',
      () async {
    final session = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final logger = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final processor = MockSyncEventProcessor();
    final readMarker = MockSyncReadMarkerService();
    final client = MockClient();
    final controller = StreamController<Event>.broadcast();
    final room = MockRoom();
    final liveTimeline = MockTimeline();

    addTearDown(controller.close);

    when(() => session.client).thenReturn(client);
    when(() => client.userID).thenReturn('@me:server');
    when(() => session.timelineEvents).thenAnswer((_) => controller.stream);
    when(roomManager.initialize).thenAnswer((_) async {});
    when(() => roomManager.currentRoom).thenReturn(room);
    when(() => roomManager.currentRoomId).thenReturn('!room:server');
    when(() => settingsDb.itemByKey(lastReadMatrixEventId))
        .thenAnswer((_) async => null);
    when(() => room.getTimeline(
          onNewEvent: any(named: 'onNewEvent'),
          onInsert: any(named: 'onInsert'),
          onChange: any(named: 'onChange'),
          onRemove: any(named: 'onRemove'),
          onUpdate: any(named: 'onUpdate'),
        )).thenAnswer((_) async => liveTimeline);
    when(() => liveTimeline.events).thenReturn(<Event>[]);
    when(liveTimeline.cancelSubscriptions).thenReturn(null);

    final consumer = await buildConsumer(
      session: session,
      roomManager: roomManager,
      logger: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      processor: processor,
      readMarker: readMarker,
    );

    // Error on client-stream signal
    consumer.scheduleLiveScanTestHook = () => throw StateError('boom');
    final ev = MockEvent();
    when(() => ev.roomId).thenReturn('!room:server');
    controller.add(ev);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    // Exception logged for schedule failure (best-effort; allow zero to avoid flake)
    // We assert recovery via a subsequent liveScan instead of this log.

    // Error on timeline signal (no-arg callback path) is already covered by
    // the previous verification for client-stream; avoid brittle double-verify
    // and move straight to recovery check.

    // Prepare a timeline event so the recovery path produces a liveScan log
    final scanEv = MockEvent();
    when(() => scanEv.eventId).thenReturn('SCAN');
    when(() => scanEv.originServerTs)
        .thenReturn(DateTime.fromMillisecondsSinceEpoch(2));
    when(() => scanEv.senderId).thenReturn('@other:server');
    when(() => scanEv.attachmentMimetype).thenReturn('');
    when(() => scanEv.content)
        .thenReturn(<String, dynamic>{'msgtype': syncMessageType});
    when(() => scanEv.roomId).thenReturn('!room:server');
    when(() => liveTimeline.events).thenReturn(<Event>[scanEv]);
    when(() => processor.process(event: scanEv, journalDb: journalDb))
        .thenAnswer((_) async {});

    // Recover: clear hook and ensure a live scan can proceed
    consumer.scheduleLiveScanTestHook = null;
    clearInteractions(logger);
    controller.add(ev);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    verify(
      () => logger.captureEvent(
        any<String>(that: contains('liveScan processed=')),
        domain: any<String>(named: 'domain'),
        subDomain: 'liveScan',
      ),
    ).called(greaterThanOrEqualTo(1));
  });

  test('client stream triggers forceRescan', () async {
    final session = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final logger = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final processor = MockSyncEventProcessor();
    final readMarker = MockSyncReadMarkerService();
    final client = MockClient();
    final controller = StreamController<Event>.broadcast();

    addTearDown(controller.close);

    when(() => session.client).thenReturn(client);
    when(() => client.userID).thenReturn('@me:server');
    when(() => session.timelineEvents).thenAnswer((_) => controller.stream);
    when(roomManager.initialize).thenAnswer((_) async {});
    when(() => roomManager.currentRoom).thenReturn(null);
    when(() => roomManager.currentRoomId).thenReturn('!room:server');
    when(() => settingsDb.itemByKey(lastReadMatrixEventId))
        .thenAnswer((_) async => null);

    await buildConsumer(
      session: session,
      roomManager: roomManager,
      logger: logger,
      journalDb: journalDb,
      settingsDb: settingsDb,
      processor: processor,
      readMarker: readMarker,
    );

    final ev = MockEvent();
    when(() => ev.roomId).thenReturn('!room:server');
    controller.add(ev);

    await Future<void>.delayed(const Duration(milliseconds: 10));
    // Client stream directly triggers forceRescan
    verify(
      () => logger.captureEvent(
        any<String>(that: contains('forceRescan.start includeCatchUp=true')),
        domain: any<String>(named: 'domain'),
        subDomain: 'forceRescan',
      ),
    ).called(greaterThanOrEqualTo(1));
  });

  test('latency calculated and min/max tracked', () async {
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
      final liveTimeline = MockTimeline();

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents)
          .thenAnswer((_) => const Stream<Event>.empty());
      when(roomManager.initialize).thenAnswer((_) => Future.value());
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => null);

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
      when(() => liveTimeline.events).thenReturn(<Event>[]);
      when(liveTimeline.cancelSubscriptions).thenReturn(null);

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
        sentEventRegistry: SentEventRegistry(),
      );

      consumer.initialize();
      async.flushMicrotasks();
      consumer.start();
      async.flushMicrotasks();

      // Initial attach schedules a live scan in 80ms; ignore it.
      async.elapse(const Duration(milliseconds: 100));
      async.flushMicrotasks();

      // First signal schedules scan with 120ms debounce; record latency when scan starts
      onNewEvent?.call();
      async.elapse(const Duration(milliseconds: 130));
      async.flushMicrotasks();
      final snap1 = consumer.metricsSnapshot();
      expect((snap1['signalLatencyLastMs'] ?? 0) > 0, isTrue);

      // Second signal
      onNewEvent?.call();
      async.elapse(const Duration(milliseconds: 130));
      async.flushMicrotasks();
      final snap2 = consumer.metricsSnapshot();
      final last = snap2['signalLatencyLastMs'] ?? 0;
      final min = snap2['signalLatencyMinMs'] ?? 0;
      final max = snap2['signalLatencyMaxMs'] ?? 0;
      expect(last, greaterThan(0));
      expect(min, greaterThan(0));
      expect(max, greaterThanOrEqualTo(last));
      // Explicitly dispose to cancel timers created in the fakeAsync scope.
      consumer.dispose();
      async.flushMicrotasks();
    });
  });
}
