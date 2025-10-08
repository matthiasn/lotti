// ignore_for_file: unnecessary_lambdas

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/key_verification_runner.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/matrix_timeline_listener.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/stats.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixSyncGateway extends Mock implements MatrixSyncGateway {}

class MockSyncRoomManager extends Mock implements SyncRoomManager {}

class MockMatrixSessionManager extends Mock implements MatrixSessionManager {}

class MockMatrixTimelineListener extends Mock
    implements MatrixTimelineListener {}

class MockLoggingService extends Mock implements LoggingService {}

class MockUserActivityGate extends Mock implements UserActivityGate {}

class MockClient extends Mock implements Client {}

class FakeMatrixClient extends Fake implements Client {}

class FakeTimeline extends Fake implements Timeline {}

class FakeEvent extends Fake implements Event {}

class MockRoomSummary extends Mock implements RoomSummary {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockJournalDb extends Mock implements JournalDb {}

class MockRoom extends Mock implements Room {}

class MockDeviceKeys extends Mock implements DeviceKeys {}

class MockKeyVerification extends Mock implements KeyVerification {}

class MockMatrixMessageSender extends Mock implements MatrixMessageSender {}

class MockSyncReadMarkerService extends Mock implements SyncReadMarkerService {}

class MockSyncEventProcessor extends Mock implements SyncEventProcessor {}

class MockSecureStorage extends Mock implements SecureStorage {}

void _noop() {}

MatrixMessageContext _createFallbackContext() => const MatrixMessageContext(
      syncRoomId: null,
      syncRoom: null,
      unverifiedDevices: [],
    );

class TestUserActivityGate extends UserActivityGate {
  TestUserActivityGate(UserActivityService service)
      : super(activityService: service, idleThreshold: Duration.zero);

  bool disposed = false;

  @override
  Future<void> dispose() async {
    disposed = true;
    await super.dispose();
  }
}

class TestableMatrixService extends MatrixService {
  TestableMatrixService({
    required super.gateway,
    required super.loggingService,
    required super.activityGate,
    required super.messageSender,
    required super.journalDb,
    required super.settingsDb,
    required super.readMarkerService,
    required super.eventProcessor,
    required super.secureStorage,
    required this.onStartKeyVerification,
    required this.onListenTimeline,
    super.roomManager,
    super.sessionManager,
    super.timelineListener,
    super.lifecycleCoordinator,
    super.syncEngine,
  });

  final VoidCallback onStartKeyVerification;
  final VoidCallback onListenTimeline;

  @override
  Future<void> startKeyVerificationListener() async {
    onStartKeyVerification();
  }

  @override
  Future<void> listenToTimeline() async {
    onListenTimeline();
  }

  bool loadConfigCalled = false;
  @override
  Future<MatrixConfig?> loadConfig() async {
    loadConfigCalled = true;
    return matrixConfig;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const connectivityMethodChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');

  setUpAll(() {
    registerFallbackValue(FakeMatrixClient());
    registerFallbackValue(
      const MatrixConfig(
        homeServer: 'https://example.org',
        user: '@fallback:example.org',
        password: 'pw',
      ),
    );
    registerFallbackValue(_createFallbackContext());
    registerFallbackValue(_noop);
    registerFallbackValue(FakeTimeline());
    registerFallbackValue(FakeEvent());
    registerFallbackValue(const SyncMessage.aiConfigDelete(id: 'fallback'));
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

  late MockMatrixSyncGateway mockGateway;
  late MockSyncRoomManager mockRoomManager;
  late MockMatrixSessionManager mockSessionManager;
  late MockMatrixTimelineListener mockTimelineListener;
  late MockLoggingService mockLoggingService;
  late MockUserActivityGate mockActivityGate;
  late MockClient mockClient;
  late MockMatrixMessageSender mockMessageSender;
  late MockSyncReadMarkerService mockReadMarkerService;
  late MockSyncEventProcessor mockEventProcessor;
  late MockSecureStorage mockSecureStorage;
  late MockSettingsDb mockSettingsDb;
  late MockJournalDb mockJournalDb;
  late StreamController<LoginState> loginStateController;
  late MatrixService service;

  setUp(() {
    mockGateway = MockMatrixSyncGateway();
    mockRoomManager = MockSyncRoomManager();
    mockSessionManager = MockMatrixSessionManager();
    mockTimelineListener = MockMatrixTimelineListener();
    mockLoggingService = MockLoggingService();
    mockActivityGate = MockUserActivityGate();
    mockClient = MockClient();
    mockMessageSender = MockMatrixMessageSender();
    mockReadMarkerService = MockSyncReadMarkerService();
    mockEventProcessor = MockSyncEventProcessor();
    mockSettingsDb = MockSettingsDb();
    mockJournalDb = MockJournalDb();
    mockSecureStorage = MockSecureStorage();

    when(() => mockGateway.client).thenReturn(mockClient);
    when(() => mockSessionManager.client).thenReturn(mockClient);
    when(() => mockSessionManager.isLoggedIn()).thenReturn(false);
    when(() => mockTimelineListener.initialize()).thenAnswer((_) async {});
    when(() => mockTimelineListener.start()).thenAnswer((_) async {});
    when(() => mockTimelineListener.dispose()).thenAnswer((_) async {});
    when(() => mockRoomManager.initialize()).thenAnswer((_) async {});
    when(() => mockRoomManager.dispose()).thenAnswer((_) async {});
    when(() => mockSessionManager.dispose()).thenAnswer((_) async {});
    when(() => mockActivityGate.dispose()).thenAnswer((_) async {});
    when(() => mockRoomManager.inviteRequests)
        .thenAnswer((_) => const Stream<SyncRoomInvite>.empty());
    when(
      () => mockMessageSender.sendMatrixMessage(
        message: any(named: 'message'),
        context: any(named: 'context'),
        onSent: any(named: 'onSent'),
        roomIdOverride: any(named: 'roomIdOverride'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => mockReadMarkerService.updateReadMarker(
        client: any(named: 'client'),
        timeline: any(named: 'timeline'),
        eventId: any(named: 'eventId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockEventProcessor.process(
        event: any(named: 'event'),
        journalDb: mockJournalDb,
      ),
    ).thenAnswer((_) async {});
    when(() => mockSecureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(
      () => mockSecureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockSecureStorage.delete(key: any(named: 'key')))
        .thenAnswer((_) async {});
    loginStateController = StreamController<LoginState>.broadcast();
    when(() => mockGateway.loginStateChanges)
        .thenAnswer((_) => loginStateController.stream);

    getIt
      ..reset()
      ..allowReassignment = true
      ..registerSingleton<UserActivityService>(UserActivityService())
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<SettingsDb>(mockSettingsDb)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<Directory>(Directory.systemTemp)
      ..registerSingleton<SecureStorage>(mockSecureStorage);

    service = MatrixService(
      gateway: mockGateway,
      loggingService: mockLoggingService,
      activityGate: mockActivityGate,
      messageSender: mockMessageSender,
      journalDb: mockJournalDb,
      settingsDb: mockSettingsDb,
      readMarkerService: mockReadMarkerService,
      eventProcessor: mockEventProcessor,
      secureStorage: mockSecureStorage,
      roomManager: mockRoomManager,
      sessionManager: mockSessionManager,
      timelineListener: mockTimelineListener,
    );
  });

  tearDown(() async {
    await loginStateController.close();
    await getIt.reset();
  });

  test('createRoom delegates to SyncRoomManager', () async {
    when(
      () => mockRoomManager.createRoom(
        inviteUserIds: any<List<String>?>(named: 'inviteUserIds'),
      ),
    ).thenAnswer((_) async => '!room:server');

    final roomId = await service.createRoom(invite: ['@user:server']);

    expect(roomId, '!room:server');
    verify(
      () => mockRoomManager.createRoom(inviteUserIds: ['@user:server']),
    ).called(1);
  });

  test('joinRoom returns identifier from room manager', () async {
    final mockRoom = MockRoom();
    when(() => mockRoom.id).thenReturn('!room:server');
    when(() => mockRoomManager.joinRoom('!room:server'))
        .thenAnswer((_) async => mockRoom);

    final result = await service.joinRoom('!room:server');

    expect(result, '!room:server');
    verify(() => mockRoomManager.joinRoom('!room:server')).called(1);
  });

  test('inviteToSyncRoom delegates to room manager', () async {
    when(() => mockRoomManager.inviteUser('@user:server'))
        .thenAnswer((_) async {});

    await service.inviteToSyncRoom(userId: '@user:server');

    verify(() => mockRoomManager.inviteUser('@user:server')).called(1);
  });

  test('inviteRequests forwards stream from room manager', () async {
    final controller = StreamController<SyncRoomInvite>.broadcast();
    when(() => mockRoomManager.inviteRequests)
        .thenAnswer((_) => controller.stream);

    final invite = SyncRoomInvite(
      roomId: '!room:server',
      senderId: '@user:server',
      matchesExistingRoom: false,
    );

    final expectation = expectLater(service.inviteRequests, emits(invite));

    controller.add(invite);
    await controller.close();
    await expectation;
  });

  test('saveRoom delegates to room manager', () async {
    when(() => mockRoomManager.saveRoomId('!room:server'))
        .thenAnswer((_) async {});

    await service.saveRoom('!room:server');

    verify(() => mockRoomManager.saveRoomId('!room:server')).called(1);
  });

  test('leaveRoom delegates to room manager', () async {
    when(() => mockRoomManager.leaveCurrentRoom()).thenAnswer((_) async {});

    await service.leaveRoom();

    verify(() => mockRoomManager.leaveCurrentRoom()).called(1);
  });

  test('connect delegates to session manager without login attempt', () async {
    when(() => mockSessionManager.connect(shouldAttemptLogin: false))
        .thenAnswer((_) async => true);

    final result = await service.connect();

    expect(result, isTrue);
    verify(() => mockSessionManager.connect(shouldAttemptLogin: false))
        .called(1);
  });

  test('login delegates to session manager with login attempt', () async {
    when(() => mockSessionManager.connect(shouldAttemptLogin: true))
        .thenAnswer((_) async => true);

    final result = await service.login();

    expect(result, isTrue);
    verify(() => mockSessionManager.connect(shouldAttemptLogin: true))
        .called(1);
  });

  test('logout delegates to session manager', () async {
    when(() => mockSessionManager.logout()).thenAnswer((_) async {});

    await service.logout();

    verify(() => mockSessionManager.logout()).called(1);
  });

  test('disposeClient disposes underlying client when logged in', () async {
    when(() => mockClient.isLogged()).thenReturn(true);
    when(() => mockClient.dispose()).thenAnswer((_) async {});

    await service.disposeClient();

    verify(() => mockClient.dispose()).called(1);
  });

  test('disposeClient skips dispose when client not logged', () async {
    when(() => mockClient.isLogged()).thenReturn(false);

    await service.disposeClient();

    verifyNever(() => mockClient.dispose());
  });

  test('getDiagnosticInfo returns expected payload and logs', () async {
    when(() => mockRoomManager.loadPersistedRoomId())
        .thenAnswer((_) async => '!room:server');
    final mockRoom = MockRoom();
    final mockSummary = MockRoomSummary();
    when(() => mockRoom.id).thenReturn('!room:server');
    when(() => mockRoom.name).thenReturn('Room');
    when(() => mockRoom.encrypted).thenReturn(true);
    when(() => mockRoom.summary).thenReturn(mockSummary);
    when(() => mockSummary.mJoinedMemberCount).thenReturn(2);
    when(() => mockClient.rooms).thenReturn([mockRoom]);
    final diagnosticsLoginController = CachedStreamController<LoginState>()
      ..add(LoginState.loggedIn);
    addTearDown(diagnosticsLoginController.close);
    when(() => mockClient.onLoginStateChanged)
        .thenReturn(diagnosticsLoginController);
    when(() => mockClient.onLoginStateChanged.value)
        .thenReturn(LoginState.loggedIn);
    when(
      () => mockLoggingService.captureEvent(
        any<String>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) {});

    final info = await service.getDiagnosticInfo();

    expect(info['savedRoomId'], '!room:server');
    expect(info['joinedRooms'], isA<List<Map<String, Object?>>>());
    verify(
      () => mockLoggingService.captureEvent(
        any<String>(),
        domain: 'MATRIX_SERVICE',
        subDomain: 'diagnostics',
      ),
    ).called(1);
  });

  test('publishIncomingRunnerState forwards publishState when runner set',
      () async {
    final mockKeyVerification = MockKeyVerification();
    when(() => mockKeyVerification.lastStep).thenReturn('init');
    when(() => mockKeyVerification.sasEmojis)
        .thenReturn(<KeyVerificationEmoji>[]);
    when(() => mockKeyVerification.acceptVerification())
        .thenAnswer((_) async {});
    when(() => mockKeyVerification.acceptSas()).thenAnswer((_) async {});
    when(() => mockKeyVerification.cancel()).thenAnswer((_) async {});

    final controller = StreamController<KeyVerificationRunner>.broadcast();
    final runner = KeyVerificationRunner(
      mockKeyVerification,
      controller: controller,
      name: 'runner',
    )..stopTimer();
    service.incomingKeyVerificationRunner = runner;

    final emitted = <KeyVerificationRunner>[];
    final sub = controller.stream.listen(emitted.add);

    service.publishIncomingRunnerState();
    await Future<void>.microtask(() {});
    await sub.cancel();
    await controller.close();

    expect(emitted.last, same(runner));
  });

  test('getIncomingKeyVerificationStream forwards controller events', () async {
    final stream = service.getIncomingKeyVerificationStream();
    final verification = MockKeyVerification();

    final expectation = expectLater(stream, emits(verification));

    service.incomingKeyVerificationController.add(verification);

    await expectation;
  });

  test('getUnverifiedDevices delegates to gateway', () {
    final deviceKeys = [MockDeviceKeys(), MockDeviceKeys()];
    when(() => mockGateway.unverifiedDevices()).thenReturn(deviceKeys);

    expect(service.getUnverifiedDevices(), deviceKeys);
  });

  test('logout ignores timeline when already null', () async {
    when(() => mockTimelineListener.timeline).thenReturn(null);
    when(() => mockSessionManager.logout()).thenAnswer((_) async {});

    await service.logout();

    verify(() => mockSessionManager.logout()).called(1);
  });

  group('deleteDevice', () {
    const config = MatrixConfig(
      homeServer: 'https://example.org',
      user: '@user:server',
      password: 'pw',
    );
    MatrixConfig? sessionConfig;

    setUp(() {
      sessionConfig = config;
      when(() => mockSessionManager.matrixConfig)
          .thenAnswer((_) => sessionConfig);
      when(() => mockSessionManager.matrixConfig = any())
          .thenAnswer((invocation) {
        return sessionConfig =
            invocation.positionalArguments.first as MatrixConfig?;
      });
      service.matrixConfig = config;
      when(() => mockClient.userID).thenReturn('@user:server');
      when(() => mockClient.deviceID).thenReturn('device');
      when(
        () => mockClient.deleteDevice(
          any(),
          auth: any(named: 'auth'),
        ),
      ).thenAnswer((_) async {});
    });

    test('throws when deviceId missing', () async {
      final deviceKeys = MockDeviceKeys();
      when(() => deviceKeys.deviceId).thenReturn(null);

      expect(() => service.deleteDevice(deviceKeys), throwsArgumentError);
    });

    test('throws when config missing', () async {
      service.matrixConfig = null;
      final deviceKeys = MockDeviceKeys();
      when(() => deviceKeys.deviceId).thenReturn('dev');

      expect(() => service.deleteDevice(deviceKeys), throwsStateError);
    });

    test('throws when user mismatch', () async {
      final deviceKeys = MockDeviceKeys();
      when(() => deviceKeys.deviceId).thenReturn('dev');
      when(() => deviceKeys.userId).thenReturn('@other:server');

      expect(() => service.deleteDevice(deviceKeys), throwsStateError);
    });

    test('throws when password missing', () async {
      service.matrixConfig = config.copyWith(password: '');
      final deviceKeys = MockDeviceKeys();
      when(() => deviceKeys.deviceId).thenReturn('dev');
      when(() => deviceKeys.userId).thenReturn('@user:server');

      expect(() => service.deleteDevice(deviceKeys), throwsUnsupportedError);
    });

    test('invokes client delete for valid device', () async {
      final deviceKeys = MockDeviceKeys();
      when(() => deviceKeys.deviceId).thenReturn('dev');
      when(() => deviceKeys.userId).thenReturn('@user:server');

      await service.deleteDevice(deviceKeys);

      verify(
        () => mockClient.deleteDevice(
          'dev',
          auth: any(named: 'auth'),
        ),
      ).called(1);
    });
  });

  test('dispose closes controllers and disposes collaborators', () async {
    await service.dispose();

    expect(
      () => service.messageCountsController.add(
        MatrixStats(sentCount: 0, messageCounts: const <String, int>{}),
      ),
      throwsA(isA<StateError>()),
    );
    verify(() => mockTimelineListener.dispose()).called(1);
    verify(() => mockRoomManager.dispose()).called(1);
    verify(() => mockSessionManager.dispose()).called(1);
    verifyNever(() => mockActivityGate.dispose());
  });

  test('dispose disposes owned activity gate when service owns instance',
      () async {
    if (getIt.isRegistered<UserActivityGate>()) {
      getIt.unregister<UserActivityGate>();
    }
    final ownedGate = TestUserActivityGate(UserActivityService());
    getIt.registerSingleton<UserActivityGate>(ownedGate);

    final extraRoomManager = MockSyncRoomManager();
    final extraSessionManager = MockMatrixSessionManager();
    final extraTimelineListener = MockMatrixTimelineListener();
    when(() => extraTimelineListener.dispose()).thenAnswer((_) async {});
    when(() => extraRoomManager.dispose()).thenAnswer((_) async {});
    when(() => extraSessionManager.dispose()).thenAnswer((_) async {});
    final extraMessageSender = MockMatrixMessageSender();
    when(
      () => extraMessageSender.sendMatrixMessage(
        message: any(named: 'message'),
        context: any(named: 'context'),
        onSent: any(named: 'onSent'),
        roomIdOverride: any(named: 'roomIdOverride'),
      ),
    ).thenAnswer((_) async => true);
    final extraReadMarkerService = MockSyncReadMarkerService();
    when(
      () => extraReadMarkerService.updateReadMarker(
        client: any(named: 'client'),
        timeline: any(named: 'timeline'),
        eventId: any(named: 'eventId'),
      ),
    ).thenAnswer((_) async {});
    final extraEventProcessor = MockSyncEventProcessor();
    final extraJournalDb = MockJournalDb();
    when(
      () => extraEventProcessor.process(
        event: any(named: 'event'),
        journalDb: extraJournalDb,
      ),
    ).thenAnswer((_) async {});
    final extraSettingsDb = MockSettingsDb();
    final extraSecureStorage = MockSecureStorage();
    when(() => extraSecureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(
      () => extraSecureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => extraSecureStorage.delete(key: any(named: 'key')))
        .thenAnswer((_) async {});
    final extraService = MatrixService(
      gateway: mockGateway,
      loggingService: mockLoggingService,
      activityGate: ownedGate,
      messageSender: extraMessageSender,
      journalDb: extraJournalDb,
      settingsDb: extraSettingsDb,
      readMarkerService: extraReadMarkerService,
      eventProcessor: extraEventProcessor,
      secureStorage: extraSecureStorage,
      roomManager: extraRoomManager,
      sessionManager: extraSessionManager,
      timelineListener: extraTimelineListener,
      ownsActivityGate: true,
    );

    await extraService.dispose();

    expect(ownedGate.disposed, isTrue);
  });

  group('MatrixSessionManager', () {
    late MatrixSessionManager sessionManager;
    late MockSyncRoomManager sessionRoomManager;
    late MockMatrixSyncGateway sessionGateway;
    late MockLoggingService sessionLogging;
    late MockClient sessionClient;
    late bool connectCalled;
    late bool loginCalled;
    late bool isLogged;

    setUp(() {
      sessionRoomManager = MockSyncRoomManager();
      sessionGateway = MockMatrixSyncGateway();
      sessionLogging = MockLoggingService();
      sessionClient = MockClient();
      when(() => sessionGateway.client).thenReturn(sessionClient);
      isLogged = false;
      when(() => sessionClient.isLogged()).thenAnswer((_) => isLogged);
      when(() => sessionRoomManager.initialize()).thenAnswer((_) async {});
      when(
        () => sessionRoomManager.hydrateRoomSnapshot(
          client: any<Client>(named: 'client'),
        ),
      ).thenAnswer((_) async {});
      connectCalled = false;
      loginCalled = false;
      when(() => sessionGateway.connect(any<MatrixConfig>()))
          .thenAnswer((_) async {
        connectCalled = true;
      });
      when(() => sessionRoomManager.loadPersistedRoomId())
          .thenAnswer((_) async => '!room:server');
      when(() => sessionClient.getRoomById('!room:server')).thenReturn(null);
      final joinedRoom = MockRoom();
      when(() => joinedRoom.id).thenReturn('!room:server');
      when(() => sessionRoomManager.joinRoom('!room:server'))
          .thenAnswer((_) async => joinedRoom);
      when(
        () => sessionGateway.login(
          any<MatrixConfig>(),
          deviceDisplayName: any(named: 'deviceDisplayName'),
        ),
      ).thenAnswer((_) async {
        loginCalled = true;
        isLogged = true;
        return LoginResponse(
          accessToken: 'token',
          deviceId: 'device',
          userId: '@user:server',
        );
      });
      when(
        () => sessionLogging.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});
      when(
        () => sessionLogging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).thenAnswer((_) {});
      sessionManager = MatrixSessionManager(
        gateway: sessionGateway,
        roomManager: sessionRoomManager,
        loggingService: sessionLogging,
      )
        ..matrixConfig = const MatrixConfig(
          homeServer: 'https://example.org',
          user: '@user:server',
          password: 'pw',
        )
        ..deviceDisplayName = 'Test Device';
    });

    test('connect joins persisted room after successful setup', () async {
      sessionManager.matrixConfig ??= const MatrixConfig(
        homeServer: 'https://example.org',
        user: '@user:server',
        password: 'pw',
      );
      sessionManager.deviceDisplayName = 'Test Device';
      expect(sessionManager.matrixConfig, isNotNull);

      await sessionManager.connect(shouldAttemptLogin: true);

      expect(connectCalled, isTrue);
      expect(loginCalled, isTrue);
      verify(
        () => sessionRoomManager.hydrateRoomSnapshot(client: sessionClient),
      ).called(1);
      verify(() => sessionRoomManager.joinRoom('!room:server')).called(1);
    });

    test('connect returns false and logs when configuration missing', () async {
      sessionManager.matrixConfig = null;

      final result = await sessionManager.connect(shouldAttemptLogin: true);

      expect(result, isFalse);
      expect(connectCalled, isFalse);
      expect(loginCalled, isFalse);
      verifyNever(
        () => sessionRoomManager.hydrateRoomSnapshot(
            client: any<Client>(named: 'client')),
      );
      verify(
        () => sessionLogging.captureEvent(
          contains('Matrix configuration missing'),
          domain: 'MATRIX_SESSION_MANAGER',
          subDomain: 'connect',
        ),
      ).called(1);
    });

    test('connect skips login when already logged in', () async {
      sessionManager.matrixConfig ??= const MatrixConfig(
        homeServer: 'https://example.org',
        user: '@user:server',
        password: 'pw',
      );
      isLogged = true;

      await sessionManager.connect(shouldAttemptLogin: true);

      expect(connectCalled, isTrue);
      expect(loginCalled, isFalse);
      verify(
        () => sessionRoomManager.hydrateRoomSnapshot(client: sessionClient),
      ).called(1);
    });

    test('connect avoids join when room already hydrated', () async {
      sessionManager.matrixConfig ??= const MatrixConfig(
        homeServer: 'https://example.org',
        user: '@user:server',
        password: 'pw',
      );
      isLogged = true;
      when(() => sessionRoomManager.loadPersistedRoomId())
          .thenAnswer((_) async => '!already:room');
      final hydratedRoom = MockRoom();
      when(() => sessionClient.getRoomById('!already:room'))
          .thenReturn(hydratedRoom);

      await sessionManager.connect(shouldAttemptLogin: true);

      verify(
        () => sessionRoomManager.hydrateRoomSnapshot(client: sessionClient),
      ).called(1);
      verifyNever(() => sessionRoomManager.joinRoom(any<String>()));
    });

    test('connect logs join failure but resolves', () async {
      sessionManager.matrixConfig ??= const MatrixConfig(
        homeServer: 'https://example.org',
        user: '@user:server',
        password: 'pw',
      );
      when(() => sessionRoomManager.loadPersistedRoomId())
          .thenAnswer((_) async => '!room:server');
      when(() => sessionRoomManager.joinRoom('!room:server'))
          .thenThrow(Exception('join failed'));

      final result = await sessionManager.connect(shouldAttemptLogin: true);

      expect(result, isTrue);
      verify(
        () => sessionRoomManager.hydrateRoomSnapshot(client: sessionClient),
      ).called(1);
      verify(
        () => sessionLogging.captureException(
          any<Object>(),
          domain: 'MATRIX_SESSION_MANAGER',
          subDomain: 'connect.join',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
    });

    test('connect does not hydrate when not logged and login skipped',
        () async {
      sessionManager.matrixConfig ??= const MatrixConfig(
        homeServer: 'https://example.org',
        user: '@user:server',
        password: 'pw',
      );

      final result = await sessionManager.connect(shouldAttemptLogin: false);

      expect(result, isTrue);
      verifyNever(
        () => sessionRoomManager.hydrateRoomSnapshot(client: sessionClient),
      );
      verifyNever(() => sessionRoomManager.joinRoom(any<String>()));
    });

    test('connect returns false when gateway connect throws', () async {
      sessionManager.matrixConfig ??= const MatrixConfig(
        homeServer: 'https://example.org',
        user: '@user:server',
        password: 'pw',
      );
      when(() => sessionGateway.connect(any())).thenThrow(Exception('fail'));

      final result = await sessionManager.connect(shouldAttemptLogin: true);

      expect(result, isFalse);
      verify(
        () => sessionLogging.captureException(
          any<Object>(),
          domain: 'MATRIX_SESSION_MANAGER',
          subDomain: 'connect',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });

  group('MatrixService lifecycle', () {
    late TestableMatrixService testService;
    late bool startKeyCalled;
    late bool listenTimelineCalled;
    late CachedStreamController<LoginState> loginController;

    setUp(() {
      startKeyCalled = false;
      listenTimelineCalled = false;
      when(() => mockTimelineListener.start()).thenAnswer((_) async {
        listenTimelineCalled = true;
      });
      when(() => mockRoomManager.loadPersistedRoomId())
          .thenAnswer((_) async => '!room:server');
      final mockRoom = MockRoom();
      final mockSummary = MockRoomSummary();
      when(() => mockSummary.mJoinedMemberCount).thenReturn(1);
      when(() => mockRoom.id).thenReturn('!room:server');
      when(() => mockRoom.name).thenReturn('Room');
      when(() => mockRoom.encrypted).thenReturn(true);
      when(() => mockRoom.summary).thenReturn(mockSummary);
      when(() => mockClient.rooms).thenReturn([mockRoom]);
      testService = TestableMatrixService(
        gateway: mockGateway,
        loggingService: mockLoggingService,
        activityGate: mockActivityGate,
        messageSender: mockMessageSender,
        journalDb: mockJournalDb,
        settingsDb: mockSettingsDb,
        readMarkerService: mockReadMarkerService,
        eventProcessor: mockEventProcessor,
        secureStorage: mockSecureStorage,
        roomManager: mockRoomManager,
        sessionManager: mockSessionManager,
        timelineListener: mockTimelineListener,
        onStartKeyVerification: () => startKeyCalled = true,
        onListenTimeline: () => listenTimelineCalled = true,
      )..matrixConfig = const MatrixConfig(
          homeServer: 'https://example.org',
          user: '@user:server',
          password: 'pw',
        );
      when(() => mockSessionManager.connect(shouldAttemptLogin: false))
          .thenAnswer((_) async => true);
      when(() => mockRoomManager.hydrateRoomSnapshot(client: mockClient))
          .thenAnswer((_) async {});
      loginController = CachedStreamController<LoginState>()
        ..add(LoginState.loggedIn);
      when(() => mockClient.onLoginStateChanged).thenReturn(loginController);
      when(() => mockSessionManager.isLoggedIn()).thenReturn(true);
      when(() => mockClient.isLogged()).thenReturn(true);
    });

    tearDown(() async {
      await testService.dispose();
      await loginController.close();
    });

    test('listen triggers startKey listener', () async {
      await testService.listen();

      expect(startKeyCalled, isTrue);
      expect(listenTimelineCalled, isFalse);
      verify(() => mockRoomManager.loadPersistedRoomId()).called(1);
    });

    test('listen logs sync state with persisted and joined rooms', () async {
      final roomA = MockRoom();
      final roomB = MockRoom();
      when(() => roomA.id).thenReturn('!roomA:server');
      when(() => roomB.id).thenReturn('!roomB:server');
      when(() => mockClient.rooms).thenReturn([roomA, roomB]);
      when(() => mockRoomManager.currentRoomId).thenReturn('!roomA:server');
      when(() => mockRoomManager.loadPersistedRoomId())
          .thenAnswer((_) async => '!roomPersisted:server');

      await testService.listen();

      verify(
        () => mockLoggingService.captureEvent(
          contains('savedRoomId: !roomPersisted:server'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'listen',
        ),
      ).called(1);
    });

    test('init connects, hydrates, and listens when logged in', () async {
      await testService.init();

      expect(testService.loadConfigCalled, isTrue);
      verify(() => mockSessionManager.connect(shouldAttemptLogin: false))
          .called(1);
      verify(() => mockRoomManager.hydrateRoomSnapshot(client: mockClient))
          .called(1);
      expect(startKeyCalled, isTrue);
      expect(listenTimelineCalled, isTrue);
    });

    test('init stops when session connect fails', () async {
      when(() => mockSessionManager.connect(shouldAttemptLogin: false))
          .thenAnswer((_) async => false);
      await loginController.close();
      loginController = CachedStreamController<LoginState>()
        ..add(LoginState.loggedOut);
      when(() => mockClient.onLoginStateChanged).thenReturn(loginController);
      when(() => mockSessionManager.isLoggedIn()).thenReturn(false);
      when(() => mockClient.isLogged()).thenReturn(false);

      await testService.init();

      expect(testService.loadConfigCalled, isTrue);
      expect(startKeyCalled, isFalse);
      expect(listenTimelineCalled, isFalse);
      verifyNever(
        () => mockRoomManager.hydrateRoomSnapshot(client: mockClient),
      );
    });

    test('init does not listen when login state is not logged in', () async {
      await loginController.close();
      loginController = CachedStreamController<LoginState>()
        ..add(LoginState.loggedOut);
      when(() => mockClient.onLoginStateChanged).thenReturn(loginController);
      when(() => mockSessionManager.isLoggedIn()).thenReturn(false);
      when(() => mockClient.isLogged()).thenReturn(false);

      await testService.init();

      expect(startKeyCalled, isFalse);
      expect(listenTimelineCalled, isFalse);
    });
  });
}
