import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/gateway/matrix_sdk_gateway.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

class MockLoginResponse extends Mock implements LoginResponse {}

class MockDeviceKeys extends Mock implements DeviceKeys {}

class MockDeviceKeysList extends Mock implements DeviceKeysList {}

class MockMatrixFile extends Mock implements MatrixFile {}

class MockGetVersionsResponse extends Mock implements GetVersionsResponse {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      AuthenticationUserIdentifier(user: '@user:server'),
    );
    registerFallbackValue(MockMatrixFile());
    registerFallbackValue(
      StateEvent(
        type: 'm.room.encryption',
        stateKey: '',
        content: <String, Object?>{},
      ),
    );
    registerFallbackValue(<StateEvent>[]);
  });

  late MockClient client;
  late MatrixSdkGateway gateway;
  late StreamController<({String roomId, StrippedStateEvent state})>
      roomStateController;
  late StreamController<LoginState> loginStateController;
  late StreamController<KeyVerification> keyVerificationController;
  late bool disposed;
  late SentEventRegistry sentEventRegistry;

  setUp(() {
    client = MockClient();
    roomStateController = StreamController<
        ({String roomId, StrippedStateEvent state})>.broadcast();
    loginStateController = StreamController<LoginState>.broadcast();
    keyVerificationController = StreamController<KeyVerification>.broadcast();

    when(() => client.onRoomState.stream)
        .thenAnswer((_) => roomStateController.stream);
    when(() => client.onLoginStateChanged.stream)
        .thenAnswer((_) => loginStateController.stream);
    when(() => client.onKeyVerificationRequest.stream)
        .thenAnswer((_) => keyVerificationController.stream);
    when(() => client.dispose()).thenAnswer((_) async {});

    disposed = false;
    sentEventRegistry = SentEventRegistry();
    gateway = MatrixSdkGateway(
      client: client,
      sentEventRegistry: sentEventRegistry,
      roomStateStream: roomStateController.stream,
      loginStateStream: loginStateController.stream,
      keyVerificationRequestStream: keyVerificationController.stream,
    );
  });

  tearDown(() async {
    if (!disposed) {
      await gateway.dispose();
    }
    await roomStateController.close();
    await loginStateController.close();
    await keyVerificationController.close();
  });

  test('connect checks homeserver and initialises client', () async {
    const config = MatrixConfig(
      homeServer: 'https://server',
      user: '@a:server',
      password: '',
    );
    final versions = MockGetVersionsResponse();
    when(() => client.checkHomeserver(Uri.parse(config.homeServer))).thenAnswer(
      (_) async => (null, versions, const <LoginFlow>[], null),
    );
    when(
      () => client.init(
        waitForFirstSync: false,
        waitUntilLoadCompletedLoaded: false,
      ),
    ).thenAnswer((_) async {});

    await gateway.connect(config);

    verify(() => client.checkHomeserver(Uri.parse(config.homeServer)))
        .called(1);
    verify(
      () => client.init(
        waitForFirstSync: false,
        waitUntilLoadCompletedLoaded: false,
      ),
    ).called(1);
  });

  test('login delegates to client.login with password auth', () async {
    const config = MatrixConfig(
      homeServer: 'https://server',
      user: '@user:server',
      password: 'secret',
    );
    final response = MockLoginResponse();
    when(
      () => client.login(
        LoginType.mLoginPassword,
        identifier: any(named: 'identifier'),
        password: config.password,
        initialDeviceDisplayName: 'Device',
      ),
    ).thenAnswer((_) async => response);

    final result = await gateway.login(config, deviceDisplayName: 'Device');

    expect(result, response);
    verify(
      () => client.login(
        LoginType.mLoginPassword,
        identifier: any(named: 'identifier'),
        password: config.password,
        initialDeviceDisplayName: 'Device',
      ),
    ).called(1);
  });

  test('logout only calls client when session is active', () async {
    when(() => client.isLogged()).thenReturn(false);

    await gateway.logout();

    verifyNever(() => client.logout());

    when(() => client.isLogged()).thenReturn(true);
    when(() => client.logout()).thenAnswer((_) async {});

    await gateway.logout();

    verify(() => client.logout()).called(1);
  });

  test('createRoom sets encrypted initial state and sync marker', () async {
    when(
      () => client.createRoom(
        visibility: Visibility.private,
        name: 'Room',
        invite: ['@bob:server'],
        preset: CreateRoomPreset.trustedPrivateChat,
        initialState: any(named: 'initialState'),
      ),
    ).thenAnswer((_) async => '!room:server');

    final roomId = await gateway.createRoom(
      name: 'Room',
      inviteUserIds: ['@bob:server'],
    );

    expect(roomId, '!room:server');
    final captured = verify(
      () => client.createRoom(
        visibility: Visibility.private,
        name: 'Room',
        invite: ['@bob:server'],
        preset: CreateRoomPreset.trustedPrivateChat,
        initialState: captureAny(named: 'initialState'),
      ),
    ).captured.single as List<StateEvent>;

    final types = captured.map((event) => event.type).toSet();
    expect(types, contains('m.room.encryption'));
    expect(types, contains('m.lotti.sync_room'));

    final encryption = captured
        .firstWhere((event) => event.type == 'm.room.encryption')
        .content;
    expect(encryption['algorithm'], 'm.megolm.v1.aes-sha2');
  });

  test('joinRoom and leaveRoom delegate to client', () async {
    when(() => client.joinRoom('!room:server'))
        .thenAnswer((_) async => '!room');
    when(() => client.leaveRoom('!room:server')).thenAnswer((_) async {});

    await gateway.joinRoom('!room:server');
    await gateway.leaveRoom('!room:server');

    verify(() => client.joinRoom('!room:server')).called(1);
    verify(() => client.leaveRoom('!room:server')).called(1);
  });

  test('getRoomById proxies to client', () {
    final room = MockRoom();
    when(() => client.getRoomById('!room:server')).thenReturn(room);

    expect(gateway.getRoomById('!room:server'), room);
  });

  test('invite stream emits only invite membership events', () async {
    final inviteStream = gateway.invites;
    final inviteFuture = expectLater(
      inviteStream,
      emitsInOrder([
        predicate<RoomInviteEvent>(
          (event) =>
              event.roomId == '!room:server' && event.senderId == '@a:server',
        ),
      ]),
    );

    roomStateController
      ..add(
        (
          roomId: '!room:server',
          state: StrippedStateEvent.fromJson(
            {
              'type': 'm.room.member',
              'sender': '@a:server',
              'content': {'membership': 'join'},
            },
          ),
        ),
      )
      ..add(
        (
          roomId: '!room:server',
          state: StrippedStateEvent.fromJson(
            {
              'type': 'm.room.member',
              'sender': '@a:server',
              'content': {'membership': 'invite'},
            },
          ),
        ),
      );

    await inviteFuture;
  });

  test('invite stream ignores invites targeted at other users', () async {
    when(() => client.userID).thenReturn('@me:server');

    final invites = <RoomInviteEvent>[];
    final sub = gateway.invites.listen(invites.add);

    // Invite targeted at a different user — should be ignored
    roomStateController.add(
      (
        roomId: '!room:server',
        state: StrippedStateEvent.fromJson(
          {
            'type': 'm.room.member',
            'sender': '@admin:server',
            'state_key': '@other:server',
            'content': {'membership': 'invite'},
          },
        ),
      ),
    );

    // Give the event time to propagate
    await Future<void>.delayed(Duration.zero);

    expect(invites, isEmpty);

    // Invite targeted at this client — should be emitted
    roomStateController.add(
      (
        roomId: '!room:server',
        state: StrippedStateEvent.fromJson(
          {
            'type': 'm.room.member',
            'sender': '@admin:server',
            'state_key': '@me:server',
            'content': {'membership': 'invite'},
          },
        ),
      ),
    );

    await Future<void>.delayed(Duration.zero);

    expect(invites, hasLength(1));
    expect(invites.first.roomId, '!room:server');

    await sub.cancel();
  });

  test('createRoom does not rely on immediate room snapshot', () async {
    when(
      () => client.createRoom(
        visibility: Visibility.private,
        name: 'Room',
        invite: <String>[],
        preset: CreateRoomPreset.trustedPrivateChat,
        initialState: any(named: 'initialState'),
      ),
    ).thenAnswer((_) async => '!room:server');

    final roomId = await gateway.createRoom(
      name: 'Room',
      inviteUserIds: [],
    );

    expect(roomId, '!room:server');
    verifyNever(() => client.getRoomById(any<String>()));
  });

  test('timelineEvents currently returns an empty stream', () async {
    await expectLater(gateway.timelineEvents('!room:server'), emitsDone);
  });

  test('sendText throws when room.sendEvent returns null', () async {
    final room = MockRoom();
    when(() => client.getRoomById('!room:server')).thenReturn(room);
    when(() => room.sendEvent(any())).thenAnswer((_) async => null);

    expect(
      () => gateway.sendText(roomId: '!room:server', message: 'hi'),
      throwsException,
    );
  });

  test('sendText returns event id when successful', () async {
    final room = MockRoom();
    when(() => client.getRoomById('!room:server')).thenReturn(room);
    when(() => room.sendEvent(any())).thenAnswer((_) async => 'event');

    final eventId =
        await gateway.sendText(roomId: '!room:server', message: 'hi');

    expect(eventId, 'event');
  });

  test('sendText registers event ID in sent registry', () async {
    final room = MockRoom();
    when(() => client.getRoomById('!room:server')).thenReturn(room);
    when(() => room.sendEvent(any())).thenAnswer((_) async => r'$text-evt');

    await gateway.sendText(roomId: '!room:server', message: 'hi');

    expect(sentEventRegistry.consume(r'$text-evt'), isTrue);
    expect(
      sentEventRegistry.debugSource(r'$text-evt'),
      equals(SentEventSource.text),
    );
  });

  test('sendFile throws when matrix SDK returns null id', () async {
    final room = MockRoom();
    when(() => client.getRoomById('!room:server')).thenReturn(room);
    when(() => room.sendFileEvent(any())).thenAnswer((_) async => null);

    expect(
      () => gateway.sendFile(
        roomId: '!room:server',
        file: MockMatrixFile(),
      ),
      throwsException,
    );
  });

  test('sendFile supports extra content payloads', () async {
    final room = MockRoom();
    when(() => client.getRoomById('!room:server')).thenReturn(room);
    when(() =>
            room.sendFileEvent(any(), extraContent: any(named: 'extraContent')))
        .thenAnswer((_) async => 'file');

    final eventId = await gateway.sendFile(
      roomId: '!room:server',
      file: MockMatrixFile(),
      extraContent: {'foo': 'bar'},
    );

    expect(eventId, 'file');
  });

  test('sendFile registers event ID in sent registry', () async {
    final room = MockRoom();
    when(() => client.getRoomById('!room:server')).thenReturn(room);
    when(() =>
            room.sendFileEvent(any(), extraContent: any(named: 'extraContent')))
        .thenAnswer((_) async => r'$file-evt');

    await gateway.sendFile(
      roomId: '!room:server',
      file: MockMatrixFile(),
      extraContent: {'foo': 'bar'},
    );

    expect(sentEventRegistry.consume(r'$file-evt'), isTrue);
    expect(
      sentEventRegistry.debugSource(r'$file-evt'),
      equals(SentEventSource.file),
    );
  });

  test('keyVerificationRequests proxies the underlying stream', () async {
    final verification = FakeKeyVerification();
    final expectation = expectLater(
      gateway.keyVerificationRequests,
      emits(verification),
    );

    keyVerificationController.add(verification);
    await expectation;
  });

  test('startKeyVerification delegates to device implementation', () async {
    final device = MockDeviceKeys();
    final verification = FakeKeyVerification();
    when(device.startVerification).thenAnswer((_) async => verification);

    final result = await gateway.startKeyVerification(device);

    expect(result, verification);
  });

  test('unverifiedDevices returns only devices missing verification', () {
    final verifiedDevice = MockDeviceKeys();
    when(() => verifiedDevice.verified).thenReturn(true);
    final unverifiedDevice = MockDeviceKeys();
    when(() => unverifiedDevice.verified).thenReturn(false);

    final deviceList = MockDeviceKeysList();
    when(() => deviceList.deviceKeys).thenReturn({
      'one': verifiedDevice,
      'two': unverifiedDevice,
    });

    when(() => client.userDeviceKeys).thenReturn({
      '@user:server': deviceList,
    });

    final devices = gateway.unverifiedDevices();

    expect(devices, [unverifiedDevice]);
  });

  test('dispose cancels subscription, closes invites, and disposes client',
      () async {
    final inviteCompletion = expectLater(gateway.invites, emitsDone);
    when(() => client.dispose()).thenAnswer((_) async {});

    await gateway.dispose();
    disposed = true;

    verify(() => client.dispose()).called(1);
    await inviteCompletion;
  });
}

class FakeKeyVerification extends Fake implements KeyVerification {}
