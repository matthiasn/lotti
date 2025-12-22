import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_helpers.dart'
    as msh;
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_processor.dart';
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/features/sync/matrix/utils/timeline_utils.dart' as tu;
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

class MatrixStreamLiveScanController {
  MatrixStreamLiveScanController({
    required LoggingService loggingService,
    required MetricsCounters metrics,
    required bool collectMetrics,
    required bool dropOldPayloadsInLiveScan,
    required MatrixStreamProcessor processor,
    required bool Function() isInitialCatchUpCompleted,
    required bool Function() isCatchUpInFlight,
    required bool Function() isWakeCatchUpPending,
    required void Function() startWakeCatchUp,
    required String Function(String message) withInstance,
  })  : _loggingService = loggingService,
        _metrics = metrics,
        _collectMetrics = collectMetrics,
        _dropOldPayloadsInLiveScan = dropOldPayloadsInLiveScan,
        _processor = processor,
        _isInitialCatchUpCompleted = isInitialCatchUpCompleted,
        _isCatchUpInFlight = isCatchUpInFlight,
        _isWakeCatchUpPending = isWakeCatchUpPending,
        _startWakeCatchUp = startWakeCatchUp,
        _withInstance = withInstance;

  final LoggingService _loggingService;
  final MetricsCounters _metrics;
  final bool _collectMetrics;
  final bool _dropOldPayloadsInLiveScan;
  final MatrixStreamProcessor _processor;
  final bool Function() _isInitialCatchUpCompleted;
  final bool Function() _isCatchUpInFlight;
  final bool Function() _isWakeCatchUpPending;
  final void Function() _startWakeCatchUp;
  final String Function(String message) _withInstance;

  Timeline? liveTimeline;
  Timer? _liveScanTimer;
  bool _scanInFlight = false;
  int _scanInFlightDepth =
      0; // guards overlapping scans and trailing scheduling
  bool _liveScanDeferred = false;
  DateTime? _lastLiveScanAt;
  // Tracks the last time we received a signal (client stream or timeline)
  // to compute signal->scan latency when the next scan runs.
  DateTime? _lastSignalAt;

  static const Duration _standbyThreshold = Duration(seconds: 30);
  static const Duration _minLiveScanGap = SyncTuning.minLiveScanGap;
  static const Duration _trailingLiveScanDebounce =
      SyncTuning.trailingLiveScanDebounce;
  static const int _liveScanTailLimit = 1000;

  // Test-only hook invoked at the start of scheduleLiveScan to simulate
  // errors and exercise fallback logic.
  void Function()? scheduleLiveScanTestHook;

  // Test-only hook invoked at the start of scanLiveTimeline with a
  // scheduler callback to allow tests to schedule additional scans while
  // the guard is asserted.
  void Function(void Function())? scanLiveTimelineTestHook;

  void dispose() {
    _liveScanTimer?.cancel();
    _liveScanTimer = null;
    try {
      liveTimeline?.cancelSubscriptions();
    } catch (_) {
      // Best effort; Matrix SDK cancel is synchronous.
    }
    liveTimeline = null;
  }

  void flushDeferredLiveScan(String source) {
    if (!_liveScanDeferred) return;
    if (!_isInitialCatchUpCompleted()) return;
    if (_isCatchUpInFlight() || _scanInFlight) return;
    _liveScanDeferred = false;
    _loggingService.captureEvent(
      _withInstance('liveScan.deferred.flush source=$source'),
      domain: syncLoggingDomain,
      subDomain: 'signal',
    );
    scheduleLiveScan();
  }

  void scheduleLiveScan() {
    // Test seam: allow tests to inject behavior/failures to exercise
    // scheduling error handling paths.
    if (scheduleLiveScanTestHook != null) {
      try {
        scheduleLiveScanTestHook!.call();
      } catch (e, st) {
        _loggingService.captureException(
          e,
          domain: syncLoggingDomain,
          subDomain: 'signal.schedule',
          stackTrace: st,
        );
      }
    }
    // Avoid live scans before the initial catch-up completes; defer until
    // older events are processed so we do not create gaps from out-of-order
    // arrival.
    if (!_isInitialCatchUpCompleted()) {
      if (!_liveScanDeferred) {
        _liveScanDeferred = true;
        _loggingService.captureEvent(
          'signal.liveScan.deferred.initialCatchUpIncomplete',
          domain: syncLoggingDomain,
          subDomain: 'signal',
        );
      }
      return;
    }
    // Ensure in-order ingest: defer live scan signals while catch-up is
    // processing older events. This prevents newer events from being recorded
    // before older ones, which would cause false positive gap detection.
    if (_isCatchUpInFlight()) {
      if (!_liveScanDeferred) {
        _liveScanDeferred = true;
        _loggingService.captureEvent(
          'signal.liveScan.deferred.catchUpInFlight',
          domain: syncLoggingDomain,
          subDomain: 'signal',
        );
      }
      return;
    }
    // Debounced scheduler for live scans. It is valid for _liveTimeline to be
    // null during early startup (hydration/catch-up still in progress). We
    // record the signal and log for observability either way.
    if (_collectMetrics) _lastSignalAt = clock.now();
    // Detect wake from standby: if the gap since the last scan exceeds the
    // threshold, trigger a catch-up before allowing marker advancement.
    final now = clock.now();
    final lastScan = _lastLiveScanAt;
    if (lastScan != null && !_isWakeCatchUpPending()) {
      final gap = now.difference(lastScan);
      if (gap > _standbyThreshold) {
        _loggingService.captureEvent(
          'wake.detected gapMs=${gap.inMilliseconds}',
          domain: syncLoggingDomain,
          subDomain: 'wake',
        );
        _startWakeCatchUp();
      }
    }
    if (liveTimeline == null) {
      _loggingService.captureEvent(
        'signal.noTimeline',
        domain: syncLoggingDomain,
        subDomain: 'signal',
      );
    }
    // If a scan is currently running, coalesce this signal.
    if (_scanInFlight) {
      if (!_liveScanDeferred) {
        _liveScanDeferred = true;
        if (_collectMetrics) _metrics.incLiveScanDeferred();
        _loggingService.captureEvent(
          'signal.liveScan.deferred set',
          domain: syncLoggingDomain,
          subDomain: 'signal',
        );
      }
      return;
    }
    // Tight base debounce keeps scans responsive while coalescing bursts, but
    // enforce a minimum gap between consecutive scans to reduce churn.
    final delay = _calculateNextLiveScanDelay();
    if (delay > _trailingLiveScanDebounce) {
      if (_collectMetrics) _metrics.incLiveScanCoalesce();
      _loggingService.captureEvent(
        'signal.liveScan.coalesce debounceMs=${delay.inMilliseconds}',
        domain: syncLoggingDomain,
        subDomain: 'signal',
      );
    }
    _liveScanTimer?.cancel();
    _liveScanTimer = Timer(delay, () {
      unawaited(scanLiveTimeline());
    });
  }

  void scheduleRescan(Duration delay) {
    _liveScanTimer?.cancel();
    _liveScanTimer = Timer(delay, () {
      unawaited(scanLiveTimeline());
    });
  }

  Future<void> scanLiveTimeline() async {
    if (!_isInitialCatchUpCompleted() || _isCatchUpInFlight()) {
      if (!_liveScanDeferred) {
        _liveScanDeferred = true;
        final reason = !_isInitialCatchUpCompleted()
            ? 'initialCatchUpIncomplete'
            : 'catchUpInFlight';
        _loggingService.captureEvent(
          _withInstance('liveScan.skipped $reason'),
          domain: syncLoggingDomain,
          subDomain: 'liveScan',
        );
      }
      return;
    }
    final tl = liveTimeline;
    if (tl == null) return;
    try {
      // Enter scan: increment depth and assert the in-flight guard.
      _scanInFlightDepth++;
      _scanInFlight = true;
      // Test seam: allow tests to invoke scheduling while a scan is in flight
      // to validate coalescing/guarding behavior.
      scanLiveTimelineTestHook?.call(scheduleLiveScan);
      // Record signal->scan latency if a signal was captured recently.
      if (_collectMetrics && _lastSignalAt != null) {
        final ms = clock.now().difference(_lastSignalAt!).inMilliseconds;
        _metrics.recordSignalLatencyMs(ms);
        _lastSignalAt = null;
      }
      // Build the normal strictly-after slice (no timestamp gating for payload
      // discovery).
      final afterSlice = msh.buildLiveScanSlice(
        timelineEvents: tl.events,
        lastEventId: _processor.lastProcessedEventId,
        tailLimit: _liveScanTailLimit,
        lastTimestamp: null,
      );
      final deduped = tu.dedupEventsByIdPreserveOrder(afterSlice);
      if (deduped.isNotEmpty) {
        final collisions = TimelineEventOrdering.timestampCollisionStats(
          deduped,
          sampleLimit: 5,
        );
        if (collisions.groupCount > 0) {
          final sample = collisions.sample
              .map((entry) => '${entry.ts}:${entry.count}')
              .join(',');
          _loggingService.captureEvent(
            _withInstance(
              'liveScan.tsCollision groups=${collisions.groupCount} events=${collisions.eventCount} total=${deduped.length} sample=$sample',
            ),
            domain: syncLoggingDomain,
            subDomain: 'ordering',
          );
        }
        // Use helper to optionally drop older/equal payloads while keeping
        // attachments and retries.
        final toProcess = msh.filterSyncPayloadsByMonotonic(
          events: deduped,
          dropOldSyncPayloads: _dropOldPayloadsInLiveScan,
          lastTimestamp: _processor.lastProcessedTs,
          lastEventId: _processor.lastProcessedEventId,
          wasCompleted: _processor.wasCompletedSync,
          onSkipped: _collectMetrics ? _metrics.incSkipped : null,
        );

        if (toProcess.isNotEmpty) {
          await _processor.processOrdered(toProcess);
        }
        if (_collectMetrics) {
          _loggingService.captureEvent(
            'liveScan processed=${toProcess.length} latest=${_processor.lastProcessedEventId ?? 'null'}',
            domain: syncLoggingDomain,
            subDomain: 'liveScan',
          );
        }
      }
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: syncLoggingDomain,
        subDomain: 'liveScan',
        stackTrace: st,
      );
    } finally {
      // Leave scan: decrement depth and only clear the in-flight flag,
      // record completion, and schedule trailing work when the outermost
      // scan completes. This prevents the guard from dropping during
      // nested scans and avoids overlapping scheduling.
      _scanInFlightDepth = _scanInFlightDepth - 1;
      final isOutermost = _scanInFlightDepth <= 0;
      if (isOutermost) {
        _scanInFlightDepth = 0;
        _scanInFlight = false;
        // Record completion time to bound the rate of subsequent scans.
        _lastLiveScanAt = clock.now();
        if (_liveScanDeferred) {
          _liveScanDeferred = false;
          if (_collectMetrics) _metrics.incLiveScanTrailingScheduled();
          _loggingService.captureEvent(
            'trailing.liveScan.scheduled',
            domain: syncLoggingDomain,
            subDomain: 'signal',
          );
          // Enforce a minimum gap between scans while keeping a small base
          // debounce to coalesce a final burst of signals.
          final delay = _calculateNextLiveScanDelay();
          _liveScanTimer?.cancel();
          _liveScanTimer = Timer(delay, () {
            unawaited(scanLiveTimeline());
          });
        }
      }
    }
  }

  // Compute the next live-scan delay by coalescing bursts and enforcing a
  // minimum gap between consecutive scans.
  Duration _calculateNextLiveScanDelay() {
    var delay = _trailingLiveScanDebounce;
    final last = _lastLiveScanAt;
    if (last != null) {
      final since = clock.now().difference(last);
      if (since < _minLiveScanGap) {
        final remaining = _minLiveScanGap - since;
        if (remaining > delay) {
          delay = remaining;
        }
      }
    }
    return delay;
  }

  // Test-only hooks are exposed as public fields for easy wiring in tests.
}
