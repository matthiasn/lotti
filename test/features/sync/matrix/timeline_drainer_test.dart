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

class MockEvent extends Mock implements Event {}

class FakeClient extends Fake implements Client {}

class FakeTimeline extends Fake implements Timeline {}

class FakeEvent extends Fake implements Event {}

class FakeJournalDb extends Fake implements JournalDb {}

class FakeRoom extends Fake implements Room {}

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
    registerFallbackValue(FakeJournalDb());
    registerFallbackValue(FakeRoom());
  });

  group('TimelineDrainer.computeFromTimeline', () {
    test('selects events strictly after lastRead (sorted oldest-first)',
        () async {
      final loggingService = MockLoggingService();
      final roomManager = MockSyncRoomManager();
      final client = MockClient();
      final timeline = MockTimeline();

      when(() => loggingService.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          )).thenReturn(null);

      final context = TestTimelineContext(
        loggingService: loggingService,
        roomManager: roomManager,
        client: client,
      )..lastReadEventContextId = r'$existing';

      // Existing and new event (unsorted in source list)
      final existing = MockEvent();
      when(() => existing.eventId).thenReturn(r'$existing');
      when(() => existing.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      when(() => existing.senderId).thenReturn('@remote:server');
      when(() => existing.type).thenReturn('m.room.message');
      when(() => existing.messageType).thenReturn(syncMessageType);
      when(() => existing.attachmentMimetype).thenReturn('');

      final newer = MockEvent();
      when(() => newer.eventId).thenReturn(r'$new');
      when(() => newer.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(2));
      when(() => newer.senderId).thenReturn('@remote:server');
      when(() => newer.type).thenReturn('m.room.message');
      when(() => newer.messageType).thenReturn(syncMessageType);
      when(() => newer.attachmentMimetype).thenReturn('');

      // Provide unsorted ordering to assert the helper sorts oldest-first.
      var call = 0;
      when(() => timeline.events).thenAnswer((_) {
        call++;
        // First call should be used for initial computation.
        return <Event>[newer, existing];
      });

      final drainer = TimelineDrainer(
        listener: context,
        journalDb: MockJournalDb(),
        loggingService: loggingService,
        readMarkerService: MockSyncReadMarkerService(),
        eventProcessor: MockSyncEventProcessor(),
        documentsDirectory: Directory.systemTemp,
        failureCounts: <String, int>{},
        config: const TimelineConfig(
          retryDelays: <Duration>[],
        ),
        metrics: null,
      );

      final selected = await drainer.computeFromTimeline(
        tl: timeline,
        source: 'live',
        pass: 0,
        roomId: '!room:server',
        usedLimit: 0,
        lastReadEventContextId: r'$existing',
      );

      expect(selected.map((e) => e.eventId), [r'$new']);
      // Ensure timeline was consulted at least once.
      expect(call, greaterThanOrEqualTo(1));
    });

    test('tail retry picks up newly appeared events on same timeline instance',
        () async {
      final loggingService = MockLoggingService();
      final roomManager = MockSyncRoomManager();
      final client = MockClient();
      final timeline = MockTimeline();

      when(() => loggingService.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          )).thenReturn(null);

      final context = TestTimelineContext(
        loggingService: loggingService,
        roomManager: roomManager,
        client: client,
      )..lastReadEventContextId = r'$existing';

      final existing = MockEvent();
      when(() => existing.eventId).thenReturn(r'$existing');
      when(() => existing.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      when(() => existing.senderId).thenReturn('@remote:server');
      when(() => existing.type).thenReturn('m.room.message');
      when(() => existing.messageType).thenReturn(syncMessageType);
      when(() => existing.attachmentMimetype).thenReturn('');

      final newer = MockEvent();
      when(() => newer.eventId).thenReturn(r'$new');
      when(() => newer.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(2));
      when(() => newer.senderId).thenReturn('@remote:server');
      when(() => newer.type).thenReturn('m.room.message');
      when(() => newer.messageType).thenReturn(syncMessageType);
      when(() => newer.attachmentMimetype).thenReturn('');

      var calls = 0;
      when(() => timeline.events).thenAnswer((_) {
        calls++;
        // First computation sees only the existing event (at tail),
        // subsequent re-eval sees the new event appended.
        return calls == 1 ? <Event>[existing] : <Event>[existing, newer];
      });

      final drainer = TimelineDrainer(
        listener: context,
        journalDb: MockJournalDb(),
        loggingService: loggingService,
        readMarkerService: MockSyncReadMarkerService(),
        eventProcessor: MockSyncEventProcessor(),
        documentsDirectory: Directory.systemTemp,
        failureCounts: <String, int>{},
        config: const TimelineConfig(
          retryDelays: <Duration>[Duration(milliseconds: 1)],
        ),
        metrics: null,
      );

      final selected = await drainer.computeFromTimeline(
        tl: timeline,
        source: 'live',
        pass: 0,
        roomId: '!room:server',
        usedLimit: 0,
        lastReadEventContextId: r'$existing',
      );

      expect(selected.map((e) => e.eventId), [r'$new']);
      expect(calls, greaterThanOrEqualTo(2));
    });
  });

  group('TimelineDrainer.drain', () {
    test('processes and advances read marker in minimal success path',
        () async {
      final loggingService = MockLoggingService();
      final roomManager = MockSyncRoomManager();
      final client = MockClient();
      final timeline = MockTimeline();
      final room = MockRoom();
      final readMarkerService = MockSyncReadMarkerService();
      final eventProcessor = MockSyncEventProcessor();
      final journalDb = MockJournalDb();
      final tempDir = Directory.systemTemp.createTempSync('timeline_drainer');

      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

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
      when(() => client.sync())
          .thenAnswer((_) async => SyncUpdate(nextBatch: 'token'));

      final context = TestTimelineContext(
        loggingService: loggingService,
        roomManager: roomManager,
        client: client,
      )
        ..lastReadEventContextId = r'$existing'
        ..timeline = timeline;

      final existing = MockEvent();
      when(() => existing.eventId).thenReturn(r'$existing');
      when(() => existing.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      when(() => existing.senderId).thenReturn('@remote:server');
      when(() => existing.type).thenReturn('m.room.message');
      when(() => existing.messageType).thenReturn(syncMessageType);
      when(() => existing.attachmentMimetype).thenReturn('');

      final newer = MockEvent();
      when(() => newer.eventId).thenReturn(r'$new');
      when(() => newer.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(2));
      when(() => newer.senderId).thenReturn('@remote:server');
      when(() => newer.type).thenReturn('m.room.message');
      when(() => newer.messageType).thenReturn(syncMessageType);
      when(() => newer.attachmentMimetype).thenReturn('');

      when(() => timeline.events).thenReturn(<Event>[existing, newer]);

      when(
        () => eventProcessor.process(
          event: any<Event>(named: 'event'),
          journalDb: any<JournalDb>(named: 'journalDb'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => readMarkerService.updateReadMarker(
          client: any<Client>(named: 'client'),
          room: any<Room>(named: 'room'),
          eventId: any<String>(named: 'eventId'),
          timeline: any<Timeline>(named: 'timeline'),
        ),
      ).thenAnswer((_) async {});

      final drainer = TimelineDrainer(
        listener: context,
        journalDb: journalDb,
        loggingService: loggingService,
        readMarkerService: readMarkerService,
        eventProcessor: eventProcessor,
        documentsDirectory: tempDir,
        failureCounts: <String, int>{},
        config: const TimelineConfig(
          maxDrainPasses: 1,
          retryDelays: <Duration>[],
        ),
        metrics: null,
      );

      await drainer.drain();

      verify(
        () => readMarkerService.updateReadMarker(
          client: client,
          room: room,
          eventId: r'$new',
          timeline: timeline,
        ),
      ).called(1);
    });
  });
}
