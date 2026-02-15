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

class MockDeviceKeysList extends Mock implements DeviceKeysList {}

class MockDeviceKeys extends Mock implements DeviceKeys {}

class MockKeyVerification extends Mock implements KeyVerification {}

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
      when(() => mockClient.onSync)
          .thenReturn(CachedStreamController<SyncUpdate>());
      when(() => mockClient.userID).thenReturn('@test:localhost');
      when(() => mockClient.deviceID).thenReturn('DEV');
      when(() => mockClient.abortSync()).thenAnswer((_) async {});
      when(() => mockClient.syncPending).thenReturn(false);
      when(() => mockClient.encryptionEnabled).thenReturn(false);
      when(() => mockClient.userDeviceKeys)
          .thenReturn(<String, DeviceKeysList>{});
      when(() => mockClient.userOwnsEncryptionKeys(any()))
          .thenAnswer((_) async => false);
      when(() => mockClient.userDeviceKeysLoading).thenAnswer((_) async {});

      onGatewayCreated?.call(mockGateway, mockClient);
      // Ensure identity fields are always available even when callbacks configure
      // additional client-level stubs.
      when(() => mockClient.userID).thenReturn('@test:localhost');
      when(() => mockClient.deviceID).thenReturn('DEV');

      return mockGateway;
    },
    vodInitializer: () async {},
    enableLogging: false,
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
    registerFallbackValue(MockDeviceKeys());
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

      test('returns device key information when available', () async {
        final keysList = MockDeviceKeysList();
        final remoteDevice = MockDeviceKeys();

        when(() => remoteDevice.deviceId).thenReturn('REMOTE');
        when(() => remoteDevice.verified).thenReturn(false);

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

    group('parameter validation', () {
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

      test('getHealth returns syncing state and loginState after init',
          () async {
        handler = createTestHandler();
        await handler.handleCommand(_initPayload());

        final health = await handler.handleCommand(_cmd('getHealth'));
        expect(health['ok'], isTrue);
        expect(health['state'], 'syncing');
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
      test('startVerification returns started false when no peer device',
          () async {
        late MockClient client;
        handler = createTestHandler(
          onGatewayCreated: (g, c) {
            client = c;
            when(() => c.userDeviceKeys).thenReturn({});
            when(() => c.userOwnsEncryptionKeys(any()))
                .thenAnswer((_) async => true);
            when(() => c.userDeviceKeysLoading).thenAnswer((_) async {});
          },
        );
        await handler.handleCommand(_initPayload());
        expect(client.userID, '@test:localhost');

        final response = await handler.handleCommand(_cmd('startVerification'));
        expect(response['ok'], isTrue);
        expect(response['started'], isFalse);
      });

      test('startVerification starts verification for unverified device',
          () async {
        late MockMatrixSdkGateway gateway;
        var callbackCalled = false;
        late MockDeviceKeysList keysList;
        final remoteDevice = MockDeviceKeys();
        final verification = MockKeyVerification();

        when(() => remoteDevice.deviceId).thenReturn('REMOTE');
        when(() => remoteDevice.verified).thenReturn(false);
        when(() => verification.lastStep)
            .thenReturn('m.key.verification.ready');
        when(() => verification.sasEmojis).thenReturn(<KeyVerificationEmoji>[]);
        when(verification.acceptSas).thenAnswer((_) async {});
        when(() => verification.isDone).thenReturn(false);
        when(() => verification.canceled).thenReturn(false);
        when(() => verification.lastStep)
            .thenReturn('m.key.verification.ready');

        handler = createTestHandler(
          onGatewayCreated: (g, c) {
            callbackCalled = true;
            gateway = g;
            keysList = MockDeviceKeysList();
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
            when(() => g.startKeyVerification(any()))
                .thenAnswer((_) async => verification);
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

      test('acceptVerification succeeds with incoming verification', () async {
        final verification = MockKeyVerification();

        when(verification.acceptVerification).thenAnswer((_) async {});
        when(() => verification.lastStep)
            .thenReturn('m.key.verification.ready');
        when(() => verification.isDone).thenReturn(false);
        when(() => verification.canceled).thenReturn(false);

        handler = createTestHandler(
          onGatewayCreated: (g, c) {
            when(() => g.keyVerificationRequests)
                .thenAnswer((_) => Stream<KeyVerification>.value(verification));
          },
        );
        await handler.handleCommand(_initPayload());
        await Future<void>.delayed(Duration.zero);
        final response =
            await handler.handleCommand(_cmd('acceptVerification'));

        expect(response['ok'], isTrue);
        verify(verification.acceptVerification).called(1);
      });

      test('acceptVerification returns error when accept fails', () async {
        final verification = MockKeyVerification();

        when(verification.acceptVerification)
            .thenThrow(Exception('accept failed'));
        when(() => verification.lastStep)
            .thenReturn('m.key.verification.ready');
        when(() => verification.isDone).thenReturn(false);
        when(() => verification.canceled).thenReturn(false);

        handler = createTestHandler(
          onGatewayCreated: (g, c) {
            when(() => g.keyVerificationRequests)
                .thenAnswer((_) => Stream<KeyVerification>.value(verification));
          },
        );
        await handler.handleCommand(_initPayload());
        await Future<void>.delayed(Duration.zero);
        final response =
            await handler.handleCommand(_cmd('acceptVerification'));

        expect(response['ok'], isFalse);
        expect(response['error'], contains('acceptVerification failed'));
      });

      test('acceptSas returns error when no active verification', () async {
        handler = createTestHandler();
        await handler.handleCommand(_initPayload());

        final response = await handler.handleCommand(_cmd('acceptSas'));
        expect(response['ok'], isFalse);
        expect(response['error'], contains('No active verification'));
      });

      test('cancelVerification cancels active incoming verification', () async {
        final verification = MockKeyVerification();

        when(verification.cancel).thenAnswer((_) async {});
        when(() => verification.lastStep)
            .thenReturn('m.key.verification.ready');
        when(() => verification.isDone).thenReturn(false);
        when(() => verification.canceled).thenReturn(false);
        handler = createTestHandler(
          onGatewayCreated: (g, c) {
            when(() => g.keyVerificationRequests)
                .thenAnswer((_) => Stream<KeyVerification>.value(verification));
          },
        );
        await handler.handleCommand(_initPayload());
        await Future<void>.delayed(Duration.zero);
        final response =
            await handler.handleCommand(_cmd('cancelVerification'));
        final state = await handler.handleCommand(_cmd('getVerificationState'));

        expect(response['ok'], isTrue);
        expect(state['hasIncoming'], isFalse);
        verify(verification.cancel).called(1);
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
