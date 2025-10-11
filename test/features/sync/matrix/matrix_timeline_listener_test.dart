// ignore_for_file: unnecessary_lambdas

import 'dart:async';
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
import 'package:lotti/features/sync/matrix/timeline.dart'
    show listenToTimelineEvents;
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixSessionManager extends Mock implements MatrixSessionManager {}

class MockSyncRoomManager extends Mock implements SyncRoomManager {}

class MockLoggingService extends Mock implements LoggingService {}

class MockUserActivityGate extends Mock implements UserActivityGate {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockTimeline extends Mock implements Timeline {}

class MockRoom extends Mock implements Room {}

class MockClient extends Mock implements Client {}

class FakeMatrixClient extends Fake implements Client {}

class FakeTimeline extends Fake implements Timeline {}

class FakeRoom extends Fake implements Room {}

class MockJournalDb extends Mock implements JournalDb {}

class MockSyncReadMarkerService extends Mock implements SyncReadMarkerService {}

class MockSyncEventProcessor extends Mock implements SyncEventProcessor {}

class FakeMatrixEvent extends Fake implements Event {}
// Note: We avoid mocking CachedStreamController from matrix SDK directly to
// keep tests resilient across SDK changes.

void main() {
  setUpAll(() {
    registerFallbackValue(FakeMatrixClient());
    registerFallbackValue(FakeTimeline());
    registerFallbackValue(FakeMatrixEvent());
    registerFallbackValue(FakeRoom());
  });

  late MockMatrixSessionManager mockSessionManager;
  late MockSyncRoomManager mockRoomManager;
  late MockLoggingService mockLoggingService;
  late MockUserActivityGate mockActivityGate;
  late MockSettingsDb mockSettingsDb;
  late MatrixTimelineListener listener;
  late MockClient mockClient;
  late MockJournalDb mockJournalDb;
  late MockSyncReadMarkerService mockReadMarkerService;
  late MockSyncEventProcessor mockEventProcessor;
  late Directory tempDir;
  late StreamController<Event> timelineEventController;

  setUp(() {
    mockSessionManager = MockMatrixSessionManager();
    mockRoomManager = MockSyncRoomManager();
    mockLoggingService = MockLoggingService();
    mockActivityGate = MockUserActivityGate();
    mockSettingsDb = MockSettingsDb();
    mockJournalDb = MockJournalDb();
    mockReadMarkerService = MockSyncReadMarkerService();
    mockEventProcessor = MockSyncEventProcessor();
    tempDir = Directory.systemTemp.createTempSync('matrix_timeline_listener');
    timelineEventController = StreamController<Event>.broadcast();
    listener = MatrixTimelineListener(
      sessionManager: mockSessionManager,
      roomManager: mockRoomManager,
      loggingService: mockLoggingService,
      activityGate: mockActivityGate,
      journalDb: mockJournalDb,
      settingsDb: mockSettingsDb,
      readMarkerService: mockReadMarkerService,
      eventProcessor: mockEventProcessor,
      documentsDirectory: tempDir,
    );
    mockClient = MockClient();
    when(() => mockSessionManager.client).thenReturn(mockClient);
    when(() => mockClient.isLogged()).thenReturn(true);
    // Do not stub onTimelineEvent here; tests that call start() are adapted
    // to avoid relying on the underlying SDK controller type.
    when(() => mockActivityGate.waitUntilIdle()).thenAnswer((_) async {});
    when(() => mockLoggingService.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        )).thenReturn(null);
  });

  tearDown(() async {
    await timelineEventController.close();
    await getIt.reset();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('initialize loads last read event id from settings', () async {
    when(() => mockSettingsDb.itemByKey(lastReadMatrixEventId))
        .thenAnswer((_) async => r'$event');

    await listener.initialize();

    expect(listener.lastReadEventContextId, r'$event');
  });

  test('enqueueTimelineRefresh enqueues request on runner', () {
    expect(listener.clientRunner.enqueuedCount, 0);

    listener.enqueueTimelineRefresh();

    expect(listener.clientRunner.enqueuedCount, 1);
  });

  test('dispose cancels timeline subscriptions and closes runner', () async {
    final mockTimeline = MockTimeline();
    when(() => mockTimeline.cancelSubscriptions()).thenAnswer((_) async {});
    listener.timeline = mockTimeline;

    await listener.dispose();

    verify(() => mockTimeline.cancelSubscriptions()).called(1);
  });

  test('dispose flushes pending read marker if scheduled', () async {
    final mockTimeline = MockTimeline();
    final mockRoom = MockRoom();
    final mockClient = MockClient();

    when(() => mockRoomManager.currentRoom).thenReturn(mockRoom);
    when(() => mockClient.isLogged()).thenReturn(true);
    when(() => mockClient.userID).thenReturn('@local:server');
    when(() => mockClient.deviceName).thenReturn('Unit Test Device');
    when(() => mockSessionManager.client).thenReturn(mockClient);

    // Set a timeline to pass through to read marker service
    listener.timeline = mockTimeline;

    // Prepare the read marker call expectation (match exact args)
    when(() => mockReadMarkerService.updateReadMarker(
          client: mockClient,
          room: mockRoom,
          eventId: r'$evt',
          timeline: mockTimeline,
        )).thenAnswer((_) async {});

    // Simulate a pending marker
    listener.debugPendingMarker = r'$evt';

    await listener.dispose();

    verify(() => mockReadMarkerService.updateReadMarker(
          client: mockClient,
          room: mockRoom,
          eventId: r'$evt',
          timeline: mockTimeline,
        )).called(1);
  });

  test('client runner callback waits for idle and hydrates context', () async {
    when(() => mockRoomManager.currentRoom).thenReturn(null);
    when(() => mockClient.sync())
        .thenAnswer((_) async => SyncUpdate(nextBatch: 'token'));

    await listener.clientRunner.callback(null);

    verify(() => mockActivityGate.waitUntilIdle()).called(1);
  });

  test('enqueueTimelineRefresh waits for activity gate before processing',
      () async {
    final activityGateCompleter = Completer<void>();
    final mockRoom = MockRoom();

    when(() => mockActivityGate.waitUntilIdle()).thenAnswer((_) async {
      await activityGateCompleter.future;
    });
    when(() => mockRoomManager.currentRoom).thenReturn(mockRoom);
    when(() => mockRoomManager.currentRoomId).thenReturn('!room:server');
    when(() => mockClient.sync())
        .thenAnswer((_) async => SyncUpdate(nextBatch: 'token'));

    final mockTimeline = MockTimeline();
    when(
      () => mockRoom.getTimeline(
        eventContextId: any(named: 'eventContextId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => mockTimeline);
    when(() => mockRoom.getTimeline(limit: any(named: 'limit')))
        .thenAnswer((_) async => mockTimeline);
    when(() => mockTimeline.events).thenReturn(const []);

    listener.enqueueTimelineRefresh();

    await Future<void>.delayed(Duration.zero);

    verify(() => mockActivityGate.waitUntilIdle()).called(1);
    verifyNever(() => mockClient.sync());

    activityGateCompleter.complete();
    await Future<void>.delayed(Duration.zero);

    // Implementation may perform multiple quick retries; ensure at least one
    // sync occurs after activity gate releases.
    verify(() => mockClient.sync()).called(greaterThanOrEqualTo(1));
  });

  test('start logs when no room is available', () async {
    await getIt.reset();
    getIt.allowReassignment = true;
    getIt.registerSingleton<LoggingService>(mockLoggingService);
    when(() => mockRoomManager.currentRoom).thenReturn(null);

    // Call the lower-level listener to assert logging without touching
    // SDK-specific onTimelineEvent controller types.
    await listenToTimelineEvents(listener: listener);

    verify(
      () => mockLoggingService.captureEvent(
        contains('Cannot listen to timeline: syncRoom is null'),
        domain: 'MATRIX_SERVICE',
        subDomain: 'listenToTimelineEvents',
      ),
    ).called(1);
  });
}
