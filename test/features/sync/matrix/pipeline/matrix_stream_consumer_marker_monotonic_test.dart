// ignore_for_file: cascade_invocations, unnecessary_lambdas, unawaited_futures
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

void main() {
  setUpAll(() {
    registerFallbackValue(MockEvent());
  });

  test('does not advance marker on equal/older events (fakeAsync)', () async {
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
      // Seed last processed marker to E1@100
      when(() => settingsDb.itemByKey(lastReadMatrixEventId))
          .thenAnswer((_) async => 'E1');
      when(() => settingsDb.itemByKey(lastReadMatrixEventTs))
          .thenAnswer((_) async => '100');
      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => room.getTimeline(limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);
      when(() => room.getTimeline(
            onNewEvent: any(named: 'onNewEvent'),
            onInsert: any(named: 'onInsert'),
            onChange: any(named: 'onChange'),
            onRemove: any(named: 'onRemove'),
            onUpdate: any(named: 'onUpdate'),
          )).thenAnswer((_) async => timeline);

      // Provide only equal/older payloads
      Event mk(String id, int ts) {
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

      final eEqualLowerId = mk('E0', 100); // equal ts but id < E1
      final eOlder = mk('E9', 90);
      when(() => timeline.events).thenReturn(<Event>[eEqualLowerId, eOlder]);

      when(() => processor.process(
          event: any(named: 'event'),
          journalDb: journalDb)).thenAnswer((_) async {});

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

      // Let initial live scan run and any marker debounce windows elapse
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();

      // No local/remote marker advancement should be scheduled
      verifyNever(() => logger.captureEvent(
            any<String>(that: contains('marker.local id=')),
            domain: syncLoggingDomain,
            subDomain: 'marker.local',
          ));
      verifyNever(() => readMarker.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
            timeline: any<Timeline>(named: 'timeline'),
          ));
    });
  });
}
