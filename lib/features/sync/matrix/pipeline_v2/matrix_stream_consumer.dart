import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/last_read.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_pipeline.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/save_attachment.dart';
import 'package:lotti/features/sync/matrix/sdk_pagination_compat.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/features/sync/matrix/utils/timeline_utils.dart' as tu;
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

class _RetryInfo {
  _RetryInfo(this.attempts, this.nextDue);
  final int attempts;
  final DateTime nextDue;
}

/// Stream-first, simplified sync consumer (V2 scaffold).
///
/// This initial version only wires the lifecycle and logging; event processing
/// and micro-batching will land incrementally behind the same flag.
class MatrixStreamConsumer implements SyncPipeline {
  MatrixStreamConsumer({
    required MatrixSessionManager sessionManager,
    required SyncRoomManager roomManager,
    required LoggingService loggingService,
    required JournalDb journalDb,
    required SettingsDb settingsDb,
    required SyncEventProcessor eventProcessor,
    required SyncReadMarkerService readMarkerService,
    required Directory documentsDirectory,
    bool collectMetrics = false,
    DateTime Function()? now,
  })  : _sessionManager = sessionManager,
        _roomManager = roomManager,
        _loggingService = loggingService,
        _journalDb = journalDb,
        _settingsDb = settingsDb,
        _eventProcessor = eventProcessor,
        _readMarkerService = readMarkerService,
        _documentsDirectory = documentsDirectory,
        _collectMetrics = collectMetrics,
        _now = now ?? DateTime.now,
        _maxRetriesPerEvent = 5,
        _retryTtl = const Duration(minutes: 10),
        _retryMaxEntries = 2000,
        _circuitFailureThreshold = 50,
        _circuitCooldown = const Duration(seconds: 30);

  final MatrixSessionManager _sessionManager;
  final SyncRoomManager _roomManager;
  final LoggingService _loggingService;
  final JournalDb _journalDb;
  final SettingsDb _settingsDb;
  final SyncEventProcessor _eventProcessor;
  final SyncReadMarkerService _readMarkerService;
  final Directory _documentsDirectory;
  final bool _collectMetrics;
  final DateTime Function() _now;

  StreamSubscription<Event>? _sub;
  bool _initialized = false;
  String? _lastProcessedEventId;
  num? _lastProcessedTs;
  final List<Event> _pending = <Event>[];
  Timer? _flushTimer;
  Timer? _liveScanTimer;
  String? _pendingMarkerEventId;
  Timer? _markerDebounceTimer;
  static const Duration _flushInterval = Duration(milliseconds: 150);
  static const int _maxBatch = 200;
  static const Duration _markerDebounce = Duration(milliseconds: 600);
  static const int _catchupMaxLookback =
      4000; // maximum events to inspect during catch-up

  // Lightweight metrics counters (dev diagnostics).
  int _metricProcessed = 0;
  int _metricSkipped = 0;
  int _metricFailures = 0;
  int _metricPrefetch = 0;
  int _metricFlushes = 0;
  int _metricCatchupBatches = 0;
  int _metricSkippedByRetryLimit = 0;
  int _metricRetriesScheduled = 0;
  // Circuit breaker counters
  int _metricCircuitOpens = 0;

  // Failure retry tracking to avoid permanent blockage (configurable).
  final int _maxRetriesPerEvent;
  final Duration _retryTtl;
  final int _retryMaxEntries;
  final int _circuitFailureThreshold;
  final Duration _circuitCooldown;
  DateTime? _circuitOpenUntil;
  int _consecutiveFailures = 0;

  final Map<String, _RetryInfo> _retryState = <String, _RetryInfo>{};

  Duration _computeBackoff(int attempts) =>
      tu.computeExponentialBackoff(attempts);

  Client get _client => _sessionManager.client;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    // Ensure room snapshot is hydrated similarly to V1.
    await _roomManager.initialize();
    _lastProcessedEventId = await getLastReadMatrixEventId(_settingsDb);
    _initialized = true;
  }

  @override
  Future<void> start() async {
    // Ensure room snapshot exists, then catch up and attach streaming.
    if (_roomManager.currentRoom == null) {
      await _roomManager.hydrateRoomSnapshot(client: _client);
    }
    await _attachCatchUp();
    await _sub?.cancel();
    _sub = _sessionManager.timelineEvents.listen((event) {
      final roomId = _roomManager.currentRoomId;
      if (roomId == null || event.roomId != roomId) return;
      _enqueue(event);
    });

    // Also attach live timeline listeners to proactively scan in case the
    // client-level stream is delayed or suppressed on some platforms.
    final room = _roomManager.currentRoom;
    if (room != null) {
      try {
        final tl = await room.getTimeline(
          onNewEvent: _scheduleLiveScan,
          onInsert: (_) => _scheduleLiveScan(),
          onChange: (_) => _scheduleLiveScan(),
          onRemove: (_) => _scheduleLiveScan(),
          onUpdate: _scheduleLiveScan,
        );
        _liveTimeline = tl;
      } catch (e, st) {
        _loggingService.captureException(
          e,
          domain: 'MATRIX_SYNC_V2',
          subDomain: 'attach.liveTimeline',
          stackTrace: st,
        );
      }
    }
    _loggingService.captureEvent(
      'MatrixStreamConsumer started',
      domain: 'MATRIX_SYNC_V2',
      subDomain: 'start',
    );
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _flushTimer?.cancel();
    _liveScanTimer?.cancel();
    _markerDebounceTimer?.cancel();
    // Cancel live timeline subscriptions to avoid leaks.
    try {
      _liveTimeline?.cancelSubscriptions();
    } catch (_) {
      // Best effort; Matrix SDK cancel is synchronous.
    }
    _liveTimeline = null;
    _loggingService.captureEvent(
      'MatrixStreamConsumer disposed',
      domain: 'MATRIX_SYNC_V2',
      subDomain: 'dispose',
    );
  }

  void _enqueue(Event event) {
    _pending.add(event);
    if (_pending.length >= _maxBatch) {
      unawaited(_flush());
      return;
    }
    _flushTimer ??= Timer(_flushInterval, () {
      _flushTimer = null;
      unawaited(_flush());
    });
  }

  Future<void> _attachCatchUp() async {
    try {
      final room = _roomManager.currentRoom;
      final roomId = _roomManager.currentRoomId;
      if (room == null || roomId == null) {
        _loggingService.captureEvent(
          'No active room for catch-up',
          domain: 'MATRIX_SYNC_V2',
          subDomain: 'catchup',
        );
        return;
      }
      // First try SDK pagination/backfill so we don't need to rebuild giant
      // snapshots for large/high-traffic rooms. Fallback to limit-doubling.
      var limit = 200;
      final snapshot = await room.getTimeline(limit: limit);
      try {
        // Attempt SDK backfill (best-effort across SDK versions).
        final attempted = await SdkPaginationCompat.backfillUntilContains(
          timeline: snapshot,
          lastEventId: _lastProcessedEventId,
          pageSize: 200,
          maxPages: 20,
          logging: _loggingService,
        );
        final events = List<Event>.from(snapshot.events)
          ..sort(TimelineEventOrdering.compare);
        var idx = tu.findLastIndexByEventId(events, _lastProcessedEventId);
        if (idx < 0 && !attempted) {
          // If SDK backfill wasn't possible, fall back to snapshot escalation.
          while (true) {
            final reachedStart = events.length < limit;
            final reachedCap = limit >= _catchupMaxLookback;
            if (idx >= 0 || reachedStart || reachedCap) break;
            limit = math.min(limit * 2, _catchupMaxLookback);
            final next = await room.getTimeline(limit: limit);
            try {
              final nextEvents = List<Event>.from(next.events)
                ..sort(TimelineEventOrdering.compare);
              events
                ..clear()
                ..addAll(nextEvents);
              idx = tu.findLastIndexByEventId(events, _lastProcessedEventId);
            } finally {
              try {
                next.cancelSubscriptions();
              } catch (_) {}
            }
          }
        }

        final slice = idx >= 0 ? events.sublist(idx + 1) : events;
        if (slice.isNotEmpty) {
          if (_collectMetrics) _metricCatchupBatches++;
          await _processOrdered(slice);
        }
      } finally {
        try {
          snapshot.cancelSubscriptions();
        } catch (_) {}
      }
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'catchup',
        stackTrace: st,
      );
    }
  }

  Timeline? _liveTimeline;

  void _scheduleLiveScan() {
    _liveScanTimer?.cancel();
    _liveScanTimer = Timer(const Duration(milliseconds: 120), () {
      unawaited(_scanLiveTimeline());
    });
  }

  Future<void> _scanLiveTimeline() async {
    final tl = _liveTimeline;
    if (tl == null) return;
    try {
      final events = List<Event>.from(tl.events)
        ..sort(TimelineEventOrdering.compare);
      final idx = tu.findLastIndexByEventId(events, _lastProcessedEventId);
      final slice = idx >= 0 ? events.sublist(idx + 1) : events;
      if (slice.isNotEmpty) {
        await _processOrdered(slice);
        if (_collectMetrics) {
          _loggingService.captureEvent(
            'v2 liveScan processed=${slice.length} latest=${_lastProcessedEventId ?? 'null'}',
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'liveScan',
          );
        }
      }
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'liveScan',
        stackTrace: st,
      );
    }
  }

  // (helper removed; all call sites use utils)

  Future<void> _flush() async {
    if (_pending.isEmpty) return;
    final queue = List<Event>.from(_pending);
    _pending.clear();
    queue.sort(TimelineEventOrdering.compare);
    // Deduplicate by id while preserving chronological order.
    final ordered = tu.dedupEventsByIdPreserveOrder(queue);
    await _processOrdered(ordered);
    if (_collectMetrics) {
      _metricFlushes++;
      _loggingService.captureEvent(
        'v2 metrics flush=$_metricFlushes processed=$_metricProcessed skipped=$_metricSkipped failures=$_metricFailures prefetch=$_metricPrefetch catchup=$_metricCatchupBatches skippedByRetry=$_metricSkippedByRetryLimit retriesScheduled=$_metricRetriesScheduled retriesPending=${_retryState.length}',
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'metrics',
      );
    }
  }

  Future<void> _processOrdered(List<Event> ordered) async {
    final room = _roomManager.currentRoom;
    if (room == null || ordered.isEmpty) return;

    // Circuit breaker: if open, skip processing and schedule a follow-up scan.
    final nowStart = _now();
    final openUntil = _circuitOpenUntil;
    if (openUntil != null && nowStart.isBefore(openUntil)) {
      _liveScanTimer?.cancel();
      final delay = openUntil.difference(nowStart);
      _liveScanTimer = Timer(delay, () {
        unawaited(_scanLiveTimeline());
      });
      return;
    }

    // First pass: prefetch attachments for remote events.
    for (final e in ordered) {
      if (tu.shouldPrefetchAttachment(e, _client.userID)) {
        await saveAttachment(
          e,
          loggingService: _loggingService,
          documentsDirectory: _documentsDirectory,
        );
        if (_collectMetrics) _metricPrefetch++;
      }
    }

    // Second pass: process text events and compute advancement.
    String? latestEventId;
    num? latestTs;
    var blockedByFailure = false;
    var hadFailure = false;
    var batchFailures = 0;
    DateTime? earliestNextDue;
    for (final e in ordered) {
      final ts = TimelineEventOrdering.timestamp(e);
      final id = e.eventId;
      final content = e.content;
      final msgType = content['msgtype'];
      var processedOk = true;
      var treatAsHandled =
          false; // allow advancement even if skipped by retry limit

      if (msgType == syncMessageType) {
        // If this event has a retry schedule, and it's not yet due, block advancement until due.
        final rs = _retryState[id];
        final now = DateTime.now();
        if (rs != null && now.isBefore(rs.nextDue)) {
          processedOk = false;
          hadFailure = true;
          // Track earliest nextDue to schedule a follow-up scan at the right time.
          if (earliestNextDue == null || rs.nextDue.isBefore(earliestNextDue)) {
            earliestNextDue = rs.nextDue;
          }
        }

        // Check retry cap — if exceeded, treat as handled and drop state to avoid memory growth.
        final attempts = rs?.attempts ?? 0;
        if (attempts >= _maxRetriesPerEvent) {
          treatAsHandled = true;
          _retryState.remove(id);
          _loggingService.captureEvent(
            'dropping after retry cap: $id (attempts=$attempts)',
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'retry.cap',
          );
          if (_collectMetrics) _metricSkippedByRetryLimit++;
        } else if (processedOk) {
          try {
            await _eventProcessor.process(event: e, journalDb: _journalDb);
            if (_collectMetrics) _metricProcessed++;
            // On success, clear retry state.
            _retryState.remove(id);
          } catch (err, st) {
            processedOk = false;
            hadFailure = true;
            batchFailures++;
            final nextAttempts = attempts + 1;
            final backoff = _computeBackoff(nextAttempts);
            final due = DateTime.now().add(backoff);
            if (nextAttempts >= _maxRetriesPerEvent) {
              // Final failure: drop retry state, mark as handled to avoid blocking,
              // and record metrics.
              _retryState.remove(id);
              treatAsHandled = true;
              _loggingService.captureEvent(
                'dropping after retry cap: $id (attempts=$nextAttempts)',
                domain: 'MATRIX_SYNC_V2',
                subDomain: 'retry.cap',
              );
              if (_collectMetrics) _metricSkippedByRetryLimit++;
            } else {
              _retryState[id] = _RetryInfo(nextAttempts, due);
            }
            if (earliestNextDue == null || due.isBefore(earliestNextDue)) {
              earliestNextDue = due;
            }
            _loggingService.captureException(
              err,
              domain: 'MATRIX_SYNC_V2',
              subDomain: 'process',
              stackTrace: st,
            );
            if (_collectMetrics) _metricFailures++;
            if (_collectMetrics) _metricRetriesScheduled++;
          }
        }
      } else {
        if (_collectMetrics) _metricSkipped++;
      }
      if (!processedOk && !treatAsHandled) {
        blockedByFailure = true;
      }
      if (!blockedByFailure &&
          (processedOk || treatAsHandled) &&
          TimelineEventOrdering.isNewer(
            candidateTimestamp: ts,
            candidateEventId: id,
            latestTimestamp: latestTs,
            latestEventId: latestEventId,
          )) {
        latestTs = ts;
        latestEventId = id;
      }
    }

    if (latestEventId != null && latestTs != null) {
      final shouldAdvance = _lastProcessedEventId == null ||
          _lastProcessedTs == null ||
          TimelineEventOrdering.isNewer(
            candidateTimestamp: latestTs,
            candidateEventId: latestEventId,
            latestTimestamp: _lastProcessedTs,
            latestEventId: _lastProcessedEventId,
          );
      if (shouldAdvance) {
        _lastProcessedEventId = latestEventId;
        _lastProcessedTs = latestTs;
        _pendingMarkerEventId = latestEventId;
        _scheduleMarkerFlush(room);
        _consecutiveFailures = 0; // reset on successful advancement
      }
    }

    // If we encountered retriable failures (e.g., attachments not yet
    // available), schedule a follow-up scan to pick them up shortly.
    if (hadFailure) {
      _consecutiveFailures += batchFailures;
      if (_consecutiveFailures >= _circuitFailureThreshold) {
        _circuitOpenUntil = _now().add(_circuitCooldown);
        if (_collectMetrics) _metricCircuitOpens++;
        _loggingService.captureEvent(
          'circuit open for ${_circuitCooldown.inSeconds}s (failures=$_consecutiveFailures)',
          domain: 'MATRIX_SYNC_V2',
          subDomain: 'circuit',
        );
      }
      final now = _now();
      final delay = earliestNextDue != null && earliestNextDue.isAfter(now)
          ? earliestNextDue.difference(now)
          : const Duration(milliseconds: 200);
      _liveScanTimer?.cancel();
      _liveScanTimer = Timer(delay, () {
        unawaited(_scanLiveTimeline());
      });
    }

    // Prune retry state map to avoid unbounded growth.
    _pruneRetryState();
  }

  Map<String, int> metricsSnapshot() => <String, int>{
        'processed': _metricProcessed,
        'skipped': _metricSkipped,
        'failures': _metricFailures,
        'prefetch': _metricPrefetch,
        'flushes': _metricFlushes,
        'catchupBatches': _metricCatchupBatches,
        'skippedByRetryLimit': _metricSkippedByRetryLimit,
        'retriesScheduled': _metricRetriesScheduled,
        'circuitOpens': _metricCircuitOpens,
        // Diagnostics-only fields (not shown in UI)
        'retryStateSize': _retryState.length,
        'circuitOpen': _circuitOpenUntil != null &&
                _now().isBefore(_circuitOpenUntil!)
            ? 1
            : 0,
      };

  void _scheduleMarkerFlush(Room room) {
    _markerDebounceTimer?.cancel();
    _markerDebounceTimer = Timer(_markerDebounce, () {
      unawaited(
        _flushReadMarker(room).catchError((Object error, StackTrace stack) {
          _loggingService.captureException(
            error,
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'flushReadMarker',
            stackTrace: stack,
          );
        }),
      );
    });
  }

  Future<void> _flushReadMarker(Room room) async {
    final id = _pendingMarkerEventId;
    if (id == null) return;
    _pendingMarkerEventId = null;
    await _readMarkerService.updateReadMarker(
      client: _client,
      room: room,
      eventId: id,
    );
  }

  // Debug helpers removed in favor of metricsSnapshot() fields.

  void _pruneRetryState() {
    if (_retryState.isEmpty) return;
    final now = _now();
    // Remove entries whose nextDue is far in the past (stale),
    // and enforce a max size by dropping oldest nextDue entries.
    _retryState
        .removeWhere((_, info) => now.difference(info.nextDue) > _retryTtl);
    if (_retryState.length <= _retryMaxEntries) return;
    final entries = _retryState.entries.toList()
      ..sort((a, b) => a.value.nextDue.compareTo(b.value.nextDue));
    final toRemove = _retryState.length - _retryMaxEntries;
    for (var i = 0; i < toRemove; i++) {
      _retryState.remove(entries[i].key);
    }
  }
}
