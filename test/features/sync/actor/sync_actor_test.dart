import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/actor/outbound_queue.dart';
import 'package:lotti/features/sync/actor/sync_actor.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart'
    as matrix_cached;
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

abstract interface class CachedStreamController<T> {
  T? get value;
  Stream<T> get stream;
}

class MockLoginStateController extends Mock
    implements CachedStreamController<LoginState> {}

/// Fake outbound queue that returns a scripted sequence of [drain] delays.
///
/// Each call to [drain] consumes the next entry from [_delays]; once the list
/// is exhausted it returns `null` so the actor's drain loop terminates.
class _ScriptedOutboundQueue extends OutboundQueue {
  _ScriptedOutboundQueue({
    required super.syncDatabase,
    required super.gateway,
    required super.emitEvent,
    required List<Duration?> delays,
  })
    // ignore: prefer_initializing_formals
    : _delays = delays;

  final List<Duration?> _delays;
  int drainCalls = 0;

  /// Completes once the scripted delay list has been fully consumed, letting
  /// tests await the drain loop deterministically without arbitrary delays.
  final Completer<void> exhausted = Completer<void>();

  void _completeExhausted() {
    if (!exhausted.isCompleted) {
      exhausted.complete();
    }
  }

  @override
  Future<Duration?> drain() async {
    drainCalls++;
    if (_delays.isEmpty) {
      _completeExhausted();
      return null;
    }
    // Complete the signal before removing the final entry so tests awaiting
    // [exhausted] observe completion exactly when the last delay is returned.
    if (_delays.length == 1) {
      _completeExhausted();
    }
    return _delays.removeAt(0);
  }
}

/// Creates a [SyncActorCommandHandler] with a mock gateway factory.
///
/// The [onGatewayCreated] callback receives the mock gateway after creation,
/// allowing tests to set up stubs before commands use it.
SyncActorCommandHandler createTestHandler({
  void Function(MockMatrixSdkGateway gateway, MockMatrixClient client)?
  onGatewayCreated,
  SyncDatabase Function(String dbRootPath)? syncDatabaseFactory,
  void Function(SyncDatabase db)? onSyncDatabaseCreated,
  bool enableLogging = false,
  int verificationPeerDiscoveryAttempts = 8,
  Duration verificationPeerDiscoveryInterval = const Duration(
    milliseconds: 500,
  ),
  Stream<LoginState>? loginStateChanges,
  Stream<KeyVerification>? keyVerificationRequests,
  Stream<SyncUpdate>? syncUpdateStream,
  Stream<ToDeviceEvent>? toDeviceEventStream,
  Stream<Event>? timelineEventStream,
  bool useDefaultToDeviceStreamFactory = false,
  bool useDefaultTimelineStreamFactory = false,
  bool useDefaultSyncDatabaseFactory = false,
  OutboundQueueFactory? outboundQueueFactory,
}) {
  late MockMatrixSdkGateway mockGateway;
  final mockClient = MockMatrixClient();
  final defaultLoginStateController = MockLoginStateController();
  final defaultSyncUpdateStreamController =
      StreamController<SyncUpdate>.broadcast();
  final defaultToDeviceStreamController =
      StreamController<ToDeviceEvent>.broadcast();
  final defaultTimelineEventStreamController =
      StreamController<Event>.broadcast();

  return SyncActorCommandHandler(
    createMatrixClientFactory:
        ({
          required Directory documentsDirectory,
          String? deviceDisplayName,
          String? dbName,
        }) async {
          return mockClient;
        },
    gatewayFactory:
        ({
          required Client client,
          required SentEventRegistry sentEventRegistry,
        }) {
          mockGateway = MockMatrixSdkGateway();

          when(
            () => defaultLoginStateController.value,
          ).thenReturn(LoginState.loggedIn);
          when(() => defaultLoginStateController.stream).thenAnswer(
            (_) => loginStateChanges ?? const Stream.empty(),
          );

          when(() => mockClient.userID).thenReturn('@test:localhost');
          when(() => mockClient.deviceID).thenReturn('DEV');
          // ignore: unnecessary_lambdas
          when(() => mockClient.abortSync()).thenAnswer((_) async {});
          when(() => mockClient.syncPending).thenReturn(false);
          when(() => mockClient.encryptionEnabled).thenReturn(false);
          when(
            () => mockClient.userDeviceKeys,
          ).thenReturn(<String, DeviceKeysList>{});
          when(
            () => mockClient.userOwnsEncryptionKeys(any()),
          ).thenAnswer((_) async => false);
          when(() => mockClient.userDeviceKeysLoading).thenAnswer((_) async {});
          when(() => mockClient.rooms).thenReturn(<Room>[]);
          when(
            () => mockClient.updateUserDeviceKeys(
              additionalUsers: any(named: 'additionalUsers'),
            ),
          ).thenAnswer((_) async {});
          // ignore: unnecessary_lambdas
          when(() => mockClient.dispose()).thenAnswer((_) async {});

          // Default stubs
          when(() => mockGateway.connect(any())).thenAnswer((_) async {});
          when(
            () => mockGateway.login(
              any(),
              deviceDisplayName: any(named: 'deviceDisplayName'),
            ),
          ).thenAnswer((_) async {
            return LoginResponse.fromJson({
              'user_id': '@test:localhost',
              'device_id': 'DEV',
              'access_token': 'tok',
            });
          });
          when(
            () => mockGateway.loginStateChanges,
          ).thenAnswer((_) => defaultLoginStateController.stream);
          when(
            () => mockGateway.keyVerificationRequests,
          ).thenAnswer((_) => keyVerificationRequests ?? const Stream.empty());
          when(
            () => mockGateway.unverifiedDevices(),
          ).thenReturn(const <DeviceKeys>[]);
          when(() => mockGateway.client).thenReturn(mockClient);
          when(() => mockGateway.dispose()).thenAnswer((_) async {
            await mockClient.dispose();
          });

          onGatewayCreated?.call(mockGateway, mockClient);
          // Ensure identity fields are always available even when callbacks configure
          // additional client-level stubs.
          when(() => mockClient.userID).thenReturn('@test:localhost');
          when(() => mockClient.deviceID).thenReturn('DEV');

          return mockGateway;
        },
    syncUpdateStreamFactory: (Client _) =>
        syncUpdateStream ?? defaultSyncUpdateStreamController.stream,
    toDeviceEventStreamFactory: useDefaultToDeviceStreamFactory
        ? null
        : (Client _) =>
              toDeviceEventStream ?? defaultToDeviceStreamController.stream,
    timelineEventStreamFactory: useDefaultTimelineStreamFactory
        ? null
        : (Client _) =>
              timelineEventStream ??
              defaultTimelineEventStreamController.stream,
    syncDatabaseFactory: useDefaultSyncDatabaseFactory
        ? null
        : (String dbRootPath) {
            final db =
                syncDatabaseFactory?.call(dbRootPath) ??
                SyncDatabase(inMemoryDatabase: true);
            onSyncDatabaseCreated?.call(db);
            return db;
          },
    outboundQueueFactory: outboundQueueFactory,
    verificationPeerDiscoveryAttempts: verificationPeerDiscoveryAttempts,
    verificationPeerDiscoveryInterval: verificationPeerDiscoveryInterval,
    vodInitializer: () async {},
    enableLogging: enableLogging,
    retryBaseDelay: Duration.zero,
  );
}

Map<String, Object?> _cmd(
  String command, [
  Map<String, Object?>? extra,
]) {
  return <String, Object?>{
    'command': command,
    ...?extra,
  };
}

Map<String, Object?> _initPayload({
  String homeServer = 'http://localhost:8008',
  String user = '@test:localhost',
  String password = 'pass',
  String dbRootPath = '/tmp/test_sync_actor',
  String deviceDisplayName = 'TestDevice',
  SendPort? eventPort,
}) {
  return <String, Object?>{
    'command': 'init',
    'homeServer': homeServer,
    'user': user,
    'password': password,
    'dbRootPath': dbRootPath,
    'deviceDisplayName': deviceDisplayName,
    'eventPort': ?eventPort,
  };
}

enum _GeneratedActorCommandKind {
  ping,
  getHealth,
  initValid,
  initMissingUser,
  startSync,
  stopSync,
  kickOutbox,
  connectivityTrue,
  connectivityInvalid,
  stop,
  unknown,
}

class _GeneratedActorExpectation {
  const _GeneratedActorExpectation({
    required this.ok,
    required this.nextState,
    this.errorCode,
  });

  final bool ok;
  final SyncActorState nextState;
  final String? errorCode;
}

class _GeneratedActorCommand {
  const _GeneratedActorCommand({
    required this.kind,
    required this.slot,
  });

  final _GeneratedActorCommandKind kind;
  final int slot;

  String requestIdAt(int index) => 'generated-$index-$slot';

  Map<String, Object?> commandAt({
    required int index,
    required String dbRootPath,
  }) {
    final requestId = requestIdAt(index);
    switch (kind) {
      case _GeneratedActorCommandKind.ping:
        return _cmd('ping', {'requestId': requestId});
      case _GeneratedActorCommandKind.getHealth:
        return _cmd('getHealth', {'requestId': requestId});
      case _GeneratedActorCommandKind.initValid:
        return {
          ..._initPayload(
            dbRootPath: dbRootPath,
            deviceDisplayName: 'GeneratedDevice$slot',
          ),
          'requestId': requestId,
        };
      case _GeneratedActorCommandKind.initMissingUser:
        final payload = {
          ..._initPayload(
            dbRootPath: dbRootPath,
            deviceDisplayName: 'GeneratedDevice$slot',
          ),
          'requestId': requestId,
        }..remove('user');
        return payload;
      case _GeneratedActorCommandKind.startSync:
        return _cmd('startSync', {'requestId': requestId});
      case _GeneratedActorCommandKind.stopSync:
        return _cmd('stopSync', {'requestId': requestId});
      case _GeneratedActorCommandKind.kickOutbox:
        return _cmd('kickOutbox', {'requestId': requestId});
      case _GeneratedActorCommandKind.connectivityTrue:
        return _cmd(
          'connectivityChanged',
          {'requestId': requestId, 'connected': true},
        );
      case _GeneratedActorCommandKind.connectivityInvalid:
        return _cmd(
          'connectivityChanged',
          {'requestId': requestId, 'connected': 'yes'},
        );
      case _GeneratedActorCommandKind.stop:
        return _cmd('stop', {'requestId': requestId});
      case _GeneratedActorCommandKind.unknown:
        return _cmd('unknown-$slot', {'requestId': requestId});
    }
  }

  _GeneratedActorExpectation expectation(SyncActorState state) {
    switch (kind) {
      case _GeneratedActorCommandKind.ping:
      case _GeneratedActorCommandKind.getHealth:
        return _GeneratedActorExpectation(ok: true, nextState: state);
      case _GeneratedActorCommandKind.initValid:
        if (state == SyncActorState.uninitialized) {
          return const _GeneratedActorExpectation(
            ok: true,
            nextState: SyncActorState.syncing,
          );
        }
        return _invalidStateExpectation(state);
      case _GeneratedActorCommandKind.initMissingUser:
        if (state == SyncActorState.uninitialized) {
          return const _GeneratedActorExpectation(
            ok: false,
            nextState: SyncActorState.uninitialized,
            errorCode: 'MISSING_PARAMETER',
          );
        }
        return _invalidStateExpectation(state);
      case _GeneratedActorCommandKind.startSync:
        if (state == SyncActorState.syncing) {
          return const _GeneratedActorExpectation(
            ok: true,
            nextState: SyncActorState.syncing,
          );
        }
        if (state == SyncActorState.idle) {
          return const _GeneratedActorExpectation(
            ok: true,
            nextState: SyncActorState.syncing,
          );
        }
        return _invalidStateExpectation(state);
      case _GeneratedActorCommandKind.stopSync:
        if (state == SyncActorState.syncing) {
          return const _GeneratedActorExpectation(
            ok: true,
            nextState: SyncActorState.idle,
          );
        }
        if (state == SyncActorState.idle) {
          return const _GeneratedActorExpectation(
            ok: true,
            nextState: SyncActorState.idle,
          );
        }
        return _invalidStateExpectation(state);
      case _GeneratedActorCommandKind.kickOutbox:
      case _GeneratedActorCommandKind.connectivityTrue:
        if (state == SyncActorState.idle || state == SyncActorState.syncing) {
          return _GeneratedActorExpectation(ok: true, nextState: state);
        }
        return _invalidStateExpectation(state);
      case _GeneratedActorCommandKind.connectivityInvalid:
        if (state == SyncActorState.idle || state == SyncActorState.syncing) {
          return _GeneratedActorExpectation(
            ok: false,
            nextState: state,
            errorCode: 'INVALID_PARAMETER',
          );
        }
        return _invalidStateExpectation(state);
      case _GeneratedActorCommandKind.stop:
        if (state == SyncActorState.disposed) {
          return _invalidStateExpectation(state);
        }
        return const _GeneratedActorExpectation(
          ok: true,
          nextState: SyncActorState.disposed,
        );
      case _GeneratedActorCommandKind.unknown:
        return _GeneratedActorExpectation(
          ok: false,
          nextState: state,
          errorCode: 'UNKNOWN_COMMAND',
        );
    }
  }

  _GeneratedActorExpectation _invalidStateExpectation(SyncActorState state) {
    return _GeneratedActorExpectation(
      ok: false,
      nextState: state,
      errorCode: 'INVALID_STATE',
    );
  }

  @override
  String toString() {
    return '_GeneratedActorCommand(kind: $kind, slot: $slot)';
  }
}

class _GeneratedActorCommandScenario {
  const _GeneratedActorCommandScenario(this.commands);

  final List<_GeneratedActorCommand> commands;

  @override
  String toString() => '_GeneratedActorCommandScenario($commands)';
}

extension _AnyGeneratedActorCommandScenario on glados.Any {
  glados.Generator<_GeneratedActorCommandKind> get actorCommandKind =>
      glados.AnyUtils(this).choose(_GeneratedActorCommandKind.values);

  glados.Generator<_GeneratedActorCommand> get actorCommand =>
      glados.CombinableAny(this).combine2(
        actorCommandKind,
        glados.IntAnys(this).intInRange(0, 12),
        (
          _GeneratedActorCommandKind kind,
          int slot,
        ) => _GeneratedActorCommand(kind: kind, slot: slot),
      );

  glados.Generator<_GeneratedActorCommandScenario> get actorCommandScenario =>
      glados.ListAnys(this)
          .listWithLengthInRange(1, 20, actorCommand)
          .map(_GeneratedActorCommandScenario.new);
}

/// Stubs the standard remote device used across the verification tests.
void stubRemoteDevice(MockDeviceKeys remoteDevice) {
  when(() => remoteDevice.deviceId).thenReturn('REMOTE');
  when(() => remoteDevice.verified).thenReturn(false);
}

/// Stubs the four read-only verification fields every flow test needs.
void stubVerificationReads(MockKeyVerification verification) {
  when(
    () => verification.lastStep,
  ).thenReturn('m.key.verification.ready');
  when(() => verification.sasEmojis).thenReturn(<KeyVerificationEmoji>[]);
  when(() => verification.isDone).thenReturn(false);
  when(() => verification.canceled).thenReturn(false);
}

/// Wires the client's identity + device-key map to [keysList] holding
/// [remoteDevice] — the shared shape of the verification gateway setup.
void stubClientDeviceKeys(
  MockMatrixClient c,
  MockDeviceKeysList keysList,
  MockDeviceKeys remoteDevice,
) {
  when(() => c.userID).thenReturn('@test:localhost');
  when(() => c.deviceID).thenReturn('DEV');
  when(() => c.userDeviceKeys).thenReturn({
    '@test:localhost': keysList,
  });
  when(() => keysList.deviceKeys).thenReturn(
    <String, DeviceKeys>{'REMOTE': remoteDevice},
  );
  when(() => c.userOwnsEncryptionKeys(any())).thenAnswer((_) async {
    return false;
  });
  when(() => c.userDeviceKeysLoading).thenAnswer((_) async {});
}

void main() {
  late SyncActorCommandHandler handler;
  late DebugPrintCallback originalDebugPrint;

  setUpAll(() {
    originalDebugPrint = debugPrint;
    debugPrint = (String? _, {int? wrapWidth}) {};
    registerFallbackValue(
      const MatrixConfig(
        homeServer: 'http://localhost:8008',
        user: '@test:localhost',
        password: 'pass',
      ),
    );
    registerFallbackValue(MockDeviceKeys());
    registerFallbackValue(MockKeyVerification());
  });

  tearDownAll(() {
    debugPrint = originalDebugPrint;
  });

  group('SyncActorCommandHandler', () {
    group('initial state', () {
      test('starts in uninitialized state', () {
        handler = createTestHandler();
        expect(handler.state, SyncActorState.uninitialized);
      });
    });

    glados.Glados(
      glados.any.actorCommandScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'generated command sequences respect actor state transitions',
      (scenario) async {
        handler = createTestHandler();
        // The in-memory DB factory is overridden, so dbRootPath is never
        // touched on disk — a constant path avoids 120 createTempSync /
        // deleteSync round-trips (one per Glados iteration).
        final dbRootPath = '${Directory.systemTemp.path}/sync_actor_generated';
        var modeledState = SyncActorState.uninitialized;

        try {
          for (var i = 0; i < scenario.commands.length; i++) {
            final command = scenario.commands[i];
            final expectation = command.expectation(modeledState);
            final response = await handler.handleCommand(
              command.commandAt(index: i, dbRootPath: dbRootPath),
            );

            expect(
              response['requestId'],
              command.requestIdAt(i),
              reason: '$scenario',
            );
            expect(response['ok'], expectation.ok, reason: '$scenario');
            if (!expectation.ok) {
              expect(
                response['errorCode'],
                expectation.errorCode,
                reason: '$scenario',
              );
            }

            modeledState = expectation.nextState;
            expect(handler.state, modeledState, reason: '$scenario');
            if (command.kind == _GeneratedActorCommandKind.getHealth) {
              // getHealth is infallible: ok is always true and the state
              // field mirrors the handler's live state in every actor state.
              expect(response['ok'], isTrue, reason: '$scenario');
              expect(response['state'], modeledState.name, reason: '$scenario');
              expect(
                response['state'],
                handler.state.name,
                reason: '$scenario',
              );
            }
          }
        } finally {
          if (handler.state != SyncActorState.disposed) {
            await handler.handleCommand(_cmd('stop'));
          }
        }
      },
      tags: 'glados',
    );

    group('debugRunWithRetries — properties', () {
      glados.Glados3(
        glados.any.intInRange(0, 8),
        glados.any.intInRange(1, 6),
        glados.any.bool,
        glados.ExploreConfig(numRuns: 120),
      ).test(
        'attempt count and outcome match the retry-loop oracle',
        (successOnAttempt, maxRetries, retryable) async {
          handler = createTestHandler();
          var attempts = 0;
          Future<String> operation() async {
            if (attempts++ < successOnAttempt) {
              throw FormatException('transient $attempts');
            }
            return 'done';
          }

          // Oracle: non-retryable errors throw on the first failure;
          // retryable ones retry up to maxRetries total attempts.
          final expectSuccess = retryable
              ? successOnAttempt < maxRetries
              : successOnAttempt == 0;
          final expectedAttempts = expectSuccess
              ? successOnAttempt + 1
              : (retryable ? maxRetries : 1);

          try {
            final result = await handler.debugRunWithRetries(
              operation,
              maxRetries: maxRetries,
              baseDelay: Duration.zero,
              isRetryable: retryable ? (_) => true : (_) => false,
            );
            expect(expectSuccess, isTrue, reason: 'unexpected success');
            expect(result, 'done');
          } on FormatException {
            expect(expectSuccess, isFalse, reason: 'unexpected failure');
          }
          expect(
            attempts,
            expectedAttempts,
            reason:
                'successOn=$successOnAttempt max=$maxRetries '
                'retryable=$retryable',
          );
        },
        tags: 'glados',
      );
    });

    group('ping', () {
      test('works in uninitialized state', () async {
        handler = createTestHandler();
        final response = await handler.handleCommand(_cmd('ping'));
        expect(response['ok'], isTrue);
      });

      test('works with requestId', () async {
        handler = createTestHandler();
        final response = await handler.handleCommand(
          _cmd('ping', {'requestId': 'req-1'}),
        );
        expect(response['ok'], isTrue);
        expect(response['requestId'], 'req-1');
      });
    });

    group('getHealth', () {
      test('returns state in uninitialized', () async {
        handler = createTestHandler();
        final response = await handler.handleCommand(_cmd('getHealth'));
        expect(response['ok'], isTrue);
        expect(response['state'], 'uninitialized');
        expect(response['loginState'], isNull);
      });

      test('returns device key information when available', () async {
        final keysList = MockDeviceKeysList();
        final remoteDevice = MockDeviceKeys();

        stubRemoteDevice(remoteDevice);

        handler = createTestHandler(
          onGatewayCreated: (g, c) {
            when(() => c.userDeviceKeys).thenReturn({
              '@test:localhost': keysList,
            });
            when(() => keysList.deviceKeys).thenReturn(
              <String, DeviceKeys>{'REMOTE': remoteDevice},
            );
          },
        );

        await handler.handleCommand(_initPayload());

        final response = await handler.handleCommand(_cmd('getHealth'));
        expect(response['ok'], isTrue);
        expect(response['state'], 'syncing');
        expect(response['userId'], '@test:localhost');
        final deviceKeys = response['deviceKeys'] as Map<String, Object?>?;
        if (deviceKeys == null) {
          fail('deviceKeys should be present in getHealth response');
        }
        expect(deviceKeys['count'], 1);
        expect(
          deviceKeys['devices'],
          contains('REMOTE(verified=false)'),
        );
      });
    });

    group('invalid state rejection', () {
      test('acceptVerification rejected in uninitialized state', () async {
        handler = createTestHandler();
        final response = await handler.handleCommand(
          _cmd('acceptVerification'),
        );
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'INVALID_STATE');
      });

      test('acceptSas rejected in uninitialized state', () async {
        handler = createTestHandler();
        final response = await handler.handleCommand(_cmd('acceptSas'));
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'INVALID_STATE');
      });

      test('cancelVerification rejected in uninitialized state', () async {
        handler = createTestHandler();
        final response = await handler.handleCommand(
          _cmd('cancelVerification'),
        );
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'INVALID_STATE');
      });

      test('stopSync is idempotent in idle state', () async {
        handler = createTestHandler();
        await handler.handleCommand(_initPayload());
        await handler.handleCommand(_cmd('startSync'));
        await handler.handleCommand(_cmd('stopSync'));
        expect(handler.state, SyncActorState.idle);

        final response = await handler.handleCommand(_cmd('stopSync'));
        expect(response['ok'], isTrue);
        expect(handler.state, SyncActorState.idle);
      });

      test('startSync rejected in uninitialized state', () async {
        handler = createTestHandler();
        final response = await handler.handleCommand(_cmd('startSync'));
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'INVALID_STATE');
      });

      test('stopSync rejected in uninitialized state', () async {
        handler = createTestHandler();
        final response = await handler.handleCommand(_cmd('stopSync'));
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'INVALID_STATE');
      });

      test('createRoom rejected in uninitialized state', () async {
        handler = createTestHandler();
        final response = await handler.handleCommand(
          _cmd('createRoom', {'name': 'test'}),
        );
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'INVALID_STATE');
      });

      test('joinRoom rejected in uninitialized state', () async {
        handler = createTestHandler();
        final response = await handler.handleCommand(
          _cmd('joinRoom', {'roomId': '!room:localhost'}),
        );
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'INVALID_STATE');
      });

      test('sendText rejected in uninitialized state', () async {
        handler = createTestHandler();
        final response = await handler.handleCommand(
          _cmd('sendText', {
            'roomId': '!room:localhost',
            'message': 'hello',
          }),
        );
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'INVALID_STATE');
      });

      test('startVerification rejected in uninitialized state', () async {
        handler = createTestHandler();
        final response = await handler.handleCommand(_cmd('startVerification'));
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'INVALID_STATE');
      });
    });

    group('unknown command', () {
      test('returns UNKNOWN_COMMAND error', () async {
        handler = createTestHandler();
        final response = await handler.handleCommand(
          _cmd('nonExistentCommand'),
        );
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'UNKNOWN_COMMAND');
      });
    });

    group('outbox control commands', () {
      test('connectivityChanged rejects non-bool connected', () async {
        handler = createTestHandler();
        await handler.handleCommand(_initPayload());

        final response = await handler.handleCommand(
          _cmd('connectivityChanged', {'connected': 'true'}),
        );

        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'INVALID_PARAMETER');
      });

      test('connectivityChanged updates connectivity', () async {
        handler = createTestHandler();
        await handler.handleCommand(_initPayload());

        final disconnect = await handler.handleCommand(
          _cmd('connectivityChanged', {'connected': false}),
        );
        expect(disconnect['ok'], isTrue);

        final reconnect = await handler.handleCommand(
          _cmd('connectivityChanged', {'connected': true}),
        );
        expect(reconnect['ok'], isTrue);
      });

      test('kickOutbox rejected when uninitialized', () async {
        handler = createTestHandler();
        final response = await handler.handleCommand(_cmd('kickOutbox'));
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'INVALID_STATE');
      });

      test('kickOutbox accepted when initialized', () async {
        handler = createTestHandler();
        await handler.handleCommand(_initPayload());
        final response = await handler.handleCommand(_cmd('kickOutbox'));
        expect(response['ok'], isTrue);
      });
    });

    group('missing command field', () {
      test('returns error for missing command', () async {
        handler = createTestHandler();
        final response = await handler.handleCommand(<String, Object?>{});
        expect(response['ok'], isFalse);
        expect(response['error'], contains('Missing command field'));
      });
    });

    group('parameter validation', () {
      test('init rejects missing user', () async {
        handler = createTestHandler();
        final response = await handler.handleCommand(<String, Object?>{
          'command': 'init',
          'homeServer': 'http://localhost:8008',
          'password': 'pass',
          'dbRootPath': '/tmp/test',
        });
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'MISSING_PARAMETER');
        expect(response['error'], contains('user'));
        expect(handler.state, SyncActorState.uninitialized);
      });

      test('init rejects missing dbRootPath', () async {
        handler = createTestHandler();
        final response = await handler.handleCommand(<String, Object?>{
          'command': 'init',
          'homeServer': 'http://localhost:8008',
          'user': '@test:localhost',
          'password': 'pass',
        });
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'MISSING_PARAMETER');
        expect(response['error'], contains('dbRootPath'));
        expect(handler.state, SyncActorState.uninitialized);
      });

      test('init rejects missing homeServer', () async {
        handler = createTestHandler();
        final response = await handler.handleCommand(<String, Object?>{
          'command': 'init',
          'user': '@test:localhost',
          'password': 'pass',
          'dbRootPath': '/tmp/test',
        });
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'MISSING_PARAMETER');
        expect(response['error'], contains('homeServer'));
        expect(handler.state, SyncActorState.uninitialized);
      });

      test('init rejects wrong type for password', () async {
        handler = createTestHandler();
        final response = await handler.handleCommand(<String, Object?>{
          'command': 'init',
          'homeServer': 'http://localhost:8008',
          'user': '@test:localhost',
          'password': 123,
          'dbRootPath': '/tmp/test',
        });
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'INVALID_PARAMETER');
        expect(response['error'], contains('password'));
      });

      test('createRoom rejects missing name', () async {
        handler = createTestHandler();
        await handler.handleCommand(_initPayload());

        final response = await handler.handleCommand(
          _cmd('createRoom'),
        );
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'MISSING_PARAMETER');
        expect(response['error'], contains('name'));
      });

      test('joinRoom rejects missing roomId', () async {
        handler = createTestHandler();
        await handler.handleCommand(_initPayload());

        final response = await handler.handleCommand(
          _cmd('joinRoom'),
        );
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'MISSING_PARAMETER');
        expect(response['error'], contains('roomId'));
      });

      test('sendText rejects missing roomId', () async {
        handler = createTestHandler();
        await handler.handleCommand(_initPayload());

        final response = await handler.handleCommand(
          _cmd('sendText', {'message': 'hello'}),
        );
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'MISSING_PARAMETER');
        expect(response['error'], contains('roomId'));
      });

      test('sendText rejects missing message', () async {
        handler = createTestHandler();
        await handler.handleCommand(_initPayload());

        final response = await handler.handleCommand(
          _cmd('sendText', {'roomId': '!room:localhost'}),
        );
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'MISSING_PARAMETER');
        expect(response['error'], contains('message'));
      });
    });

    group('init', () {
      test('transitions to syncing on success', () async {
        handler = createTestHandler();
        final response = await handler.handleCommand(_initPayload());
        expect(response['ok'], isTrue);
        expect(handler.state, SyncActorState.syncing);
      });

      test('returns error and disposes gateway on failure', () async {
        late MockMatrixSdkGateway gateway;

        handler = createTestHandler(
          onGatewayCreated: (g, c) {
            gateway = g;
            when(() => g.connect(any())).thenThrow(Exception('connect failed'));
          },
        );

        final response = await handler.handleCommand(_initPayload());

        expect(response['ok'], isFalse);
        expect(response['error'], contains('Init failed'));
        expect(handler.state, SyncActorState.uninitialized);
        verify(() => gateway.dispose()).called(1);
      });

      test('double init rejected', () async {
        handler = createTestHandler();
        await handler.handleCommand(_initPayload());
        expect(handler.state, SyncActorState.syncing);

        final response = await handler.handleCommand(_initPayload());
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'INVALID_STATE');
      });

      test(
        'getHealth returns syncing state and loginState after init',
        () async {
          handler = createTestHandler();
          await handler.handleCommand(_initPayload());

          final health = await handler.handleCommand(_cmd('getHealth'));
          expect(health['ok'], isTrue);
          expect(health['state'], 'syncing');
          expect(health['loginState'], 'loggedIn');
        },
      );

      test('emits ready event via eventPort', () async {
        handler = createTestHandler();
        final eventPort = ReceivePort();
        final events = <Map<String, Object?>>[];
        eventPort.listen((dynamic raw) {
          if (raw is Map) {
            events.add(raw.cast<String, Object?>());
          }
        });

        await handler.handleCommand(
          _initPayload(eventPort: eventPort.sendPort),
        );

        // Allow event to propagate (microtask yield, no timer)
        await pumpEventQueue();

        expect(events, isNotEmpty);
        expect(events.last['event'], 'ready');
        eventPort.close();
      });

      test('wires event streams and emits updates', () async {
        final loginStateController = StreamController<LoginState>.broadcast();
        final verificationController =
            StreamController<KeyVerification>.broadcast();
        final onSyncController = StreamController<SyncUpdate>.broadcast();
        final toDeviceController = StreamController<ToDeviceEvent>.broadcast();
        final timelineController = StreamController<Event>.broadcast();
        final mockVerification = MockKeyVerification();
        final mockTimelineRoom = MockRoom();
        final mockTimelineEvent = MockEvent();
        final incomingEvents = <Map<String, Object?>>[];
        final verificationSeen = Completer<void>();
        final toDeviceSeen = Completer<void>();
        final incomingMessageSeen = Completer<void>();
        final syncUpdatesSeen = Completer<void>();
        var syncUpdateCount = 0;

        when(() => mockTimelineRoom.id).thenReturn('!room:localhost');
        when(() => mockTimelineEvent.type).thenReturn('m.room.message');
        when(() => mockTimelineEvent.room).thenReturn(mockTimelineRoom);
        when(() => mockTimelineEvent.eventId).thenReturn(r'$timeline:1');
        when(() => mockTimelineEvent.senderId).thenReturn('@sender:localhost');
        when(() => mockTimelineEvent.text).thenReturn('actor test message');
        when(() => mockTimelineEvent.messageType).thenReturn('m.text');

        when(
          () => mockVerification.lastStep,
        ).thenReturn('m.key.verification.ready');
        when(() => mockVerification.canceled).thenReturn(false);
        when(() => mockVerification.isDone).thenReturn(false);
        when(
          () => mockVerification.sasEmojis,
        ).thenReturn(<KeyVerificationEmoji>[]);

        final eventPort = ReceivePort()
          ..listen((dynamic raw) {
            if (raw is Map) {
              final event = raw.cast<String, Object?>();
              incomingEvents.add(event);
              switch (event['event']) {
                case 'verificationState':
                  if (!verificationSeen.isCompleted) {
                    verificationSeen.complete();
                  }
                case 'toDevice':
                  if (!toDeviceSeen.isCompleted) {
                    toDeviceSeen.complete();
                  }
                case 'incomingMessage':
                  if (!incomingMessageSeen.isCompleted) {
                    incomingMessageSeen.complete();
                  }
                case 'syncUpdate':
                  syncUpdateCount++;
                  if (syncUpdateCount == 3 && !syncUpdatesSeen.isCompleted) {
                    syncUpdatesSeen.complete();
                  }
              }
            }
          });

        handler = createTestHandler(
          loginStateChanges: loginStateController.stream,
          keyVerificationRequests: verificationController.stream,
          syncUpdateStream: onSyncController.stream,
          toDeviceEventStream: toDeviceController.stream,
          timelineEventStream: timelineController.stream,
          onGatewayCreated: (g, c) {
            when(() => c.userOwnsEncryptionKeys(any())).thenAnswer(
              (_) async => true,
            );
            when(() => c.userDeviceKeys).thenReturn({});
          },
        );
        await handler.handleCommand(
          _initPayload(eventPort: eventPort.sendPort),
        );

        loginStateController.add(LoginState.loggedIn);
        verificationController.add(mockVerification);
        toDeviceController.add(
          ToDeviceEvent(
            sender: '@sender:localhost',
            type: 'mock.to.device',
            content: const <String, dynamic>{},
          ),
        );
        await Future.wait<void>([
          verificationSeen.future,
          toDeviceSeen.future,
        ]);
        onSyncController
          ..add(MockSyncUpdate())
          ..add(MockSyncUpdate())
          ..add(MockSyncUpdate());
        timelineController.add(mockTimelineEvent);
        await Future.wait<void>([
          syncUpdatesSeen.future,
          incomingMessageSeen.future,
        ]);

        final health = await handler.handleCommand(_cmd('getHealth'));
        final syncCount = health['syncCount'];
        expect(syncCount, isA<int>());
        expect(syncCount, greaterThanOrEqualTo(3));
        expect(health['toDeviceEventCount'], equals(1));
        final healthWithToDevice = await handler.handleCommand(
          _cmd('getHealth'),
        );
        expect(healthWithToDevice['toDeviceEventCount'], equals(1));
        final verificationState = await handler.handleCommand(
          _cmd('getVerificationState'),
        );
        final verificationEvent = incomingEvents
            .where((event) => event['event'] == 'verificationState')
            .toList();
        final incomingMessageEvents = incomingEvents
            .where((event) => event['event'] == 'incomingMessage')
            .toList();

        expect(verificationState['hasIncoming'], isTrue);
        expect(verificationEvent, isNotEmpty);
        expect(
          verificationEvent.first['direction'],
          'incoming',
        );
        expect(incomingMessageEvents, isNotEmpty);
        expect(incomingMessageEvents.first['text'], 'actor test message');
        expect(incomingMessageEvents.first['sender'], '@sender:localhost');
        expect(
          incomingMessageEvents.first['roomId'],
          '!room:localhost',
        );

        await handler.handleCommand(_cmd('stop'));
        await timelineController.close();
        await onSyncController.close();
        await loginStateController.close();
        await verificationController.close();
        await toDeviceController.close();
        eventPort.close();
      });
    });

    group('syncActorEntrypoint', () {
      Future<Map<String, Object?>> sendCommand(
        SendPort commandPort,
        Map<String, Object?> command,
      ) async {
        final responsePort = ReceivePort();
        command['replyTo'] = responsePort.sendPort;
        commandPort.send(command);
        final response = await responsePort.first;
        responsePort.close();
        return Map<String, Object?>.from(response as Map);
      }

      test('handles sync actor init attempt and still exits', () async {
        final readyPort = ReceivePort();
        syncActorEntrypoint(readyPort.sendPort, vodInitializer: () async {});
        final commandPort = (await readyPort.first) as SendPort;

        final initResponse = await sendCommand(
          commandPort,
          _initPayload(
            homeServer: 'http://127.0.0.1:9',
            user: '@entrypoint:localhost',
            dbRootPath: '/tmp/test_sync_actor_entrypoint',
          ),
        );
        expect(initResponse['ok'], isFalse);
        expect(initResponse['error'], contains('Init failed'));

        final stopResponse = await sendCommand(commandPort, _cmd('stop'));
        expect(stopResponse['ok'], isTrue);

        readyPort.close();
      });

      test('returns validation error when command type is invalid', () async {
        final readyPort = ReceivePort();
        syncActorEntrypoint(readyPort.sendPort, vodInitializer: () async {});
        final commandPort = (await readyPort.first) as SendPort;

        final responsePort = ReceivePort();
        commandPort.send(
          <Object, Object?>{
            'command': 123,
            'replyTo': responsePort.sendPort,
          },
        );

        final response = await responsePort.first;
        responsePort.close();
        readyPort.close();

        expect(response, isA<Map<Object?, Object?>>());
        final responseMap = Map<String, Object?>.from(response as Map);
        expect(responseMap['ok'], isFalse);
        expect(
          responseMap['error'],
          contains('Invalid command type: expected String'),
        );
        expect(responseMap['errorCode'], 'INVALID_PARAMETER');
      });

      test(
        'returns missing-command error for raw entrypoint payload',
        () async {
          final readyPort = ReceivePort();
          syncActorEntrypoint(readyPort.sendPort, vodInitializer: () async {});
          final commandPort = (await readyPort.first) as SendPort;

          final responsePort = ReceivePort();
          commandPort.send(
            <Object, Object?>{
              'replyTo': responsePort.sendPort,
            },
          );

          final response = await responsePort.first;
          responsePort.close();
          readyPort.close();

          expect(response, isA<Map<Object?, Object?>>());
          final responseMap = Map<String, Object?>.from(response as Map);
          expect(responseMap['ok'], isFalse);
          expect(responseMap['error'], contains('Missing command field'));
          expect(responseMap['errorCode'], 'MISSING_PARAMETER');
        },
      );

      test(
        'silently ignores a non-Map message and keeps serving commands',
        () async {
          final readyPort = ReceivePort();
          syncActorEntrypoint(readyPort.sendPort, vodInitializer: () async {});
          final commandPort = (await readyPort.first) as SendPort
            // Non-Map payload: the entrypoint must drop it without replying
            // or crashing the message loop.
            ..send('not-a-map');
          await pumpEventQueue();

          // The loop is still alive: a follow-up stop command round-trips.
          final stopResponse = await sendCommand(commandPort, _cmd('stop'));
          expect(stopResponse['ok'], isTrue);

          readyPort.close();
        },
      );
    });
  });

  group('startSync / stopSync', () {
    test('startSync is idempotent while syncing', () async {
      handler = createTestHandler();
      await handler.handleCommand(_initPayload());

      final response = await handler.handleCommand(_cmd('startSync'));
      expect(response['ok'], isTrue);
      expect(handler.state, SyncActorState.syncing);
    });

    test('stopSync transitions back to idle', () async {
      handler = createTestHandler();
      await handler.handleCommand(_initPayload());
      await handler.handleCommand(_cmd('startSync'));

      final response = await handler.handleCommand(_cmd('stopSync'));
      expect(response['ok'], isTrue);
      expect(handler.state, SyncActorState.idle);
    });

    test('startSync rejected in stopped state', () async {
      handler = createTestHandler();
      await handler.handleCommand(_initPayload());
      await handler.handleCommand(_cmd('startSync'));
      await handler.handleCommand(_cmd('stopSync'));

      final response = await handler.handleCommand(_cmd('startSync'));
      expect(response['ok'], isTrue);
      expect(handler.state, SyncActorState.syncing);
    });
  });

  group('createRoom', () {
    test('delegates to gateway in idle state', () async {
      late MockMatrixSdkGateway gateway;
      handler = createTestHandler(
        onGatewayCreated: (g, c) {
          gateway = g;
        },
      );
      await handler.handleCommand(_initPayload());

      when(
        () => gateway.createRoom(
          name: any(named: 'name'),
          inviteUserIds: any(named: 'inviteUserIds'),
        ),
      ).thenAnswer((_) async => '!room:localhost');

      final response = await handler.handleCommand(
        _cmd('createRoom', {
          'name': 'Test Room',
          'inviteUserIds': <String>['@user2:localhost'],
        }),
      );

      expect(response['ok'], isTrue);
      expect(response['roomId'], '!room:localhost');
    });

    test('returns error when gateway createRoom fails', () async {
      late MockMatrixSdkGateway gateway;
      handler = createTestHandler(
        onGatewayCreated: (g, c) {
          gateway = g;
        },
      );
      await handler.handleCommand(_initPayload());

      when(
        () => gateway.createRoom(
          name: any(named: 'name'),
          inviteUserIds: any(named: 'inviteUserIds'),
        ),
      ).thenThrow(Exception('create failed'));

      final response = await handler.handleCommand(
        _cmd('createRoom', {'name': 'Test Room'}),
      );

      expect(response['ok'], isFalse);
      expect(response['error'], contains('createRoom failed'));
    });
  });

  group('joinRoom', () {
    test('delegates to gateway in idle state', () async {
      late MockMatrixSdkGateway gateway;
      handler = createTestHandler(
        onGatewayCreated: (g, c) {
          gateway = g;
        },
      );
      await handler.handleCommand(_initPayload());

      when(() => gateway.joinRoom(any())).thenAnswer((_) async {});

      final response = await handler.handleCommand(
        _cmd('joinRoom', {'roomId': '!room:localhost'}),
      );

      expect(response['ok'], isTrue);
    });

    test('returns error when gateway joinRoom fails', () async {
      late MockMatrixSdkGateway gateway;
      handler = createTestHandler(
        onGatewayCreated: (g, c) {
          gateway = g;
        },
      );
      await handler.handleCommand(_initPayload());

      when(() => gateway.joinRoom(any())).thenThrow(
        Exception('join failed'),
      );

      final response = await handler.handleCommand(
        _cmd('joinRoom', {'roomId': '!room:localhost'}),
      );

      expect(response['ok'], isFalse);
      expect(response['error'], contains('joinRoom failed'));
    });
  });

  group('sendText', () {
    test('delegates while idle without pausing sync', () async {
      late MockMatrixSdkGateway gateway;
      late MockMatrixClient client;

      handler = createTestHandler(
        onGatewayCreated: (g, c) {
          gateway = g;
          client = c;
        },
      );
      await handler.handleCommand(_initPayload());
      await handler.handleCommand(_cmd('stopSync'));
      expect(handler.state, SyncActorState.idle);

      when(
        () => gateway.sendText(
          roomId: any(named: 'roomId'),
          message: any(named: 'message'),
          messageType: any(named: 'messageType'),
          displayPendingEvent: false,
        ),
      ).thenAnswer((_) async => r'$idleEvent');

      final response = await handler.handleCommand(
        _cmd('sendText', {
          'roomId': '!room:localhost',
          'message': 'hello world',
          'requestId': 'idle-send',
        }),
      );

      expect(response['ok'], isTrue);
      expect(response['requestId'], 'idle-send');
      expect(response['eventId'], r'$idleEvent');
      verifyNever(() => client.abortSync());
    });

    test(
      'pauses sync (abortSync) and resumes when sent while syncing',
      () async {
        late MockMatrixSdkGateway gateway;
        late MockMatrixClient client;

        handler = createTestHandler(
          onGatewayCreated: (g, c) {
            gateway = g;
            client = c;
          },
        );
        await handler.handleCommand(_initPayload());
        expect(handler.state, SyncActorState.syncing);

        when(
          () => gateway.sendText(
            roomId: any(named: 'roomId'),
            message: any(named: 'message'),
            messageType: any(named: 'messageType'),
            displayPendingEvent: false,
          ),
        ).thenAnswer((_) async => r'$syncingEvent');

        final response = await handler.handleCommand(
          _cmd('sendText', {
            'roomId': '!room:localhost',
            'message': 'hello while syncing',
            'requestId': 'syncing-send',
          }),
        );

        expect(response['ok'], isTrue);
        expect(response['eventId'], r'$syncingEvent');
        // The transient pause must abort the in-flight sync before sending …
        verify(() => client.abortSync()).called(1);
        // … and turn background sync back on afterwards (still syncing).
        // (init also toggles backgroundSync, so assert at-least-once here.)
        verify(
          () => client.backgroundSync = false,
        ).called(greaterThanOrEqualTo(1));
        verify(
          () => client.backgroundSync = true,
        ).called(greaterThanOrEqualTo(1));
        expect(handler.state, SyncActorState.syncing);
      },
    );

    test('delegates to gateway and returns eventId', () async {
      late MockMatrixSdkGateway gateway;
      handler = createTestHandler(
        onGatewayCreated: (g, c) {
          gateway = g;
        },
      );
      await handler.handleCommand(_initPayload());

      when(
        () => gateway.sendText(
          roomId: any(named: 'roomId'),
          message: any(named: 'message'),
          messageType: any(named: 'messageType'),
          displayPendingEvent: false,
        ),
      ).thenAnswer((_) async => r'$event123');

      final response = await handler.handleCommand(
        _cmd('sendText', {
          'roomId': '!room:localhost',
          'message': 'hello world',
        }),
      );

      expect(response['ok'], isTrue);
      expect(response['eventId'], r'$event123');
    });

    test('retries on retryable errors before succeeding', () async {
      late MockMatrixSdkGateway gateway;
      var attempt = 0;

      handler = createTestHandler(
        onGatewayCreated: (g, c) {
          gateway = g;
        },
      );
      await handler.handleCommand(_initPayload());

      when(
        () => gateway.sendText(
          roomId: any(named: 'roomId'),
          message: any(named: 'message'),
          messageType: any(named: 'messageType'),
          displayPendingEvent: false,
        ),
      ).thenAnswer((_) async {
        if (attempt < 2) {
          attempt++;
          throw Exception('SqliteFfiException(21): bad');
        }
        return r'$event456';
      });

      final response = await handler.handleCommand(
        _cmd('sendText', {
          'roomId': '!room:localhost',
          'message': 'hello world',
        }),
      );

      expect(response['ok'], isTrue);
      expect(response['eventId'], r'$event456');
      expect(attempt, 2);
    });

    test('returns error after exhausting retryable errors', () async {
      late MockMatrixSdkGateway gateway;
      var attempt = 0;

      handler = createTestHandler(
        onGatewayCreated: (g, c) {
          gateway = g;
        },
      );
      await handler.handleCommand(_initPayload());

      when(
        () => gateway.sendText(
          roomId: any(named: 'roomId'),
          message: any(named: 'message'),
          messageType: any(named: 'messageType'),
          displayPendingEvent: false,
        ),
      ).thenAnswer((_) async {
        attempt++;
        throw Exception(
          'SqliteFfiException(21): bad parameter or other API misuse',
        );
      });

      final response = await handler.handleCommand(
        _cmd('sendText', {
          'roomId': '!room:localhost',
          'message': 'hello world',
        }),
      );

      expect(response['ok'], isFalse);
      expect(response['error'], contains('sendText failed'));
      expect(attempt, greaterThanOrEqualTo(5));
    });

    test('returns error when gateway sendText fails', () async {
      late MockMatrixSdkGateway gateway;
      handler = createTestHandler(
        onGatewayCreated: (g, c) {
          gateway = g;
        },
      );
      await handler.handleCommand(_initPayload());

      when(
        () => gateway.sendText(
          roomId: any(named: 'roomId'),
          message: any(named: 'message'),
          messageType: any(named: 'messageType'),
          displayPendingEvent: false,
        ),
      ).thenThrow(Exception('send failed'));

      final response = await handler.handleCommand(
        _cmd('sendText', {
          'roomId': '!room:localhost',
          'message': 'hello world',
        }),
      );

      expect(response['ok'], isFalse);
      expect(response['error'], contains('sendText failed'));
    });
  });

  group('verification', () {
    test(
      'startVerification returns started false when no peer device',
      () async {
        late MockMatrixClient client;
        handler = createTestHandler(
          onGatewayCreated: (g, c) {
            client = c;
            when(() => c.userDeviceKeys).thenReturn({});
            when(
              () => c.userOwnsEncryptionKeys(any()),
            ).thenAnswer((_) async => true);
            when(() => c.userDeviceKeysLoading).thenAnswer((_) async {});
          },
          verificationPeerDiscoveryAttempts: 1,
          verificationPeerDiscoveryInterval: Duration.zero,
        );
        await handler.handleCommand(_initPayload());
        expect(client.userID, '@test:localhost');

        final response = await handler.handleCommand(_cmd('startVerification'));
        expect(response['ok'], isTrue);
        expect(response['started'], isFalse);
      },
    );

    test('startVerification caps peer discovery attempts at eight', () async {
      var unverifiedCalls = 0;

      handler = createTestHandler(
        verificationPeerDiscoveryAttempts: 24,
        verificationPeerDiscoveryInterval: Duration.zero,
        onGatewayCreated: (g, c) {
          when(
            () => c.userOwnsEncryptionKeys(any()),
          ).thenAnswer((_) async => true);
          when(() => c.userDeviceKeys).thenReturn({});
          when(() => c.userDeviceKeysLoading).thenAnswer((_) async {});
          when(() => g.unverifiedDevices()).thenAnswer((_) {
            unverifiedCalls++;
            return const <DeviceKeys>[];
          });
        },
      );

      await handler.handleCommand(_initPayload());
      final response = await handler.handleCommand(_cmd('startVerification'));

      expect(response['ok'], isTrue);
      expect(response['started'], isFalse);
      expect(unverifiedCalls, 8);
    });

    test('startVerification validates roomId type', () async {
      handler = createTestHandler();
      await handler.handleCommand(_initPayload());

      final response = await handler.handleCommand(
        _cmd('startVerification', {'roomId': 123}),
      );

      expect(response['ok'], isFalse);
      expect(response['errorCode'], 'INVALID_PARAMETER');
      expect(response['error'], contains('roomId'));
    });

    test('startVerification validates non-empty roomId', () async {
      handler = createTestHandler();
      await handler.handleCommand(_initPayload());

      final response = await handler.handleCommand(
        _cmd('startVerification', {'roomId': ''}),
      );

      expect(response['ok'], isFalse);
      expect(response['errorCode'], 'INVALID_PARAMETER');
      expect(response['error'], contains('roomId'));
    });

    test(
      'startVerification refreshes peer keys and emits update log when key count changes',
      () async {
        final ownDevice = MockDeviceKeys();
        final remoteDevice = MockDeviceKeys();
        final initialKeys = MockDeviceKeysList();
        final updatedKeys = MockDeviceKeysList();
        final incomingEvents = <Map<String, Object?>>[];
        final keyRefreshLogged = Completer<void>();
        var keysUpdated = false;

        when(() => ownDevice.deviceId).thenReturn('DEV');
        when(() => ownDevice.verified).thenReturn(true);

        stubRemoteDevice(remoteDevice);
        when(() => remoteDevice.userId).thenReturn('@peer:localhost');

        when(() => initialKeys.deviceKeys).thenReturn(
          <String, DeviceKeys>{'DEV': ownDevice},
        );
        when(() => updatedKeys.deviceKeys).thenReturn(
          <String, DeviceKeys>{
            'DEV': ownDevice,
            'REMOTE': remoteDevice,
          },
        );

        final eventPort = ReceivePort()
          ..listen((dynamic raw) {
            if (raw is Map) {
              final event = raw.cast<String, Object?>();
              incomingEvents.add(event);
              if (event['event'] == 'log' &&
                  '${event['message']}'.contains(
                    'verification device keys updated for',
                  ) &&
                  !keyRefreshLogged.isCompleted) {
                keyRefreshLogged.complete();
              }
            }
          });

        handler = createTestHandler(
          enableLogging: true,
          verificationPeerDiscoveryAttempts: 2,
          verificationPeerDiscoveryInterval: Duration.zero,
          onGatewayCreated: (g, c) {
            when(
              () => c.userOwnsEncryptionKeys(any()),
            ).thenAnswer((_) async => true);
            when(() => c.userDeviceKeys).thenAnswer(
              (_) => <String, DeviceKeysList>{
                '@test:localhost': keysUpdated ? updatedKeys : initialKeys,
              },
            );
            when(() => c.userDeviceKeysLoading).thenAnswer((_) async {});
            when(
              () => c.updateUserDeviceKeys(
                additionalUsers: any(named: 'additionalUsers'),
              ),
            ).thenAnswer((_) async {
              keysUpdated = true;
            });
            when(() => g.unverifiedDevices()).thenReturn(const <DeviceKeys>[]);
          },
        );

        await handler.handleCommand(
          _initPayload(eventPort: eventPort.sendPort),
        );

        final first = await handler.handleCommand(_cmd('startVerification'));
        final second = await handler.handleCommand(_cmd('startVerification'));
        await keyRefreshLogged.future;

        expect(first['ok'], isTrue);
        expect(first['started'], isFalse);
        expect(second['ok'], isTrue);
        expect(second['started'], isFalse);
        expect(
          incomingEvents.any(
            (event) =>
                event['event'] == 'log' &&
                '${event['message']}'.contains(
                  'verification device keys updated for',
                ),
          ),
          isTrue,
        );

        eventPort.close();
      },
    );

    test(
      'startVerification emits key-refresh error event on refresh failure',
      () async {
        final incomingEvents = <Map<String, Object?>>[];
        final refreshErrorSeen = Completer<void>();

        final eventPort = ReceivePort()
          ..listen((dynamic raw) {
            if (raw is Map) {
              final event = raw.cast<String, Object?>();
              incomingEvents.add(event);
              if (event['event'] == 'verificationKeyRefreshError' &&
                  '${event['error']}'.contains('refresh failed') &&
                  !refreshErrorSeen.isCompleted) {
                refreshErrorSeen.complete();
              }
            }
          });

        handler = createTestHandler(
          enableLogging: true,
          verificationPeerDiscoveryAttempts: 1,
          verificationPeerDiscoveryInterval: Duration.zero,
          onGatewayCreated: (g, c) {
            when(
              () => c.userOwnsEncryptionKeys(any()),
            ).thenAnswer((_) async => true);
            when(
              () => c.updateUserDeviceKeys(
                additionalUsers: any(named: 'additionalUsers'),
              ),
            ).thenThrow(Exception('refresh failed'));
            when(() => g.unverifiedDevices()).thenReturn(const <DeviceKeys>[]);
          },
        );

        await handler.handleCommand(
          _initPayload(eventPort: eventPort.sendPort),
        );
        final response = await handler.handleCommand(_cmd('startVerification'));
        await refreshErrorSeen.future;

        expect(response['ok'], isTrue);
        expect(response['started'], isFalse);
        expect(
          incomingEvents.where(
            (event) =>
                event['event'] == 'verificationKeyRefreshError' &&
                '${event['error']}'.contains('refresh failed'),
          ),
          isNotEmpty,
        );

        eventPort.close();
      },
    );

    test(
      'startVerification ignores start request while another verification is active',
      () async {
        late MockMatrixSdkGateway gateway;
        final remoteDevice = MockDeviceKeys();
        final verification = MockKeyVerification();

        stubRemoteDevice(remoteDevice);
        stubVerificationReads(verification);
        when(verification.acceptSas).thenAnswer((_) async {});
        when(() => verification.openSSSS(skip: true)).thenAnswer((_) async {});
        when(() => verification.startedVerification).thenReturn(true);

        handler = createTestHandler(
          onGatewayCreated: (g, c) {
            gateway = g;
            final keysList = MockDeviceKeysList();
            stubClientDeviceKeys(c, keysList, remoteDevice);
            when(() => g.unverifiedDevices()).thenReturn(
              <DeviceKeys>[remoteDevice],
            );
            when(
              () => g.startKeyVerification(any()),
            ).thenAnswer((_) async => verification);
          },
        );

        await handler.handleCommand(_initPayload());

        final first = await handler.handleCommand(_cmd('startVerification'));
        final second = await handler.handleCommand(_cmd('startVerification'));
        final finalState = await handler.handleCommand(
          _cmd('getVerificationState'),
        );

        expect(first['ok'], isTrue);
        expect(first['started'], isTrue);
        expect(second['ok'], isTrue);
        expect(second['started'], isFalse);
        expect(finalState['hasOutgoing'], isTrue);
        expect(finalState['hasIncoming'], isFalse);
        verify(() => gateway.startKeyVerification(any())).called(1);
      },
    );

    test(
      'startVerification starts verification for unverified device',
      () async {
        late MockMatrixSdkGateway gateway;
        var callbackCalled = false;
        late MockDeviceKeysList keysList;
        final remoteDevice = MockDeviceKeys();
        final verification = MockKeyVerification();

        stubRemoteDevice(remoteDevice);
        when(
          () => verification.lastStep,
        ).thenReturn('m.key.verification.ready');
        when(() => verification.sasEmojis).thenReturn(<KeyVerificationEmoji>[]);
        when(verification.acceptSas).thenAnswer((_) async {});
        when(() => verification.isDone).thenReturn(false);
        when(() => verification.canceled).thenReturn(false);
        when(
          () => verification.lastStep,
        ).thenReturn('m.key.verification.ready');
        when(() => verification.openSSSS(skip: true)).thenAnswer((_) async {});
        when(() => verification.startedVerification).thenReturn(true);

        handler = createTestHandler(
          onGatewayCreated: (g, c) {
            callbackCalled = true;
            gateway = g;
            keysList = MockDeviceKeysList();
            stubClientDeviceKeys(c, keysList, remoteDevice);
            when(() => g.unverifiedDevices()).thenReturn(
              <DeviceKeys>[remoteDevice],
            );
            when(
              () => g.startKeyVerification(any()),
            ).thenAnswer((_) async => verification);
          },
        );
        final initResponse = await handler.handleCommand(_initPayload());
        expect(initResponse['ok'], isTrue, reason: '$initResponse');
        expect(callbackCalled, isTrue);
        final preState = await handler.handleCommand(_cmd('getHealth'));
        final deviceKeys = preState['deviceKeys'] as Map<String, Object?>?;
        expect(preState['userId'], '@test:localhost');
        expect(preState['state'], 'syncing');
        expect(deviceKeys, isNotNull);
        expect(deviceKeys!['count'], 1);

        final response = await handler.handleCommand(_cmd('startVerification'));
        final state = await handler.handleCommand(_cmd('getVerificationState'));
        final sasResponse = await handler.handleCommand(_cmd('acceptSas'));

        expect(response['ok'], isTrue);
        expect(response['started'], isTrue);
        expect(state['hasOutgoing'], isTrue);
        expect(sasResponse['ok'], isTrue);
        verify(() => gateway.startKeyVerification(any())).called(1);
      },
    );

    test(
      'startVerification returns error when direct verification does not start',
      () async {
        final keysList = MockDeviceKeysList();
        final remoteDevice = MockDeviceKeys();
        final verification = MockKeyVerification();

        stubRemoteDevice(remoteDevice);
        when(() => remoteDevice.userId).thenReturn('@test:localhost');
        when(() => verification.startedVerification).thenReturn(false);
        when(() => verification.openSSSS(skip: true)).thenAnswer((_) async {});
        stubVerificationReads(verification);

        handler = createTestHandler(
          onGatewayCreated: (g, c) {
            stubClientDeviceKeys(c, keysList, remoteDevice);
            when(() => g.unverifiedDevices()).thenReturn(
              <DeviceKeys>[remoteDevice],
            );
            when(
              () => g.startKeyVerification(any()),
            ).thenAnswer((_) async => verification);
          },
        );

        await handler.handleCommand(_initPayload());
        final response = await handler.handleCommand(_cmd('startVerification'));

        expect(response['ok'], isFalse);
        expect(
          response['error'],
          contains('Verification request did not start'),
        );
      },
    );

    test(
      'startVerification returns error when room verification has no encryption',
      () async {
        final keysList = MockDeviceKeysList();
        final remoteDevice = MockDeviceKeys();

        stubRemoteDevice(remoteDevice);
        when(() => remoteDevice.userId).thenReturn('@peer:localhost');

        handler = createTestHandler(
          onGatewayCreated: (g, c) {
            stubClientDeviceKeys(c, keysList, remoteDevice);
            when(() => g.unverifiedDevices()).thenReturn(
              <DeviceKeys>[remoteDevice],
            );
          },
        );

        await handler.handleCommand(_initPayload());
        final response = await handler.handleCommand(
          _cmd('startVerification', {'roomId': '!room:localhost'}),
        );

        expect(response['ok'], isFalse);
        expect(
          response['error'],
          contains('startKeyVerification requires enabled encryption'),
        );
      },
    );

    test(
      'startVerification returns error when room verification room is missing',
      () async {
        final keysList = MockDeviceKeysList();
        final remoteDevice = MockDeviceKeys();
        final encryption = MockEncryption();

        stubRemoteDevice(remoteDevice);
        when(() => remoteDevice.userId).thenReturn('@peer:localhost');

        handler = createTestHandler(
          onGatewayCreated: (g, c) {
            when(() => c.userID).thenReturn('@test:localhost');
            when(() => c.deviceID).thenReturn('DEV');
            when(() => c.userDeviceKeys).thenReturn({
              '@test:localhost': keysList,
            });
            when(() => keysList.deviceKeys).thenReturn(
              <String, DeviceKeys>{'REMOTE': remoteDevice},
            );
            when(() => c.encryption).thenReturn(encryption);
            when(() => c.getRoomById(any())).thenReturn(null);
            when(() => c.userOwnsEncryptionKeys(any())).thenAnswer((_) async {
              return false;
            });
            when(() => c.userDeviceKeysLoading).thenAnswer((_) async {});
            when(() => g.unverifiedDevices()).thenReturn(
              <DeviceKeys>[remoteDevice],
            );
          },
        );

        await handler.handleCommand(_initPayload());
        final response = await handler.handleCommand(
          _cmd('startVerification', {'roomId': '!missing:localhost'}),
        );

        expect(response['ok'], isFalse);
        expect(
          response['error'],
          contains('Room verification requires existing room'),
        );
      },
    );

    test(
      'startVerification attempts room verification flow for peer user',
      () async {
        final keysList = MockDeviceKeysList();
        final remoteDevice = MockDeviceKeys();
        final encryption = MockEncryption();
        final crossSigning = MockCrossSigning();
        final keyVerificationManager = MockKeyVerificationManager();
        final room = MockRoom();

        stubRemoteDevice(remoteDevice);
        when(() => remoteDevice.userId).thenReturn('@peer:localhost');
        when(() => crossSigning.enabled).thenReturn(false);
        when(() => keyVerificationManager.addRequest(any())).thenReturn(null);

        handler = createTestHandler(
          onGatewayCreated: (g, c) {
            when(() => c.userID).thenReturn('@test:localhost');
            when(() => c.deviceID).thenReturn('DEV');
            when(() => c.verificationMethods).thenReturn(
              <KeyVerificationMethod>{KeyVerificationMethod.emoji},
            );
            when(() => c.userDeviceKeys).thenReturn({
              '@test:localhost': keysList,
            });
            when(() => keysList.deviceKeys).thenReturn(
              <String, DeviceKeys>{'REMOTE': remoteDevice},
            );
            when(() => c.encryption).thenReturn(encryption);
            when(() => c.getRoomById(any())).thenReturn(room);
            when(() => c.userOwnsEncryptionKeys(any())).thenAnswer((_) async {
              return false;
            });
            when(() => c.userDeviceKeysLoading).thenAnswer((_) async {});

            when(() => encryption.client).thenReturn(c);
            when(() => encryption.crossSigning).thenReturn(crossSigning);
            when(
              () => encryption.keyVerificationManager,
            ).thenReturn(keyVerificationManager);
            when(
              () => room.sendEvent(
                any(),
                type: any(named: 'type'),
              ),
            ).thenAnswer((_) async => r'$evtRoom');

            when(() => g.unverifiedDevices()).thenReturn(
              <DeviceKeys>[remoteDevice],
            );
          },
        );

        await handler.handleCommand(_initPayload());
        final response = await handler.handleCommand(
          _cmd('startVerification', {'roomId': '!room:localhost'}),
        );

        expect(response['ok'], isFalse);
        expect(response['error'], contains('startVerification failed'));
      },
    );

    test(
      'acceptVerification returns error when no incoming verification',
      () async {
        handler = createTestHandler();
        await handler.handleCommand(_initPayload());

        final response = await handler.handleCommand(
          _cmd('acceptVerification'),
        );
        expect(response['ok'], isFalse);
        expect(
          response['error'],
          contains('No incoming verification'),
        );
      },
    );

    test('acceptVerification succeeds with incoming verification', () async {
      final verification = MockKeyVerification();

      when(verification.acceptVerification).thenAnswer(
        (_) async => Future<void>.value(),
      );
      when(() => verification.lastStep).thenReturn('m.key.verification.ready');
      when(() => verification.isDone).thenReturn(false);
      when(() => verification.canceled).thenReturn(false);
      when(() => verification.sasEmojis).thenReturn(<KeyVerificationEmoji>[]);

      handler = createTestHandler(
        onGatewayCreated: (g, c) {
          when(
            () => g.keyVerificationRequests,
          ).thenAnswer((_) => Stream<KeyVerification>.value(verification));
        },
      );
      await handler.handleCommand(_initPayload());
      await pumpEventQueue();
      final response = await handler.handleCommand(_cmd('acceptVerification'));

      expect(response['ok'], isTrue);
      verify(verification.acceptVerification).called(1);
    });

    test('acceptVerification returns error when accept fails', () async {
      final verification = MockKeyVerification();

      when(
        verification.acceptVerification,
      ).thenThrow(Exception('accept failed'));
      when(() => verification.lastStep).thenReturn('m.key.verification.ready');
      when(() => verification.isDone).thenReturn(false);
      when(() => verification.canceled).thenReturn(false);
      when(() => verification.sasEmojis).thenReturn(<KeyVerificationEmoji>[]);

      handler = createTestHandler(
        onGatewayCreated: (g, c) {
          when(
            () => g.keyVerificationRequests,
          ).thenAnswer((_) => Stream<KeyVerification>.value(verification));
        },
      );
      await handler.handleCommand(_initPayload());
      await pumpEventQueue();
      final response = await handler.handleCommand(_cmd('acceptVerification'));

      expect(response['ok'], isFalse);
      expect(response['error'], contains('acceptVerification failed'));
    });

    test(
      'startVerification returns error when key verification fails',
      () async {
        final keysList = MockDeviceKeysList();
        final remoteDevice = MockDeviceKeys();
        final verification = MockKeyVerification();

        stubRemoteDevice(remoteDevice);
        stubVerificationReads(verification);

        handler = createTestHandler(
          onGatewayCreated: (g, c) {
            stubClientDeviceKeys(c, keysList, remoteDevice);
            when(() => g.unverifiedDevices()).thenReturn(
              <DeviceKeys>[remoteDevice],
            );
            when(
              () => g.startKeyVerification(any()),
            ).thenThrow(Exception('verification failed'));
          },
        );

        await handler.handleCommand(_initPayload());
        final response = await handler.handleCommand(
          _cmd(
            'startVerification',
            {'requestId': 'start-verification-fail'},
          ),
        );

        expect(response['ok'], isFalse);
        expect(response['requestId'], 'start-verification-fail');
        expect(response['error'], contains('startVerification failed'));
        expect(response['stackTrace'], isNotNull);
      },
    );

    test('acceptSas returns error when no active verification', () async {
      handler = createTestHandler();
      await handler.handleCommand(_initPayload());

      final response = await handler.handleCommand(_cmd('acceptSas'));
      expect(response['ok'], isFalse);
      expect(response['error'], contains('No active verification'));
    });

    test('acceptSas returns error when active verification fails', () async {
      final verification = MockKeyVerification();

      when(verification.acceptSas).thenThrow(
        Exception('acceptSas failed'),
      );
      when(() => verification.lastStep).thenReturn('m.key.verification.ready');
      when(() => verification.isDone).thenReturn(false);
      when(() => verification.canceled).thenReturn(false);
      when(() => verification.sasEmojis).thenReturn(<KeyVerificationEmoji>[]);

      handler = createTestHandler(
        onGatewayCreated: (g, c) {
          when(
            () => g.keyVerificationRequests,
          ).thenAnswer((_) => Stream<KeyVerification>.value(verification));
        },
      );
      await handler.handleCommand(_initPayload());
      await pumpEventQueue();
      final response = await handler.handleCommand(
        _cmd('acceptSas', {'requestId': 'accept-sas-fail'}),
      );

      expect(response['ok'], isFalse);
      expect(response['requestId'], 'accept-sas-fail');
      expect(response['error'], contains('acceptSas failed'));
    });

    test('cancelVerification cancels active incoming verification', () async {
      final verification = MockKeyVerification();

      when(verification.cancel).thenAnswer((_) async => Future<void>.value());
      when(() => verification.lastStep).thenReturn('m.key.verification.ready');
      when(() => verification.isDone).thenReturn(false);
      when(() => verification.canceled).thenReturn(false);
      when(() => verification.sasEmojis).thenReturn(<KeyVerificationEmoji>[]);
      handler = createTestHandler(
        onGatewayCreated: (g, c) {
          when(
            () => g.keyVerificationRequests,
          ).thenAnswer((_) => Stream<KeyVerification>.value(verification));
        },
      );
      await handler.handleCommand(_initPayload());
      await pumpEventQueue();
      final response = await handler.handleCommand(_cmd('cancelVerification'));
      final state = await handler.handleCommand(_cmd('getVerificationState'));

      expect(response['ok'], isTrue);
      expect(state['hasIncoming'], isFalse);
      verify(verification.cancel).called(1);
    });

    test('cancelVerification succeeds with no active verification', () async {
      handler = createTestHandler();
      await handler.handleCommand(_initPayload());

      final response = await handler.handleCommand(_cmd('cancelVerification'));
      expect(response['ok'], isTrue);
    });

    test('cancelVerification returns error when cancel throws', () async {
      final verification = MockKeyVerification();

      when(verification.cancel).thenThrow(Exception('cancel failed'));
      when(() => verification.lastStep).thenReturn('m.key.verification.ready');
      when(() => verification.isDone).thenReturn(false);
      when(() => verification.canceled).thenReturn(false);
      when(() => verification.sasEmojis).thenReturn(<KeyVerificationEmoji>[]);

      handler = createTestHandler(
        onGatewayCreated: (g, c) {
          when(
            () => g.keyVerificationRequests,
          ).thenAnswer((_) => Stream<KeyVerification>.value(verification));
        },
      );
      await handler.handleCommand(_initPayload());
      await pumpEventQueue();

      final response = await handler.handleCommand(
        _cmd('cancelVerification', {'requestId': 'cancel-verification-fail'}),
      );

      expect(response['ok'], isFalse);
      expect(response['requestId'], 'cancel-verification-fail');
      expect(response['error'], contains('cancelVerification failed'));
    });
  });

  group('stop', () {
    test('from uninitialized transitions to disposed', () async {
      handler = createTestHandler();
      final response = await handler.handleCommand(_cmd('stop'));
      expect(response['ok'], isTrue);
      expect(handler.state, SyncActorState.disposed);
    });

    test('from idle transitions to disposed', () async {
      handler = createTestHandler();
      await handler.handleCommand(_initPayload());
      expect(handler.state, SyncActorState.syncing);

      final response = await handler.handleCommand(_cmd('stop'));
      expect(response['ok'], isTrue);
      expect(handler.state, SyncActorState.disposed);
    });

    test('from syncing transitions to disposed', () async {
      handler = createTestHandler();
      await handler.handleCommand(_initPayload());
      await handler.handleCommand(_cmd('startSync'));
      expect(handler.state, SyncActorState.syncing);

      final response = await handler.handleCommand(_cmd('stop'));
      expect(response['ok'], isTrue);
      expect(handler.state, SyncActorState.disposed);
    });

    test('double stop rejected', () async {
      handler = createTestHandler();
      await handler.handleCommand(_cmd('stop'));
      expect(handler.state, SyncActorState.disposed);

      final response = await handler.handleCommand(_cmd('stop'));
      expect(response['ok'], isFalse);
      expect(response['errorCode'], 'INVALID_STATE');
    });

    test('ignores cleanup errors while stopping', () async {
      late MockMatrixSdkGateway gateway;

      handler = createTestHandler(
        onGatewayCreated: (g, c) {
          gateway = g;
          when(() => g.dispose()).thenThrow(Exception('shutdown failed'));
        },
      );
      await handler.handleCommand(_initPayload());

      final response = await handler.handleCommand(_cmd('stop'));

      expect(response['ok'], isTrue);
      expect(handler.state, SyncActorState.disposed);
      verify(() => gateway.dispose()).called(1);

      // The finally block ran to completion despite the dispose throw:
      // getHealth reports the disposed state with every gateway-derived
      // field reset (the nulled _gateway drops client/device/user), and
      // no active sync loop. _latestLoginState is a cached observation
      // that stop deliberately does not clear.
      final health = await handler.handleCommand(_cmd('getHealth'));
      expect(health['ok'], isTrue);
      expect(health['state'], SyncActorState.disposed.name);
      expect(health['deviceId'], isNull);
      expect(health['userId'], isNull);
      expect(health['encryptionEnabled'], isFalse);
      expect(health['syncLoopActive'], isFalse);
    });

    test('commands rejected after stop', () async {
      handler = createTestHandler();
      await handler.handleCommand(_cmd('stop'));

      final response = await handler.handleCommand(_cmd('startSync'));
      expect(response['ok'], isFalse);
      expect(response['errorCode'], 'INVALID_STATE');
    });

    test('ping still works after stop', () async {
      handler = createTestHandler();
      await handler.handleCommand(_cmd('stop'));

      final response = await handler.handleCommand(_cmd('ping'));
      expect(response['ok'], isTrue);
    });

    test('getHealth works after stop', () async {
      handler = createTestHandler();
      await handler.handleCommand(_cmd('stop'));

      final response = await handler.handleCommand(_cmd('getHealth'));
      expect(response['ok'], isTrue);
      expect(response['state'], 'disposed');
    });
  });

  group('default stream factories', () {
    test(
      'falls back to client.onToDeviceEvent when no factory is injected',
      () async {
        final onToDevice =
            matrix_cached.CachedStreamController<ToDeviceEvent>();
        final toDeviceSeen = Completer<void>();
        final eventPort = ReceivePort()
          ..listen((dynamic raw) {
            if (raw is Map &&
                raw['event'] == 'toDevice' &&
                !toDeviceSeen.isCompleted) {
              toDeviceSeen.complete();
            }
          });

        handler = createTestHandler(
          useDefaultToDeviceStreamFactory: true,
          onGatewayCreated: (g, c) {
            when(() => c.onToDeviceEvent).thenReturn(onToDevice);
          },
        );

        await handler.handleCommand(
          _initPayload(eventPort: eventPort.sendPort),
        );

        onToDevice.add(
          ToDeviceEvent(
            sender: '@peer:localhost',
            type: 'mock.to.device',
            content: const <String, dynamic>{},
          ),
        );
        await toDeviceSeen.future;

        final health = await handler.handleCommand(_cmd('getHealth'));
        expect(health['toDeviceEventCount'], 1);

        await handler.handleCommand(_cmd('stop'));
        await onToDevice.close();
        eventPort.close();
      },
    );

    test(
      'falls back to client.onTimelineEvent when no factory is injected',
      () async {
        final onTimeline = matrix_cached.CachedStreamController<Event>();
        final room = MockRoom();
        final event = MockEvent();
        final incomingSeen = Completer<Map<String, Object?>>();

        when(() => room.id).thenReturn('!room:localhost');
        when(() => event.type).thenReturn('m.room.message');
        when(() => event.room).thenReturn(room);
        when(() => event.eventId).thenReturn(r'$timeline:fallback');
        when(() => event.senderId).thenReturn('@peer:localhost');
        when(() => event.text).thenReturn('fallback message');
        when(() => event.messageType).thenReturn('m.text');

        final eventPort = ReceivePort()
          ..listen((dynamic raw) {
            if (raw is Map &&
                raw['event'] == 'incomingMessage' &&
                !incomingSeen.isCompleted) {
              incomingSeen.complete(raw.cast<String, Object?>());
            }
          });

        handler = createTestHandler(
          useDefaultTimelineStreamFactory: true,
          onGatewayCreated: (g, c) {
            when(() => c.onTimelineEvent).thenReturn(onTimeline);
          },
        );

        await handler.handleCommand(
          _initPayload(eventPort: eventPort.sendPort),
        );

        onTimeline.add(event);
        final incoming = await incomingSeen.future;

        expect(incoming['text'], 'fallback message');
        expect(incoming['roomId'], '!room:localhost');
        expect(incoming['sender'], '@peer:localhost');

        await handler.handleCommand(_cmd('stop'));
        await onTimeline.close();
        eventPort.close();
      },
    );
  });

  group('default sync database factory', () {
    test('opens and closes a real on-disk SyncDatabase via init/stop', () async {
      final dbRoot = Directory.systemTemp.createTempSync(
        'sync_actor_default_db',
      );

      handler = createTestHandler(useDefaultSyncDatabaseFactory: true);

      try {
        final initResponse = await handler.handleCommand(
          _initPayload(dbRootPath: dbRoot.path),
        );
        // Success proves the default SyncDatabase factory ran: it built a real
        // on-disk SyncDatabase rooted at dbRootPath and wired it into the
        // outbound queue during init.
        expect(initResponse['ok'], isTrue, reason: '$initResponse');
        expect(handler.state, SyncActorState.syncing);

        // kickOutbox drives a drain pass against the real database, exercising a
        // query (claimNextOutboxItem) through the live connection.
        final kick = await handler.handleCommand(_cmd('kickOutbox'));
        expect(kick['ok'], isTrue);

        // stop() closes the real database connection; a clean disposal confirms
        // the connection was valid.
        final stopResponse = await handler.handleCommand(_cmd('stop'));
        expect(stopResponse['ok'], isTrue);
        expect(handler.state, SyncActorState.disposed);
      } finally {
        if (dbRoot.existsSync()) {
          dbRoot.deleteSync(recursive: true);
        }
      }
    });
  });

  group('room verification success', () {
    test(
      'completes room verification request and tracks outgoing flow',
      () async {
        final keysList = MockDeviceKeysList();
        final remoteDevice = MockDeviceKeys();
        final encryption = MockEncryption();
        final crossSigning = MockCrossSigning();
        final keyVerificationManager = MockKeyVerificationManager();
        final room = MockRoom();
        final addRequestCalls = <KeyVerification>[];

        stubRemoteDevice(remoteDevice);
        when(() => remoteDevice.userId).thenReturn('@peer:localhost');
        when(() => crossSigning.enabled).thenReturn(false);
        when(() => room.id).thenReturn('!room:localhost');
        when(() => keyVerificationManager.addRequest(any())).thenAnswer((
          invocation,
        ) {
          addRequestCalls.add(
            invocation.positionalArguments.first as KeyVerification,
          );
        });

        handler = createTestHandler(
          onGatewayCreated: (g, c) {
            when(() => c.userID).thenReturn('@test:localhost');
            when(() => c.deviceID).thenReturn('DEV');
            when(() => c.verificationMethods).thenReturn(
              <KeyVerificationMethod>{KeyVerificationMethod.emoji},
            );
            when(() => c.userDeviceKeys).thenReturn({
              '@test:localhost': keysList,
            });
            when(() => keysList.deviceKeys).thenReturn(
              <String, DeviceKeys>{'REMOTE': remoteDevice},
            );
            when(() => c.encryption).thenReturn(encryption);
            when(() => c.getRoomById(any())).thenReturn(room);
            when(() => c.userOwnsEncryptionKeys(any())).thenAnswer((_) async {
              return false;
            });
            when(() => c.userDeviceKeysLoading).thenAnswer((_) async {});
            when(() => encryption.client).thenReturn(c);
            when(() => encryption.crossSigning).thenReturn(crossSigning);
            when(
              () => encryption.keyVerificationManager,
            ).thenReturn(keyVerificationManager);
            when(
              () => room.sendEvent(any(), type: any(named: 'type')),
            ).thenAnswer((_) async => r'$evtRoom');
            when(() => g.unverifiedDevices()).thenReturn(
              <DeviceKeys>[remoteDevice],
            );
          },
        );

        await handler.handleCommand(_initPayload());
        final response = await handler.handleCommand(
          _cmd('startVerification', {'roomId': '!room:localhost'}),
        );
        final state = await handler.handleCommand(
          _cmd('getVerificationState'),
        );

        expect(response['ok'], isTrue, reason: '$response');
        expect(response['started'], isTrue);
        // The room-based path sends the verification request event through the
        // room and registers it with the key-verification manager.
        verify(
          () => room.sendEvent(any(), type: any(named: 'type')),
        ).called(1);
        expect(addRequestCalls, hasLength(1));
        expect(state['hasOutgoing'], isTrue);
        expect(state['hasIncoming'], isFalse);

        await handler.handleCommand(_cmd('stop'));
      },
    );
  });

  group('outbox drain rescheduling', () {
    test(
      'continues draining on zero delay then reschedules on non-zero delay',
      () async {
        late _ScriptedOutboundQueue scriptedQueue;

        handler = createTestHandler(
          outboundQueueFactory:
              ({
                required syncDatabase,
                required gateway,
                required emitEvent,
                leaseDuration = const Duration(minutes: 1),
                retryDelay = const Duration(seconds: 1),
                errorDelay = const Duration(seconds: 1),
                maxRetries = 5,
                sendTimeout = const Duration(seconds: 30),
                connected = true,
                syncRoomId,
              }) {
                final queue = _ScriptedOutboundQueue(
                  syncDatabase: syncDatabase,
                  gateway: gateway,
                  emitEvent: emitEvent,
                  // First drain returns zero (loop continues), second returns a
                  // non-zero delay which triggers the reschedule branch.
                  delays: <Duration?>[
                    Duration.zero,
                    const Duration(seconds: 5),
                  ],
                );
                scriptedQueue = queue;
                return queue;
              },
        );

        // init kicks the outbox queue, scheduling the first drain pass.
        await handler.handleCommand(_initPayload());

        // Wait until the scripted delays are fully consumed; this guarantees the
        // loop ran the zero-delay continuation and the non-zero reschedule.
        await scriptedQueue.exhausted.future;

        // `exhausted` completes inside the final `drain()` call, before the
        // non-zero delay is returned and the reschedule timer is scheduled.
        // Drain the microtask queue so the returned delay propagates back up
        // the drain loop and the reschedule branch runs deterministically
        // before we assert (and before stop() cancels the pending timer).
        await pumpEventQueue();

        expect(scriptedQueue.drainCalls, 2);

        // stop() cancels the pending reschedule timer, preventing timer leaks.
        await handler.handleCommand(_cmd('stop'));
        expect(handler.state, SyncActorState.disposed);
      },
    );
  });
}
