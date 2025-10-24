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

class MockSyncRoomManager extends Mock implements SyncRoomManager {}

class MockLoggingService extends Mock implements LoggingService {}

class MockPipeline extends Mock implements SyncPipeline {}

class MockClient extends Mock implements Client {}

class _FakeClient extends Fake implements Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(_FakeClient());
  });

  group('SyncLifecycleCoordinator with V2 pipeline', () {
    late MockMatrixSyncGateway gateway;
    late MockMatrixSessionManager sessionManager;
    late MockSyncRoomManager roomManager;
    late MockLoggingService logging;
    late MockPipeline pipeline;
    late StreamController<LoginState> loginStates;

    SyncLifecycleCoordinator makeCoordinator() {
      return SyncLifecycleCoordinator(
        gateway: gateway,
        sessionManager: sessionManager,
        roomManager: roomManager,
        loggingService: logging,
        pipeline: pipeline,
      );
    }

    setUp(() {
      gateway = MockMatrixSyncGateway();
      sessionManager = MockMatrixSessionManager();
      roomManager = MockSyncRoomManager();
      logging = MockLoggingService();
      pipeline = MockPipeline();
      loginStates = StreamController<LoginState>.broadcast(sync: true);
      when(() => gateway.loginStateChanges)
          .thenAnswer((_) => loginStates.stream);

      when(() => roomManager.initialize()).thenAnswer((_) async {});
      when(() => roomManager.hydrateRoomSnapshot(
          client: any<Client>(named: 'client'))).thenAnswer((_) async {});
      when(() => sessionManager.client).thenReturn(MockClient());
      when(() => pipeline.initialize()).thenAnswer((_) async {});
      when(() => pipeline.start()).thenAnswer((_) async {});
      when(() => pipeline.dispose()).thenAnswer((_) async {});
      when(() => logging.captureEvent(any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'))).thenReturn(null);
      when(() => logging.captureException(any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);
    });

    tearDown(() async {
      await loginStates.close();
    });

    test(
        'initialize calls pipeline.initialize and activates if already logged in',
        () async {
      when(() => sessionManager.isLoggedIn()).thenReturn(true);
      final coord = makeCoordinator();

      await coord.initialize();

      verify(() => pipeline.initialize()).called(1);
      verify(() =>
              roomManager.hydrateRoomSnapshot(client: any(named: 'client')))
          .called(1);
      verify(() => pipeline.start()).called(1);
      expect(coord.isActive, isTrue);
    });

    test('reacts to login event and starts pipeline once', () async {
      when(() => sessionManager.isLoggedIn()).thenReturn(false);
      final coord = makeCoordinator();
      await coord.initialize();

      // Emit loggedIn twice rapidly
      loginStates
        ..add(LoginState.loggedIn)
        ..add(LoginState.loggedIn);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(() =>
              roomManager.hydrateRoomSnapshot(client: any(named: 'client')))
          .called(greaterThanOrEqualTo(1));
      verify(() => pipeline.start()).called(1);
      expect(coord.isActive, isTrue);
    });

    test('reacts to loggedOut and disposes pipeline', () async {
      when(() => sessionManager.isLoggedIn()).thenReturn(false);
      final coord = makeCoordinator();
      await coord.initialize();

      loginStates.add(LoginState.loggedIn);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      loginStates.add(LoginState.loggedOut);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      verify(() => pipeline.dispose()).called(1);
      expect(coord.isActive, isFalse);
    });

    test('logout before activation completes is ignored', () async {
      when(() => sessionManager.isLoggedIn()).thenReturn(false);
      final startCompleter = Completer<void>();
      when(() => pipeline.start()).thenAnswer((_) => startCompleter.future);

      final coord = makeCoordinator();
      await coord.initialize();

      loginStates
        ..add(LoginState.loggedIn)
        // Immediately log out before start completes
        ..add(LoginState.loggedOut);
      // Now complete start
      startCompleter.complete();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      // Because logout arrived while not active, coordinator does not queue a
      // deactivation. Activation completes and remains active.
      verifyNever(() => pipeline.dispose());
      expect(coord.isActive, isTrue);
    });

    test('dispose cancels subscription; further events ignored', () async {
      when(() => sessionManager.isLoggedIn()).thenReturn(false);
      final coord = makeCoordinator();
      await coord.initialize();
      await coord.dispose();

      // Emit an event after dispose; expect no calls
      clearInteractions(pipeline);
      loginStates.add(LoginState.loggedIn);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      verifyNever(() => pipeline.start());
      expect(coord.isActive, isFalse);
    });
  });
}
