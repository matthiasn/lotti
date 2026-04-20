import 'dart:async';
import 'dart:math' as math;

import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/pending_decryption_pen.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// Outcome the [InboundApplyFn] returns to the worker per entry.
enum ApplyOutcome {
  applied,
  retriable,
  missingBase,
  decryptionPending,
  permanentSkip,
}

/// Apply callback contract. Phase-2 wiring plugs in
/// `SyncEventProcessor.prepare` + `apply`; Phase-1 tests pass a mock.
typedef InboundApplyFn =
    Future<ApplyOutcome> Function(
      InboundQueueEntry entry,
      Room room,
    );

const _logDomain = 'sync';
const _logSub = 'queue.worker';

/// Drains [InboundQueue] under the single-worker contract from
/// the queue design. Each drain cycle:
///
/// 1. Optionally waits on [UserActivityGate] so inbound apply does not
///    fight the user's writes (M1).
/// 2. Flushes the [PendingDecryptionPen] so any newly-decrypted events
///    enter the queue before this batch is peeked.
/// 3. Peeks up to [SyncTuning.inboundWorkerBatchSize] ready entries
///    and wraps the batch in
///    `sequenceLogService.runWithDeferredMissingEntries` so the N gap
///    detections inside the slice coalesce into at most one
///    `_emitMissingEntriesDetected` callback — the F1 concern from the
///    design review.
/// 4. Applies each entry in order; commits the marker atomically via
///    [InboundQueue.commitApplied]; retries failures with
///    exponential backoff.
class InboundWorker {
  InboundWorker({
    required InboundQueue queue,
    required SyncSequenceLogService sequenceLogService,
    required Future<Room?> Function() resolveRoom,
    required InboundApplyFn apply,
    required LoggingService logging,
    UserActivityGate? activityGate,
    PendingDecryptionPen? decryptionPen,
    Duration idleTick = const Duration(seconds: 5),
    Duration initialBackoff = const Duration(milliseconds: 500),
    Duration maxBackoff = const Duration(seconds: 30),
    int maxAttempts = 10,
  }) : _queue = queue,
       _sequenceLogService = sequenceLogService,
       _resolveRoom = resolveRoom,
       _apply = apply,
       _logging = logging,
       _activityGate = activityGate,
       _decryptionPen = decryptionPen,
       _idleTick = idleTick,
       _initialBackoff = initialBackoff,
       _maxBackoff = maxBackoff,
       _maxAttempts = maxAttempts;

  final InboundQueue _queue;
  final SyncSequenceLogService _sequenceLogService;
  final Future<Room?> Function() _resolveRoom;
  final InboundApplyFn _apply;
  final LoggingService _logging;
  final UserActivityGate? _activityGate;
  final PendingDecryptionPen? _decryptionPen;
  final Duration _idleTick;
  final Duration _initialBackoff;
  final Duration _maxBackoff;
  final int _maxAttempts;

  Completer<void>? _stopRequested;
  Completer<void>? _loopCompleted;
  bool _running = false;

  bool get isRunning => _running;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    _stopRequested = Completer<void>();
    _loopCompleted = Completer<void>();
    unawaited(_loop());
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _stopRequested?.complete();
    await _loopCompleted?.future;
  }

  /// Drains the queue until it is empty, then returns. Useful for
  /// flag-off transitions and tests — does not subscribe to
  /// [InboundQueue.depthChanges].
  Future<int> drainToCompletion() async {
    var applied = 0;
    while (true) {
      final batch = await _queue.peekBatchReady();
      if (batch.isEmpty) return applied;
      applied += await _runBatch(batch);
    }
  }

  Future<void> _loop() async {
    try {
      while (_running) {
        await _activityGate?.waitUntilIdle();
        final pen = _decryptionPen;
        if (pen != null) {
          final room = await _resolveRoom();
          if (room != null) {
            await pen.flushInto(queue: _queue, room: room);
          }
        }

        final batch = await _queue.peekBatchReady();
        if (batch.isEmpty) {
          await _waitForWork();
          continue;
        }
        await _runBatch(batch);
      }
    } catch (error, stackTrace) {
      _logging.captureException(
        error,
        domain: _logDomain,
        subDomain: '$_logSub.loop',
        stackTrace: stackTrace,
      );
    } finally {
      _loopCompleted?.complete();
    }
  }

  Future<int> _runBatch(List<InboundQueueEntry> batch) async {
    final room = await _resolveRoom();
    if (room == null) {
      _logging.captureEvent(
        'queue.worker.noRoom batch=${batch.length}',
        domain: _logDomain,
        subDomain: _logSub,
      );
      // Release the lease so another drain cycle can retry once the
      // room becomes available. Use a short delay to avoid a spin.
      for (final entry in batch) {
        await _queue.scheduleRetry(
          entry,
          const Duration(seconds: 2),
          reason: RetryReason.retriable,
        );
      }
      return 0;
    }

    var appliedCount = 0;
    await _sequenceLogService.runWithDeferredMissingEntries(() async {
      for (final entry in batch) {
        final outcome = await _applyOne(entry, room);
        switch (outcome) {
          case ApplyOutcome.applied:
            await _queue.commitApplied(entry);
            appliedCount++;
          case ApplyOutcome.retriable:
            await _maybeRetry(entry, RetryReason.retriable);
          case ApplyOutcome.missingBase:
            await _maybeRetry(entry, RetryReason.missingBase);
          case ApplyOutcome.decryptionPending:
            await _maybeRetry(entry, RetryReason.decryptionPending);
          case ApplyOutcome.permanentSkip:
            await _queue.markSkipped(entry, reason: 'permanentSkip');
        }
      }
    });
    return appliedCount;
  }

  Future<ApplyOutcome> _applyOne(
    InboundQueueEntry entry,
    Room room,
  ) async {
    try {
      return await _apply(entry, room);
    } catch (error, stackTrace) {
      _logging.captureException(
        error,
        domain: _logDomain,
        subDomain: '$_logSub.apply',
        stackTrace: stackTrace,
      );
      return ApplyOutcome.retriable;
    }
  }

  Future<void> _maybeRetry(
    InboundQueueEntry entry,
    RetryReason reason,
  ) async {
    final nextAttempts = entry.attempts + 1;
    if (nextAttempts >= _maxAttempts) {
      await _queue.markSkipped(
        entry,
        reason: 'maxAttempts(${reason.name})',
      );
      return;
    }
    await _queue.scheduleRetry(
      entry,
      _backoff(entry.attempts, reason),
      reason: reason,
    );
  }

  Duration _backoff(int attempts, RetryReason reason) {
    // Decryption delays follow a shorter curve: the Megolm session key
    // typically arrives within a couple of seconds, so aggressive
    // backoff wastes time. The other reasons (network/file I/O +
    // missing-base) use a standard exponential curve capped by
    // [_maxBackoff].
    final base = reason == RetryReason.decryptionPending
        ? const Duration(milliseconds: 250)
        : _initialBackoff;
    final millis = base.inMilliseconds * math.pow(2, attempts).toInt();
    final capped = math.min(millis, _maxBackoff.inMilliseconds);
    return Duration(milliseconds: capped);
  }

  Future<void> _waitForWork() async {
    final stopFuture = _stopRequested?.future ?? Future<void>.value();
    final depthFuture = _queue.depthChanges.first.then<void>((_) {});
    final tickFuture = Future<void>.delayed(_idleTick);
    await Future.any<void>([stopFuture, depthFuture, tickFuture]);
  }
}
