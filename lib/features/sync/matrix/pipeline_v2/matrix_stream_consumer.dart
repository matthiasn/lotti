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
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
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
  })  : _sessionManager = sessionManager,
        _roomManager = roomManager,
        _loggingService = loggingService,
        _journalDb = journalDb,
        _settingsDb = settingsDb,
        _eventProcessor = eventProcessor,
        _readMarkerService = readMarkerService,
        _documentsDirectory = documentsDirectory,
        _collectMetrics = collectMetrics;

  final MatrixSessionManager _sessionManager;
  final SyncRoomManager _roomManager;
  final LoggingService _loggingService;
  final JournalDb _journalDb;
  final SettingsDb _settingsDb;
  final SyncEventProcessor _eventProcessor;
  final SyncReadMarkerService _readMarkerService;
  final Directory _documentsDirectory;
  final bool _collectMetrics;

  StreamSubscription<Event>? _sub;
  bool _initialized = false;
  String? _lastProcessedEventId;
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

  // Failure retry tracking to avoid permanent blockage.
  static const int _maxRetriesPerEvent = 5;
  static const Duration _retryBaseDelay = Duration(milliseconds: 200);
  static const Duration _retryMaxDelay = Duration(seconds: 10);
  static const double _retryJitter = 0.2; // +/- 20%

  final Map<String, _RetryInfo> _retryState = <String, _RetryInfo>{};

  Duration _computeBackoff(int attempts) {
    final baseMs = _retryBaseDelay.inMilliseconds;
    final maxMs = _retryMaxDelay.inMilliseconds;
    final raw = baseMs * math.pow(2, attempts);
    final clamped = raw.clamp(baseMs.toDouble(), maxMs.toDouble());
    // Jitter: +/- _retryJitter
    final jitterFactor =
        1 + (_retryJitter * (math.Random().nextDouble() * 2 - 1));
    final jittered =
        (clamped * jitterFactor).clamp(baseMs.toDouble(), maxMs.toDouble());
    return Duration(milliseconds: jittered.round());
  }

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
    _sub = _client.onTimelineEvent.stream.listen((event) {
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
      var limit = 200;
      while (true) {
        final snapshot = await room.getTimeline(limit: limit);
        final events = List<Event>.from(snapshot.events)
          ..sort(TimelineEventOrdering.compare);
        final idx = _findLastIndex(events, _lastProcessedEventId);
        final reachedStart = events.length < limit; // room has fewer than limit
        final reachedCap = limit >= _catchupMaxLookback;
        if (idx >= 0 || reachedStart || reachedCap) {
          final slice = idx >= 0 ? events.sublist(idx + 1) : events;
          if (slice.isNotEmpty) {
            if (_collectMetrics) _metricCatchupBatches++;
            await _processOrdered(slice);
          }
          snapshot.cancelSubscriptions();
          break; // done
        } else {
          snapshot.cancelSubscriptions();
          limit = math.min(limit * 2, _catchupMaxLookback);
        }
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
      final idx = _findLastIndex(events, _lastProcessedEventId);
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

  int _findLastIndex(List<Event> ordered, String? id) {
    if (id == null) return -1;
    for (var i = ordered.length - 1; i >= 0; i--) {
      if (ordered[i].eventId == id) return i;
    }
    return -1;
  }

  Future<void> _flush() async {
    if (_pending.isEmpty) return;
    final queue = List<Event>.from(_pending);
    _pending.clear();
    queue.sort(TimelineEventOrdering.compare);
    // Deduplicate by id while preserving chronological order.
    final seen = <String>{};
    final ordered = <Event>[
      for (final e in queue)
        if (seen.add(e.eventId)) e,
    ];
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

    // First pass: prefetch attachments for remote events.
    for (final e in ordered) {
      final isRemote = e.senderId != _client.userID;
      if (isRemote && e.attachmentMimetype.isNotEmpty) {
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

        // Check retry cap — if exceeded, treat as handled to avoid permanent blockage.
        final attempts = rs?.attempts ?? 0;
        if (attempts >= _maxRetriesPerEvent) {
          treatAsHandled = true;
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
            final nextAttempts = attempts + 1;
            final backoff = _computeBackoff(nextAttempts);
            final due = DateTime.now().add(backoff);
            _retryState[id] = _RetryInfo(nextAttempts, due);
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

    if (latestEventId != null) {
      _lastProcessedEventId = latestEventId;
      _pendingMarkerEventId = latestEventId;
      _scheduleMarkerFlush(room);
    }

    // If we encountered retriable failures (e.g., attachments not yet
    // available), schedule a follow-up scan to pick them up shortly.
    if (hadFailure) {
      final now = DateTime.now();
      final delay = earliestNextDue != null && earliestNextDue.isAfter(now)
          ? earliestNextDue.difference(now)
          : const Duration(milliseconds: 200);
      _liveScanTimer?.cancel();
      _liveScanTimer = Timer(delay, () {
        unawaited(_scanLiveTimeline());
      });
    }
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
}
