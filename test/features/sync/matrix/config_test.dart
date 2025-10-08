import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/config.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureStorage extends Mock implements SecureStorage {}

class MockMatrixSyncGateway extends Mock implements MatrixSyncGateway {}

class MockSyncRoomManager extends Mock implements SyncRoomManager {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  late MockSecureStorage mockSecureStorage;
  late MatrixSessionManager sessionManager;
  late MockMatrixSyncGateway mockGateway;
  late MockLoggingService mockLoggingService;

  setUp(() {
    mockSecureStorage = MockSecureStorage();
    mockGateway = MockMatrixSyncGateway();
    mockLoggingService = MockLoggingService();
    sessionManager = MatrixSessionManager(
      gateway: mockGateway,
      roomManager: MockSyncRoomManager(),
      loggingService: mockLoggingService,
    );
  });

  test('loadMatrixConfig returns cached value if already set', () async {
    const config = MatrixConfig(
      homeServer: 'https://example.org',
      user: '@user:example.org',
      password: 'pw',
    );
    sessionManager.matrixConfig = config;

    final result = await loadMatrixConfig(
      session: sessionManager,
      storage: mockSecureStorage,
    );

    expect(result, same(config));
    verifyNever(() => mockSecureStorage.read(key: matrixConfigKey));
  });

  test('loadMatrixConfig reads from secure storage when not cached', () async {
    const config = MatrixConfig(
      homeServer: 'https://example.org',
      user: '@user:example.org',
      password: 'pw',
    );
    when(() => mockSecureStorage.read(key: matrixConfigKey))
        .thenAnswer((_) async => jsonEncode(config));

    final result = await loadMatrixConfig(
      session: sessionManager,
      storage: mockSecureStorage,
    );

    expect(result, equals(config));
    expect(sessionManager.matrixConfig, equals(config));
  });

  test('loadMatrixConfig returns null when storage empty', () async {
    when(() => mockSecureStorage.read(key: matrixConfigKey))
        .thenAnswer((_) async => null);

    final result = await loadMatrixConfig(
      session: sessionManager,
      storage: mockSecureStorage,
    );

    expect(result, isNull);
    expect(sessionManager.matrixConfig, isNull);
  });

  test('setMatrixConfig persists config to secure storage', () async {
    const config = MatrixConfig(
      homeServer: 'https://example.org',
      user: '@user:example.org',
      password: 'pw',
    );
    when(() => mockSecureStorage.write(
          key: matrixConfigKey,
          value: jsonEncode(config),
        )).thenAnswer((_) async {});

    await setMatrixConfig(
      config,
      session: sessionManager,
      storage: mockSecureStorage,
    );

    expect(sessionManager.matrixConfig, equals(config));
    verify(
      () => mockSecureStorage.write(
        key: matrixConfigKey,
        value: jsonEncode(config),
      ),
    ).called(1);
  });

  test('deleteMatrixConfig clears persisted config and logs out', () async {
    const config = MatrixConfig(
      homeServer: 'https://example.org',
      user: '@user:example.org',
      password: 'pw',
    );
    sessionManager.matrixConfig = config;
    when(() => mockSecureStorage.delete(key: matrixConfigKey))
        .thenAnswer((_) async {});
    when(() => mockGateway.logout()).thenAnswer((_) async {});

    await deleteMatrixConfig(
      session: sessionManager,
      storage: mockSecureStorage,
    );

    expect(sessionManager.matrixConfig, isNull);
    verify(() => mockSecureStorage.delete(key: matrixConfigKey)).called(1);
    verify(() => mockGateway.logout()).called(1);
  });
}
