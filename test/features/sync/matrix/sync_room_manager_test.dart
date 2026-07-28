// ignore_for_file: unnecessary_lambdas

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
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

class MockClient extends Mock implements Client {}

class MockMatrixException extends Mock implements MatrixException {}

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
  late SyncRoomManager manager;

  setUp(() {
    gateway = MockMatrixGateway();
    settingsDb = MockSettingsDb();
    loggingService = MockDomainLogger();
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
        async.flushMicrotasks();
      });
    },
    tags: 'glados',
  );

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

  // ---------------------------------------------------------------------------
  // Tests originally in room_test.dart
  // ---------------------------------------------------------------------------
  group('SyncRoomManager (room_test)', () {
    late _MockMatrixSyncGateway mockGateway;
    late MockSettingsDb mockSettingsDb;
    late MockDomainLogger mockLoggingService;
    late SyncRoomManager manager;
    late MockRoom mockRoom;
    late _MockMatrixClient mockClient;

    setUp(() {
      registerFallbackValue(StackTrace.empty);
      mockGateway = _MockMatrixSyncGateway();
      mockSettingsDb = MockSettingsDb();
      mockLoggingService = MockDomainLogger();
      mockRoom = MockRoom();
      mockClient = _MockMatrixClient();

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
  });

  group('roomIdChanges', () {
    test('emits on join and on clear, so UI can gate on configured', () async {
      // `currentRoomId` is a plain field. Without this stream the device
      // roster stays on screen for a room the account can no longer join,
      // because the clear happens after the login event has already fired.
      when(
        () => settingsDb.saveSettingsItem(matrixRoomKey, '!room:server'),
      ).thenAnswer((_) async => 1);
      when(() => gateway.getRoomById('!room:server')).thenReturn(MockRoom());

      final seen = <String?>[];
      final sub = manager.roomIdChanges.listen(seen.add);
      addTearDown(sub.cancel);

      await manager.saveRoomId('!room:server');
      await manager.clearPersistedRoom();
      await pumpEventQueue();

      expect(seen, ['!room:server', null]);
    });

    test(
      'stays silent when the id is set to the value it already has',
      () async {
        when(
          () => settingsDb.saveSettingsItem(matrixRoomKey, '!room:server'),
        ).thenAnswer((_) async => 1);
        when(() => gateway.getRoomById('!room:server')).thenReturn(MockRoom());

        final seen = <String?>[];
        final sub = manager.roomIdChanges.listen(seen.add);
        addTearDown(sub.cancel);

        await manager.saveRoomId('!room:server');
        await manager.saveRoomId('!room:server');
        await pumpEventQueue();

        // A re-save on every sync tick would otherwise rebuild the roster
        // repeatedly for no change.
        expect(seen, ['!room:server']);
      },
    );

    test(
      'a clear after dispose does not throw on the closed controller',
      () async {
        await manager.dispose();

        // dispose() is racy by nature: teardown can land while a leave is still
        // in flight, and an add on a closed controller would surface as an
        // unhandled error rather than a no-op.
        await expectLater(manager.clearPersistedRoom(), completes);
      },
    );
  });
}
