// ignore_for_file: unnecessary_lambdas

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/matrix/timeline.dart';
import 'package:lotti/features/sync/matrix/timeline_config.dart';
import 'package:lotti/features/sync/matrix/timeline_context.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockRoomManager extends Mock implements SyncRoomManager {}

class MockRoom extends Mock implements Room {}

class MockClient extends Mock implements Client {}

class MockTimeline extends Mock implements Timeline {}

class MockJournalDb extends Mock implements JournalDb {}

class MockReadMarkerService extends Mock implements SyncReadMarkerService {}

class MockEventProcessor extends Mock implements SyncEventProcessor {}

class TestContext implements TimelineContext {
  TestContext({
    required this.loggingService,
    required this.roomManager,
    required this.client,
  });

  @override
  final LoggingService loggingService;

  @override
  final SyncRoomManager roomManager;

  @override
  final Client client;

  @override
  Timeline? timeline;

  @override
  String? lastReadEventContextId;

  @override
  final SentEventRegistry sentEventRegistry = SentEventRegistry();

  @override
  void enqueueTimelineRefresh() {}
}

void main() {
  test('tail settle logs only for live timeline (not snapshots)', () async {
    final logging = MockLoggingService();
    final roomManager = MockRoomManager();
    final room = MockRoom();
    final client = MockClient();
    final live = MockTimeline();
    final snap = MockTimeline();
    final journal = MockJournalDb();
    final marker = MockReadMarkerService();
    final processor = MockEventProcessor();
    final tempDir = Directory.systemTemp.createTempSync('tail_retry');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final ctx = TestContext(
      loggingService: logging,
      roomManager: roomManager,
      client: client,
    )
      ..lastReadEventContextId = r'$e0'
      // Attach a live timeline so the drainer runs the 'live' path first.
      ..timeline = live;

    when(() => logging.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        )).thenReturn(null);
    when(() => logging.captureException(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<dynamic>(named: 'stackTrace'),
        )).thenReturn(null);

    when(() => roomManager.currentRoom).thenReturn(room);
    when(() => roomManager.currentRoomId).thenReturn('!room:server');
    when(() => room.id).thenReturn('!room:server');
    when(() => client.isLogged()).thenReturn(true);

    final e0 = Event.fromJson(
      {
        'event_id': r'$e0',
        'sender': '@remote:server',
        'room_id': '!room:server',
        'type': 'm.room.message',
        'origin_server_ts': 1,
        'content': {'msgtype': syncMessageType, 'body': 'x'},
      },
      room,
    );

    when(() => live.events).thenReturn([e0]);
    when(() => snap.events).thenReturn([e0]);
    when(() => room.getTimeline(limit: any(named: 'limit')))
        .thenAnswer((_) async => snap);
    when(() => client.sync())
        .thenAnswer((_) async => SyncUpdate(nextBatch: 't'));

    await processNewTimelineEvents(
      listener: ctx,
      journalDb: journal,
      loggingService: logging,
      readMarkerService: marker,
      eventProcessor: processor,
      documentsDirectory: tempDir,
      failureCounts: <String, int>{},
      config: const TimelineConfig(
        maxDrainPasses: 1,
        timelineLimits: <int>[100],
        retryDelays: <Duration>[Duration(milliseconds: 10)],
      ),
    );

    // Expect the live tail settle log at least once.
    verify(
      () => logging.captureEvent(
        contains('Empty live timeline at tail'),
        domain: 'MATRIX_SERVICE',
        subDomain: 'timeline.debug',
      ),
    ).called(greaterThanOrEqualTo(1));

    // And no snapshot-equivalent message.
    verifyNever(
      () => logging.captureEvent(
        contains('Empty snapshot at tail'),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    );
  });

  test('logs live drain start before snapshot escalation', () async {
    final logging = MockLoggingService();
    final roomManager = MockRoomManager();
    final room = MockRoom();
    final client = MockClient();
    final live = MockTimeline();
    final snap = MockTimeline();
    final journal = MockJournalDb();
    final marker = MockReadMarkerService();
    final processor = MockEventProcessor();
    final tempDir = Directory.systemTemp.createTempSync('tail_retry_order');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final ctx = TestContext(
      loggingService: logging,
      roomManager: roomManager,
      client: client,
    )
      ..lastReadEventContextId = r'$e0'
      ..timeline = live;

    when(() => logging.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        )).thenReturn(null);
    when(() => logging.captureException(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<dynamic>(named: 'stackTrace'),
        )).thenReturn(null);

    when(() => roomManager.currentRoom).thenReturn(room);
    when(() => roomManager.currentRoomId).thenReturn('!room:server');
    when(() => room.id).thenReturn('!room:server');
    when(() => client.isLogged()).thenReturn(true);

    final e0 = Event.fromJson(
      {
        'event_id': r'$e0',
        'sender': '@remote:server',
        'room_id': '!room:server',
        'type': 'm.room.message',
        'origin_server_ts': 1,
        'content': {'msgtype': syncMessageType, 'body': 'x'},
      },
      room,
    );

    when(() => live.events).thenReturn([e0]);
    when(() => snap.events).thenReturn([e0]);
    when(() => room.getTimeline(limit: any(named: 'limit')))
        .thenAnswer((_) async => snap);
    when(() => client.sync())
        .thenAnswer((_) async => SyncUpdate(nextBatch: 't'));

    await processNewTimelineEvents(
      listener: ctx,
      journalDb: journal,
      loggingService: logging,
      readMarkerService: marker,
      eventProcessor: processor,
      documentsDirectory: tempDir,
      failureCounts: <String, int>{},
      config: const TimelineConfig(
        maxDrainPasses: 1,
        timelineLimits: <int>[100],
        retryDelays: <Duration>[Duration(milliseconds: 10)],
      ),
    );

    verifyInOrder([
      () => logging.captureEvent(
            contains('source: live'),
            domain: 'MATRIX_SERVICE',
            subDomain: 'timeline.debug',
          ),
      () => logging.captureEvent(
            contains('source: snapshot'),
            domain: 'MATRIX_SERVICE',
            subDomain: 'timeline.debug',
          ),
    ]);
  });
}
