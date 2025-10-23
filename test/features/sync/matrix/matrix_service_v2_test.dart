// ignore_for_file: unnecessary_lambdas

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/matrix_message_sender.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/matrix_timeline_listener.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/matrix_stream_consumer.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/v2_metrics.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_lifecycle_coordinator.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class MockMatrixSyncGateway extends Mock implements MatrixSyncGateway {}

class MockSyncRoomManager extends Mock implements SyncRoomManager {}

class MockMatrixSessionManager extends Mock implements MatrixSessionManager {}

class MockMatrixTimelineListener extends Mock
    implements MatrixTimelineListener {}

class MockLoggingService extends Mock implements LoggingService {}

class MockClient extends Mock implements Client {}

class MockSettingsDb extends Mock implements SettingsDb {}

class MockJournalDb extends Mock implements JournalDb {}

class MockSyncReadMarkerService extends Mock implements SyncReadMarkerService {}

class MockSyncEventProcessor extends Mock implements SyncEventProcessor {}

class MockSecureStorage extends Mock implements SecureStorage {}

class MockSyncLifecycleCoordinator extends Mock
    implements SyncLifecycleCoordinator {}

class MockMatrixMessageSender extends Mock implements MatrixMessageSender {}

MockMatrixMessageSender createMockMessageSender() {
  final sender = MockMatrixMessageSender();
  when(() => sender.sentEventRegistry).thenReturn(SentEventRegistry());
  return sender;
}

class _TestV2Pipeline2 extends MatrixStreamConsumer {
  _TestV2Pipeline2({
    required super.sessionManager,
    required super.roomManager,
    required super.loggingService,
    required super.journalDb,
    required super.settingsDb,
    required super.eventProcessor,
    required super.readMarkerService,
    required super.documentsDirectory,
  }) : super(collectMetrics: true);

  Map<String, int>? testMetrics;
  Future<void> Function({required bool includeCatchUp})? onForceRescan;

  @override
  Map<String, int> metricsSnapshot() => testMetrics ?? super.metricsSnapshot();

  @override
  Future<void> forceRescan({bool includeCatchUp = true}) async {
    if (onForceRescan != null) {
      await onForceRescan!(includeCatchUp: includeCatchUp);
      return;
    }
    await super.forceRescan(includeCatchUp: includeCatchUp);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  MatrixService makeService({required bool enableV2}) {
    final gateway = MockMatrixSyncGateway();
    final logging = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final readMarker = MockSyncReadMarkerService();
    final processor = MockSyncEventProcessor();
    final storage = MockSecureStorage();
    final sessionManager = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final timelineListener = MockMatrixTimelineListener();
    final lifecycleCoordinator = MockSyncLifecycleCoordinator();
    final client = MockClient();

    when(() => sessionManager.client).thenReturn(client);
    // No need to stub onLoginStateChanged for these tests.
    when(() => sessionManager.isLoggedIn()).thenReturn(false);
    when(() => lifecycleCoordinator.isActive).thenReturn(false);
    when(() => lifecycleCoordinator.updateHooks(
          onLogin: any(named: 'onLogin'),
          onLogout: any(named: 'onLogout'),
        )).thenReturn(null);
    when(() => lifecycleCoordinator.initialize()).thenAnswer((_) async {});
    when(() => lifecycleCoordinator.reconcileLifecycleState())
        .thenAnswer((_) async {});
    when(() => lifecycleCoordinator.dispose()).thenAnswer((_) async {});
    when(() => timelineListener.dispose()).thenAnswer((_) async {});
    when(() => sessionManager.dispose()).thenAnswer((_) async {});
    when(() => roomManager.dispose()).thenAnswer((_) async {});
    when(() => lifecycleCoordinator.dispose()).thenAnswer((_) async {});
    when(() => timelineListener.dispose()).thenAnswer((_) async {});
    when(() => sessionManager.dispose()).thenAnswer((_) async {});
    when(() => roomManager.dispose()).thenAnswer((_) async {});
    when(() => lifecycleCoordinator.dispose()).thenAnswer((_) async {});
    when(() => timelineListener.dispose()).thenAnswer((_) async {});
    when(() => sessionManager.dispose()).thenAnswer((_) async {});
    when(() => roomManager.dispose()).thenAnswer((_) async {});
    when(() => lifecycleCoordinator.dispose()).thenAnswer((_) async {});
    when(() => timelineListener.dispose()).thenAnswer((_) async {});
    when(() => sessionManager.dispose()).thenAnswer((_) async {});
    when(() => roomManager.dispose()).thenAnswer((_) async {});
    when(() => lifecycleCoordinator.dispose()).thenAnswer((_) async {});
    when(() => timelineListener.dispose()).thenAnswer((_) async {});
    when(() => sessionManager.dispose()).thenAnswer((_) async {});
    when(() => roomManager.dispose()).thenAnswer((_) async {});
    when(() => lifecycleCoordinator.dispose()).thenAnswer((_) async {});
    when(() => timelineListener.dispose()).thenAnswer((_) async {});
    when(() => sessionManager.dispose()).thenAnswer((_) async {});
    when(() => roomManager.dispose()).thenAnswer((_) async {});

    return MatrixService(
      gateway: gateway,
      loggingService: logging,
      activityGate: TestUserActivityGate(TestUserActivityService()),
      messageSender: createMockMessageSender(),
      journalDb: journalDb,
      settingsDb: settingsDb,
      readMarkerService: readMarker,
      eventProcessor: processor,
      secureStorage: storage,
      documentsDirectory: Directory.systemTemp,
      enableSyncV2: enableV2,
      collectV2Metrics: true,
      roomManager: roomManager,
      sessionManager: sessionManager,
      timelineListener: timelineListener,
      lifecycleCoordinator: lifecycleCoordinator,
      attachmentIndex: AttachmentIndex(logging: logging),
    );
  }

  test('getV2Metrics returns null when V2 disabled', () async {
    final service = makeService(enableV2: false);
    final metrics = await service.getV2Metrics();
    expect(metrics, isNull);
  });

  test('getV2Metrics returns null when collectV2Metrics is false', () async {
    final gateway = MockMatrixSyncGateway();
    final logging = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final readMarker = MockSyncReadMarkerService();
    final processor = MockSyncEventProcessor();
    final storage = MockSecureStorage();
    final sessionManager = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final timelineListener = MockMatrixTimelineListener();
    final lifecycleCoordinator = MockSyncLifecycleCoordinator();
    final client = MockClient();
    when(() => sessionManager.client).thenReturn(client);
    when(() => lifecycleCoordinator.updateHooks(
          onLogin: any(named: 'onLogin'),
          onLogout: any(named: 'onLogout'),
        )).thenReturn(null);
    when(() => lifecycleCoordinator.initialize()).thenAnswer((_) async {});
    when(() => lifecycleCoordinator.reconcileLifecycleState())
        .thenAnswer((_) async {});
    when(() => lifecycleCoordinator.dispose()).thenAnswer((_) async {});
    when(() => timelineListener.dispose()).thenAnswer((_) async {});
    when(() => sessionManager.dispose()).thenAnswer((_) async {});
    when(() => roomManager.dispose()).thenAnswer((_) async {});

    final service = MatrixService(
      gateway: gateway,
      loggingService: logging,
      activityGate: TestUserActivityGate(TestUserActivityService()),
      messageSender: createMockMessageSender(),
      journalDb: journalDb,
      settingsDb: settingsDb,
      readMarkerService: readMarker,
      eventProcessor: processor,
      secureStorage: storage,
      documentsDirectory: Directory.systemTemp,
      enableSyncV2: true,
      roomManager: roomManager,
      sessionManager: sessionManager,
      timelineListener: timelineListener,
      lifecycleCoordinator: lifecycleCoordinator,
      attachmentIndex: AttachmentIndex(logging: logging),
    );
    expect(await service.getV2Metrics(), isNull);
  });

  test('getV2Metrics returns metrics when V2 enabled', () async {
    final service = makeService(enableV2: true);
    final metrics = await service.getV2Metrics();
    expect(metrics, isA<V2Metrics>());
    // Expect default zeros from fresh pipeline map
    expect(metrics?.processed, greaterThanOrEqualTo(0));
  });

  test('creates V2 pipeline only when enabled and passes collect flag',
      () async {
    final s1 = makeService(enableV2: false);
    expect(s1.debugV2Pipeline, isNull);

    final s2 = makeService(enableV2: true);
    expect(s2.debugV2Pipeline, isNotNull);
    // collectV2Metrics is true in makeService; verify pipeline sees it
    expect(s2.debugV2Pipeline!.debugCollectMetrics, isTrue);
  });

  test('getV2Metrics maps from injected pipeline snapshot', () async {
    final gateway = MockMatrixSyncGateway();
    final logging = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final readMarker = MockSyncReadMarkerService();
    final processor = MockSyncEventProcessor();
    final storage = MockSecureStorage();
    final sessionManager = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final timelineListener = MockMatrixTimelineListener();
    final lifecycleCoordinator = MockSyncLifecycleCoordinator();
    final messageSender = createMockMessageSender();
    final client = MockClient();
    when(() => sessionManager.client).thenReturn(client);
    when(() => lifecycleCoordinator.updateHooks(
          onLogin: any(named: 'onLogin'),
          onLogout: any(named: 'onLogout'),
        )).thenReturn(null);
    when(() => lifecycleCoordinator.initialize()).thenAnswer((_) async {});
    when(() => lifecycleCoordinator.reconcileLifecycleState())
        .thenAnswer((_) async {});

    // Test pipeline overriding metricsSnapshot
    final testPipeline = _TestV2Pipeline(
      sessionManager: sessionManager,
      roomManager: roomManager,
      loggingService: logging,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      documentsDirectory: Directory.systemTemp,
    )..testMetrics = {
        'processed': 100,
        'skipped': 10,
        'failures': 2,
        'prefetch': 5,
        'flushes': 20,
        'catchupBatches': 3,
        'skippedByRetryLimit': 1,
        'retriesScheduled': 4,
        'circuitOpens': 0,
      };

    final service = MatrixService(
      gateway: gateway,
      loggingService: logging,
      activityGate: TestUserActivityGate(TestUserActivityService()),
      messageSender: messageSender,
      journalDb: journalDb,
      settingsDb: settingsDb,
      readMarkerService: readMarker,
      eventProcessor: processor,
      secureStorage: storage,
      documentsDirectory: Directory.systemTemp,
      enableSyncV2: true,
      collectV2Metrics: true,
      roomManager: roomManager,
      sessionManager: sessionManager,
      timelineListener: timelineListener,
      lifecycleCoordinator: lifecycleCoordinator,
      v2PipelineOverride: testPipeline,
      attachmentIndex: AttachmentIndex(logging: logging),
    );
    expect(service, isNotNull);
    expect(service.debugV2Pipeline, isNotNull);

    final metrics = await service.getV2Metrics();
    expect(metrics, isNotNull);
    expect(metrics!.processed, 100);
    expect(metrics.skipped, 10);
    expect(metrics.failures, 2);
    expect(metrics.circuitOpens, 0);
  });

  test('getV2Metrics treats empty snapshot as zeros', () async {
    final gateway = MockMatrixSyncGateway();
    final logging = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final readMarker = MockSyncReadMarkerService();
    final processor = MockSyncEventProcessor();
    final storage = MockSecureStorage();
    final sessionManager = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final timelineListener = MockMatrixTimelineListener();
    final lifecycleCoordinator = MockSyncLifecycleCoordinator();
    final messageSender = createMockMessageSender();
    final client = MockClient();
    when(() => sessionManager.client).thenReturn(client);
    when(() => lifecycleCoordinator.updateHooks(
          onLogin: any(named: 'onLogin'),
          onLogout: any(named: 'onLogout'),
        )).thenReturn(null);
    when(() => lifecycleCoordinator.initialize()).thenAnswer((_) async {});
    when(() => lifecycleCoordinator.reconcileLifecycleState())
        .thenAnswer((_) async {});

    final testPipeline = _TestV2Pipeline(
      sessionManager: sessionManager,
      roomManager: roomManager,
      loggingService: logging,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      documentsDirectory: Directory.systemTemp,
    )..testMetrics = {};

    final service = MatrixService(
      gateway: gateway,
      loggingService: logging,
      activityGate: TestUserActivityGate(TestUserActivityService()),
      messageSender: messageSender,
      journalDb: journalDb,
      settingsDb: settingsDb,
      readMarkerService: readMarker,
      eventProcessor: processor,
      secureStorage: storage,
      documentsDirectory: Directory.systemTemp,
      enableSyncV2: true,
      collectV2Metrics: true,
      roomManager: roomManager,
      sessionManager: sessionManager,
      timelineListener: timelineListener,
      lifecycleCoordinator: lifecycleCoordinator,
      v2PipelineOverride: testPipeline,
      attachmentIndex: AttachmentIndex(logging: logging),
    );

    final metrics = await service.getV2Metrics();
    expect(metrics, isNotNull);
    expect(metrics!.processed, 0);
  });

  test('forceV2Rescan delegates to pipeline', () async {
    final gateway = MockMatrixSyncGateway();
    final logging = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final readMarker = MockSyncReadMarkerService();
    final processor = MockSyncEventProcessor();
    final storage = MockSecureStorage();
    final sessionManager = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final timelineListener = MockMatrixTimelineListener();
    final lifecycleCoordinator = MockSyncLifecycleCoordinator();
    final messageSender = createMockMessageSender();
    final client = MockClient();
    when(() => sessionManager.client).thenReturn(client);
    when(() => lifecycleCoordinator.updateHooks(
          onLogin: any(named: 'onLogin'),
          onLogout: any(named: 'onLogout'),
        )).thenReturn(null);
    when(() => lifecycleCoordinator.initialize()).thenAnswer((_) async {});
    when(() => lifecycleCoordinator.reconcileLifecycleState())
        .thenAnswer((_) async {});
    when(() => lifecycleCoordinator.dispose()).thenAnswer((_) async {});
    when(() => timelineListener.dispose()).thenAnswer((_) async {});
    when(() => sessionManager.dispose()).thenAnswer((_) async {});
    when(() => roomManager.dispose()).thenAnswer((_) async {});

    final pipeline = _TestV2Pipeline2(
      sessionManager: sessionManager,
      roomManager: roomManager,
      loggingService: logging,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      documentsDirectory: Directory.systemTemp,
    );
    var called = 0;
    pipeline.onForceRescan = ({required bool includeCatchUp}) async {
      called++;
      expect(includeCatchUp, isTrue);
    };

    final service = MatrixService(
      gateway: gateway,
      loggingService: logging,
      activityGate: TestUserActivityGate(TestUserActivityService()),
      messageSender: messageSender,
      journalDb: journalDb,
      settingsDb: settingsDb,
      readMarkerService: readMarker,
      eventProcessor: processor,
      secureStorage: storage,
      documentsDirectory: Directory.systemTemp,
      enableSyncV2: true,
      collectV2Metrics: true,
      roomManager: roomManager,
      sessionManager: sessionManager,
      timelineListener: timelineListener,
      lifecycleCoordinator: lifecycleCoordinator,
      v2PipelineOverride: pipeline,
      attachmentIndex: AttachmentIndex(logging: logging),
    );

    await service.forceV2Rescan();
    expect(called, 1);
  });

  test('getSyncDiagnosticsText formats metrics snapshot as lines', () async {
    final gateway = MockMatrixSyncGateway();
    final logging = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final readMarker = MockSyncReadMarkerService();
    final processor = MockSyncEventProcessor();
    final storage = MockSecureStorage();
    final sessionManager = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final timelineListener = MockMatrixTimelineListener();
    final lifecycleCoordinator = MockSyncLifecycleCoordinator();
    final messageSender = createMockMessageSender();
    final client = MockClient();
    when(() => sessionManager.client).thenReturn(client);
    when(() => lifecycleCoordinator.updateHooks(
          onLogin: any(named: 'onLogin'),
          onLogout: any(named: 'onLogout'),
        )).thenReturn(null);
    when(() => lifecycleCoordinator.initialize()).thenAnswer((_) async {});
    when(() => lifecycleCoordinator.reconcileLifecycleState())
        .thenAnswer((_) async {});

    final pipeline = _TestV2Pipeline2(
      sessionManager: sessionManager,
      roomManager: roomManager,
      loggingService: logging,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      documentsDirectory: Directory.systemTemp,
    )..testMetrics = {'processed': 3, 'dbApplied': 2, 'dbEntryLinkNoop': 4};

    final service = MatrixService(
      gateway: gateway,
      loggingService: logging,
      activityGate: TestUserActivityGate(TestUserActivityService()),
      messageSender: messageSender,
      journalDb: journalDb,
      settingsDb: settingsDb,
      readMarkerService: readMarker,
      eventProcessor: processor,
      secureStorage: storage,
      documentsDirectory: Directory.systemTemp,
      enableSyncV2: true,
      collectV2Metrics: true,
      roomManager: roomManager,
      sessionManager: sessionManager,
      timelineListener: timelineListener,
      lifecycleCoordinator: lifecycleCoordinator,
      v2PipelineOverride: pipeline,
      attachmentIndex: AttachmentIndex(logging: logging),
    );

    final text = await service.getSyncDiagnosticsText();
    expect(text.contains('processed=3'), isTrue);
    expect(text.contains('dbApplied=2'), isTrue);
    expect(text.contains('dbEntryLinkNoop=4'), isTrue);
  });

  test('forceV2Rescan handles overlapping calls gracefully', () async {
    final gateway = MockMatrixSyncGateway();
    final logging = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final readMarker = MockSyncReadMarkerService();
    final processor = MockSyncEventProcessor();
    final storage = MockSecureStorage();
    final sessionManager = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final timelineListener = MockMatrixTimelineListener();
    final lifecycleCoordinator = MockSyncLifecycleCoordinator();
    final messageSender = createMockMessageSender();
    final client = MockClient();
    when(() => sessionManager.client).thenReturn(client);
    when(() => lifecycleCoordinator.updateHooks(
          onLogin: any(named: 'onLogin'),
          onLogout: any(named: 'onLogout'),
        )).thenReturn(null);
    when(() => lifecycleCoordinator.initialize()).thenAnswer((_) async {});
    when(() => lifecycleCoordinator.reconcileLifecycleState())
        .thenAnswer((_) async {});

    final pipeline = _TestV2Pipeline2(
      sessionManager: sessionManager,
      roomManager: roomManager,
      loggingService: logging,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      documentsDirectory: Directory.systemTemp,
    );
    var calls = 0;
    pipeline.onForceRescan = ({required bool includeCatchUp}) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    };

    final service = MatrixService(
      gateway: gateway,
      loggingService: logging,
      activityGate: TestUserActivityGate(TestUserActivityService()),
      messageSender: messageSender,
      journalDb: journalDb,
      settingsDb: settingsDb,
      readMarkerService: readMarker,
      eventProcessor: processor,
      secureStorage: storage,
      documentsDirectory: Directory.systemTemp,
      enableSyncV2: true,
      collectV2Metrics: true,
      roomManager: roomManager,
      sessionManager: sessionManager,
      timelineListener: timelineListener,
      lifecycleCoordinator: lifecycleCoordinator,
      v2PipelineOverride: pipeline,
      attachmentIndex: AttachmentIndex(logging: logging),
    );

    // Trigger two rescans overlapping in time
    final f1 = service.forceV2Rescan();
    final f2 = service.forceV2Rescan();
    await Future.wait([f1, f2]);
    expect(calls, 2);
  });

  test('getDiagnosticInfo does not include v2Metrics (typed-only)', () async {
    final service = makeService(enableV2: true);
    final info = await service.getDiagnosticInfo();
    expect(info.containsKey('v2Metrics'), isFalse);
  });

  test('connectivity resumes triggers V2 forceRescan (includeCatchUp=true)',
      () async {
    final gateway = MockMatrixSyncGateway();
    final logging = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final readMarker = MockSyncReadMarkerService();
    final processor = MockSyncEventProcessor();
    final storage = MockSecureStorage();
    final sessionManager = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final timelineListener = MockMatrixTimelineListener();
    final lifecycleCoordinator = MockSyncLifecycleCoordinator();
    final client = MockClient();
    when(() => sessionManager.client).thenReturn(client);
    when(() => lifecycleCoordinator.updateHooks(
          onLogin: any(named: 'onLogin'),
          onLogout: any(named: 'onLogout'),
        )).thenReturn(null);
    when(() => lifecycleCoordinator.initialize()).thenAnswer((_) async {});
    when(() => lifecycleCoordinator.reconcileLifecycleState())
        .thenAnswer((_) async {});

    final pipeline = _TestV2Pipeline2(
      sessionManager: sessionManager,
      roomManager: roomManager,
      loggingService: logging,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      documentsDirectory: Directory.systemTemp,
    );
    var called = 0;
    pipeline.onForceRescan = ({required bool includeCatchUp}) async {
      called++;
      expect(includeCatchUp, isTrue);
    };

    final controller = StreamController<List<ConnectivityResult>>.broadcast();
    addTearDown(controller.close);

    // Ensure async disposals are stubbed to Futures for service.dispose()
    when(() => lifecycleCoordinator.dispose()).thenAnswer((_) async {});
    when(() => timelineListener.dispose()).thenAnswer((_) async {});
    when(() => sessionManager.dispose()).thenAnswer((_) async {});
    when(() => roomManager.dispose()).thenAnswer((_) async {});

    // Construct service with injected connectivity stream and pipeline
    final matrixService = MatrixService(
      gateway: gateway,
      loggingService: logging,
      activityGate: TestUserActivityGate(TestUserActivityService()),
      messageSender: createMockMessageSender(),
      journalDb: journalDb,
      settingsDb: settingsDb,
      readMarkerService: readMarker,
      eventProcessor: processor,
      secureStorage: storage,
      documentsDirectory: Directory.systemTemp,
      enableSyncV2: true,
      collectV2Metrics: true,
      roomManager: roomManager,
      sessionManager: sessionManager,
      timelineListener: timelineListener,
      lifecycleCoordinator: lifecycleCoordinator,
      v2PipelineOverride: pipeline,
      connectivityStream: controller.stream,
      attachmentIndex: AttachmentIndex(logging: logging),
    );
    addTearDown(() => matrixService.dispose());

    // Simulate connectivity regained
    controller.add(<ConnectivityResult>[ConnectivityResult.wifi]);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(called, 1);
  });

  test('startup triggers V2 forceRescan includeCatchUp=true', () async {
    final gateway = MockMatrixSyncGateway();
    final logging = MockLoggingService();
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final readMarker = MockSyncReadMarkerService();
    final processor = MockSyncEventProcessor();
    final storage = MockSecureStorage();
    final sessionManager = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final timelineListener = MockMatrixTimelineListener();
    final lifecycleCoordinator = MockSyncLifecycleCoordinator();
    final client = MockClient();
    when(() => sessionManager.client).thenReturn(client);
    when(() => lifecycleCoordinator.updateHooks(
          onLogin: any(named: 'onLogin'),
          onLogout: any(named: 'onLogout'),
        )).thenReturn(null);
    when(() => lifecycleCoordinator.initialize()).thenAnswer((_) async {});
    when(() => lifecycleCoordinator.reconcileLifecycleState())
        .thenAnswer((_) async {});
    when(() => lifecycleCoordinator.dispose()).thenAnswer((_) async {});
    when(() => timelineListener.dispose()).thenAnswer((_) async {});
    when(() => sessionManager.dispose()).thenAnswer((_) async {});
    when(() => roomManager.dispose()).thenAnswer((_) async {});

    final pipeline = _TestV2Pipeline2(
      sessionManager: sessionManager,
      roomManager: roomManager,
      loggingService: logging,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      documentsDirectory: Directory.systemTemp,
    );
    var called = 0;
    pipeline.onForceRescan = ({required bool includeCatchUp}) async {
      called++;
      expect(includeCatchUp, isTrue);
    };

    final matrixService = MatrixService(
      gateway: gateway,
      loggingService: logging,
      activityGate: TestUserActivityGate(TestUserActivityService()),
      messageSender: createMockMessageSender(),
      journalDb: journalDb,
      settingsDb: settingsDb,
      readMarkerService: readMarker,
      eventProcessor: processor,
      secureStorage: storage,
      documentsDirectory: Directory.systemTemp,
      enableSyncV2: true,
      collectV2Metrics: true,
      roomManager: roomManager,
      sessionManager: sessionManager,
      timelineListener: timelineListener,
      lifecycleCoordinator: lifecycleCoordinator,
      v2PipelineOverride: pipeline,
      attachmentIndex: AttachmentIndex(logging: logging),
    );
    addTearDown(() => matrixService.dispose());

    // Allow delayed startup forceRescan to fire
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(called, 1);
  });

  test('connectivity handler logs exceptions from V2 forceRescan', () async {
    final gateway = MockMatrixSyncGateway();
    final logging = MockLoggingService();
    when(() => logging.captureException(any<Object>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'))).thenReturn(null);
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final readMarker = MockSyncReadMarkerService();
    final processor = MockSyncEventProcessor();
    final storage = MockSecureStorage();
    final sessionManager = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final timelineListener = MockMatrixTimelineListener();
    final lifecycleCoordinator = MockSyncLifecycleCoordinator();
    final client = MockClient();
    when(() => sessionManager.client).thenReturn(client);
    when(() => lifecycleCoordinator.updateHooks(
          onLogin: any(named: 'onLogin'),
          onLogout: any(named: 'onLogout'),
        )).thenReturn(null);
    when(() => lifecycleCoordinator.initialize()).thenAnswer((_) async {});
    when(() => lifecycleCoordinator.reconcileLifecycleState())
        .thenAnswer((_) async {});
    when(() => lifecycleCoordinator.dispose()).thenAnswer((_) async {});
    when(() => timelineListener.dispose()).thenAnswer((_) async {});
    when(() => sessionManager.dispose()).thenAnswer((_) async {});
    when(() => roomManager.dispose()).thenAnswer((_) async {});

    final pipeline = _TestV2Pipeline2(
      sessionManager: sessionManager,
      roomManager: roomManager,
      loggingService: logging,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      documentsDirectory: Directory.systemTemp,
    )..onForceRescan = ({required bool includeCatchUp}) async {
        throw Exception('fail');
      };

    final controller = StreamController<List<ConnectivityResult>>.broadcast();
    addTearDown(controller.close);

    final matrixService = MatrixService(
      gateway: gateway,
      loggingService: logging,
      activityGate: TestUserActivityGate(TestUserActivityService()),
      messageSender: createMockMessageSender(),
      journalDb: journalDb,
      settingsDb: settingsDb,
      readMarkerService: readMarker,
      eventProcessor: processor,
      secureStorage: storage,
      documentsDirectory: Directory.systemTemp,
      enableSyncV2: true,
      collectV2Metrics: true,
      roomManager: roomManager,
      sessionManager: sessionManager,
      timelineListener: timelineListener,
      lifecycleCoordinator: lifecycleCoordinator,
      v2PipelineOverride: pipeline,
      connectivityStream: controller.stream,
      attachmentIndex: AttachmentIndex(logging: logging),
    );
    addTearDown(() => matrixService.dispose());

    controller.add(<ConnectivityResult>[ConnectivityResult.ethernet]);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    verify(() => logging.captureException(
          any<Object>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'connectivity',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        )).called(1);
  });

  test('startup forceRescan logs success', () async {
    final gateway = MockMatrixSyncGateway();
    final logging = MockLoggingService();
    when(() => logging.captureEvent(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        )).thenReturn(null);
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final readMarker = MockSyncReadMarkerService();
    final processor = MockSyncEventProcessor();
    final storage = MockSecureStorage();
    final sessionManager = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final timelineListener = MockMatrixTimelineListener();
    final lifecycleCoordinator = MockSyncLifecycleCoordinator();
    final client = MockClient();
    when(() => sessionManager.client).thenReturn(client);
    when(() => lifecycleCoordinator.updateHooks(
          onLogin: any(named: 'onLogin'),
          onLogout: any(named: 'onLogout'),
        )).thenReturn(null);
    when(() => lifecycleCoordinator.initialize()).thenAnswer((_) async {});
    when(() => lifecycleCoordinator.reconcileLifecycleState())
        .thenAnswer((_) async {});
    when(() => lifecycleCoordinator.dispose()).thenAnswer((_) async {});
    when(() => timelineListener.dispose()).thenAnswer((_) async {});
    when(() => sessionManager.dispose()).thenAnswer((_) async {});
    when(() => roomManager.dispose()).thenAnswer((_) async {});

    var called = 0;
    final pipeline = _TestV2Pipeline2(
      sessionManager: sessionManager,
      roomManager: roomManager,
      loggingService: logging,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      documentsDirectory: Directory.systemTemp,
    )..onForceRescan = ({required bool includeCatchUp}) async {
        called++;
      };

    final service = MatrixService(
      gateway: gateway,
      loggingService: logging,
      activityGate: TestUserActivityGate(TestUserActivityService()),
      messageSender: createMockMessageSender(),
      journalDb: journalDb,
      settingsDb: settingsDb,
      readMarkerService: readMarker,
      eventProcessor: processor,
      secureStorage: storage,
      documentsDirectory: Directory.systemTemp,
      enableSyncV2: true,
      collectV2Metrics: true,
      roomManager: roomManager,
      sessionManager: sessionManager,
      timelineListener: timelineListener,
      lifecycleCoordinator: lifecycleCoordinator,
      v2PipelineOverride: pipeline,
      connectivityStream: const Stream<List<ConnectivityResult>>.empty(),
      attachmentIndex: AttachmentIndex(logging: logging),
    );
    addTearDown(() => service.dispose());

    await Future<void>.delayed(const Duration(milliseconds: 400));

    verify(() => logging.captureEvent(
          'service.forceRescan.startup includeCatchUp=true',
          domain: 'MATRIX_SERVICE',
          subDomain: 'v2.forceRescan',
        )).called(1);
    verify(() => logging.captureEvent(
          'service.forceRescan.startup.done',
          domain: 'MATRIX_SERVICE',
          subDomain: 'v2.forceRescan',
        )).called(1);
    expect(called, 1);
  });

  test('startup forceRescan logs and handles exception', () async {
    final gateway = MockMatrixSyncGateway();
    final logging = MockLoggingService();
    when(() => logging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        )).thenReturn(null);
    final journalDb = MockJournalDb();
    final settingsDb = MockSettingsDb();
    final readMarker = MockSyncReadMarkerService();
    final processor = MockSyncEventProcessor();
    final storage = MockSecureStorage();
    final sessionManager = MockMatrixSessionManager();
    final roomManager = MockSyncRoomManager();
    final timelineListener = MockMatrixTimelineListener();
    final lifecycleCoordinator = MockSyncLifecycleCoordinator();
    final client = MockClient();
    when(() => sessionManager.client).thenReturn(client);
    when(() => lifecycleCoordinator.updateHooks(
          onLogin: any(named: 'onLogin'),
          onLogout: any(named: 'onLogout'),
        )).thenReturn(null);
    when(() => lifecycleCoordinator.initialize()).thenAnswer((_) async {});
    when(() => lifecycleCoordinator.reconcileLifecycleState())
        .thenAnswer((_) async {});
    when(() => lifecycleCoordinator.dispose()).thenAnswer((_) async {});
    when(() => timelineListener.dispose()).thenAnswer((_) async {});
    when(() => sessionManager.dispose()).thenAnswer((_) async {});
    when(() => roomManager.dispose()).thenAnswer((_) async {});

    final pipeline = _TestV2Pipeline2(
      sessionManager: sessionManager,
      roomManager: roomManager,
      loggingService: logging,
      journalDb: journalDb,
      settingsDb: settingsDb,
      eventProcessor: processor,
      readMarkerService: readMarker,
      documentsDirectory: Directory.systemTemp,
    )..onForceRescan = ({required bool includeCatchUp}) async {
        throw Exception('boom');
      };

    final service = MatrixService(
      gateway: gateway,
      loggingService: logging,
      activityGate: TestUserActivityGate(TestUserActivityService()),
      messageSender: createMockMessageSender(),
      journalDb: journalDb,
      settingsDb: settingsDb,
      readMarkerService: readMarker,
      eventProcessor: processor,
      secureStorage: storage,
      documentsDirectory: Directory.systemTemp,
      enableSyncV2: true,
      collectV2Metrics: true,
      roomManager: roomManager,
      sessionManager: sessionManager,
      timelineListener: timelineListener,
      lifecycleCoordinator: lifecycleCoordinator,
      v2PipelineOverride: pipeline,
      connectivityStream: const Stream<List<ConnectivityResult>>.empty(),
      attachmentIndex: AttachmentIndex(logging: logging),
    );
    addTearDown(() => service.dispose());

    await Future<void>.delayed(const Duration(milliseconds: 400));

    verify(() => logging.captureException(
          any<Object>(),
          domain: 'MATRIX_SERVICE',
          subDomain: 'v2.forceRescan.startup',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        )).called(1);
  });
}

class TestUserActivityService extends UserActivityService {}

class TestUserActivityGate extends UserActivityGate {
  TestUserActivityGate(UserActivityService service)
      : super(activityService: service, idleThreshold: Duration.zero);
}

class _TestV2Pipeline extends MatrixStreamConsumer {
  _TestV2Pipeline({
    required super.sessionManager,
    required super.roomManager,
    required super.loggingService,
    required super.journalDb,
    required super.settingsDb,
    required super.eventProcessor,
    required super.readMarkerService,
    required super.documentsDirectory,
  });

  Map<String, int> testMetrics = const {};

  @override
  Map<String, int> metricsSnapshot() => testMetrics;
}
