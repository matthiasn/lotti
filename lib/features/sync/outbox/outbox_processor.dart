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
    required this._repository,
    required this._messageSender,
    required this._loggingService,
    Duration? retryDelayOverride,
    Duration? errorDelayOverride,
    int? maxRetriesOverride,
    Duration? sendTimeoutOverride,
    Duration? claimLeaseOverride,
    this._domainLogger,
    int? bundleMaxSizeOverride,
  }) : bundleMaxSize = bundleMaxSizeOverride ?? SyncTuning.outboxBundleMaxSize,
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
  final int bundleMaxSize;
  final Duration retryDelay;
  final Duration errorDelay;
  final int maxRetriesForDiagnostics;
  final Duration sendTimeout;
  final Duration claimLease;

  void _syncLog(String message, {String? subDomain}) {
    _domainLogger?.log(LogDomain.sync, message, subDomain: subDomain);
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
    //
    // The batch claim enforces the bundling boundary rule: media
    // attachments always travel alone; text rows pack up to [bundleMaxSize]
    // consecutive rows stopping before the next attachment. A single-row
    // batch routes through [_processSingle] so the wire format stays
    // byte-for-byte identical to the pre-bundling behavior when only one
    // row is pending.
    final batch = await _repository.claimNextBatch(
      maxSize: bundleMaxSize,
      leaseDuration: claimLease,
    );
    if (batch.isEmpty) {
      return OutboxProcessingResult.none;
    }
    if (batch.length == 1) {
      return _processSingle(batch.first);
    }
    return _processBundle(batch);
  }

  Future<OutboxProcessingResult> _processSingle(OutboxItem claimedItem) async {
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

  Future<OutboxProcessingResult> _processBundle(
    List<OutboxItem> claimedBatch,
  ) async {
    // Head subject anchors all head-of-queue diagnostics. The bundle is one
    // logical send attempt; per-row retries++/error-cap accounting still
    // happens row-by-row inside [OutboxRepository.markRetryBatch], so a
    // rotten head row eventually flips to error and the next drain claims a
    // smaller bundle without it.
    final headSubject = claimedBatch.first.subject;
    final bundleSize = claimedBatch.length;

    var markedSent = false;
    try {
      final children = <SyncMessage>[];
      for (final item in claimedBatch) {
        children.add(_decodeMessage(item));
      }
      final bundle = SyncMessage.outboxBundle(children: children);

      final sendStart = DateTime.now();
      var timedOut = false;
      final success = await _messageSender
          .send(bundle)
          .timeout(
            sendTimeout,
            onTimeout: () {
              timedOut = true;
              return false;
            },
          );

      if (!success) {
        final nextAttempts = claimedBatch.first.retries + 1;
        await _repository.markRetryBatch(claimedBatch);
        _syncLog(
          'bundleSendFail size=$bundleSize headSubject=$headSubject '
          'attempts=$nextAttempts timedOut=$timedOut',
          subDomain: 'outbox.retry',
        );
        if (_lastFailedSubject == headSubject) {
          _lastFailedRepeats++;
        } else {
          _lastFailedSubject = headSubject;
          _lastFailedRepeats = 1;
        }
        try {
          _loggingService.captureEvent(
            'bundleSendFailed size=$bundleSize headSubject=$headSubject '
            'attempts=$nextAttempts repeats=$_lastFailedRepeats '
            'backoffMs=${retryDelay.inMilliseconds} timedOut=$timedOut',
            domain: 'OUTBOX',
            subDomain: 'retry',
          );
        } catch (_) {}
        // If any row in the bundle just hit the retry cap, fast-path the
        // next drain. The repository has already flipped those rows to
        // error in the same transaction; the next claim will skip them.
        final capReached = claimedBatch.any(
          (row) => row.retries + 1 >= maxRetriesForDiagnostics,
        );
        if (capReached) {
          try {
            _loggingService.captureEvent(
              'retryCapReached headSubject=$headSubject size=$bundleSize '
              'attempts=$nextAttempts status=error → skip/head-advance',
              domain: 'OUTBOX',
              subDomain: 'retry.cap',
            );
          } catch (_) {}
          return OutboxProcessingResult.schedule(Duration.zero);
        }
        return OutboxProcessingResult.schedule(retryDelay);
      }

      await _repository.markSentBatch(claimedBatch);
      markedSent = true;
      final elapsedMs = DateTime.now().difference(sendStart).inMilliseconds;
      final hasMore = await _repository.hasMorePending();
      _loggingService.captureEvent(
        'bundleSent size=$bundleSize headSubject=$headSubject '
        'ms=$elapsedMs pending=${hasMore ? 2 : 1}',
        domain: 'OUTBOX',
        subDomain: 'outbox.send',
      );
      if (_lastFailedSubject == headSubject) {
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
        subDomain: 'sendNext.bundle',
        stackTrace: stackTrace,
      );
      if (markedSent) {
        return OutboxProcessingResult.schedule(Duration.zero);
      }
      final nextAttempts = claimedBatch.first.retries + 1;
      await _repository.markRetryBatch(claimedBatch);
      if (_lastFailedSubject == headSubject) {
        _lastFailedRepeats++;
      } else {
        _lastFailedSubject = headSubject;
        _lastFailedRepeats = 1;
      }
      try {
        _loggingService.captureEvent(
          'bundleSendException size=$bundleSize headSubject=$headSubject '
          'attempts=$nextAttempts repeats=$_lastFailedRepeats '
          'backoffMs=${errorDelay.inMilliseconds}',
          domain: 'OUTBOX',
          subDomain: 'retry',
        );
      } catch (_) {}
      final capReached = claimedBatch.any(
        (row) => row.retries + 1 >= maxRetriesForDiagnostics,
      );
      if (capReached) {
        try {
          _loggingService.captureEvent(
            'retryCapReached headSubject=$headSubject size=$bundleSize '
            'attempts=$nextAttempts status=error → skip/head-advance',
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
