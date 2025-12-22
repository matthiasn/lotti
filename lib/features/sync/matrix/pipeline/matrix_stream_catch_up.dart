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
    required bool skipSyncWait,
    required MatrixStreamProcessor processor,
    required void Function(String source) flushDeferredLiveScan,
    required String Function(String message) withInstance,
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
        _metrics = metrics,
        _collectMetrics = collectMetrics,
        _skipSyncWait = skipSyncWait,
        _processor = processor,
        _flushDeferredLiveScan = flushDeferredLiveScan,
        _withInstance = withInstance,
        _backfill = backfill;

  final MatrixSessionManager _sessionManager;
  final SyncRoomManager _roomManager;
  final LoggingService _loggingService;
  final MetricsCounters _metrics;
  final bool _collectMetrics;
  final bool _skipSyncWait;
  final MatrixStreamProcessor _processor;
  final void Function(String source) _flushDeferredLiveScan;
  final String Function(String message) _withInstance;
  final Future<bool> Function({
    required Timeline timeline,
    required String? lastEventId,
    required int pageSize,
    required int maxPages,
    required LoggingService logging,
  })? _backfill;

  String? _startupLastProcessedEventId;
  num? _startupLastProcessedTs;
  bool _initialCatchUpCompleted = false;
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

  StreamSubscription<SyncUpdate>? _pendingSyncSubscription;
  Timer? _wakeCatchUpRetryTimer;
  bool _wakeCatchUpPending = false;
  static const Duration _wakeCatchUpRetryDelay = Duration(milliseconds: 500);

  Completer<void>? _forceRescanCompleter;
  Future<void> Function()? scanLiveTimeline;

  bool get initialCatchUpCompleted => _initialCatchUpCompleted;
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
    if (_initialCatchUpCompleted || _firstStreamEventCatchUpTriggered) {
      return false;
    }
    _firstStreamEventCatchUpTriggered = true;
    if (_collectMetrics) {
      _loggingService.captureEvent(
        'signal.firstStreamEvent.triggering.catchup',
        domain: syncLoggingDomain,
        subDomain: 'signal',
      );
    }
    _startCatchupNow();
    return true;
  }

  /// Returns true if catch-up handling took the signal, false if the caller
  /// should schedule a live scan instead.
  bool handleClientStreamSignal() {
    if (_initialCatchUpCompleted) {
      return false;
    }
    // Startup: coalesce client-stream-driven catch-ups to avoid redundant work.
    // If one is in-flight, defer a single trailing catch-up; otherwise enforce
    // a short minimum gap.
    if (_catchUpInFlight) {
      if (!_deferredCatchup) {
        _deferredCatchup = true;
        _loggingService.captureEvent(
          'signal.catchup.deferred set',
          domain: syncLoggingDomain,
          subDomain: 'signal',
        );
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
      _loggingService.captureEvent(
        'signal.catchup.coalesce debounceMs=${remaining.inMilliseconds}',
        domain: syncLoggingDomain,
        subDomain: 'signal',
      );
      return true;
    }
    _startCatchupNow();
    return true;
  }

  Future<void> runInitialCatchUpIfReady() async {
    if (_roomManager.currentRoom != null) {
      await _attachCatchUp();
      _flushDeferredLiveScan('start');
    }
    if (!_initialCatchUpCompleted) {
      _scheduleInitialCatchUpRetry();
    }
  }

  void _startCatchupNow() {
    if (_catchUpInFlight) {
      _deferredCatchup = true;
      return;
    }
    _catchUpInFlight = true;
    // New burst: emit start once for the first run only; defer 'done' until the
    // last run in this coalesced burst (after any trailing catch-up completes).
    _catchupLogStartPending = true;
    _catchupDoneLoggedThisBurst = false;
    unawaited(
      forceRescan(
        bypassCatchUpInFlightCheck: true,
      ).whenComplete(() {
        _catchUpInFlight = false;
        _flushDeferredLiveScan('startCatchupNow');
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
          _catchupDebounceTimer =
              Timer(_trailingCatchupDelay, _startCatchupNow);
        } else {
          // No trailing run scheduled: log 'done' once for this burst.
          if (!_catchupDoneLoggedThisBurst) {
            _loggingService.captureEvent(
              _withInstance('catchup.done events=$_lastCatchupEventsCount'),
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

  /// Runs catch-up with proper in-flight guard to prevent concurrent live scans.
  /// This ensures in-order event processing.
  Future<void> runGuardedCatchUp(String source) async {
    if (_catchUpInFlight) {
      _loggingService.captureEvent(
        '$source: skipped (catch-up already in flight)',
        domain: syncLoggingDomain,
        subDomain: 'catchup.guarded',
      );
      return;
    }
    _catchUpInFlight = true;
    _loggingService.captureEvent(
      '$source: starting guarded catch-up',
      domain: syncLoggingDomain,
      subDomain: 'catchup.guarded',
    );
    try {
      await _attachCatchUp();
    } finally {
      _catchUpInFlight = false;
      _flushDeferredLiveScan('runGuardedCatchUp');
    }
  }

  void _scheduleInitialCatchUpRetry() {
    _catchUpRetryTimer?.cancel();
    _catchUpRetryTimer = Timer(const Duration(milliseconds: 500), () {
      if (_initialCatchUpCompleted) return;
      if (_catchUpInFlight) {
        _scheduleInitialCatchUpRetry();
        return;
      }
      _catchUpInFlight = true;
      _loggingService.captureEvent(
        _withInstance('catchup.retry.attempt'),
        domain: syncLoggingDomain,
        subDomain: 'catchup',
      );
      unawaited(
        _attachCatchUp().whenComplete(() {
          _catchUpInFlight = false;
          _flushDeferredLiveScan('catchUpRetry');
        }).then((_) {
          if (!_initialCatchUpCompleted) {
            _loggingService.captureEvent(
              _withInstance('catchup.retry.reschedule (not completed)'),
              domain: syncLoggingDomain,
              subDomain: 'catchup',
            );
            _scheduleInitialCatchUpRetry();
          }
        }).catchError((Object error, StackTrace st) {
          _loggingService.captureException(
            error,
            domain: syncLoggingDomain,
            subDomain: 'catchup.retry',
            stackTrace: st,
          );
          if (!_initialCatchUpCompleted) {
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
    if (_skipSyncWait) return true;

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
    _pendingSyncSubscription =
        client.onSync.stream.first.asStream().listen((syncUpdate) {
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
  Future<bool> _attachCatchUp() async {
    try {
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
      final roomId = _roomManager.currentRoomId;
      if (room == null || roomId == null) {
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
        final marker = !_initialCatchUpCompleted
            ? _startupLastProcessedEventId
            : _processor.lastProcessedEventId;
        _loggingService.captureEvent(
          _withInstance(
            'catchup.start lastEventId=${marker ?? 'null'} (${!_initialCatchUpCompleted ? 'startup' : 'current'})',
          ),
          domain: syncLoggingDomain,
          subDomain: 'catchup',
        );
        _catchupLogStartPending = false;
      }
      final preSinceTs = _startupLastProcessedTs == null
          ? null
          : (_startupLastProcessedTs!.toInt() - 1000); // small skew buffer
      // Use startup marker for initial catch-up to avoid race with live scans
      // that may advance the current marker before catch-up runs.
      final catchUpMarker = !_initialCatchUpCompleted
          ? _startupLastProcessedEventId
          : _processor.lastProcessedEventId;
      final slice = await CatchUpStrategy.collectEventsForCatchUp(
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
      _lastCatchupEventsCount = slice.length;
      if (slice.isNotEmpty) {
        if (_collectMetrics) _metrics.incCatchupBatches();
        // Log event summary for catch-up diagnostics (single pass)
        final counts = slice.fold(
          (payloads: 0, attachments: 0),
          (counts, event) {
            final isPayload =
                ec.MatrixEventClassifier.isSyncPayloadEvent(event);
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
      // Mark initial catch-up as completed and cancel retry timer.
      if (!_initialCatchUpCompleted) {
        _initialCatchUpCompleted = true;
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

    _catchUpInFlight = true;
    _loggingService.captureEvent(
      'wake.catchup.start',
      domain: syncLoggingDomain,
      subDomain: 'wake',
    );

    unawaited(
      _attachCatchUp().then((success) {
        _catchUpInFlight = false;
        _flushDeferredLiveScan('wakeCatchUp');
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
  // Guards against concurrent execution at two levels:
  // 1. _forceRescanCompleter: Serializes forceRescan calls (e.g., connectivity +
  //    startup from MatrixService) so later callers await the in-flight run.
  // 2. _catchUpInFlight: Skips catch-up if one is already running from
  //    runGuardedCatchUp (e.g., catchUpRetry signal), preventing concurrent
  //    attachCatchUp calls that cause processOrdered timeout failures.
  //    Use bypassCatchUpInFlightCheck=true when the caller has already set
  //    _catchUpInFlight (e.g., _startCatchupNow).
  // Live scans are deferred until the initial catch-up completes to avoid
  // recording newer events before older ones are processed.
  Future<void> forceRescan({
    bool includeCatchUp = true,
    bool bypassCatchUpInFlightCheck = false,
  }) async {
    // Prevent concurrent forceRescan calls from external sources.
    // This is separate from _catchUpInFlight which is managed by _startCatchupNow.
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
        // Skip catch-up if one is already running from runGuardedCatchUp.
        // This prevents concurrent attachCatchUp calls which cause
        // processOrdered timeout failures.
        // Bypass check when caller (e.g., _startCatchupNow) has already set the flag.
        if (!bypassCatchUpInFlightCheck && _catchUpInFlight) {
          _loggingService.captureEvent(
            _withInstance('forceRescan.skippedCatchUp (catchUpInFlight)'),
            domain: syncLoggingDomain,
            subDomain: 'forceRescan',
          );
        } else {
          await _attachCatchUp();
        }
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
