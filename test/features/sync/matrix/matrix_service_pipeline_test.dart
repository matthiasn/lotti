import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_consumer.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_metrics.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_discovery.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _MockMatrixSyncGateway extends Mock implements MatrixSyncGateway {}

class _MockSyncRoomManager extends Mock implements SyncRoomManager {}

class _MockMatrixSessionManager extends Mock implements MatrixSessionManager {}

class _MockJournalDb extends Mock implements JournalDb {}

class _MockSettingsDb extends Mock implements SettingsDb {}

class _MockSyncReadMarkerService extends Mock
    implements SyncReadMarkerService {}

class _MockSyncEventProcessor extends Mock implements SyncEventProcessor {}

class _MockSecureStorage extends Mock implements SecureStorage {}

class _MockMatrixMessageSender extends Mock implements MatrixMessageSender {}

class _MockUserActivityGate extends Mock implements UserActivityGate {}

class _MockMatrixStreamConsumer extends Mock implements MatrixStreamConsumer {}

class _MockQueuePipelineCoordinator extends Mock
    implements QueuePipelineCoordinator {}

class _MockInboundQueue extends Mock implements InboundQueue {}

class _MockClient extends Mock implements Client {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(<ConnectivityResult>[]);
    registerFallbackValue(SentEventRegistry());
    registerFallbackValue(Duration.zero);
    registerFallbackValue(
      SyncApplyDiagnostics(
        eventId: 'event',
        payloadType: 'type',
        vectorClock: null,
        conflictStatus: 'none',
        applied: true,
      ),
    );
  });

  late _MockMatrixSyncGateway gateway;
  late MockLoggingService logging;
  late _MockJournalDb journalDb;
  late _MockSettingsDb settingsDb;
  late _MockSyncReadMarkerService readMarkerService;
  late _MockSyncEventProcessor eventProcessor;
  late _MockSecureStorage secureStorage;
  late _MockMatrixMessageSender messageSender;
  late _MockSyncRoomManager roomManager;
  late _MockMatrixSessionManager sessionManager;
  late _MockUserActivityGate activityGate;
  late _MockMatrixStreamConsumer pipeline;
  late _MockQueuePipelineCoordinator coordinator;
  late AttachmentIndex attachmentIndex;
  late _MockClient client;

  _MockQueuePipelineCoordinator buildDefaultCoordinator() {
    final c = _MockQueuePipelineCoordinator();
    when(c.start).thenAnswer((_) async {});
    when(() => c.isRunning).thenReturn(false);
    when(
      () => c.stop(drainFirst: any(named: 'drainFirst')),
    ).thenAnswer((_) async {});
    when(c.triggerBridge).thenAnswer((_) async {});
    when(() => c.onRoomChanged(any())).thenAnswer((_) async {});
    return c;
  }

  /// Creates a [MatrixService] with all mocks wired up.
  MatrixService createService({
    bool collectMetrics = true,
    Stream<List<ConnectivityResult>>? connectivity,
    Map<String, int> metricsSnapshot = const {'dbApplied': 4},
    Map<String, String> diagnostics = const {'nextRetry': 'soon'},
    _MockQueuePipelineCoordinator? queueCoordinator,
  }) {
    final connectivityStream =
        connectivity ?? const Stream<List<ConnectivityResult>>.empty();

    when(() => pipeline.reportDbApplyDiagnostics(any())).thenReturn(null);
    when(() => pipeline.start()).thenAnswer((_) async {});
    when(
      () => pipeline.forceRescan(includeCatchUp: any(named: 'includeCatchUp')),
    ).thenAnswer((_) async {});
    when(() => pipeline.retryNow()).thenAnswer((_) async {});
    when(() => pipeline.metricsSnapshot()).thenReturn(metricsSnapshot);
    when(() => pipeline.diagnosticsStrings()).thenReturn(diagnostics);
    when(() => pipeline.recordConnectivitySignal()).thenReturn(null);

    when(() => eventProcessor.applyObserver = any()).thenReturn(null);
    when(() => messageSender.sentEventRegistry).thenReturn(SentEventRegistry());
    when(() => sessionManager.client).thenReturn(client);
    when(() => sessionManager.dispose()).thenAnswer((_) async {});
    when(() => roomManager.saveRoomId(any())).thenAnswer((_) async {});
    when(() => roomManager.dispose()).thenAnswer((_) async {});
    when(() => activityGate.dispose()).thenAnswer((_) async {});

    coordinator = queueCoordinator ?? buildDefaultCoordinator();

    return MatrixService(
      gateway: gateway,
      loggingService: logging,
      activityGate: activityGate,
      messageSender: messageSender,
      journalDb: journalDb,
      settingsDb: settingsDb,
      readMarkerService: readMarkerService,
      eventProcessor: eventProcessor,
      secureStorage: secureStorage,
      queueCoordinator: coordinator,
      collectSyncMetrics: collectMetrics,
      roomManager: roomManager,
      sessionManager: sessionManager,
      pipelineOverride: pipeline,
      attachmentIndex: attachmentIndex,
      connectivityStream: connectivityStream,
    );
  }

  setUp(() {
    gateway = _MockMatrixSyncGateway();
    logging = MockLoggingService();
    journalDb = _MockJournalDb();
    settingsDb = _MockSettingsDb();
    readMarkerService = _MockSyncReadMarkerService();
    eventProcessor = _MockSyncEventProcessor();
    secureStorage = _MockSecureStorage();
    messageSender = _MockMatrixMessageSender();
    roomManager = _MockSyncRoomManager();
    sessionManager = _MockMatrixSessionManager();
    activityGate = _MockUserActivityGate();
    pipeline = _MockMatrixStreamConsumer();
    attachmentIndex = AttachmentIndex(logging: logging);
    client = _MockClient();
  });

  test('getSyncMetrics returns null when metrics collection disabled', () {
    fakeAsync((async) {
      final service = createService(collectMetrics: false);
      unawaited(
        service.getSyncMetrics().then((metrics) {
          expect(metrics, isNull);
        }),
      );
      async.flushMicrotasks();
    });
  });

  test('getSyncMetrics returns metrics when collection enabled', () {
    fakeAsync((async) {
      final service = createService(
        metricsSnapshot: const {'dbApplied': 7, 'failures': 0},
      );
      unawaited(
        service.getSyncMetrics().then((metrics) {
          expect(metrics, isA<SyncMetrics>());
          expect(metrics?.dbApplied, 7);
        }),
      );
      async.flushMicrotasks();
    });
  });

  test(
    'forceRescan(includeCatchUp: true) routes to the queue coordinator '
    'and never touches the stream-consumer pipeline',
    () async {
      final service = createService();

      await service.forceRescan();

      verify(coordinator.triggerBridge).called(1);
      verifyNever(
        () => pipeline.forceRescan(
          includeCatchUp: any(named: 'includeCatchUp'),
        ),
      );
    },
  );

  test(
    'forceRescan(includeCatchUp: false) is a no-op — live-only rescans '
    "have no meaning now that the consumer's live ingestion is suppressed",
    () async {
      final service = createService();

      await service.forceRescan(includeCatchUp: false);

      verifyNever(coordinator.triggerBridge);
      verifyNever(
        () => pipeline.forceRescan(
          includeCatchUp: any(named: 'includeCatchUp'),
        ),
      );
    },
  );

  test(
    'forceRescan swallows triggerBridge failure and logs it so a '
    'transient bridge error does not bubble out of the service API',
    () async {
      final coord = buildDefaultCoordinator();
      when(coord.triggerBridge).thenThrow(StateError('bridge down'));
      final service = createService(queueCoordinator: coord);

      await service.forceRescan();

      verify(
        () => logging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: 'forceRescan.triggerBridge',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
    },
  );

  test('retryNow triggers pipeline retry', () {
    fakeAsync((async) {
      final service = createService();
      unawaited(service.retryNow());
      async.flushMicrotasks();

      verify(() => pipeline.retryNow()).called(1);
    });
  });

  test(
    'saveRoom restarts the pipeline and drives catch-up via '
    'onRoomChanged + triggerBridge on the coordinator',
    () {
      fakeAsync((async) {
        final service = createService();
        unawaited(service.saveRoom('!room:server'));
        async.elapse(const Duration(milliseconds: 10));

        verify(() => roomManager.saveRoomId('!room:server')).called(1);
        verify(() => pipeline.start()).called(1);
        verifyInOrder([
          () => coordinator.onRoomChanged('!room:server'),
          coordinator.triggerBridge,
        ]);
        verifyNever(
          () => pipeline.forceRescan(
            includeCatchUp: any(named: 'includeCatchUp'),
          ),
        );
      });
    },
  );

  test(
    'connectivity regain records a diagnostic signal on the pipeline — '
    "catch-up itself is the coordinator's job, not the service's",
    () {
      fakeAsync((async) {
        final connectivityController =
            StreamController<List<ConnectivityResult>>.broadcast();
        addTearDown(connectivityController.close);

        final service = createService(
          connectivity: connectivityController.stream,
        );

        connectivityController.add([ConnectivityResult.wifi]);
        async.elapse(const Duration(milliseconds: 10));

        verify(() => pipeline.recordConnectivitySignal()).called(1);
        verifyNever(
          () => pipeline.forceRescan(
            includeCatchUp: any(named: 'includeCatchUp'),
          ),
        );

        unawaited(service.dispose());
        async.flushMicrotasks();
      });
    },
  );

  test(
    'connectivity result without a network type (e.g. none) does not '
    'emit a signal',
    () {
      fakeAsync((async) {
        final connectivityController =
            StreamController<List<ConnectivityResult>>.broadcast();
        addTearDown(connectivityController.close);

        createService(connectivity: connectivityController.stream);

        connectivityController.add([ConnectivityResult.none]);
        async.elapse(const Duration(milliseconds: 10));

        verifyNever(() => pipeline.recordConnectivitySignal());
      });
    },
  );

  test('getSyncDiagnosticsText joins metrics and diagnostics strings', () {
    fakeAsync((async) {
      final service = createService(
        metricsSnapshot: const {'dbApplied': 3, 'failures': 1},
        diagnostics: const {'nextRetry': '42s'},
      );
      unawaited(
        service.getSyncDiagnosticsText().then((text) {
          expect(text, contains('dbApplied=3'));
          expect(text, contains('failures=1'));
          expect(text, contains('nextRetry=42s'));
        }),
      );
      async.flushMicrotasks();
    });
  });

  test(
    'dispose releases owned dependencies and drains the coordinator',
    () async {
      final coord = buildDefaultCoordinator();
      when(() => coord.isRunning).thenReturn(true);
      final service = createService(queueCoordinator: coord);

      await service.dispose();

      verify(() => coord.stop(drainFirst: true)).called(1);
      verify(() => sessionManager.dispose()).called(1);
      verify(() => roomManager.dispose()).called(1);
    },
  );

  test(
    'dispose logs and continues when coordinator.stop throws — a drain '
    'failure must not prevent the rest of shutdown from running',
    () async {
      final coord = buildDefaultCoordinator();
      when(() => coord.isRunning).thenReturn(true);
      when(
        () => coord.stop(drainFirst: any(named: 'drainFirst')),
      ).thenThrow(StateError('drain failed'));
      final service = createService(queueCoordinator: coord);

      await service.dispose();

      verify(
        () => logging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: 'queue.dispose',
          stackTrace: any<StackTrace>(named: 'stackTrace'),
        ),
      ).called(1);
      verify(() => sessionManager.dispose()).called(1);
      verify(() => roomManager.dispose()).called(1);
    },
  );

  group('queue pipeline startup', () {
    test(
      'debugStartQueuePipelineForTest starts the coordinator',
      () async {
        final service = createService();

        await service.debugStartQueuePipelineForTest();

        verify(coordinator.start).called(1);
      },
    );

    test(
      'rethrows when coordinator.start fails — queue is the only '
      'inbound path, so a start failure must surface, not be swallowed',
      () async {
        final coord = buildDefaultCoordinator();
        when(coord.start).thenThrow(StateError('boom'));
        final service = createService(queueCoordinator: coord);

        await expectLater(
          service.debugStartQueuePipelineForTest(),
          throwsA(isA<StateError>()),
        );
        verify(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: 'queue.init',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      },
    );
  });

  test('discoverExistingSyncRooms delegates to room manager', () {
    final candidates = [
      const SyncRoomCandidate(
        roomId: '!room1:server',
        roomName: 'Sync Room',
        createdAt: null,
        memberCount: 2,
        hasStateMarker: true,
        hasLottiContent: true,
      ),
    ];

    when(
      () => roomManager.discoverExistingSyncRooms(),
    ).thenAnswer((_) async => candidates);

    fakeAsync((async) {
      final service = createService();

      unawaited(
        service.discoverExistingSyncRooms().then((result) {
          expect(result, equals(candidates));
        }),
      );
      async.flushMicrotasks();

      verify(() => roomManager.discoverExistingSyncRooms()).called(1);
    });
  });

  group('getSyncMetrics queue overlay', () {
    test(
      'when the queue coordinator is running, queueActive / queueApplied '
      '/ queueAbandoned / queueRetrying are overlaid on top of the '
      'pipeline snapshot so the Matrix Stats UI surfaces ledger state',
      () async {
        final coord = buildDefaultCoordinator();
        final queue = _MockInboundQueue();
        when(() => coord.isRunning).thenReturn(true);
        when(() => coord.queue).thenReturn(queue);
        when(queue.stats).thenAnswer(
          (_) async => const QueueStats(
            total: 7,
            byProducer: {InboundEventProducer.live: 7},
            readyNow: 7,
            oldestEnqueuedAt: 1,
            applied: 42,
            abandoned: 3,
            retrying: 2,
          ),
        );

        final service = createService(
          metricsSnapshot: const {'dbApplied': 11, 'failures': 0},
          queueCoordinator: coord,
        );

        final metrics = await service.getSyncMetrics();
        expect(metrics, isNotNull);
        final map = metrics!.toMap();
        expect(map['queueActive'], 7);
        expect(map['queueApplied'], 42);
        expect(map['queueAbandoned'], 3);
        expect(map['queueRetrying'], 2);
        // Consumer counters still flow through — the overlay augments.
        expect(map['dbApplied'], 11);
      },
    );

    test(
      'when queue.stats() throws, the overlay is silently skipped and '
      'the consumer snapshot still returns — a transient sync_db error '
      'must not hide the consumer counters',
      () async {
        final coord = buildDefaultCoordinator();
        final queue = _MockInboundQueue();
        when(() => coord.isRunning).thenReturn(true);
        when(() => coord.queue).thenReturn(queue);
        when(queue.stats).thenThrow(StateError('db locked'));

        final service = createService(
          metricsSnapshot: const {'dbApplied': 5},
          queueCoordinator: coord,
        );

        final metrics = await service.getSyncMetrics();
        expect(metrics, isNotNull);
        final map = metrics!.toMap();
        expect(map['dbApplied'], 5);
        expect(map['queueActive'], 0);
        expect(map['queueApplied'], 0);
        verify(
          () => logging.captureException(
            any<Object>(),
            domain: any<String>(named: 'domain'),
            subDomain: 'metrics.queueStats',
            stackTrace: any<StackTrace>(named: 'stackTrace'),
          ),
        ).called(1);
      },
    );

    test(
      'when the queue coordinator is not running, the overlay is '
      'skipped entirely — never calling queue.stats() avoids a '
      'spurious db read',
      () async {
        final coord = buildDefaultCoordinator();
        final queue = _MockInboundQueue();
        when(() => coord.isRunning).thenReturn(false);
        when(() => coord.queue).thenReturn(queue);

        final service = createService(
          metricsSnapshot: const {'dbApplied': 3},
          queueCoordinator: coord,
        );

        final metrics = await service.getSyncMetrics();
        expect(metrics, isNotNull);
        verifyNever(queue.stats);
      },
    );
  });
}
