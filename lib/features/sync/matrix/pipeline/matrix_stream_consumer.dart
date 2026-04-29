import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/last_read.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_processor.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_signals.dart';
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_pipeline.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:meta/meta.dart';

/// Encryption + diagnostics façade for the queue pipeline.
///
/// Live ingestion is owned by `QueuePipelineCoordinator`. This consumer
/// handles startup state (un-partials the sync room, seeds the
/// `SyncEventProcessor` with the last-read timestamp so old backfill
/// requests get skipped), keeps the `sync.limited` Phase-0 diagnostic
/// attached via `MatrixStreamSignalBinder`, and surfaces metrics for the
/// Matrix Stats UI.
class MatrixStreamConsumer implements SyncPipeline {
  MatrixStreamConsumer({
    required MatrixSessionManager sessionManager,
    required SyncRoomManager roomManager,
    required LoggingService loggingService,
    required SettingsDb settingsDb,
    required SyncEventProcessor eventProcessor,
    MetricsCounters? metricsCounters,
    bool collectMetrics = false,
  }) : _sessionManager = sessionManager,
       _roomManager = roomManager,
       _loggingService = loggingService,
       _settingsDb = settingsDb,
       _eventProcessor = eventProcessor,
       _collectMetrics = collectMetrics,
       _metrics = metricsCounters ?? MetricsCounters(collect: collectMetrics) {
    _processor = MatrixStreamProcessor(
      metricsCounters: _metrics,
      collectMetrics: _collectMetrics,
    );
    _signals = MatrixStreamSignalBinder(
      sessionManager: _sessionManager,
      roomManager: _roomManager,
      loggingService: _loggingService,
    );
  }

  static int _instanceCounter = 0;
  final int _instanceId = ++_instanceCounter;

  String _withInstance(String message) => '$message inst=$_instanceId';

  final MatrixSessionManager _sessionManager;
  final SyncRoomManager _roomManager;
  final LoggingService _loggingService;
  final SettingsDb _settingsDb;
  final SyncEventProcessor _eventProcessor;
  final bool _collectMetrics;
  final MetricsCounters _metrics;

  late final MatrixStreamProcessor _processor;
  late final MatrixStreamSignalBinder _signals;

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await _roomManager.initialize();
    final lastEventId = await getLastReadMatrixEventId(_settingsDb);
    num? lastTs;
    try {
      lastTs = await getLastReadMatrixEventTs(_settingsDb);
    } catch (_) {
      // optional
    }
    // Pass startup timestamp to the SyncEventProcessor so it can skip old
    // backfill requests during the queue pipeline's startup catch-up.
    _eventProcessor.startupTimestamp = lastTs;
    _loggingService.captureEvent(
      _withInstance(
        'startup.marker id=${lastEventId ?? 'null'} ts=${lastTs?.toInt() ?? 'null'}',
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
      final hasConfiguredRoom = _roomManager.currentRoomId != null;
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
      // Wait only when a room is already configured. During fresh provisioning
      // there is no persisted room yet, and waiting here adds unnecessary
      // startup latency before the room is joined and saved.
      if (hasConfiguredRoom) {
        // Total wait ~10s (50 x 200ms). This avoids races where the live scan
        // would start before the room becomes available and skip backlog.
        for (var i = 0; i < 50 && _roomManager.currentRoom == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      }
      final hydrateElapsed = clock
          .now()
          .difference(hydrateStart)
          .inMilliseconds;
      _loggingService.captureEvent(
        _withInstance(
          'start.hydrateRoom.ready=${_roomManager.currentRoom != null} '
          'configured=$hasConfiguredRoom after ${hydrateElapsed}ms',
        ),
        domain: syncLoggingDomain,
        subDomain: 'start',
      );
    }
    // CRITICAL: call `room.getTimeline()` to un-partial the sync room.
    // Matrix SDK skips `RoomMember` state events on partial rooms in
    // `_updateRoomsByEventUpdate`, so a partial room never has its
    // `_trackedUserIds` extended when a new member joins. That breaks
    // device-key discovery: `updateUserDeviceKeys` never queries keys
    // for users the SDK isn't tracking, and SAS verification / E2EE
    // never sees the other device. We call `getTimeline()` for the
    // side effect of loading room state, then cancel the subscription
    // immediately — the queue pipeline owns live ingestion.
    final room = _roomManager.currentRoom;
    if (room != null) {
      try {
        final tl = await room.getTimeline();
        tl.cancelSubscriptions();
      } catch (error, stackTrace) {
        _loggingService.captureException(
          error,
          domain: syncLoggingDomain,
          subDomain: 'start.getTimeline',
          stackTrace: stackTrace,
        );
      }
    }
    await _signals.start();
    _loggingService.captureEvent(
      _withInstance('MatrixStreamConsumer started'),
      domain: syncLoggingDomain,
      subDomain: 'start',
    );
  }

  @override
  Future<void> dispose() async {
    await _signals.dispose();
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

  @visibleForTesting
  bool get debugCollectMetrics => _collectMetrics;

  // Additional textual diagnostics not represented in numeric metrics.
  Map<String, String> diagnosticsStrings() => _processor.diagnosticsStrings();

  // Record a connectivity-driven signal for observability.
  void recordConnectivitySignal() => _processor.recordConnectivitySignal();
}
