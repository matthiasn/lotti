import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/last_read.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_index.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_ingestor.dart';
import 'package:lotti/features/sync/matrix/pipeline/descriptor_catch_up_manager.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_event_classifier.dart'
    as ec;
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_helpers.dart'
    as msh;
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';
import 'package:lotti/features/sync/matrix/pipeline/read_marker_manager.dart';
import 'package:lotti/features/sync/matrix/pipeline/retry_and_circuit.dart'
    as rc;
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/features/sync/matrix/utils/timeline_utils.dart' as tu;
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

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

class MatrixStreamProcessor {
  MatrixStreamProcessor({
    required SyncRoomManager roomManager,
    required LoggingService loggingService,
    required JournalDb journalDb,
    required SettingsDb settingsDb,
    required SyncEventProcessor eventProcessor,
    required SyncReadMarkerService readMarkerService,
    required SentEventRegistry sentEventRegistry,
    required Client Function() clientProvider,
    required Timeline? Function() liveTimelineProvider,
    AttachmentIndex? attachmentIndex,
    MetricsCounters? metricsCounters,
    bool collectMetrics = false,
    Duration markerDebounce = const Duration(milliseconds: 300),
    int? maxRetriesPerEvent,
    Duration circuitCooldown = const Duration(seconds: 30),
    Directory? documentsDirectory,
  })  : _roomManager = roomManager,
        _loggingService = loggingService,
        _journalDb = journalDb,
        _settingsDb = settingsDb,
        _eventProcessor = eventProcessor,
        _readMarkerService = readMarkerService,
        _sentEventRegistry = sentEventRegistry,
        _clientProvider = clientProvider,
        _liveTimelineProvider = liveTimelineProvider,
        _attachmentIndex = attachmentIndex,
        _collectMetrics = collectMetrics,
        _metrics = metricsCounters ?? MetricsCounters(collect: collectMetrics),
        _markerDebounce = markerDebounce,
        _maxRetriesPerEvent = maxRetriesPerEvent ?? 5,
        _retryTtl = const Duration(minutes: 10),
        _retryMaxEntries = 2000,
        _circuitFailureThreshold = 50,
        _circuitCooldown = circuitCooldown,
        _ingestor = AttachmentIngestor(documentsDirectory: documentsDirectory) {
    _retryTracker = rc.RetryTracker(
      ttl: _retryTtl,
      maxEntries: _retryMaxEntries,
    );
    _circuit = rc.CircuitBreaker(
      failureThreshold: _circuitFailureThreshold,
      cooldown: _circuitCooldown,
    );
    _eventProcessor.cachePurgeListener = _metrics.incStaleAttachmentPurges;
    _readMarkerManager = ReadMarkerManager(
      debounce: _markerDebounce,
      onFlush: (Room room, String id) => _readMarkerService.updateReadMarker(
        client: _clientProvider(),
        room: room,
        eventId: id,
        timeline: _liveTimelineProvider(),
      ),
      logging: _loggingService,
    );
  }

  final SyncRoomManager _roomManager;
  final LoggingService _loggingService;
  final JournalDb _journalDb;
  final SettingsDb _settingsDb;
  final SyncEventProcessor _eventProcessor;
  final SyncReadMarkerService _readMarkerService;
  final SentEventRegistry _sentEventRegistry;
  final Client Function() _clientProvider;
  final Timeline? Function() _liveTimelineProvider;
  final AttachmentIndex? _attachmentIndex;
  final bool _collectMetrics;
  final MetricsCounters _metrics;
  final Duration _markerDebounce;
  final int _maxRetriesPerEvent;
  final Duration _retryTtl;
  final int _retryMaxEntries;
  final int _circuitFailureThreshold;
  final Duration _circuitCooldown;
  final AttachmentIngestor _ingestor;
  late final rc.CircuitBreaker _circuit;
  late final rc.RetryTracker _retryTracker;
  late final ReadMarkerManager _readMarkerManager;

  DescriptorCatchUpManager? _descriptorCatchUp;
  void Function()? _scheduleLiveScan;
  Future<void> Function()? _scanLiveTimeline;
  void Function(Duration delay)? _scheduleRescan;

  String? _lastProcessedEventId;
  num? _lastProcessedTs;

  // Tracks eventIds that reported rows=0 while predicted status suggests
  // incoming is newer (missing base). These should be retried and block
  // advancement in the current batch.
  final Set<String> _missingBaseEventIds = <String>{};

  // Recent eventId LRU to suppress duplicate first-pass work for attachments
  // across overlapping ingestion paths (client stream + live timeline).
  final Set<String> _seenEventIds = <String>{};
  final Queue<String> _seenEventOrder = Queue<String>();
  static const int _seenEventCapacity = 5000;

  // Tracks sync payload events that have completed processing to avoid
  // duplicate apply work across overlapping ingestion paths.
  final Set<String> _completedSyncIds = <String>{};
  final Queue<String> _completedSyncOrder = Queue<String>();
  static const int _completedSyncCapacity = 5000;

  // Tracks sync payload eventIds currently processing to avoid duplicate
  // applies across overlapping ingestion paths.
  final Set<String> _inFlightSyncIds = <String>{};

  Completer<void>? _processingCompleter;

  MetricsCounters get metrics => _metrics;
  bool get collectMetrics => _collectMetrics;
  String? get lastProcessedEventId => _lastProcessedEventId;
  num? get lastProcessedTs => _lastProcessedTs;

  void setLastProcessed({String? eventId, num? timestamp}) {
    _lastProcessedEventId = eventId;
    _lastProcessedTs = timestamp;
  }

  void configureLiveScanCallbacks({
    required void Function() scheduleLiveScan,
    required Future<void> Function() scanLiveTimeline,
    required void Function(Duration delay) scheduleRescan,
  }) {
    _scheduleLiveScan = scheduleLiveScan;
    _scanLiveTimeline = scanLiveTimeline;
    _scheduleRescan = scheduleRescan;

    if (_attachmentIndex != null && _descriptorCatchUp == null) {
      _descriptorCatchUp = DescriptorCatchUpManager(
        logging: _loggingService,
        attachmentIndex: _attachmentIndex!,
        roomManager: _roomManager,
        scheduleLiveScan: scheduleLiveScan,
        retryNow: retryNow,
        now: clock.now,
      );
    }
  }

  void dispose() {
    _readMarkerManager.dispose();
    _descriptorCatchUp?.dispose();
    _ingestor.dispose();
  }

  bool wasCompletedSync(String id) => _completedSyncIds.contains(id);

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

  void _recordCompletedSync(String id) {
    if (_completedSyncIds.add(id)) {
      _completedSyncOrder.addLast(id);
      while (_completedSyncOrder.length > _completedSyncCapacity) {
        final oldest = _completedSyncOrder.removeFirst();
        _completedSyncIds.remove(oldest);
      }
    }
  }

  Duration _computeBackoff(int attempts) =>
      tu.computeExponentialBackoff(attempts);

  String? _extractRuntimeType(Event ev) => msh.extractRuntimeTypeFromEvent(ev);

  String? _extractJsonPath(Event ev) => msh.extractJsonPathFromEvent(ev);

  void _bumpDroppedType(String? rt) => _metrics.bumpDroppedType(rt);

  Future<_ProcessOutcome> _processSyncPayloadEvent(
    Event e, {
    String dropSuffix = '',
  }) async {
    var processedOk = true;
    const treatAsHandled = false;
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
      // Keep retrying indefinitely - never permanently skip sync payloads.
      // Data loss from skipping is worse than retrying forever.
      processedOk = false;
      hadFailure = true;
      final nextAttempts = attempts + 1;
      final backoff = _computeBackoff(nextAttempts);
      final due = clock.now().add(backoff);
      _retryTracker.scheduleNext(id, nextAttempts, due);
      nextDue = due;
      _loggingService.captureEvent(
        'keepRetrying after cap$dropSuffix: $id (attempts=$nextAttempts)',
        domain: syncLoggingDomain,
        subDomain: 'retry.keepRetrying',
      );
      if (_collectMetrics) _metrics.incRetriesScheduled();
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
            domain: syncLoggingDomain,
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
        // Keep retrying indefinitely - never permanently skip sync payloads.
        // Data loss from skipping is worse than retrying forever.
        _retryTracker.scheduleNext(id, nextAttempts, due);
        nextDue = due;
        _loggingService.captureEvent(
          'keepRetrying$dropSuffix: $id (attempts=$nextAttempts)',
          domain: syncLoggingDomain,
          subDomain: 'retry.keepRetrying',
        );
        if (_collectMetrics) _metrics.incRetriesScheduled();
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
          domain: syncLoggingDomain,
          subDomain: dropSuffix.isEmpty ? 'process' : 'process.fallback',
          stackTrace: st,
        );
        if (_collectMetrics) _metrics.incFailures();
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

  Future<void> processOrdered(List<Event> ordered) async {
    final room = _roomManager.currentRoom;
    if (room == null || ordered.isEmpty) return;

    // Serialize event processing to ensure in-order ingest across all paths.
    // This prevents concurrent catch-up and live scan from processing events
    // out of order, which would cause false positive gap detection.
    if (_processingCompleter != null) {
      _loggingService.captureEvent(
        'processOrdered: waiting for previous batch to complete (${ordered.length} events)',
        domain: syncLoggingDomain,
        subDomain: 'processOrdered.serialize',
      );
      while (_processingCompleter != null) {
        final inFlight = _processingCompleter!;
        await inFlight.future;
      }
    }
    final completer = Completer<void>();
    _processingCompleter = completer;

    try {
      await _processOrderedInternal(ordered, room);
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
      if (identical(_processingCompleter, completer)) {
        _processingCompleter = null;
      }
    }
  }

  Future<void> _processOrderedInternal(List<Event> ordered, Room room) async {
    _sentEventRegistry.prune();
    final suppressedIds = <String>{};

    // Circuit breaker: if open, skip processing and schedule a follow-up scan.
    final nowStart = clock.now();
    final remaining = _circuit.remainingCooldown(nowStart);
    if (remaining != null) {
      _scheduleRescan?.call(remaining);
      return;
    }

    // First pass: observe attachment descriptors for remote events.
    var suppressedCount = 0; // count self-origin/suppressed events
    for (final e in ordered) {
      final eventId = e.eventId;
      // Skip duplicate attachment work if we've already seen this eventId.
      // Keep processing for sync payload events to ensure apply/retry semantics.
      final dup = _isDuplicateAndRecordSeen(eventId);
      final isSelfOrigin = e.senderId == _clientProvider().userID;
      final suppressed = _sentEventRegistry.consume(eventId) || isSelfOrigin;
      if (suppressed) {
        suppressedIds.add(eventId);
        _metrics.incSelfEventsSuppressed();
        suppressedCount++;
        continue;
      }
      if (dup && ec.MatrixEventClassifier.isAttachment(e)) {
        continue; // skip record/observe for duplicate attachments
      }
      // Also skip re-applying the same sync payload event if it already
      // completed on another ingestion path.
      if (dup && ec.MatrixEventClassifier.isSyncPayloadEvent(e)) {
        if (wasCompletedSync(eventId)) {
          continue;
        }
      }
      // Centralize descriptor record and queued download logic.
      await _ingestor.process(
        event: e,
        logging: _loggingService,
        attachmentIndex: _attachmentIndex,
        descriptorCatchUp: _descriptorCatchUp,
        scheduleLiveScan: _scheduleLiveScan ?? () {},
        retryNow: retryNow,
        scheduleDownload: true,
      );
    }

    // Emit a compact summary for suppressed items to avoid log spam.
    if (suppressedCount > 0 && _collectMetrics) {
      _loggingService.captureEvent(
        'selfEventSuppressed.count=$suppressedCount',
        domain: syncLoggingDomain,
        subDomain: 'selfEvent',
      );
    }

    // Second pass: process text events and compute advancement.
    String? latestEventId;
    num? latestTs;
    var blockedByFailure = false;
    var hadFailure = false;
    var batchFailures = 0;
    DateTime? earliestNextDue;
    var syncPayloadEventsSeen = 0;
    var syncPayloadsApplied = 0;
    var syncPayloadsSkippedCompleted = 0;
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
      final wasSuppressed = suppressedIds.contains(id);
      if (!wasSuppressed && isPotentialSync && _inFlightSyncIds.contains(id)) {
        // Defer; the completing path will record completion and advancement.
        continue;
      }

      if (wasSuppressed) {
        isSyncPayloadEvent = isPotentialSync;
        processedOk = true;
        treatAsHandled = true;
      } else if (ec.MatrixEventClassifier.isSyncPayloadEvent(e) &&
          content['msgtype'] == syncMessageType) {
        // Skip already-completed sync events to avoid redundant logging
        // and DB checks.
        if (wasCompletedSync(id)) {
          isSyncPayloadEvent = true;
          processedOk = true;
          treatAsHandled = true;
          syncPayloadsSkippedCompleted++;
        } else {
          isSyncPayloadEvent = true;
          syncPayloadEventsSeen++;
          _inFlightSyncIds.add(id);
          try {
            final outcome = await _processSyncPayloadEvent(e);
            processedOk = outcome.processedOk;
            treatAsHandled = outcome.treatAsHandled;
            if (processedOk) syncPayloadsApplied++;
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
        }
      } else {
        // Fallback: attempt to decode base64 JSON and detect a SyncMessage.
        final validFallback = ec.MatrixEventClassifier.isSyncPayloadEvent(e) &&
            content['msgtype'] != syncMessageType;

        if (validFallback) {
          // Skip already-completed sync events to avoid redundant logging
          // and DB checks.
          if (wasCompletedSync(id)) {
            isSyncPayloadEvent = true;
            processedOk = true;
            treatAsHandled = true;
          } else {
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
              if (outcome.failureDelta > 0) {
                batchFailures += outcome.failureDelta;
              }
              if (outcome.nextDue != null &&
                  (earliestNextDue == null ||
                      outcome.nextDue!.isBefore(earliestNextDue))) {
                earliestNextDue = outcome.nextDue;
              }
              if (processedOk && _collectMetrics) {
                _loggingService.captureEvent(
                  'processed via no-msgtype fallback: $id',
                  domain: syncLoggingDomain,
                  subDomain: 'fallback',
                );
              }
            } finally {
              _inFlightSyncIds.remove(id);
            }
          }
        } else {
          // Do not count attachment events as "skipped" - they are part of
          // the sync flow.
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

    // Log batch processing summary for diagnostics
    _loggingService.captureEvent(
      'batch.summary total=${ordered.length} seen=$syncPayloadEventsSeen applied=$syncPayloadsApplied skippedCompleted=$syncPayloadsSkippedCompleted suppressed=$suppressedCount blocked=$blockedByFailure',
      domain: syncLoggingDomain,
      subDomain: 'batch',
    );

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
          await setLastReadMatrixEventTs(latestTs.toInt(), _settingsDb);
          if (_collectMetrics) {
            _loggingService.captureEvent(
              'marker.local id=$latestEventId ts=${latestTs.toInt()}',
              domain: syncLoggingDomain,
              subDomain: 'marker.local',
            );
          }
        } catch (e, st) {
          _loggingService.captureException(
            e,
            domain: syncLoggingDomain,
            subDomain: 'marker.local',
            stackTrace: st,
          );
        }
        _readMarkerManager.schedule(room, latestEventId);
        _circuit.reset(); // reset on successful advancement
        // Nudge a quick tail rescan to catch immediately subsequent events
        // that may have landed while we were applying this batch.
        _scheduleRescan?.call(const Duration(milliseconds: 100));
      }
    }

    // If we encountered retriable failures (e.g., attachments not yet
    // available), schedule a follow-up scan to pick them up shortly.
    if (hadFailure) {
      final openedNow = _circuit.recordFailures(batchFailures, clock.now());
      if (openedNow) {
        if (_collectMetrics) {
          _metrics.incCircuitOpens();
          _loggingService.captureEvent(
            'circuit open for ${_circuitCooldown.inSeconds}s',
            domain: syncLoggingDomain,
            subDomain: 'circuit',
          );
        }
      }
      final now = clock.now();
      final delay = msh.computeNextScanDelay(now, earliestNextDue);
      _scheduleRescan?.call(delay);
    } else if (latestEventId == null && (syncPayloadEventsSeen > 0)) {
      // Defensive: if we saw activity but could not advance and had no explicit
      // failures, schedule a small tail rescan to catch ordering edge-cases.
      if (_collectMetrics) {
        _loggingService.captureEvent(
          'no advancement; scheduling tail rescan (syncEvents=$syncPayloadEventsSeen)',
          domain: syncLoggingDomain,
          subDomain: 'noAdvance.rescan',
        );
      }
      _scheduleRescan?.call(const Duration(milliseconds: 150));
    }

    // Prune retry state map to avoid unbounded growth.
    _retryTracker.prune(clock.now());
  }

  Map<String, int> metricsSnapshot() {
    final map = _metrics.snapshot(
      retryStateSize: _retryTracker.size(),
      circuitIsOpen: _circuit.isOpen(clock.now()),
    )
      ..putIfAbsent(
          'pendingJsonPaths', () => _descriptorCatchUp?.pendingLength ?? 0)
      ..putIfAbsent(
          'descriptorCatchUpRuns', () => _descriptorCatchUp?.runs ?? 0);
    // Derived metric to assess processing efficiency when metrics collection is
    // enabled. When either value is zero, omit the ratio.
    try {
      final processed = map['processed'] ?? 0;
      final applied = map['dbApplied'] ?? 0;
      if (processed > 0 && applied > 0) {
        final ratio = processed / applied;
        // Store as integer by rounding ratio*100 to preserve ordering in maps;
        // UI can present as text if needed.
        map['processedPerAppliedPct'] = (ratio * 100).round();
      }
    } catch (_) {
      // best-effort only
    }
    return map;
  }

  // Called by SyncEventProcessor via observer to record DB apply results
  void reportDbApplyDiagnostics(SyncApplyDiagnostics diag) {
    try {
      final applied = diag.applied;
      final status = diag.conflictStatus;
      final rt = diag.payloadType;
      if (rt == 'entryLink') {
        if (applied) {
          _metrics.incDbApplied();
        } else {
          _metrics
            ..incDbEntryLinkNoop()
            ..bumpDroppedType('entryLink')
            // Record in diagnostics ring buffer
            ..addLastIgnored('${diag.eventId}:entryLink.noop');
        }
        return;
      }

      if (applied) {
        _metrics.incDbApplied();
        return;
      }

      String labelForSkip(JournalUpdateSkipReason reason) {
        switch (reason) {
          case JournalUpdateSkipReason.olderOrEqual:
            return msh.ignoredReasonFromStatus(status);
          case JournalUpdateSkipReason.conflict:
            return 'conflict';
          case JournalUpdateSkipReason.overwritePrevented:
            return reason.label;
          case JournalUpdateSkipReason.missingBase:
            return reason.label;
        }
      }

      void addIgnored(String label) {
        final entry = '${diag.eventId}:$label';
        _metrics.addLastIgnored(entry);
      }

      switch (diag.skipReason) {
        case JournalUpdateSkipReason.conflict:
          _metrics.incConflictsCreated();
          addIgnored(labelForSkip(JournalUpdateSkipReason.conflict));
        case JournalUpdateSkipReason.missingBase:
          _metrics.incDbMissingBase();
          _missingBaseEventIds.add(diag.eventId);
          addIgnored(labelForSkip(JournalUpdateSkipReason.missingBase));
        case JournalUpdateSkipReason.overwritePrevented:
          _metrics.incDbIgnoredByVectorClock();
          _bumpDroppedType(rt);
          addIgnored(labelForSkip(JournalUpdateSkipReason.overwritePrevented));
        case JournalUpdateSkipReason.olderOrEqual:
          _metrics.incDbIgnoredByVectorClock();
          _bumpDroppedType(rt);
          addIgnored(labelForSkip(JournalUpdateSkipReason.olderOrEqual));
        case null:
          _metrics.incDbIgnoredByVectorClock();
          _bumpDroppedType(rt);
          addIgnored(msh.ignoredReasonFromStatus(status));
      }
    } catch (_) {
      // best-effort only
    }
  }

  // Visible for testing only
  bool get debugCollectMetrics => _collectMetrics;

  // Additional textual diagnostics not represented in numeric metrics.
  Map<String, String> diagnosticsStrings() {
    final map = <String, String>{
      'lastIgnoredCount': _metrics.lastIgnored.length.toString(),
    };
    // Compact summary lines for quick scanning in diagnostics text.
    try {
      final snap = _metrics.snapshot(
        retryStateSize: _retryTracker.size(),
        circuitIsOpen: _circuit.isOpen(clock.now()),
      );
      if (snap.containsKey('dbEntryLinkNoop')) {
        map['entryLink.noops'] = snap['dbEntryLinkNoop'].toString();
      }
    } catch (_) {
      // best-effort only
    }
    for (var i = 0; i < _metrics.lastIgnored.length; i++) {
      map['lastIgnored.${i + 1}'] = _metrics.lastIgnored[i];
    }
    return map;
  }

  // Force all pending retries to be immediately due and trigger a scan.
  Future<void> retryNow() async {
    try {
      if (_retryTracker.size() == 0) return;
      final now = clock.now();
      _retryTracker.markAllDueNow(now);
      final scan = _scanLiveTimeline;
      if (scan != null) {
        await scan();
      }
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: syncLoggingDomain,
        subDomain: 'retryNow',
        stackTrace: st,
      );
    }
  }

  // Record a connectivity-driven signal for observability.
  void recordConnectivitySignal() {
    if (_collectMetrics) _metrics.incSignalConnectivity();
  }
}
