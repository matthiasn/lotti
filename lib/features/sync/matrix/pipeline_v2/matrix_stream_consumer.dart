import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/last_read.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_pipeline.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/attachment_ingestor.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/catch_up_strategy.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/descriptor_catch_up_manager.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/matrix_event_classifier.dart'
    as ec;
import 'package:lotti/features/sync/matrix/pipeline_v2/matrix_stream_helpers.dart'
    as msh;
import 'package:lotti/features/sync/matrix/pipeline_v2/metrics_counters.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/read_marker_manager.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/retry_and_circuit.dart'
    as rc;
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
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
    Duration flushInterval = const Duration(milliseconds: 150),
    int maxBatch = 200,
    Duration markerDebounce = const Duration(milliseconds: 300),
    int? maxRetriesPerEvent,
    Duration circuitCooldown = const Duration(seconds: 30),
    // Live-scan look-behind tuning (test seams)
    bool liveScanIncludeLookBehind = true,
    int liveScanInitialAuditScans = 5,
    int? liveScanInitialAuditTail,
    int liveScanSteadyTail = 100,
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
        _flushInterval = flushInterval,
        _maxBatch = maxBatch,
        _markerDebounce = markerDebounce,
        _backfill = backfill,
        _maxRetriesPerEvent = maxRetriesPerEvent ?? 5,
        _retryTtl = const Duration(minutes: 10),
        _retryMaxEntries = 2000,
        _circuitFailureThreshold = 50,
        _circuitCooldown = circuitCooldown,
        _liveScanIncludeLookBehind = liveScanIncludeLookBehind,
        _liveScanSteadyTail = liveScanSteadyTail,
        _overrideAuditTail = liveScanInitialAuditTail,
        _liveScanAuditScansRemaining = liveScanInitialAuditScans {
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
    // Initialize descriptor catch-up manager to proactively discover
    // attachment descriptors for pending jsonPaths.
    if (_attachmentIndex != null) {
      _descriptorCatchUp = DescriptorCatchUpManager(
        logging: _loggingService,
        attachmentIndex: _attachmentIndex!,
        roomManager: _roomManager,
        scheduleLiveScan: _scheduleLiveScan,
        retryNow: retryNow,
        now: clock.now,
      );
    }
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
  // Captured at initialize() for attach-time anchoring and sizing initial
  // audit tails. These represent the persisted "last sync" marker when we
  // start this session, before we process any new events.
  String? _startupLastProcessedEventId;
  num? _startupLastProcessedTs;
  final List<Event> _pending = <Event>[];
  Timer? _flushTimer;
  Timer? _liveScanTimer;
  Timer? _initialCatchUpRetryTimer;
  DateTime? _initialCatchUpStartAt;
  int _initialCatchUpAttempts = 0;
  bool _initialCatchUpCompleted = false;
  bool _firstStreamEventCatchUpTriggered = false;
  final Duration _flushInterval;
  final int _maxBatch;
  final Duration _markerDebounce;
  // Catch-up window is handled by strategy with sensible defaults.

  late final MetricsCounters _metrics;
  // Descriptor-focused catch-up helper (manages pending jsonPaths)
  DescriptorCatchUpManager? _descriptorCatchUp;
  DateTime? _lastAttachmentOnlyRescanAt;
  static const Duration _minAttachmentOnlyRescanGap =
      Duration(milliseconds: 500);
  static const int _liveScanTailLimit = 50;
  static const Duration _attachmentTsGate = Duration(seconds: 2);
  // Live-scan look-behind policy. Can be tuned via constructor (test seams).
  final bool _liveScanIncludeLookBehind;
  int _liveScanAuditScansRemaining;
  int _liveScanAuditTail =
      300; // sized later based on offline delta or override
  final int _liveScanSteadyTail;
  final int? _overrideAuditTail; // optional override for tests

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

  // Recent eventId LRU to suppress duplicate first-pass work for attachments
  // across overlapping ingestion paths (client stream + live timeline).
  final Set<String> _seenEventIds = <String>{};
  final Queue<String> _seenEventOrder = Queue<String>();
  static const int _seenEventCapacity = 5000;

  // Descriptor-related catch-up logic now lives in DescriptorCatchUpManager.

  bool _isDuplicateAndRecordSeen(String id) {
    if (_seenEventIds.contains(id)) return true;
    _seenEventIds.add(id);
    _seenEventOrder.addLast(id);
    while (_seenEventOrder.length > _seenEventCapacity) {
      final oldest = _seenEventOrder.removeFirst();
      _seenEventIds.remove(oldest);
    }
    return false;
  }

  // Tracks sync payload events that have completed processing to avoid
  // duplicate apply work across overlapping ingestion paths.
  final Set<String> _completedSyncIds = <String>{};
  final Queue<String> _completedSyncOrder = Queue<String>();
  static const int _completedSyncCapacity = 5000;

  bool _wasCompletedSync(String id) => _completedSyncIds.contains(id);
  void _recordCompletedSync(String id) {
    if (_completedSyncIds.add(id)) {
      _completedSyncOrder.addLast(id);
      while (_completedSyncOrder.length > _completedSyncCapacity) {
        final oldest = _completedSyncOrder.removeFirst();
        _completedSyncIds.remove(oldest);
      }
    }
  }

  // Tracks sync payload eventIds currently processing to avoid duplicate
  // applies across overlapping ingestion paths.
  final Set<String> _inFlightSyncIds = <String>{};

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
    final now = clock.now();
    final blockedUntil = _retryTracker.blockedUntil(id, now);

    if (blockedUntil != null) {
      processedOk = false;
      hadFailure = true;
      nextDue = blockedUntil;
    }

    final attempts = _retryTracker.attempts(id);
    if (attempts >= _maxRetriesPerEvent) {
      // Special-case: if this event is blocked by a missing attachment
      // descriptor (jsonPath tracked in _pendingJsonPaths), keep retrying and
      // do not treat as handled. This aligns with intended behavior to block
      // advancement until descriptors land.
      final jpAtCap = _extractJsonPath(e);
      final isMissingAtCap =
          jpAtCap != null && (_descriptorCatchUp?.contains(jpAtCap) ?? false);
      if (isMissingAtCap) {
        processedOk = false;
        hadFailure = true;
        final nextAttempts = attempts + 1;
        final backoff = _computeBackoff(nextAttempts);
        final due = clock.now().add(backoff);
        _retryTracker.scheduleNext(id, nextAttempts, due);
        nextDue = due;
        _loggingService.captureEvent(
          'missingAttachment keepRetrying: $id (attempts=$nextAttempts)',
          domain: 'MATRIX_SYNC_V2',
          subDomain: 'retry.missingAttachment',
        );
        if (_collectMetrics) _metrics.incRetriesScheduled();
      } else {
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
          final due = clock.now().add(backoff);
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
        final due = clock.now().add(backoff);
        // If this looks like a missing attachment/descriptor scenario, keep the
        // event blocking and do not advance the marker even after the retry cap.
        // We detect this via a FileSystemException earlier, which records the
        // jsonPath into _pendingJsonPaths. When present, continue scheduling
        // retries and avoid marking as handled.
        final jp = _extractJsonPath(e);
        final isMissingAttachment =
            jp != null && (_descriptorCatchUp?.contains(jp) ?? false);
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
            _descriptorCatchUp?.addPending(jp);
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
    // Capture startup marker for attach-time anchoring and log it for visibility.
    _startupLastProcessedEventId = _lastProcessedEventId;
    _startupLastProcessedTs = _lastProcessedTs;
    _loggingService.captureEvent(
      'startup.marker id=${_startupLastProcessedEventId ?? 'null'} ts=${_startupLastProcessedTs?.toInt() ?? 'null'}',
      domain: 'MATRIX_SYNC_V2',
      subDomain: 'startup.marker',
    );
    _initialized = true;
  }

  @override
  Future<void> start() async {
    // Ensure room snapshot exists, then run an initial catch‑up BEFORE any
    // live scans or marker advancement to avoid skipping backlog.
    if (_roomManager.currentRoom == null) {
      final hydrateStart = clock.now();
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
      // Wait deterministically for room readiness with a bounded timeout.
      // Total wait ~10s (50 × 200ms). This avoids races where the live scan
      // would start before the room becomes available and skip backlog.
      for (var i = 0; i < 50 && _roomManager.currentRoom == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      final hydrateElapsed = clock.now().difference(hydrateStart).inMilliseconds;
      _loggingService.captureEvent(
        'start.hydrateRoom.ready=${_roomManager.currentRoom != null} after ${hydrateElapsed}ms',
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'start',
      );
    }
    // Attempt catch‑up only when we have an active room; otherwise we'll rely
    // on the later scheduled retry once the room is ready.
    if (_roomManager.currentRoom != null) {
      await _attachCatchUp();
    }
    // Ensure we eventually run initial catch‑up even if the room was not yet
    // ready — schedule a retry loop that cancels itself once catch‑up runs.
    if (_roomManager.currentRoom == null) {
      _scheduleInitialCatchUpRetry();
    }
    await _sub?.cancel();
    _sub = _sessionManager.timelineEvents.listen((event) {
      final roomId = _roomManager.currentRoomId;
      if (roomId == null || event.roomId != roomId) return;
      if (!_initialCatchUpCompleted && !_firstStreamEventCatchUpTriggered) {
        _firstStreamEventCatchUpTriggered = true;
        _loggingService.captureEvent(
          'catchup.trigger.onFirstStreamEvent',
          domain: 'MATRIX_SYNC_V2',
          subDomain: 'catchup',
        );
        // Attempt a catch-up + live scan in the background.
        unawaited(forceRescan());
      }
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
        // Size the initial audit tail based on offline delta (or override).
        _liveScanAuditTail =
            _overrideAuditTail ?? _computeAuditTailCountByDelta();
        // Proactively scan once at startup, now that initial catch‑up has run
        // (or been attempted) to avoid skipping backlog.
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
    _initialCatchUpRetryTimer?.cancel();
    _readMarkerManager.dispose();
    _descriptorCatchUp?.dispose();
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
      _loggingService.captureEvent(
        'catchup.start lastEventId=${_lastProcessedEventId ?? 'null'}',
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'catchup',
      );
      final preSinceTs = _startupLastProcessedTs == null
          ? null
          : (_startupLastProcessedTs!.toInt() - 1000); // small skew buffer
      final slice = await CatchUpStrategy.collectEventsForCatchUp(
        room: room,
        lastEventId: _lastProcessedEventId,
        backfill: _backfill ?? SdkPaginationCompat.backfillUntilContains,
        logging: _loggingService,
        // Ensure we also include a bounded pre-context since the stored last
        // sync timestamp, escalating pagination as needed.
        preContextSinceTs: preSinceTs,
        preContextCount: 300,
        maxLookback: 8000,
      );
      _loggingService.captureEvent(
        'catchup.done events=${slice.length}',
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'catchup',
      );
      if (slice.isNotEmpty) {
        if (_collectMetrics) _metrics.incCatchupBatches();
        await _processOrdered(slice);
      }
      // Initial catch-up attempt considered completed (even if empty). Cancel any pending retries.
      _initialCatchUpRetryTimer?.cancel();
      _initialCatchUpRetryTimer = null;
      _initialCatchUpCompleted = true;
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'catchup',
        stackTrace: st,
      );
    }
  }

  void _scheduleInitialCatchUpRetry() {
    _initialCatchUpRetryTimer?.cancel();
    final start = _initialCatchUpStartAt ?? clock.now();
    _initialCatchUpStartAt = start;
    final elapsed = clock.now().difference(start);
    // Give up after ~15 minutes of trying; logs will indicate timeout.
    const maxWait = Duration(minutes: 15);
    if (elapsed >= maxWait) {
      _loggingService.captureEvent(
        'catchup.timeout after ${elapsed.inSeconds}s',
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'catchup',
      );
      return;
    }
    // Exponential backoff starting at 200ms, capping at 10s, no jitter.
    final delay = tu.computeExponentialBackoff(
      _initialCatchUpAttempts,
    );
    _initialCatchUpAttempts++;
    _initialCatchUpRetryTimer = Timer(delay, () {
      if (_initialCatchUpCompleted) return;
      if (_roomManager.currentRoom != null) {
        // Attempt catch-up and ensure we continue retrying until it marks
        // completion. Capture and log errors before rescheduling.
        _attachCatchUp().then((_) {
          if (!_initialCatchUpCompleted) {
            _loggingService.captureEvent(
              'catchup.retry.reschedule (not completed)',
              domain: 'MATRIX_SYNC_V2',
              subDomain: 'catchup',
            );
            _scheduleInitialCatchUpRetry();
          }
        }).catchError((Object error, StackTrace st) {
          _loggingService.captureException(
            error,
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'catchup.retry',
            stackTrace: st,
          );
          _scheduleInitialCatchUpRetry();
        });
      } else {
        _loggingService.captureEvent(
          'waiting for room for initial catch-up (attempt=$_initialCatchUpAttempts, delay=${delay.inMilliseconds}ms)',
          domain: 'MATRIX_SYNC_V2',
          subDomain: 'catchup',
        );
        _scheduleInitialCatchUpRetry();
      }
    });
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
      // Build the normal strictly-after slice (no timestamp gating for
      // payload discovery; gating applies only to attachment prefetch).
      final afterSlice = msh.buildLiveScanSlice(
        timelineEvents: tl.events,
        lastEventId: _lastProcessedEventId,
        tailLimit: _liveScanTailLimit,
        lastTimestamp: null,
        tsGate: _attachmentTsGate,
      );
      List<Event> combined;
      if (_liveScanIncludeLookBehind) {
        // Merge bounded look-behind tail.
        var tail = _liveScanSteadyTail;
        if (_liveScanAuditScansRemaining > 0) {
          tail = _liveScanAuditTail;
          _liveScanAuditScansRemaining--;
        }
        final tailSlice = msh.buildLiveScanSlice(
          timelineEvents: tl.events,
          lastEventId: null,
          tailLimit: tail,
          lastTimestamp: null,
          tsGate: _attachmentTsGate,
        );
        if (_collectMetrics) {
          _metrics.recordLookBehindMerge(tail);
        }
        combined = [...afterSlice, ...tailSlice]
          ..sort(TimelineEventOrdering.compare);
      } else {
        combined = [...afterSlice]..sort(TimelineEventOrdering.compare);
      }
      final deduped = tu.dedupEventsByIdPreserveOrder(combined);
      if (deduped.isNotEmpty) {
        await _processOrdered(deduped);
        if (_collectMetrics) {
          _loggingService.captureEvent(
            'v2 liveScan processed=${deduped.length} latest=${_lastProcessedEventId ?? 'null'}',
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

  int _computeAuditTailCountByDelta() {
    final ts = _startupLastProcessedTs;
    if (ts == null) return 200;
    final nowMs = clock.now().millisecondsSinceEpoch;
    final deltaMs = nowMs - ts.toInt();
    final deltaH = deltaMs / (1000 * 60 * 60);
    if (deltaH >= 48) return 400;
    if (deltaH >= 12) return 300;
    return 200;
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
    final nowStart = clock.now();
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
    const ingestor = AttachmentIngestor();
    for (final e in ordered) {
      // Skip duplicate attachment work if we've already seen this eventId.
      // Keep processing for sync payload events to ensure apply/retry semantics.
      final dup = _isDuplicateAndRecordSeen(e.eventId);
      if (dup && ec.MatrixEventClassifier.isAttachment(e)) {
        continue; // skip record/observe/prefetch for duplicate attachments
      }
      // Also skip re-applying the same sync payload event if it already
      // completed on another ingestion path.
      if (dup && ec.MatrixEventClassifier.isSyncPayloadEvent(e)) {
        if (_wasCompletedSync(e.eventId)) {
          continue;
        }
      }
      // Centralize descriptor record + optional media prefetch logic.
      final wrote = await ingestor.process(
        event: e,
        logging: _loggingService,
        documentsDirectory: _documentsDirectory,
        attachmentIndex: _attachmentIndex,
        collectMetrics: _collectMetrics,
        metrics: _metrics,
        lastProcessedTs: _lastProcessedTs,
        attachmentTsGate: _attachmentTsGate,
        currentUserId: _client.userID,
        descriptorCatchUp: _descriptorCatchUp,
        scheduleLiveScan: _scheduleLiveScan,
        retryNow: retryNow,
      );
      if (wrote) sawAttachmentPrefetch = true;

      // (prefetch handled above)
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

      // If this looks like a sync payload and another ingestion path is already
      // processing it, skip to avoid duplicate applies.
      final isPotentialSync = ec.MatrixEventClassifier.isSyncPayloadEvent(e);
      if (isPotentialSync && _inFlightSyncIds.contains(id)) {
        // Defer; the completing path will record completion and advancement.
        continue;
      }

      if (ec.MatrixEventClassifier.isSyncPayloadEvent(e) &&
          content['msgtype'] == syncMessageType) {
        isSyncPayloadEvent = true;
        syncPayloadEventsSeen++;
        _inFlightSyncIds.add(id);
        try {
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
        } finally {
          _inFlightSyncIds.remove(id);
        }
      } else {
        // Fallback: attempt to decode base64 JSON and detect a SyncMessage.
        final validFallback = ec.MatrixEventClassifier.isSyncPayloadEvent(e) &&
            content['msgtype'] != syncMessageType;

        if (validFallback) {
          isSyncPayloadEvent = true;
          syncPayloadEventsSeen++;
          _inFlightSyncIds.add(id);
          try {
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
          } finally {
            _inFlightSyncIds.remove(id);
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
      // Record completed sync payloads to suppress duplicate applies across
      // overlapping ingestion paths (e.g., live scan + client stream).
      if ((processedOk || treatAsHandled) && isSyncPayloadEvent) {
        _recordCompletedSync(id);
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
      final openedNow = _circuit.recordFailures(batchFailures, clock.now());
      if (openedNow) {
        if (_collectMetrics) _metrics.incCircuitOpens();
        _loggingService.captureEvent(
          'circuit open for ${_circuitCooldown.inSeconds}s',
          domain: 'MATRIX_SYNC_V2',
          subDomain: 'circuit',
        );
      }
      final now = clock.now();
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
        final now = clock.now();
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
    _retryTracker.prune(clock.now());
  }

  Map<String, int> metricsSnapshot() => _metrics.snapshot(
        retryStateSize: _retryTracker.size(),
        circuitIsOpen: _circuit.isOpen(clock.now()),
      )
        ..putIfAbsent(
            'pendingJsonPaths', () => _descriptorCatchUp?.pendingLength ?? 0)
        ..putIfAbsent(
            'descriptorCatchUpRuns', () => _descriptorCatchUp?.runs ?? 0);

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
      _loggingService.captureEvent(
        'forceRescan.start includeCatchUp=$includeCatchUp',
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'forceRescan',
      );
      if (includeCatchUp) {
        await _attachCatchUp();
      }
      await _scanLiveTimeline();
      _loggingService.captureEvent(
        'forceRescan.done includeCatchUp=$includeCatchUp',
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'forceRescan',
      );
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
      final now = clock.now();
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
