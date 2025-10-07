import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixSyncGateway extends Mock implements MatrixSyncGateway {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockLoggingService extends Mock implements LoggingService {}

class MockRoom extends Mock implements Room {}

class MockMatrixClient extends Mock implements Client {}

void main() {
  late MockMatrixSyncGateway mockGateway;
  late MockSettingsDb mockSettingsDb;
  late MockLoggingService mockLoggingService;
  late SyncRoomManager manager;
  late StreamController<RoomInviteEvent> inviteController;
  late MockRoom mockRoom;
  late MockMatrixClient mockClient;

  setUp(() {
    registerFallbackValue(StackTrace.empty);
    mockGateway = MockMatrixSyncGateway();
    mockSettingsDb = MockSettingsDb();
    mockLoggingService = MockLoggingService();
    inviteController = StreamController<RoomInviteEvent>.broadcast();
    mockRoom = MockRoom();
    mockClient = MockMatrixClient();

    when(() => mockGateway.invites).thenAnswer((_) => inviteController.stream);
    when(() => mockGateway.getRoomById(any<String>())).thenReturn(null);
    when(() => mockSettingsDb.itemByKey(any<String>()))
        .thenAnswer((_) async => null);
    when(
      () => mockLoggingService.captureEvent(
        any<String>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenAnswer((_) {});
    when(
      () => mockLoggingService.captureException(
        any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) {});

    manager = SyncRoomManager(
      gateway: mockGateway,
      settingsDb: mockSettingsDb,
      loggingService: mockLoggingService,
    );
  });

  tearDown(() async {
    await manager.dispose();
    await inviteController.close();
  });

  group('SyncRoomManager', () {
    test('initialize loads persisted room and resolves snapshot', () async {
      when(() => mockSettingsDb.itemByKey(matrixRoomKey))
          .thenAnswer((_) async => '!room:server');
      when(() => mockGateway.getRoomById('!room:server')).thenReturn(mockRoom);

      await manager.initialize();

      expect(manager.currentRoomId, '!room:server');
      expect(manager.currentRoom, mockRoom);
    });

    test('emits invite requests for valid room ids', () async {
      await manager.initialize();
      final invites = <SyncRoomInvite>[];
      final sub = manager.inviteRequests.listen(invites.add);

      inviteController.add(
        const RoomInviteEvent(
          roomId: '!room:server',
          senderId: '@user:server',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(invites, hasLength(1));
      expect(invites.first.roomId, '!room:server');
      expect(invites.first.senderId, '@user:server');
      expect(invites.first.matchesExistingRoom, isFalse);
      await sub.cancel();
    });

    test('ignores invites with invalid room id', () async {
      await manager.initialize();
      final invites = <SyncRoomInvite>[];
      final sub = manager.inviteRequests.listen(invites.add);

      inviteController.add(
        const RoomInviteEvent(
          roomId: 'not-a-room',
          senderId: '@user:server',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(invites, isEmpty);
      await sub.cancel();
    });

    test('marks invite as matching when ids align', () async {
      when(() => mockSettingsDb.itemByKey(matrixRoomKey))
          .thenAnswer((_) async => '!room:server');
      when(() => mockGateway.getRoomById('!room:server')).thenReturn(mockRoom);

      await manager.initialize();

      final invites = <SyncRoomInvite>[];
      final sub = manager.inviteRequests.listen(invites.add);

      inviteController.add(
        const RoomInviteEvent(
          roomId: '!room:server',
          senderId: '@user:server',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(invites.single.matchesExistingRoom, isTrue);
      await sub.cancel();
    });

    test('acceptInvite joins room and persists id', () async {
      when(() => mockGateway.joinRoom('!room:server')).thenAnswer((_) async {});
      when(
        () => mockSettingsDb.saveSettingsItem(matrixRoomKey, '!room:server'),
      ).thenAnswer((_) async => 1);
      when(() => mockGateway.getRoomById('!room:server')).thenReturn(mockRoom);

      await manager.initialize();

      final invite = SyncRoomInvite(
        roomId: '!room:server',
        senderId: '@user:server',
        matchesExistingRoom: false,
      );
      await manager.acceptInvite(invite);

      verify(() => mockGateway.joinRoom('!room:server')).called(1);
      verify(
        () => mockSettingsDb.saveSettingsItem(
          matrixRoomKey,
          '!room:server',
        ),
      ).called(1);
      expect(manager.currentRoomId, '!room:server');
      expect(manager.currentRoom, mockRoom);
    });

    test('leaveCurrentRoom clears persisted id and leaves gateway room',
        () async {
      when(() => mockSettingsDb.itemByKey(matrixRoomKey))
          .thenAnswer((_) async => '!room:server');
      when(() => mockGateway.getRoomById('!room:server')).thenReturn(mockRoom);
      when(() => mockSettingsDb.removeSettingsItem(matrixRoomKey))
          .thenAnswer((_) async {});
      when(() => mockGateway.leaveRoom('!room:server'))
          .thenAnswer((_) async {});

      await manager.initialize();
      await manager.leaveCurrentRoom();

      verify(() => mockGateway.leaveRoom('!room:server')).called(1);
      verify(() => mockSettingsDb.removeSettingsItem(matrixRoomKey)).called(1);
      expect(manager.currentRoomId, isNull);
      expect(manager.currentRoom, isNull);
    });

    test('inviteUser throws when no room is configured', () async {
      await manager.initialize();
      expect(
        () => manager.inviteUser('@user:server'),
        throwsStateError,
      );
    });

    test('inviteUser delegates to current room when available', () async {
      when(() => mockGateway.getRoomById('!room:server')).thenReturn(mockRoom);
      when(() => mockSettingsDb.saveSettingsItem(matrixRoomKey, '!room:server'))
          .thenAnswer((_) async => 1);
      when(() => mockRoom.invite('@user:server')).thenAnswer((_) async {});

      await manager.saveRoomId('!room:server');
      await manager.inviteUser('@user:server');

      verify(() => mockRoom.invite('@user:server')).called(1);
    });

    test('createRoom persists room id and resolves snapshot', () async {
      when(() => mockGateway.createRoom(
            name: any<String>(named: 'name'),
            inviteUserIds: ['@user:server'],
          )).thenAnswer((_) async => '!created:room');
      when(() =>
              mockSettingsDb.saveSettingsItem(matrixRoomKey, '!created:room'))
          .thenAnswer((_) async => 1);
      when(() => mockGateway.getRoomById('!created:room')).thenReturn(mockRoom);

      final roomId = await manager.createRoom(inviteUserIds: ['@user:server']);

      expect(roomId, '!created:room');
      expect(manager.currentRoomId, '!created:room');
      expect(manager.currentRoom, mockRoom);
      verify(
        () => mockGateway.createRoom(
          name: any<String>(named: 'name'),
          inviteUserIds: ['@user:server'],
        ),
      ).called(1);
      verify(() =>
              mockSettingsDb.saveSettingsItem(matrixRoomKey, '!created:room'))
          .called(1);
    });

    test('loadPersistedRoomId caches value after first lookup', () async {
      when(() => mockSettingsDb.itemByKey(matrixRoomKey))
          .thenAnswer((_) async => '!cached:room');

      final first = await manager.loadPersistedRoomId();
      final second = await manager.loadPersistedRoomId();

      expect(first, '!cached:room');
      expect(second, '!cached:room');
      verify(() => mockSettingsDb.itemByKey(matrixRoomKey)).called(1);
    });

    test('hydrateRoomSnapshot resolves room after retry', () {
      when(() => mockSettingsDb.itemByKey(matrixRoomKey))
          .thenAnswer((_) async => '!retry:room');
      var attempt = 0;
      when(() => mockGateway.getRoomById('!retry:room')).thenAnswer((_) {
        attempt++;
        return attempt >= 3 ? mockRoom : null;
      });
      var syncCalls = 0;
      when(() => mockClient.sync()).thenAnswer((_) async {
        syncCalls++;
        return SyncUpdate(nextBatch: 'token');
      });

      fakeAsync((async) {
        async.flushMicrotasks();
        manager.initialize();
        async.flushMicrotasks();

        var completed = false;
        manager
            .hydrateRoomSnapshot(client: mockClient)
            .then((_) => completed = true);

        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 1000))
          ..flushTimers()
          ..elapse(const Duration(milliseconds: 2000))
          ..flushTimers()
          ..flushMicrotasks();

        expect(manager.currentRoom, mockRoom);
        expect(manager.currentRoomId, '!retry:room');
        expect(syncCalls, 2);
        expect(completed, isTrue);
      });
    });

    test('hydrateRoomSnapshot logs when no room id saved', () async {
      await manager.initialize();
      await manager.hydrateRoomSnapshot(client: mockClient);

      verify(
        () => mockLoggingService.captureEvent(
          'No saved room ID found during hydrateRoomSnapshot.',
          domain: 'SYNC_ROOM_MANAGER',
          subDomain: 'hydrate',
        ),
      ).called(1);
    });

    test('hydrateRoomSnapshot logs failure after max attempts', () {
      when(() => mockSettingsDb.itemByKey(matrixRoomKey))
          .thenAnswer((_) async => '!missing:room');
      when(() => mockGateway.getRoomById('!missing:room')).thenReturn(null);
      var syncCalls = 0;
      when(() => mockClient.sync()).thenAnswer((_) async {
        syncCalls++;
        return SyncUpdate(nextBatch: 'token');
      });

      fakeAsync((async) {
        manager.initialize();
        async.flushMicrotasks();

        var completed = false;
        manager
            .hydrateRoomSnapshot(client: mockClient)
            .then((_) => completed = true);

        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 1000))
          ..flushTimers()
          ..elapse(const Duration(milliseconds: 2000))
          ..flushTimers()
          ..elapse(const Duration(milliseconds: 4000))
          ..flushTimers()
          ..flushMicrotasks();

        expect(manager.currentRoom, isNull);
        expect(syncCalls, 4);
        expect(completed, isTrue);
      });

      verify(
        () => mockLoggingService.captureEvent(
          contains('Failed to resolve room !missing:room'),
          domain: 'SYNC_ROOM_MANAGER',
          subDomain: 'hydrate',
        ),
      ).called(1);
    });

    test('leaveCurrentRoom skips gateway call when no room stored', () async {
      when(() => mockSettingsDb.itemByKey(matrixRoomKey))
          .thenAnswer((_) async => null);

      await manager.initialize();
      await manager.leaveCurrentRoom();

      verifyNever(() => mockGateway.leaveRoom(any<String>()));
    });

    test('leaveCurrentRoom preserves state when leave fails', () async {
      when(() => mockSettingsDb.saveSettingsItem(matrixRoomKey, '!room:server'))
          .thenAnswer((_) async => 1);
      await manager.saveRoomId('!room:server');
      when(() => mockGateway.leaveRoom('!room:server'))
          .thenThrow(Exception('network error'));

      expect(
        () => manager.leaveCurrentRoom(),
        throwsException,
      );
      expect(manager.currentRoomId, '!room:server');
      verifyNever(() => mockSettingsDb.removeSettingsItem(matrixRoomKey));
      verify(
        () => mockLoggingService.captureException(
          any<Object>(),
          domain: 'SYNC_ROOM_MANAGER',
          subDomain: 'leaveRoom',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });
}
