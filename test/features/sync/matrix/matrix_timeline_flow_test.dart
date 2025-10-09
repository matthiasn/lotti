// ignore_for_file: unnecessary_lambdas

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/matrix_timeline_listener.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixSessionManager extends Mock implements MatrixSessionManager {}

class MockSyncRoomManager extends Mock implements SyncRoomManager {}

class MockLoggingService extends Mock implements LoggingService {}

class MockUserActivityGate extends Mock implements UserActivityGate {}

class MockSyncReadMarkerService extends Mock implements SyncReadMarkerService {}

class MockSyncEventProcessor extends Mock implements SyncEventProcessor {}

class MockJournalDb extends Mock implements JournalDb {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

class MockTimeline extends Mock implements Timeline {}

class MockEvent extends Mock implements Event {}

class FakeClient extends Fake implements Client {}

class FakeTimeline extends Fake implements Timeline {}

class FakeEvent extends Fake implements Event {}

class FakeJournalDb extends Fake implements JournalDb {}

class FakeSettingsDb extends Fake implements SettingsDb {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeClient());
    registerFallbackValue(FakeTimeline());
    registerFallbackValue(FakeEvent());
    registerFallbackValue(FakeJournalDb());
    registerFallbackValue(FakeSettingsDb());
  });

  test('MatrixTimelineListener processes remote events through runner',
      () async {
    final sessionManager = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final loggingService = MockLoggingService();
    final activityGate = MockUserActivityGate();
    final readMarkerService = MockSyncReadMarkerService();
    final eventProcessor = MockSyncEventProcessor();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final client = MockClient();
    final room = MockRoom();
    final timeline = MockTimeline();
    final event = MockEvent();
    final tempDir = Directory.systemTemp.createTempSync('matrix_timeline_flow');
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    when(() => loggingService.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
        )).thenReturn(null);
    when(() => loggingService.captureException(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
          stackTrace: any<dynamic>(named: 'stackTrace'),
        )).thenReturn(null);

    when(() => activityGate.waitUntilIdle()).thenAnswer((_) async {});

    when(() => sessionManager.client).thenReturn(client);
    when(() => client.sync())
        .thenAnswer((_) async => SyncUpdate(nextBatch: 'token'));
    when(() => client.userID).thenReturn('@local:server');
    when(() => client.deviceName).thenReturn('Unit Test Device');

    when(() => roomManager.currentRoom).thenReturn(room);

    when(() => room.getTimeline(
            eventContextId: any<String?>(named: 'eventContextId')))
        .thenAnswer((invocation) async {
      expect(invocation.namedArguments[#eventContextId], isNull);
      return timeline;
    });
    when(() => timeline.events).thenReturn(<Event>[event]);

    when(() => event.eventId).thenReturn(r'$evt');
    when(() => event.senderId).thenReturn('@remote:server');
    when(() => event.messageType).thenReturn(syncMessageType);
    when(() => event.type).thenReturn('m.room.message');
    when(() => event.attachmentMimetype).thenReturn('');
    when(() => event.content).thenReturn(<String, dynamic>{});

    when(() => eventProcessor.process(
          event: any<Event>(named: 'event'),
          journalDb: any<JournalDb>(named: 'journalDb'),
        )).thenAnswer((_) async {});
    when(() => readMarkerService.updateReadMarker(
          client: any<Client>(named: 'client'),
          timeline: any<Timeline>(named: 'timeline'),
          eventId: any<String>(named: 'eventId'),
        )).thenAnswer((_) async {});

    final listener = MatrixTimelineListener(
      sessionManager: sessionManager,
      roomManager: roomManager,
      loggingService: loggingService,
      activityGate: activityGate,
      journalDb: journalDb,
      settingsDb: settingsDb,
      readMarkerService: readMarkerService,
      eventProcessor: eventProcessor,
      documentsDirectory: tempDir,
    );

    expect(listener.lastReadEventContextId, isNull);

    await listener.clientRunner.callback(null);

    verify(() => activityGate.waitUntilIdle()).called(1);
    verify(() => client.sync()).called(1);
    verify(() => room.getTimeline()).called(1);
  });
}
