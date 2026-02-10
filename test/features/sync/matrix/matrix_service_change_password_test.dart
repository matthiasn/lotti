import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_consumer.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoggingService extends Mock implements LoggingService {}

class _MockGateway extends Mock implements MatrixSyncGateway {}

class _MockMessageSender extends Mock implements MatrixMessageSender {}

class _MockJournalDb extends Mock implements JournalDb {}

class _MockSettingsDb extends Mock implements SettingsDb {}

class _MockReadMarkerService extends Mock implements SyncReadMarkerService {}

class _MockEventProcessor extends Mock implements SyncEventProcessor {}

class _MockSecureStorage extends Mock implements SecureStorage {}

class _MockRoomManager extends Mock implements SyncRoomManager {}

class _MockSessionManager extends Mock implements MatrixSessionManager {}

class _MockPipeline extends Mock implements MatrixStreamConsumer {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(StackTrace.current);
  });

  late _MockGateway gateway;
  late _MockSessionManager sessionManager;
  late _MockSecureStorage secureStorage;
  late _MockLoggingService logging;
  late MatrixService service;

  const existingConfig = MatrixConfig(
    homeServer: 'https://matrix.example.com',
    user: '@alice:example.com',
    password: 'old-password',
  );

  setUp(() {
    gateway = _MockGateway();
    sessionManager = _MockSessionManager();
    secureStorage = _MockSecureStorage();

    logging = _MockLoggingService();
    final sender = _MockMessageSender();
    final journalDb = _MockJournalDb();
    final settingsDb = _MockSettingsDb();
    final readMarkerService = _MockReadMarkerService();
    final eventProcessor = _MockEventProcessor();
    final roomManager = _MockRoomManager();
    final pipeline = _MockPipeline();

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
      journalDb: journalDb,
      settingsDb: settingsDb,
      readMarkerService: readMarkerService,
      eventProcessor: eventProcessor,
      secureStorage: secureStorage,
      sentEventRegistry: SentEventRegistry(),
      attachmentIndex: AttachmentIndex(logging: logging),
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
        () => logging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
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
        () => logging.captureException(
          any<Object>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'changePassword.persist',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
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
        () => logging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
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
        () => logging.captureException(
          any<Object>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'changePassword.persist',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
      verify(
        () => logging.captureException(
          any<Object>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'changePassword.rollback',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });
}
