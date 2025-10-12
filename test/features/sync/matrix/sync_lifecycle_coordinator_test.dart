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

class MockGateway extends Mock implements MatrixSyncGateway {}

class MockSessionManager extends Mock implements MatrixSessionManager {}

class MockRoomManager extends Mock implements SyncRoomManager {}

class MockLoggingService extends Mock implements LoggingService {}

class MockPipeline extends Mock implements SyncPipeline {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGateway gateway;
  late MockSessionManager sessionManager;
  late MockRoomManager roomManager;
  late MockLoggingService logging;
  late MockPipeline pipeline;
  late StreamController<LoginState> loginStates;

  setUp(() {
    gateway = MockGateway();
    sessionManager = MockSessionManager();
    roomManager = MockRoomManager();
    logging = MockLoggingService();
    pipeline = MockPipeline();
    loginStates = StreamController<LoginState>.broadcast();

    when(() => gateway.loginStateChanges).thenAnswer((_) => loginStates.stream);
    when(() => sessionManager.isLoggedIn()).thenReturn(false);
    when(() => roomManager.initialize()).thenAnswer((_) async {});
    when(() => pipeline.initialize()).thenAnswer((_) async {});
    when(() => pipeline.start()).thenAnswer((_) async {});
    when(() => pipeline.dispose()).thenAnswer((_) async {});
    when(() => logging.captureEvent(
          any<String>(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
        )).thenReturn(null);
  });

  tearDown(() async {
    await loginStates.close();
  });

  test('initializes and activates when already logged in', () async {
    when(() => sessionManager.isLoggedIn()).thenReturn(true);

    var onLoginCalled = false;
    var onLogoutCalled = false;

    final coord = SyncLifecycleCoordinator(
      gateway: gateway,
      sessionManager: sessionManager,
      roomManager: roomManager,
      loggingService: logging,
      pipeline: pipeline,
      onLogin: () async => onLoginCalled = true,
      onLogout: () async => onLogoutCalled = true,
    );

    await coord.initialize();

    verify(() => pipeline.initialize()).called(1);
    verify(() => roomManager.initialize()).called(1);
    verify(() => pipeline.start()).called(1);
    expect(coord.isActive, isTrue);
    expect(onLoginCalled, isTrue);
    expect(onLogoutCalled, isFalse);
  });

  test('reacts to login state changes and disposes on logout', () async {
    when(() => sessionManager.isLoggedIn()).thenReturn(false);

    final coord = SyncLifecycleCoordinator(
      gateway: gateway,
      sessionManager: sessionManager,
      roomManager: roomManager,
      loggingService: logging,
      pipeline: pipeline,
    );

    await coord.initialize();
    verify(() => pipeline.initialize()).called(1);
    verify(() => roomManager.initialize()).called(1);
    expect(coord.isActive, isFalse);

    // Emit logged-in to activate
    loginStates.add(LoginState.loggedIn);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    verify(() => pipeline.start()).called(1);

    // Emit logged-out to deactivate
    loginStates.add(LoginState.loggedOut);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    verify(() => pipeline.dispose()).called(1);
  });
}
