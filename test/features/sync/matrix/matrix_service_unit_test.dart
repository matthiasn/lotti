import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';

class MockMatrixClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockJournalDb extends Mock implements JournalDb {}

class MockLoggingService extends Mock implements LoggingService {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockDeviceKeys extends Mock implements DeviceKeys {}

class MockRoomSummary extends Mock implements RoomSummary {}

class MockTimeline extends Mock implements Timeline {}

class MockKeyVerificationRunner extends Mock implements KeyVerificationRunner {}

class TestMatrixService extends MatrixService {
  TestMatrixService({
    required super.client,
    super.matrixConfig,
    JournalDb? journalDb,
    SettingsDb? settingsDb,
  }) : super(
          overriddenJournalDb: journalDb,
          overriddenSettingsDb: settingsDb,
        );

  List<DeviceKeys> unverifiedDevices = const [];

  @override
  List<DeviceKeys> getUnverifiedDevices() => unverifiedDevices;
}

class StubMatrixService extends MatrixService {
  StubMatrixService({
    required super.client,
    JournalDb? journalDb,
    SettingsDb? settingsDb,
  }) : super(
          overriddenJournalDb: journalDb,
          overriddenSettingsDb: settingsDb,
        );

  int startKeyVerificationCount = 0;
  int listenToTimelineCount = 0;
  bool loadConfigCalled = false;
  bool connectCalled = false;

  @override
  Future<void> startKeyVerificationListener() async {
    startKeyVerificationCount++;
  }

  @override
  Future<void> listenToTimeline() async {
    listenToTimelineCount++;
  }

  @override
  Future<MatrixConfig?> loadConfig() async {
    loadConfigCalled = true;
    return matrixConfig;
  }

  @override
  Future<void> connect() async {
    connectCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const connectivityMethodChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');

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
  late MockSettingsDb mockSettingsDb;
  late MockJournalDb mockJournalDb;
  late MockLoggingService mockLoggingService;
  late MockUpdateNotifications mockUpdateNotifications;
  late TestMatrixService service;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(
      AuthenticationPassword(
        password: 'pw',
        identifier: AuthenticationUserIdentifier(user: '@user:server'),
      ),
    );
    registerFallbackValue(AuthenticationUserIdentifier(user: '@user:server'));
  });

  setUp(() {
    mockClient = MockMatrixClient();
    mockSettingsDb = MockSettingsDb();
    mockJournalDb = MockJournalDb();
    mockLoggingService = MockLoggingService();
    mockUpdateNotifications = MockUpdateNotifications();

    when(() => mockSettingsDb.itemByKey(any())).thenAnswer((_) async => null);
    when(() => mockJournalDb.watchConfigFlag(enableMatrixFlag)).thenAnswer(
      (_) => Stream<bool>.value(false),
    );
    when(() => mockClient.isLogged()).thenReturn(true);
    when(() => mockClient.userDeviceKeys).thenReturn({});
    when(() => mockClient.rooms).thenReturn(const []);
    when(() => mockClient.sync())
        .thenAnswer((_) async => SyncUpdate(nextBatch: 'token'));
    when(() => mockClient.userID).thenReturn('@user:server');
    when(() => mockClient.deviceID).thenReturn('device-id');
    when(() => mockClient.deviceName).thenReturn('device');

    getIt
      ..reset()
      ..allowReassignment = true
      ..registerSingleton<UserActivityService>(UserActivityService())
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<SettingsDb>(mockSettingsDb)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
      ..registerSingleton<Directory>(Directory.systemTemp);

    when(
      () => mockLoggingService.captureEvent(
        any<String>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) {});

    when(
      () => mockLoggingService.captureException(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) {});

    service = TestMatrixService(
      client: mockClient,
      matrixConfig: const MatrixConfig(
        homeServer: 'https://server',
        user: '@user:server',
        password: 'secret',
      ),
      journalDb: mockJournalDb,
      settingsDb: mockSettingsDb,
    );
  });

  tearDown(getIt.reset);

  group('deleteDevice', () {
    late MockDeviceKeys deviceKeys;

    setUp(() {
      deviceKeys = MockDeviceKeys();
      when(() => deviceKeys.deviceDisplayName).thenReturn('device');
      when(() => deviceKeys.userId).thenReturn('@user:server');
    });

    test('throws ArgumentError when deviceId is null', () async {
      when(() => deviceKeys.deviceId).thenReturn(null);

      expect(
        () => service.deleteDevice(deviceKeys),
        throwsArgumentError,
      );
    });

    test('throws StateError when config is missing', () async {
      final serviceWithoutConfig = TestMatrixService(
        client: mockClient,
        journalDb: mockJournalDb,
        settingsDb: mockSettingsDb,
      );

      when(() => deviceKeys.deviceId).thenReturn('device-id');

      expect(
        () => serviceWithoutConfig.deleteDevice(deviceKeys),
        throwsStateError,
      );
    });

    test('throws StateError when device belongs to different user', () async {
      when(() => deviceKeys.deviceId).thenReturn('device-id');
      when(() => deviceKeys.userId).thenReturn('@other:server');

      expect(
        () => service.deleteDevice(deviceKeys),
        throwsStateError,
      );
    });

    test('throws UnsupportedError when password is empty', () async {
      service.matrixConfig = const MatrixConfig(
        homeServer: 'https://server',
        user: '@user:server',
        password: '',
      );
      when(() => deviceKeys.deviceId).thenReturn('device-id');

      expect(
        () => service.deleteDevice(deviceKeys),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('calls client.deleteDevice with authentication when valid', () async {
      when(() => deviceKeys.deviceId).thenReturn('device-id');
      when(
        () => mockClient.deleteDevice(
          any<String>(),
          auth: any<AuthenticationPassword>(named: 'auth'),
        ),
      ).thenAnswer((_) async {});

      await service.deleteDevice(deviceKeys);

      verify(
        () => mockClient.deleteDevice(
          'device-id',
          auth: any<AuthenticationPassword>(named: 'auth'),
        ),
      ).called(1);
    });
  });

  group('getDiagnosticInfo', () {
    test('returns snapshot and logs diagnostics', () async {
      final mockRoom = MockRoom();
      final mockSummary = MockRoomSummary();

      when(() => mockSettingsDb.itemByKey(matrixRoomKey)).thenAnswer(
        (_) async => '!saved:room',
      );
      when(() => mockRoom.id).thenReturn('!room:server');
      when(() => mockRoom.name).thenReturn('Room');
      when(() => mockRoom.encrypted).thenReturn(true);
      when(() => mockRoom.summary).thenReturn(mockSummary);
      when(() => mockSummary.mJoinedMemberCount).thenReturn(2);
      when(() => mockClient.rooms).thenReturn([mockRoom]);

      service
        ..syncRoomId = '!room:server'
        ..syncRoom = mockRoom;

      final result = await service.getDiagnosticInfo();

      expect(result['deviceId'], 'device-id');
      expect(result['savedRoomId'], '!saved:room');
      expect(result['syncRoomId'], '!room:server');
      expect(result['joinedRooms'], isNotEmpty);

      verify(
        () => mockLoggingService.captureEvent(
          any<String>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'diagnostics',
        ),
      ).called(1);
    });
  });

  group('incrementSentCount', () {
    test('increments count and notifies listeners', () async {
      final stats = <MatrixStats>[];
      final subscription =
          service.messageCountsController.stream.listen(stats.add);

      addTearDown(subscription.cancel);

      service.incrementSentCount();

      expect(service.sentCount, 1);
      await Future<void>.delayed(Duration.zero);
      expect(stats.single.sentCount, 1);
    });
  });

  group('listener utilities', () {
    test('publishIncomingRunnerState triggers publish on runner', () {
      final runner = MockKeyVerificationRunner();
      service
        ..incomingKeyVerificationRunner = runner
        ..publishIncomingRunnerState();

      verify(runner.publishState).called(1);
    });

    test('logout cancels timeline and logs out client', () async {
      final mockTimeline = MockTimeline();
      service
        ..timeline = mockTimeline
        ..syncRoom = MockRoom();

      when(mockTimeline.cancelSubscriptions).thenAnswer((_) {});
      when(() => mockClient.logout()).thenAnswer((_) async {});

      await service.logout();

      verify(mockTimeline.cancelSubscriptions).called(1);
      verify(() => mockClient.logout()).called(1);
    });

    test('disposeClient calls client.dispose when logged in', () async {
      when(() => mockClient.dispose()).thenAnswer((_) async {});

      await service.disposeClient();

      verify(() => mockClient.dispose()).called(1);
    });

    test('listen starts key verification and timeline listeners', () async {
      final stubService = StubMatrixService(
        client: mockClient,
        journalDb: mockJournalDb,
        settingsDb: mockSettingsDb,
      );
      final onRoomStateController =
          CachedStreamController<({String roomId, StrippedStateEvent state})>();

      when(() => mockClient.onRoomState).thenReturn(onRoomStateController);
      when(() => mockClient.rooms).thenReturn(const []);

      await stubService.listen();

      expect(stubService.startKeyVerificationCount, 1);
      expect(stubService.listenToTimelineCount, 1);

      await onRoomStateController.close();
    });
  });

  group('sendMatrixMsg guard rails', () {
    test('logs send attempts and successes', () async {
      final mockRoom = MockRoom();
      when(() => mockRoom.id).thenReturn('!room:server');

      service
        ..syncRoom = mockRoom
        ..syncRoomId = '!room:server'
        ..unverifiedDevices = const [];

      when(
        () => mockRoom.sendTextEvent(
          any(),
          msgtype: any(named: 'msgtype'),
          parseCommands: any(named: 'parseCommands'),
          parseMarkdown: any(named: 'parseMarkdown'),
        ),
      ).thenAnswer((_) async => 'event');

      final result = await service.sendMatrixMsg(
        SyncMessage.aiConfig(
          aiConfig: fallbackAiConfig,
          status: SyncEntryStatus.update,
        ),
      );

      expect(result, isTrue);
      verify(
        () => mockLoggingService.captureEvent(
          contains('Sending message - using roomId'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'sendMatrixMsg',
        ),
      ).called(1);
      verify(
        () => mockLoggingService.captureEvent(
          contains('sent text message'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'sendMatrixMsg',
        ),
      ).called(1);
    });

    test('throws when unverified devices are present', () async {
      final mockDeviceKeys = MockDeviceKeys();
      service.unverifiedDevices = [mockDeviceKeys];

      expect(
        () => service.sendMatrixMsg(
          SyncMessage.aiConfig(
            aiConfig: fallbackAiConfig,
            status: SyncEntryStatus.update,
          ),
        ),
        throwsA(isA<Exception>()),
      );

      verify(
        () => mockLoggingService.captureException(
          any<Object>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'sendMatrixMsg',
        ),
      ).called(1);
    });

    test('returns false when roomId is missing', () async {
      service
        ..unverifiedDevices = const []
        ..syncRoomId = null;

      final result = await service.sendMatrixMsg(
        SyncMessage.aiConfig(
          aiConfig: fallbackAiConfig,
          status: SyncEntryStatus.update,
        ),
      );

      expect(result, isFalse);
      verify(
        () => mockLoggingService.captureEvent(
          configNotFound,
          domain: 'MATRIX_SERVICE',
          subDomain: 'sendMatrixMsg',
        ),
      ).called(1);
    });
  });
}
