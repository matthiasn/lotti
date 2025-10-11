// ignore_for_file: unnecessary_lambdas

import 'dart:convert';
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
    late Map<String, int> failureCounts;

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
      failureCounts = <String, int>{};

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
      when(() => client.isLogged()).thenReturn(true);
      when(() => client.userID).thenReturn('@local:server');
      when(() => client.deviceName).thenReturn('device');
      when(() => client.deviceName).thenReturn('device');
      when(
        () => readMarkerService.updateReadMarker(
          client: any<Client>(named: 'client'),
          room: any<Room>(named: 'room'),
          eventId: any<String>(named: 'eventId'),
          timeline: any<Timeline>(named: 'timeline'),
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
      when(
        () => room.getTimeline(
          eventContextId: any<String?>(named: 'eventContextId'),
          onChange: any(named: 'onChange'),
          onInsert: any(named: 'onInsert'),
          onRemove: any(named: 'onRemove'),
          onNewEvent: any(named: 'onNewEvent'),
          onUpdate: any(named: 'onUpdate'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((invocation) async {
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
        failureCounts: failureCounts,
      );

      verifyNever(() => room.getEventById(any<String>()));
      verifyNever(() => readMarkerService.updateReadMarker(
            client: any<Client>(named: 'client'),
            room: any<Room>(named: 'room'),
            eventId: any<String>(named: 'eventId'),
            timeline: any<Timeline>(named: 'timeline'),
          ));
      expect(context.lastReadEventContextId, isNull);
    });

    test('requests context timeline when previous event exists', () async {
      context
        ..lastReadEventContextId = r'$existing'
        ..timeline = null;

      final existingEvent = MockEvent();
      when(() => existingEvent.eventId).thenReturn(r'$existing');

      final newEvent = MockEvent();
      when(() => newEvent.eventId).thenReturn(r'$new');
      when(() => newEvent.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(2));
      when(() => newEvent.senderId).thenReturn('@remote:server');
      when(() => newEvent.messageType).thenReturn(syncMessageType);
      when(() => newEvent.attachmentMimetype).thenReturn('');
      when(() => newEvent.type).thenReturn('m.room.message');
      when(() => existingEvent.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      when(() => timeline.events).thenReturn(<Event>[existingEvent, newEvent]);
      when(() => room.id).thenReturn('!room:server');
      when(
        () => room.getTimeline(
          eventContextId: any<String?>(named: 'eventContextId'),
          onChange: any(named: 'onChange'),
          onInsert: any(named: 'onInsert'),
          onRemove: any(named: 'onRemove'),
          onNewEvent: any(named: 'onNewEvent'),
          onUpdate: any(named: 'onUpdate'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => timeline);

      await processNewTimelineEvents(
        listener: context,
        journalDb: journalDb,
        loggingService: loggingService,
        readMarkerService: readMarkerService,
        eventProcessor: eventProcessor,
        documentsDirectory: tempDir,
        failureCounts: failureCounts,
      );

      verifyNever(() => room.getEventById(any<String>()));
      final captured = verify(
        () => readMarkerService.updateReadMarker(
          client: client,
          room: room,
          eventId: captureAny<String>(named: 'eventId'),
          timeline: timeline,
        ),
      ).captured;
      expect(captured, hasLength(1));
      expect(captured.single, r'$new');
      expect(context.lastReadEventContextId, captured.single);
      verify(
        () => loggingService.captureEvent(
          'Processing 1 timeline events for room !room:server',
          domain: 'MATRIX_SERVICE',
          subDomain: 'processNewTimelineEvents',
        ),
      ).called(1);
      verify(
        () => eventProcessor.process(
          event: newEvent,
          journalDb: journalDb,
        ),
      ).called(1);
    });

    test('processes events sharing a timestamp regardless of eventId order',
        () async {
      context
        ..lastReadEventContextId = r'$existing'
        ..timeline = null;

      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => room.id).thenReturn('!room:server');
      when(() => client.sync())
          .thenAnswer((_) async => SyncUpdate(nextBatch: 'token'));

      final existingEvent = MockEvent();
      final newEvent = MockEvent();

      final timestamp = DateTime.fromMillisecondsSinceEpoch(42);
      when(() => existingEvent.eventId).thenReturn(r'$existing');
      when(() => existingEvent.originServerTs).thenReturn(timestamp);
      when(() => existingEvent.senderId).thenReturn('@remote:server');
      when(() => existingEvent.type).thenReturn('m.room.message');
      when(() => existingEvent.messageType).thenReturn(syncMessageType);
      when(() => existingEvent.attachmentMimetype).thenReturn('');

      when(() => newEvent.eventId).thenReturn(r'$earlierLex');
      when(() => newEvent.originServerTs).thenReturn(timestamp);
      when(() => newEvent.senderId).thenReturn('@remote:server');
      when(() => newEvent.type).thenReturn('m.room.message');
      when(() => newEvent.messageType).thenReturn(syncMessageType);
      when(() => newEvent.attachmentMimetype).thenReturn('');

      when(() => timeline.events).thenReturn(<Event>[newEvent, existingEvent]);
      when(
        () => room.getTimeline(
          eventContextId: any<String?>(named: 'eventContextId'),
          onChange: any(named: 'onChange'),
          onInsert: any(named: 'onInsert'),
          onRemove: any(named: 'onRemove'),
          onNewEvent: any(named: 'onNewEvent'),
          onUpdate: any(named: 'onUpdate'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => timeline);

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

      await processNewTimelineEvents(
        listener: context,
        journalDb: journalDb,
        loggingService: loggingService,
        readMarkerService: readMarkerService,
        eventProcessor: eventProcessor,
        documentsDirectory: tempDir,
        failureCounts: failureCounts,
      );

      verify(
        () => eventProcessor.process(
          event: newEvent,
          journalDb: journalDb,
        ),
      ).called(1);
      verify(
        () => readMarkerService.updateReadMarker(
          client: client,
          room: room,
          eventId: r'$earlierLex',
          timeline: timeline,
        ),
      ).called(1);
      expect(context.lastReadEventContextId, r'$earlierLex');
    });

    test('falls back to null context when previous event missing', () async {
      context
        ..lastReadEventContextId = r'$missing'
        ..timeline = null;

      when(() => room.getEventById(r'$missing')).thenAnswer((_) async => null);
      when(() => timeline.events).thenReturn(<Event>[]);
      when(
        () => room.getTimeline(
          eventContextId: any<String?>(named: 'eventContextId'),
          onChange: any(named: 'onChange'),
          onInsert: any(named: 'onInsert'),
          onRemove: any(named: 'onRemove'),
          onNewEvent: any(named: 'onNewEvent'),
          onUpdate: any(named: 'onUpdate'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((invocation) async {
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
        failureCounts: failureCounts,
      );

      verifyNever(() => room.getEventById(any<String>()));
    });

    test(
        'processes sync event after attachments saved even when text precedes file',
        () async {
      context
        ..lastReadEventContextId = null
        ..timeline = null;

      final textEvent = MockEvent();
      final fileEvent = MockEvent();
      final bytes = Uint8List.fromList(utf8.encode('{}'));

      when(
        () => room.getTimeline(
          eventContextId: any<String?>(named: 'eventContextId'),
          onChange: any(named: 'onChange'),
          onInsert: any(named: 'onInsert'),
          onRemove: any(named: 'onRemove'),
          onNewEvent: any(named: 'onNewEvent'),
          onUpdate: any(named: 'onUpdate'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => timeline);
      when(() => room.id).thenReturn('!room:server');
      when(() => timeline.events).thenReturn(<Event>[textEvent, fileEvent]);

      when(() => textEvent.eventId).thenReturn(r'$text');
      when(() => textEvent.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      when(() => textEvent.senderId).thenReturn('@remote:server');
      when(() => textEvent.messageType).thenReturn(syncMessageType);
      when(() => textEvent.attachmentMimetype).thenReturn('');
      when(() => textEvent.type).thenReturn('m.room.message');

      when(() => fileEvent.eventId).thenReturn(r'$file');
      when(() => fileEvent.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(2));
      when(() => fileEvent.senderId).thenReturn('@remote:server');
      when(() => fileEvent.messageType).thenReturn('m.room.message');
      when(() => fileEvent.attachmentMimetype).thenReturn('application/json');
      when(() => fileEvent.type).thenReturn('m.room.message');
      Map<String, dynamic> contentBuilder(Invocation _) =>
          {'relativePath': '/matrix/file.json'};
      when(() => fileEvent.content).thenAnswer(
        contentBuilder,
      );
      when(() => fileEvent.downloadAndDecryptAttachment()).thenAnswer(
        (_) async => MatrixFile(
          bytes: bytes,
          name: 'file.json',
        ),
      );

      final processedEvents = <Event>[];
      when(
        () => eventProcessor.process(
          event: any<Event>(named: 'event'),
          journalDb: any<JournalDb>(named: 'journalDb'),
        ),
      ).thenAnswer((invocation) async {
        final event =
            invocation.namedArguments[#event] as Event? ?? FakeEvent();
        processedEvents.add(event);
        final file = File('${tempDir.path}/matrix/file.json');
        expect(file.existsSync(), isTrue);
      });

      await processNewTimelineEvents(
        listener: context,
        journalDb: journalDb,
        loggingService: loggingService,
        readMarkerService: readMarkerService,
        eventProcessor: eventProcessor,
        documentsDirectory: tempDir,
        failureCounts: failureCounts,
      );

      expect(processedEvents, contains(textEvent));
      expect(failureCounts, isEmpty);
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
      when(() => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);
      when(() => timeline.events).thenReturn([event]);
      when(() => event.eventId).thenReturn(eventId);
      when(() => event.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
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
          room: any<Room>(named: 'room'),
          eventId: any<String>(named: 'eventId'),
          timeline: any<Timeline>(named: 'timeline'),
        ),
      ).thenAnswer((_) async {});

      await processNewTimelineEvents(
        listener: context,
        journalDb: journalDb,
        loggingService: loggingService,
        readMarkerService: readMarkerService,
        eventProcessor: eventProcessor,
        documentsDirectory: tempDir,
        failureCounts: failureCounts,
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
          room: any<Room>(named: 'room'),
          eventId: any<String>(named: 'eventId'),
          timeline: any<Timeline>(named: 'timeline'),
        ),
      );
      expect(failureCounts[eventId], 1);
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
      when(() => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);
      when(() => timeline.events).thenReturn([event]);
      when(() => event.eventId).thenReturn(eventId);
      when(() => event.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
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
          room: any<Room>(named: 'room'),
          eventId: any<String>(named: 'eventId'),
          timeline: any<Timeline>(named: 'timeline'),
        ),
      ).thenAnswer((_) async {});

      await processNewTimelineEvents(
        listener: context,
        journalDb: journalDb,
        loggingService: loggingService,
        readMarkerService: readMarkerService,
        eventProcessor: eventProcessor,
        documentsDirectory: tempDir,
        failureCounts: failureCounts,
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
          room: any<Room>(named: 'room'),
          eventId: eventId,
          timeline: any<Timeline>(named: 'timeline'),
        ),
      );
      expect(failureCounts[eventId], 1);
    });

    test('advances read marker after exceeding retry limit', () async {
      final room = MockRoom();
      final timeline = MockTimeline();
      final event = MockEvent();
      const eventId = r'$skip';

      when(() => roomManager.currentRoom).thenReturn(room);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => room.id).thenReturn('!room:server');
      when(() => client.sync())
          .thenAnswer((_) async => SyncUpdate(nextBatch: 'token'));
      when(() => room.getTimeline(
            eventContextId: any(named: 'eventContextId'),
            limit: any(named: 'limit')))
          .thenAnswer((_) async => timeline);
      when(() => timeline.events).thenReturn([event]);
      when(() => event.eventId).thenReturn(eventId);
      when(() => event.originServerTs)
          .thenReturn(DateTime.fromMillisecondsSinceEpoch(1));
      when(() => event.senderId).thenReturn('@remote:server');
      when(() => event.type).thenReturn('m.room.message');
      when(() => event.messageType).thenReturn(syncMessageType);
      when(() => event.attachmentMimetype).thenReturn('application/json');
      when(() => event.content)
          .thenReturn({'relativePath': '/matrix/missing.json'});
      final matrixFile = MockMatrixFile();
      when(event.downloadAndDecryptAttachment)
          .thenAnswer((_) async => matrixFile);
      when(() => matrixFile.bytes).thenReturn(Uint8List.fromList([1, 2, 3]));
      when(
        () => eventProcessor.process(
          event: any<Event>(named: 'event'),
          journalDb: any<JournalDb>(named: 'journalDb'),
        ),
      ).thenThrow(const FileSystemException('missing attachment'));

      for (var attempt = 0; attempt < 5; attempt++) {
        await processNewTimelineEvents(
          listener: context,
          journalDb: journalDb,
          loggingService: loggingService,
          readMarkerService: readMarkerService,
          eventProcessor: eventProcessor,
          documentsDirectory: tempDir,
          failureCounts: failureCounts,
        );
      }

      verify(
        () => readMarkerService.updateReadMarker(
          client: any<Client>(named: 'client'),
          room: any<Room>(named: 'room'),
          eventId: eventId,
          timeline: any<Timeline>(named: 'timeline'),
        ),
      ).called(1);
      expect(failureCounts[eventId], isNull);
      verify(
        () => loggingService.captureEvent(
          'Skipping event $eventId after 5 failed attempts (missing attachment)',
          domain: 'MATRIX_SERVICE',
          subDomain: 'processNewTimelineEvents.skip',
        ),
      ).called(1);
    });
  });
}
