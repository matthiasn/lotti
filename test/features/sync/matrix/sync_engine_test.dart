import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/matrix_timeline_listener.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_engine.dart';
import 'package:lotti/features/sync/matrix/sync_lifecycle_coordinator.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixSessionManager extends Mock implements MatrixSessionManager {}

class MockSyncRoomManager extends Mock implements SyncRoomManager {}

class MockTimelineListener extends Mock implements MatrixTimelineListener {}

class MockSyncLifecycleCoordinator extends Mock
    implements SyncLifecycleCoordinator {}

class MockLoggingService extends Mock implements LoggingService {}

class MockClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

class MockRoomSummary extends Mock implements RoomSummary {}

void main() {
  setUpAll(() {
    registerFallbackValue(() async {});
  });

  late MockMatrixSessionManager sessionManager;
  late MockSyncRoomManager roomManager;
  late MockTimelineListener timelineListener;
  late MockSyncLifecycleCoordinator lifecycleCoordinator;
  late MockLoggingService loggingService;
  late SyncEngine engine;

  setUp(() {
    sessionManager = MockMatrixSessionManager();
    roomManager = MockSyncRoomManager();
    timelineListener = MockTimelineListener();
    lifecycleCoordinator = MockSyncLifecycleCoordinator();
    loggingService = MockLoggingService();

    engine = SyncEngine(
      sessionManager: sessionManager,
      roomManager: roomManager,
      timelineListener: timelineListener,
      lifecycleCoordinator: lifecycleCoordinator,
      loggingService: loggingService,
    );

    when(() => lifecycleCoordinator.updateHooks(
          onLogin: any(named: 'onLogin'),
          onLogout: any(named: 'onLogout'),
        )).thenReturn(null);
    when(() => lifecycleCoordinator.initialize()).thenAnswer((_) async {});
    when(() => lifecycleCoordinator.reconcileLifecycleState())
        .thenAnswer((_) async {});
    when(() => lifecycleCoordinator.dispose()).thenAnswer((_) async {});
  });

  test('initialize primes lifecycle coordinator exactly once', () async {
    await engine.initialize(onLogin: () async {}, onLogout: () async {});

    verify(
      () => lifecycleCoordinator.updateHooks(
        onLogin: any(named: 'onLogin'),
        onLogout: any(named: 'onLogout'),
      ),
    ).called(1);
    verify(() => lifecycleCoordinator.initialize()).called(1);
    verify(() => lifecycleCoordinator.reconcileLifecycleState()).called(1);

    clearInteractions(lifecycleCoordinator);
    when(() => lifecycleCoordinator.reconcileLifecycleState())
        .thenAnswer((_) async {});

    await engine.initialize();

    verifyNever(() => lifecycleCoordinator.initialize());
    verify(() => lifecycleCoordinator.reconcileLifecycleState()).called(1);
  });

  test('connect delegates to session manager and syncs lifecycle on success',
      () async {
    when(
      () => sessionManager.connect(
          shouldAttemptLogin: any(named: 'shouldAttemptLogin')),
    ).thenAnswer((invocation) async {
      final shouldAttemptLogin =
          invocation.namedArguments[#shouldAttemptLogin] as bool;
      return shouldAttemptLogin;
    });

    when(() => lifecycleCoordinator.reconcileLifecycleState())
        .thenAnswer((_) async {});

    final loginResult = await engine.connect(shouldAttemptLogin: true);
    expect(loginResult, isTrue);
    verify(
      () => sessionManager.connect(shouldAttemptLogin: true),
    ).called(1);
    verify(() => lifecycleCoordinator.reconcileLifecycleState()).called(1);

    final connectResult = await engine.connect(shouldAttemptLogin: false);
    expect(connectResult, isFalse);
  });

  test('logout calls session manager and synchronises lifecycle', () async {
    when(() => sessionManager.logout()).thenAnswer((_) async {});
    when(() => lifecycleCoordinator.reconcileLifecycleState())
        .thenAnswer((_) async {});

    await engine.logout();

    verify(() => sessionManager.logout()).called(1);
    verify(() => lifecycleCoordinator.reconcileLifecycleState()).called(1);
  });

  test('dispose delegates to lifecycle coordinator', () async {
    await engine.dispose();
    verify(() => lifecycleCoordinator.dispose()).called(1);
  });

  test('diagnostics aggregates engine state and logs when requested', () async {
    final client = MockClient();
    final room = MockRoom();
    final summary = MockRoomSummary();

    when(() => sessionManager.client).thenReturn(client);
    when(() => sessionManager.isLoggedIn()).thenReturn(true);
    when(() => roomManager.loadPersistedRoomId())
        .thenAnswer((_) async => '!saved:server');
    when(() => roomManager.currentRoomId).thenReturn('!current:server');
    when(() => roomManager.currentRoom).thenReturn(room);
    when(() => lifecycleCoordinator.isActive).thenReturn(true);
    when(() => client.deviceID).thenReturn('device');
    when(() => client.deviceName).thenReturn('Device Name');
    when(() => client.userID).thenReturn('@user:server');
    when(() => client.rooms).thenReturn([room]);
    when(() => room.id).thenReturn('!room:server');
    when(() => room.name).thenReturn('Room');
    when(() => room.encrypted).thenReturn(true);
    when(() => room.summary).thenReturn(summary);
    when(() => summary.mJoinedMemberCount).thenReturn(2);
    final loginController = CachedStreamController<LoginState>()
      ..add(LoginState.loggedIn);
    addTearDown(loginController.close);
    when(() => client.onLoginStateChanged).thenReturn(loginController);
    when(() => client.onLoginStateChanged.value)
        .thenReturn(LoginState.loggedIn);
    when(
      () => loggingService.captureEvent(
        any<String>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenReturn(null);

    final diagnostics = await engine.diagnostics();

    expect(diagnostics['deviceId'], 'device');
    expect(diagnostics['savedRoomId'], '!saved:server');
    expect(diagnostics['timelineActive'], isTrue);
    verify(
      () => loggingService.captureEvent(
        any<String>(),
        domain: 'SYNC_ENGINE',
        subDomain: 'diagnostics',
      ),
    ).called(1);

    clearInteractions(loggingService);
    await engine.diagnostics(log: false);
    verifyNever(
      () => loggingService.captureEvent(
        any<String>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    );
  });
}
