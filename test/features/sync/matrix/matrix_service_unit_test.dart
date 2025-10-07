// ignore_for_file: unnecessary_lambdas

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/matrix_timeline_listener.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/stats.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
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

class MockTimeline extends Mock implements Timeline {}

class MockRoomSummary extends Mock implements RoomSummary {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockJournalDb extends Mock implements JournalDb {}

class MockRoom extends Mock implements Room {}

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
  late MatrixService service;

  setUp(() {
    mockGateway = MockMatrixSyncGateway();
    mockRoomManager = MockSyncRoomManager();
    mockSessionManager = MockMatrixSessionManager();
    mockTimelineListener = MockMatrixTimelineListener();
    mockLoggingService = MockLoggingService();
    mockActivityGate = MockUserActivityGate();
    mockClient = MockClient();

    when(() => mockGateway.client).thenReturn(mockClient);
    when(() => mockSessionManager.client).thenReturn(mockClient);
    when(() => mockSessionManager.isLoggedIn()).thenReturn(false);
    when(() => mockTimelineListener.start()).thenAnswer((_) async {});
    when(() => mockTimelineListener.dispose()).thenAnswer((_) async {});
    when(() => mockRoomManager.dispose()).thenAnswer((_) async {});
    when(() => mockSessionManager.dispose()).thenAnswer((_) async {});
    when(() => mockActivityGate.dispose()).thenAnswer((_) async {});
    when(() => mockRoomManager.inviteRequests)
        .thenAnswer((_) => const Stream<SyncRoomInvite>.empty());

    getIt
      ..reset()
      ..allowReassignment = true
      ..registerSingleton<UserActivityService>(UserActivityService())
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<SettingsDb>(MockSettingsDb())
      ..registerSingleton<JournalDb>(MockJournalDb())
      ..registerSingleton<Directory>(Directory.systemTemp);

    service = MatrixService(
      gateway: mockGateway,
      activityGate: mockActivityGate,
      overriddenLoggingService: mockLoggingService,
      roomManager: mockRoomManager,
      sessionManager: mockSessionManager,
      timelineListener: mockTimelineListener,
    );
  });

  tearDown(getIt.reset);

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

  test('logout cancels timeline and invokes session manager', () async {
    final mockTimeline = MockTimeline();
    when(() => mockTimeline.cancelSubscriptions()).thenAnswer((_) async {});
    when(() => mockTimelineListener.timeline).thenReturn(mockTimeline);
    when(() => mockSessionManager.logout()).thenAnswer((_) async {});

    await service.logout();

    verify(() => mockTimeline.cancelSubscriptions()).called(1);
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
        () => sessionRoomManager.hydrateRoomSnapshot(
            client: any<Client>(named: 'client')),
      );
      verifyNever(() => sessionRoomManager.joinRoom(any<String>()));
    });
  });
}
