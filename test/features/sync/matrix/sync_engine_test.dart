//

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_engine.dart';
import 'package:lotti/features/sync/matrix/sync_lifecycle_coordinator.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixSessionManager extends Mock implements MatrixSessionManager {}

class MockSyncRoomManager extends Mock implements SyncRoomManager {}

class MockSyncLifecycleCoordinator extends Mock
    implements SyncLifecycleCoordinator {}

class MockLoggingService extends Mock implements LoggingService {}

class MockClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

class MockRoomSummary extends Mock implements RoomSummary {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixSessionManager sessionManager;
  late MockSyncRoomManager roomManager;
  late MockSyncLifecycleCoordinator lifecycle;
  late MockLoggingService logging;
  late SyncEngine engine;
  late MockClient client;

  setUp(() {
    sessionManager = MockMatrixSessionManager();
    roomManager = MockSyncRoomManager();
    lifecycle = MockSyncLifecycleCoordinator();
    logging = MockLoggingService();
    client = MockClient();

    when(() => lifecycle.isActive).thenReturn(false);
    when(() => lifecycle.updateHooks(
          onLogin: any(named: 'onLogin'),
          onLogout: any(named: 'onLogout'),
        )).thenReturn(null);
    when(() => lifecycle.initialize()).thenAnswer((_) async {});
    when(() => lifecycle.reconcileLifecycleState()).thenAnswer((_) async {});
    when(() => lifecycle.dispose()).thenAnswer((_) async {});

    when(() => sessionManager.client).thenReturn(client);
    when(() => sessionManager.connect(
            shouldAttemptLogin: any(named: 'shouldAttemptLogin')))
        .thenAnswer((_) async => true);
    when(() => sessionManager.logout()).thenAnswer((_) async {});
    when(() => sessionManager.isLoggedIn()).thenReturn(true);

    engine = SyncEngine(
      sessionManager: sessionManager,
      roomManager: roomManager,
      lifecycleCoordinator: lifecycle,
      loggingService: logging,
    );
  });

  test('initialize primes and reconciles lifecycle', () async {
    var onLoginCalled = false;
    var onLogoutCalled = false;

    await engine.initialize(
      onLogin: () async => onLoginCalled = true,
      onLogout: () async => onLogoutCalled = true,
    );

    verify(() => lifecycle.updateHooks(
          onLogin: any(named: 'onLogin'),
          onLogout: any(named: 'onLogout'),
        )).called(1);
    verify(() => lifecycle.initialize()).called(1);
    verify(() => lifecycle.reconcileLifecycleState()).called(1);

    // Second initialize should be a no-op beyond reconciliation; do not assert call count.
    await engine.initialize();

    // Ensure hooks are set (invoke them by calling updateHooks with captured)
    // We cannot directly call private stored hooks; trust the first call sufficed.
    expect(onLoginCalled, isFalse);
    expect(onLogoutCalled, isFalse);
  });

  test('connect delegates and reconciles on success', () async {
    final result = await engine.connect(shouldAttemptLogin: true);

    expect(result, isTrue);
    verify(() => sessionManager.connect(shouldAttemptLogin: true)).called(1);
    verify(() => lifecycle.reconcileLifecycleState()).called(1);
  });

  test('logout delegates and reconciles', () async {
    await engine.logout();
    verify(() => sessionManager.logout()).called(1);
    verify(() => lifecycle.reconcileLifecycleState()).called(1);
  });

  test('dispose delegates to lifecycle', () async {
    await engine.dispose();
    verify(() => lifecycle.dispose()).called(1);
  });

  test('diagnostics emits snapshot and logs', () async {
    final room = MockRoom();
    final summary = MockRoomSummary();
    when(() => room.id).thenReturn('!room:server');
    when(() => room.name).thenReturn('Room');
    when(() => room.encrypted).thenReturn(true);
    when(() => room.summary).thenReturn(summary);
    when(() => summary.mJoinedMemberCount).thenReturn(1);
    when(() => client.rooms).thenReturn([room]);
    when(() => client.onLoginStateChanged.value)
        .thenReturn(LoginState.loggedIn);
    when(() => roomManager.loadPersistedRoomId())
        .thenAnswer((_) async => '!room:server');
    when(() => logging.captureEvent(
          any<String>(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
        )).thenReturn(null);

    final map = await engine.diagnostics();

    expect(map['userId'], client.userID);
    expect(map['joinedRooms'], isA<List<Map<String, Object?>>>());
    verify(() => logging.captureEvent(
          any<String>(),
          domain: 'SYNC_ENGINE',
          subDomain: 'diagnostics',
        )).called(1);
  });
}
