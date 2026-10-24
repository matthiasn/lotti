import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_page_state.dart';
import 'package:lotti/classes/saved_task_filter.dart';
import 'package:lotti/classes/sync/sync_message.dart';
import 'package:lotti/classes/sync/sync_node_profile.dart';
import 'package:lotti/classes/sync_sequence_payload_type.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/sync/matrix/key_verification_runner.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/matrix_service_ops.dart';
import 'package:lotti/features/sync/matrix/stats.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/models/sync_login_state.dart';
import 'package:lotti/features/sync/sync_service.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart' show Device, LoginState, MatrixException;
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../ai_consumption/test_utils.dart';

class _FakeMatrixMessageContext extends Fake implements MatrixMessageContext {}

void main() {
  late MockMatrixSyncGateway gateway;
  late DomainLogger loggingService;
  late MockUserActivityGate activityGate;
  late MockMatrixMessageSender messageSender;
  late MockSettingsDb settingsDb;
  late MockSyncEventProcessor eventProcessor;
  late MockSecureStorage secureStorage;
  late MockMatrixClient client;
  late MockMatrixSessionManager sessionManager;
  late MockSyncRoomManager roomManager;
  late MockMatrixStreamConsumer pipeline;
  late MockSyncEngine syncEngine;
  late MockSyncLifecycleCoordinator coordinator;
  late MockQueuePipelineCoordinator queueCoordinator;

  MockQueuePipelineCoordinator buildQueueCoordinator() {
    final c = MockQueuePipelineCoordinator();
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
    gateway = MockMatrixSyncGateway();
    loggingService = MockDomainLogger();
    activityGate = MockUserActivityGate();
    messageSender = MockMatrixMessageSender();
    settingsDb = MockSettingsDb();
    eventProcessor = MockSyncEventProcessor();
    secureStorage = MockSecureStorage();
    client = MockMatrixClient();
    sessionManager = MockMatrixSessionManager();
    roomManager = MockSyncRoomManager();
    pipeline = MockMatrixStreamConsumer();
    syncEngine = MockSyncEngine();
    coordinator = MockSyncLifecycleCoordinator();
    queueCoordinator = buildQueueCoordinator();

    when(() => sessionManager.client).thenReturn(client);
    when(() => sessionManager.matrixConfig).thenReturn(null);
    when(() => roomManager.currentRoomId).thenReturn(null);
    when(() => roomManager.currentRoom).thenReturn(null);
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
    test('client getter returns session manager client', () {
      final service = createService();

      expect(service.client, client);
    });

    test("own identity is the client session's user and device", () {
      when(() => client.userID).thenReturn('@alice:example.com');
      when(() => client.deviceID).thenReturn('DEVICE1');
      final service = createService();

      expect(service.ownUserId, '@alice:example.com');
      expect(service.ownDeviceId, 'DEVICE1');
    });

    test('syncRoomId returns room manager currentRoomId', () {
      when(() => roomManager.currentRoomId).thenReturn('!room:s');

      final service = createService();

      expect(service.syncRoomId, '!room:s');
    });

    test('syncRoomIdChanges forwards the room manager stream', () async {
      // The UI gate for "is sync configured" hangs off this; a getter that
      // returned a fresh empty stream would leave the roster stale forever.
      final changes = Stream<String?>.fromIterable(['!room:s', null]);
      when(() => roomManager.roomIdChanges).thenAnswer((_) => changes);

      final service = createService();

      expect(await service.syncRoomIdChanges.toList(), ['!room:s', null]);
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
              invocation.namedArguments[#onSent] as MatrixMessageSentCallback;
          await onSent(
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
        SyncMessage? observedSentMessage;
        service.onSyncMessageSent = (message) async {
          observedSentMessage = message;
        };
        final result = await service.sendMatrixMsg(
          bundle,
          myRoomId: '!room:s',
        );

        expect(result, isTrue);
        expect(service.messageCounts['agentBundle'], 1);
        expect(observedSentMessage, bundle);
      },
    );

    test('sent hook receives original outbox bundle children', () async {
      when(() => roomManager.currentRoom).thenReturn(null);
      when(() => roomManager.currentRoomId).thenReturn(null);
      when(() => client.getRoomById(any())).thenReturn(null);
      const end = SyncMessage.onboardingSnapshotEnd(
        protocolVersion: 1,
        roundId: 'round-1',
        senderHostId: 'sender-host',
        recipientUserId: 'recipient-user',
        recipientDeviceId: 'recipient-device',
        reason: OnboardingSyncEndReason.complete,
      );
      const original = SyncMessage.outboxBundle(
        children: [
          SyncMessage.aiConfigDelete(id: 'adjacent'),
          end,
        ],
      );
      when(
        () => messageSender.sendMatrixMessage(
          message: original,
          context: any(named: 'context'),
          onSent: any(named: 'onSent'),
        ),
      ).thenAnswer((invocation) async {
        final onSent =
            invocation.namedArguments[#onSent] as MatrixMessageSentCallback;
        await onSent(
          r'$evt-bundle',
          const SyncOutboxBundle(
            children: [],
            jsonPath: '/outbox_bundles/stripped.json',
          ),
        );
        return true;
      });

      final service = createService();
      SyncMessage? observed;
      service.onSyncMessageSent = (message) async => observed = message;

      expect(
        await service.sendMatrixMsg(original, myRoomId: '!room:s'),
        isTrue,
      );
      expect(observed, original);
    });

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

    test(
      'dispose stops live ceremonies before closing their streams',
      () async {
        when(() => syncEngine.dispose()).thenAnswer((_) async {});
        when(() => sessionManager.dispose()).thenAnswer((_) async {});
        when(() => roomManager.dispose()).thenAnswer((_) async {});
        final service = createService();
        final outgoing = MockKeyVerificationRunner();
        final incoming = MockKeyVerificationRunner();
        when(outgoing.stopTimer).thenReturn(null);
        when(incoming.stopTimer).thenReturn(null);
        service
          ..keyVerificationRunner = outgoing
          ..incomingKeyVerificationRunner = incoming;

        await service.dispose();

        // Their 100 ms polls publish into the controllers dispose closes.
        verify(outgoing.stopTimer).called(1);
        verify(incoming.stopTimer).called(1);
      },
    );

    test('createRoom delegates to room manager and returns the id', () async {
      when(
        () => roomManager.createRoom(name: any(named: 'name')),
      ).thenAnswer((_) async => '!created:server');

      final service = createService();

      expect(await service.createRoom(), '!created:server');
      verify(() => roomManager.createRoom(name: any(named: 'name'))).called(1);
    });

    test('findSyncRoom asks the room manager for the existing '
        'sync room', () async {
      when(
        () => roomManager.findSyncRoom(),
      ).thenAnswer((_) async => '!existing:server');

      expect(await createService().findSyncRoom(), '!existing:server');
      verify(() => roomManager.findSyncRoom()).called(1);
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

    test('getRoom delegates to room manager', () async {
      when(
        () => roomManager.loadPersistedRoomId(),
      ).thenAnswer((_) async => '!stored:room');

      final service = createService();
      final result = await service.getRoom();

      expect(result, '!stored:room');
    });

    test('clearPersistedRoom delegates to room manager', () async {
      when(
        () => roomManager.clearPersistedRoom(),
      ).thenAnswer((_) async {});

      final service = createService();
      await service.clearPersistedRoom();

      verify(() => roomManager.clearPersistedRoom()).called(1);
    });

    test('logout delegates to sync engine', () async {
      when(() => syncEngine.logout()).thenAnswer((_) async {});

      final service = createService();
      await service.logout();

      verify(() => syncEngine.logout()).called(1);
    });
  });

  group('MatrixService error and log branches', () {
    test(
      'init logs and rethrows when the queue coordinator cannot start',
      () async {
        final failure = Exception('queue start boom');
        when(queueCoordinator.start).thenThrow(failure);
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

        final service = createService();

        await expectLater(
          service.init(),
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
    test('init logs readiness without account or device identity', () async {
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
              contains('MatrixService initialized'),
              isNot(contains('DEVICE1')),
              isNot(contains('@me:server')),
              isNot(contains('Lotti')),
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

    // Success path of the saveRoom bootstrap: pipeline start, room-change
    // hook, and bridge kick all run — in that order — with no error log.
    test(
      'saveRoom success path starts pipeline, seeds room, kicks bridge',
      () async {
        final order = <String>[];
        when(() => roomManager.saveRoomId(any())).thenAnswer((_) async {});
        when(pipeline.start).thenAnswer((_) async {
          order.add('pipeline.start');
        });
        when(() => queueCoordinator.onRoomChanged(any())).thenAnswer((_) async {
          order.add('onRoomChanged');
        });
        when(queueCoordinator.triggerBridge).thenAnswer((_) async {
          order.add('triggerBridge');
        });

        final service = createServiceWithPipeline();
        await service.saveRoom('!room:server');
        await pumpEventQueue();

        expect(order, ['pipeline.start', 'onRoomChanged', 'triggerBridge']);
        verifyNever(
          () => loggingService.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
            subDomain: 'saveRoom.bootstrap',
          ),
        );
      },
    );

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

    // Covers lines 287-288: publishIncomingRunnerState is a no-op when
    // incomingKeyVerificationRunner is null (default).
    test(
      'publishIncomingRunnerState is a no-op when runner is null',
      () {
        final service = createService();
        // No runner set — returnsNormally invokes the passed tear-off, so this
        // genuinely calls publishIncomingRunnerState and asserts it doesn't throw.
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
        final innerRoomManager = MockSyncRoomManager();
        when(() => innerRoomManager.currentRoomId).thenReturn('!r:s');
        when(() => innerRoomManager.currentRoom).thenReturn(null);
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
        final differentCoordinator = MockSyncLifecycleCoordinator();
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

  group('MatrixService exclusion-policy rotation gate', () {
    test(
      'a send started before the rotation finishes waits for it, so no entry '
      'is encrypted with the pre-upgrade session (ADR 0045)',
      () => fakeAsync((async) {
        final settingsGate = Completer<String?>();
        final rotationGate = Completer<bool>();
        final encryption = MockEncryption();
        final keyManager = MockKeyManager();
        when(() => sessionManager.client).thenReturn(client);
        when(() => client.encryption).thenReturn(encryption);
        when(() => encryption.keyManager).thenReturn(keyManager);
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        // The marker read is what the rotation awaits first; hold it open to
        // keep the migration in flight while a send is attempted.
        when(
          () => settingsDb.itemByKey(any()),
        ).thenAnswer((_) => settingsGate.future);
        when(
          () => keyManager.clearOrUseOutboundGroupSession(
            any(),
            wipe: any(named: 'wipe'),
            use: any(named: 'use'),
          ),
        ).thenAnswer((_) => rotationGate.future);
        when(
          () => settingsDb.saveSettingsItem(any(), any()),
        ).thenAnswer((_) async => 1);
        when(
          () => messageSender.sendMatrixMessage(
            message: any(named: 'message'),
            context: any(named: 'context'),
            onSent: any(named: 'onSent'),
          ),
        ).thenAnswer((_) async => true);

        final service = createService();
        var sendCompleted = false;
        unawaited(
          service
              .sendMatrixMsg(const SyncMessage.aiConfigDelete(id: 'abc'))
              .then((_) => sendCompleted = true),
        );
        async.flushMicrotasks();

        // The rotation has not finished, so nothing may have been sent yet.
        expect(sendCompleted, isFalse);
        verifyNever(
          () => messageSender.sendMatrixMessage(
            message: any(named: 'message'),
            context: any(named: 'context'),
            onSent: any(named: 'onSent'),
          ),
        );

        settingsGate.complete(null);
        async.flushMicrotasks();

        verify(
          () => keyManager.clearOrUseOutboundGroupSession(
            '!room:server',
            wipe: true,
            use: false,
          ),
        ).called(1);
        expect(sendCompleted, isFalse);
        verifyNever(() => settingsDb.saveSettingsItem(any(), any()));
        verifyNever(
          () => messageSender.sendMatrixMessage(
            message: any(named: 'message'),
            context: any(named: 'context'),
            onSent: any(named: 'onSent'),
          ),
        );

        rotationGate.complete(true);
        async.flushMicrotasks();

        verifyInOrder([
          () => settingsDb.saveSettingsItem(
            MatrixServiceOps.megolmRotatedForExclusionKey('!room:server'),
            'true',
          ),
          () => messageSender.sendMatrixMessage(
            message: any(named: 'message'),
            context: any(named: 'context'),
            onSent: any(named: 'onSent'),
          ),
        ]);
        expect(sendCompleted, isTrue);
      }),
    );

    test(
      'logging out clears the gate so the next login re-runs the rotation',
      () async {
        when(() => sessionManager.client).thenReturn(client);
        when(() => client.encryption).thenReturn(null);
        when(() => client.deviceID).thenReturn('DEVICE1');
        when(() => client.deviceName).thenReturn('Lotti');
        when(() => client.userID).thenReturn('@me:server');
        when(() => roomManager.currentRoomId).thenReturn('!room:server');
        when(() => settingsDb.itemByKey(any())).thenAnswer((_) async => null);
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
        when(
          () => messageSender.sendMatrixMessage(
            message: any(named: 'message'),
            context: any(named: 'context'),
            onSent: any(named: 'onSent'),
          ),
        ).thenAnswer((_) async => true);

        final service = createService();
        await service.init();
        await service.sendMatrixMsg(const SyncMessage.aiConfigDelete(id: 'a'));
        verify(() => settingsDb.itemByKey(any())).called(1);

        final captured = verify(
          () => syncEngine.initialize(
            onLogin: any(named: 'onLogin'),
            onLogout: captureAny(named: 'onLogout'),
          ),
        ).captured;
        await (captured.last as Future<void> Function())();

        // A new session must re-evaluate the migration for whatever room and
        // device it comes back as.
        await service.sendMatrixMsg(const SyncMessage.aiConfigDelete(id: 'b'));
        verify(() => settingsDb.itemByKey(any())).called(1);
      },
    );

    test('the rotation runs at most once per login', () async {
      when(() => sessionManager.client).thenReturn(client);
      when(() => client.encryption).thenReturn(null);
      when(() => roomManager.currentRoomId).thenReturn('!room:server');
      when(() => settingsDb.itemByKey(any())).thenAnswer((_) async => null);
      when(
        () => messageSender.sendMatrixMessage(
          message: any(named: 'message'),
          context: any(named: 'context'),
          onSent: any(named: 'onSent'),
        ),
      ).thenAnswer((_) async => true);

      final service = createService();
      await service.sendMatrixMsg(const SyncMessage.aiConfigDelete(id: 'a'));
      await service.sendMatrixMsg(const SyncMessage.aiConfigDelete(id: 'b'));

      verify(() => settingsDb.itemByKey(any())).called(1);
    });
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
            invocation.namedArguments[#onSent] as MatrixMessageSentCallback;
        await onSent(
          r'$evt',
          invocation.namedArguments[#message] as SyncMessage,
        );
        return true;
      });
    }

    // Covers lines 377-378 and 381-382: the entryLink / aiConfig /
    // notification / notificationStateUpdate `map` arms. Each variant must
    // route through its own arm and increment the matching bucket. Driven by
    // a parameterized loop to avoid copy-paste permutations.
    const vectorClock = VectorClock({'host-1': 1});
    final entryLink = SyncMessage.entryLink(
      entryLink: EntryLink.basic(
        id: 'link-1',
        fromId: 'from-1',
        toId: 'to-1',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        vectorClock: null,
      ),
      status: SyncEntryStatus.initial,
    );
    final aiConfig = SyncMessage.aiConfig(
      aiConfig: AiConfig.inferenceProvider(
        id: 'prov-1',
        baseUrl: 'https://api',
        apiKey: 'secret',
        name: 'Anthropic',
        createdAt: DateTime(2024, 3, 15),
        inferenceProviderType: InferenceProviderType.anthropic,
      ),
      status: SyncEntryStatus.initial,
    );
    const notification = SyncMessage.notification(
      id: 'note-1',
      jsonPath: '/notes/note-1.json',
      vectorClock: vectorClock,
      originatingHostId: 'host-1',
    );
    const notificationStateUpdate = SyncMessage.notificationStateUpdate(
      id: 'note-1',
      vectorClock: vectorClock,
      originatingHostId: 'host-1',
    );

    final variantsByBucket = <String, SyncMessage>{
      'onboardingSnapshotBegin': const SyncMessage.onboardingSnapshotBegin(
        protocolVersion: 1,
        roundId: 'round-1',
        senderHostId: 'sender-host',
        senderUserId: 'sender-user',
        senderDeviceId: 'sender-device',
        recipientUserId: 'recipient-user',
        recipientDeviceId: 'recipient-device',
        coverageUpperBounds: {'sender-host': 42},
        leaseSeconds: 3600,
      ),
      'onboardingSnapshotAccepted':
          const SyncMessage.onboardingSnapshotAccepted(
            protocolVersion: 1,
            roundId: 'round-1',
            senderHostId: 'sender-host',
            senderUserId: 'sender-user',
            senderDeviceId: 'sender-device',
            recipientHostId: 'recipient-host',
            recipientDeviceId: 'recipient-device',
          ),
      'onboardingTerminalCounters':
          const SyncMessage.onboardingTerminalCounters(
            protocolVersion: 1,
            roundId: 'round-1',
            senderHostId: 'sender-host',
            recipientUserId: 'recipient-user',
            recipientDeviceId: 'recipient-device',
            ranges: [SyncCounterRange(start: 1, end: 2)],
          ),
      'onboardingSnapshotEnd': const SyncMessage.onboardingSnapshotEnd(
        protocolVersion: 1,
        roundId: 'round-1',
        senderHostId: 'sender-host',
        recipientUserId: 'recipient-user',
        recipientDeviceId: 'recipient-device',
        reason: OnboardingSyncEndReason.complete,
      ),
      'entryLink': entryLink,
      'aiConfig': aiConfig,
      'notification': notification,
      'notificationStateUpdate': notificationStateUpdate,
      'journalEntity': const SyncMessage.journalEntity(
        id: 'j1',
        jsonPath: '/p',
        vectorClock: null,
        status: SyncEntryStatus.initial,
      ),
      'entityDefinition': SyncMessage.entityDefinition(
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
      ),
      'aiConfigDelete': const SyncMessage.aiConfigDelete(id: 'ai1'),
      'savedTaskFilter': const SyncMessage.savedTaskFilter(
        filter: SavedTaskFilter(
          id: 'stf1',
          name: 'In Progress',
          filter: TasksFilter(selectedTaskStatuses: {'IN_PROGRESS'}),
        ),
        status: SyncEntryStatus.initial,
      ),
      'savedTaskFilterDelete': const SyncMessage.savedTaskFilterDelete(
        id: 'stf1',
      ),
      'configFlag': const SyncMessage.configFlag(
        name: 'enable_logging',
        description: 'Enable logging',
        status: true,
      ),
      'themingSelection': const SyncMessage.themingSelection(
        lightThemeName: 'light',
        darkThemeName: 'dark',
        themeMode: 'system',
        updatedAt: 0,
        status: SyncEntryStatus.initial,
      ),
      'dailyOsUserName': const SyncMessage.dailyOsUserName(
        userName: 'Sam',
        updatedAt: 0,
        status: SyncEntryStatus.initial,
      ),
      'companionCustomization': const SyncMessage.companionCustomization(
        customization: '{}',
        updatedAt: 0,
        status: SyncEntryStatus.initial,
      ),
      'gitHubAccount': const SyncMessage.gitHubAccount(
        updatedAt: 0,
        status: SyncEntryStatus.initial,
      ),
      'backfillRequest': const SyncMessage.backfillRequest(
        entries: [],
        requesterId: 'host-1',
      ),
      'mediaRequest': const SyncMessage.mediaRequest(
        entryIds: ['img-1'],
        requesterId: 'host-1',
      ),
      'deepBackfillInventory': const SyncMessage.deepBackfillInventory(
        roundId: 'round-1',
        hostId: 'host-1',
        payloadType: SyncSequencePayloadType.journalEntity,
        batch: 0,
      ),
      'deepBackfillRequest': const SyncMessage.deepBackfillRequest(
        requesterId: 'host-2',
        targetHostId: 'host-1',
        payloadType: SyncSequencePayloadType.journalEntity,
      ),
      'agentWakeCoordination': SyncMessage.agentWakeCoordination(
        agentId: 'agent-1',
        kind: AgentWakeCoordinationKind.claim,
        watermark: const {'host-a': 7},
        readsPrivate: false,
        definitionsDigest: 'sha256-v1:definitions',
        runKey: 'run-1',
        hostId: 'host-1',
        sentAt: DateTime(2024, 3, 15),
      ),
      'backfillResponse': const SyncMessage.backfillResponse(
        hostId: 'h1',
        counter: 1,
        deleted: false,
      ),
      'agentEntity': const SyncMessage.agentEntity(
        status: SyncEntryStatus.initial,
      ),
      'agentLink': const SyncMessage.agentLink(
        status: SyncEntryStatus.initial,
      ),
      'consumptionEvent': SyncMessage.consumptionEvent(
        event: makeConsumptionEvent(),
        status: SyncEntryStatus.update,
      ),
      'outboxBundle': const SyncMessage.outboxBundle(children: []),
      'syncNodeProfile': SyncMessage.syncNodeProfile(
        profile: SyncNodeProfile(
          hostId: 'h1',
          displayName: 'dev',
          platform: 'macos',
          capabilities: const [],
          updatedAt: DateTime(2024, 3, 15),
        ),
      ),
    };

    for (final entry in variantsByBucket.entries) {
      final bucket = entry.key;
      test('sendMatrixMsg increments $bucket bucket and forwards the '
          'message', () async {
        stubSenderSuccess();
        when(() => client.getRoomById(any())).thenReturn(null);

        final service = createService();
        final result = await service.sendMatrixMsg(entry.value);

        expect(result, isTrue);
        // Only the targeted bucket is incremented for this variant.
        expect(service.messageCounts[bucket], 1);
        expect(service.messageCounts.keys, [bucket]);
        // The exact message instance is forwarded to the sender unchanged.
        verify(
          () => messageSender.sendMatrixMessage(
            message: entry.value,
            context: any(named: 'context'),
            onSent: any(named: 'onSent'),
          ),
        ).called(1);
      });
    }
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

    // Covers line 635: dispose() disposes the activity gate when the service
    // owns it (ownsActivityGate == true). Pairs with the false-branch test
    // above.
    test(
      'dispose disposes activity gate when ownsActivityGate is true',
      () async {
        when(() => syncEngine.dispose()).thenAnswer((_) async {});
        when(() => sessionManager.dispose()).thenAnswer((_) async {});
        when(() => roomManager.dispose()).thenAnswer((_) async {});
        when(() => activityGate.dispose()).thenAnswer((_) async {});

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
          syncEngine: syncEngine,
          ownsActivityGate: true,
          connectivityStream: const Stream.empty(),
        );
        await service.dispose();

        verify(() => activityGate.dispose()).called(1);
      },
    );
  });

  group('MatrixService deleteDevice', () {
    test('deleteDeviceById delegates through ops to the gateway', () async {
      when(() => client.userID).thenReturn('@me:server');
      when(() => gateway.currentDeviceId).thenReturn('THIS_DEVICE');
      when(() => sessionManager.matrixConfig).thenReturn(
        const MatrixConfig(
          homeServer: 'https://hs',
          user: '@me:server',
          password: 'secret',
        ),
      );
      when(
        () => gateway.deleteDevice(any(), auth: any(named: 'auth')),
      ).thenAnswer((_) async {});
      when(
        () => client.updateUserDeviceKeys(
          additionalUsers: any(named: 'additionalUsers'),
        ),
      ).thenAnswer((_) async {});

      final service = createService();
      await service.deleteDeviceById('KEYLESS');

      verify(
        () => gateway.deleteDevice('KEYLESS', auth: any(named: 'auth')),
      ).called(1);
    });

    test('getSyncDevices returns the merged, ordered inventory', () async {
      when(() => client.userID).thenReturn('@me:server');
      when(() => client.userDeviceKeysLoading).thenReturn(null);
      when(() => client.userDeviceKeys).thenReturn({});
      when(() => gateway.currentDeviceId).thenReturn('THIS_DEVICE');
      when(() => gateway.getDevices()).thenAnswer(
        (_) async => [
          Device(deviceId: 'OTHER', displayName: 'Old laptop'),
          Device(deviceId: 'THIS_DEVICE', displayName: 'This desktop'),
        ],
      );

      final service = createService();
      final devices = await service.getSyncDevices();

      expect(
        devices.map((d) => d.deviceId).toList(),
        ['THIS_DEVICE', 'OTHER'],
      );
      expect(devices.first.isCurrentDevice, isTrue);
    });
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

  group('MatrixService connect after a start without network', () {
    test('a failed first connect is retried with a doubling wait, at once '
        'when connectivity returns, and not after dispose', () {
      fakeAsync((async) {
        final connectivity =
            StreamController<List<ConnectivityResult>>.broadcast();
        var attempts = 0;
        var online = false;
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
        ).thenAnswer((_) async {
          attempts++;
          return online;
        });
        when(
          () => secureStorage.read(key: any(named: 'key')),
        ).thenAnswer((_) async => null);
        when(() => sessionManager.matrixConfig).thenReturn(
          const MatrixConfig(
            homeServer: 'https://matrix.example.com',
            user: '@user:example.com',
            password: 'secret',
          ),
        );
        when(() => sessionManager.isLoggedIn()).thenReturn(false);
        when(() => client.isLogged()).thenReturn(false);
        when(pipeline.recordConnectivitySignal).thenReturn(null);
        when(
          () => pipeline.reportDbApplyDiagnostics(any()),
        ).thenReturn(null);

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
          syncEngine: syncEngine,
          pipelineOverride: pipeline,
          connectivityStream: connectivity.stream,
        );
        unawaited(service.init());
        async.flushMicrotasks();
        expect(attempts, 1);

        async
          ..elapse(SyncTuning.matrixReconnectInitialDelay)
          ..flushMicrotasks();
        expect(attempts, 2);
        // The wait doubled: nothing more after another initial delay.
        async
          ..elapse(SyncTuning.matrixReconnectInitialDelay)
          ..flushMicrotasks();
        expect(attempts, 2);

        // The network comes back before the next attempt is due.
        online = true;
        connectivity.add([ConnectivityResult.wifi]);
        async.flushMicrotasks();
        expect(attempts, 3);
        async
          ..elapse(SyncTuning.matrixReconnectMaxDelay * 2)
          ..flushMicrotasks();
        expect(attempts, 3);

        when(() => syncEngine.dispose()).thenAnswer((_) async {});
        when(() => sessionManager.dispose()).thenAnswer((_) async {});
        when(() => roomManager.dispose()).thenAnswer((_) async {});
        unawaited(service.dispose());
        unawaited(connectivity.close());
        async.flushMicrotasks();
      });
    });

    test('dispose stops a scheduled retry', () {
      fakeAsync((async) {
        var attempts = 0;
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
        ).thenAnswer((_) async {
          attempts++;
          return false;
        });
        when(
          () => secureStorage.read(key: any(named: 'key')),
        ).thenAnswer((_) async => null);
        when(() => sessionManager.matrixConfig).thenReturn(
          const MatrixConfig(
            homeServer: 'https://matrix.example.com',
            user: '@user:example.com',
            password: 'secret',
          ),
        );
        when(() => sessionManager.isLoggedIn()).thenReturn(false);
        when(() => client.isLogged()).thenReturn(false);
        when(() => syncEngine.dispose()).thenAnswer((_) async {});
        when(() => sessionManager.dispose()).thenAnswer((_) async {});
        when(() => roomManager.dispose()).thenAnswer((_) async {});

        final service = createService();
        unawaited(service.init());
        async.flushMicrotasks();
        expect(attempts, 1);

        unawaited(service.dispose());
        async
          ..flushMicrotasks()
          ..elapse(SyncTuning.matrixReconnectMaxDelay)
          ..flushMicrotasks();
        expect(attempts, 1);
      });
    });
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
        buildWithDefaults();

        // The wiring set the event processor's apply observer to the
        // pipeline's diagnostics reporter (line 122).
        verify(() => eventProcessor.applyObserver = any()).called(1);
      },
    );

    test(
      'hands the injected config and display name to the default session '
      'manager, which logs in with them',
      () async {
        const config = MatrixConfig(
          homeServer: 'https://matrix.waddle.example',
          user: '@pip:waddle.example',
          password: 'krill',
        );
        when(() => gateway.client).thenReturn(client);
        when(() => client.isLogged()).thenReturn(false);
        when(() => gateway.connect(config)).thenAnswer((_) async {});
        when(
          () => gateway.login(
            config,
            deviceDisplayName: any(named: 'deviceDisplayName'),
          ),
        ).thenAnswer((_) async => throw StateError('stop after login'));

        final service = buildWithDefaults(
          matrixConfig: config,
          deviceDisplayName: 'Waddle Desktop',
        );

        expect(await service.login(), isFalse);
        verify(() => gateway.connect(config)).called(1);
        verify(
          () => gateway.login(config, deviceDisplayName: 'Waddle Desktop'),
        ).called(1);
      },
    );
  });

  group('MatrixService with an injected lifecycle coordinator', () {
    test("adopts the coordinator's pipeline instead of building its own", () {
      when(() => coordinator.pipeline).thenReturn(pipeline);

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
        lifecycleCoordinator: coordinator,
        connectivityStream: const Stream.empty(),
      );

      expect(service.debugPipeline, same(pipeline));
      verify(() => eventProcessor.applyObserver = any()).called(1);
    });
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
      final verification = MockKeyVerification();

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
      final deviceKeys = MockDeviceKeys();
      final deviceKeysList = MockDeviceKeysList();
      when(() => deviceKeysList.deviceKeys).thenReturn({'DEVICE1': deviceKeys});
      when(
        () => client.userDeviceKeys,
      ).thenReturn({'@alice:example.com': deviceKeysList});
      final verification = MockKeyVerification();
      when(deviceKeys.startVerification).thenAnswer((_) async => verification);
      when(() => verification.lastStep).thenReturn(null);
      when(() => verification.isDone).thenReturn(false);
      when(() => verification.sasEmojis).thenReturn([]);

      final service = createService();

      return Future<void>(() async {
        expect(service.keyVerificationRunner, isNull);
        await service.verifyDevice(
          userId: '@alice:example.com',
          deviceId: 'DEVICE1',
        );

        verify(deviceKeys.startVerification).called(1);
        final runner = service.keyVerificationRunner;
        expect(runner, isNotNull);
        expect(runner!.name, 'Outgoing KeyVerificationRunner');

        // Cancel the runner's 100ms poll timer so it does not leak.
        runner.stopTimer();
      });
    });
  });

  group('MatrixService plain-typed verification API (ADR 0142)', () {
    /// An SDK ceremony with the stubs the runner reads on construction.
    MockKeyVerification ceremony({
      required String transactionId,
      String userId = '@alice:example.com',
      String deviceId = 'PEER',
      String? lastStep,
    }) {
      final kv = MockKeyVerification();
      when(() => kv.transactionId).thenReturn(transactionId);
      when(() => kv.userId).thenReturn(userId);
      when(() => kv.deviceId).thenReturn(deviceId);
      when(() => kv.lastStep).thenReturn(lastStep);
      when(() => kv.isDone).thenReturn(false);
      when(() => kv.sasEmojis).thenReturn([]);
      when(() => kv.onUpdate).thenReturn(null);
      when(() => kv.onUpdate = any()).thenReturn(null);
      when(kv.acceptVerification).thenAnswer((_) async {});
      when(kv.acceptSas).thenAnswer((_) async {});
      when(kv.cancel).thenAnswer((_) async {});
      return kv;
    }

    KeyVerificationRunner attachOutgoing(
      MatrixService service,
      MockKeyVerification kv,
    ) {
      final runner = KeyVerificationRunner(
        kv,
        controller: service.keyVerificationController,
        name: 'Outgoing KeyVerificationRunner',
        direction: SyncVerificationDirection.outgoing,
        domainLogger: loggingService,
      );
      addTearDown(runner.stopTimer);
      service.keyVerificationRunner = runner;
      return runner;
    }

    KeyVerificationRunner attachIncoming(
      MatrixService service,
      MockKeyVerification kv,
    ) {
      final runner = KeyVerificationRunner(
        kv,
        controller: service.incomingKeyVerificationRunnerController,
        name: 'Incoming KeyVerificationRunner',
        direction: SyncVerificationDirection.incoming,
        domainLogger: loggingService,
      );
      addTearDown(runner.stopTimer);
      service.incomingKeyVerificationRunner = runner;
      return runner;
    }

    test('outgoingVerifications publishes the runner as plain state and '
        'outgoingVerification is its latest snapshot', () async {
      final service = createService();
      final states = <SyncVerificationState>[];
      final sub = service.outgoingVerifications.listen(states.add);
      addTearDown(sub.cancel);

      attachOutgoing(
        service,
        ceremony(transactionId: 'txn-out', lastStep: 'm.key.verification.key'),
      ).publishState();
      await pumpEventQueue();

      expect(states, isNotEmpty);
      final state = states.last;
      expect(state.id, 'txn-out');
      expect(state.direction, SyncVerificationDirection.outgoing);
      expect(state.peerUserId, '@alice:example.com');
      expect(state.peerDeviceId, 'PEER');
      expect(state.lastStep, 'm.key.verification.key');
      expect(state.outcome, KeyVerificationOutcome.pending);
      expect(service.outgoingVerification?.id, 'txn-out');
      expect(service.incomingVerification, isNull);
    });

    test('incomingVerifications and incomingVerification report the incoming '
        'runner', () async {
      final service = createService();
      final states = <SyncVerificationState>[];
      final sub = service.incomingVerifications.listen(states.add);
      addTearDown(sub.cancel);

      attachIncoming(service, ceremony(transactionId: 'txn-in')).publishState();
      await pumpEventQueue();

      expect(states.last.id, 'txn-in');
      expect(states.last.direction, SyncVerificationDirection.incoming);
      expect(service.incomingVerification?.id, 'txn-in');
      expect(service.outgoingVerification, isNull);
    });

    test('incomingVerificationRequests maps each SDK request to a pending '
        'incoming state', () async {
      final service = createService();
      final states = <SyncVerificationState>[];
      final sub = service.incomingVerificationRequests.listen(states.add);
      addTearDown(sub.cancel);

      service.incomingKeyVerificationController.add(
        ceremony(
          transactionId: 'txn-req',
          deviceId: 'AAA',
          lastStep: 'm.key.verification.request',
        ),
      );
      await pumpEventQueue();

      expect(states, hasLength(1));
      expect(states.single.id, 'txn-req');
      expect(states.single.direction, SyncVerificationDirection.incoming);
      expect(states.single.peerDeviceId, 'AAA');
      expect(states.single.lastStep, 'm.key.verification.request');
      expect(states.single.isPending, isTrue);
      expect(states.single.emojis, isNull);
    });

    test('the state streams are the same instance on every read, so a '
        'StreamBuilder never resubscribes on a rebuild', () {
      final service = createService();

      expect(
        service.outgoingVerifications,
        same(service.outgoingVerifications),
      );
      expect(
        service.incomingVerifications,
        same(service.incomingVerifications),
      );
      expect(
        service.incomingVerificationRequests,
        same(service.incomingVerificationRequests),
      );
    });

    test('a request without a transaction id still gets a stable id', () {
      final service = createService();
      final kv = ceremony(transactionId: 'unused');
      when(() => kv.transactionId).thenReturn(null);

      final runner = attachIncoming(service, kv);

      expect(runner.id, startsWith('local-'));
      expect(service.incomingVerification?.id, runner.id);
    });

    group('acceptVerification', () {
      test('answers a remembered request before it has a runner', () async {
        final service = createService();
        final request = ceremony(transactionId: 'txn-req');
        service.rememberIncomingRequest(request);

        await service.acceptVerification('txn-req');

        verify(request.acceptVerification).called(1);
      });

      test('answers through the runner once one exists', () async {
        final service = createService();
        final kv = ceremony(transactionId: 'txn-in');
        attachIncoming(service, kv);

        await service.acceptVerification('txn-in');

        verify(kv.acceptVerification).called(1);
      });

      test('ignores an id it does not know', () async {
        final service = createService();

        await expectLater(service.acceptVerification('nobody'), completes);
      });

      test('keeps only the most recent requests', () async {
        final service = createService();
        final oldest = ceremony(transactionId: 'txn-0');
        service.rememberIncomingRequest(oldest);
        for (var i = 1; i <= 16; i++) {
          service.rememberIncomingRequest(ceremony(transactionId: 'txn-$i'));
        }

        await service.acceptVerification('txn-0');
        await service.acceptVerification('txn-16');

        verifyNever(oldest.acceptVerification);
      });
    });

    test('acceptEmojiVerification confirms the SAS of the runner with that id '
        'and nothing else', () async {
      final service = createService();
      final outgoing = ceremony(transactionId: 'txn-out');
      final incoming = ceremony(transactionId: 'txn-in');
      attachOutgoing(service, outgoing);
      attachIncoming(service, incoming);

      await service.acceptEmojiVerification('txn-in');
      await service.acceptEmojiVerification('nobody');

      verify(incoming.acceptSas).called(1);
      verifyNever(outgoing.acceptSas);
    });

    group('cancelVerification', () {
      test('cancels a live runner by id', () async {
        final service = createService();
        final kv = ceremony(transactionId: 'txn-out');
        attachOutgoing(service, kv);

        await service.cancelVerification('txn-out');

        verify(kv.cancel).called(1);
      });

      test('leaves a finished runner alone', () async {
        final service = createService();
        final kv = ceremony(
          transactionId: 'txn-out',
          lastStep: 'm.key.verification.done',
        );
        when(() => kv.isDone).thenReturn(true);
        attachOutgoing(service, kv);

        await service.cancelVerification('txn-out');

        verifyNever(kv.cancel);
      });

      test('cancels a remembered request that was never answered', () async {
        final service = createService();
        final request = ceremony(transactionId: 'txn-req');
        service.rememberIncomingRequest(request);

        await service.cancelVerification('txn-req');

        verify(request.cancel).called(1);
      });

      test('leaves a finished request alone and ignores unknown ids', () async {
        final service = createService();
        final request = ceremony(transactionId: 'txn-req');
        when(() => request.isDone).thenReturn(true);
        service.rememberIncomingRequest(request);

        await service.cancelVerification('txn-req');
        await service.cancelVerification('nobody');

        verifyNever(request.cancel);
      });

      test('logs a cancel the SDK refuses instead of throwing', () async {
        final service = createService();
        final request = ceremony(transactionId: 'txn-req');
        when(request.cancel).thenThrow(StateError('gone'));
        service.rememberIncomingRequest(request);

        await expectLater(service.cancelVerification('txn-req'), completes);

        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'verification.cancelRequest',
          ),
        ).called(1);
      });
    });

    group('handOffOutgoingVerificationTo', () {
      test("withdraws the own ceremony, continues the peer's on the outgoing "
          'stream and answers it', () async {
        final service = createService();
        final own = ceremony(transactionId: 'txn-own');
        final ownRunner = attachOutgoing(service, own);
        final peer = ceremony(transactionId: 'txn-peer', deviceId: 'AAA');
        service.rememberIncomingRequest(peer);
        final published = <SyncVerificationState>[];
        final sub = service.outgoingVerifications.listen(published.add);
        addTearDown(sub.cancel);

        await service.handOffOutgoingVerificationTo('txn-peer');
        await pumpEventQueue();

        verify(own.cancel).called(1);
        verify(peer.acceptVerification).called(1);
        final handedOff = service.keyVerificationRunner!;
        addTearDown(handedOff.stopTimer);
        expect(handedOff, isNot(same(ownRunner)));
        expect(handedOff.keyVerification, same(peer));
        expect(handedOff.direction, SyncVerificationDirection.outgoing);
        expect(service.outgoingVerification?.id, 'txn-peer');
        expect(published.map((s) => s.id), contains('txn-peer'));
        // Detached before the cancel: the withdrawn runner never published
        // its cancelled state onto the sheet's stream.
        expect(
          published.where((s) => s.id == 'txn-own'),
          everyElement(
            isA<SyncVerificationState>().having(
              (s) => s.outcome,
              'outcome',
              KeyVerificationOutcome.pending,
            ),
          ),
        );
      });

      test(
        "with no ceremony of its own it simply answers the peer's",
        () async {
          final service = createService();
          final peer = ceremony(transactionId: 'txn-peer');
          attachIncoming(service, peer);

          await service.handOffOutgoingVerificationTo('txn-peer');

          verify(peer.acceptVerification).called(1);
          final handedOff = service.keyVerificationRunner!;
          addTearDown(handedOff.stopTimer);
          expect(handedOff.keyVerification, same(peer));
        },
      );

      test('a handed-off ceremony that completes refreshes device trust like '
          'any other', () async {
        final service = createService();
        when(() => sessionManager.isLoggedIn()).thenReturn(false);
        final peer = ceremony(transactionId: 'txn-peer');
        service.rememberIncomingRequest(peer);

        await service.handOffOutgoingVerificationTo('txn-peer');
        addTearDown(service.keyVerificationRunner!.stopTimer);
        // The runner hooks the SDK's onUpdate; drive it as the SDK would.
        final onUpdate =
            verify(() => peer.onUpdate = captureAny()).captured.last
                as void Function();
        when(() => peer.lastStep).thenReturn('m.key.verification.done');
        when(() => peer.state).thenReturn(KeyVerificationState.done);
        when(() => peer.isDone).thenReturn(true);

        onUpdate();
        await pumpEventQueue();

        expect(
          service.outgoingVerification?.outcome,
          KeyVerificationOutcome.success,
        );
        verify(
          () => loggingService.log(
            LogDomain.sync,
            any<String>(that: startsWith('verification.completed')),
            subDomain: 'verification',
          ),
        ).called(1);
      });

      test('a cancel the SDK refuses is logged and the hand-off still '
          'completes', () async {
        final service = createService();
        final own = ceremony(transactionId: 'txn-own');
        when(own.cancel).thenThrow(StateError('offline'));
        attachOutgoing(service, own);
        final peer = ceremony(transactionId: 'txn-peer', deviceId: 'AAA');
        service.rememberIncomingRequest(peer);

        await service.handOffOutgoingVerificationTo('txn-peer');
        addTearDown(service.keyVerificationRunner!.stopTimer);

        verify(peer.acceptVerification).called(1);
        expect(service.outgoingVerification?.id, 'txn-peer');
        verify(
          () => loggingService.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'verification.handOff.cancel',
          ),
        ).called(1);
      });

      test('refuses an id it does not know', () async {
        final service = createService();

        await expectLater(
          service.handOffOutgoingVerificationTo('nobody'),
          throwsStateError,
        );
      });
    });

    test('loginStateChanges maps every SDK login state', () async {
      final service = createService();
      final sdkStates = CachedStreamController<LoginState>();
      when(() => client.onLoginStateChanged).thenReturn(sdkStates);

      final mapped = service.loginStateChanges.take(3).toList();
      sdkStates
        ..add(LoginState.loggedIn)
        ..add(LoginState.softLoggedOut)
        ..add(LoginState.loggedOut);

      expect(await mapped, [
        SyncLoginState.loggedIn,
        SyncLoginState.softLoggedOut,
        SyncLoginState.loggedOut,
      ]);
    });

    test('homeserverHost is the host of the resolved homeserver, or null', () {
      final service = createService();

      when(() => client.homeserver).thenReturn(null);
      expect(service.homeserverHost, isNull);

      when(
        () => client.homeserver,
      ).thenReturn(Uri.parse('https://matrix.example.com:8448'));
      expect(service.homeserverHost, 'matrix.example.com');
    });

    test('stats is the message-count stream and inboundQueue the '
        "coordinator's queue", () async {
      final queue = MockInboundQueue();
      when(() => queueCoordinator.queue).thenReturn(queue);
      final service = createService();

      final next = service.stats.first;
      service.incrementSentCountOf('journalEntity');

      expect((await next).sentCount, 1);
      expect(service.inboundQueue, same(queue));
    });

    group('deleteDeviceById error mapping', () {
      setUp(() {
        when(() => client.userID).thenReturn('@me:server');
        when(() => gateway.currentDeviceId).thenReturn('THIS_DEVICE');
        when(() => sessionManager.matrixConfig).thenReturn(
          const MatrixConfig(
            homeServer: 'https://hs',
            user: '@me:server',
            password: 'secret',
          ),
        );
      });

      test(
        'a refused credential surfaces as SyncReauthRequiredException',
        () async {
          when(
            () => gateway.deleteDevice(any(), auth: any(named: 'auth')),
          ).thenThrow(
            MatrixException.fromJson(
              const {'errcode': 'M_FORBIDDEN', 'error': 'Invalid password'},
            ),
          );

          await expectLater(
            createService().deleteDeviceById('OTHER'),
            throwsA(
              isA<SyncReauthRequiredException>().having(
                (e) => e.toString(),
                'toString',
                allOf(
                  startsWith('SyncReauthRequiredException:'),
                  contains('Invalid password'),
                ),
              ),
            ),
          );
        },
      );

      test('any other homeserver error passes through unchanged', () async {
        when(
          () => gateway.deleteDevice(any(), auth: any(named: 'auth')),
        ).thenThrow(
          MatrixException.fromJson(
            const {'errcode': 'M_LIMIT_EXCEEDED', 'error': 'Too many'},
          ),
        );

        await expectLater(
          createService().deleteDeviceById('OTHER'),
          throwsA(
            isA<MatrixException>().having(
              (e) => e.errcode,
              'errcode',
              'M_LIMIT_EXCEEDED',
            ),
          ),
        );
      });
    });

    test('verifyDevice refuses a device without published keys', () async {
      when(() => client.userDeviceKeys).thenReturn({});

      await expectLater(
        createService().verifyDevice(
          userId: '@alice:example.com',
          deviceId: 'KEYLESS',
        ),
        throwsStateError,
      );
    });
  });
}
