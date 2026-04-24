// ignore_for_file: one_member_abstracts, sort_constructors_first

import 'dart:async';
import 'dart:convert';

import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_repository.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/domain_logging.dart';
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
    Duration? retryDelayOverride,
    Duration? errorDelayOverride,
    int? maxRetriesOverride,
    Duration? sendTimeoutOverride,
    Duration? claimLeaseOverride,
    DomainLogger? domainLogger,
  }) : _repository = repository,
       _messageSender = messageSender,
       _loggingService = loggingService,
       _domainLogger = domainLogger,
       retryDelay = retryDelayOverride ?? SyncTuning.outboxRetryDelay,
       errorDelay = errorDelayOverride ?? SyncTuning.outboxErrorDelay,
       maxRetriesForDiagnostics =
           maxRetriesOverride ?? SyncTuning.outboxMaxRetriesDiagnostics,
       sendTimeout = sendTimeoutOverride ?? SyncTuning.outboxSendTimeout,
       claimLease = claimLeaseOverride ?? SyncTuning.outboxClaimLease;

  final OutboxRepository _repository;
  final OutboxMessageSender _messageSender;
  final LoggingService _loggingService;
  final DomainLogger? _domainLogger;
  final Duration retryDelay;
  final Duration errorDelay;
  final int maxRetriesForDiagnostics;
  final Duration sendTimeout;
  final Duration claimLease;

  void _syncLog(String message, {String? subDomain}) {
    _domainLogger?.log(LogDomains.sync, message, subDomain: subDomain);
  }

  // Diagnostics for repeated failures on the same head-of-queue subject.
  String? _lastFailedSubject;
  int _lastFailedRepeats = 0;

  Future<OutboxProcessingResult> processQueue() async {
    // Atomic claim (pending → sending). Closes the merge-send race: while
    // we are sending, the row's status is `sending`, so in-flight merges'
    // `updateOutboxMessage` (which matches `status=pending`) returns
    // affectedRows=0 and falls through to inserting a fresh row — the
    // merged content still rides a later Matrix event instead of being
    // silently overwritten into an already-sent row.
    final claimedItem = await _repository.claim(leaseDuration: claimLease);
    if (claimedItem == null) {
      return OutboxProcessingResult.none;
    }

    // Tracks whether the row has already been committed as sent so the
    // exception handler below does not revive an already-sent row. Without
    // this, a throw from the post-send observability path (hasMorePending,
    // captureEvent) would run `markRetry` on a row we've just acknowledged —
    // re-sending the same Matrix event on the next pass.
    var markedSent = false;

    try {
      final syncMessage = _decodeMessage(claimedItem);
      final sendStart = DateTime.now();
      var timedOut = false;
      final success = await _messageSender
          .send(syncMessage)
          .timeout(
            sendTimeout,
            onTimeout: () {
              timedOut = true;
              return false;
            },
          );

      if (!success) {
        final nextAttempts = claimedItem.retries + 1;
        await _repository.markRetry(claimedItem);
        _syncLog(
          'sendFail subject=${claimedItem.subject} attempts=$nextAttempts timedOut=$timedOut',
          subDomain: 'outbox.retry',
        );
        // Track repeated failures for quick visibility on head-of-queue pins.
        if (_lastFailedSubject == claimedItem.subject) {
          _lastFailedRepeats++;
        } else {
          _lastFailedSubject = claimedItem.subject;
          _lastFailedRepeats = 1;
        }
        try {
          _loggingService.captureEvent(
            'sendFailed subject=${claimedItem.subject} attempts=$nextAttempts repeats=$_lastFailedRepeats backoffMs=${retryDelay.inMilliseconds} timedOut=$timedOut',
            domain: 'OUTBOX',
            subDomain: 'retry',
          );
        } catch (_) {}
        if (nextAttempts >= maxRetriesForDiagnostics) {
          try {
            _loggingService.captureEvent(
              'retryCapReached subject=${claimedItem.subject} attempts=$nextAttempts status=error → skip/head-advance',
              domain: 'OUTBOX',
              subDomain: 'retry.cap',
            );
          } catch (_) {}
          // The repository marks status=error at cap. Continue immediately to the next item.
          return OutboxProcessingResult.schedule(Duration.zero);
        }
        return OutboxProcessingResult.schedule(retryDelay);
      }

      await _repository.markSent(claimedItem);
      markedSent = true;
      final elapsedMs = DateTime.now().difference(sendStart).inMilliseconds;
      final hasMore = await _repository.hasMorePending();
      _loggingService.captureEvent(
        'sent type=${syncMessage.runtimeType} subject=${claimedItem.subject} '
        'retries=${claimedItem.retries} ms=$elapsedMs '
        'pending=${hasMore ? 2 : 1}',
        domain: 'OUTBOX',
        subDomain: 'outbox.send',
      );
      // Reset repeat tracker on success for this subject.
      if (_lastFailedSubject == claimedItem.subject) {
        _lastFailedSubject = null;
        _lastFailedRepeats = 0;
      }

      return hasMore
          ? OutboxProcessingResult.schedule(Duration.zero)
          : OutboxProcessingResult.none;
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'OUTBOX',
        subDomain: 'sendNext',
        stackTrace: stackTrace,
      );
      // If the row is already sent, the exception happened in the post-send
      // observability path (hasMorePending/logging). Swallow it here — we do
      // not want markRetry to revive a sent row and cause duplicate delivery.
      if (markedSent) {
        return OutboxProcessingResult.schedule(Duration.zero);
      }
      final nextAttempts = claimedItem.retries + 1;
      await _repository.markRetry(claimedItem);
      if (_lastFailedSubject == claimedItem.subject) {
        _lastFailedRepeats++;
      } else {
        _lastFailedSubject = claimedItem.subject;
        _lastFailedRepeats = 1;
      }
      try {
        _loggingService.captureEvent(
          'sendException subject=${claimedItem.subject} attempts=$nextAttempts repeats=$_lastFailedRepeats backoffMs=${errorDelay.inMilliseconds}',
          domain: 'OUTBOX',
          subDomain: 'retry',
        );
      } catch (_) {}
      if (nextAttempts >= maxRetriesForDiagnostics) {
        try {
          _loggingService.captureEvent(
            'retryCapReached subject=${claimedItem.subject} attempts=$nextAttempts status=error → skip/head-advance',
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
