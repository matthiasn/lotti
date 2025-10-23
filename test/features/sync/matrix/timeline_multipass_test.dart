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

class MockSyncRoomManager extends Mock implements SyncRoomManager {}

class MockRoom extends Mock implements Room {}

class MockClient extends Mock implements Client {}

class MockTimeline extends Mock implements Timeline {}

class MockSyncReadMarkerService extends Mock implements SyncReadMarkerService {}

class MockSyncEventProcessor extends Mock implements SyncEventProcessor {}

class MockJournalDb extends Mock implements JournalDb {}

class FakeClient extends Fake implements Client {}

class FakeTimeline extends Fake implements Timeline {}

class FakeEvent extends Fake implements Event {}

class MockEvent extends Mock implements Event {}

class TestCtx implements TimelineContext {
  TestCtx({
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
  bool refreshRequested = false;
  @override
  void enqueueTimelineRefresh() {
    refreshRequested = true;
  }
}

class TestTimelineContext implements TimelineContext {
  TestTimelineContext({
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
  setUpAll(() {
    registerFallbackValue(FakeClient());
    registerFallbackValue(FakeTimeline());
    registerFallbackValue(FakeEvent());
  });

  test('multi-pass drain performs multiple syncs when empty', () async {
    final loggingService = MockLoggingService();
    final roomManager = MockSyncRoomManager();
    final room = MockRoom();
    final client = MockClient();
    final timeline = MockTimeline();
    final readMarkerService = MockSyncReadMarkerService();
    final eventProcessor = MockSyncEventProcessor();
    final journalDb = MockJournalDb();
    final tempDir = Directory.systemTemp.createTempSync('timeline_multipass');

    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final context = TestTimelineContext(
      loggingService: loggingService,
      roomManager: roomManager,
      client: client,
    )..lastReadEventContextId = r'$existing';

    when(() => loggingService.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        )).thenReturn(null);
    when(() => loggingService.captureException(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
          stackTrace: any<dynamic>(named: 'stackTrace'),
        )).thenReturn(null);
    when(() => roomManager.currentRoom).thenReturn(room);
    when(() => roomManager.currentRoomId).thenReturn('!room:server');
    when(() => room.id).thenReturn('!room:server');
    when(() => client.isLogged()).thenReturn(true);

    final existingEvent = MockEvent();
    when(() => existingEvent.eventId).thenReturn(r'$existing');
    when(() => existingEvent.originServerTs)
        .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
    when(() => existingEvent.senderId).thenReturn('@remote:server');
    when(() => existingEvent.type).thenReturn('m.room.message');
    when(() => existingEvent.messageType).thenReturn(syncMessageType);
    when(() => existingEvent.attachmentMimetype).thenReturn('');

    when(() => timeline.events).thenReturn(<Event>[existingEvent]);
    when(() => room.getTimeline(
          eventContextId: any(named: 'eventContextId'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => timeline);

    var syncCalls = 0;
    when(() => client.sync()).thenAnswer((_) async {
      syncCalls++;
      return SyncUpdate(nextBatch: 'token');
    });

    await processNewTimelineEvents(
      listener: context,
      journalDb: journalDb,
      loggingService: loggingService,
      readMarkerService: readMarkerService,
      eventProcessor: eventProcessor,
      documentsDirectory: tempDir,
      failureCounts: <String, int>{},
      config: const TimelineConfig(
        maxDrainPasses: 2,
        timelineLimits: <int>[100],
        retryDelays: <Duration>[],
        readMarkerFollowUpDelay: Duration(milliseconds: 1),
      ),
    );

    expect(syncCalls, 2);
  });

  test('no follow-up scheduled when empty; logs idle on final pass', () async {
    final loggingService = MockLoggingService();
    final roomManager = MockSyncRoomManager();
    final room = MockRoom();
    final client = MockClient();
    final timeline = MockTimeline();
    final readMarkerService = MockSyncReadMarkerService();
    final eventProcessor = MockSyncEventProcessor();
    final journalDb = MockJournalDb();
    final tempDir = Directory.systemTemp.createTempSync('timeline_multipass');

    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final context = TestCtx(
      loggingService: loggingService,
      roomManager: roomManager,
      client: client,
    )..lastReadEventContextId = r'$existing';

    when(() => loggingService.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        )).thenReturn(null);
    when(() => loggingService.captureException(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
          stackTrace: any<dynamic>(named: 'stackTrace'),
        )).thenReturn(null);
    when(() => roomManager.currentRoom).thenReturn(room);
    when(() => roomManager.currentRoomId).thenReturn('!room:server');
    when(() => room.id).thenReturn('!room:server');
    when(() => client.isLogged()).thenReturn(true);

    final existingEvent = MockEvent();
    when(() => existingEvent.eventId).thenReturn(r'$existing');
    when(() => existingEvent.originServerTs)
        .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
    when(() => existingEvent.senderId).thenReturn('@remote:server');
    when(() => existingEvent.type).thenReturn('m.room.message');
    when(() => existingEvent.messageType).thenReturn(syncMessageType);
    when(() => existingEvent.attachmentMimetype).thenReturn('');

    when(() => timeline.events).thenReturn(<Event>[existingEvent]);
    when(() => room.getTimeline(
          eventContextId: any(named: 'eventContextId'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => timeline);

    when(() => client.sync())
        .thenAnswer((_) async => SyncUpdate(nextBatch: 't'));

    await processNewTimelineEvents(
      listener: context,
      journalDb: journalDb,
      loggingService: loggingService,
      readMarkerService: readMarkerService,
      eventProcessor: eventProcessor,
      documentsDirectory: tempDir,
      failureCounts: <String, int>{},
      config: const TimelineConfig(
        maxDrainPasses: 2,
        timelineLimits: <int>[100],
        retryDelays: <Duration>[],
        readMarkerFollowUpDelay: Duration(milliseconds: 10),
      ),
    );

    // Give a little time in case a follow-up was (incorrectly) scheduled.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(context.refreshRequested, isFalse);

    // Verify the idle log emitted on final pass.
    verify(
      () => loggingService.captureEvent(
        contains('idle – waiting for live timeline callbacks'),
        domain: 'MATRIX_SERVICE',
        subDomain: 'timeline.debug',
      ),
    ).called(1);
  });
}
