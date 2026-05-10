import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _MockGateway extends Mock implements MatrixSyncGateway {
  _MockGateway(this._client);
  final Client _client;

  @override
  Client get client => _client;
}

class _MockRoomManager extends Mock implements SyncRoomManager {}

class _MockClient extends Mock implements Client {}

class _MockRoom extends Mock implements Room {}

class _GeneratedMatrixException extends Fake
    implements MatrixException, Exception {
  _GeneratedMatrixException(this.errcode);

  @override
  final String errcode;
}

enum _GeneratedSessionConfigKind { missing, present }

enum _GeneratedSessionConnectKind { succeeds, throwsError }

enum _GeneratedSessionLoginKind { alreadyLoggedIn, loggedOut }

enum _GeneratedSessionRoomKind { none, cached, missingFromClient }

enum _GeneratedSessionJoinKind { succeeds, forbidden, notFound, genericError }

class _GeneratedSessionScenario {
  const _GeneratedSessionScenario({
    required this.configKind,
    required this.connectKind,
    required this.loginKind,
    required this.shouldAttemptLogin,
    required this.roomKind,
    required this.joinKind,
  });

  final _GeneratedSessionConfigKind configKind;
  final _GeneratedSessionConnectKind connectKind;
  final _GeneratedSessionLoginKind loginKind;
  final bool shouldAttemptLogin;
  final _GeneratedSessionRoomKind roomKind;
  final _GeneratedSessionJoinKind joinKind;

  bool get hasConfig => configKind == _GeneratedSessionConfigKind.present;

  bool get connectSucceeds =>
      connectKind == _GeneratedSessionConnectKind.succeeds;

  bool get initiallyLoggedIn =>
      loginKind == _GeneratedSessionLoginKind.alreadyLoggedIn;

  bool get attemptsLogin =>
      hasConfig && connectSucceeds && !initiallyLoggedIn && shouldAttemptLogin;

  bool get loggedInAfterConnect => initiallyLoggedIn || attemptsLogin;

  bool get expectsSuccess => hasConfig && connectSucceeds;

  bool get expectsHydrate => expectsSuccess && loggedInAfterConnect;

  bool get expectsJoin =>
      expectsHydrate && roomKind == _GeneratedSessionRoomKind.missingFromClient;

  bool get expectsClear =>
      expectsJoin &&
      (joinKind == _GeneratedSessionJoinKind.forbidden ||
          joinKind == _GeneratedSessionJoinKind.notFound);

  Never throwJoinError() {
    switch (joinKind) {
      case _GeneratedSessionJoinKind.succeeds:
        throw StateError('not used');
      case _GeneratedSessionJoinKind.forbidden:
        throw _GeneratedMatrixException('M_FORBIDDEN');
      case _GeneratedSessionJoinKind.notFound:
        throw _GeneratedMatrixException('M_NOT_FOUND');
      case _GeneratedSessionJoinKind.genericError:
        throw StateError('join failed');
    }
  }

  @override
  String toString() {
    return '_GeneratedSessionScenario('
        'configKind: $configKind, '
        'connectKind: $connectKind, '
        'loginKind: $loginKind, '
        'shouldAttemptLogin: $shouldAttemptLogin, '
        'roomKind: $roomKind, '
        'joinKind: $joinKind'
        ')';
  }
}

extension _AnyGeneratedSessionScenario on glados.Any {
  glados.Generator<_GeneratedSessionConfigKind> get sessionConfigKind =>
      glados.AnyUtils(this).choose(_GeneratedSessionConfigKind.values);

  glados.Generator<_GeneratedSessionConnectKind> get sessionConnectKind =>
      glados.AnyUtils(this).choose(_GeneratedSessionConnectKind.values);

  glados.Generator<_GeneratedSessionLoginKind> get sessionLoginKind =>
      glados.AnyUtils(this).choose(_GeneratedSessionLoginKind.values);

  glados.Generator<_GeneratedSessionRoomKind> get sessionRoomKind =>
      glados.AnyUtils(this).choose(_GeneratedSessionRoomKind.values);

  glados.Generator<_GeneratedSessionJoinKind> get sessionJoinKind =>
      glados.AnyUtils(this).choose(_GeneratedSessionJoinKind.values);

  glados.Generator<_GeneratedSessionScenario> get sessionScenario =>
      glados.CombinableAny(this).combine6(
        sessionConfigKind,
        sessionConnectKind,
        sessionLoginKind,
        glados.BoolAny(this).bool,
        sessionRoomKind,
        sessionJoinKind,
        (
          _GeneratedSessionConfigKind configKind,
          _GeneratedSessionConnectKind connectKind,
          _GeneratedSessionLoginKind loginKind,
          bool shouldAttemptLogin,
          _GeneratedSessionRoomKind roomKind,
          _GeneratedSessionJoinKind joinKind,
        ) => _GeneratedSessionScenario(
          configKind: configKind,
          connectKind: connectKind,
          loginKind: loginKind,
          shouldAttemptLogin: shouldAttemptLogin,
          roomKind: roomKind,
          joinKind: joinKind,
        ),
      );
}

void main() {
  late _MockGateway gateway;
  late _MockRoomManager roomManager;
  late MockLoggingService loggingService;
  late _MockClient client;
  late MatrixSessionManager sessionManager;

  const testConfig = MatrixConfig(
    homeServer: 'https://matrix.example.com',
    user: '@test:example.com',
    password: 'password123',
  );

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
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
    loggingService = MockLoggingService();
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
        stackTrace: any<StackTrace>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});

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
        when(() => client.isLogged()).thenReturn(false);
        when(
          () => roomManager.initialize(),
        ).thenAnswer((_) async {});

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

      glados.Glados(
        glados.any.sessionScenario,
        glados.ExploreConfig(numRuns: 180),
      ).test('generated connect matrix preserves room recovery semantics', (
        scenario,
      ) async {
        const persistedRoomId = '!persisted:example.org';
        final client = _MockClient();
        final gateway = _MockGateway(client);
        final roomManager = _MockRoomManager();
        final loggingService = MockLoggingService();
        final sessionManager = MatrixSessionManager(
          gateway: gateway,
          roomManager: roomManager,
          loggingService: loggingService,
        );
        final room = _MockRoom();
        var loginCalled = false;

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
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).thenAnswer((_) async {});

        sessionManager
          ..matrixConfig = scenario.hasConfig ? testConfig : null
          ..deviceDisplayName = 'Generated Test Device';
        when(client.isLogged).thenAnswer(
          (_) => scenario.initiallyLoggedIn || loginCalled,
        );
        when(() => gateway.connect(any())).thenAnswer((_) async {
          if (!scenario.connectSucceeds) {
            throw StateError('connect failed');
          }
        });
        when(
          () => gateway.login(
            any(),
            deviceDisplayName: any(named: 'deviceDisplayName'),
          ),
        ).thenAnswer((_) async {
          loginCalled = true;
          return null;
        });
        when(roomManager.initialize).thenAnswer((_) async {});
        when(
          () => roomManager.hydrateRoomSnapshot(
            client: any(named: 'client'),
          ),
        ).thenAnswer((_) async {});
        when(roomManager.loadPersistedRoomId).thenAnswer((_) async {
          return scenario.roomKind == _GeneratedSessionRoomKind.none
              ? null
              : persistedRoomId;
        });
        when(() => client.getRoomById(persistedRoomId)).thenAnswer((_) {
          return scenario.roomKind == _GeneratedSessionRoomKind.cached
              ? room
              : null;
        });
        when(() => roomManager.joinRoom(persistedRoomId)).thenAnswer((_) async {
          if (scenario.joinKind != _GeneratedSessionJoinKind.succeeds) {
            scenario.throwJoinError();
          }
          return room;
        });
        when(
          () => roomManager.clearPersistedRoom(
            subDomain: any(named: 'subDomain'),
          ),
        ).thenAnswer((_) async {});
        final result = await sessionManager.connect(
          shouldAttemptLogin: scenario.shouldAttemptLogin,
        );

        expect(result, scenario.expectsSuccess, reason: '$scenario');
        if (!scenario.hasConfig) {
          verifyNever(() => gateway.connect(any()));
        } else {
          verify(() => gateway.connect(testConfig)).called(1);
        }
        if (scenario.attemptsLogin) {
          verify(
            () => gateway.login(
              testConfig,
              deviceDisplayName: any(named: 'deviceDisplayName'),
            ),
          ).called(1);
        } else {
          verifyNever(
            () => gateway.login(
              any(),
              deviceDisplayName: any(named: 'deviceDisplayName'),
            ),
          );
        }
        if (scenario.expectsSuccess) {
          verify(roomManager.initialize).called(1);
        } else {
          verifyNever(roomManager.initialize);
        }
        if (scenario.expectsHydrate) {
          verify(
            () => roomManager.hydrateRoomSnapshot(
              client: any(named: 'client'),
            ),
          ).called(1);
          verify(roomManager.loadPersistedRoomId).called(1);
        } else {
          verifyNever(
            () => roomManager.hydrateRoomSnapshot(
              client: any(named: 'client'),
            ),
          );
          verifyNever(roomManager.loadPersistedRoomId);
        }
        if (scenario.expectsJoin) {
          verify(() => roomManager.joinRoom(persistedRoomId)).called(1);
        } else {
          verifyNever(() => roomManager.joinRoom(any()));
        }
        if (scenario.expectsClear) {
          verify(
            () => roomManager.clearPersistedRoom(
              subDomain: 'connect.join.clear',
            ),
          ).called(1);
        } else {
          verifyNever(
            () => roomManager.clearPersistedRoom(
              subDomain: any(named: 'subDomain'),
            ),
          );
        }
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
