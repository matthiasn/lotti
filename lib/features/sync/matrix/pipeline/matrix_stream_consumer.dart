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
    required this._sessionManager,
    required this._roomManager,
    required this._loggingService,
    required this._settingsDb,
    required this._eventProcessor,
    MetricsCounters? metricsCounters,
    bool collectMetrics = false,
  }) : _metrics = metricsCounters ?? MetricsCounters(collect: collectMetrics) {
    _processor = MatrixStreamProcessor(
      metricsCounters: _metrics,
      collectMetrics: collectMetrics,
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
  final MetricsCounters _metrics;

  late final MatrixStreamProcessor _processor;
  late final MatrixStreamSignalBinder _signals;

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await _roomManager.initialize();
    final results = await Future.wait([
      getLastReadMatrixEventId(_settingsDb),
      getLastReadMatrixEventTs(_settingsDb),
    ]);
    final lastEventId = results[0];
    final lastTs = results[1] as num?;
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
        // Up to ~10s (50 x 200ms) so the queue pipeline doesn't start
        // catch-up against a not-yet-hydrated room and miss backlog.
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
    // Un-partialling the sync room (so `RoomMember` state events get
    // tracked and E2EE / SAS verification can discover the other
    // device) is owned by `QueuePipelineCoordinator._maybePostLoadCurrentRoom`,
    // which calls `room.postLoad()` on every onSync.
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
    _loggingService.captureEvent(
      _withInstance('MatrixStreamConsumer disposed'),
      domain: syncLoggingDomain,
      subDomain: 'dispose',
    );
  }

  Map<String, int> metricsSnapshot() => _processor.metricsSnapshot();

  void reportDbApplyDiagnostics(SyncApplyDiagnostics diag) {
    _processor.reportDbApplyDiagnostics(diag);
  }

  Map<String, String> diagnosticsStrings() => _processor.diagnosticsStrings();

  void recordConnectivitySignal() => _processor.recordConnectivitySignal();
}
