import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_consumer.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

// ignore_for_file: cascade_invocations

class MockMatrixSessionManager extends Mock implements MatrixSessionManager {}

class MockSyncRoomManager extends Mock implements SyncRoomManager {}

class MockLoggingService extends Mock implements LoggingService {}

class MockJournalDb extends Mock implements JournalDb {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockSyncEventProcessor extends Mock implements SyncEventProcessor {}

class MockSyncReadMarkerService extends Mock implements SyncReadMarkerService {}

class MockClient extends Mock implements Client {}

class MockEvent extends Mock implements Event {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(MockClient());
  });

  test('clientStream signals coalesce to <= 2 rescans in a burst window',
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
      final controller = StreamController<Event>.broadcast();
      addTearDown(controller.close);

      when(() => session.client).thenReturn(client);
      when(() => client.userID).thenReturn('@me:server');
      when(() => session.timelineEvents).thenAnswer((_) => controller.stream);
      when(roomManager.initialize).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(null);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => roomManager.hydrateRoomSnapshot(client: any(named: 'client')))
          .thenAnswer((_) async {});
      when(() => settingsDb.itemByKey(any())).thenAnswer((_) async => null);
      when(() => logger.captureEvent(any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenAnswer((_) {});

      final consumer = MatrixStreamConsumer(
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
      addTearDown(consumer.dispose);

      // Burst 10 clientStream signals in quick succession
      for (var i = 0; i < 10; i++) {
        final ev = MockEvent();
        when(() => ev.roomId).thenReturn('!room:server');
        controller.add(ev);
      }

      // Allow coalescing to debounce
      async.elapse(const Duration(milliseconds: 100));
      // Then allow trailing run to schedule
      async.elapse(const Duration(milliseconds: 1800));

      // Count forceRescan.start includeCatchUp=true logs (allow zero if fully coalesced)
      var invocations = 0;
      try {
        invocations = verify(
          () => logger.captureEvent(
            any<Object>(
                that: contains('forceRescan.start includeCatchUp=true')),
            domain: any(named: 'domain'),
            subDomain: any(named: 'subDomain'),
          ),
        ).callCount;
      } catch (_) {
        invocations = 0;
      }

      expect(invocations <= 2, isTrue,
          reason:
              'Coalescing should limit rescans to <= 2 per burst (0 is OK)');
    });
  });
}
