import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/sync_engine.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';
// No internal SDK controllers in tests
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class MockRoomSummary extends Mock implements RoomSummary {}

void main() {
  setUpAll(() {
    registerFallbackValue(() async {});
  });

  late MockMatrixSessionManager sessionManager;
  late MockSyncRoomManager roomManager;
  late MockSyncLifecycleCoordinator lifecycleCoordinator;
  late MockDomainLogger loggingService;
  late SyncEngine engine;

  setUp(() {
    sessionManager = MockMatrixSessionManager();
    roomManager = MockSyncRoomManager();
    lifecycleCoordinator = MockSyncLifecycleCoordinator();
    // Mocks above (MatrixSessionManager / SyncRoomManager /
    // SyncLifecycleCoordinator) come from the centralized test/mocks/mocks.dart.
    loggingService = MockDomainLogger();

    engine = SyncEngine(
      sessionManager: sessionManager,
      roomManager: roomManager,
      lifecycleCoordinator: lifecycleCoordinator,
      loggingService: loggingService,
    );

    when(
      () => lifecycleCoordinator.updateHooks(
        onLogin: any(named: 'onLogin'),
        onLogout: any(named: 'onLogout'),
      ),
    ).thenReturn(null);
    when(() => lifecycleCoordinator.initialize()).thenAnswer((_) async {});
    when(
      () => lifecycleCoordinator.reconcileLifecycleState(),
    ).thenAnswer((_) async {});
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
    when(
      () => lifecycleCoordinator.reconcileLifecycleState(),
    ).thenAnswer((_) async {});

    await engine.initialize();

    verifyNever(() => lifecycleCoordinator.initialize());
    verify(() => lifecycleCoordinator.reconcileLifecycleState()).called(1);
  });

  test(
    'connect delegates to session manager and syncs lifecycle on success',
    () async {
      when(
        () => sessionManager.connect(
          shouldAttemptLogin: any(named: 'shouldAttemptLogin'),
        ),
      ).thenAnswer((invocation) async {
        final shouldAttemptLogin =
            invocation.namedArguments[#shouldAttemptLogin] as bool;
        return shouldAttemptLogin;
      });

      when(
        () => lifecycleCoordinator.reconcileLifecycleState(),
      ).thenAnswer((_) async {});

      final loginResult = await engine.connect(shouldAttemptLogin: true);
      expect(loginResult, isTrue);
      verify(
        () => sessionManager.connect(shouldAttemptLogin: true),
      ).called(1);
      verify(() => lifecycleCoordinator.reconcileLifecycleState()).called(1);

      final connectResult = await engine.connect(shouldAttemptLogin: false);
      expect(connectResult, isFalse);
    },
  );

  test('logout calls session manager and synchronises lifecycle', () async {
    when(() => sessionManager.logout()).thenAnswer((_) async {});
    when(
      () => lifecycleCoordinator.reconcileLifecycleState(),
    ).thenAnswer((_) async {});

    await engine.logout();

    verify(() => sessionManager.logout()).called(1);
    verify(() => lifecycleCoordinator.reconcileLifecycleState()).called(1);
  });

  test('dispose delegates to lifecycle coordinator', () async {
    await engine.dispose();
    verify(() => lifecycleCoordinator.dispose()).called(1);
  });

  test('diagnostics aggregates engine state and logs when requested', () async {
    final client = MockMatrixClient();
    final room = MockRoom();
    final summary = MockRoomSummary();

    when(() => sessionManager.client).thenReturn(client);
    when(() => sessionManager.isLoggedIn()).thenReturn(true);
    when(
      () => roomManager.loadPersistedRoomId(),
    ).thenAnswer((_) async => '!saved:server');
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
    when(
      () => client.onLoginStateChanged.value,
    ).thenReturn(LoginState.loggedIn);
    when(
      () => loggingService.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenReturn(null);

    final diagnostics = await engine.diagnostics();

    expect(diagnostics['deviceId'], 'device');
    expect(diagnostics['savedRoomId'], '!saved:server');
    expect(diagnostics['pipelineActive'], isTrue);
    verify(
      () => loggingService.log(
        LogDomain.sync,
        any<String>(),
        subDomain: 'diagnostics',
      ),
    ).called(1);

    clearInteractions(loggingService);
    await engine.diagnostics(log: false);
    verifyNever(
      () => loggingService.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any<String>(named: 'subDomain'),
      ),
    );
  });

  test(
    'connectWithLifecycleOption background lifecycle logs errors',
    () {
      when(
        () => sessionManager.connect(
          shouldAttemptLogin: any(named: 'shouldAttemptLogin'),
        ),
      ).thenAnswer((_) async => true);

      when(
        () => lifecycleCoordinator.reconcileLifecycleState(),
      ).thenThrow(Exception('background error'));

      when(
        () => loggingService.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});

      fakeAsync((async) {
        bool? result;
        unawaited(
          engine
              .connectWithLifecycleOption(
                shouldAttemptLogin: true,
                waitForLifecycle: false,
              )
              .then((value) => result = value),
        );

        // Drain the connect future and the fire-and-forget background lifecycle
        // closure, both of which complete via microtasks.
        async.flushMicrotasks();

        expect(result, isTrue);

        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'connect.backgroundLifecycle',
          ),
        ).called(1);
      });
    },
  );

  test('diagnostics handles client error gracefully', () async {
    when(() => sessionManager.client).thenThrow(Exception('client broken'));
    when(() => sessionManager.isLoggedIn()).thenReturn(false);
    when(() => lifecycleCoordinator.isActive).thenReturn(false);
    when(
      () => loggingService.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => loggingService.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenReturn(null);

    final diagnostics = await engine.diagnostics();

    expect(diagnostics['error'], contains('client broken'));
    expect(diagnostics['isLoggedIn'], isFalse);
    expect(diagnostics['pipelineActive'], isFalse);

    verify(
      () => loggingService.error(
        LogDomain.sync,
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: 'diagnostics.snapshot',
      ),
    ).called(1);
  });
}
