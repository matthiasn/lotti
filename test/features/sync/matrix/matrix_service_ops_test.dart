import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/matrix_service_ops.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_consumer.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/queue/inbound_queue_models.dart';
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

  MatrixServiceOps buildOps() => MatrixServiceOps(
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
    // which are covered by the parent MatrixService tests.
    service: () => throw UnimplementedError('service() not used in this test'),
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
