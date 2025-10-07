// ignore_for_file: unnecessary_lambdas

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

class MockClient extends Mock implements Client {}

class FakeMatrixClient extends Fake implements Client {}

class FakeTimeline extends Fake implements Timeline {}

class MockJournalDb extends Mock implements JournalDb {}

class MockSyncReadMarkerService extends Mock implements SyncReadMarkerService {}

class MockSyncEventProcessor extends Mock implements SyncEventProcessor {}

class FakeMatrixEvent extends Fake implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeMatrixClient());
    registerFallbackValue(FakeTimeline());
    registerFallbackValue(FakeMatrixEvent());
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

  setUp(() {
    mockSessionManager = MockMatrixSessionManager();
    mockRoomManager = MockSyncRoomManager();
    mockLoggingService = MockLoggingService();
    mockActivityGate = MockUserActivityGate();
    mockSettingsDb = MockSettingsDb();
    mockJournalDb = MockJournalDb();
    mockReadMarkerService = MockSyncReadMarkerService();
    mockEventProcessor = MockSyncEventProcessor();
    listener = MatrixTimelineListener(
      sessionManager: mockSessionManager,
      roomManager: mockRoomManager,
      loggingService: mockLoggingService,
      activityGate: mockActivityGate,
      overriddenJournalDb: mockJournalDb,
      overriddenSettingsDb: mockSettingsDb,
      readMarkerService: mockReadMarkerService,
      eventProcessor: mockEventProcessor,
    );
    mockClient = MockClient();
    when(() => mockSessionManager.client).thenReturn(mockClient);
    when(() => mockActivityGate.waitUntilIdle()).thenAnswer((_) async {});
    when(() => mockLoggingService.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        )).thenReturn(null);
  });

  tearDown(() async {
    await getIt.reset();
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

  test('client runner callback waits for idle and hydrates context', () async {
    when(() => mockRoomManager.currentRoom).thenReturn(null);
    when(() => mockClient.sync())
        .thenAnswer((_) async => SyncUpdate(nextBatch: 'token'));

    await listener.clientRunner.callback(null);

    verify(() => mockActivityGate.waitUntilIdle()).called(1);
  });

  test('start logs when no room is available', () async {
    await getIt.reset();
    getIt.allowReassignment = true;
    getIt.registerSingleton<LoggingService>(mockLoggingService);
    when(() => mockRoomManager.currentRoom).thenReturn(null);

    await listener.start();

    verify(
      () => mockLoggingService.captureEvent(
        contains('Cannot listen to timeline: syncRoom is null'),
        domain: 'MATRIX_SERVICE',
        subDomain: 'listenToTimelineEvents',
      ),
    ).called(1);
  });
}
