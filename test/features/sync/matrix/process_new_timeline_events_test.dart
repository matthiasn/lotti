import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/matrix/timeline.dart';
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

class MockMatrixFile extends Mock implements MatrixFile {}

class FakeClient extends Fake implements Client {}

class FakeTimeline extends Fake implements Timeline {}

class FakeEvent extends Fake implements Event {}

class FakeJournalDb extends Fake implements JournalDb {}

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
  void enqueueTimelineRefresh() {}
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeClient());
    registerFallbackValue(FakeTimeline());
    registerFallbackValue(FakeEvent());
    registerFallbackValue(FakeJournalDb());
  });

  group('processNewTimelineEvents', () {
    late TestTimelineContext context;
    late MockLoggingService loggingService;
    late MockSyncRoomManager roomManager;
    late MockRoom room;
    late MockClient client;
    late MockTimeline timeline;
    late MockSyncReadMarkerService readMarkerService;
    late MockSyncEventProcessor eventProcessor;
    late MockJournalDb journalDb;
    late Directory tempDir;

    setUp(() {
      loggingService = MockLoggingService();
      roomManager = MockSyncRoomManager();
      room = MockRoom();
      client = MockClient();
      timeline = MockTimeline();
      readMarkerService = MockSyncReadMarkerService();
      eventProcessor = MockSyncEventProcessor();
      journalDb = MockJournalDb();
      tempDir = Directory.systemTemp.createTempSync('process_new_timeline');

      context = TestTimelineContext(
        loggingService: loggingService,
        roomManager: roomManager,
        client: client,
      );

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
      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => client.sync())
          .thenAnswer((_) async => SyncUpdate(nextBatch: 'token'));
      when(() => client.userID).thenReturn('@local:server');
      when(() => client.deviceName).thenReturn('device');
      when(
        () => readMarkerService.updateReadMarker(
          client: any<Client>(named: 'client'),
          timeline: any<Timeline>(named: 'timeline'),
          eventId: any<String>(named: 'eventId'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => eventProcessor.process(
          event: any<Event>(named: 'event'),
          journalDb: any<JournalDb>(named: 'journalDb'),
        ),
      ).thenAnswer((_) async {});
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('does not query when lastReadEventContextId is null', () async {
      context
        ..lastReadEventContextId = null
        ..timeline = null;

      when(() => timeline.events).thenReturn(<Event>[]);
      when(() => room.getTimeline(
              eventContextId: any<String?>(named: 'eventContextId')))
          .thenAnswer((invocation) async {
        expect(invocation.namedArguments[#eventContextId], isNull);
        return timeline;
      });

      await processNewTimelineEvents(
        listener: context,
        journalDb: journalDb,
        loggingService: loggingService,
        readMarkerService: readMarkerService,
        eventProcessor: eventProcessor,
        documentsDirectory: tempDir,
      );

      verifyNever(() => room.getEventById(any<String>()));
      verify(() => room.getTimeline()).called(1);
      verifyNever(() => readMarkerService.updateReadMarker(
            client: any<Client>(named: 'client'),
            timeline: any<Timeline>(named: 'timeline'),
            eventId: any<String>(named: 'eventId'),
          ));
      expect(context.lastReadEventContextId, isNull);
    });

    test('requests context timeline when previous event exists', () async {
      context
        ..lastReadEventContextId = r'$existing'
        ..timeline = null;

      final existingEvent = MockEvent();
      when(() => existingEvent.eventId).thenReturn(r'$existing');
      when(() => timeline.events)
          .thenReturn(<Event>[MockEvent(), existingEvent]);

      when(() => room.getEventById(r'$existing'))
          .thenAnswer((_) async => existingEvent);
      when(() => room.getTimeline(
              eventContextId: any<String?>(named: 'eventContextId')))
          .thenAnswer((invocation) async {
        expect(invocation.namedArguments[#eventContextId], r'$existing');
        return timeline;
      });

      final newEvent = MockEvent();
      when(() => newEvent.eventId).thenReturn(r'$new');
      when(() => newEvent.senderId).thenReturn('@remote:server');
      when(() => newEvent.messageType).thenReturn(syncMessageType);
      when(() => newEvent.attachmentMimetype).thenReturn('');
      when(() => newEvent.type).thenReturn('m.room.message');
      when(() => timeline.events).thenReturn(<Event>[newEvent, existingEvent]);

      await processNewTimelineEvents(
        listener: context,
        journalDb: journalDb,
        loggingService: loggingService,
        readMarkerService: readMarkerService,
        eventProcessor: eventProcessor,
        documentsDirectory: tempDir,
      );

      verify(() => room.getEventById(r'$existing')).called(1);
      verify(() => room.getTimeline(eventContextId: r'$existing')).called(1);
      expect(context.lastReadEventContextId, r'$existing');
    });

    test('falls back to null context when previous event missing', () async {
      context
        ..lastReadEventContextId = r'$missing'
        ..timeline = null;

      when(() => room.getEventById(r'$missing')).thenAnswer((_) async => null);
      when(() => timeline.events).thenReturn(<Event>[]);
      when(() => room.getTimeline(
              eventContextId: any<String?>(named: 'eventContextId')))
          .thenAnswer((invocation) async {
        expect(invocation.namedArguments[#eventContextId], isNull);
        return timeline;
      });

      await processNewTimelineEvents(
        listener: context,
        journalDb: journalDb,
        loggingService: loggingService,
        readMarkerService: readMarkerService,
        eventProcessor: eventProcessor,
        documentsDirectory: tempDir,
      );

      verify(() => room.getEventById(r'$missing')).called(1);
      verify(() => room.getTimeline()).called(1);
    });

    test('logs and recovers when event processing throws', () async {
      final room = MockRoom();
      final timeline = MockTimeline();
      final event = MockEvent();
      const eventId = r'$remote';

      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => room.id).thenReturn('!room:server');
      when(() => client.sync())
          .thenAnswer((_) async => SyncUpdate(nextBatch: 'token'));
      when(() => room.getTimeline(eventContextId: any(named: 'eventContextId')))
          .thenAnswer((_) async => timeline);
      when(() => timeline.events).thenReturn([event]);
      when(() => event.eventId).thenReturn(eventId);
      when(() => event.senderId).thenReturn('@remote:server');
      when(() => event.messageType).thenReturn(syncMessageType);
      when(() => event.attachmentMimetype).thenReturn('');
      when(() => event.type).thenReturn('m.room.message');
      when(
        () => eventProcessor.process(
          event: any<Event>(named: 'event'),
          journalDb: any<JournalDb>(named: 'journalDb'),
        ),
      ).thenThrow(Exception('failed to process'));
      when(
        () => readMarkerService.updateReadMarker(
          client: any<Client>(named: 'client'),
          timeline: any<Timeline>(named: 'timeline'),
          eventId: any<String>(named: 'eventId'),
        ),
      ).thenAnswer((_) async {});

      await processNewTimelineEvents(
        listener: context,
        journalDb: journalDb,
        loggingService: loggingService,
        readMarkerService: readMarkerService,
        eventProcessor: eventProcessor,
        documentsDirectory: tempDir,
      );

      verify(
        () => loggingService.captureException(
          any<dynamic>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'processNewTimelineEvents.handler',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
      verifyNever(
        () => readMarkerService.updateReadMarker(
          client: any<Client>(named: 'client'),
          timeline: any<Timeline>(named: 'timeline'),
          eventId: any<String>(named: 'eventId'),
        ),
      );
    });

    test(
        'does not advance read marker when event handling throws FileSystemException',
        () async {
      final room = MockRoom();
      final timeline = MockTimeline();
      final event = MockEvent();
      final matrixFile = MockMatrixFile();
      const eventId = r'$fsError';

      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => room.id).thenReturn('!room:server');
      when(() => client.sync())
          .thenAnswer((_) async => SyncUpdate(nextBatch: 'token'));
      when(() => room.getTimeline(eventContextId: any(named: 'eventContextId')))
          .thenAnswer((_) async => timeline);
      when(() => timeline.events).thenReturn([event]);
      when(() => event.eventId).thenReturn(eventId);
      when(() => event.senderId).thenReturn('@remote:server');
      when(() => event.type).thenReturn('m.room.message');
      when(() => event.messageType).thenReturn(syncMessageType);
      when(() => event.attachmentMimetype).thenReturn('image/png');
      when(() => event.content)
          .thenReturn({'relativePath': '/matrix/attachment.bin'});
      when(event.downloadAndDecryptAttachment)
          .thenAnswer((_) async => matrixFile);
      when(() => matrixFile.bytes).thenReturn(Uint8List.fromList([1, 2, 3]));

      when(
        () => eventProcessor.process(
          event: any<Event>(named: 'event'),
          journalDb: any<JournalDb>(named: 'journalDb'),
        ),
      ).thenThrow(const FileSystemException('attachment missing'));
      when(
        () => readMarkerService.updateReadMarker(
          client: any<Client>(named: 'client'),
          timeline: any<Timeline>(named: 'timeline'),
          eventId: any<String>(named: 'eventId'),
        ),
      ).thenAnswer((_) async {});

      await processNewTimelineEvents(
        listener: context,
        journalDb: journalDb,
        loggingService: loggingService,
        readMarkerService: readMarkerService,
        eventProcessor: eventProcessor,
        documentsDirectory: tempDir,
      );

      verify(
        () => loggingService.captureException(
          any<dynamic>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'processNewTimelineEvents.missingAttachment',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
      verifyNever(
        () => readMarkerService.updateReadMarker(
          client: any<Client>(named: 'client'),
          timeline: any<Timeline>(named: 'timeline'),
          eventId: eventId,
        ),
      );
    });
  });
}
