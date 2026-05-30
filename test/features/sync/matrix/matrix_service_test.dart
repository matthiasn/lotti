import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
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
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/services/domain_logging.dart';
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
}
