import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class _MockGateway extends Mock implements MatrixSyncGateway {
  _MockGateway(this._client);
  final Client _client;

  @override
  Client get client => _client;
}

class _MockRoomManager extends Mock implements SyncRoomManager {}

class _MockClient extends Mock implements Client {}

void main() {
  late _MockGateway gateway;
  late _MockRoomManager roomManager;
  late LoggingService loggingService;
  late _MockClient client;
  late MatrixSessionManager sessionManager;

  const testConfig = MatrixConfig(
    homeServer: 'https://matrix.example.com',
    user: '@test:example.com',
    password: 'password123',
  );

  setUpAll(() {
    registerFallbackValue(
      const MatrixConfig(
        homeServer: 'https://fallback.example.com',
        user: '@fallback:example.com',
        password: 'fallback',
      ),
    );
    registerFallbackValue(_MockClient());
  });

  setUp(() {
    client = _MockClient();
    gateway = _MockGateway(client);
    roomManager = _MockRoomManager();
    loggingService = LoggingService();

    sessionManager = MatrixSessionManager(
      gateway: gateway,
      roomManager: roomManager,
      loggingService: loggingService,
    );
  });

  group('MatrixSessionManager', () {
    group('connect', () {
      test('returns false when matrixConfig is null', () async {
        sessionManager.matrixConfig = null;

        final result = await sessionManager.connect(shouldAttemptLogin: false);

        expect(result, isFalse);
        verifyNever(() => gateway.connect(any()));
      });

      test('connects to gateway with config', () async {
        sessionManager.matrixConfig = testConfig;
        when(() => gateway.connect(any())).thenAnswer((_) async {});
        when(() => client.isLogged()).thenReturn(true);
        when(
          () => roomManager.initialize(),
        ).thenAnswer((_) async {});
        when(
          () => roomManager.hydrateRoomSnapshot(client: any(named: 'client')),
        ).thenAnswer((_) async {});
        when(
          () => roomManager.loadPersistedRoomId(),
        ).thenAnswer((_) async => null);

        final result = await sessionManager.connect(shouldAttemptLogin: false);

        expect(result, isTrue);
        verify(() => gateway.connect(testConfig)).called(1);
      });

      test('does not login when shouldAttemptLogin is false', () async {
        sessionManager.matrixConfig = testConfig;
        when(() => gateway.connect(any())).thenAnswer((_) async {});
        when(() => client.isLogged()).thenReturn(true);
        when(
          () => roomManager.initialize(),
        ).thenAnswer((_) async {});
        when(
          () => roomManager.hydrateRoomSnapshot(client: any(named: 'client')),
        ).thenAnswer((_) async {});
        when(
          () => roomManager.loadPersistedRoomId(),
        ).thenAnswer((_) async => null);

        await sessionManager.connect(shouldAttemptLogin: false);

        verifyNever(
          () => gateway.login(
            any(),
            deviceDisplayName: any(named: 'deviceDisplayName'),
          ),
        );
      });

      test('returns false on exception', () async {
        sessionManager.matrixConfig = testConfig;
        when(
          () => gateway.connect(any()),
        ).thenThrow(Exception('connection failed'));

        final result = await sessionManager.connect(shouldAttemptLogin: false);

        expect(result, isFalse);
      });
    });

    test('isLoggedIn delegates to client', () {
      when(() => client.isLogged()).thenReturn(true);

      expect(sessionManager.isLoggedIn(), isTrue);

      when(() => client.isLogged()).thenReturn(false);

      expect(sessionManager.isLoggedIn(), isFalse);
    });

    test('logout delegates to gateway', () async {
      when(() => gateway.logout()).thenAnswer((_) async {});

      await sessionManager.logout();

      verify(() => gateway.logout()).called(1);
    });

    test('dispose delegates to gateway', () async {
      when(() => gateway.dispose()).thenAnswer((_) async {});

      await sessionManager.dispose();

      verify(() => gateway.dispose()).called(1);
    });

    test('client getter returns gateway client', () {
      expect(sessionManager.client, client);
    });

    test('roomManager getter returns injected room manager', () {
      expect(sessionManager.roomManager, roomManager);
    });

    test('matrixConfig can be set and read', () {
      expect(sessionManager.matrixConfig, isNull);

      sessionManager.matrixConfig = testConfig;

      expect(sessionManager.matrixConfig, testConfig);
    });

    test('deviceDisplayName can be set', () {
      sessionManager.deviceDisplayName = 'My Device';

      expect(sessionManager.deviceDisplayName, 'My Device');
    });
  });
}
