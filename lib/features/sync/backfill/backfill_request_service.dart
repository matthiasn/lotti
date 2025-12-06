import 'dart:async';

import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:meta/meta.dart';

/// Service responsible for periodically sending backfill requests
/// for missing entries detected in the sync sequence log.
class BackfillRequestService {
  BackfillRequestService({
    required SyncSequenceLogService sequenceLogService,
    required OutboxService outboxService,
    required VectorClockService vectorClockService,
    required LoggingService loggingService,
    Duration? requestInterval,
    int? maxBatchSize,
    int? maxRequestCount,
  })  : _sequenceLogService = sequenceLogService,
        _outboxService = outboxService,
        _vectorClockService = vectorClockService,
        _loggingService = loggingService,
        _requestInterval =
            requestInterval ?? SyncTuning.backfillRequestInterval,
        _maxBatchSize = maxBatchSize ?? SyncTuning.backfillBatchSize,
        _maxRequestCount =
            maxRequestCount ?? SyncTuning.backfillMaxRequestCount;

  final SyncSequenceLogService _sequenceLogService;
  final OutboxService _outboxService;
  final VectorClockService _vectorClockService;
  final LoggingService _loggingService;
  final Duration _requestInterval;
  final int _maxBatchSize;
  final int _maxRequestCount;

  Timer? _timer;
  bool _isProcessing = false;
  bool _isDisposed = false;

  /// Start the periodic backfill request processing.
  void start() {
    if (_isDisposed) return;

    _timer?.cancel();
    _timer =
        Timer.periodic(_requestInterval, (_) => _processBackfillRequests());

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
  Future<void> processNow() => _processBackfillRequests();

  /// Main processing logic - fetch missing entries and send backfill requests.
  Future<void> _processBackfillRequests() async {
    if (_isDisposed || _isProcessing) return;
    _isProcessing = true;

    try {
      // Use smart retry: only request from hosts that have been active
      // since our last request (prevents wasteful repeated requests)
      final missing = await _sequenceLogService.getMissingEntriesForActiveHosts(
        limit: _maxBatchSize,
        maxRequestCount: _maxRequestCount,
      );

      if (missing.isEmpty) {
        _loggingService.captureEvent(
          'processBackfillRequests: no missing entries',
          domain: 'SYNC_BACKFILL',
          subDomain: 'process',
        );
        return;
      }

      final requesterId = await _vectorClockService.getHost();
      if (requesterId == null) {
        _loggingService.captureEvent(
          'processBackfillRequests: no host ID available, skipping',
          domain: 'SYNC_BACKFILL',
          subDomain: 'process',
        );
        return;
      }

      // Batch entries into messages (up to backfillMessageBatchSize per message)
      final entries = missing
          .map(
            (item) => BackfillRequestEntry(
              hostId: item.hostId,
              counter: item.counter,
            ),
          )
          .toList();

      // Send batched request(s)
      for (var i = 0;
          i < entries.length;
          i += SyncTuning.backfillMessageBatchSize) {
        final batch = entries.sublist(
          i,
          (i + SyncTuning.backfillMessageBatchSize).clamp(0, entries.length),
        );
        await _outboxService.enqueueMessage(
          SyncMessage.backfillRequest(
            entries: batch,
            requesterId: requesterId,
          ),
        );
      }

      // Mark all as requested (increments request count and sets lastRequestedAt)
      await _sequenceLogService.markAsRequested(
        missing.map((m) => (hostId: m.hostId, counter: m.counter)).toList(),
      );

      _loggingService.captureEvent(
        'processBackfillRequests: sent ${missing.length} requests in ${(entries.length / SyncTuning.backfillMessageBatchSize).ceil()} batch(es)',
        domain: 'SYNC_BACKFILL',
        subDomain: 'process',
      );
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'SYNC_BACKFILL',
        subDomain: 'process',
        stackTrace: st,
      );
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
