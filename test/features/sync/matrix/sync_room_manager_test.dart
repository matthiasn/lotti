// ignore_for_file: unnecessary_lambdas

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixGateway extends Mock implements MatrixSyncGateway {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockLoggingService extends Mock implements LoggingService {}

class MockRoom extends Mock implements Room {}

class MockRoomInviteEvent extends Mock implements RoomInviteEvent {}

class MockClient extends Mock implements Client {}

class MockMatrixException extends Mock implements MatrixException {}

void main() {
  late MockMatrixGateway gateway;
  late MockSettingsDb settingsDb;
  late MockLoggingService loggingService;
  late StreamController<RoomInviteEvent> inviteController;
  late SyncRoomManager manager;

  setUp(() {
    gateway = MockMatrixGateway();
    settingsDb = MockSettingsDb();
    loggingService = MockLoggingService();
    inviteController = StreamController<RoomInviteEvent>.broadcast();

    when(() => gateway.invites).thenAnswer((_) => inviteController.stream);
    when(() => loggingService.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
        )).thenReturn(null);
    when(() => loggingService.captureException(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
          stackTrace: any<dynamic>(named: 'stackTrace'),
        )).thenReturn(null);
    when(() => settingsDb.saveSettingsItem(any<String>(), any<String>()))
        .thenAnswer((_) async => 1);
    when(() => settingsDb.removeSettingsItem(any<String>()))
        .thenAnswer((_) async {});
    when(() => settingsDb.itemByKey(any<String>()))
        .thenAnswer((_) async => null);

    manager = SyncRoomManager(
      gateway: gateway,
      settingsDb: settingsDb,
      loggingService: loggingService,
    );
  });

  tearDown(() async {
    await manager.dispose();
    await inviteController.close();
  });

  test('initialize does nothing when no persisted room id', () async {
    when(() => settingsDb.itemByKey(matrixRoomKey))
        .thenAnswer((_) async => null);

    await manager.initialize();

    verifyNever(() => gateway.getRoomById(any<String>()));
    expect(manager.currentRoom, isNull);
    expect(manager.currentRoomId, isNull);
  });

  test('initialize hydrates persisted room snapshot', () async {
    final room = MockRoom();
    when(() => settingsDb.itemByKey(matrixRoomKey))
        .thenAnswer((_) async => '!room:server');
    when(() => gateway.getRoomById('!room:server')).thenReturn(room);

    await manager.initialize();

    verify(() => gateway.getRoomById('!room:server')).called(1);
    expect(manager.currentRoom, same(room));
    expect(manager.currentRoomId, '!room:server');
  });

  test('hydrateRoomSnapshot syncs client and resolves room', () async {
    final room = MockRoom();
    final client = MockClient();
    when(() => client.sync())
        .thenAnswer((_) async => SyncUpdate(nextBatch: 'token'));
    when(() => settingsDb.itemByKey(matrixRoomKey))
        .thenAnswer((_) async => '!room:server');
    when(() => gateway.getRoomById('!room:server')).thenReturn(room);

    await manager.hydrateRoomSnapshot(client: client);

    verify(() => client.sync()).called(1);
    verify(() => gateway.getRoomById('!room:server')).called(1);
    expect(manager.currentRoom, same(room));
    expect(manager.currentRoomId, '!room:server');
  });

  test('inviteUser throws when no active room configured', () {
    expect(
      () => manager.inviteUser('@user:server'),
      throwsStateError,
    );
  });

  test('inviteUser delegates to current room invite', () async {
    final room = MockRoom();
    when(() => room.invite(any<String>())).thenAnswer((_) async {});
    when(() => gateway.getRoomById('!room:server')).thenReturn(room);
    when(() => settingsDb.itemByKey(matrixRoomKey))
        .thenAnswer((_) async => '!room:server');

    await manager.initialize();
    await manager.inviteUser('@user:server');

    verify(() => room.invite('@user:server')).called(1);
  });

  test('invite stream filters invalid room ids', () async {
    final invites = <SyncRoomInvite>[];
    final sub = manager.inviteRequests.listen(invites.add);

    final invalidInvite = MockRoomInviteEvent();
    when(() => invalidInvite.roomId).thenReturn('room');
    when(() => invalidInvite.senderId).thenReturn('@alice:server');

    inviteController.add(invalidInvite);
    await Future<void>(() {});

    expect(invites, isEmpty);
    verify(
      () => loggingService.captureEvent(
        contains('Discarding invite'),
        domain: 'SYNC_ROOM_MANAGER',
        subDomain: 'inviteFiltered',
      ),
    ).called(1);

    await sub.cancel();
  });

  test('invite stream emits validated invites', () async {
    when(() => gateway.getRoomById('!existing:server')).thenReturn(MockRoom());
    when(
      () => settingsDb.saveSettingsItem(matrixRoomKey, '!existing:server'),
    ).thenAnswer((_) async => 1);
    await manager.saveRoomId('!existing:server');

    final invite = MockRoomInviteEvent();
    when(() => invite.roomId).thenReturn('!existing:server');
    when(() => invite.senderId).thenReturn('@alice:server');

    final expectation = expectLater(
      manager.inviteRequests,
      emits(
        isA<SyncRoomInvite>()
            .having((invite) => invite.roomId, 'roomId', '!existing:server')
            .having((invite) => invite.senderId, 'senderId', '@alice:server')
            .having((invite) => invite.matchesExistingRoom,
                'matchesExistingRoom', isTrue),
      ),
    );

    inviteController.add(invite);
    await expectation;
  });

  test('leaveCurrentRoom clears state and notifies gateway', () async {
    final room = MockRoom();
    when(() => gateway.getRoomById('!room:server')).thenReturn(room);
    when(() => settingsDb.saveSettingsItem(matrixRoomKey, '!room:server'))
        .thenAnswer((_) async => 1);
    when(() => settingsDb.removeSettingsItem(matrixRoomKey))
        .thenAnswer((_) async {});
    when(() => gateway.leaveRoom('!room:server')).thenAnswer((_) async {});

    await manager.saveRoomId('!room:server');
    expect(manager.currentRoomId, '!room:server');

    await manager.leaveCurrentRoom();

    verify(() => gateway.leaveRoom('!room:server')).called(1);
    verify(() => settingsDb.removeSettingsItem(matrixRoomKey)).called(1);
    expect(manager.currentRoom, isNull);
    expect(manager.currentRoomId, isNull);
  });

  test('leaveCurrentRoom clears state when server says not in room', () async {
    when(() => settingsDb.itemByKey(matrixRoomKey))
        .thenAnswer((_) async => '!room:server');
    // Throw a MatrixException with M_NOT_FOUND
    final mex = MockMatrixException();
    when(() => mex.errcode).thenReturn('M_NOT_FOUND');
    when(() => gateway.leaveRoom('!room:server')).thenThrow(mex);

    await manager.initialize();
    await manager.leaveCurrentRoom();

    verify(() => settingsDb.removeSettingsItem(matrixRoomKey)).called(1);
    expect(manager.currentRoomId, isNull);
  });

  test('acceptInvite delegates to joinRoom and logs', () async {
    when(() => gateway.joinRoom('!inv:server')).thenAnswer((_) async {});
    when(() => settingsDb.saveSettingsItem(matrixRoomKey, '!inv:server'))
        .thenAnswer((_) async => 1);
    final invite = SyncRoomInvite(
      roomId: '!inv:server',
      senderId: '@alice:server',
      matchesExistingRoom: false,
    );

    await manager.acceptInvite(invite);

    verify(() => gateway.joinRoom('!inv:server')).called(1);
    verify(() => settingsDb.saveSettingsItem(matrixRoomKey, '!inv:server'))
        .called(1);
  });

  test('clearPersistedRoom clears state and logs', () async {
    when(() => settingsDb.removeSettingsItem(matrixRoomKey))
        .thenAnswer((_) async {});
    // prime a current room id
    when(() => settingsDb.itemByKey(matrixRoomKey))
        .thenAnswer((_) async => '!room:server');
    await manager.initialize();
    expect(manager.currentRoomId, '!room:server');

    await manager.clearPersistedRoom();

    verify(() => settingsDb.removeSettingsItem(matrixRoomKey)).called(1);
    expect(manager.currentRoomId, isNull);
  });
}
