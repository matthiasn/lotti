// ignore_for_file: one_member_abstracts, sort_constructors_first

import 'dart:convert';

import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/logging_service.dart';

abstract class OutboxMessageSender {
  Future<bool> send(SyncMessage message);
}

class OutboxProcessingResult {
  const OutboxProcessingResult._({this.nextDelay});

  final Duration? nextDelay;

  static const OutboxProcessingResult none = OutboxProcessingResult._();

  factory OutboxProcessingResult.schedule(Duration delay) =>
      OutboxProcessingResult._(nextDelay: delay);

  bool get shouldSchedule => nextDelay != null;
}

class OutboxProcessor {
  OutboxProcessor({
    required OutboxRepository repository,
    required OutboxMessageSender messageSender,
    required LoggingService loggingService,
    int? batchSizeOverride,
    Duration? retryDelayOverride,
    Duration? errorDelayOverride,
    int? maxRetriesOverride,
    Duration? sendTimeoutOverride,
  })  : _repository = repository,
        _messageSender = messageSender,
        _loggingService = loggingService,
        batchSize = batchSizeOverride ?? 10,
        retryDelay = retryDelayOverride ?? SyncTuning.outboxRetryDelay,
        errorDelay = errorDelayOverride ?? SyncTuning.outboxErrorDelay,
        maxRetriesForDiagnostics =
            maxRetriesOverride ?? SyncTuning.outboxMaxRetriesDiagnostics,
        sendTimeout = sendTimeoutOverride ?? SyncTuning.outboxSendTimeout;

  final OutboxRepository _repository;
  final OutboxMessageSender _messageSender;
  final LoggingService _loggingService;
  final int batchSize;
  final Duration retryDelay;
  final Duration errorDelay;
  final int maxRetriesForDiagnostics;
  final Duration sendTimeout;

  // Diagnostics for repeated failures on the same head-of-queue subject.
  String? _lastFailedSubject;
  int _lastFailedRepeats = 0;

  Future<OutboxProcessingResult> processQueue() async {
    final pendingItems = await _repository.fetchPending(limit: batchSize);
    if (pendingItems.isEmpty) {
      return OutboxProcessingResult.none;
    }

    final nextItem = pendingItems.first;
    try {
      _loggingService.captureEvent(
        'pending=${pendingItems.length} head=${nextItem.subject}',
        domain: 'OUTBOX',
        subDomain: 'queue',
      );
    } catch (_) {
      // best-effort logging only
    }
    _loggingService.captureEvent(
      'trying ${nextItem.subject} ',
      domain: 'OUTBOX',
      subDomain: 'sendNext()',
    );

    try {
      // Re-read item to get the latest message after any merges that may
      // have occurred since fetchPending(). This ensures coveredVectorClocks
      // accumulated during the processing delay are included.
      final refreshedItem = await _repository.refreshItem(nextItem);
      if (refreshedItem == null) {
        // Item was deleted or status changed during processing
        try {
          _loggingService.captureEvent(
            'skip ${nextItem.subject} - item no longer pending',
            domain: 'OUTBOX',
            subDomain: 'sendNext()',
          );
        } catch (_) {}
        // Continue to next item immediately
        final hasMore = pendingItems.length > 1;
        return hasMore
            ? OutboxProcessingResult.schedule(Duration.zero)
            : OutboxProcessingResult.none;
      }

      final syncMessage = _decodeMessage(refreshedItem);
      // Log the decoded message type to improve visibility, especially for links
      try {
        _loggingService.captureEvent(
          'sending type=${syncMessage.runtimeType} subject=${refreshedItem.subject}',
          domain: 'OUTBOX',
          subDomain: 'sendNext()',
        );
      } catch (_) {
        // best-effort logging only
      }
      var timedOut = false;
      final success = await _messageSender
          .send(syncMessage)
          .timeout(sendTimeout, onTimeout: () {
        timedOut = true;
        return false;
      });

      if (!success) {
        final nextAttempts = refreshedItem.retries + 1;
        await _repository.markRetry(refreshedItem);
        // Track repeated failures for quick visibility on head-of-queue pins.
        if (_lastFailedSubject == refreshedItem.subject) {
          _lastFailedRepeats++;
        } else {
          _lastFailedSubject = refreshedItem.subject;
          _lastFailedRepeats = 1;
        }
        try {
          _loggingService.captureEvent(
            'sendFailed subject=${refreshedItem.subject} attempts=$nextAttempts repeats=$_lastFailedRepeats backoffMs=${retryDelay.inMilliseconds} timedOut=$timedOut',
            domain: 'OUTBOX',
            subDomain: 'retry',
          );
        } catch (_) {}
        if (nextAttempts >= maxRetriesForDiagnostics) {
          try {
            _loggingService.captureEvent(
              'retryCapReached subject=${refreshedItem.subject} attempts=$nextAttempts status=error → skip/head-advance',
              domain: 'OUTBOX',
              subDomain: 'retry.cap',
            );
          } catch (_) {}
          // The repository marks status=error at cap. Continue immediately to the next item.
          return OutboxProcessingResult.schedule(Duration.zero);
        }
        return OutboxProcessingResult.schedule(retryDelay);
      }

      await _repository.markSent(refreshedItem);
      _loggingService.captureEvent(
        '${refreshedItem.subject} done',
        domain: 'OUTBOX',
        subDomain: 'sendNext()',
      );
      // Reset repeat tracker on success for this subject.
      if (_lastFailedSubject == refreshedItem.subject) {
        _lastFailedSubject = null;
        _lastFailedRepeats = 0;
      }

      final hasMore = pendingItems.length > 1;
      if (hasMore) {
        try {
          _loggingService.captureEvent(
            'scheduleNext immediate (hasMore)',
            domain: 'OUTBOX',
            subDomain: 'queue',
          );
        } catch (_) {}
        return OutboxProcessingResult.schedule(Duration.zero);
      }
      return OutboxProcessingResult.none;
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'OUTBOX',
        subDomain: 'sendNext',
        stackTrace: stackTrace,
      );
      final nextAttempts = nextItem.retries + 1;
      await _repository.markRetry(nextItem);
      if (_lastFailedSubject == nextItem.subject) {
        _lastFailedRepeats++;
      } else {
        _lastFailedSubject = nextItem.subject;
        _lastFailedRepeats = 1;
      }
      try {
        _loggingService.captureEvent(
          'sendException subject=${nextItem.subject} attempts=$nextAttempts repeats=$_lastFailedRepeats backoffMs=${errorDelay.inMilliseconds}',
          domain: 'OUTBOX',
          subDomain: 'retry',
        );
      } catch (_) {}
      if (nextAttempts >= maxRetriesForDiagnostics) {
        try {
          _loggingService.captureEvent(
            'retryCapReached subject=${nextItem.subject} attempts=$nextAttempts status=error → skip/head-advance',
            domain: 'OUTBOX',
            subDomain: 'retry.cap',
          );
        } catch (_) {}
        return OutboxProcessingResult.schedule(Duration.zero);
      }
      return OutboxProcessingResult.schedule(errorDelay);
    }
  }

  SyncMessage _decodeMessage(OutboxItem item) {
    final jsonMap = json.decode(item.message) as Map<String, dynamic>;
    return SyncMessage.fromJson(jsonMap);
  }
}
