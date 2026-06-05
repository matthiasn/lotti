// ignore_for_file: unnecessary_lambdas

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/sync_room_discovery.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

// ---------------------------------------------------------------------------
// room_test.dart mocks (local to this file; use the same interfaces as
// MockMatrixGateway / MockClient declared above but are only referenced inside
// the 'SyncRoomManager (room_test)' group below)
// ---------------------------------------------------------------------------
class _MockMatrixSyncGateway extends Mock implements MatrixSyncGateway {}

class _MockMatrixClient extends Mock implements Client {}

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
  late MockDomainLogger loggingService;
  late StreamController<RoomInviteEvent> inviteController;
  late SyncRoomManager manager;

  setUp(() {
    gateway = MockMatrixGateway();
    settingsDb = MockSettingsDb();
    loggingService = MockDomainLogger();
    inviteController = StreamController<RoomInviteEvent>.broadcast();

    when(() => gateway.invites).thenAnswer((_) => inviteController.stream);
    when(
      () => loggingService.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any<String?>(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(
      () => loggingService.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace>(named: 'stackTrace'),
        subDomain: any<String?>(named: 'subDomain'),
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
        final loggingService = MockDomainLogger();
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
          () => loggingService.log(
            any<LogDomain>(),
            any<String>(),
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
      () => loggingService.log(
        LogDomain.sync,
        any<String>(that: contains('Discarding invite')),
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

  // ---------------------------------------------------------------------------
  // Tests originally in room_test.dart
  // ---------------------------------------------------------------------------
  group('SyncRoomManager (room_test)', () {
    late _MockMatrixSyncGateway mockGateway;
    late MockSettingsDb mockSettingsDb;
    late MockDomainLogger mockLoggingService;
    late SyncRoomManager manager;
    late StreamController<RoomInviteEvent> inviteController;
    late MockRoom mockRoom;
    late _MockMatrixClient mockClient;

    setUp(() {
      registerFallbackValue(StackTrace.empty);
      mockGateway = _MockMatrixSyncGateway();
      mockSettingsDb = MockSettingsDb();
      mockLoggingService = MockDomainLogger();
      inviteController = StreamController<RoomInviteEvent>.broadcast();
      mockRoom = MockRoom();
      mockClient = _MockMatrixClient();

      when(
        () => mockGateway.invites,
      ).thenAnswer((_) => inviteController.stream);
      when(() => mockGateway.getRoomById(any<String>())).thenReturn(null);
      when(
        () => mockSettingsDb.itemByKey(any<String>()),
      ).thenAnswer((_) async => null);
      when(
        () => mockLoggingService.log(
          any<LogDomain>(),
          any<String>(),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) {});
      when(
        () => mockLoggingService.error(
          any<LogDomain>(),
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenAnswer((_) async {});

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

    test('initialize loads persisted room and resolves snapshot', () async {
      when(
        () => mockSettingsDb.itemByKey(matrixRoomKey),
      ).thenAnswer((_) async => '!room:server');
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
      when(
        () => mockSettingsDb.itemByKey(matrixRoomKey),
      ).thenAnswer((_) async => '!room:server');
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

    test(
      'leaveCurrentRoom clears persisted id and leaves gateway room',
      () async {
        when(
          () => mockSettingsDb.itemByKey(matrixRoomKey),
        ).thenAnswer((_) async => '!room:server');
        when(
          () => mockGateway.getRoomById('!room:server'),
        ).thenReturn(mockRoom);
        when(
          () => mockSettingsDb.removeSettingsItem(matrixRoomKey),
        ).thenAnswer((_) async {});
        when(
          () => mockGateway.leaveRoom('!room:server'),
        ).thenAnswer((_) async {});

        await manager.initialize();
        await manager.leaveCurrentRoom();

        verify(() => mockGateway.leaveRoom('!room:server')).called(1);
        verify(
          () => mockSettingsDb.removeSettingsItem(matrixRoomKey),
        ).called(1);
        expect(manager.currentRoomId, isNull);
        expect(manager.currentRoom, isNull);
      },
    );

    test('inviteUser throws when no room is configured', () async {
      await manager.initialize();
      expect(
        () => manager.inviteUser('@user:server'),
        throwsStateError,
      );
    });

    test('inviteUser delegates to current room when available', () async {
      when(() => mockGateway.getRoomById('!room:server')).thenReturn(mockRoom);
      when(
        () => mockSettingsDb.saveSettingsItem(matrixRoomKey, '!room:server'),
      ).thenAnswer((_) async => 1);
      when(() => mockRoom.invite('@user:server')).thenAnswer((_) async {});

      await manager.saveRoomId('!room:server');
      await manager.inviteUser('@user:server');

      verify(() => mockRoom.invite('@user:server')).called(1);
    });

    test('createRoom persists room id and resolves snapshot', () async {
      when(
        () => mockGateway.createRoom(
          name: any<String>(named: 'name'),
          inviteUserIds: ['@user:server'],
        ),
      ).thenAnswer((_) async => '!created:room');
      when(
        () => mockSettingsDb.saveSettingsItem(matrixRoomKey, '!created:room'),
      ).thenAnswer((_) async => 1);
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
      verify(
        () => mockSettingsDb.saveSettingsItem(matrixRoomKey, '!created:room'),
      ).called(1);
    });

    test('loadPersistedRoomId caches value after first lookup', () async {
      when(
        () => mockSettingsDb.itemByKey(matrixRoomKey),
      ).thenAnswer((_) async => '!cached:room');

      final first = await manager.loadPersistedRoomId();
      final second = await manager.loadPersistedRoomId();

      expect(first, '!cached:room');
      expect(second, '!cached:room');
      verify(() => mockSettingsDb.itemByKey(matrixRoomKey)).called(1);
    });

    test('hydrateRoomSnapshot resolves room after retry', () {
      when(
        () => mockSettingsDb.itemByKey(matrixRoomKey),
      ).thenAnswer((_) async => '!retry:room');
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
        () => mockLoggingService.log(
          LogDomain.sync,
          'No saved room ID found during hydrateRoomSnapshot.',
          subDomain: 'hydrate',
        ),
      ).called(1);
    });

    test('hydrateRoomSnapshot logs failure after max attempts', () {
      when(
        () => mockSettingsDb.itemByKey(matrixRoomKey),
      ).thenAnswer((_) async => '!missing:room');
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
        () => mockLoggingService.log(
          LogDomain.sync,
          any<String>(that: contains('Failed to resolve room !missing:room')),
          subDomain: 'hydrate',
        ),
      ).called(1);
    });

    test('leaveCurrentRoom skips gateway call when no room stored', () async {
      when(
        () => mockSettingsDb.itemByKey(matrixRoomKey),
      ).thenAnswer((_) async => null);

      await manager.initialize();
      await manager.leaveCurrentRoom();

      verifyNever(() => mockGateway.leaveRoom(any<String>()));
    });

    test('leaveCurrentRoom preserves state when leave fails', () async {
      when(
        () => mockSettingsDb.saveSettingsItem(matrixRoomKey, '!room:server'),
      ).thenAnswer((_) async => 1);
      await manager.saveRoomId('!room:server');
      when(
        () => mockGateway.leaveRoom('!room:server'),
      ).thenThrow(Exception('network error'));

      expect(
        () => manager.leaveCurrentRoom(),
        throwsException,
      );
      expect(manager.currentRoomId, '!room:server');
      verifyNever(() => mockSettingsDb.removeSettingsItem(matrixRoomKey));
      verify(
        () => mockLoggingService.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'leaveRoom',
        ),
      ).called(1);
    });
  });
}
