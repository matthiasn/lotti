import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/timeline.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/matrix/fake_matrix_gateway.dart';

class MockMatrixClient extends Mock implements Client {}

class MockJournalDb extends Mock implements JournalDb {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockLoggingService extends Mock implements LoggingService {}

class MockRoom extends Mock implements Room {}

class MockTimeline extends Mock implements Timeline {}

class TestMatrixService extends MatrixService {
  TestMatrixService({
    required Client client,
    MatrixSyncGateway? gateway,
    JournalDb? journalDb,
    SettingsDb? settingsDb,
  }) : super(
          gateway: gateway ?? FakeMatrixGateway(client: client),
          overriddenJournalDb: journalDb,
          overriddenSettingsDb: settingsDb,
        );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const connectivityMethodChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
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

  late MockMatrixClient mockClient;
  late MockJournalDb mockJournalDb;
  late MockSettingsDb mockSettingsDb;
  late MockLoggingService mockLoggingService;
  late TestMatrixService service;

  setUp(() {
    mockClient = MockMatrixClient();
    mockJournalDb = MockJournalDb();
    mockSettingsDb = MockSettingsDb();
    mockLoggingService = MockLoggingService();

    when(() => mockClient.isLogged()).thenReturn(true);
    when(() => mockClient.userID).thenReturn('@user:server');
    when(() => mockClient.deviceName).thenReturn('device');
    when(() => mockClient.sync())
        .thenAnswer((_) async => SyncUpdate(nextBatch: 'token'));

    getIt
      ..reset()
      ..allowReassignment = true
      ..registerSingleton<UserActivityService>(UserActivityService())
      ..registerSingleton<UserActivityGate>(
        UserActivityGate(
          activityService: getIt<UserActivityService>(),
          idleThreshold: Duration.zero,
        ),
      )
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<SettingsDb>(mockSettingsDb)
      ..registerSingleton<Directory>(Directory.systemTemp);

    when(() => mockSettingsDb.itemByKey(any<String>()))
        .thenAnswer((_) async => null);
    when(
      () => mockLoggingService.captureEvent(
        any<String>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) {});

    service = TestMatrixService(
      client: mockClient,
      journalDb: mockJournalDb,
      settingsDb: mockSettingsDb,
    );
  });

  tearDown(getIt.reset);

  test('listenToTimelineEvents logs when syncRoom is null', () async {
    service.syncRoom = null;

    await listenToTimelineEvents(service: service);

    verify(
      () => mockLoggingService.captureEvent(
        contains('Cannot listen to timeline: syncRoom is null'),
        domain: 'MATRIX_SERVICE',
        subDomain: 'listenToTimelineEvents',
      ),
    ).called(1);
  });

  test('processNewTimelineEvents logs when fetched timeline is null', () async {
    service
      ..syncRoom = null
      ..lastReadEventContextId = 'event-id';

    await processNewTimelineEvents(service: service);

    verify(
      () => mockLoggingService.captureEvent(
        'Timeline is null',
        domain: 'MATRIX_SERVICE',
        subDomain: 'processNewTimelineEvents',
      ),
    ).called(1);
  });

  test('processNewTimelineEvents logs event processing details', () async {
    final mockRoom = MockRoom();
    final mockTimeline = MockTimeline();
    when(() => mockRoom.id).thenReturn('!room:server');

    final event = Event.fromJson(
      {
        'event_id': 'event',
        'sender': '@other:server',
        'room_id': '!room:server',
        'type': 'm.room.message',
        'origin_server_ts': DateTime.now().millisecondsSinceEpoch,
        'content': {
          'body': 'hi',
          'msgtype': 'm.text',
        },
      },
      mockRoom,
    );

    service
      ..syncRoom = mockRoom
      ..syncRoomId = '!room:server'
      ..lastReadEventContextId = 'start';

    when(() => mockRoom.getEventById(any())).thenAnswer((_) async => null);
    when(() =>
            mockRoom.getTimeline(eventContextId: any(named: 'eventContextId')))
        .thenAnswer((_) async => mockTimeline);
    when(() => mockTimeline.events).thenReturn([event]);
    when(() => mockTimeline.setReadMarker(eventId: any(named: 'eventId')))
        .thenAnswer((_) async {});

    await processNewTimelineEvents(service: service);

    verify(
      () => mockLoggingService.captureEvent(
        contains('Processing timeline events'),
        domain: 'MATRIX_SERVICE',
        subDomain: 'processNewTimelineEvents',
      ),
    ).called(1);
    verify(
      () => mockLoggingService.captureEvent(
        contains('Received message from @other:server'),
        domain: 'MATRIX_SERVICE',
        subDomain: 'processNewTimelineEvents',
      ),
    ).called(1);
  });
}
