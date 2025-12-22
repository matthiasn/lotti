import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/last_read.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_catch_up.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_live_scan.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_processor.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_signals.dart';
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_pipeline.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:meta/meta.dart';

/// Stream-first sync consumer.
///
/// Design (high level):
/// - Client stream events and live timeline callbacks are treated as lightweight
///   signals only. They schedule a debounced live scan and never process per
///   event payloads directly. This avoids advancing markers out of order when
///   the device comes online mid-stream.
/// - Marker advancement happens exclusively inside ordered batches produced by
///   live scan or catch-up.
/// - Optional metrics capture signal counts (client/timeline/connectivity) and
///   the latency from signal -> first scan to aid observability.
class MatrixStreamConsumer implements SyncPipeline {
  MatrixStreamConsumer({
    required MatrixSessionManager sessionManager,
    required SyncRoomManager roomManager,
    required LoggingService loggingService,
    required JournalDb journalDb,
    required SettingsDb settingsDb,
    required SyncEventProcessor eventProcessor,
    required SyncReadMarkerService readMarkerService,
    required SentEventRegistry sentEventRegistry,
    AttachmentIndex? attachmentIndex,
    MetricsCounters? metricsCounters,
    bool collectMetrics = false,
    Duration markerDebounce = const Duration(milliseconds: 300),
    int? maxRetriesPerEvent,
    Duration circuitCooldown = const Duration(seconds: 30),
    bool dropOldPayloadsInLiveScan = true,
    // Test seam: skip sync wait in tests to avoid needing to mock client.onSync
    bool skipSyncWait = false,
    Future<bool> Function({
      required Timeline timeline,
      required String? lastEventId,
      required int pageSize,
      required int maxPages,
      required LoggingService logging,
    })? backfill,
    Directory? documentsDirectory,
  })  : _skipSyncWait = skipSyncWait,
        _sessionManager = sessionManager,
        _roomManager = roomManager,
        _loggingService = loggingService,
        _journalDb = journalDb,
        _settingsDb = settingsDb,
        _eventProcessor = eventProcessor,
        _readMarkerService = readMarkerService,
        _attachmentIndex = attachmentIndex,
        _collectMetrics = collectMetrics,
        _metrics = metricsCounters ?? MetricsCounters(collect: collectMetrics),
        _markerDebounce = markerDebounce,
        _maxRetriesPerEvent = maxRetriesPerEvent ?? 5,
        _circuitCooldown = circuitCooldown,
        _dropOldPayloadsInLiveScan = dropOldPayloadsInLiveScan,
        _sentEventRegistry = sentEventRegistry,
        _backfill = backfill,
        _documentsDirectory = documentsDirectory {
    _processor = MatrixStreamProcessor(
      roomManager: _roomManager,
      loggingService: _loggingService,
      journalDb: _journalDb,
      settingsDb: _settingsDb,
      eventProcessor: _eventProcessor,
      readMarkerService: _readMarkerService,
      sentEventRegistry: _sentEventRegistry,
      clientProvider: () => _sessionManager.client,
      liveTimelineProvider: () => _liveScan.liveTimeline,
      attachmentIndex: _attachmentIndex,
      metricsCounters: _metrics,
      collectMetrics: _collectMetrics,
      markerDebounce: _markerDebounce,
      maxRetriesPerEvent: _maxRetriesPerEvent,
      circuitCooldown: _circuitCooldown,
      documentsDirectory: _documentsDirectory,
    );
    _catchUp = MatrixStreamCatchUpCoordinator(
      sessionManager: _sessionManager,
      roomManager: _roomManager,
      loggingService: _loggingService,
      metrics: _metrics,
      collectMetrics: _collectMetrics,
      skipSyncWait: _skipSyncWait,
      processor: _processor,
      flushDeferredLiveScan: (source) =>
          _liveScan.flushDeferredLiveScan(source),
      withInstance: _withInstance,
      backfill: _backfill,
    );
    _liveScan = MatrixStreamLiveScanController(
      loggingService: _loggingService,
      metrics: _metrics,
      collectMetrics: _collectMetrics,
      dropOldPayloadsInLiveScan: _dropOldPayloadsInLiveScan,
      processor: _processor,
      isInitialCatchUpCompleted: () => _catchUp.initialCatchUpCompleted,
      isCatchUpInFlight: () => _catchUp.catchUpInFlight,
      isWakeCatchUpPending: () => _catchUp.wakeCatchUpPending,
      startWakeCatchUp: _catchUp.startWakeCatchUp,
      withInstance: _withInstance,
    );
    _processor.configureLiveScanCallbacks(
      scheduleLiveScan: _liveScan.scheduleLiveScan,
      scanLiveTimeline: _liveScan.scanLiveTimeline,
      scheduleRescan: _liveScan.scheduleRescan,
    );
    _catchUp.scanLiveTimeline = _liveScan.scanLiveTimeline;
    _signals = MatrixStreamSignalBinder(
      sessionManager: _sessionManager,
      roomManager: _roomManager,
      loggingService: _loggingService,
      metrics: _metrics,
      collectMetrics: _collectMetrics,
      catchUpCoordinator: _catchUp,
      liveScanController: _liveScan,
      withInstance: _withInstance,
    );
  }

  static int _instanceCounter = 0;
  final int _instanceId = ++_instanceCounter;

  String _withInstance(String message) => '$message inst=$_instanceId';

  final bool _skipSyncWait;
  final MatrixSessionManager _sessionManager;
  final SyncRoomManager _roomManager;
  final LoggingService _loggingService;
  final JournalDb _journalDb;
  final SettingsDb _settingsDb;
  final SyncEventProcessor _eventProcessor;
  final SyncReadMarkerService _readMarkerService;
  final AttachmentIndex? _attachmentIndex;
  final bool _collectMetrics;
  final MetricsCounters _metrics;
  final Duration _markerDebounce;
  final int _maxRetriesPerEvent;
  final Duration _circuitCooldown;
  final bool _dropOldPayloadsInLiveScan;
  final SentEventRegistry _sentEventRegistry;
  final Future<bool> Function({
    required Timeline timeline,
    required String? lastEventId,
    required int pageSize,
    required int maxPages,
    required LoggingService logging,
  })? _backfill;
  final Directory? _documentsDirectory;

  late final MatrixStreamProcessor _processor;
  late final MatrixStreamCatchUpCoordinator _catchUp;
  late final MatrixStreamLiveScanController _liveScan;
  late final MatrixStreamSignalBinder _signals;

  bool _initialized = false;
  String? _startupLastProcessedEventId;
  num? _startupLastProcessedTs;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    // Ensure room snapshot is hydrated similarly to V1.
    await _roomManager.initialize();
    _startupLastProcessedEventId = await getLastReadMatrixEventId(_settingsDb);
    try {
      final ts = await getLastReadMatrixEventTs(_settingsDb);
      if (ts != null) _startupLastProcessedTs = ts;
    } catch (_) {
      // optional
    }
    _processor.setLastProcessed(
      eventId: _startupLastProcessedEventId,
      timestamp: _startupLastProcessedTs,
    );
    _catchUp.startupMarkers = (
      eventId: _startupLastProcessedEventId,
      timestamp: _startupLastProcessedTs,
    );
    // Pass startup timestamp to event processor to skip old backfill requests
    // that would otherwise be re-processed on every restart due to catch-up.
    _eventProcessor.startupTimestamp = _startupLastProcessedTs;
    _loggingService.captureEvent(
      _withInstance(
        'startup.marker id=${_startupLastProcessedEventId ?? 'null'} ts=${_startupLastProcessedTs?.toInt() ?? 'null'}',
      ),
      domain: syncLoggingDomain,
      subDomain: 'startup.marker',
    );
    _initialized = true;
  }

  @override
  Future<void> start() async {
    // Ensure room snapshot exists, then run an initial catch-up BEFORE any
    // live scans or marker advancement to avoid skipping backlog.
    if (_roomManager.currentRoom == null) {
      final hydrateStart = clock.now();
      try {
        await _roomManager.hydrateRoomSnapshot(client: _sessionManager.client);
      } catch (e, st) {
        _loggingService.captureException(
          e,
          domain: syncLoggingDomain,
          subDomain: 'start.hydrateRoom',
          stackTrace: st,
        );
      }
      // Wait deterministically for room readiness with a bounded timeout.
      // Total wait ~10s (50 x 200ms). This avoids races where the live scan
      // would start before the room becomes available and skip backlog.
      for (var i = 0; i < 50 && _roomManager.currentRoom == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      final hydrateElapsed =
          clock.now().difference(hydrateStart).inMilliseconds;
      _loggingService.captureEvent(
        _withInstance(
          'start.hydrateRoom.ready=${_roomManager.currentRoom != null} after ${hydrateElapsed}ms',
        ),
        domain: syncLoggingDomain,
        subDomain: 'start',
      );
    }
    await _catchUp.runInitialCatchUpIfReady();
    await _signals.start(lastProcessedEventId: _processor.lastProcessedEventId);
    _loggingService.captureEvent(
      _withInstance('MatrixStreamConsumer started'),
      domain: syncLoggingDomain,
      subDomain: 'start',
    );
  }

  @override
  Future<void> dispose() async {
    await _signals.dispose();
    await _catchUp.dispose();
    _liveScan.dispose();
    _processor.dispose();
    _loggingService.captureEvent(
      _withInstance('MatrixStreamConsumer disposed'),
      domain: syncLoggingDomain,
      subDomain: 'dispose',
    );
  }

  Map<String, int> metricsSnapshot() => _processor.metricsSnapshot();

  // Called by SyncEventProcessor via observer to record DB apply results
  void reportDbApplyDiagnostics(SyncApplyDiagnostics diag) {
    _processor.reportDbApplyDiagnostics(diag);
  }

  // Visible for testing only
  @visibleForTesting
  bool get debugCollectMetrics => _processor.debugCollectMetrics;

  // Additional textual diagnostics not represented in numeric metrics.
  Map<String, String> diagnosticsStrings() => _processor.diagnosticsStrings();

  // Force a rescan and optional catch-up to recover from potential gaps.
  Future<void> forceRescan({
    bool includeCatchUp = true,
    bool bypassCatchUpInFlightCheck = false,
  }) async {
    await _catchUp.forceRescan(
      includeCatchUp: includeCatchUp,
      bypassCatchUpInFlightCheck: bypassCatchUpInFlightCheck,
    );
  }

  // Force all pending retries to be immediately due and trigger a scan.
  Future<void> retryNow() async => _processor.retryNow();

  // Record a connectivity-driven signal for observability.
  void recordConnectivitySignal() => _processor.recordConnectivitySignal();

  // Test-only hook invoked at the start of scheduleLiveScan to simulate
  // errors and exercise fallback logic.
  @visibleForTesting
  void Function()? get scheduleLiveScanTestHook =>
      _liveScan.scheduleLiveScanTestHook;

  @visibleForTesting
  set scheduleLiveScanTestHook(void Function()? fn) {
    _liveScan.scheduleLiveScanTestHook = fn;
  }

  // Test-only hook invoked at the start of scanLiveTimeline with a
  // scheduler callback to allow tests to schedule additional scans while
  // the guard is asserted.
  @visibleForTesting
  void Function(void Function())? get scanLiveTimelineTestHook =>
      _liveScan.scanLiveTimelineTestHook;

  @visibleForTesting
  set scanLiveTimelineTestHook(void Function(void Function())? fn) {
    _liveScan.scanLiveTimelineTestHook = fn;
  }
}
