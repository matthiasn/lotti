import 'dart:async';

import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_catch_up.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_live_scan.dart';
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

class MatrixStreamSignalBinder {
  MatrixStreamSignalBinder({
    required MatrixSessionManager sessionManager,
    required SyncRoomManager roomManager,
    required LoggingService loggingService,
    required MetricsCounters metrics,
    required bool collectMetrics,
    required MatrixStreamCatchUpCoordinator catchUpCoordinator,
    required MatrixStreamLiveScanController liveScanController,
    required String Function(String message) withInstance,
  }) : _sessionManager = sessionManager,
       _roomManager = roomManager,
       _loggingService = loggingService,
       _metrics = metrics,
       _collectMetrics = collectMetrics,
       _catchUp = catchUpCoordinator,
       _liveScan = liveScanController,
       _withInstance = withInstance;

  final MatrixSessionManager _sessionManager;
  final SyncRoomManager _roomManager;
  final LoggingService _loggingService;
  final MetricsCounters _metrics;
  final bool _collectMetrics;
  final MatrixStreamCatchUpCoordinator _catchUp;
  final MatrixStreamLiveScanController _liveScan;
  final String Function(String message) _withInstance;

  StreamSubscription<Event>? _sub;
  StreamSubscription<SyncUpdate>? _syncSub;

  // Phase 0 diagnostic state — InboundEventQueue design validation.
  // Tracks last successful sync response to correlate limited=true events
  // with the gap since the previous sync for the current sync room.
  DateTime? _lastSyncAt;
  // Tracks originServerTs ordering of events delivered by onTimelineEvent
  // for the current sync room to measure intra-sync reordering.
  int? _lastTimelineEventTsMs;
  int _timelineEventsSinceSummary = 0;
  int _timelineReorderingsSinceSummary = 0;
  int _timelineSameTsSinceSummary = 0;
  static const int _timelineOrderingSummaryEvery = 100;

  void _recordTimelineSignal(String kind) {
    if (!_collectMetrics) return;
    _metrics.incSignalTimelineCallbacks();
    if (kind == 'new') {
      _metrics.incSignalTimelineNewEvent();
    } else if (kind == 'insert') {
      _metrics.incSignalTimelineInsert();
    }
  }

  // Phase 0 diagnostic: measures whether events arriving on
  // onTimelineEvent land in originServerTs-ascending order within the
  // current sync room. Summary log every N events reports the count of
  // strict reorderings (ts < prev) and same-ts ties. A healthy baseline
  // is reorderings=0 with occasional sameTs; large reordering counts
  // would mean the InboundEventQueue's drain-time sort is load-bearing.
  void _recordTimelineOrdering(Event event) {
    final ts = event.originServerTs.millisecondsSinceEpoch;
    final prev = _lastTimelineEventTsMs;
    if (prev != null) {
      if (ts < prev) {
        _timelineReorderingsSinceSummary++;
      } else if (ts == prev) {
        _timelineSameTsSinceSummary++;
      }
    }
    _lastTimelineEventTsMs = ts;
    _timelineEventsSinceSummary++;
    if (_timelineEventsSinceSummary >= _timelineOrderingSummaryEvery) {
      _loggingService.captureEvent(
        'onTimelineEvent.ordering '
        'events=$_timelineEventsSinceSummary '
        'reorderings=$_timelineReorderingsSinceSummary '
        'sameTs=$_timelineSameTsSinceSummary',
        domain: syncLoggingDomain,
        subDomain: 'onTimelineEvent.ordering',
      );
      _timelineEventsSinceSummary = 0;
      _timelineReorderingsSinceSummary = 0;
      _timelineSameTsSinceSummary = 0;
    }
  }

  Future<void> start({required String? lastProcessedEventId}) async {
    await _sub?.cancel();
    _sub = null;
    await _syncSub?.cancel();
    _syncSub = null;

    _lastSyncAt = DateTime.now();
    _lastTimelineEventTsMs = null;
    _timelineEventsSinceSummary = 0;
    _timelineReorderingsSinceSummary = 0;
    _timelineSameTsSinceSummary = 0;

    // Phase 0 diagnostic: detect `timeline.limited == true` for the current
    // sync room. A limited sync means the SDK truncated local timeline state
    // and delivered only the tail via onTimelineEvent; events before the
    // limited boundary are silently dropped unless we bridge them via
    // /messages. The log line + sinceMs gap informs whether a limited=true
    // bridge is the right primary trigger for the planned InboundEventQueue.
    _syncSub = _sessionManager.client.onSync.stream.listen((update) {
      final roomId = _roomManager.currentRoomId;
      final now = DateTime.now();
      final prev = _lastSyncAt;
      _lastSyncAt = now;
      if (roomId == null) return;
      final joined = update.rooms?.join?[roomId];
      final timeline = joined?.timeline;
      if (timeline == null || timeline.limited != true) return;
      final sinceMs = prev == null
          ? 'initial'
          : '${now.difference(prev).inMilliseconds}';
      _loggingService.captureEvent(
        'sync.limited roomId=$roomId '
        'prevBatch=${timeline.prevBatch} '
        'eventCount=${timeline.events?.length ?? 0} '
        'sinceMs=$sinceMs',
        domain: syncLoggingDomain,
        subDomain: 'sync.limited',
      );
    });

    // Client-level session stream -> signal-driven catch-up.
    // Filter by current room; the very first event also triggers a catch-up
    // to ensure we ingest backlog before scanning the tail.
    _sub = _sessionManager.timelineEvents.listen((event) {
      final roomId = _roomManager.currentRoomId;
      if (roomId == null || event.roomId != roomId) return;
      _recordTimelineOrdering(event);
      _catchUp.handleFirstStreamEvent();
      if (_collectMetrics) _metrics.incSignalClientStream();
      // Conditional processing: expensive catch-up during startup, cheap scan in
      // steady state.
      if (_catchUp.handleClientStreamSignal()) {
        return;
      }
      // Steady state: skip expensive catch-up, just scan timeline.
      // Use scheduleLiveScan() to benefit from debouncing and coalescing,
      // preventing excessive scans during event bursts.
      _liveScan.scheduleLiveScan();
    });

    // Also attach live timeline listeners to proactively scan in case the
    // client-level stream is delayed or suppressed on some platforms.
    final room = _roomManager.currentRoom;
    if (room != null) {
      try {
        // Wrap timeline callbacks to count and log signals. These callbacks do
        // not process payloads; they only nudge the scheduler.
        void onTimelineSignal(String kind) {
          _recordTimelineSignal(kind);
          try {
            _liveScan.scheduleLiveScan();
          } catch (e, st) {
            _loggingService.captureException(
              e,
              domain: syncLoggingDomain,
              subDomain: 'signal.schedule',
              stackTrace: st,
            );
            unawaited(_catchUp.forceRescan());
          }
        }

        // Only subscribe to append callbacks. In a single-user,
        // append-only sync model, `onChange` / `onRemove` / `onUpdate` have
        // no legitimate trigger and their per-event metrics dominated the
        // signalSummary breakdown without ever driving work.
        final tl = await room.getTimeline(
          onNewEvent: () => onTimelineSignal('new'),
          onInsert: (_) => onTimelineSignal('insert'),
        );
        _liveScan.liveTimeline = tl;
        // Proactively scan once at startup, now that initial catch-up has run
        // (or been attempted) to avoid skipping backlog.
        _loggingService.captureEvent(
          _withInstance('start: scheduling initial liveScan'),
          domain: syncLoggingDomain,
          subDomain: 'start.liveScan',
        );
        _liveScan.scheduleRescan(const Duration(milliseconds: 80));
        // If we had a stored lastProcessed marker AND the initial catch-up has
        // not yet completed, schedule one follow-up run. This covers the case
        // where the room snapshot became available only after start() and the
        // first catch-up attempt had no active room. When the initial catch-up
        // already succeeded (common steady state) there is nothing to retry,
        // and running another full catch-up here caused a redundant
        // `_waitForSyncCompletion` + re-ingest pass on every startup.
        if (lastProcessedEventId != null && !_catchUp.initialCatchUpReady) {
          _loggingService.captureEvent(
            _withInstance('start: scheduling catchUp retry'),
            domain: syncLoggingDomain,
            subDomain: 'start.catchUpRetry',
          );
          unawaited(
            Future<void>.delayed(
              const Duration(milliseconds: 150),
            ).then((_) {
              if (!_catchUp.initialCatchUpReady) {
                return _catchUp.runGuardedCatchUp('start.catchUpRetry');
              }
              return Future<void>.value();
            }),
          );
        }
      } catch (e, st) {
        _loggingService.captureException(
          e,
          domain: syncLoggingDomain,
          subDomain: 'attach.liveTimeline',
          stackTrace: st,
        );
      }
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _syncSub?.cancel();
    _syncSub = null;
  }
}
