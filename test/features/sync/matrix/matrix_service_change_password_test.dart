import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(StackTrace.current);
  });

  late MockMatrixSyncGateway gateway;
  late MockMatrixSessionManager sessionManager;
  late MockSecureStorage secureStorage;
  late MockDomainLogger logging;
  late MatrixService service;

  const existingConfig = MatrixConfig(
    homeServer: 'https://matrix.example.com',
    user: '@alice:example.com',
    password: 'old-password',
  );

  setUp(() {
    gateway = MockMatrixSyncGateway();
    sessionManager = MockMatrixSessionManager();
    secureStorage = MockSecureStorage();

    logging = MockDomainLogger();
    final sender = MockMatrixMessageSender();
    final settingsDb = MockSettingsDb();
    final eventProcessor = MockSyncEventProcessor();
    final roomManager = MockSyncRoomManager();
    final pipeline = MockMatrixStreamConsumer();
    final queueCoordinator = MockQueuePipelineCoordinator();
    when(queueCoordinator.start).thenAnswer((_) async {});
    when(() => queueCoordinator.isRunning).thenReturn(false);
    when(
      () => queueCoordinator.stop(drainFirst: any(named: 'drainFirst')),
    ).thenAnswer((_) async {});

    // Default stubs for disposal
    when(() => sessionManager.dispose()).thenAnswer((_) async {});
    when(roomManager.dispose).thenAnswer((_) async {});

    // Stub gateway changePassword
    when(
      () => gateway.changePassword(
        oldPassword: any(named: 'oldPassword'),
        newPassword: any(named: 'newPassword'),
      ),
    ).thenAnswer((_) async {});

    // Stub secure storage for setConfig
    when(
      () => secureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});

    service = MatrixService(
      gateway: gateway,
      loggingService: logging,
      activityGate: UserActivityGate(activityService: UserActivityService()),
      messageSender: sender,
      settingsDb: settingsDb,
      eventProcessor: eventProcessor,
      secureStorage: secureStorage,
      queueCoordinator: queueCoordinator,
      roomManager: roomManager,
      sessionManager: sessionManager,
      pipelineOverride: pipeline,
    );
  });

  group('MatrixService.changePassword', () {
    test('delegates to gateway and updates stored config', () async {
      // Set up session manager with existing config
      when(() => sessionManager.matrixConfig).thenReturn(existingConfig);

      await service.changePassword(
        oldPassword: 'old-password',
        newPassword: 'new-password',
      );

      // Verify gateway was called
      verify(
        () => gateway.changePassword(
          oldPassword: 'old-password',
          newPassword: 'new-password',
        ),
      ).called(1);

      // Verify config was updated with new password via setConfig
      final captured = verify(
        () => secureStorage.write(
          key: matrixConfigKey,
          value: captureAny(named: 'value'),
        ),
      ).captured;

      final storedJson =
          jsonDecode(captured.first as String) as Map<String, dynamic>;
      final storedConfig = MatrixConfig.fromJson(storedJson);
      expect(storedConfig.password, 'new-password');
      expect(storedConfig.homeServer, existingConfig.homeServer);
      expect(storedConfig.user, existingConfig.user);
    });

    test('skips setConfig when loadConfig returns null', () async {
      // No config stored - session manager returns null
      when(() => sessionManager.matrixConfig).thenReturn(null);
      when(
        () => secureStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => null);

      await service.changePassword(
        oldPassword: 'old-password',
        newPassword: 'new-password',
      );

      // Gateway should still be called
      verify(
        () => gateway.changePassword(
          oldPassword: 'old-password',
          newPassword: 'new-password',
        ),
      ).called(1);

      // setConfig should NOT have been called (no config to update)
      verifyNever(
        () => secureStorage.write(
          key: matrixConfigKey,
          value: any(named: 'value'),
        ),
      );
    });

    test('rolls back password when config persist fails', () async {
      when(() => sessionManager.matrixConfig).thenReturn(existingConfig);

      // Make the write (setConfig) throw to simulate persist failure
      when(
        () => secureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenThrow(Exception('Storage write failed'));

      // Stub logging
      when(
        () => logging.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});

      await expectLater(
        service.changePassword(
          oldPassword: 'old-password',
          newPassword: 'new-password',
        ),
        throwsA(isA<Exception>()),
      );

      // Verify rollback was attempted: gateway called twice
      // (once for original change, once for rollback)
      verify(
        () => gateway.changePassword(
          oldPassword: 'old-password',
          newPassword: 'new-password',
        ),
      ).called(1);
      verify(
        () => gateway.changePassword(
          oldPassword: 'new-password',
          newPassword: 'old-password',
        ),
      ).called(1);

      // Verify persist error was logged
      verify(
        () => logging.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'changePassword.persist',
        ),
      ).called(1);
    });

    test('logs critical when both persist and rollback fail', () async {
      when(() => sessionManager.matrixConfig).thenReturn(existingConfig);

      // Make the write (setConfig) throw to simulate persist failure
      when(
        () => secureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenThrow(Exception('Storage write failed'));

      // Make rollback also fail
      var callCount = 0;
      when(
        () => gateway.changePassword(
          oldPassword: any(named: 'oldPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenAnswer((_) async {
        callCount++;
        if (callCount > 1) {
          throw Exception('Rollback failed');
        }
      });

      // Stub logging
      when(
        () => logging.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});

      await expectLater(
        service.changePassword(
          oldPassword: 'old-password',
          newPassword: 'new-password',
        ),
        throwsA(isA<Exception>()),
      );

      // Verify both persist and rollback errors were logged
      verify(
        () => logging.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'changePassword.persist',
        ),
      ).called(1);
      verify(
        () => logging.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: 'changePassword.rollback',
        ),
      ).called(1);
    });
  });
}
