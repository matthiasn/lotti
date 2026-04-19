import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_event_classifier.dart'
    as ec;
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_processor.dart';
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';
import 'package:lotti/features/sync/matrix/sdk_pagination_compat.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

class MatrixStreamCatchUpCoordinator {
  MatrixStreamCatchUpCoordinator({
    required MatrixSessionManager sessionManager,
    required SyncRoomManager roomManager,
    required LoggingService loggingService,
    required MetricsCounters metrics,
    required bool collectMetrics,
    required this.skipSyncWait,
    required MatrixStreamProcessor processor,
    required void Function(String source) flushDeferredLiveScan,
    required String Function(String message) withInstance,
    Future<bool> Function({
      required Timeline timeline,
      required String? lastEventId,
      required int pageSize,
      required int? maxPages,
      required LoggingService logging,
      num? untilTimestamp,
    })?
    backfill,
  }) : _sessionManager = sessionManager,
       _roomManager = roomManager,
       _loggingService = loggingService,
       _metrics = metrics,
       _collectMetrics = collectMetrics,
       _processor = processor,
       _flushDeferredLiveScan = flushDeferredLiveScan,
       _withInstance = withInstance,
       _backfill = backfill;

  final MatrixSessionManager _sessionManager;
  final SyncRoomManager _roomManager;
  final LoggingService _loggingService;
  final MetricsCounters _metrics;
  final bool _collectMetrics;
  bool skipSyncWait;
  final MatrixStreamProcessor _processor;
  final void Function(String source) _flushDeferredLiveScan;
  final String Function(String message) _withInstance;
  final Future<bool> Function({
    required Timeline timeline,
    required String? lastEventId,
    required int pageSize,
    required int? maxPages,
    required LoggingService logging,
    num? untilTimestamp,
  })?
  _backfill;

  String? _startupLastProcessedEventId;
  num? _startupLastProcessedTs;
  // "Ready" means startup catch-up has run enough that live scans may proceed
  // without deadlocking. "Converged" means we re-established a trustworthy
  // historical boundary, either by finding the stored marker or by paging back
  // past the stored timestamp and replaying forward from there.
  bool _initialCatchUpReady = false;
  bool _initialCatchUpConverged = false;
  Timer? _catchUpRetryTimer;
  bool _firstStreamEventCatchUpTriggered = false;
  bool _catchUpInFlight = false;

  // --- Catch-up coalescing -------------------------------------------------
  DateTime? _lastCatchupAt;
  bool _deferredCatchup = false;
  Timer? _catchupDebounceTimer;
  static const Duration _minCatchupGap = SyncTuning.minCatchupGap;
  static const Duration _trailingCatchupDelay = SyncTuning.trailingCatchupDelay;
  // Coalesced catch-up burst logging control
  bool _catchupLogStartPending = false;
  bool _catchupDoneLoggedThisBurst = false;
  int _lastCatchupEventsCount = 0;
  int _lastCatchupSignalClientStream = 0;
  int _lastCatchupFirstStreamTriggers = 0;
  int _lastCatchupDeferredSignals = 0;
  int _lastCatchupCoalescedSignals = 0;
  int _lastCatchupTrailingSignals = 0;

  StreamSubscription<SyncUpdate>? _pendingSyncSubscription;
  Timer? _wakeCatchUpRetryTimer;
  bool _wakeCatchUpPending = false;
  static const Duration _wakeCatchUpRetryDelay = Duration(milliseconds: 500);

  Completer<void>? _forceRescanCompleter;
  Future<void> Function()? scanLiveTimeline;

  bool get initialCatchUpCompleted => _initialCatchUpConverged;
  bool get initialCatchUpReady => _initialCatchUpReady;
  bool get catchUpInFlight => _catchUpInFlight;
  bool get wakeCatchUpPending => _wakeCatchUpPending;

  ({String? eventId, num? timestamp}) get startupMarkers => (
    eventId: _startupLastProcessedEventId,
    timestamp: _startupLastProcessedTs,
  );

  set startupMarkers(({String? eventId, num? timestamp}) markers) {
    _startupLastProcessedEventId = markers.eventId;
    _startupLastProcessedTs = markers.timestamp;
  }

  bool handleFirstStreamEvent() {
    if (_initialCatchUpReady || _firstStreamEventCatchUpTriggered) {
      return false;
    }
    _firstStreamEventCatchUpTriggered = true;
    if (_collectMetrics) _metrics.incSignalFirstStreamCatchupTriggers();
    _startCatchupNow();
    return true;
  }

  /// Returns true if catch-up handling took the signal, false if the caller
  /// should schedule a live scan instead.
  bool handleClientStreamSignal() {
    if (_initialCatchUpReady) {
      return false;
    }
    // Startup: coalesce client-stream-driven catch-ups to avoid redundant work.
    // If one is in-flight, defer a single trailing catch-up; otherwise enforce
    // a short minimum gap.
    if (_catchUpInFlight) {
      if (!_deferredCatchup) {
        _deferredCatchup = true;
        if (_collectMetrics) _metrics.incSignalCatchupDeferred();
      }
      return true;
    }
    final now = clock.now();
    if (_lastCatchupAt != null &&
        now.difference(_lastCatchupAt!) < _minCatchupGap) {
      // Debounce: schedule once at the end of the gap
      final remaining = _minCatchupGap - now.difference(_lastCatchupAt!);
      _catchupDebounceTimer?.cancel();
      _catchupDebounceTimer = Timer(remaining, _startCatchupNow);
      if (_collectMetrics) _metrics.incSignalCatchupCoalesce();
      return true;
    }
    _startCatchupNow();
    return true;
  }

  Future<void> runInitialCatchUpIfReady() async {
    if (_roomManager.currentRoom != null) {
      await _attachCatchUp();
    }
    if (!_initialCatchUpReady) {
      _scheduleInitialCatchUpRetry();
    }
  }

  void _startCatchupNow() {
    if (_catchUpInFlight) {
      _deferredCatchup = true;
      return;
    }
    // `_attachCatchUp()` (invoked transitively by `forceRescan`) now owns the
    // `_catchUpInFlight` flag and `_flushDeferredLiveScan` call. This wrapper
    // only drives the coalesced burst logging and trailing-catchup scheduling.
    _catchupLogStartPending = true;
    _catchupDoneLoggedThisBurst = false;
    unawaited(
      forceRescan().whenComplete(() {
        _lastCatchupAt = clock.now();
        if (_deferredCatchup) {
          _deferredCatchup = false;
          if (_collectMetrics) _metrics.incTrailingCatchups();
          _loggingService.captureEvent(
            _withInstance('trailing.catchup.scheduled'),
            domain: syncLoggingDomain,
            subDomain: 'signal',
          );
          _catchupDebounceTimer?.cancel();
          // Enforce a minimum idle gap before running the trailing catch-up to
          // give the UI time to settle under bursty conditions.
          _catchupDebounceTimer = Timer(
            _trailingCatchupDelay,
            _startCatchupNow,
          );
        } else {
          // No trailing run scheduled: log 'done' once for this burst.
          if (!_catchupDoneLoggedThisBurst) {
            _loggingService.captureEvent(
              _withInstance(
                'catchup.done events=$_lastCatchupEventsCount ${_catchupSignalSummary()}',
              ),
              domain: syncLoggingDomain,
              subDomain: 'catchup',
            );
            _catchupDoneLoggedThisBurst = true;
          }
          // Reset start flag for the next burst.
          _catchupLogStartPending = false;
        }
      }),
    );
  }

  /// Runs catch-up. The in-flight guard and deferred-live-scan flush are owned
  /// by `_attachCatchUp()` itself, so this wrapper only emits the
  /// `source`-annotated start log for observability.
  Future<void> runGuardedCatchUp(String source) async {
    _loggingService.captureEvent(
      '$source: starting guarded catch-up',
      domain: syncLoggingDomain,
      subDomain: 'catchup.guarded',
    );
    await _attachCatchUp();
  }

  String _catchupSignalSummary() {
    if (!_collectMetrics) {
      return '';
    }
    final clientStream =
        _metrics.signalClientStream - _lastCatchupSignalClientStream;
    final firstStream =
        _metrics.signalFirstStreamCatchupTriggers -
        _lastCatchupFirstStreamTriggers;
    final deferred =
        _metrics.signalCatchupDeferredCount - _lastCatchupDeferredSignals;
    final coalesced =
        _metrics.signalCatchupCoalesceCount - _lastCatchupCoalescedSignals;
    final trailing = _metrics.trailingCatchups - _lastCatchupTrailingSignals;

    _lastCatchupSignalClientStream = _metrics.signalClientStream;
    _lastCatchupFirstStreamTriggers = _metrics.signalFirstStreamCatchupTriggers;
    _lastCatchupDeferredSignals = _metrics.signalCatchupDeferredCount;
    _lastCatchupCoalescedSignals = _metrics.signalCatchupCoalesceCount;
    _lastCatchupTrailingSignals = _metrics.trailingCatchups;

    final parts = <String>[
      'signalSummary',
      if (clientStream > 0) 'clientStream=$clientStream',
      if (firstStream > 0) 'firstStream=$firstStream',
      if (deferred > 0) 'deferred=$deferred',
      if (coalesced > 0) 'coalesced=$coalesced',
      if (trailing > 0) 'trailing=$trailing',
    ];
    return parts.join(' ');
  }

  void _scheduleInitialCatchUpRetry() {
    _catchUpRetryTimer?.cancel();
    _catchUpRetryTimer = Timer(const Duration(milliseconds: 500), () {
      if (_initialCatchUpReady) return;
      if (_catchUpInFlight) {
        _scheduleInitialCatchUpRetry();
        return;
      }
      _loggingService.captureEvent(
        _withInstance('catchup.retry.attempt'),
        domain: syncLoggingDomain,
        subDomain: 'catchup',
      );
      unawaited(
        _attachCatchUp()
            .then((_) {
              if (!_initialCatchUpReady) {
                _loggingService.captureEvent(
                  _withInstance('catchup.retry.reschedule (not completed)'),
                  domain: syncLoggingDomain,
                  subDomain: 'catchup',
                );
                _scheduleInitialCatchUpRetry();
              }
            })
            .catchError((Object error, StackTrace st) {
              _loggingService.captureException(
                error,
                domain: syncLoggingDomain,
                subDomain: 'catchup.retry',
                stackTrace: st,
              );
              if (!_initialCatchUpReady) {
                _scheduleInitialCatchUpRetry();
              }
            }),
      );
    });
  }

  /// Waits for Matrix SDK to complete a sync with the server.
  /// Returns true if sync completed within timeout, false otherwise.
  /// If timeout occurs, sets up a listener to trigger another catch-up when
  /// sync eventually completes (handles slow networks gracefully).
  Future<bool> _waitForSyncCompletion({Duration? timeout}) async {
    if (skipSyncWait) return true;

    final effectiveTimeout = timeout ?? SyncTuning.catchupSyncWaitTimeout;
    final client = _sessionManager.client;

    try {
      await client.onSync.stream.first.timeout(effectiveTimeout);
      return true;
    } on TimeoutException {
      _loggingService.captureEvent(
        'waitForSync.timeout after ${effectiveTimeout.inMilliseconds}ms, setting up follow-up listener',
        domain: syncLoggingDomain,
        subDomain: 'catchup.sync',
      );
      // Set up a one-time listener to trigger catch-up when sync eventually completes
      _setupPendingSyncListener();
      return false;
    }
  }

  /// Sets up a one-time listener to trigger catch-up when sync completes.
  /// Used when the initial sync wait times out on slow networks.
  void _setupPendingSyncListener() {
    // Cancel any existing pending listener
    _pendingSyncSubscription?.cancel();

    final client = _sessionManager.client;
    // Use .first.asStream() to create a single-event stream that auto-cancels
    _pendingSyncSubscription = client.onSync.stream.first.asStream().listen((
      syncUpdate,
    ) {
      _pendingSyncSubscription = null;
      _loggingService.captureEvent(
        'pendingSyncListener.triggered, scheduling follow-up catch-up',
        domain: syncLoggingDomain,
        subDomain: 'catchup.sync',
      );
      // Trigger a follow-up catch-up now that sync has completed
      unawaited(runGuardedCatchUp('pendingSyncListener'));
    });
  }

  /// Runs catch-up and returns true on success, false on failure.
  ///
  /// Self-guards against concurrent execution: if another `_attachCatchUp()`
  /// is already running, this returns `false` immediately after logging
  /// `catchup.skipped (in flight)`. This is the single source of truth for
  /// `_catchUpInFlight` so every external entry point (`forceRescan`,
  /// `runInitialCatchUpIfReady`, `runGuardedCatchUp`,
  /// `_scheduleInitialCatchUpRetry`, `startWakeCatchUp`) can call through
  /// here without coordinating the flag themselves.
  Future<bool> _attachCatchUp() async {
    if (_catchUpInFlight) {
      _loggingService.captureEvent(
        _withInstance('catchup.skipped (in flight)'),
        domain: syncLoggingDomain,
        subDomain: 'catchup',
      );
      return false;
    }
    _catchUpInFlight = true;
    try {
      final roomId = _roomManager.currentRoomId;
      if (roomId == null) {
        if (_collectMetrics) {
          _loggingService.captureEvent(
            _withInstance('No configured room for catch-up'),
            domain: syncLoggingDomain,
            subDomain: 'catchup',
          );
        }
        return false;
      }

      // Wait for SDK sync to complete before catch-up.
      // This ensures the SDK has fetched the latest events from the server.
      // Applies to ALL catch-up scenarios: initial, resume, wake, reconnect.
      final synced = await _waitForSyncCompletion();
      _loggingService.captureEvent(
        _withInstance('catchup.waitForSync synced=$synced'),
        domain: syncLoggingDomain,
        subDomain: 'catchup',
      );

      final room = _roomManager.currentRoom;
      if (room == null) {
        if (_collectMetrics) {
          _loggingService.captureEvent(
            _withInstance('No active room for catch-up'),
            domain: syncLoggingDomain,
            subDomain: 'catchup',
          );
        }
        return false;
      }
      if (_catchupLogStartPending) {
        final marker = !_initialCatchUpReady
            ? _startupLastProcessedEventId
            : _processor.lastProcessedEventId;
        _loggingService.captureEvent(
          _withInstance(
            'catchup.start lastEventId=${marker ?? 'null'} (${!_initialCatchUpReady ? 'startup' : 'current'})',
          ),
          domain: syncLoggingDomain,
          subDomain: 'catchup',
        );
        _catchupLogStartPending = false;
      }
      final anchorTimestamp = !_initialCatchUpReady
          ? _startupLastProcessedTs
          : _processor.lastProcessedTs;
      final preSinceTs = anchorTimestamp == null
          ? null
          : (anchorTimestamp.toInt() - 1000); // small skew buffer
      // Use startup marker for initial catch-up to avoid race with live scans
      // that may advance the current marker before catch-up runs.
      final catchUpMarker = !_initialCatchUpReady
          ? _startupLastProcessedEventId
          : _processor.lastProcessedEventId;
      final catchUp = await CatchUpStrategy.collectEventsForCatchUp(
        room: room,
        lastEventId: catchUpMarker,
        backfill: _backfill ?? SdkPaginationCompat.backfillUntilContains,
        logging: _loggingService,
        // Ensure we also include a bounded pre-context since the stored last
        // sync timestamp, escalating pagination as needed.
        preContextSinceTs: preSinceTs,
        preContextCount: SyncTuning.catchupPreContextCount,
        maxLookback: SyncTuning.catchupMaxLookback,
      );
      if (catchUp.incomplete) {
        _loggingService
          ..captureEvent(
            _withInstance(
              'catchup.incomplete reason=timestampBoundaryUnreachable marker=$catchUpMarker '
              'snapshot=${catchUp.snapshotSize} visibleTail=${catchUp.visibleTailCount} '
              'timestampBoundary=${catchUp.reachedTimestampBoundary}',
            ),
            domain: syncLoggingDomain,
            subDomain: 'catchup',
          )
          ..captureEvent(
            _withInstance(
              'catchup.${_initialCatchUpReady ? 'ongoing' : 'initial'}.incomplete '
              'reason=timestampBoundaryUnreachable',
            ),
            domain: syncLoggingDomain,
            subDomain: 'catchup',
          );
        return false;
      }
      if (catchUp.timestampAnchored) {
        _loggingService.captureEvent(
          _withInstance(
            'catchup.recovered via=timestampBoundary marker=$catchUpMarker '
            'snapshot=${catchUp.snapshotSize} slice=${catchUp.events.length}',
          ),
          domain: syncLoggingDomain,
          subDomain: 'catchup',
        );
      }
      final slice = catchUp.events;
      _lastCatchupEventsCount = slice.length;
      if (slice.isNotEmpty) {
        if (_collectMetrics) _metrics.incCatchupBatches();
        // Log event summary for catch-up diagnostics (single pass)
        final counts = slice.fold(
          (payloads: 0, attachments: 0),
          (counts, event) {
            final isPayload = ec.MatrixEventClassifier.isSyncPayloadEvent(
              event,
            );
            final isAttachment = ec.MatrixEventClassifier.isAttachment(event);
            return (
              payloads: counts.payloads + (isPayload ? 1 : 0),
              attachments: counts.attachments + (isAttachment ? 1 : 0),
            );
          },
        );
        _loggingService.captureEvent(
          _withInstance(
            'catchup.slice total=${slice.length} payloads=${counts.payloads} attachments=${counts.attachments} marker=$catchUpMarker',
          ),
          domain: syncLoggingDomain,
          subDomain: 'catchup',
        );
        final collisions = TimelineEventOrdering.timestampCollisionStats(
          slice,
        );
        if (collisions.groupCount > 0) {
          final sample = collisions.sample
              .map((entry) => '${entry.ts}:${entry.count}')
              .join(',');
          _loggingService.captureEvent(
            _withInstance(
              'catchup.tsCollision groups=${collisions.groupCount} events=${collisions.eventCount} total=${slice.length} sample=$sample',
            ),
            domain: syncLoggingDomain,
            subDomain: 'ordering',
          );
        }
        await _processor.processOrdered(slice);
      }
      if (!_initialCatchUpConverged) {
        _initialCatchUpConverged = true;
      }
      // Mark initial catch-up as completed and cancel retry timer.
      if (!_initialCatchUpReady) {
        _initialCatchUpReady = true;
        _catchUpRetryTimer?.cancel();
        _catchUpRetryTimer = null;
        _loggingService.captureEvent(
          _withInstance('catchup.initial.completed'),
          domain: syncLoggingDomain,
          subDomain: 'catchup',
        );
      }
      return true; // Success
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: syncLoggingDomain,
        subDomain: 'catchup',
        stackTrace: st,
      );
      return false; // Failure
    } finally {
      _catchUpInFlight = false;
      _flushDeferredLiveScan('attachCatchUp');
    }
  }

  /// Starts wake catch-up, handling in-flight and failure cases.
  void startWakeCatchUp() {
    if (_wakeCatchUpPending) return;
    _wakeCatchUpPending = true;
    // If catch-up is already in-flight, schedule retry after it completes.
    if (_catchUpInFlight) {
      _loggingService.captureEvent(
        'wake.catchup.deferred (catch-up in flight)',
        domain: syncLoggingDomain,
        subDomain: 'wake',
      );
      _wakeCatchUpRetryTimer?.cancel();
      _wakeCatchUpRetryTimer = Timer(_wakeCatchUpRetryDelay, () {
        if (_wakeCatchUpPending) {
          startWakeCatchUp();
        }
      });
      return;
    }

    _loggingService.captureEvent(
      'wake.catchup.start',
      domain: syncLoggingDomain,
      subDomain: 'wake',
    );

    unawaited(
      _attachCatchUp().then((success) {
        if (success) {
          _wakeCatchUpPending = false;
          _loggingService.captureEvent(
            'wake.catchup.done success=true',
            domain: syncLoggingDomain,
            subDomain: 'wake',
          );
        } else {
          // Catch-up failed; retry after delay.
          _loggingService.captureEvent(
            'wake.catchup.done success=false, scheduling retry',
            domain: syncLoggingDomain,
            subDomain: 'wake',
          );
          _wakeCatchUpRetryTimer?.cancel();
          _wakeCatchUpRetryTimer = Timer(_wakeCatchUpRetryDelay, () {
            if (_wakeCatchUpPending) {
              startWakeCatchUp();
            }
          });
        }
      }),
    );
  }

  // Force a rescan and optional catch-up to recover from potential gaps.
  // `_forceRescanCompleter` serialises external forceRescan calls (connectivity
  // + startup from MatrixService) so later callers await the in-flight run.
  // `_attachCatchUp()` owns `_catchUpInFlight` and the deferred-live-scan
  // flush, so this method never has to touch either.
  Future<void> forceRescan({bool includeCatchUp = true}) async {
    final pending = _forceRescanCompleter;
    if (pending != null) {
      _loggingService.captureEvent(
        _withInstance('forceRescan.skipped (already in flight)'),
        domain: syncLoggingDomain,
        subDomain: 'forceRescan',
      );
      await pending.future;
      return;
    }
    final completer = Completer<void>();
    _forceRescanCompleter = completer;
    try {
      _loggingService.captureEvent(
        _withInstance('forceRescan.start includeCatchUp=$includeCatchUp'),
        domain: syncLoggingDomain,
        subDomain: 'forceRescan',
      );
      if (includeCatchUp) {
        await _attachCatchUp();
      }
      final scan = scanLiveTimeline;
      if (scan != null) {
        await scan();
      }
      _loggingService.captureEvent(
        _withInstance('forceRescan.done includeCatchUp=$includeCatchUp'),
        domain: syncLoggingDomain,
        subDomain: 'forceRescan',
      );
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: syncLoggingDomain,
        subDomain: 'forceRescan',
        stackTrace: st,
      );
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
      if (identical(_forceRescanCompleter, completer)) {
        _forceRescanCompleter = null;
      }
    }
  }

  Future<void> dispose() async {
    _catchupDebounceTimer?.cancel();
    _catchUpRetryTimer?.cancel();
    _catchUpRetryTimer = null;
    await _pendingSyncSubscription?.cancel();
    _pendingSyncSubscription = null;
    _wakeCatchUpRetryTimer?.cancel();
    _wakeCatchUpRetryTimer = null;
  }
}
