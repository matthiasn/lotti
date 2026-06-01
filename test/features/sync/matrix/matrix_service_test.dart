import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_consumer.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/stats.dart';
import 'package:lotti/features/sync/matrix/sync_engine.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_lifecycle_coordinator.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/model/sync_node_profile.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _MockGateway extends Mock implements MatrixSyncGateway {}

class _MockMessageSender extends Mock implements MatrixMessageSender {}

class _MockSettingsDb extends Mock implements SettingsDb {}

class _MockEventProcessor extends Mock implements SyncEventProcessor {}

class _MockSecureStorage extends Mock implements SecureStorage {}

class _MockActivityGate extends Mock implements UserActivityGate {}

class _MockClient extends Mock implements Client {}

class _MockSentEventRegistry extends Mock implements SentEventRegistry {}

class _MockSessionManager extends Mock implements MatrixSessionManager {}

class _MockRoomManager extends Mock implements SyncRoomManager {}

class _MockPipeline extends Mock implements MatrixStreamConsumer {}

class _MockSyncEngine extends Mock implements SyncEngine {}

class _MockCoordinator extends Mock implements SyncLifecycleCoordinator {}

class _MockQueueCoordinator extends Mock implements QueuePipelineCoordinator {}

class _FakeMatrixMessageContext extends Fake implements MatrixMessageContext {}

class _MockDeviceKeys extends Mock implements DeviceKeys {}

class _MockKeyVerification extends Mock implements KeyVerification {}

void main() {
  late _MockGateway gateway;
  late DomainLogger loggingService;
  late _MockActivityGate activityGate;
  late _MockMessageSender messageSender;
  late _MockSettingsDb settingsDb;
  late _MockEventProcessor eventProcessor;
  late _MockSecureStorage secureStorage;
  late _MockClient client;
  late _MockSentEventRegistry sentEventRegistry;
  late _MockSessionManager sessionManager;
  late _MockRoomManager roomManager;
  late _MockPipeline pipeline;
  late _MockSyncEngine syncEngine;
  late _MockCoordinator coordinator;
  late _MockQueueCoordinator queueCoordinator;

  _MockQueueCoordinator buildQueueCoordinator() {
    final c = _MockQueueCoordinator();
    when(c.start).thenAnswer((_) async {});
    when(() => c.isRunning).thenReturn(false);
    when(
      () => c.stop(drainFirst: any(named: 'drainFirst')),
    ).thenAnswer((_) async {});
    return c;
  }

  setUpAll(() {
    registerFallbackValue(
      SyncApplyDiagnostics(
        eventId: 'fallback',
        payloadType: 'fallback',
        vectorClock: null,
        conflictStatus: 'fallback',
        applied: false,
      ),
    );
    registerFallbackValue(
      const SyncMessage.agentBundle(agentId: 'fb', wakeRunKey: 'fb'),
    );
    registerFallbackValue(_FakeMatrixMessageContext());
  });

  setUp(() {
    gateway = _MockGateway();
    loggingService = MockDomainLogger();
    activityGate = _MockActivityGate();
    messageSender = _MockMessageSender();
    settingsDb = _MockSettingsDb();
    eventProcessor = _MockEventProcessor();
    secureStorage = _MockSecureStorage();
    client = _MockClient();
    sentEventRegistry = _MockSentEventRegistry();
    sessionManager = _MockSessionManager();
    roomManager = _MockRoomManager();
    pipeline = _MockPipeline();
    syncEngine = _MockSyncEngine();
    coordinator = _MockCoordinator();
    queueCoordinator = buildQueueCoordinator();

    when(() => sessionManager.client).thenReturn(client);
    when(() => sessionManager.matrixConfig).thenReturn(null);
    when(() => messageSender.sentEventRegistry).thenReturn(sentEventRegistry);
    when(() => roomManager.currentRoomId).thenReturn(null);
    when(() => roomManager.currentRoom).thenReturn(null);
    when(
      () => roomManager.inviteRequests,
    ).thenAnswer((_) => const Stream.empty());
    when(() => syncEngine.lifecycleCoordinator).thenReturn(coordinator);
    when(() => gateway.unverifiedDevices()).thenReturn([]);
  });

  /// Creates a service with a provided syncEngine (no pipeline).
  MatrixService createService() {
    return MatrixService(
      gateway: gateway,
      loggingService: loggingService,
      activityGate: activityGate,
      messageSender: messageSender,
      settingsDb: settingsDb,
      eventProcessor: eventProcessor,
      secureStorage: secureStorage,
      queueCoordinator: queueCoordinator,
      sessionManager: sessionManager,
      roomManager: roomManager,
      syncEngine: syncEngine,
      connectivityStream: const Stream.empty(),
    );
  }

  /// Creates a service with a pipeline override (no syncEngine).
  MatrixService createServiceWithPipeline({bool collectSyncMetrics = false}) {
    when(
      () => pipeline.reportDbApplyDiagnostics(any()),
    ).thenReturn(null);
    return MatrixService(
      gateway: gateway,
      loggingService: loggingService,
      activityGate: activityGate,
      messageSender: messageSender,
      settingsDb: settingsDb,
      eventProcessor: eventProcessor,
      secureStorage: secureStorage,
      queueCoordinator: queueCoordinator,
      sessionManager: sessionManager,
      roomManager: roomManager,
      pipelineOverride: pipeline,
      collectSyncMetrics: collectSyncMetrics,
      connectivityStream: const Stream.empty(),
    );
  }

  group('MatrixService', () {
    test('can be constructed', () {
      final service = createService();

      expect(service, isNotNull);
    });

    test('client getter returns session manager client', () {
      final service = createService();

      expect(service.client, client);
    });

    test('syncRoomId returns room manager currentRoomId', () {
      when(() => roomManager.currentRoomId).thenReturn('!room:s');

      final service = createService();

      expect(service.syncRoomId, '!room:s');
    });

    test('isLoggedIn delegates to session manager', () {
      when(() => sessionManager.isLoggedIn()).thenReturn(true);

      // Need to use the sessionManager from the existing service for this test
      // but MatrixService creates its own sessionManager if not provided
      final service = createService();

      // Cannot easily test isLoggedIn because it goes through _sessionManager
      // which is the one we injected
      expect(service.isLoggedIn(), isTrue);
    });

    test('getUnverifiedDevices delegates to gateway', () {
      final service = createService();

      final devices = service.getUnverifiedDevices();

      expect(devices, isEmpty);
      verify(() => gateway.unverifiedDevices()).called(1);
    });

    test('incrementSentCountOf updates messageCounts', () {
      final service = createService()
        ..incrementSentCountOf('journalEntity')
        ..incrementSentCountOf('journalEntity')
        ..incrementSentCountOf('entryLink');

      expect(service.sentCount, 3);
      expect(service.messageCounts['journalEntity'], 2);
      expect(service.messageCounts['entryLink'], 1);
    });

    test(
      'sendMatrixMsg increments agentBundle bucket on successful send',
      () async {
        when(() => roomManager.currentRoom).thenReturn(null);
        when(() => roomManager.currentRoomId).thenReturn(null);
        when(() => client.getRoomById(any())).thenReturn(null);
        when(
          () => messageSender.sendMatrixMessage(
            message: any(named: 'message'),
            context: any(named: 'context'),
            onSent: any(named: 'onSent'),
          ),
        ).thenAnswer((invocation) async {
          // Invoke the onSent callback so the matrix-type bucket is
          // incremented for `agentBundle`.
          final onSent =
              invocation.namedArguments[#onSent]
                  as void Function(String, SyncMessage);
          onSent(
            r'$evt-bundle',
            invocation.namedArguments[#message] as SyncMessage,
          );
          return true;
        });

        final service = createService();
        const bundle = SyncMessage.agentBundle(
          agentId: 'agent-1',
          wakeRunKey: 'run-1',
        );
        final result = await service.sendMatrixMsg(
          bundle,
          myRoomId: '!room:s',
        );

        expect(result, isTrue);
        expect(service.messageCounts['agentBundle'], 1);
      },
    );

    test('messageCountsController emits stats', () async {
      final service = createService();

      final future = service.messageCountsController.stream.first;

      service.incrementSentCountOf('test');

      final stats = await future;

      expect(stats, isA<MatrixStats>());
      expect(stats.sentCount, 1);
      expect(stats.messageCounts['test'], 1);
    });

    test('forceRescan delegates to queue coordinator bridge', () async {
      when(queueCoordinator.triggerBridge).thenAnswer((_) async {});

      final service = createServiceWithPipeline();

      await service.forceRescan();

      verify(queueCoordinator.triggerBridge).called(1);
    });

    test('retryNow delegates to queue coordinator bridge', () async {
      when(queueCoordinator.triggerBridge).thenAnswer((_) async {});

      final service = createServiceWithPipeline();

      await service.retryNow();

      verify(queueCoordinator.triggerBridge).called(1);
    });

    test('getSyncMetrics returns null when metrics disabled', () async {
      final service = createService();

      final metrics = await service.getSyncMetrics();

      expect(metrics, isNull);
    });

    test('dispose closes all controllers', () async {
      when(() => syncEngine.dispose()).thenAnswer((_) async {});
      when(() => sessionManager.dispose()).thenAnswer((_) async {});
      when(() => roomManager.dispose()).thenAnswer((_) async {});

      final service = createService();

      await service.dispose();

      verify(() => syncEngine.dispose()).called(1);
      verify(() => sessionManager.dispose()).called(1);
      verify(() => roomManager.dispose()).called(1);
    });

    test('joinRoom delegates to room manager', () async {
      when(
        () => roomManager.joinRoom(any()),
      ).thenAnswer((_) async => null);

      final service = createService();
      final result = await service.joinRoom('!room:server');

      expect(result, '!room:server');
      verify(() => roomManager.joinRoom('!room:server')).called(1);
    });

    test('createRoom delegates to room manager', () async {
      when(
        () =>
            roomManager.createRoom(inviteUserIds: any(named: 'inviteUserIds')),
      ).thenAnswer((_) async => '!new:room');

      final service = createService();
      final result = await service.createRoom();

      expect(result, '!new:room');
    });

    test('getRoom delegates to room manager', () async {
      when(
        () => roomManager.loadPersistedRoomId(),
      ).thenAnswer((_) async => '!stored:room');

      final service = createService();
      final result = await service.getRoom();

      expect(result, '!stored:room');
    });

    test('leaveRoom delegates to room manager', () async {
      when(
        () => roomManager.leaveCurrentRoom(),
      ).thenAnswer((_) async {});

      final service = createService();
      await service.leaveRoom();

      verify(() => roomManager.leaveCurrentRoom()).called(1);
    });

    test('clearPersistedRoom delegates to room manager', () async {
      when(
        () => roomManager.clearPersistedRoom(),
      ).thenAnswer((_) async {});

      final service = createService();
      await service.clearPersistedRoom();

      verify(() => roomManager.clearPersistedRoom()).called(1);
    });

    test('inviteToSyncRoom delegates to room manager', () async {
      when(
        () => roomManager.inviteUser(any()),
      ).thenAnswer((_) async {});

      final service = createService();
      await service.inviteToSyncRoom(userId: '@bob:server');

      verify(() => roomManager.inviteUser('@bob:server')).called(1);
    });

    test('logout delegates to sync engine', () async {
      when(() => syncEngine.logout()).thenAnswer((_) async {});

      final service = createService();
      await service.logout();

      verify(() => syncEngine.logout()).called(1);
    });

    test('debugPipeline returns pipeline override', () {
      final service = createServiceWithPipeline();

      expect(service.debugPipeline, pipeline);
    });
  });

  group('MatrixService error and log branches', () {
    // Covers lib/features/sync/matrix/matrix_service.dart lines 318-323:
    // _startQueuePipeline() catch branch logs and rethrows.
    test(
      'debugStartQueuePipelineForTest logs and rethrows on coordinator '
      'start failure',
      () async {
        final failure = Exception('queue start boom');
        when(queueCoordinator.start).thenThrow(failure);

        final service = createService();

        await expectLater(
          service.debugStartQueuePipelineForTest(),
          throwsA(failure),
        );
        verify(
          () => loggingService.error(
            LogDomain.sync,
            failure,
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'queue.init',
          ),
        ).called(1);
      },
    );

    // Covers lines 301-306: init() logs the initialized banner after wiring
    // the sync engine, config load, connect, and queue pipeline start.
    test('init logs initialized banner with device and user ids', () async {
      when(
        () => syncEngine.initialize(
          onLogin: any(named: 'onLogin'),
          onLogout: any(named: 'onLogout'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => syncEngine.connect(
          shouldAttemptLogin: any(named: 'shouldAttemptLogin'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => secureStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => null);
      when(() => client.deviceID).thenReturn('DEVICE1');
      when(() => client.deviceName).thenReturn('Lotti');
      when(() => client.userID).thenReturn('@me:server');

      final service = createService();
      await service.init();

      verify(
        () => loggingService.log(
          LogDomain.sync,
          any(
            that: allOf(
              contains('DEVICE1'),
              contains('@me:server'),
            ),
          ),
          subDomain: 'init',
        ),
      ).called(1);
    });

    // Covers lines 344-350: _onLifecycleLogout() logs when the sync engine
    // invokes the captured onLogout hook.
    test('lifecycle logout hook logs paused message', () async {
      when(
        () => syncEngine.initialize(
          onLogin: any(named: 'onLogin'),
          onLogout: any(named: 'onLogout'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => syncEngine.connect(
          shouldAttemptLogin: any(named: 'shouldAttemptLogin'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => secureStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => null);
      when(() => client.deviceID).thenReturn('DEVICE1');
      when(() => client.deviceName).thenReturn('Lotti');
      when(() => client.userID).thenReturn('@me:server');

      final service = createService();
      await service.init();

      // Capture the onLogout hook handed to the engine and invoke it.
      final captured = verify(
        () => syncEngine.initialize(
          onLogin: any(named: 'onLogin'),
          onLogout: captureAny(named: 'onLogout'),
        ),
      ).captured;
      final onLogout = captured.last as Future<void> Function();
      await onLogout();

      verify(
        () => loggingService.log(
          LogDomain.sync,
          any(that: contains('paused')),
          subDomain: 'logoutLifecycle',
        ),
      ).called(1);
    });

    // Covers lines 335-341: listen() logs sync state.
    test('listen logs sync state after loading persisted room', () async {
      when(
        () => roomManager.loadPersistedRoomId(),
      ).thenAnswer((_) async => '!saved:server');
      when(() => roomManager.currentRoomId).thenReturn('!current:server');
      when(() => client.rooms).thenReturn(const []);

      final service = createService();
      await service.listen();

      verify(
        () => loggingService.log(
          LogDomain.sync,
          any(
            that: allOf(
              contains('!saved:server'),
              contains('!current:server'),
            ),
          ),
          subDomain: 'listen',
        ),
      ).called(1);
    });

    // Covers lines 443-448: saveRoom() bootstrap catch branch logs when the
    // queue coordinator's room-change / bridge work throws.
    test('saveRoom logs bootstrap failure when onRoomChanged throws', () async {
      final failure = Exception('onRoomChanged boom');
      when(() => roomManager.saveRoomId(any())).thenAnswer((_) async {});
      when(
        () => queueCoordinator.onRoomChanged(any()),
      ).thenThrow(failure);

      final service = createService();
      await service.saveRoom('!room:server');
      // The bootstrap work runs in an unawaited future; let microtasks drain.
      await pumpEventQueue();

      verify(
        () => loggingService.error(
          LogDomain.sync,
          failure,
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'saveRoom.bootstrap',
        ),
      ).called(1);
    });

    // Covers lines 486-490: acceptInvite() logs the request and delegates.
    test('acceptInvite logs request and delegates to room manager', () async {
      final invite = SyncRoomInvite(
        roomId: '!invited:server',
        senderId: '@alice:server',
        matchesExistingRoom: false,
      );
      when(() => roomManager.acceptInvite(invite)).thenAnswer((_) async {});

      final service = createService();
      await service.acceptInvite(invite);

      verify(
        () => loggingService.log(
          LogDomain.sync,
          any(
            that: allOf(
              contains('!invited:server'),
              contains('@alice:server'),
            ),
          ),
          subDomain: 'room.acceptInvite',
        ),
      ).called(1);
      verify(() => roomManager.acceptInvite(invite)).called(1);
    });

    // Covers lines 508-512: onVerificationCompleted() logs the source. Also
    // returns early at the !isLoggedIn() guard so neither catch is reached.
    test(
      'onVerificationCompleted logs source and returns when logged out',
      () async {
        when(() => sessionManager.isLoggedIn()).thenReturn(false);

        final service = createService();
        await service.onVerificationCompleted(source: 'manual');

        verify(
          () => loggingService.log(
            LogDomain.sync,
            any(that: contains('manual')),
            subDomain: 'verification',
          ),
        ).called(1);
        // Logged-out short-circuit: no device-key update is attempted.
        verifyNever(
          () => client.updateUserDeviceKeys(
            additionalUsers: any(named: 'additionalUsers'),
          ),
        );
      },
    );

    // Covers lines 523-529: onVerificationCompleted() catch branch when
    // updateUserDeviceKeys throws.
    test(
      'onVerificationCompleted logs error when updateUserDeviceKeys throws',
      () async {
        final failure = Exception('device key update boom');
        when(() => sessionManager.isLoggedIn()).thenReturn(true);
        when(() => client.userID).thenReturn('@me:server');
        when(
          () => client.updateUserDeviceKeys(
            additionalUsers: any(named: 'additionalUsers'),
          ),
        ).thenThrow(failure);
        when(
          () => coordinator.reconcileLifecycleState(),
        ).thenAnswer((_) async {});
        when(queueCoordinator.triggerBridge).thenAnswer((_) async {});

        final service = createService();
        await service.onVerificationCompleted(source: 'auto');

        verify(
          () => loggingService.error(
            LogDomain.sync,
            failure,
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'verification.updateUserDeviceKeys',
          ),
        ).called(1);
      },
    );

    // Covers lines 535-541: onVerificationCompleted() catch branch when
    // reconcileLifecycleState / forceRescan throws.
    test(
      'onVerificationCompleted logs error when reconcileLifecycleState throws',
      () async {
        final failure = Exception('reconcile boom');
        when(() => sessionManager.isLoggedIn()).thenReturn(true);
        when(() => client.userID).thenReturn('@me:server');
        when(
          () => client.updateUserDeviceKeys(
            additionalUsers: any(named: 'additionalUsers'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => coordinator.reconcileLifecycleState(),
        ).thenThrow(failure);

        final service = createService();
        await service.onVerificationCompleted(source: 'auto');

        verify(
          () => loggingService.error(
            LogDomain.sync,
            failure,
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'verification.forceRescan',
          ),
        ).called(1);
      },
    );

    // Covers lines 622-627: dispose() catch branch when the queue coordinator
    // stop throws during drain.
    test('dispose logs error when queue coordinator stop throws', () async {
      final failure = Exception('queue stop boom');
      when(() => syncEngine.dispose()).thenAnswer((_) async {});
      when(() => sessionManager.dispose()).thenAnswer((_) async {});
      when(() => roomManager.dispose()).thenAnswer((_) async {});
      when(() => queueCoordinator.isRunning).thenReturn(true);
      when(
        () => queueCoordinator.stop(drainFirst: any(named: 'drainFirst')),
      ).thenThrow(failure);

      final service = createService();
      await service.dispose();

      verify(
        () => loggingService.error(
          LogDomain.sync,
          failure,
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'queue.dispose',
        ),
      ).called(1);
    });

    // Covers lines 639-646: getDiagnosticInfo() logs encoded diagnostics.
    test('getDiagnosticInfo logs and returns engine diagnostics', () async {
      when(
        () => syncEngine.diagnostics(log: any(named: 'log')),
      ).thenAnswer((_) async => {'foo': 'bar'});

      final service = createService();
      final result = await service.getDiagnosticInfo();

      expect(result, {'foo': 'bar'});
      verify(
        () => loggingService.log(
          LogDomain.sync,
          any(that: contains('foo')),
          subDomain: 'diagnostics',
        ),
      ).called(1);
    });

    // Covers lines 665-671: getSyncMetrics() inner catch when queue.stats
    // throws while overlaying ledger counts.
    test('getSyncMetrics logs error when queue stats throws', () async {
      final failure = Exception('queue stats boom');
      final queue = MockInboundQueue();
      when(queue.stats).thenThrow(failure);
      when(() => queueCoordinator.isRunning).thenReturn(true);
      when(() => queueCoordinator.queue).thenReturn(queue);
      when(() => pipeline.metricsSnapshot()).thenReturn({'consumed': 1});

      final service = createServiceWithPipeline(collectSyncMetrics: true);
      final metrics = await service.getSyncMetrics();

      // The outer try still returns a SyncMetrics from the snapshot map.
      expect(metrics, isNotNull);
      verify(
        () => loggingService.error(
          LogDomain.sync,
          failure,
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'metrics.queueStats',
        ),
      ).called(1);
    });

    // Covers lines 675-682: getSyncMetrics() outer catch when metricsSnapshot
    // throws; returns null.
    test(
      'getSyncMetrics logs error and returns null when snapshot throws',
      () async {
        final failure = Exception('snapshot boom');
        when(() => queueCoordinator.isRunning).thenReturn(false);
        when(() => pipeline.metricsSnapshot()).thenThrow(failure);

        final service = createServiceWithPipeline(collectSyncMetrics: true);
        final metrics = await service.getSyncMetrics();

        expect(metrics, isNull);
        verify(
          () => loggingService.error(
            LogDomain.sync,
            failure,
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'metrics',
          ),
        ).called(1);
      },
    );

    // Covers lines 692-698: forceRescan(includeCatchUp: false) logs the
    // suppressed message and returns without nudging the bridge.
    test('forceRescan with includeCatchUp false logs suppression', () async {
      final service = createServiceWithPipeline();
      await service.forceRescan(includeCatchUp: false);

      verify(
        () => loggingService.log(
          LogDomain.sync,
          any(that: contains('forceRescan.suppressed')),
          subDomain: 'forceRescan',
        ),
      ).called(1);
      verifyNever(queueCoordinator.triggerBridge);
    });

    // Covers lines 712-717: retryNow() success log after resurrectAll.
    test('retryNow logs resurrected count on success', () async {
      final queue = MockInboundQueue();
      when(queue.resurrectAll).thenAnswer((_) async => 3);
      when(() => queueCoordinator.queue).thenReturn(queue);
      when(queueCoordinator.triggerBridge).thenAnswer((_) async {});

      final service = createServiceWithPipeline();
      await service.retryNow();

      verify(
        () => loggingService.log(
          LogDomain.sync,
          any(that: contains('resurrected=3')),
          subDomain: 'retryNow',
        ),
      ).called(1);
    });

    // Covers lines 718-724: retryNow() catch branch when resurrectAll throws.
    test('retryNow logs error when resurrectAll throws', () async {
      final failure = Exception('resurrect boom');
      final queue = MockInboundQueue();
      when(queue.resurrectAll).thenThrow(failure);
      when(() => queueCoordinator.queue).thenReturn(queue);
      when(queueCoordinator.triggerBridge).thenAnswer((_) async {});

      final service = createServiceWithPipeline();
      await service.retryNow();

      verify(
        () => loggingService.error(
          LogDomain.sync,
          failure,
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'retryNow.resurrectAll',
        ),
      ).called(1);
    });

    // Covers lines 743-749: _nudgeBridge() catch branch when triggerBridge
    // throws (reached here via forceRescan -> _nudgeBridge).
    test('forceRescan logs error when triggerBridge throws', () async {
      final failure = Exception('bridge boom');
      when(queueCoordinator.triggerBridge).thenThrow(failure);

      final service = createServiceWithPipeline();
      await service.forceRescan();

      verify(
        () => loggingService.error(
          LogDomain.sync,
          failure,
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'forceRescan.triggerBridge',
        ),
      ).called(1);
    });

    // Covers lines 776-778: deleteConfig delegates to deleteMatrixConfig.
    test('deleteConfig delegates through session and secure storage', () async {
      when(
        () => secureStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});
      when(() => sessionManager.logout()).thenAnswer((_) async {});

      final service = createService();
      await service.deleteConfig();

      verify(() => secureStorage.delete(key: any(named: 'key'))).called(
        greaterThanOrEqualTo(1),
      );
      verify(() => sessionManager.logout()).called(1);
    });

    // Covers lines 801-807 (persist catch) and 814-820 (rollback catch) plus
    // the rethrow: changePassword() persist fails, rollback also fails.
    test(
      'changePassword logs persist and rollback errors then rethrows',
      () async {
        final persistFailure = Exception('persist boom');
        final rollbackFailure = Exception('rollback boom');
        const config = MatrixConfig(
          homeServer: 'https://hs',
          user: '@me:server',
          password: 'old-pass',
        );

        // First changePassword (the real change) succeeds; the rollback
        // changePassword (second call) throws.
        var changePasswordCalls = 0;
        when(
          () => gateway.changePassword(
            oldPassword: any(named: 'oldPassword'),
            newPassword: any(named: 'newPassword'),
          ),
        ).thenAnswer((_) async {
          changePasswordCalls++;
          if (changePasswordCalls >= 2) {
            throw rollbackFailure;
          }
        });
        // Persisting the new config fails, entering the persist catch.
        when(() => sessionManager.matrixConfig).thenReturn(config);
        when(
          () => secureStorage.read(key: any(named: 'key')),
        ).thenAnswer((_) async => null);
        when(
          () => secureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenThrow(persistFailure);

        final service = createService();

        await expectLater(
          service.changePassword(
            oldPassword: 'old-pass',
            newPassword: 'new-pass',
          ),
          throwsA(persistFailure),
        );

        verify(
          () => loggingService.error(
            LogDomain.sync,
            persistFailure,
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'changePassword.persist',
          ),
        ).called(1);
        verify(
          () => loggingService.error(
            LogDomain.sync,
            rollbackFailure,
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'changePassword.rollback',
          ),
        ).called(1);
      },
    );
  });

  group('MatrixService getters', () {
    // Covers line 202: queueCoordinator getter.
    test('queueCoordinator getter returns the coordinator', () {
      final service = createService();
      expect(service.queueCoordinator, same(queueCoordinator));
    });

    // Covers line 216: matrixConfig getter delegates to session manager.
    test('matrixConfig getter returns session manager matrixConfig', () {
      const config = MatrixConfig(
        homeServer: 'https://hs',
        user: '@me:server',
        password: 'pass',
      );
      when(() => sessionManager.matrixConfig).thenReturn(config);

      final service = createService();
      expect(service.matrixConfig, config);
    });

    // Covers line 220: inviteRequests getter delegates to room manager.
    test('inviteRequests getter returns room manager stream', () {
      final controller = StreamController<SyncRoomInvite>.broadcast();
      when(() => roomManager.inviteRequests).thenAnswer(
        (_) => controller.stream,
      );

      final service = createService();
      expect(service.inviteRequests, isA<Stream<SyncRoomInvite>>());
      controller.close();
    });

    // Covers lines 287-288: publishIncomingRunnerState is a no-op when
    // incomingKeyVerificationRunner is null (default).
    test(
      'publishIncomingRunnerState is a no-op when runner is null',
      () {
        final service = createService();
        // No runner set — should not throw.
        expect(service.publishIncomingRunnerState, returnsNormally);
        expect(service.incomingKeyVerificationRunner, isNull);
      },
    );
  });

  group('MatrixService constructor paths', () {
    // Covers lines 77-88: sessionManager provided but no roomManager,
    // so _roomManager is taken from sessionManager.roomManager.
    test(
      'constructor uses roomManager from sessionManager when no roomManager '
      'is injected',
      () {
        final innerRoomManager = _MockRoomManager();
        when(() => innerRoomManager.currentRoomId).thenReturn('!r:s');
        when(() => innerRoomManager.currentRoom).thenReturn(null);
        when(
          () => innerRoomManager.inviteRequests,
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => sessionManager.roomManager,
        ).thenReturn(innerRoomManager);

        final service = MatrixService(
          gateway: gateway,
          loggingService: loggingService,
          activityGate: activityGate,
          messageSender: messageSender,
          settingsDb: settingsDb,
          eventProcessor: eventProcessor,
          secureStorage: secureStorage,
          queueCoordinator: queueCoordinator,
          sessionManager: sessionManager,
          // roomManager intentionally omitted
          syncEngine: syncEngine,
          connectivityStream: const Stream.empty(),
        );

        // _roomManager was resolved from sessionManager.roomManager
        expect(service.syncRoomId, '!r:s');
      },
    );

    // Covers lines 100-106: ArgumentError when syncEngine and coordinator
    // do not reference the same coordinator instance.
    test(
      'constructor throws ArgumentError when syncEngine coordinator does not '
      'match provided lifecycleCoordinator',
      () {
        final differentCoordinator = _MockCoordinator();
        // syncEngine returns `coordinator`, but we pass `differentCoordinator`.
        when(() => syncEngine.lifecycleCoordinator).thenReturn(coordinator);

        expect(
          () => MatrixService(
            gateway: gateway,
            loggingService: loggingService,
            activityGate: activityGate,
            messageSender: messageSender,
            settingsDb: settingsDb,
            eventProcessor: eventProcessor,
            secureStorage: secureStorage,
            queueCoordinator: queueCoordinator,
            sessionManager: sessionManager,
            roomManager: roomManager,
            syncEngine: syncEngine,
            lifecycleCoordinator: differentCoordinator,
            connectivityStream: const Stream.empty(),
          ),
          throwsArgumentError,
        );
      },
    );
  });

  group('MatrixService sendMatrixMsg variants', () {
    // Helper that wires sendMatrixMessage to invoke onSent and return true.
    void stubSenderSuccess() {
      when(
        () => messageSender.sendMatrixMessage(
          message: any(named: 'message'),
          context: any(named: 'context'),
          onSent: any(named: 'onSent'),
        ),
      ).thenAnswer((invocation) async {
        final onSent =
            invocation.namedArguments[#onSent]
                as void Function(String, SyncMessage);
        onSent(
          r'$evt',
          invocation.namedArguments[#message] as SyncMessage,
        );
        return true;
      });
    }

    // Covers line 375: journalEntity bucket.
    test('sendMatrixMsg increments journalEntity bucket', () async {
      stubSenderSuccess();
      when(() => client.getRoomById(any())).thenReturn(null);
      final service = createService();
      const msg = SyncMessage.journalEntity(
        id: 'j1',
        jsonPath: '/p',
        vectorClock: null,
        status: SyncEntryStatus.initial,
      );
      await service.sendMatrixMsg(msg);
      expect(service.messageCounts['journalEntity'], 1);
    });

    // Covers line 376: entityDefinition bucket.
    test('sendMatrixMsg increments entityDefinition bucket', () async {
      stubSenderSuccess();
      when(() => client.getRoomById(any())).thenReturn(null);
      final service = createService();
      final msg = SyncMessage.entityDefinition(
        entityDefinition: EntityDefinition.categoryDefinition(
          id: 'c1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          name: 'test',
          vectorClock: null,
          private: false,
          active: true,
        ),
        status: SyncEntryStatus.initial,
      );
      await service.sendMatrixMsg(msg);
      expect(service.messageCounts['entityDefinition'], 1);
    });

    // Covers line 378: aiConfig bucket.
    test('sendMatrixMsg increments aiConfig bucket', () async {
      stubSenderSuccess();
      when(() => client.getRoomById(any())).thenReturn(null);
      final service = createService();
      const msg = SyncMessage.aiConfigDelete(id: 'ai1');
      await service.sendMatrixMsg(msg);
      expect(service.messageCounts['aiConfigDelete'], 1);
    });

    // Covers line 380: themingSelection bucket.
    test('sendMatrixMsg increments themingSelection bucket', () async {
      stubSenderSuccess();
      when(() => client.getRoomById(any())).thenReturn(null);
      final service = createService();
      const msg = SyncMessage.themingSelection(
        lightThemeName: 'light',
        darkThemeName: 'dark',
        themeMode: 'system',
        updatedAt: 0,
        status: SyncEntryStatus.initial,
      );
      await service.sendMatrixMsg(msg);
      expect(service.messageCounts['themingSelection'], 1);
    });

    // Covers line 383: backfillRequest bucket.
    test('sendMatrixMsg increments backfillRequest bucket', () async {
      stubSenderSuccess();
      when(() => client.getRoomById(any())).thenReturn(null);
      final service = createService();
      const msg = SyncMessage.backfillRequest(
        entries: [],
        requesterId: 'host-1',
      );
      await service.sendMatrixMsg(msg);
      expect(service.messageCounts['backfillRequest'], 1);
    });

    // Covers line 384: backfillResponse bucket.
    test('sendMatrixMsg increments backfillResponse bucket', () async {
      stubSenderSuccess();
      when(() => client.getRoomById(any())).thenReturn(null);
      final service = createService();
      const msg = SyncMessage.backfillResponse(
        hostId: 'h1',
        counter: 1,
        deleted: false,
      );
      await service.sendMatrixMsg(msg);
      expect(service.messageCounts['backfillResponse'], 1);
    });

    // Covers line 385: agentEntity bucket.
    test('sendMatrixMsg increments agentEntity bucket', () async {
      stubSenderSuccess();
      when(() => client.getRoomById(any())).thenReturn(null);
      final service = createService();
      const msg = SyncMessage.agentEntity(status: SyncEntryStatus.initial);
      await service.sendMatrixMsg(msg);
      expect(service.messageCounts['agentEntity'], 1);
    });

    // Covers line 386: agentLink bucket.
    test('sendMatrixMsg increments agentLink bucket', () async {
      stubSenderSuccess();
      when(() => client.getRoomById(any())).thenReturn(null);
      final service = createService();
      const msg = SyncMessage.agentLink(status: SyncEntryStatus.initial);
      await service.sendMatrixMsg(msg);
      expect(service.messageCounts['agentLink'], 1);
    });

    // Covers line 388: outboxBundle bucket.
    test('sendMatrixMsg increments outboxBundle bucket', () async {
      stubSenderSuccess();
      when(() => client.getRoomById(any())).thenReturn(null);
      final service = createService();
      const msg = SyncMessage.outboxBundle(children: []);
      await service.sendMatrixMsg(msg);
      expect(service.messageCounts['outboxBundle'], 1);
    });

    // Covers line 389: syncNodeProfile bucket.
    test('sendMatrixMsg increments syncNodeProfile bucket', () async {
      stubSenderSuccess();
      when(() => client.getRoomById(any())).thenReturn(null);
      final service = createService();
      final msg = SyncMessage.syncNodeProfile(
        profile: SyncNodeProfile(
          hostId: 'h1',
          displayName: 'dev',
          platform: 'macos',
          capabilities: const [],
          updatedAt: DateTime(2024, 3, 15),
        ),
      );
      await service.sendMatrixMsg(msg);
      expect(service.messageCounts['syncNodeProfile'], 1);
    });
  });

  group('MatrixService additional coverage', () {
    // Covers lines 403-404: login() delegates to syncEngine.
    test('login delegates to syncEngine connectWithLifecycleOption', () async {
      when(
        () => syncEngine.connectWithLifecycleOption(
          shouldAttemptLogin: any(named: 'shouldAttemptLogin'),
          waitForLifecycle: any(named: 'waitForLifecycle'),
        ),
      ).thenAnswer((_) async => true);

      final service = createService();
      final result = await service.login();

      expect(result, isTrue);
      verify(
        () => syncEngine.connectWithLifecycleOption(
          shouldAttemptLogin: true,
          waitForLifecycle: true,
        ),
      ).called(1);
    });

    // Covers line 413: joinRoom returns room.id when room is non-null.
    test('joinRoom returns room id when room manager returns a room', () async {
      final room = MockRoom();
      when(() => room.id).thenReturn('!joined:server');
      when(
        () => roomManager.joinRoom(any()),
      ).thenAnswer((_) async => room);

      final service = createService();
      final result = await service.joinRoom('!joined:server');

      expect(result, '!joined:server');
    });

    // Covers line 521: onVerificationCompleted calls updateUserDeviceKeys()
    // without additionalUsers when userId is null.
    test(
      'onVerificationCompleted calls updateUserDeviceKeys without userId when '
      'client.userID is null',
      () async {
        when(() => sessionManager.isLoggedIn()).thenReturn(true);
        when(() => client.userID).thenReturn(null);
        when(
          () => client.updateUserDeviceKeys(),
        ).thenAnswer((_) async {});
        when(
          () => coordinator.reconcileLifecycleState(),
        ).thenAnswer((_) async {});
        when(queueCoordinator.triggerBridge).thenAnswer((_) async {});

        final service = createService();
        await service.onVerificationCompleted(source: 'test');

        verify(() => client.updateUserDeviceKeys()).called(1);
        verifyNever(
          () => client.updateUserDeviceKeys(
            additionalUsers: any(named: 'additionalUsers'),
          ),
        );
      },
    );

    // Covers dispose() does not call activityGate.dispose() when
    // _ownsActivityGate is false (the default).
    test(
      'dispose does not dispose activity gate when ownsActivityGate is false',
      () async {
        when(() => syncEngine.dispose()).thenAnswer((_) async {});
        when(() => sessionManager.dispose()).thenAnswer((_) async {});
        when(() => roomManager.dispose()).thenAnswer((_) async {});

        final service = createService();
        await service.dispose();

        verifyNever(() => activityGate.dispose());
      },
    );
  });

  group('MatrixService deleteDevice', () {
    // Covers lines 548-552: throws ArgumentError when deviceId is null.
    test('deleteDevice throws ArgumentError when deviceId is null', () async {
      final deviceKeys = _MockDeviceKeys();
      when(() => deviceKeys.deviceId).thenReturn(null);
      when(() => deviceKeys.deviceDisplayName).thenReturn('My Device');

      final service = createService();

      await expectLater(
        service.deleteDevice(deviceKeys),
        throwsA(isA<ArgumentError>()),
      );
    });

    // Covers lines 556-560: throws StateError when matrixConfig is null.
    test('deleteDevice throws StateError when matrixConfig is null', () async {
      final deviceKeys = _MockDeviceKeys();
      when(() => deviceKeys.deviceId).thenReturn('DEVICE1');
      when(() => sessionManager.matrixConfig).thenReturn(null);

      final service = createService();

      await expectLater(
        service.deleteDevice(deviceKeys),
        throwsA(isA<StateError>()),
      );
    });

    // Covers lines 563-567: throws StateError when device belongs to a
    // different user.
    test(
      'deleteDevice throws StateError when device belongs to different user',
      () async {
        final deviceKeys = _MockDeviceKeys();
        when(() => deviceKeys.deviceId).thenReturn('DEVICE1');
        when(() => deviceKeys.userId).thenReturn('@other:server');
        when(() => client.userID).thenReturn('@me:server');
        when(() => sessionManager.matrixConfig).thenReturn(
          const MatrixConfig(
            homeServer: 'https://hs',
            user: '@me:server',
            password: 'pass',
          ),
        );

        final service = createService();

        await expectLater(
          service.deleteDevice(deviceKeys),
          throwsA(isA<StateError>()),
        );
      },
    );

    // Covers lines 579-583: throws UnsupportedError when password is empty.
    test(
      'deleteDevice throws UnsupportedError when password is empty',
      () async {
        final deviceKeys = _MockDeviceKeys();
        when(() => deviceKeys.deviceId).thenReturn('DEVICE1');
        when(() => deviceKeys.userId).thenReturn('@me:server');
        when(() => client.userID).thenReturn('@me:server');
        when(() => sessionManager.matrixConfig).thenReturn(
          const MatrixConfig(
            homeServer: 'https://hs',
            user: '@me:server',
            password: '',
          ),
        );

        final service = createService();

        await expectLater(
          service.deleteDevice(deviceKeys),
          throwsA(isA<UnsupportedError>()),
        );
      },
    );

    // Covers lines 570-577: deleteDevice calls client.deleteDevice when
    // password is non-empty and user matches.
    test(
      'deleteDevice calls client.deleteDevice when credentials are valid',
      () async {
        final deviceKeys = _MockDeviceKeys();
        when(() => deviceKeys.deviceId).thenReturn('DEVICE1');
        when(() => deviceKeys.userId).thenReturn('@me:server');
        when(() => client.userID).thenReturn('@me:server');
        when(() => sessionManager.matrixConfig).thenReturn(
          const MatrixConfig(
            homeServer: 'https://hs',
            user: '@me:server',
            password: 'secret',
          ),
        );
        when(
          () => client.deleteDevice(
            any(),
            auth: any(named: 'auth'),
          ),
        ).thenAnswer((_) async {});

        final service = createService();
        await service.deleteDevice(deviceKeys);

        verify(
          () => client.deleteDevice('DEVICE1', auth: any(named: 'auth')),
        ).called(1);
      },
    );
  });

  group('MatrixService getSyncDiagnosticsText', () {
    // Covers line 755: returns 'pipeline disabled' when no pipeline.
    test(
      'getSyncDiagnosticsText returns pipeline disabled without pipeline',
      () async {
        final service = createService();
        final text = await service.getSyncDiagnosticsText();
        expect(text, 'pipeline disabled');
      },
    );

    // Covers lines 757-766: returns formatted metrics text with diagnostics.
    test(
      'getSyncDiagnosticsText returns metric lines joined with newline',
      () async {
        when(() => pipeline.metricsSnapshot()).thenReturn({'consumed': 5});
        when(() => pipeline.diagnosticsStrings()).thenReturn({'lag': '100ms'});

        final service = createServiceWithPipeline();
        final text = await service.getSyncDiagnosticsText();

        expect(text, contains('consumed=5'));
        expect(text, contains('lag=100ms'));
      },
    );

    // Covers lines 763-764: swallows exception from diagnosticsStrings.
    test(
      'getSyncDiagnosticsText still returns metrics when diagnosticsStrings '
      'throws',
      () async {
        when(
          () => pipeline.metricsSnapshot(),
        ).thenReturn({'consumed': 2});
        when(() => pipeline.diagnosticsStrings()).thenThrow(
          UnimplementedError('no diagnostics'),
        );

        final service = createServiceWithPipeline();
        final text = await service.getSyncDiagnosticsText();

        expect(text, 'consumed=2');
      },
    );
  });

  group('MatrixService connectivity signal', () {
    // Covers line 181: recordConnectivitySignal called on wifi reconnect.
    test(
      'connectivity regain triggers pipeline recordConnectivitySignal',
      () async {
        final connectivityController =
            StreamController<List<ConnectivityResult>>();
        when(
          () => pipeline.reportDbApplyDiagnostics(any()),
        ).thenReturn(null);
        when(pipeline.recordConnectivitySignal).thenReturn(null);

        final service = MatrixService(
          gateway: gateway,
          loggingService: loggingService,
          activityGate: activityGate,
          messageSender: messageSender,
          settingsDb: settingsDb,
          eventProcessor: eventProcessor,
          secureStorage: secureStorage,
          queueCoordinator: queueCoordinator,
          sessionManager: sessionManager,
          roomManager: roomManager,
          pipelineOverride: pipeline,
          connectivityStream: connectivityController.stream,
        );

        connectivityController.add([ConnectivityResult.wifi]);
        await pumpEventQueue();

        verify(pipeline.recordConnectivitySignal).called(1);

        // Cleanup
        await connectivityController.close();
        when(() => syncEngine.dispose()).thenAnswer((_) async {});
        when(() => sessionManager.dispose()).thenAnswer((_) async {});
        when(() => roomManager.dispose()).thenAnswer((_) async {});
        await service.dispose();
      },
    );
  });

  group('MatrixService default sub-service construction', () {
    // Builds a service with neither a sessionManager, roomManager, syncEngine,
    // nor a pipelineOverride. This exercises the constructor's default-wiring
    // branches:
    //   - lines 78-82  : default SyncRoomManager(gateway, settingsDb, logging)
    //   - lines 85-89  : default MatrixSessionManager(gateway, roomManager, ...)
    //   - lines 110-119: default MatrixStreamConsumer(...)
    //   - lines 141-156: default SyncLifecycleCoordinator + SyncEngine
    // The real SyncRoomManager subscribes to `gateway.invites` in its
    // constructor, so that stream must be stubbed.
    MatrixService buildWithDefaults({
      MatrixConfig? matrixConfig,
      String? deviceDisplayName,
    }) {
      when(() => gateway.invites).thenAnswer((_) => const Stream.empty());
      return MatrixService(
        gateway: gateway,
        loggingService: loggingService,
        activityGate: activityGate,
        messageSender: messageSender,
        settingsDb: settingsDb,
        eventProcessor: eventProcessor,
        secureStorage: secureStorage,
        queueCoordinator: queueCoordinator,
        matrixConfig: matrixConfig,
        deviceDisplayName: deviceDisplayName,
        connectivityStream: const Stream.empty(),
      );
    }

    test(
      'constructs a real pipeline and real engine when nothing is injected',
      () {
        final service = buildWithDefaults();

        // The default pipeline branch (lines 110-120) constructed a real
        // MatrixStreamConsumer that is exposed via debugPipeline.
        expect(service.debugPipeline, isA<MatrixStreamConsumer>());
        // The wiring set the event processor's apply observer to the
        // pipeline's diagnostics reporter (line 122).
        verify(() => eventProcessor.applyObserver = any()).called(1);
      },
    );

    test(
      'assigns matrixConfig onto the default session manager (line 92)',
      () {
        const config = MatrixConfig(
          homeServer: 'https://hs',
          user: '@me:server',
          password: 'pass',
        );

        final service = buildWithDefaults(matrixConfig: config);

        // The real MatrixSessionManager.matrixConfig getter returns the value
        // assigned during construction.
        expect(service.matrixConfig, config);
      },
    );

    test(
      'assigns deviceDisplayName onto the default session manager (line 95)',
      () {
        // Without a deviceDisplayName, the freshly constructed session
        // manager has no config and reports a null matrixConfig.
        final service = buildWithDefaults(deviceDisplayName: 'My Laptop');

        // deviceDisplayName is internal to the session manager; assert the
        // service built without throwing and exposes the default real chain,
        // proving the line 94-96 branch ran (it would have thrown on a
        // null-check failure otherwise).
        expect(service.matrixConfig, isNull);
        expect(service.debugPipeline, isA<MatrixStreamConsumer>());
      },
    );
  });

  group('MatrixService stats debounce (non-test env)', () {
    // Covers lines 261-268: when `isTestEnv` is false, `_scheduleStatsEmit`
    // sets up a debounce Timer instead of emitting immediately, and a second
    // increment before the timer fires is coalesced (line 261 early return).
    test('debounces stats emissions and coalesces rapid increments', () {
      final original = platform.isTestEnv;
      addTearDown(() => platform.isTestEnv = original);

      fakeAsync((async) {
        platform.isTestEnv = false;
        final service = createService();

        final emitted = <MatrixStats>[];
        final sub = service.messageCountsController.stream.listen(emitted.add);

        // First increment schedules the debounce timer (line 262); the second
        // increment before the timer fires hits the early-return guard at line
        // 261 (a timer is already pending) and is coalesced.
        service
          ..incrementSentCountOf('journalEntity')
          ..incrementSentCountOf('journalEntity');

        // Nothing emitted yet: the debounce window has not elapsed.
        expect(emitted, isEmpty);

        // Advance past the 500ms debounce window to fire the timer body
        // (lines 262-266).
        async.elapse(const Duration(milliseconds: 500));

        // Exactly one coalesced emission carrying both increments.
        expect(emitted, hasLength(1));
        expect(emitted.single.sentCount, 2);
        expect(emitted.single.messageCounts['journalEntity'], 2);

        sub.cancel();
      });
    });
  });

  group('MatrixService key verification', () {
    // Covers lines 587-588: getIncomingKeyVerificationStream returns the
    // incoming key-verification controller's stream, and events added to that
    // controller flow through to subscribers.
    test('getIncomingKeyVerificationStream exposes incoming controller', () {
      final service = createService();
      final verification = _MockKeyVerification();

      final received = <KeyVerification>[];
      final sub = service.getIncomingKeyVerificationStream().listen(
        received.add,
      );

      service.incomingKeyVerificationController.add(verification);

      return Future<void>(() async {
        await pumpEventQueue();
        expect(received, [verification]);
        await sub.cancel();
      });
    });

    // Covers line 498: verifyDevice delegates to verifyMatrixDevice, which
    // starts SDK verification and stores the resulting runner on the service.
    test('verifyDevice starts verification and sets keyVerificationRunner', () {
      final deviceKeys = _MockDeviceKeys();
      final verification = _MockKeyVerification();
      when(deviceKeys.startVerification).thenAnswer((_) async => verification);
      when(() => verification.lastStep).thenReturn(null);
      when(() => verification.isDone).thenReturn(false);
      when(() => verification.sasEmojis).thenReturn([]);

      final service = createService();

      return Future<void>(() async {
        expect(service.keyVerificationRunner, isNull);
        await service.verifyDevice(deviceKeys);

        verify(deviceKeys.startVerification).called(1);
        final runner = service.keyVerificationRunner;
        expect(runner, isNotNull);
        expect(runner!.name, 'Outgoing KeyVerificationRunner');

        // Cancel the runner's 100ms poll timer so it does not leak.
        runner.stopTimer();
      });
    });
  });
}
