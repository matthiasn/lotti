import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/matrix_service_ops.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_consumer.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/queue/inbound_queue_models.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

QueueStats _stats({
  int total = 0,
  int applied = 0,
  int abandoned = 0,
  int retrying = 0,
}) => QueueStats(
  total: total,
  byProducer: const {},
  readyNow: 0,
  oldestEnqueuedAt: null,
  applied: applied,
  abandoned: abandoned,
  retrying: retrying,
);

void main() {
  setUpAll(() {
    registerFallbackValue(LogDomain.sync);
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(
      AuthenticationPassword(
        password: 'fallback',
        identifier: AuthenticationUserIdentifier(user: '@fallback:server'),
      ),
    );
  });

  late MockMatrixSyncGateway gateway;
  late MockDomainLogger logging;
  late MockQueuePipelineCoordinator coordinator;
  late MockInboundQueue queue;
  late MockSyncRoomManager roomManager;
  late MockMatrixSessionManager sessionManager;
  late MockSyncEngine syncEngine;
  late MockMatrixStreamConsumer pipeline;
  late StreamController<KeyVerification> incomingController;
  late MatrixStreamConsumer? currentPipeline;
  late StreamSubscription<KeyVerification>? keyVerSub;

  MatrixServiceOps buildOps({MatrixService Function()? service}) =>
      MatrixServiceOps(
        gateway: gateway,
        loggingService: logging,
        collectSyncMetrics: true,
        queueCoordinator: coordinator,
        roomManager: roomManager,
        sessionManager: sessionManager,
        syncEngine: syncEngine,
        incomingKeyVerificationController: incomingController,
        pipeline: () => currentPipeline,
        keyVerificationRequestSubscription: () => keyVerSub,
        setKeyVerificationRequestSubscription: (value) => keyVerSub = value,
        // The service() seam is only used by the key-verification round-trips
        // (covered by the parent MatrixService tests) and by deleteDevice's
        // runner cancellation, which injects a mock service explicitly.
        service:
            service ??
            () => throw UnimplementedError('service() not used in this test'),
      );

  setUp(() {
    gateway = MockMatrixSyncGateway();
    logging = MockDomainLogger();
    coordinator = MockQueuePipelineCoordinator();
    queue = MockInboundQueue();
    roomManager = MockSyncRoomManager();
    sessionManager = MockMatrixSessionManager();
    syncEngine = MockSyncEngine();
    pipeline = MockMatrixStreamConsumer();
    incomingController = StreamController<KeyVerification>.broadcast();
    currentPipeline = pipeline;
    keyVerSub = null;

    when(() => coordinator.queue).thenReturn(queue);
    when(() => coordinator.triggerBridge()).thenAnswer((_) async {});
    when(() => coordinator.onRoomChanged(any())).thenAnswer((_) async {});
    when(() => coordinator.isRunning).thenReturn(false);
  });

  tearDown(() async {
    await incomingController.close();
  });

  group('room operations', () {
    test('joinRoom returns the joined room id', () async {
      final room = MockRoom();
      when(() => room.id).thenReturn('!joined:server');
      when(() => roomManager.joinRoom(any())).thenAnswer((_) async => room);

      expect(await buildOps().joinRoom('!req:server'), '!joined:server');
      verify(() => roomManager.joinRoom('!req:server')).called(1);
    });

    test(
      'joinRoom falls back to the requested id when no room returns',
      () async {
        when(() => roomManager.joinRoom(any())).thenAnswer((_) async => null);

        expect(await buildOps().joinRoom('!req:server'), '!req:server');
      },
    );

    test('createRoom forwards invite ids to the room manager', () async {
      when(
        () =>
            roomManager.createRoom(inviteUserIds: any(named: 'inviteUserIds')),
      ).thenAnswer((_) async => '!new:server');

      expect(
        await buildOps().createRoom(invite: const ['@a:server']),
        '!new:server',
      );
      verify(
        () => roomManager.createRoom(inviteUserIds: const ['@a:server']),
      ).called(1);
    });

    test('getRoom returns the persisted room id', () async {
      when(
        roomManager.loadPersistedRoomId,
      ).thenAnswer((_) async => '!persisted:server');

      expect(await buildOps().getRoom(), '!persisted:server');
    });

    test('clearPersistedRoom delegates to the room manager', () async {
      when(roomManager.clearPersistedRoom).thenAnswer((_) async {});

      await buildOps().clearPersistedRoom();
      verify(roomManager.clearPersistedRoom).called(1);
    });

    test('leaveRoom logs and delegates to the room manager', () async {
      when(roomManager.leaveCurrentRoom).thenAnswer((_) async {});

      await buildOps().leaveRoom();
      verify(roomManager.leaveCurrentRoom).called(1);
      verify(
        () => logging.log(
          LogDomain.sync,
          any(),
          subDomain: 'room.leave',
        ),
      ).called(1);
    });

    test(
      'inviteToSyncRoom delegates the user id to the room manager',
      () async {
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => roomManager.inviteUser(any())).thenAnswer((_) async {});

        await buildOps().inviteToSyncRoom(userId: '@guest:server');
        verify(() => roomManager.inviteUser('@guest:server')).called(1);
      },
    );

    test('acceptInvite delegates the invite to the room manager', () async {
      final invite = SyncRoomInvite(
        roomId: '!room:server',
        senderId: '@host:server',
        matchesExistingRoom: false,
      );
      when(() => roomManager.acceptInvite(invite)).thenAnswer((_) async {});

      await buildOps().acceptInvite(invite);
      verify(() => roomManager.acceptInvite(invite)).called(1);
    });

    test('isLoggedIn reflects the session manager state', () {
      when(sessionManager.isLoggedIn).thenReturn(true);
      expect(buildOps().isLoggedIn(), isTrue);
    });
  });

  group('saveRoom', () {
    test(
      'starts the pipeline, seeds the room, then nudges the bridge',
      () async {
        when(() => roomManager.saveRoomId(any())).thenAnswer((_) async {});
        when(pipeline.start).thenAnswer((_) async {});

        await buildOps().saveRoom('!room:server');
        // The bootstrap runs in an unawaited microtask chain; flush it.
        await Future<void>.delayed(Duration.zero);

        verify(() => roomManager.saveRoomId('!room:server')).called(1);
        verify(pipeline.start).called(1);
        verify(() => coordinator.onRoomChanged('!room:server')).called(1);
        verify(() => coordinator.triggerBridge()).called(1);
      },
    );

    test(
      'logs and swallows bootstrap failures so they never escape the task',
      () async {
        when(() => roomManager.saveRoomId(any())).thenAnswer((_) async {});
        when(pipeline.start).thenAnswer((_) async {});
        when(
          () => coordinator.onRoomChanged(any()),
        ).thenThrow(Exception('boom'));

        await buildOps().saveRoom('!room:server');
        await Future<void>.delayed(Duration.zero);

        verify(
          () => logging.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'saveRoom.bootstrap',
          ),
        ).called(1);
      },
    );
  });

  group('device operations', () {
    test('getUnverifiedDevices returns the gateway list', () {
      final keys = <DeviceKeys>[];
      when(gateway.unverifiedDevices).thenReturn(keys);
      expect(buildOps().getUnverifiedDevices(), same(keys));
    });
  });

  group('deleteDevice', () {
    const userId = '@user:server';
    late MockMatrixClient client;
    late MockSyncLifecycleCoordinator lifecycle;
    late MockMatrixService svc;
    late MockDeviceKeys deviceKeys;

    MatrixServiceOps buildDeleteOps() => buildOps(service: () => svc);

    setUp(() {
      client = MockMatrixClient();
      lifecycle = MockSyncLifecycleCoordinator();
      svc = MockMatrixService();
      deviceKeys = MockDeviceKeys();

      when(() => sessionManager.client).thenReturn(client);
      when(() => sessionManager.matrixConfig).thenReturn(
        const MatrixConfig(
          homeServer: 'https://server',
          user: userId,
          password: 'secret',
        ),
      );
      when(() => client.userID).thenReturn(userId);
      when(() => gateway.currentDeviceId).thenReturn('THIS_DEVICE');
      when(
        () => gateway.deleteDevice(any(), auth: any(named: 'auth')),
      ).thenAnswer((_) async {});
      when(
        () => client.updateUserDeviceKeys(
          additionalUsers: any(named: 'additionalUsers'),
        ),
      ).thenAnswer((_) async {});
      when(() => syncEngine.lifecycleCoordinator).thenReturn(lifecycle);
      when(lifecycle.reconcileLifecycleState).thenAnswer((_) async {});
      when(() => svc.keyVerificationRunner).thenReturn(null);
      when(() => svc.incomingKeyVerificationRunner).thenReturn(null);

      when(() => deviceKeys.deviceId).thenReturn('DEV1');
      when(() => deviceKeys.deviceDisplayName).thenReturn('Pixel 7');
      when(() => deviceKeys.userId).thenReturn(userId);
    });

    test(
      'deletes on the homeserver, then refreshes the device-key cache and '
      'nudges the pipeline so the removal unblocks sync immediately',
      () async {
        await buildDeleteOps().deleteDevice(deviceKeys);

        final captured = verify(
          () => gateway.deleteDevice('DEV1', auth: captureAny(named: 'auth')),
        ).captured;
        final auth = captured.single as AuthenticationPassword;
        expect(auth.password, 'secret');
        expect(
          (auth.identifier as AuthenticationUserIdentifier?)?.user,
          userId,
        );

        verify(
          () => client.updateUserDeviceKeys(additionalUsers: {userId}),
        ).called(1);
        verify(lifecycle.reconcileLifecycleState).called(1);
        verify(() => coordinator.triggerBridge()).called(1);
      },
    );

    test(
      'cancels an in-flight verification against the device before deleting, '
      'and leaves runners for other devices alone',
      () async {
        final matchingVerification = MockKeyVerification();
        when(() => matchingVerification.deviceId).thenReturn('DEV1');
        final matchingRunner = MockKeyVerificationRunner();
        when(
          () => matchingRunner.keyVerification,
        ).thenReturn(matchingVerification);
        when(matchingRunner.cancelVerification).thenAnswer((_) async {});

        final otherVerification = MockKeyVerification();
        when(() => otherVerification.deviceId).thenReturn('OTHER');
        final otherRunner = MockKeyVerificationRunner();
        when(() => otherRunner.keyVerification).thenReturn(otherVerification);

        when(() => svc.keyVerificationRunner).thenReturn(matchingRunner);
        when(() => svc.incomingKeyVerificationRunner).thenReturn(otherRunner);

        await buildDeleteOps().deleteDevice(deviceKeys);

        verifyInOrder([
          matchingRunner.cancelVerification,
          () => gateway.deleteDevice('DEV1', auth: any(named: 'auth')),
        ]);
        verifyNever(otherRunner.cancelVerification);
      },
    );

    test(
      'a failing runner cancellation is logged and does not abort the '
      'deletion',
      () async {
        final verification = MockKeyVerification();
        when(() => verification.deviceId).thenReturn('DEV1');
        final runner = MockKeyVerificationRunner();
        when(() => runner.keyVerification).thenReturn(verification);
        when(runner.cancelVerification).thenThrow(Exception('gone'));
        when(() => svc.keyVerificationRunner).thenReturn(runner);

        await buildDeleteOps().deleteDevice(deviceKeys);

        verify(
          () => logging.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'deleteDevice.cancelVerification',
          ),
        ).called(1);
        verify(
          () => gateway.deleteDevice('DEV1', auth: any(named: 'auth')),
        ).called(1);
      },
    );

    test(
      'a failing cache refresh is logged but does not fail the deletion, '
      'and the pipeline nudge still runs',
      () async {
        when(
          () => client.updateUserDeviceKeys(
            additionalUsers: any(named: 'additionalUsers'),
          ),
        ).thenThrow(Exception('offline'));

        await buildDeleteOps().deleteDevice(deviceKeys);

        verify(
          () => logging.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'deleteDevice.updateUserDeviceKeys',
          ),
        ).called(1);
        verify(lifecycle.reconcileLifecycleState).called(1);
        verify(() => coordinator.triggerBridge()).called(1);
      },
    );

    test('throws ArgumentError and stays offline when deviceId is null', () {
      when(() => deviceKeys.deviceId).thenReturn(null);

      expect(
        () => buildDeleteOps().deleteDevice(deviceKeys),
        throwsArgumentError,
      );
      verifyNever(() => gateway.deleteDevice(any(), auth: any(named: 'auth')));
    });

    test('throws StateError when no Matrix configuration is stored', () {
      when(() => sessionManager.matrixConfig).thenReturn(null);

      expect(
        () => buildDeleteOps().deleteDevice(deviceKeys),
        throwsStateError,
      );
      verifyNever(() => gateway.deleteDevice(any(), auth: any(named: 'auth')));
    });

    test('throws StateError when the device belongs to another user', () {
      when(() => deviceKeys.userId).thenReturn('@intruder:server');

      expect(
        () => buildDeleteOps().deleteDevice(deviceKeys),
        throwsStateError,
      );
      verifyNever(() => gateway.deleteDevice(any(), auth: any(named: 'auth')));
    });

    test('throws UnsupportedError when the stored password is empty', () {
      when(() => sessionManager.matrixConfig).thenReturn(
        const MatrixConfig(
          homeServer: 'https://server',
          user: userId,
          password: '',
        ),
      );

      expect(
        () => buildDeleteOps().deleteDevice(deviceKeys),
        throwsUnsupportedError,
      );
      verifyNever(() => gateway.deleteDevice(any(), auth: any(named: 'auth')));
    });

    test('refuses to delete the session the app itself runs as', () {
      expect(
        () => buildDeleteOps().deleteDeviceById('THIS_DEVICE'),
        throwsArgumentError,
      );
      verifyNever(() => gateway.deleteDevice(any(), auth: any(named: 'auth')));
    });

    test(
      'deleteDeviceById works for keyless sessions straight from the '
      'server inventory',
      () async {
        await buildDeleteOps().deleteDeviceById('KEYLESS');

        verify(
          () => gateway.deleteDevice('KEYLESS', auth: any(named: 'auth')),
        ).called(1);
        verify(
          () => client.updateUserDeviceKeys(additionalUsers: {userId}),
        ).called(1);
      },
    );

    test(
      'a hanging device-key refresh cannot delay the deletion beyond the '
      'recovery timeout',
      () {
        fakeAsync((async) {
          when(
            () => client.updateUserDeviceKeys(
              additionalUsers: any(named: 'additionalUsers'),
            ),
          ).thenAnswer((_) => Completer<void>().future);

          var completed = false;
          unawaited(
            buildDeleteOps()
                .deleteDeviceById('DEV1')
                .then(
                  (_) => completed = true,
                ),
          );

          async
            ..elapse(
              SyncTuning.deleteDeviceRecoveryTimeout +
                  const Duration(milliseconds: 1),
            )
            ..flushMicrotasks();

          expect(completed, isTrue);
          verify(
            () => logging.log(
              LogDomain.sync,
              any(),
              subDomain: 'deleteDevice.refreshTimeout',
            ),
          ).called(1);
        });
      },
    );
  });

  group('getSyncDevices', () {
    const userId = '@user:server';
    late MockMatrixClient client;

    setUp(() {
      client = MockMatrixClient();
      when(() => sessionManager.client).thenReturn(client);
      when(() => client.userID).thenReturn(userId);
      when(() => client.userDeviceKeysLoading).thenReturn(null);
      when(() => gateway.currentDeviceId).thenReturn('THIS_DEVICE');
    });

    DeviceKeys keysFor(String deviceId, {required bool verified}) {
      final keys = MockDeviceKeys();
      when(() => keys.deviceId).thenReturn(deviceId);
      when(() => keys.deviceDisplayName).thenReturn(null);
      when(() => keys.verified).thenReturn(verified);
      return keys;
    }

    void stubKeys(Map<String, DeviceKeys> byId) {
      final list = MockDeviceKeysList();
      when(() => list.deviceKeys).thenReturn(byId);
      when(() => client.userDeviceKeys).thenReturn({userId: list});
    }

    test(
      'merges the server inventory with the key cache and orders devices '
      'blockers-first, then the current device, then by recency',
      () async {
        when(() => gateway.getDevices()).thenAnswer(
          (_) async => [
            Device(
              deviceId: 'OLD_VERIFIED',
              displayName: 'Old laptop',
              lastSeenTs: DateTime(2026, 7, 20).millisecondsSinceEpoch,
            ),
            Device(deviceId: 'KEYLESS', displayName: 'Dead install'),
            Device(
              deviceId: 'GHOST',
              displayName: 'Uninstalled phone',
              lastSeenTs: DateTime(2026, 5).millisecondsSinceEpoch,
            ),
            Device(
              deviceId: 'THIS_DEVICE',
              displayName: 'This desktop',
              lastSeenTs: DateTime(2026, 7, 26).millisecondsSinceEpoch,
            ),
          ],
        );
        stubKeys({
          'GHOST': keysFor('GHOST', verified: false),
          'OLD_VERIFIED': keysFor('OLD_VERIFIED', verified: true),
        });

        final devices = await buildOps().getSyncDevices();

        expect(
          devices.map((d) => d.deviceId).toList(),
          ['GHOST', 'THIS_DEVICE', 'OLD_VERIFIED', 'KEYLESS'],
        );

        final current = devices[1];
        expect(current.isCurrentDevice, isTrue);
        expect(current.verified, isTrue);
        expect(current.blocksSync, isFalse);

        final ghost = devices[0];
        expect(ghost.verified, isFalse);
        expect(ghost.blocksSync, isTrue);
        expect(ghost.lastSeen, DateTime(2026, 5));
        expect(ghost.keys, isNotNull);

        final oldVerified = devices[2];
        expect(oldVerified.verified, isTrue);
        expect(oldVerified.blocksSync, isFalse);

        final keyless = devices[3];
        expect(keyless.verified, isFalse);
        expect(keyless.keys, isNull);
        expect(
          keyless.blocksSync,
          isFalse,
          reason: 'keyless sessions never gate the send path',
        );
        expect(keyless.lastSeen, isNull);
      },
    );

    test(
      'marks the current device verified even without cached keys',
      () async {
        when(() => gateway.getDevices()).thenAnswer(
          (_) async => [Device(deviceId: 'THIS_DEVICE')],
        );
        when(() => client.userDeviceKeys).thenReturn({});

        final devices = await buildOps().getSyncDevices();

        expect(devices.single.isCurrentDevice, isTrue);
        expect(devices.single.verified, isTrue);
      },
    );

    test(
      'waits for an in-flight device-key load before classifying sessions',
      () async {
        final keysLoaded = Completer<void>();
        when(
          () => client.userDeviceKeysLoading,
        ).thenAnswer((_) => keysLoaded.future);
        when(() => gateway.getDevices()).thenAnswer(
          (_) async => [Device(deviceId: 'THIS_DEVICE')],
        );
        when(() => client.userDeviceKeys).thenReturn({});

        var completed = false;
        final pending = buildOps().getSyncDevices().then((devices) {
          completed = true;
          return devices;
        });
        await Future<void>.delayed(Duration.zero);
        expect(
          completed,
          isFalse,
          reason: 'the roster must not snapshot a half-loaded key cache',
        );

        keysLoaded.complete();
        final devices = await pending;
        expect(devices.single.deviceId, 'THIS_DEVICE');
      },
    );

    test(
      'retains an unverified cache-only device as a blocker and drops '
      'verified cache-only leftovers',
      () async {
        when(() => gateway.getDevices()).thenAnswer(
          (_) async => [Device(deviceId: 'THIS_DEVICE')],
        );
        stubKeys({
          // Still gates the sender even though the server no longer lists it.
          'CACHE_ONLY': keysFor('CACHE_ONLY', verified: false),
          // Already deleted elsewhere and trusted — pruned, not shown.
          'DELETED_ELSEWHERE': keysFor('DELETED_ELSEWHERE', verified: true),
        });

        final devices = await buildOps().getSyncDevices();

        expect(
          devices.map((d) => d.deviceId).toList(),
          ['CACHE_ONLY', 'THIS_DEVICE'],
        );
        final ghost = devices.first;
        expect(ghost.blocksSync, isTrue);
        expect(ghost.lastSeen, isNull);
        expect(ghost.keys, isNotNull);
        expect(ghost.onServer, isFalse);
      },
    );
  });

  group('diagnostics', () {
    test('getDiagnosticInfo returns and logs the engine diagnostics', () async {
      when(
        () => syncEngine.diagnostics(log: any(named: 'log')),
      ).thenAnswer((_) async => {'a': 1});

      final result = await buildOps().getDiagnosticInfo();
      expect(result, {'a': 1});
      verify(() => syncEngine.diagnostics(log: false)).called(1);
    });

    test(
      'getSyncDiagnosticsText joins metrics and diagnostic strings',
      () async {
        when(pipeline.metricsSnapshot).thenReturn({'sent': 3});
        when(pipeline.diagnosticsStrings).thenReturn({'state': 'idle'});

        expect(
          await buildOps().getSyncDiagnosticsText(),
          'sent=3\nstate=idle',
        );
      },
    );

    test('getSyncDiagnosticsText reports disabled when no pipeline', () async {
      currentPipeline = null;
      expect(await buildOps().getSyncDiagnosticsText(), 'pipeline disabled');
    });
  });

  group('getSyncMetrics', () {
    test(
      'overlays queue ledger counts when the coordinator is running',
      () async {
        when(pipeline.metricsSnapshot).thenReturn({'sent': 2});
        when(() => coordinator.isRunning).thenReturn(true);
        when(queue.stats).thenAnswer(
          (_) async => _stats(
            total: 5,
            applied: 4,
            abandoned: 1,
            retrying: 2,
          ),
        );

        final metrics = await buildOps().getSyncMetrics();
        expect(metrics, isNotNull);
        expect(metrics!.queueActive, 5);
        expect(metrics.queueApplied, 4);
        expect(metrics.queueAbandoned, 1);
        expect(metrics.queueRetrying, 2);
      },
    );

    test(
      'skips the overlay and still returns when queue.stats throws',
      () async {
        when(pipeline.metricsSnapshot).thenReturn({'sent': 2});
        when(() => coordinator.isRunning).thenReturn(true);
        when(queue.stats).thenThrow(Exception('db'));

        final metrics = await buildOps().getSyncMetrics();
        expect(metrics, isNotNull);
        verify(
          () => logging.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'metrics.queueStats',
          ),
        ).called(1);
      },
    );

    test('returns null when metrics collection is disabled', () async {
      final ops = MatrixServiceOps(
        gateway: gateway,
        loggingService: logging,
        collectSyncMetrics: false,
        queueCoordinator: coordinator,
        roomManager: roomManager,
        sessionManager: sessionManager,
        syncEngine: syncEngine,
        incomingKeyVerificationController: incomingController,
        pipeline: () => currentPipeline,
        keyVerificationRequestSubscription: () => keyVerSub,
        setKeyVerificationRequestSubscription: (value) => keyVerSub = value,
        service: () => throw UnimplementedError(),
      );

      expect(await ops.getSyncMetrics(), isNull);
    });

    test('returns null when there is no pipeline', () async {
      currentPipeline = null;
      expect(await buildOps().getSyncMetrics(), isNull);
    });
  });

  group('forceRescan / retryNow', () {
    test('forceRescan(includeCatchUp: true) nudges the bridge', () async {
      await buildOps().forceRescan();
      verify(() => coordinator.triggerBridge()).called(1);
    });

    test('forceRescan(includeCatchUp: false) is a no-op', () async {
      await buildOps().forceRescan(includeCatchUp: false);
      verifyNever(() => coordinator.triggerBridge());
    });

    test('retryNow resurrects abandoned rows then nudges the bridge', () async {
      when(() => queue.resurrectAll()).thenAnswer((_) async => 3);

      await buildOps().retryNow();
      verify(() => queue.resurrectAll()).called(1);
      verify(() => coordinator.triggerBridge()).called(1);
    });

    test(
      'retryNow swallows and logs a resurrectAll failure but still nudges',
      () async {
        when(() => queue.resurrectAll()).thenThrow(Exception('boom'));

        await buildOps().retryNow();
        verify(
          () => logging.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'retryNow.resurrectAll',
          ),
        ).called(1);
        verify(() => coordinator.triggerBridge()).called(1);
      },
    );
  });

  group('key verification stream / pipeline accessors', () {
    test(
      'getIncomingKeyVerificationStream forwards controller events',
      () async {
        final ops = buildOps();
        final received = <KeyVerification>[];
        final sub = ops.getIncomingKeyVerificationStream().listen(received.add);
        addTearDown(sub.cancel);

        final verification = MockKeyVerification();
        incomingController.add(verification);
        await Future<void>.delayed(Duration.zero);

        expect(received, [same(verification)]);
      },
    );

    test('debugPipeline reflects the current pipeline accessor', () {
      final ops = buildOps();
      expect(ops.debugPipeline, same(pipeline));
      currentPipeline = null;
      expect(ops.debugPipeline, isNull);
    });
  });
}
