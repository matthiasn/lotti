import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
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
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/secure_storage.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

class _MockMatrixSyncGateway extends Mock implements MatrixSyncGateway {}

class _MockSyncRoomManager extends Mock implements SyncRoomManager {}

class _MockMatrixSessionManager extends Mock implements MatrixSessionManager {}

class _MockLoggingService extends Mock implements LoggingService {}

class _MockJournalDb extends Mock implements JournalDb {}

class _MockSettingsDb extends Mock implements SettingsDb {}

class _MockSyncReadMarkerService extends Mock
    implements SyncReadMarkerService {}

class _MockSyncEventProcessor extends Mock implements SyncEventProcessor {}

class _MockSecureStorage extends Mock implements SecureStorage {}

class _MockMatrixMessageSender extends Mock implements MatrixMessageSender {}

class _MockUserActivityGate extends Mock implements UserActivityGate {}

class _MockMatrixStreamConsumer extends Mock implements MatrixStreamConsumer {}

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
        entityId: 'entity',
        vectorClock: null,
        conflictStatus: 'none',
        applied: true,
      ),
    );
  });

  late _MockMatrixSyncGateway gateway;
  late _MockLoggingService logging;
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

  Future<MatrixService> createService({
    bool collectMetrics = true,
    Stream<List<ConnectivityResult>>? connectivity,
    Map<String, int> metricsSnapshot = const {'dbApplied': 4},
    Map<String, String> diagnostics = const {'nextRetry': 'soon'},
  }) async {
    final connectivityStream =
        connectivity ?? const Stream<List<ConnectivityResult>>.empty();

    when(() => pipeline.reportDbApplyDiagnostics(any())).thenReturn(null);
    when(() =>
            pipeline.forceRescan(includeCatchUp: any(named: 'includeCatchUp')))
        .thenAnswer((_) async {});
    when(() => pipeline.retryNow()).thenAnswer((_) async {});
    when(() => pipeline.metricsSnapshot()).thenReturn(metricsSnapshot);
    when(() => pipeline.diagnosticsStrings()).thenReturn(diagnostics);

    when(() => eventProcessor.applyObserver = any()).thenReturn(null);
    when(() => messageSender.sentEventRegistry).thenReturn(SentEventRegistry());
    when(() => sessionManager.client).thenReturn(client);
    when(() => sessionManager.dispose()).thenAnswer((_) async {});
    when(() => roomManager.dispose()).thenAnswer((_) async {});
    when(() => activityGate.dispose()).thenAnswer((_) async {});

    final service = MatrixService(
      gateway: gateway,
      loggingService: logging,
      activityGate: activityGate,
      messageSender: messageSender,
      journalDb: journalDb,
      settingsDb: settingsDb,
      readMarkerService: readMarkerService,
      eventProcessor: eventProcessor,
      secureStorage: secureStorage,
      documentsDirectory: Directory.systemTemp,
      collectSyncMetrics: collectMetrics,
      roomManager: roomManager,
      sessionManager: sessionManager,
      v2PipelineOverride: pipeline,
      attachmentIndex: attachmentIndex,
      connectivityStream: connectivityStream,
    );

    // Allow the eager forceRescan task to run before assertions.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    clearInteractions(pipeline);
    return service;
  }

  setUp(() {
    gateway = _MockMatrixSyncGateway();
    logging = _MockLoggingService();
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

  test('getV2Metrics returns null when metrics collection disabled', () async {
    final service = await createService(collectMetrics: false);

    final metrics = await service.getSyncMetrics();

    expect(metrics, isNull);
  });

  test('getV2Metrics returns metrics when collection enabled', () async {
    final service = await createService(
      metricsSnapshot: const {'dbApplied': 7, 'failures': 0},
    );

    final metrics = await service.getSyncMetrics();

    expect(metrics, isA<SyncMetrics>());
    expect(metrics?.dbApplied, 7);
  });

  test('forceV2Rescan forwards includeCatchUp flag to pipeline', () async {
    final service = await createService();

    await service.forceRescan(includeCatchUp: false);

    verify(() => pipeline.forceRescan(includeCatchUp: false)).called(1);
  });

  test('retryV2Now triggers pipeline retry', () async {
    final service = await createService();

    await service.retryNow();

    verify(() => pipeline.retryNow()).called(1);
  });

  test('getSyncDiagnosticsText joins metrics and diagnostics strings',
      () async {
    final service = await createService(
      metricsSnapshot: const {'dbApplied': 3, 'failures': 1},
      diagnostics: const {'nextRetry': '42s'},
    );

    final text = await service.getSyncDiagnosticsText();

    expect(text, contains('dbApplied=3'));
    expect(text, contains('failures=1'));
    expect(text, contains('nextRetry=42s'));
  });

  test('dispose releases owned dependencies', () async {
    final service = await createService();

    await service.dispose();

    verify(() => sessionManager.dispose()).called(1);
    verify(() => roomManager.dispose()).called(1);
  });
}
