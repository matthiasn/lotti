import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_pipeline.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_lifecycle_coordinator.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixSyncGateway extends Mock implements MatrixSyncGateway {}

class MockMatrixSessionManager extends Mock implements MatrixSessionManager {}

class MockSyncPipeline extends Mock implements SyncPipeline {}

class MockSyncRoomManager extends Mock implements SyncRoomManager {}

class MockLoggingService extends Mock implements LoggingService {}

class MockClient extends Mock implements Client {}

class _FakeClient extends Fake implements Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeClient());
  });

  late MockMatrixSyncGateway gateway;
  late MockMatrixSessionManager sessionManager;
  late MockSyncPipeline pipeline;
  late MockSyncRoomManager roomManager;
  late MockLoggingService loggingService;
  late MockClient client;
  late StreamController<LoginState> loginStateController;

  setUp(() {
    gateway = MockMatrixSyncGateway();
    sessionManager = MockMatrixSessionManager();
    pipeline = MockSyncPipeline();
    roomManager = MockSyncRoomManager();
    loggingService = MockLoggingService();
    client = MockClient();
    loginStateController = StreamController<LoginState>.broadcast();

    when(() => gateway.loginStateChanges)
        .thenAnswer((_) => loginStateController.stream);
    when(() => sessionManager.client).thenReturn(client);
    when(() => sessionManager.isLoggedIn()).thenReturn(false);
    when(() => pipeline.initialize()).thenAnswer((_) async {});
    when(() => pipeline.start()).thenAnswer((_) async {});
    when(() => pipeline.dispose()).thenAnswer((_) async {});
    when(() => roomManager.initialize()).thenAnswer((_) async {});
    when(
      () => roomManager.hydrateRoomSnapshot(
        client: any<Client>(named: 'client'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => loggingService.captureEvent(
        any<String>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(
      () => loggingService.captureException(
        any<dynamic>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<dynamic>(named: 'stackTrace'),
      ),
    ).thenReturn(null);
  });

  tearDown(() async {
    await loginStateController.close();
  });

  test('initialize primes pipeline and handles already logged-in devices',
      () async {
    when(() => client.isLogged()).thenReturn(true);
    when(() => sessionManager.isLoggedIn()).thenReturn(true);

    var onLoginInvoked = 0;
    final coordinator = SyncLifecycleCoordinator(
      gateway: gateway,
      sessionManager: sessionManager,
      roomManager: roomManager,
      loggingService: loggingService,
      pipeline: pipeline,
      onLogin: () async {
        onLoginInvoked += 1;
      },
    );

    await coordinator.initialize();

    verify(() => pipeline.initialize()).called(1);
    verify(() => roomManager.initialize()).called(1);
    verify(
      () => roomManager.hydrateRoomSnapshot(client: client),
    ).called(1);
    verify(() => pipeline.start()).called(1);
    expect(onLoginInvoked, 1);
    expect(coordinator.isActive, isTrue);
  });

  test('login state transitions trigger lifecycle hooks once', () async {
    when(() => client.isLogged()).thenReturn(false);

    var onLoginInvoked = 0;
    var onLogoutInvoked = 0;

    final coordinator = SyncLifecycleCoordinator(
      gateway: gateway,
      sessionManager: sessionManager,
      roomManager: roomManager,
      loggingService: loggingService,
      pipeline: pipeline,
      onLogin: () async {
        onLoginInvoked += 1;
      },
      onLogout: () async {
        onLogoutInvoked += 1;
      },
    );

    await coordinator.initialize();

    when(() => client.isLogged()).thenReturn(true);
    when(() => sessionManager.isLoggedIn()).thenReturn(true);

    loginStateController.add(LoginState.loggedIn);
    await Future<void>.delayed(Duration.zero);

    loginStateController.add(LoginState.loggedIn);
    await Future<void>.delayed(Duration.zero);

    expect(onLoginInvoked, 1);
    expect(coordinator.isActive, isTrue);

    when(() => sessionManager.isLoggedIn()).thenReturn(false);
    when(() => client.isLogged()).thenReturn(false);
    when(() => pipeline.dispose()).thenAnswer((_) async {});

    loginStateController.add(LoginState.loggedOut);
    await Future<void>.delayed(Duration.zero);

    expect(onLogoutInvoked, 1);
    verify(() => pipeline.dispose()).called(1);
    expect(coordinator.isActive, isFalse);
  });

  test(
      'reconcileLifecycleState honours imperative session changes when no events fire',
      () async {
    when(() => client.isLogged()).thenReturn(false);

    final coordinator = SyncLifecycleCoordinator(
      gateway: gateway,
      sessionManager: sessionManager,
      roomManager: roomManager,
      loggingService: loggingService,
      pipeline: pipeline,
    );

    await coordinator.initialize();

    when(() => client.isLogged()).thenReturn(true);
    when(() => sessionManager.isLoggedIn()).thenReturn(true);

    await coordinator.reconcileLifecycleState();

    verify(() => pipeline.start()).called(1);
    expect(coordinator.isActive, isTrue);

    when(() => client.isLogged()).thenReturn(false);
    when(() => sessionManager.isLoggedIn()).thenReturn(false);

    await coordinator.reconcileLifecycleState();

    verify(() => pipeline.dispose()).called(1);
    expect(coordinator.isActive, isFalse);
  });

  test(
      '_handleLoggedOut waits for pending transition before triggering another',
      () async {
    when(() => client.isLogged()).thenReturn(true);
    when(() => sessionManager.isLoggedIn()).thenReturn(true);

    final coordinator = SyncLifecycleCoordinator(
      gateway: gateway,
      sessionManager: sessionManager,
      roomManager: roomManager,
      loggingService: loggingService,
      pipeline: pipeline,
    );

    await coordinator.initialize();

    when(() => pipeline.start()).thenAnswer((_) async {});
    await coordinator.reconcileLifecycleState();

    expect(coordinator.isActive, isTrue);

    final firstDeactivationCompleter = Completer<void>();
    when(() => pipeline.dispose()).thenAnswer((_) async {
      firstDeactivationCompleter.complete();
    });

    final pendingLogout = coordinator.reconcileLifecycleState();

    when(() => sessionManager.isLoggedIn()).thenReturn(false);
    await coordinator.reconcileLifecycleState();

    await pendingLogout;
    await firstDeactivationCompleter.future;

    verify(() => pipeline.dispose()).called(1);
  });
}
