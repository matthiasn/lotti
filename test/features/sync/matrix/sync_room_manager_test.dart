// ignore_for_file: unnecessary_lambdas

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/sync_room_discovery.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class MockMatrixGateway extends Mock implements MatrixSyncGateway {}

class MockRoomInviteEvent extends Mock implements RoomInviteEvent {}

class MockClient extends Mock implements Client {}

class MockMatrixException extends Mock implements MatrixException {}

class MockSyncRoomDiscoveryService extends Mock
    implements SyncRoomDiscoveryService {}

class FakeRoom extends Fake implements Room {}

class _GeneratedHydrateScenario {
  const _GeneratedHydrateScenario({
    required this.hasSavedRoom,
    required this.availabilitySlot,
  });

  final bool hasSavedRoom;
  final int availabilitySlot;

  String get roomId => '!generated-hydrate:server';

  int? get availableOnAttempt {
    if (!hasSavedRoom || availabilitySlot >= kSyncRoomLoadMaxAttempts) {
      return null;
    }
    return availabilitySlot + 1;
  }

  int get expectedSyncCalls {
    if (!hasSavedRoom) return 0;
    return availableOnAttempt ?? kSyncRoomLoadMaxAttempts;
  }

  bool get resolvesRoom => availableOnAttempt != null;

  @override
  String toString() {
    return '_GeneratedHydrateScenario('
        'hasSavedRoom: $hasSavedRoom, '
        'availabilitySlot: $availabilitySlot'
        ')';
  }
}

extension _AnyGeneratedHydrateScenario on glados.Any {
  glados.Generator<_GeneratedHydrateScenario> get hydrateScenario =>
      glados.CombinableAny(this).combine2(
        glados.BoolAny(this).bool,
        glados.IntAnys(this).intInRange(0, 6),
        (
          bool hasSavedRoom,
          int availabilitySlot,
        ) => _GeneratedHydrateScenario(
          hasSavedRoom: hasSavedRoom,
          availabilitySlot: availabilitySlot,
        ),
      );
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoom());
  });
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
    when(
      () => loggingService.captureEvent(
        any<String>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String?>(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(
      () => loggingService.captureException(
        any<dynamic>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String?>(named: 'subDomain'),
        stackTrace: any<dynamic>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => settingsDb.saveSettingsItem(any<String>(), any<String>()),
    ).thenAnswer((_) async => 1);
    when(
      () => settingsDb.removeSettingsItem(any<String>()),
    ).thenAnswer((_) async {});
    when(
      () => settingsDb.itemByKey(any<String>()),
    ).thenAnswer((_) async => null);

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
    when(
      () => settingsDb.itemByKey(matrixRoomKey),
    ).thenAnswer((_) async => null);

    await manager.initialize();

    verifyNever(() => gateway.getRoomById(any<String>()));
    expect(manager.currentRoom, isNull);
    expect(manager.currentRoomId, isNull);
  });

  test('initialize hydrates persisted room snapshot', () async {
    final room = MockRoom();
    when(
      () => settingsDb.itemByKey(matrixRoomKey),
    ).thenAnswer((_) async => '!room:server');
    when(() => gateway.getRoomById('!room:server')).thenReturn(room);

    await manager.initialize();

    verify(() => gateway.getRoomById('!room:server')).called(1);
    expect(manager.currentRoom, same(room));
    expect(manager.currentRoomId, '!room:server');
  });

  test('hydrateRoomSnapshot syncs client and resolves room', () async {
    final room = MockRoom();
    final client = MockClient();
    when(
      () => client.sync(),
    ).thenAnswer((_) async => SyncUpdate(nextBatch: 'token'));
    when(
      () => settingsDb.itemByKey(matrixRoomKey),
    ).thenAnswer((_) async => '!room:server');
    when(() => gateway.getRoomById('!room:server')).thenReturn(room);

    await manager.hydrateRoomSnapshot(client: client);

    verify(() => client.sync()).called(1);
    verify(() => gateway.getRoomById('!room:server')).called(1);
    expect(manager.currentRoom, same(room));
    expect(manager.currentRoomId, '!room:server');
  });

  glados.Glados(
    glados.any.hydrateScenario,
    glados.ExploreConfig(numRuns: 120),
  ).test(
    'generated hydrate retry loop stops when the room snapshot appears',
    (scenario) {
      fakeAsync((async) {
        final gateway = MockMatrixGateway();
        final settingsDb = MockSettingsDb();
        final loggingService = MockLoggingService();
        final inviteController = StreamController<RoomInviteEvent>.broadcast();
        when(() => gateway.invites).thenAnswer((_) => inviteController.stream);
        final manager = SyncRoomManager(
          gateway: gateway,
          settingsDb: settingsDb,
          loggingService: loggingService,
        );
        final room = MockRoom();
        final client = MockClient();
        var syncCalls = 0;
        var resolveCalls = 0;

        when(
          () => loggingService.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String?>(named: 'subDomain'),
          ),
        ).thenReturn(null);
        when(() => client.sync()).thenAnswer((_) async {
          syncCalls++;
          return SyncUpdate(nextBatch: 'generated-$syncCalls');
        });
        when(() => settingsDb.itemByKey(matrixRoomKey)).thenAnswer(
          (_) async => scenario.hasSavedRoom ? scenario.roomId : null,
        );
        when(() => gateway.getRoomById(scenario.roomId)).thenAnswer((_) {
          resolveCalls++;
          final availableOnAttempt = scenario.availableOnAttempt;
          if (availableOnAttempt != null && syncCalls >= availableOnAttempt) {
            return room;
          }
          return null;
        });

        unawaited(manager.hydrateRoomSnapshot(client: client));
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 8))
          ..flushMicrotasks();

        expect(syncCalls, scenario.expectedSyncCalls, reason: '$scenario');
        expect(
          resolveCalls,
          scenario.expectedSyncCalls,
          reason: '$scenario',
        );
        expect(
          manager.currentRoom,
          scenario.resolvesRoom ? same(room) : isNull,
          reason: '$scenario',
        );
        expect(
          manager.currentRoomId,
          scenario.resolvesRoom
              ? scenario.roomId
              : scenario.hasSavedRoom
              ? scenario.roomId
              : isNull,
          reason: '$scenario',
        );
        unawaited(manager.dispose());
        unawaited(inviteController.close());
        async.flushMicrotasks();
      });
    },
    tags: 'glados',
  );

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
    when(
      () => settingsDb.itemByKey(matrixRoomKey),
    ).thenAnswer((_) async => '!room:server');

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
    // Yield an event-loop turn, then flush microtasks deterministically
    await Future<void>.delayed(Duration.zero);
    fakeAsync((async) => async.flushMicrotasks());

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
            .having(
              (invite) => invite.matchesExistingRoom,
              'matchesExistingRoom',
              isTrue,
            ),
      ),
    );

    inviteController.add(invite);
    await expectation;
  });

  test('leaveCurrentRoom clears state and notifies gateway', () async {
    final room = MockRoom();
    when(() => gateway.getRoomById('!room:server')).thenReturn(room);
    when(
      () => settingsDb.saveSettingsItem(matrixRoomKey, '!room:server'),
    ).thenAnswer((_) async => 1);
    when(
      () => settingsDb.removeSettingsItem(matrixRoomKey),
    ).thenAnswer((_) async {});
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
    when(
      () => settingsDb.itemByKey(matrixRoomKey),
    ).thenAnswer((_) async => '!room:server');
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
    when(
      () => settingsDb.saveSettingsItem(matrixRoomKey, '!inv:server'),
    ).thenAnswer((_) async => 1);
    final invite = SyncRoomInvite(
      roomId: '!inv:server',
      senderId: '@alice:server',
      matchesExistingRoom: false,
    );

    await manager.acceptInvite(invite);

    verify(() => gateway.joinRoom('!inv:server')).called(1);
    verify(
      () => settingsDb.saveSettingsItem(matrixRoomKey, '!inv:server'),
    ).called(1);
  });

  test('clearPersistedRoom clears state and logs', () async {
    when(
      () => settingsDb.removeSettingsItem(matrixRoomKey),
    ).thenAnswer((_) async {});
    // prime a current room id
    when(
      () => settingsDb.itemByKey(matrixRoomKey),
    ).thenAnswer((_) async => '!room:server');
    await manager.initialize();
    expect(manager.currentRoomId, '!room:server');

    await manager.clearPersistedRoom();

    verify(() => settingsDb.removeSettingsItem(matrixRoomKey)).called(1);
    expect(manager.currentRoomId, isNull);
  });

  group('room discovery integration', () {
    late MockSyncRoomDiscoveryService discoveryService;
    late SyncRoomManager managerWithDiscovery;
    late StreamController<RoomInviteEvent> inviteController2;

    setUp(() {
      discoveryService = MockSyncRoomDiscoveryService();
      inviteController2 = StreamController<RoomInviteEvent>.broadcast();

      when(() => gateway.invites).thenAnswer((_) => inviteController2.stream);

      managerWithDiscovery = SyncRoomManager(
        gateway: gateway,
        settingsDb: settingsDb,
        loggingService: loggingService,
        discoveryService: discoveryService,
      );
    });

    tearDown(() async {
      await managerWithDiscovery.dispose();
      await inviteController2.close();
    });

    test(
      'discoverExistingSyncRooms returns empty when no discovery service',
      () async {
        // manager without discovery service
        final rooms = await manager.discoverExistingSyncRooms();
        expect(rooms, isEmpty);
      },
    );

    test('discoverExistingSyncRooms delegates to discovery service', () async {
      final client = MockClient();
      final candidates = [
        const SyncRoomCandidate(
          roomId: '!room1:server',
          roomName: 'Room 1',
          createdAt: null,
          memberCount: 2,
          hasStateMarker: true,
          hasLottiContent: true,
        ),
      ];

      when(() => gateway.client).thenReturn(client);
      when(
        () => discoveryService.discoverSyncRooms(client),
      ).thenAnswer((_) async => candidates);

      final rooms = await managerWithDiscovery.discoverExistingSyncRooms();

      expect(rooms, equals(candidates));
      verify(() => discoveryService.discoverSyncRooms(client)).called(1);
    });

    test(
      'createRoom marks room with Lotti state when discovery service exists',
      () async {
        final room = MockRoom();
        final client = MockClient();
        when(() => gateway.client).thenReturn(client);
        when(() => client.userID).thenReturn('@lotti_user:example.com');
        when(
          () => gateway.createRoom(
            name: any(named: 'name'),
            inviteUserIds: any(named: 'inviteUserIds'),
          ),
        ).thenAnswer((_) async => '!newroom:server');
        when(() => gateway.getRoomById('!newroom:server')).thenReturn(room);
        when(
          () => settingsDb.saveSettingsItem(matrixRoomKey, '!newroom:server'),
        ).thenAnswer((_) async => 1);
        when(
          () => discoveryService.markRoomAsLottiSync(room),
        ).thenAnswer((_) async {});

        await managerWithDiscovery.createRoom();

        verify(() => discoveryService.markRoomAsLottiSync(room)).called(1);
      },
    );

    test('createRoom includes the creator username in room name', () async {
      final client = MockClient();
      when(() => gateway.client).thenReturn(client);
      when(() => client.userID).thenReturn('@lotti_user:example.com');
      when(
        () => gateway.createRoom(
          name: any(named: 'name'),
          inviteUserIds: any(named: 'inviteUserIds'),
        ),
      ).thenAnswer((_) async => '!newroom:server');
      when(
        () => settingsDb.saveSettingsItem(matrixRoomKey, '!newroom:server'),
      ).thenAnswer((_) async => 1);
      when(() => gateway.getRoomById('!newroom:server')).thenReturn(null);

      await managerWithDiscovery.createRoom();

      final name =
          verify(
                () => gateway.createRoom(
                  name: captureAny(named: 'name'),
                  inviteUserIds: any(named: 'inviteUserIds'),
                ),
              ).captured.single
              as String;
      expect(name, contains('Lotti Sync (lotti_user)'));
    });

    test(
      'createRoom does not mark room when gateway returns null room',
      () async {
        final client = MockClient();
        when(() => gateway.client).thenReturn(client);
        when(() => client.userID).thenReturn('@lotti_user:example.com');
        when(
          () => gateway.createRoom(
            name: any(named: 'name'),
            inviteUserIds: any(named: 'inviteUserIds'),
          ),
        ).thenAnswer((_) async => '!newroom:server');
        when(() => gateway.getRoomById('!newroom:server')).thenReturn(null);
        when(
          () => settingsDb.saveSettingsItem(matrixRoomKey, '!newroom:server'),
        ).thenAnswer((_) async => 1);

        await managerWithDiscovery.createRoom();

        verifyNever(() => discoveryService.markRoomAsLottiSync(any()));
      },
    );
  });
}
