import 'dart:async';

import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/state/backfill_config_controller.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:meta/meta.dart';

/// Service responsible for periodically sending backfill requests
/// for missing entries detected in the sync sequence log.
///
/// By default, automatic backfill is bounded to recent entries (last day,
/// max 250 per host). For full historical backfill, use [processFullBackfill].
class BackfillRequestService {
  BackfillRequestService({
    required SyncSequenceLogService sequenceLogService,
    required SyncDatabase syncDatabase,
    required OutboxService outboxService,
    required VectorClockService vectorClockService,
    required LoggingService loggingService,
    Duration? requestInterval,
    int? maxBatchSize,
    int? maxRequestCount,
    Duration? maxAge,
    int? maxPerHost,
  })  : _sequenceLogService = sequenceLogService,
        _syncDatabase = syncDatabase,
        _outboxService = outboxService,
        _vectorClockService = vectorClockService,
        _loggingService = loggingService,
        _requestInterval =
            requestInterval ?? SyncTuning.backfillRequestInterval,
        // Use processing batch size for per-cycle limits (smaller to avoid
        // overwhelming the network). backfillBatchSize is for DB fetch limits.
        _maxBatchSize = maxBatchSize ?? SyncTuning.backfillProcessingBatchSize,
        _maxRequestCount =
            maxRequestCount ?? SyncTuning.backfillMaxRequestCount,
        _maxAge = maxAge ?? SyncTuning.defaultBackfillMaxAge,
        _maxPerHost = maxPerHost ?? SyncTuning.defaultBackfillMaxEntriesPerHost;

  final SyncSequenceLogService _sequenceLogService;
  final SyncDatabase _syncDatabase;
  final OutboxService _outboxService;
  final VectorClockService _vectorClockService;
  final LoggingService _loggingService;
  final Duration _requestInterval;
  final int _maxBatchSize;
  final int _maxRequestCount;
  final Duration _maxAge;
  final int _maxPerHost;

  Timer? _timer;
  bool _isProcessing = false;
  bool _isDisposed = false;

  /// Start the periodic backfill request processing.
  /// Uses bounded limits (age and per-host) for automatic backfill.
  void start() {
    if (_isDisposed) return;

    _timer?.cancel();
    _timer = Timer.periodic(
      _requestInterval,
      (_) => _processBackfillRequests(useLimits: true),
    );

    _loggingService.captureEvent(
      'start interval=${_requestInterval.inSeconds}s batchSize=$_maxBatchSize maxRetries=$_maxRequestCount',
      domain: 'SYNC_BACKFILL',
      subDomain: 'start',
    );
  }

  /// Stop periodic processing.
  void stop() {
    _timer?.cancel();
    _timer = null;

    _loggingService.captureEvent(
      'stop',
      domain: 'SYNC_BACKFILL',
      subDomain: 'stop',
    );
  }

  /// Force immediate processing (for testing or manual trigger).
  /// Uses bounded limits (age and per-host).
  Future<void> processNow() => _processBackfillRequests(useLimits: true);

  /// Process full historical backfill without age/per-host limits.
  /// This should be triggered manually from the UI.
  /// Note: This ignores the enabled flag since it's a manual trigger.
  Future<int> processFullBackfill() async {
    return _processBackfillRequests(useLimits: false, ignoreEnabledFlag: true);
  }

  /// Re-request entries that are in 'requested' status but haven't been received.
  /// This resets their request counts and sends new backfill requests.
  /// Uses pagination to process all requested entries, not just the batch size.
  Future<int> processReRequest() async {
    if (_isDisposed || _isProcessing) return 0;

    _isProcessing = true;
    var totalProcessed = 0;

    try {
      final requesterId = await _vectorClockService.getHost();
      if (requesterId == null) {
        _loggingService.captureEvent(
          'processReRequest: no host ID available, skipping',
          domain: 'SYNC_BACKFILL',
          subDomain: 'reRequest',
        );
        return 0;
      }

      // Process in batches until no more requested entries
      while (true) {
        // Get next batch of requested entries
        var requested = await _sequenceLogService.getRequestedEntries(
          limit: _maxBatchSize,
        );

        if (requested.isEmpty) break;

        // Filter out entries that are already queued in the outbox
        final alreadyQueued = await _syncDatabase.getPendingBackfillEntries();
        if (alreadyQueued.isNotEmpty) {
          requested = requested
              .where(
                (m) => !alreadyQueued
                    .contains((hostId: m.hostId, counter: m.counter)),
              )
              .toList();
        }

        if (requested.isEmpty) break;

        // Reset request counts for these entries
        final entries = requested
            .map((item) => (hostId: item.hostId, counter: item.counter))
            .toList();
        await _sequenceLogService.resetRequestCounts(entries);

        // Build request entries
        final requestEntries = requested
            .map(
              (item) => BackfillRequestEntry(
                hostId: item.hostId,
                counter: item.counter,
              ),
            )
            .toList();

        // Send backfill request message
        await _outboxService.enqueueMessage(
          SyncMessage.backfillRequest(
            entries: requestEntries,
            requesterId: requesterId,
          ),
        );

        // Mark all as requested (increments request count and sets lastRequestedAt)
        await _sequenceLogService.markAsRequested(entries);

        totalProcessed += requested.length;

        _loggingService.captureEvent(
          'processReRequest: sent ${requested.length} re-requests (total: $totalProcessed)',
          domain: 'SYNC_BACKFILL',
          subDomain: 'reRequest',
        );
      }

      _loggingService.captureEvent(
        'processReRequest: completed, total $totalProcessed entries re-requested',
        domain: 'SYNC_BACKFILL',
        subDomain: 'reRequest',
      );

      return totalProcessed;
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'SYNC_BACKFILL',
        subDomain: 'reRequest',
        stackTrace: st,
      );
      return totalProcessed;
    } finally {
      _isProcessing = false;
    }
  }

  /// Main processing logic - fetch missing entries and send backfill requests.
  /// [useLimits] - If true, apply age and per-host limits for automatic backfill.
  /// [ignoreEnabledFlag] - If true, process even when backfill is disabled (for manual trigger).
  Future<int> _processBackfillRequests({
    required bool useLimits,
    bool ignoreEnabledFlag = false,
  }) async {
    if (_isDisposed || _isProcessing) return 0;

    // Check if backfill is enabled (skip check for manual triggers)
    if (!ignoreEnabledFlag) {
      final enabled = await isBackfillEnabled();
      if (!enabled) {
        _loggingService.captureEvent(
          'processBackfillRequests: backfill is disabled, skipping',
          domain: 'SYNC_BACKFILL',
          subDomain: 'process',
        );
        return 0;
      }
    }

    _isProcessing = true;

    try {
      // Get missing entries - either with limits (automatic) or without (manual)
      // For manual full backfill, use getMissingEntries which doesn't filter
      // by host activity, allowing backfill from hosts not recently seen.
      var missing = useLimits
          ? await _sequenceLogService.getMissingEntriesWithLimits(
              limit: _maxBatchSize,
              maxRequestCount: _maxRequestCount,
              maxAge: _maxAge,
              maxPerHost: _maxPerHost,
            )
          : await _sequenceLogService.getMissingEntries(
              limit: _maxBatchSize,
              maxRequestCount: _maxRequestCount,
            );

      if (missing.isEmpty) {
        _loggingService.captureEvent(
          'processBackfillRequests: no missing entries (useLimits=$useLimits)',
          domain: 'SYNC_BACKFILL',
          subDomain: 'process',
        );
        return 0;
      }

      // Filter out entries that are already queued in the outbox
      final alreadyQueued = await _syncDatabase.getPendingBackfillEntries();
      if (alreadyQueued.isNotEmpty) {
        final beforeCount = missing.length;
        missing = missing
            .where(
              (m) => !alreadyQueued
                  .contains((hostId: m.hostId, counter: m.counter)),
            )
            .toList();
        final filtered = beforeCount - missing.length;
        if (filtered > 0) {
          _loggingService.captureEvent(
            'processBackfillRequests: filtered $filtered already-queued entries',
            domain: 'SYNC_BACKFILL',
            subDomain: 'process',
          );
        }
      }

      if (missing.isEmpty) {
        _loggingService.captureEvent(
          'processBackfillRequests: all entries already queued (useLimits=$useLimits)',
          domain: 'SYNC_BACKFILL',
          subDomain: 'process',
        );
        return 0;
      }

      final requesterId = await _vectorClockService.getHost();
      if (requesterId == null) {
        _loggingService.captureEvent(
          'processBackfillRequests: no host ID available, skipping',
          domain: 'SYNC_BACKFILL',
          subDomain: 'process',
        );
        return 0;
      }

      // Build request entries
      final entries = missing
          .map(
            (item) => BackfillRequestEntry(
              hostId: item.hostId,
              counter: item.counter,
            ),
          )
          .toList();

      // Send single backfill request message
      await _outboxService.enqueueMessage(
        SyncMessage.backfillRequest(
          entries: entries,
          requesterId: requesterId,
        ),
      );

      // Mark all as requested (increments request count and sets lastRequestedAt)
      await _sequenceLogService.markAsRequested(
        missing.map((m) => (hostId: m.hostId, counter: m.counter)).toList(),
      );

      _loggingService.captureEvent(
        'processBackfillRequests: sent ${missing.length} requests (useLimits=$useLimits)',
        domain: 'SYNC_BACKFILL',
        subDomain: 'process',
      );

      return missing.length;
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'SYNC_BACKFILL',
        subDomain: 'process',
        stackTrace: st,
      );
      return 0;
    } finally {
      _isProcessing = false;
    }
  }

  /// Dispose of the service and cancel the timer.
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _timer = null;
  }

  /// Exposed for tests to check timer state.
  @visibleForTesting
  bool get isRunning => _timer != null && _timer!.isActive;

  /// Exposed for tests to check processing state.
  @visibleForTesting
  bool get isProcessing => _isProcessing;
}
