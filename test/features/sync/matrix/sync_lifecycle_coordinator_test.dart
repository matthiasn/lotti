// ignore_for_file: unnecessary_lambdas

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/matrix_timeline_listener.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_lifecycle_coordinator.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixSyncGateway extends Mock implements MatrixSyncGateway {}

class MockMatrixSessionManager extends Mock implements MatrixSessionManager {}

class MockMatrixTimelineListener extends Mock
    implements MatrixTimelineListener {}

class MockSyncRoomManager extends Mock implements SyncRoomManager {}

class MockLoggingService extends Mock implements LoggingService {}

class MockClient extends Mock implements Client {}

class MockTimeline extends Mock implements Timeline {}

class _FakeClient extends Fake implements Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeClient());
  });

  late MockMatrixSyncGateway gateway;
  late MockMatrixSessionManager sessionManager;
  late MockMatrixTimelineListener timelineListener;
  late MockSyncRoomManager roomManager;
  late MockLoggingService loggingService;
  late MockClient client;
  late StreamController<LoginState> loginStateController;

  setUp(() {
    gateway = MockMatrixSyncGateway();
    sessionManager = MockMatrixSessionManager();
    timelineListener = MockMatrixTimelineListener();
    roomManager = MockSyncRoomManager();
    loggingService = MockLoggingService();
    client = MockClient();
    loginStateController = StreamController<LoginState>.broadcast();

    when(() => gateway.loginStateChanges)
        .thenAnswer((_) => loginStateController.stream);
    when(() => sessionManager.client).thenReturn(client);
    when(() => sessionManager.isLoggedIn()).thenReturn(false);
    when(() => timelineListener.initialize()).thenAnswer((_) async {});
    when(() => timelineListener.start()).thenAnswer((_) async {});
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

  test('initialize primes timeline and handles already logged-in devices',
      () async {
    final timeline = MockTimeline();
    when(() => timelineListener.timeline).thenReturn(timeline);
    when(() => client.isLogged()).thenReturn(true);
    when(() => sessionManager.isLoggedIn()).thenReturn(true);

    var onLoginInvoked = 0;
    final coordinator = SyncLifecycleCoordinator(
      gateway: gateway,
      sessionManager: sessionManager,
      timelineListener: timelineListener,
      roomManager: roomManager,
      loggingService: loggingService,
      onLogin: () async {
        onLoginInvoked += 1;
      },
    );

    await coordinator.initialize();

    verify(() => timelineListener.initialize()).called(1);
    verify(() => roomManager.initialize()).called(1);
    verify(
      () => roomManager.hydrateRoomSnapshot(client: client),
    ).called(1);
    verify(() => timelineListener.start()).called(1);
    expect(onLoginInvoked, 1);
    expect(coordinator.isActive, isTrue);
  });

  test('login state transitions trigger lifecycle hooks once', () async {
    final timeline = MockTimeline();
    when(() => timelineListener.timeline).thenReturn(timeline);
    when(() => client.isLogged()).thenReturn(false);

    var onLoginInvoked = 0;
    var onLogoutInvoked = 0;

    final coordinator = SyncLifecycleCoordinator(
      gateway: gateway,
      sessionManager: sessionManager,
      timelineListener: timelineListener,
      roomManager: roomManager,
      loggingService: loggingService,
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

    final timelineInstance = MockTimeline();
    when(() => timelineListener.timeline).thenReturn(timelineInstance);
    when(() => sessionManager.isLoggedIn()).thenReturn(false);
    when(() => client.isLogged()).thenReturn(false);

    loginStateController.add(LoginState.loggedOut);
    await Future<void>.delayed(Duration.zero);

    expect(onLogoutInvoked, 1);
    verify(() => timelineInstance.cancelSubscriptions()).called(1);
    expect(coordinator.isActive, isFalse);
  });

  test(
      'reconcileLifecycleState honours imperative session changes when no events fire',
      () async {
    final timeline = MockTimeline();
    when(() => timelineListener.timeline).thenReturn(timeline);
    when(() => client.isLogged()).thenReturn(false);

    final coordinator = SyncLifecycleCoordinator(
      gateway: gateway,
      sessionManager: sessionManager,
      timelineListener: timelineListener,
      roomManager: roomManager,
      loggingService: loggingService,
    );

    await coordinator.initialize();

    when(() => client.isLogged()).thenReturn(true);
    when(() => sessionManager.isLoggedIn()).thenReturn(true);

    await coordinator.reconcileLifecycleState();

    verify(() => timelineListener.start()).called(1);
    expect(coordinator.isActive, isTrue);

    when(() => client.isLogged()).thenReturn(false);
    when(() => sessionManager.isLoggedIn()).thenReturn(false);

    await coordinator.reconcileLifecycleState();

    verify(() => timeline.cancelSubscriptions()).called(1);
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
      timelineListener: timelineListener,
      roomManager: roomManager,
      loggingService: loggingService,
    );

    await coordinator.initialize();

    when(() => timelineListener.start()).thenAnswer((_) async {});
    await coordinator.reconcileLifecycleState();

    expect(coordinator.isActive, isTrue);

    final timeline = MockTimeline();
    when(() => timelineListener.timeline).thenReturn(timeline);

    final firstDeactivationCompleter = Completer<void>();
    when(() => timeline.cancelSubscriptions()).thenAnswer((_) async {
      firstDeactivationCompleter.complete();
    });

    final pendingLogout = coordinator.reconcileLifecycleState();

    when(() => sessionManager.isLoggedIn()).thenReturn(false);
    await coordinator.reconcileLifecycleState();

    await pendingLogout;
    await firstDeactivationCompleter.future;

    verify(() => timeline.cancelSubscriptions()).called(1);
  });
}
