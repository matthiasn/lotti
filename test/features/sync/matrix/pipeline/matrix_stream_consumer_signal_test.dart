// ignore_for_file: cascade_invocations

import 'dart:async';

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

class MockEvent extends Mock implements Event {}

class _FakeEvent extends Fake implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(_FakeEvent());
    // Fallbacks for mocked method arguments
    registerFallbackValue(MockClient());
  });

  test(
      'client stream event triggers catch-up/forceRescan (no immediate processing)',
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
      consumer.initialize();
      async.flushMicrotasks();
      consumer.start();
      async.flushMicrotasks();
      // start() waits up to ~10s for room readiness when no room exists.
      // Advance fake time to complete that phase so the client-stream
      // subscription is attached.
      async.elapse(const Duration(seconds: 10));
      async.flushMicrotasks();
      addTearDown(() async {
        await consumer.dispose();
      });

      // Push a client stream event for the active room
      final ev = MockEvent();
      when(() => ev.roomId).thenReturn('!room:server');
      controller.add(ev);
      async.flushMicrotasks();

      // Give scheduler a moment; there should be no processing yet.
      async.elapse(const Duration(milliseconds: 10));
      async.flushMicrotasks();
      verifyNever(() => processor.process(
            event: any<Event>(named: 'event'),
            journalDb: journalDb,
          ));

      // After a brief delay, snapshot shows 1 client signal.
      async.elapse(const Duration(milliseconds: 120));
      async.flushMicrotasks();
      final snap = consumer.metricsSnapshot();
      expect(snap['signalClientStream'], 1);
      // Log contains signal.clientStream marker
      verify(
        () => logger.captureEvent(
          any<String>(that: contains('signal.clientStream')),
          domain: any<String>(named: 'domain'),
          subDomain: 'signal',
        ),
      ).called(greaterThanOrEqualTo(1));
      // With new behavior, client-stream triggers a forceRescan (catch-up + scan)
      verify(
        () => logger.captureEvent(
          any<String>(that: contains('forceRescan.start includeCatchUp=true')),
          domain: any<String>(named: 'domain'),
          subDomain: 'forceRescan',
        ),
      ).called(greaterThanOrEqualTo(1));
    });
  });

  test('catch-up coalesces within 1s minimum gap', () {
    fakeAsync((async) {
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

      // Capture logs for precise assertions
      final logs = <String>[];
      when(() => logger.captureEvent(captureAny<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenAnswer((inv) {
        logs.add(inv.positionalArguments.first.toString());
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
      unawaited(consumer.initialize());
      async.flushMicrotasks();
      unawaited(consumer.start());
      async.flushMicrotasks();
      // Allow hydration wait in start()
      async.elapse(const Duration(seconds: 10));
      async.flushMicrotasks();
      addTearDown(consumer.dispose);

      // Two client-stream signals within < 1s
      final e1 = MockEvent();
      when(() => e1.roomId).thenReturn('!room:server');
      controller.add(e1);
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 100));
      final e2 = MockEvent();
      when(() => e2.roomId).thenReturn('!room:server');
      controller.add(e2);
      async.flushMicrotasks();

      // Within the first second, we should see a coalesce log and at most one forceRescan start
      async.elapse(const Duration(milliseconds: 200));
      final coalesceSeen =
          logs.any((l) => l.contains('signal.catchup.coalesce debounceMs='));
      final rescansWithinFirstBurst = logs
          .where((l) => l.contains('forceRescan.start includeCatchUp=true'))
          .length;
      expect(coalesceSeen, isTrue);
      expect(rescansWithinFirstBurst <= 1, isTrue);

      // After total >= 1s, a trailing catch-up may run → rescans <= 2 total
      async.elapse(const Duration(milliseconds: 800));
      final rescansTotal = logs
          .where((l) => l.contains('forceRescan.start includeCatchUp=true'))
          .length;
      expect(rescansTotal <= 2, isTrue);
    });
  });

  test('trailing catch-up waits ~1s of idle before running', () {
    fakeAsync((async) {
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

      final logs = <String>[];
      when(() => logger.captureEvent(captureAny<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenAnswer((inv) {
        logs.add(inv.positionalArguments.first.toString());
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
      unawaited(consumer.initialize());
      async.flushMicrotasks();
      unawaited(consumer.start());
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 10));
      async.flushMicrotasks();
      addTearDown(consumer.dispose);

      // Burst some signals
      for (var i = 0; i < 3; i++) {
        final ev = MockEvent();
        when(() => ev.roomId).thenReturn('!room:server');
        controller.add(ev);
      }
      async.flushMicrotasks();

      // Allow scheduler to settle; don't require a specific trailing log,
      // only enforce idle delay behavior via catchup.start counts below.
      async
        ..elapse(const Duration(milliseconds: 100))
        ..flushMicrotasks();

      // Before 1s trailing delay elapses from catchup completion,
      // no new rescan should start (coalesced)
      final startsBefore = logs
          .where((l) => l.contains('forceRescan.start includeCatchUp=true'))
          .length;
      async.elapse(const Duration(milliseconds: 700));
      async.flushMicrotasks();
      final startsMid = logs
          .where((l) => l.contains('forceRescan.start includeCatchUp=true'))
          .length;
      expect(startsMid, equals(startsBefore));

      // After full 1s trailing delay + buffer for processing, trailing run fires
      async.elapse(const Duration(milliseconds: 500));
      async.flushMicrotasks();
      final startsAfter = logs
          .where((l) => l.contains('forceRescan.start includeCatchUp=true'))
          .length;
      expect(startsAfter >= startsBefore + 1, isTrue);
    });
  });
}
