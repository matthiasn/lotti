// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
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
  late AttachmentIndex attachmentIndex;
  late _MockClient client;

  /// Creates a [MatrixService] with all mocks wired up.
  ///
  /// This is synchronous — callers running inside `fakeAsync` must
  /// `async.elapse(...)` and `clearInteractions(pipeline)` themselves
  /// so the eager `forceRescan` task completes before assertions.
  MatrixService createService({
    bool collectMetrics = true,
    Stream<List<ConnectivityResult>>? connectivity,
    Map<String, int> metricsSnapshot = const {'dbApplied': 4},
    Map<String, String> diagnostics = const {'nextRetry': 'soon'},
    QueuePipelineCoordinator? queueCoordinator,
    bool suppressLegacyPipeline = false,
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

    when(() => eventProcessor.applyObserver = any()).thenReturn(null);
    when(() => messageSender.sentEventRegistry).thenReturn(SentEventRegistry());
    when(() => sessionManager.client).thenReturn(client);
    when(() => sessionManager.dispose()).thenAnswer((_) async {});
    when(() => roomManager.saveRoomId(any())).thenAnswer((_) async {});
    when(() => roomManager.dispose()).thenAnswer((_) async {});
    when(() => activityGate.dispose()).thenAnswer((_) async {});

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
      collectSyncMetrics: collectMetrics,
      roomManager: roomManager,
      sessionManager: sessionManager,
      pipelineOverride: pipeline,
      attachmentIndex: attachmentIndex,
      connectivityStream: connectivityStream,
      queueCoordinator: queueCoordinator,
      suppressLegacyPipeline: suppressLegacyPipeline,
    );
  }

  /// Elapses fake time past the eager `forceRescan` that fires on
  /// construction, then clears all recorded interactions so tests
  /// start with a clean slate.
  void settleServiceStartup(FakeAsync async) {
    async.elapse(const Duration(milliseconds: 350));
    clearInteractions(pipeline);
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

  test('getV2Metrics returns null when metrics collection disabled', () {
    fakeAsync((async) {
      final service = createService(collectMetrics: false);
      settleServiceStartup(async);

      unawaited(
        service.getSyncMetrics().then((metrics) {
          expect(metrics, isNull);
        }),
      );
      async.flushMicrotasks();
    });
  });

  test('getV2Metrics returns metrics when collection enabled', () {
    fakeAsync((async) {
      final service = createService(
        metricsSnapshot: const {'dbApplied': 7, 'failures': 0},
      );
      settleServiceStartup(async);

      unawaited(
        service.getSyncMetrics().then((metrics) {
          expect(metrics, isA<SyncMetrics>());
          expect(metrics?.dbApplied, 7);
        }),
      );
      async.flushMicrotasks();
    });
  });

  test('forceV2Rescan forwards includeCatchUp flag to pipeline', () {
    fakeAsync((async) {
      final service = createService();
      settleServiceStartup(async);

      unawaited(service.forceRescan(includeCatchUp: false));
      async.flushMicrotasks();

      verify(() => pipeline.forceRescan(includeCatchUp: false)).called(1);
    });
  });

  test('retryV2Now triggers pipeline retry', () {
    fakeAsync((async) {
      final service = createService();
      settleServiceStartup(async);

      unawaited(service.retryNow());
      async.flushMicrotasks();

      verify(() => pipeline.retryNow()).called(1);
    });
  });

  test('saveRoom bootstraps pipeline start + catch-up in background', () {
    fakeAsync((async) {
      final service = createService();
      settleServiceStartup(async);

      unawaited(service.saveRoom('!room:server'));
      async.elapse(const Duration(milliseconds: 10));

      verify(() => roomManager.saveRoomId('!room:server')).called(1);
      verify(() => pipeline.start()).called(1);
      verify(() => pipeline.forceRescan(includeCatchUp: true)).called(1);
    });
  });

  test(
    'connectivity change calls recordConnectivitySignal before forceRescan',
    () {
      fakeAsync((async) {
        final connectivityController =
            StreamController<List<ConnectivityResult>>.broadcast();
        addTearDown(connectivityController.close);

        final service = createService(
          connectivity: connectivityController.stream,
        );
        settleServiceStartup(async);

        // Stub methods to track ordering
        when(() => pipeline.recordConnectivitySignal()).thenReturn(null);
        when(
          () => pipeline.forceRescan(
            includeCatchUp: any(named: 'includeCatchUp'),
          ),
        ).thenAnswer((_) async {});

        // First emission is the synthetic bootstrap snapshot from
        // `connectivity_plus`. The service records the connectivity signal
        // (metrics) but intentionally swallows the `forceRescan` so it does
        // not duplicate the dedicated startup rescan.
        connectivityController.add([ConnectivityResult.wifi]);
        async.elapse(const Duration(milliseconds: 10));

        verify(() => pipeline.recordConnectivitySignal()).called(1);
        verifyNever(
          () => pipeline.forceRescan(
            includeCatchUp: any(named: 'includeCatchUp'),
          ),
        );

        // Reset interactions so the follow-up `verifyInOrder` only sees the
        // calls caused by the second (genuine) regain event.
        clearInteractions(pipeline);

        // Second emission represents a genuine regain event; it must record
        // the signal and then drive forceRescan, in that order.
        connectivityController.add([ConnectivityResult.wifi]);
        async.elapse(const Duration(milliseconds: 10));

        verifyInOrder([
          () => pipeline.recordConnectivitySignal(),
          () => pipeline.forceRescan(includeCatchUp: true),
        ]);

        // Clean up
        unawaited(service.dispose());
        async.flushMicrotasks();
      });
    },
  );

  test('getSyncDiagnosticsText joins metrics and diagnostics strings', () {
    fakeAsync((async) {
      final service = createService(
        metricsSnapshot: const {'dbApplied': 3, 'failures': 1},
        diagnostics: const {'nextRetry': '42s'},
      );
      settleServiceStartup(async);

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

  test('dispose releases owned dependencies', () async {
    late MatrixService service;
    fakeAsync((async) {
      service = createService();
      settleServiceStartup(async);
    });

    await service.dispose();

    verify(() => sessionManager.dispose()).called(1);
    verify(() => roomManager.dispose()).called(1);
  });

  group('queue pipeline flag', () {
    test(
      'init starts the coordinator when the flag is on',
      () async {
        final coordinator = _MockQueuePipelineCoordinator();
        when(coordinator.start).thenAnswer((_) async {});
        when(() => coordinator.isRunning).thenReturn(true);
        when(
          () => coordinator.stop(drainFirst: any(named: 'drainFirst')),
        ).thenAnswer((_) async {});
        when(
          () => settingsDb.itemByKey(useInboundEventQueueKey),
        ).thenAnswer((_) async => 'true');

        final service = createService(
          queueCoordinator: coordinator,
          suppressLegacyPipeline: true,
        );

        // Short-circuit the rest of init: we don't want loadConfig /
        // connect to run their full flows, but we do want
        // _maybeStartQueuePipeline to fire. Call it directly via the
        // visible hook instead of init().
        await service.debugMaybeStartQueuePipelineForTest();

        verify(coordinator.start).called(1);
      },
    );

    test(
      'init does not start the coordinator when the flag is off',
      () async {
        final coordinator = _MockQueuePipelineCoordinator();
        when(coordinator.start).thenAnswer((_) async {});
        when(() => coordinator.isRunning).thenReturn(false);
        when(
          () => coordinator.stop(drainFirst: any(named: 'drainFirst')),
        ).thenAnswer((_) async {});
        when(
          () => settingsDb.itemByKey(useInboundEventQueueKey),
        ).thenAnswer((_) async => 'false');

        final service = createService(queueCoordinator: coordinator);
        await service.debugMaybeStartQueuePipelineForTest();

        verifyNever(coordinator.start);
      },
    );

    test(
      'dispose drains the coordinator first (F7)',
      () async {
        final coordinator = _MockQueuePipelineCoordinator();
        when(coordinator.start).thenAnswer((_) async {});
        when(() => coordinator.isRunning).thenReturn(true);
        when(
          () => coordinator.stop(drainFirst: any(named: 'drainFirst')),
        ).thenAnswer((_) async {});

        late MatrixService service;
        fakeAsync((async) {
          service = createService(
            queueCoordinator: coordinator,
            suppressLegacyPipeline: true,
          );
          settleServiceStartup(async);
        });

        await service.dispose();
        verify(() => coordinator.stop(drainFirst: true)).called(1);
      },
    );

    test(
      'isLegacyPipelineSuppressed mirrors the constructor argument',
      () {
        fakeAsync((async) {
          final service = createService(suppressLegacyPipeline: true);
          settleServiceStartup(async);
          expect(service.isLegacyPipelineSuppressed, isTrue);

          final other = createService();
          settleServiceStartup(async);
          expect(other.isLegacyPipelineSuppressed, isFalse);
        });
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
      settleServiceStartup(async);

      unawaited(
        service.discoverExistingSyncRooms().then((result) {
          expect(result, equals(candidates));
        }),
      );
      async.flushMicrotasks();

      verify(() => roomManager.discoverExistingSyncRooms()).called(1);
    });
  });
}
