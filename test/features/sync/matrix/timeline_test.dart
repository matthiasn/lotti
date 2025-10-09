import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/matrix/timeline.dart';
import 'package:lotti/features/sync/matrix/timeline_context.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

class MockTimeline extends Mock implements Timeline {}

class MockLoggingService extends Mock implements LoggingService {}

class MockJournalDb extends Mock implements JournalDb {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockSyncReadMarkerService extends Mock implements SyncReadMarkerService {}

class MockSyncEventProcessor extends Mock implements SyncEventProcessor {}

class MockSyncRoomManager extends Mock implements SyncRoomManager {}

class FakeMatrixEvent extends Fake implements Event {}

class FakeJournalDb extends Fake implements JournalDb {}

class TestTimelineContext implements TimelineContext {
  TestTimelineContext({
    required this.client,
    required this.roomManager,
    required this.loggingService,
  });

  @override
  final Client client;

  @override
  final SyncRoomManager roomManager;

  @override
  final LoggingService loggingService;

  @override
  Timeline? timeline;

  @override
  String? lastReadEventContextId;

  bool refreshRequested = false;

  @override
  void enqueueTimelineRefresh() {
    refreshRequested = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const connectivityMethodChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(FakeMatrixEvent());
    registerFallbackValue(FakeJournalDb());

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityMethodChannel,
            (MethodCall call) async {
      if (call.method == 'check') {
        return 'wifi';
      }
      return 'wifi';
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      'dev.fluttercommunity.plus/connectivity_status',
      (ByteData? message) async => null,
    );
  });

  late MockClient mockClient;
  late MockRoom mockRoom;
  late MockTimeline mockTimeline;
  late MockLoggingService mockLoggingService;
  late MockSyncRoomManager mockRoomManager;
  late TestTimelineContext context;
  late MockJournalDb mockJournalDb;
  late MockSettingsDb mockSettingsDb;
  late MockSyncReadMarkerService mockReadMarkerService;
  late MockSyncEventProcessor mockEventProcessor;
  late Directory tempDir;
  late Map<String, int> failureCounts;

  setUp(() {
    mockClient = MockClient();
    mockRoom = MockRoom();
    mockTimeline = MockTimeline();
    mockLoggingService = MockLoggingService();
    mockRoomManager = MockSyncRoomManager();
    mockJournalDb = MockJournalDb();
    mockSettingsDb = MockSettingsDb();
    mockReadMarkerService = MockSyncReadMarkerService();
    mockEventProcessor = MockSyncEventProcessor();
    tempDir = Directory.systemTemp.createTempSync('timeline_test');
    failureCounts = <String, int>{};

    when(() => mockClient.isLogged()).thenReturn(true);
    when(() => mockClient.userID).thenReturn('@user:server');
    when(() => mockClient.deviceName).thenReturn('device');
    when(() => mockClient.sync())
        .thenAnswer((_) async => SyncUpdate(nextBatch: 'token'));
    when(() => mockTimeline.events).thenReturn(const []);

    getIt
      ..reset()
      ..allowReassignment = true
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<SettingsDb>(mockSettingsDb)
      ..registerSingleton<Directory>(tempDir);

    context = TestTimelineContext(
      client: mockClient,
      roomManager: mockRoomManager,
      loggingService: mockLoggingService,
    );
  });

  tearDown(() {
    getIt.reset();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('listenToTimelineEvents logs when syncRoom is null', () async {
    when(() => mockRoomManager.currentRoom).thenReturn(null);
    when(() => mockRoomManager.currentRoomId).thenReturn(null);

    await listenToTimelineEvents(listener: context);

    verify(
      () => mockLoggingService.captureEvent(
        contains('Cannot listen to timeline: syncRoom is null'),
        domain: 'MATRIX_SERVICE',
        subDomain: 'listenToTimelineEvents',
      ),
    ).called(1);
  });

  test('processNewTimelineEvents updates last read before marker call',
      () async {
    const eventId = r'$event';
    when(() => mockRoom.id).thenReturn('!room:server');
    final event = Event.fromJson(
      {
        'event_id': eventId,
        'sender': '@other:server',
        'room_id': '!room:server',
        'type': 'm.room.message',
        'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
        'content': {
          'body': 'hello',
          'msgtype': 'com.lotti.sync.message',
        },
      },
      mockRoom,
    );

    context.lastReadEventContextId = 'initial';

    when(() => mockRoomManager.currentRoom).thenReturn(mockRoom);
    when(() => mockRoomManager.currentRoomId).thenReturn('!room:server');
    when(() => mockRoom.getEventById(any())).thenAnswer((_) async => null);
    when(() =>
            mockRoom.getTimeline(eventContextId: any(named: 'eventContextId')))
        .thenAnswer((_) async => mockTimeline);
    when(() => mockTimeline.events).thenReturn([event]);
    when(() => mockTimeline.setReadMarker(eventId: any(named: 'eventId')))
        .thenAnswer((_) async {});

    when(
      () => mockEventProcessor.process(
        event: any<Event>(named: 'event'),
        journalDb: mockJournalDb,
      ),
    ).thenAnswer((_) async {});

    when(
      () => mockReadMarkerService.updateReadMarker(
        client: context.client,
        timeline: mockTimeline,
        eventId: eventId,
      ),
    ).thenAnswer((_) async {
      expect(context.lastReadEventContextId, eventId);
    });

    await processNewTimelineEvents(
      listener: context,
      journalDb: mockJournalDb,
      loggingService: mockLoggingService,
      readMarkerService: mockReadMarkerService,
      eventProcessor: mockEventProcessor,
      documentsDirectory: tempDir,
      failureCounts: failureCounts,
    );

    verify(
      () => mockReadMarkerService.updateReadMarker(
        client: context.client,
        timeline: mockTimeline,
        eventId: eventId,
      ),
    ).called(1);
  });

  test('processNewTimelineEvents skips processing events from self', () async {
    final mockRoom = MockRoom();
    final mockTimeline = MockTimeline();
    when(() => mockRoom.id).thenReturn('!room:server');
    final event = Event.fromJson(
      {
        'event_id': r'$selfEvent',
        'sender': '@user:server',
        'room_id': '!room:server',
        'type': 'm.room.message',
        'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
        'content': {
          'body': 'self message',
          'msgtype': 'com.lotti.sync.message',
        },
      },
      mockRoom,
    );

    when(() => mockRoomManager.currentRoom).thenReturn(mockRoom);
    context.lastReadEventContextId = null;
    when(() => mockClient.sync())
        .thenAnswer((_) async => SyncUpdate(nextBatch: 'token'));
    when(() => mockRoom.getEventById(any())).thenAnswer((_) async => null);
    when(() =>
            mockRoom.getTimeline(eventContextId: any(named: 'eventContextId')))
        .thenAnswer((_) async => mockTimeline);
    when(() => mockTimeline.events).thenReturn([event]);

    await processNewTimelineEvents(
      listener: context,
      journalDb: mockJournalDb,
      loggingService: mockLoggingService,
      readMarkerService: mockReadMarkerService,
      eventProcessor: mockEventProcessor,
      documentsDirectory: tempDir,
      failureCounts: failureCounts,
    );

    verifyNever(() => mockEventProcessor.process(
          event: any<Event>(named: 'event'),
          journalDb: any<JournalDb>(named: 'journalDb'),
        ));
  });

  test('processNewTimelineEvents logs when timeline unavailable', () async {
    when(() => mockRoomManager.currentRoom).thenReturn(null);
    when(() => mockClient.sync())
        .thenAnswer((_) async => SyncUpdate(nextBatch: 'token'));

    await processNewTimelineEvents(
      listener: context,
      journalDb: mockJournalDb,
      loggingService: mockLoggingService,
      readMarkerService: mockReadMarkerService,
      eventProcessor: mockEventProcessor,
      documentsDirectory: tempDir,
      failureCounts: failureCounts,
    );

    verify(
      () => mockLoggingService.captureEvent(
        'Timeline is null',
        domain: 'MATRIX_SERVICE',
        subDomain: 'processNewTimelineEvents',
      ),
    ).called(1);
  });
}
