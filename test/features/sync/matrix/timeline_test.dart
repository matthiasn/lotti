import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/timeline.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixClient extends Mock implements Client {}

class MockJournalDb extends Mock implements JournalDb {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockLoggingService extends Mock implements LoggingService {}

class TestMatrixService extends MatrixService {
  TestMatrixService({
    required super.client,
    JournalDb? journalDb,
    SettingsDb? settingsDb,
  }) : super(
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
  });

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
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<SettingsDb>(mockSettingsDb)
      ..registerSingleton<Directory>(Directory.systemTemp);

    when(() => mockSettingsDb.itemByKey(any<String>()))
        .thenAnswer((_) async => null);

    service = TestMatrixService(
      client: mockClient,
      journalDb: mockJournalDb,
      settingsDb: mockSettingsDb,
    );
  });

  tearDown(getIt.reset);

  test('listenToTimelineEvents logs when timeline is null', () async {
    service.syncRoom = null;

    await listenToTimelineEvents(service: service);

    verify(
      () => mockLoggingService.captureEvent(
        'Timeline is null',
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
}
