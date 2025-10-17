import 'dart:async';
import 'dart:io';

import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/last_read.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_pipeline.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/catch_up_strategy.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/matrix_event_classifier.dart'
    as ec;
import 'package:lotti/features/sync/matrix/pipeline_v2/matrix_stream_helpers.dart'
    as msh;
import 'package:lotti/features/sync/matrix/pipeline_v2/metrics_counters.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/read_marker_manager.dart';
// metrics_utils is used indirectly via MetricsCounters.snapshot
import 'package:lotti/features/sync/matrix/pipeline_v2/retry_and_circuit.dart'
    as rc;
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
import 'package:meta/meta.dart';

class _ProcessOutcome {
  const _ProcessOutcome({
    required this.processedOk,
    required this.treatAsHandled,
    required this.hadFailure,
    required this.failureDelta,
    this.nextDue,
  });
  final bool processedOk;
  final bool treatAsHandled;
  final bool hadFailure;
  final int failureDelta; // counts only processing exceptions (for circuit)
  final DateTime? nextDue; // earliest next due time if blocked/retried
}

// Retry info moved to retry_and_circuit.dart

/// Stream-first sync consumer (V2 pipeline).
///
/// Responsibilities:
/// - Attach-time catch-up using SDK pagination/backfill when available and a
///   limit-escalation fallback for large backlogs.
/// - Micro-batched streaming with chronological ordering and in-batch
///   de-duplication by event ID.
/// - Attachment prefetch for remote events before text processing.
/// - Monotonic read marker advancement with lexicographical tie-breakers.
/// - Per-event retries with exponential backoff, TTL pruning, and a size cap
///   to bound memory growth; circuit breaker to avoid thrashing.
/// - Lightweight typed metrics via metricsSnapshot().
///
/// Constructor parameters allow test seams for time (now), SDK backfill
/// (backfill), and tuning for flush interval, batch size, and marker
/// debounce. Defaults are production-safe.
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
    AttachmentIndex? attachmentIndex,
    bool collectMetrics = false,
    DateTime Function()? now,
    Duration flushInterval = const Duration(milliseconds: 150),
    int maxBatch = 200,
    Duration markerDebounce = const Duration(milliseconds: 300),
    int? maxRetriesPerEvent,
    Future<bool> Function({
      required Timeline timeline,
      required String? lastEventId,
      required int pageSize,
      required int maxPages,
      required LoggingService logging,
    })? backfill,
  })  : _sessionManager = sessionManager,
        _roomManager = roomManager,
        _loggingService = loggingService,
        _journalDb = journalDb,
        _settingsDb = settingsDb,
        _eventProcessor = eventProcessor,
        _readMarkerService = readMarkerService,
        _documentsDirectory = documentsDirectory,
        _attachmentIndex = attachmentIndex,
        _collectMetrics = collectMetrics,
        _now = now ?? DateTime.now,
        _flushInterval = flushInterval,
        _maxBatch = maxBatch,
        _markerDebounce = markerDebounce,
        _backfill = backfill,
        _maxRetriesPerEvent = maxRetriesPerEvent ?? 5,
        _retryTtl = const Duration(minutes: 10),
        _retryMaxEntries = 2000,
        _circuitFailureThreshold = 50,
        _circuitCooldown = const Duration(seconds: 30) {
    _retryTracker = rc.RetryTracker(
      ttl: _retryTtl,
      maxEntries: _retryMaxEntries,
    );
    _circuit = rc.CircuitBreaker(
      failureThreshold: _circuitFailureThreshold,
      cooldown: _circuitCooldown,
    );
    _metrics = MetricsCounters(
      collect: _collectMetrics,
    );
    _readMarkerManager = ReadMarkerManager(
      debounce: _markerDebounce,
      onFlush: (Room room, String id) => _readMarkerService.updateReadMarker(
        client: _client,
        room: room,
        eventId: id,
        timeline: _liveTimeline,
      ),
      logging: _loggingService,
    );
  }

  final MatrixSessionManager _sessionManager;
  final SyncRoomManager _roomManager;
  final LoggingService _loggingService;
  final JournalDb _journalDb;
  final SettingsDb _settingsDb;
  final SyncEventProcessor _eventProcessor;
  final SyncReadMarkerService _readMarkerService;
  final Directory _documentsDirectory;
  final AttachmentIndex? _attachmentIndex;
  final bool _collectMetrics;
  final DateTime Function() _now;
  final Future<bool> Function({
    required Timeline timeline,
    required String? lastEventId,
    required int pageSize,
    required int maxPages,
    required LoggingService logging,
  })? _backfill;

  StreamSubscription<Event>? _sub;
  bool _initialized = false;
  String? _lastProcessedEventId;
  num? _lastProcessedTs;
  final List<Event> _pending = <Event>[];
  Timer? _flushTimer;
  Timer? _liveScanTimer;
  final Duration _flushInterval;
  final int _maxBatch;
  final Duration _markerDebounce;
  // Catch-up window is handled by strategy with sensible defaults.

  late final MetricsCounters _metrics;
  final Set<String> _pendingJsonPaths = <String>{};
  DateTime? _lastAttachmentOnlyRescanAt;
  static const Duration _minAttachmentOnlyRescanGap =
      Duration(milliseconds: 500);

  // Tracks eventIds that reported rows=0 while predicted status suggests
  // incoming is newer (missing base). These should be retried and block
  // advancement in the current batch.
  final Set<String> _missingBaseEventIds = <String>{};

  // Failure retry tracking to avoid permanent blockage (configurable).
  final int _maxRetriesPerEvent;
  final Duration _retryTtl;
  final int _retryMaxEntries;
  final int _circuitFailureThreshold;
  final Duration _circuitCooldown;
  late final rc.CircuitBreaker _circuit;
  late final rc.RetryTracker _retryTracker;
  late final ReadMarkerManager _readMarkerManager;

  Duration _computeBackoff(int attempts) =>
      tu.computeExponentialBackoff(attempts);

  Client get _client => _sessionManager.client;

  String? _extractRuntimeType(Event ev) => msh.extractRuntimeTypeFromEvent(ev);

  String? _extractJsonPath(Event ev) => msh.extractJsonPathFromEvent(ev);

  void _bumpDroppedType(String? rt) => _metrics.bumpDroppedType(rt);

  Future<_ProcessOutcome> _processSyncPayloadEvent(
    Event e, {
    String dropSuffix = '',
  }) async {
    var processedOk = true;
    var treatAsHandled = false;
    var hadFailure = false;
    var failureDelta = 0;
    DateTime? nextDue;

    final id = e.eventId;
    final now = _now();
    final blockedUntil = _retryTracker.blockedUntil(id, now);

    if (blockedUntil != null) {
      processedOk = false;
      hadFailure = true;
      nextDue = blockedUntil;
    }

    final attempts = _retryTracker.attempts(id);
    if (attempts >= _maxRetriesPerEvent) {
      treatAsHandled = true;
      _retryTracker.clear(id);
      _loggingService.captureEvent(
        'dropping after retry cap$dropSuffix: $id (attempts=$attempts)',
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'retry.cap',
      );
      if (_collectMetrics) {
        _metrics.incSkippedByRetryLimit();
        _bumpDroppedType(_extractRuntimeType(e));
      }
    } else if (processedOk) {
      try {
        await _eventProcessor.process(event: e, journalDb: _journalDb);
        // If apply observer flagged this as "missing base" then treat it as a
        // retryable failure (do not count as processed, do not advance, and
        // schedule a retry soon).
        if (_missingBaseEventIds.remove(id)) {
          processedOk = false;
          hadFailure = true;
          failureDelta = 0; // apply-level retry, not an exception
          final nextAttempts = attempts + 1;
          final backoff = _computeBackoff(nextAttempts);
          final due = _now().add(backoff);
          _retryTracker.scheduleNext(id, nextAttempts, due);
          nextDue = due;
          _loggingService.captureEvent(
            'missingBase retry scheduled: $id (attempts=$nextAttempts)',
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'retry.missingBase',
          );
        } else {
          if (_collectMetrics) {
            _metrics.incProcessedWithType(_extractRuntimeType(e));
          }
          _retryTracker.clear(id);
        }
      } catch (err, st) {
        processedOk = false;
        hadFailure = true;
        failureDelta = 1;
        final nextAttempts = attempts + 1;
        final backoff = _computeBackoff(nextAttempts);
        final due = _now().add(backoff);
        // If this looks like a missing attachment/descriptor scenario, keep the
        // event blocking and do not advance the marker even after the retry cap.
        // We detect this via a FileSystemException earlier, which records the
        // jsonPath into _pendingJsonPaths. When present, continue scheduling
        // retries and avoid marking as handled.
        final jp = _extractJsonPath(e);
        final isMissingAttachment =
            jp != null && _pendingJsonPaths.contains(jp);
        if (nextAttempts >= _maxRetriesPerEvent && !isMissingAttachment) {
          _retryTracker.clear(id);
          treatAsHandled = true;
          _loggingService.captureEvent(
            'dropping after retry cap$dropSuffix: $id (attempts=$nextAttempts)',
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'retry.cap',
          );
          if (_collectMetrics) {
            _metrics.incSkippedByRetryLimit();
            _bumpDroppedType(_extractRuntimeType(e));
          }
        } else {
          // Keep retrying (or start retrying) for missing attachments and normal failures
          // below the cap.
          _retryTracker.scheduleNext(id, nextAttempts, due);
          if (isMissingAttachment) {
            _loggingService.captureEvent(
              'missingAttachment keepRetrying: $id (attempts=$nextAttempts)',
              domain: 'MATRIX_SYNC_V2',
              subDomain: 'retry.missingAttachment',
            );
          }
        }
        nextDue = due;
        // Record pending JSON path for faster recovery when the failure is
        // due to a missing attachment.
        if (err is FileSystemException) {
          final jp = _extractJsonPath(e);
          if (jp != null) {
            _pendingJsonPaths.add(jp);
          }
        }
        _loggingService.captureException(
          err,
          domain: 'MATRIX_SYNC_V2',
          subDomain: dropSuffix.isEmpty ? 'process' : 'process.fallback',
          stackTrace: st,
        );
        if (_collectMetrics) _metrics.incFailures();
        if (_collectMetrics) _metrics.incRetriesScheduled();
      }
    }

    return _ProcessOutcome(
      processedOk: processedOk,
      treatAsHandled: treatAsHandled,
      hadFailure: hadFailure,
      failureDelta: failureDelta,
      nextDue: nextDue,
    );
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    // Ensure room snapshot is hydrated similarly to V1.
    await _roomManager.initialize();
    _lastProcessedEventId = await getLastReadMatrixEventId(_settingsDb);
    try {
      final ts = await getLastReadMatrixEventTs(_settingsDb);
      if (ts != null) _lastProcessedTs = ts;
    } catch (_) {
      // optional
    }
    _initialized = true;
  }

  @override
  Future<void> start() async {
    // Ensure room snapshot exists, then catch up and attach streaming.
    if (_roomManager.currentRoom == null) {
      try {
        await _roomManager.hydrateRoomSnapshot(client: _client);
      } catch (e, st) {
        _loggingService.captureException(
          e,
          domain: 'MATRIX_SYNC_V2',
          subDomain: 'start.hydrateRoom',
          stackTrace: st,
        );
      }
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
        // Proactively scan once at startup so we don't rely on a fresh
        // incoming event to kick the first processing pass.
        _loggingService.captureEvent(
          'v2 start: scheduling initial liveScan',
          domain: 'MATRIX_SYNC_V2',
          subDomain: 'start.liveScan',
        );
        _liveScanTimer?.cancel();
        _liveScanTimer = Timer(const Duration(milliseconds: 80), () {
          unawaited(_scanLiveTimeline());
        });
        // If we had a stored lastProcessed marker, ensure we run catch-up once
        // more shortly after the room is ready. This covers the case where the
        // room snapshot became available only after start(), and the first
        // catch-up attempt had no active room.
        if (_lastProcessedEventId != null) {
          _loggingService.captureEvent(
            'v2 start: scheduling catchUp retry',
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'start.catchUpRetry',
          );
          unawaited(Future<void>.delayed(const Duration(milliseconds: 150))
              .then((_) => _attachCatchUp()));
        }
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
    _readMarkerManager.dispose();
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
      final thresholdTs =
          _lastProcessedTs != null ? (_lastProcessedTs!.toInt() - 1) : null;
      final slice = await CatchUpStrategy.collectEventsForCatchUp(
        room: room,
        lastEventId: _lastProcessedEventId,
        backfill: _backfill ?? SdkPaginationCompat.backfillUntilContains,
        logging: _loggingService,
        rewindCount: 3,
        thresholdTsMillis: thresholdTs,
      );
      if (slice.isNotEmpty) {
        if (_collectMetrics) _metrics.incCatchupBatches();
        await _processOrdered(slice);
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
    try {
      queue.sort(TimelineEventOrdering.compare);
      // Deduplicate by id while preserving chronological order.
      final ordered = tu.dedupEventsByIdPreserveOrder(queue);
      await _processOrdered(ordered);
      if (_collectMetrics) {
        _metrics.incFlushes();
        _loggingService.captureEvent(
          _metrics.buildFlushLog(retriesPending: _retryTracker.size()),
          domain: 'MATRIX_SYNC_V2',
          subDomain: 'metrics',
        );
      }
    } catch (err, st) {
      // Restore pending queue to avoid losing events if processing failed.
      _pending.insertAll(0, queue);
      _loggingService.captureException(
        err,
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'flush',
        stackTrace: st,
      );
    }
  }

  Future<void> _processOrdered(List<Event> ordered) async {
    final room = _roomManager.currentRoom;
    if (room == null || ordered.isEmpty) return;

    // Circuit breaker: if open, skip processing and schedule a follow-up scan.
    final nowStart = _now();
    final remaining = _circuit.remainingCooldown(nowStart);
    if (remaining != null) {
      _liveScanTimer?.cancel();
      _liveScanTimer = Timer(remaining, () {
        unawaited(_scanLiveTimeline());
      });
      return;
    }

    // First pass: prefetch attachments for remote events.
    var sawAttachmentPrefetch = false; // true only if a new file was written
    for (final e in ordered) {
      // Always record descriptors when a relativePath is present, even if the
      // SDK doesn't classify it as an attachment (robust to MIME quirks).
      final rpAny = e.content['relativePath'];
      if (rpAny is String && rpAny.isNotEmpty) {
        _attachmentIndex?.record(e);
        if (_collectMetrics) {
          // Count an attachment observed and record path for diagnostics.
          _metrics
            ..incPrefetch()
            ..addLastPrefetched(rpAny);
        }
        try {
          final mime = e.attachmentMimetype;
          final content = e.content;
          final hasUrl = content.containsKey('url') ||
              content.containsKey('mxc') ||
              content.containsKey('mxcUrl') ||
              content.containsKey('uri');
          final hasEnc = content.containsKey('file');
          final msgType = content['msgtype'];
          _loggingService.captureEvent(
            'attachmentEvent id=${e.eventId} path=$rpAny mime=$mime msgtype=$msgType hasUrl=$hasUrl hasFile=$hasEnc',
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'attachment.observe',
          );
        } catch (_) {
          // best-effort logging
        }
        if (_pendingJsonPaths.remove(rpAny)) {
          unawaited(_scanLiveTimeline());
        }
      }

      // For metrics and optional background media download, continue using the
      // classifier's attachment predicate (media only).
      if (ec.MatrixEventClassifier.shouldPrefetchAttachment(
          e, _client.userID)) {
        try {
          final wrote = await saveAttachment(
            e,
            loggingService: _loggingService,
            documentsDirectory: _documentsDirectory,
          );
          final rp = e.content['relativePath'];
          if (wrote && rp is String && rp.isNotEmpty) {
            if (_pendingJsonPaths.remove(rp)) {
              unawaited(_scanLiveTimeline());
            }
          }
          if (wrote) sawAttachmentPrefetch = true;
        } catch (err, st) {
          _loggingService.captureException(
            err,
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'prefetch',
            stackTrace: st,
          );
          if (_collectMetrics) _metrics.incFailures();
          // Continue with the next event; do not abort the batch on prefetch failures.
        }
      }

      // Perform actual background download only for media (not JSON).
      if (ec.MatrixEventClassifier.shouldPrefetchAttachment(
          e, _client.userID)) {
        try {
          final wrote = await saveAttachment(
            e,
            loggingService: _loggingService,
            documentsDirectory: _documentsDirectory,
          );
          final rp = e.content['relativePath'];
          if (wrote && rp is String && rp.isNotEmpty) {
            // If this path was pending during apply and we just wrote it,
            // trigger an immediate scan now that the attachment exists.
            if (_pendingJsonPaths.remove(rp)) {
              unawaited(_scanLiveTimeline());
            }
          }
          if (wrote) sawAttachmentPrefetch = true;
        } catch (err, st) {
          _loggingService.captureException(
            err,
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'prefetch',
            stackTrace: st,
          );
          if (_collectMetrics) _metrics.incFailures();
          // Continue with the next event; do not abort the batch on prefetch failures.
        }
      }
    }

    // Second pass: process text events and compute advancement.
    String? latestEventId;
    num? latestTs;
    var blockedByFailure = false;
    var hadFailure = false;
    var batchFailures = 0;
    DateTime? earliestNextDue;
    var syncPayloadEventsSeen = 0;
    for (final e in ordered) {
      final ts = TimelineEventOrdering.timestamp(e);
      final id = e.eventId;
      final content = e.content;
      var processedOk = true;
      var treatAsHandled =
          false; // allow advancement even if skipped by retry cap
      var isSyncPayloadEvent = false;

      if (ec.MatrixEventClassifier.isSyncPayloadEvent(e) &&
          content['msgtype'] == syncMessageType) {
        isSyncPayloadEvent = true;
        syncPayloadEventsSeen++;
        final outcome = await _processSyncPayloadEvent(e);
        processedOk = outcome.processedOk;
        treatAsHandled = outcome.treatAsHandled;
        if (outcome.hadFailure) hadFailure = true;
        if (outcome.failureDelta > 0) batchFailures += outcome.failureDelta;
        if (outcome.nextDue != null &&
            (earliestNextDue == null ||
                outcome.nextDue!.isBefore(earliestNextDue))) {
          earliestNextDue = outcome.nextDue;
        }
      } else {
        // Fallback: attempt to decode base64 JSON and detect a SyncMessage.
        final validFallback = ec.MatrixEventClassifier.isSyncPayloadEvent(e) &&
            content['msgtype'] != syncMessageType;

        if (validFallback) {
          isSyncPayloadEvent = true;
          syncPayloadEventsSeen++;
          final outcome = await _processSyncPayloadEvent(
            e,
            dropSuffix: ' (no-msgtype)',
          );
          processedOk = outcome.processedOk;
          treatAsHandled = outcome.treatAsHandled;
          if (outcome.hadFailure) hadFailure = true;
          if (outcome.failureDelta > 0) batchFailures += outcome.failureDelta;
          if (outcome.nextDue != null &&
              (earliestNextDue == null ||
                  outcome.nextDue!.isBefore(earliestNextDue))) {
            earliestNextDue = outcome.nextDue;
          }
          if (processedOk && _collectMetrics) {
            _loggingService.captureEvent(
              'v2 processed via no-msgtype fallback: $id',
              domain: 'MATRIX_SYNC_V2',
              subDomain: 'fallback',
            );
          }
        } else {
          // Do not count attachment events as "skipped" — they are part of
          // the sync flow and are already tracked via the `prefetch` metric.
          if (!ec.MatrixEventClassifier.isAttachment(e)) {
            if (_collectMetrics) _metrics.incSkipped();
          }
        }
      }
      if (!processedOk && !treatAsHandled) {
        blockedByFailure = true;
      }
      if (!blockedByFailure &&
          (processedOk || treatAsHandled) &&
          isSyncPayloadEvent &&
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
      final shouldAdvance = msh.shouldAdvanceMarker(
        candidateTimestamp: latestTs,
        candidateEventId: latestEventId,
        lastTimestamp: _lastProcessedTs,
        lastEventId: _lastProcessedEventId,
      );
      if (shouldAdvance) {
        _lastProcessedEventId = latestEventId;
        _lastProcessedTs = latestTs;
        // Persist locally immediately to avoid losing progress if the app
        // backgrounds or exits before the debounced remote flush fires.
        try {
          await setLastReadMatrixEventId(latestEventId, _settingsDb);
          _loggingService.captureEvent(
            'marker.local id=$latestEventId',
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'marker.local',
          );
          await setLastReadMatrixEventTs(latestTs.toInt(), _settingsDb);
          _loggingService.captureEvent(
            'marker.local.ts ts=${latestTs.toInt()}',
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'marker.local',
          );
        } catch (e, st) {
          _loggingService.captureException(
            e,
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'marker.local',
            stackTrace: st,
          );
        }
        _readMarkerManager.schedule(room, latestEventId);
        _circuit.reset(); // reset on successful advancement
        // Nudge a quick tail rescan to catch immediately subsequent events
        // that may have landed while we were applying this batch.
        _liveScanTimer?.cancel();
        _liveScanTimer = Timer(const Duration(milliseconds: 100), () {
          unawaited(_scanLiveTimeline());
        });
      }
    }

    // If we encountered retriable failures (e.g., attachments not yet
    // available), schedule a follow-up scan to pick them up shortly.
    if (hadFailure) {
      final openedNow = _circuit.recordFailures(batchFailures, _now());
      if (openedNow) {
        if (_collectMetrics) _metrics.incCircuitOpens();
        _loggingService.captureEvent(
          'circuit open for ${_circuitCooldown.inSeconds}s',
          domain: 'MATRIX_SYNC_V2',
          subDomain: 'circuit',
        );
      }
      final now = _now();
      final delay = msh.computeNextScanDelay(now, earliestNextDue);
      _liveScanTimer?.cancel();
      _liveScanTimer = Timer(delay, () {
        unawaited(_scanLiveTimeline());
      });
    } else if (latestEventId == null &&
        (sawAttachmentPrefetch || syncPayloadEventsSeen > 0)) {
      // Defensive: if we saw activity but could not advance and had no explicit
      // failures, schedule a small tail rescan to catch ordering edge-cases.
      if (syncPayloadEventsSeen == 0 && sawAttachmentPrefetch) {
        final now = _now();
        final last = _lastAttachmentOnlyRescanAt;
        if (last == null ||
            now.difference(last) >= _minAttachmentOnlyRescanGap) {
          _lastAttachmentOnlyRescanAt = now;
          _loggingService.captureEvent(
            'no advancement; scheduling tail rescan (attachments=$sawAttachmentPrefetch, syncEvents=$syncPayloadEventsSeen)',
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'noAdvance.rescan',
          );
          _liveScanTimer?.cancel();
          _liveScanTimer = Timer(const Duration(milliseconds: 150), () {
            unawaited(_scanLiveTimeline());
          });
        }
      } else {
        _loggingService.captureEvent(
          'no advancement; scheduling tail rescan (attachments=$sawAttachmentPrefetch, syncEvents=$syncPayloadEventsSeen)',
          domain: 'MATRIX_SYNC_V2',
          subDomain: 'noAdvance.rescan',
        );
        _liveScanTimer?.cancel();
        _liveScanTimer = Timer(const Duration(milliseconds: 150), () {
          unawaited(_scanLiveTimeline());
        });
      }
    }

    // Double-scan when attachments were prefetched: run an immediate scan and
    // a second scan shortly after to catch text events that may land after the
    // attachment in the SDK's live list.
    if (sawAttachmentPrefetch) {
      _loggingService.captureEvent(
        'doubleScan.attachment immediate',
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'doubleScan',
      );
      unawaited(_scanLiveTimeline());
      _liveScanTimer?.cancel();
      _liveScanTimer = Timer(const Duration(milliseconds: 200), () {
        _loggingService.captureEvent(
          'doubleScan.attachment delayed',
          domain: 'MATRIX_SYNC_V2',
          subDomain: 'doubleScan',
        );
        unawaited(_scanLiveTimeline());
      });
    }

    // Prune retry state map to avoid unbounded growth.
    _retryTracker.prune(_now());
  }

  Map<String, int> metricsSnapshot() => _metrics.snapshot(
        retryStateSize: _retryTracker.size(),
        circuitIsOpen: _circuit.isOpen(_now()),
      );

  // Called by SyncEventProcessor via observer to record DB apply results
  void reportDbApplyDiagnostics(SyncApplyDiagnostics diag) {
    try {
      final rows = diag.rowsAffected;
      final status = diag.conflictStatus;
      final rt = diag.payloadType;
      if (rows > 0) {
        _metrics.incDbApplied();
      } else if (status.contains('concurrent')) {
        _metrics.incConflictsCreated();
      } else {
        _metrics.incDbIgnoredByVectorClock();
      }
      // Also attribute to type-specific drops if ignored
      if (rows == 0 && !status.contains('concurrent')) {
        final isMissingBase = status.contains('b_gt_a');
        if (isMissingBase) {
          _metrics.incDbMissingBase();
          _missingBaseEventIds.add(diag.eventId);
          // Record in diagnostics ring buffer
          final entry = '${diag.eventId}:missingBase';
          _metrics.addLastIgnored(entry);
        } else {
          // older/equal – count as dropped by type
          _bumpDroppedType(rt);
          final reason = msh.ignoredReasonFromStatus(status);
          final entry = '${diag.eventId}:$reason';
          _metrics.addLastIgnored(entry);
        }
      }
    } catch (_) {
      // best-effort only
    }
  }

  // Visible for testing only
  @visibleForTesting
  bool get debugCollectMetrics => _collectMetrics;

  // Additional textual diagnostics not represented in numeric metrics.
  Map<String, String> diagnosticsStrings() {
    final map = <String, String>{
      'lastIgnoredCount': _metrics.lastIgnored.length.toString(),
      'lastPrefetchedCount': _metrics.lastPrefetched.length.toString(),
    };
    for (var i = 0; i < _metrics.lastIgnored.length; i++) {
      map['lastIgnored.${i + 1}'] = _metrics.lastIgnored[i];
    }
    for (var i = 0; i < _metrics.lastPrefetched.length; i++) {
      map['lastPrefetched.${i + 1}'] = _metrics.lastPrefetched[i];
    }
    return map;
  }

  // Force a rescan and optional catch-up to recover from potential gaps
  Future<void> forceRescan({bool includeCatchUp = true}) async {
    try {
      if (includeCatchUp) {
        await _attachCatchUp();
      }
      await _scanLiveTimeline();
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'forceRescan',
        stackTrace: st,
      );
    }
  }

  // Force all pending retries to be immediately due and trigger a scan.
  Future<void> retryNow() async {
    try {
      if (_retryTracker.size() == 0) return;
      final now = _now();
      _retryTracker.markAllDueNow(now);
      await _scanLiveTimeline();
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'retryNow',
        stackTrace: st,
      );
    }
  }

  // Debug helpers removed in favor of metricsSnapshot() fields.
}
