import 'dart:async';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/actor/sync_actor.dart';
import 'package:lotti/features/sync/gateway/matrix_sdk_gateway.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockClient extends Mock implements Client {}

class MockMatrixSdkGateway extends Mock implements MatrixSdkGateway {}

/// Creates a [SyncActorCommandHandler] with a mock gateway factory.
///
/// The [onGatewayCreated] callback receives the mock gateway after creation,
/// allowing tests to set up stubs before commands use it.
SyncActorCommandHandler createTestHandler({
  void Function(MockMatrixSdkGateway gateway, MockClient client)?
      onGatewayCreated,
}) {
  late MockMatrixSdkGateway mockGateway;
  late MockClient mockClient;

  return SyncActorCommandHandler(
    gatewayFactory: ({
      required Client client,
      required SentEventRegistry sentEventRegistry,
    }) {
      mockClient = MockClient();
      mockGateway = MockMatrixSdkGateway();

      // Default stubs
      when(() => mockGateway.connect(any())).thenAnswer((_) async {});
      when(() => mockGateway.login(any(),
              deviceDisplayName: any(named: 'deviceDisplayName')))
          .thenAnswer((_) async => LoginResponse.fromJson({
                'user_id': '@test:localhost',
                'device_id': 'DEV',
                'access_token': 'tok'
              }));
      when(() => mockGateway.loginStateChanges)
          .thenAnswer((_) => const Stream<LoginState>.empty());
      when(() => mockGateway.keyVerificationRequests)
          .thenAnswer((_) => const Stream<KeyVerification>.empty());
      when(() => mockGateway.client).thenReturn(mockClient);
      when(() => mockGateway.dispose()).thenAnswer((_) async {});

      when(() => mockClient.onLoginStateChanged)
          .thenReturn(CachedStreamController(LoginState.loggedIn));
      when(() => mockClient.userID).thenReturn('@test:localhost');
      when(() => mockClient.deviceID).thenReturn('DEV');
      when(() => mockClient.encryptionEnabled).thenReturn(false);
      when(() => mockClient.userDeviceKeys)
          .thenReturn(<String, DeviceKeysList>{});
      when(() => mockClient.userOwnsEncryptionKeys(any()))
          .thenAnswer((_) async => false);
      when(() => mockClient.userDeviceKeysLoading).thenAnswer((_) async {});

      onGatewayCreated?.call(mockGateway, mockClient);

      return mockGateway;
    },
    vodInitializer: () async {},
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
    if (eventPort != null) 'eventPort': eventPort,
  };
}

void main() {
  late SyncActorCommandHandler handler;

  setUpAll(() {
    registerFallbackValue(
      const MatrixConfig(
        homeServer: 'http://localhost:8008',
        user: '@test:localhost',
        password: 'pass',
      ),
    );
  });

  group('SyncActorCommandHandler', () {
    group('initial state', () {
      test('starts in uninitialized state', () {
        handler = createTestHandler();
        expect(handler.state, SyncActorState.uninitialized);
      });
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
    });

    group('invalid state rejection', () {
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
        final response =
            await handler.handleCommand(_cmd('nonExistentCommand'));
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'UNKNOWN_COMMAND');
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

    group('init', () {
      test('transitions to idle on success', () async {
        handler = createTestHandler();
        final response = await handler.handleCommand(_initPayload());
        expect(response['ok'], isTrue);
        expect(handler.state, SyncActorState.idle);
      });

      test('double init rejected', () async {
        handler = createTestHandler();
        await handler.handleCommand(_initPayload());
        expect(handler.state, SyncActorState.idle);

        final response = await handler.handleCommand(_initPayload());
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'INVALID_STATE');
      });

      test('getHealth returns idle state and loginState after init', () async {
        handler = createTestHandler();
        await handler.handleCommand(_initPayload());

        final health = await handler.handleCommand(_cmd('getHealth'));
        expect(health['ok'], isTrue);
        expect(health['state'], 'idle');
        expect(health['loginState'], 'loggedIn');
      });

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

        // Allow event to propagate
        await Future<void>.delayed(Duration.zero);

        expect(events, isNotEmpty);
        expect(events.last['event'], 'ready');
        eventPort.close();
      });
    });

    group('startSync / stopSync', () {
      test('startSync transitions to syncing', () async {
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

      test('startSync rejected in syncing state', () async {
        handler = createTestHandler();
        await handler.handleCommand(_initPayload());
        await handler.handleCommand(_cmd('startSync'));

        final response = await handler.handleCommand(_cmd('startSync'));
        expect(response['ok'], isFalse);
        expect(response['errorCode'], 'INVALID_STATE');
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
    });

    group('sendText', () {
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
    });

    group('verification', () {
      test('startVerification returns started false when no peer device',
          () async {
        handler = createTestHandler(
          onGatewayCreated: (g, c) {
            when(() => c.userDeviceKeys).thenReturn({});
            when(() => c.userOwnsEncryptionKeys(any()))
                .thenAnswer((_) async => true);
            when(() => c.userDeviceKeysLoading).thenAnswer((_) async {});
          },
        );
        await handler.handleCommand(_initPayload());

        final response = await handler.handleCommand(_cmd('startVerification'));
        expect(response['ok'], isTrue);
        expect(response['started'], isFalse);
      });

      test('acceptVerification returns error when no incoming verification',
          () async {
        handler = createTestHandler();
        await handler.handleCommand(_initPayload());

        final response =
            await handler.handleCommand(_cmd('acceptVerification'));
        expect(response['ok'], isFalse);
        expect(
          response['error'],
          contains('No incoming verification'),
        );
      });

      test('acceptSas returns error when no active verification', () async {
        handler = createTestHandler();
        await handler.handleCommand(_initPayload());

        final response = await handler.handleCommand(_cmd('acceptSas'));
        expect(response['ok'], isFalse);
        expect(response['error'], contains('No active verification'));
      });

      test('cancelVerification succeeds with no active verification', () async {
        handler = createTestHandler();
        await handler.handleCommand(_initPayload());

        final response =
            await handler.handleCommand(_cmd('cancelVerification'));
        expect(response['ok'], isTrue);
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
        expect(handler.state, SyncActorState.idle);

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
  });
}
