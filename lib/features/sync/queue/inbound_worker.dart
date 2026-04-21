import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
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

  /// Drains every entry that is ready at call time, then returns.
  ///
  /// Does not subscribe to [InboundQueue.depthChanges] and does not
  /// sleep for rows with a future `nextDueAt` or an unexpired lease —
  /// those are the caller's problem to re-drive. Used by the Phase-1
  /// worker tests and any future flag-off drain that wants a blocking
  /// "best effort once" pass. A flag-off transition that needs a true
  /// wait-until-empty contract should layer that on top of this method
  /// (repeatedly call after elapsing backoffs), not hide the wait
  /// inside this primitive.
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
        await _waitUntilIdleOrStopped();
        if (!_running) break;
        final pen = _decryptionPen;
        if (pen != null) {
          final room = await _resolveRoom();
          if (room != null) {
            await pen.flushInto(queue: _queue, room: room);
          }
        }

        // Subscribe to depthChanges BEFORE peeking so an enqueue that
        // lands during the peek cannot be missed: if the subscription
        // were attached after a peek-empty outcome, the signal for an
        // enqueue in that gap would land on a dead stream.
        final depthTrigger = Completer<void>();
        final depthSub = _queue.depthChanges.listen((_) {
          if (!depthTrigger.isCompleted) depthTrigger.complete();
        });

        final batch = await _queue.peekBatchReady();
        if (batch.isEmpty) {
          try {
            await _waitForWork(depthTrigger.future);
          } finally {
            await depthSub.cancel();
          }
          continue;
        }
        await depthSub.cancel();
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
      // Clear `_running` even when the loop exits via the catch block
      // so a later `start()` can relaunch the worker cleanly. Without
      // this the worker would silently stop processing after any
      // uncaught error inside the loop body.
      _running = false;
      _loopCompleted?.complete();
    }
  }

  /// Awaits whichever of the activity gate or the stop signal resolves
  /// first. A wedged gate must not prevent `stop()` from returning.
  Future<void> _waitUntilIdleOrStopped() async {
    final idleFuture = _activityGate?.waitUntilIdle();
    if (idleFuture == null) return;
    final stopFuture = _stopRequested?.future;
    if (stopFuture == null) {
      await idleFuture;
      return;
    }
    await Future.any<void>([idleFuture, stopFuture]);
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
      // room becomes available. Batched in a single sync_db
      // transaction to avoid N round trips for the common wedged-room
      // path.
      await _queue.runInTransaction(() async {
        for (final entry in batch) {
          await _queue.scheduleRetry(
            entry,
            const Duration(seconds: 2),
            reason: RetryReason.retriable,
          );
        }
      });
      return 0;
    }

    var appliedCount = 0;
    await _sequenceLogService.runWithDeferredMissingEntries(() async {
      // Phase 1: apply each entry outside any sync_db transaction —
      // apply may write to journal_db and we do not want sync_db
      // locked while journal_db does I/O. Accumulate outcomes so the
      // second phase can commit/retry/skip in one sync_db transaction.
      final outcomes = <_EntryOutcome>[];
      for (final entry in batch) {
        final outcome = await _applyOne(entry, room);
        outcomes.add(_EntryOutcome(entry, outcome));
      }

      // Phase 2: coalesce every queue-side write for the batch into a
      // single sync_db transaction, so a slice of 20 entries performs
      // one commit instead of up to 20 back-to-back.
      await _queue.runInTransaction(() async {
        for (final pair in outcomes) {
          switch (pair.outcome) {
            case ApplyOutcome.applied:
              await _queue.commitApplied(pair.entry);
              appliedCount++;
            case ApplyOutcome.retriable:
              await _maybeRetry(pair.entry, RetryReason.retriable);
            case ApplyOutcome.missingBase:
              await _maybeRetry(pair.entry, RetryReason.missingBase);
            case ApplyOutcome.decryptionPending:
              await _maybeRetry(pair.entry, RetryReason.decryptionPending);
            case ApplyOutcome.permanentSkip:
              await _queue.markSkipped(pair.entry, reason: 'permanentSkip');
          }
        }
      });
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

  /// Races stop, a depthChanges signal, and a delay that matches the
  /// queue's earliest ready timestamp. Without the ready-aware delay,
  /// a queue that only contains rows with a future `nextDueAt` (every
  /// retry path — retriable, missingBase, decryptionPending, noRoom)
  /// would round its intended 250 ms / 500 ms / 2 s backoff up to
  /// `_idleTick` (5 s by default), delaying recovery and starving the
  /// bootstrap back-pressure contract.
  Future<void> _waitForWork(Future<void> depthFuture) async {
    final stopFuture = _stopRequested?.future ?? Future<void>.value();
    final readyAt = await _queue.earliestReadyAt();
    final nowMs = clock.now().millisecondsSinceEpoch;
    final Duration delay;
    if (readyAt == null) {
      // Queue is empty — sleep until either stop or a new depth
      // signal. The tick bound is a safety net, not the primary exit.
      delay = _idleTick;
    } else {
      final deltaMs = readyAt - nowMs;
      delay = deltaMs <= 0
          ? const Duration(milliseconds: 1)
          : Duration(milliseconds: deltaMs);
    }
    final tickFuture = Future<void>.delayed(delay);
    await Future.any<void>([stopFuture, depthFuture, tickFuture]);
  }
}

class _EntryOutcome {
  const _EntryOutcome(this.entry, this.outcome);

  final InboundQueueEntry entry;
  final ApplyOutcome outcome;
}
