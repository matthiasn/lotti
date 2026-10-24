import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/features/sync/instrumentation/sync_cost_meter.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_queue_gateway.dart';
import 'package:lotti/features/sync/queue/inbound_queue_settlement.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/services/domain_logging.dart';

export 'package:lotti/features/sync/queue/inbound_queue_settlement.dart'
    show ApplyOutcome, InboundEntryOutcome, undecodableReason;

/// Apply callback contract. Phase-2 wiring plugs in
/// `SyncEventProcessor.prepare` + `apply`; Phase-1 tests pass a mock. The
/// entry carries everything apply reads; no live Room is involved (ADR
/// 0142, step 3).
typedef InboundApplyFn = Future<ApplyOutcome> Function(InboundQueueEntry entry);

/// Optional batch-prepare hook. Called once per batch in
/// [InboundWorker._runBatch] before the per-entry apply loop so the
/// adapter can fan out the I/O-bound prepare phase via `Future.wait`
/// and cache the prepared payloads by `eventId`. Apply itself is still
/// invoked entry-by-entry via [InboundApplyFn] to preserve the
/// journalDb writer-lock discipline.
///
/// Contractual guarantees:
/// - Must not throw. Per-entry failures must be recorded so the
///   subsequent apply call for the same entry returns the correct
///   terminal [ApplyOutcome].
/// - Wiring is optional. A worker built without this hook prepares
///   each entry inline inside [InboundApplyFn].
typedef InboundPrepareBatchFn =
    Future<void> Function(List<InboundQueueEntry> entries);

const _logSub = 'queue.worker';

/// Drains the inbound queue under the single-worker contract from
/// the queue design. Each drain cycle:
///
/// 1. Optionally waits on [UserActivityGate] so inbound apply does not
///    fight the user's writes (M1).
/// 2. Leases up to [SyncTuning.inboundWorkerBatchSize] ready entries
///    through its [InboundQueueGateway] and wraps the batch in
///    `sequenceLogService.runWithDeferredMissingEntries` so the N gap
///    detections inside the slice coalesce into at most one
///    `_emitMissingEntriesDetected` callback — the F1 concern from the
///    design review.
/// 3. Applies each entry in order and acknowledges the batch's outcomes
///    through the gateway, whose owner commits, retries or abandons each
///    entry ([InboundQueueSettlement]).
///
/// The gateway is the queue's owner: the UI isolate's own [InboundQueue] by
/// default, or the sync isolate when `use_isolate_sync` is on (ADR 0142).
/// The retry parameters shape the default, in-process owner's settlement
/// and are ignored when a gateway is given.
class InboundWorker {
  InboundWorker({
    required InboundQueue queue,
    required this._sequenceLogService,
    required this._apply,
    required this._logging,
    InboundQueueGateway? gateway,
    this._prepareBatch,
    this._activityGate,
    this._idleTick = const Duration(seconds: 5),
    Duration initialBackoff = const Duration(milliseconds: 500),
    Duration maxBackoff = const Duration(seconds: 30),
    int maxAttempts = 10,
    SyncCostMeter? costMeter,
  }) : _costMeter = costMeter ?? SyncCostMeter.inert(),
       _gateway =
           gateway ??
           LocalInboundQueueGateway(
             queue: queue,
             settlement: InboundQueueSettlement(
               queue: queue,
               initialBackoff: initialBackoff,
               maxBackoff: maxBackoff,
               maxAttempts: maxAttempts,
             ),
           );

  final InboundQueueGateway _gateway;
  final SyncCostMeter _costMeter;
  final SyncSequenceLogService _sequenceLogService;
  final InboundApplyFn _apply;
  final InboundPrepareBatchFn? _prepareBatch;
  final DomainLogger _logging;
  final UserActivityGate? _activityGate;
  final Duration _idleTick;

  Completer<void>? _stopRequested;
  Completer<void>? _loopCompleted;
  bool _running = false;

  /// Starts the drain loop in the background. Idempotent: a call while already
  /// running is a no-op. The returned future completes once the loop is
  /// scheduled, not when draining finishes.
  Future<void> start() async {
    if (_running) return;
    _running = true;
    _stopRequested = Completer<void>();
    _loopCompleted = Completer<void>();
    unawaited(_loop());
  }

  /// Signals the drain loop to stop and awaits its graceful exit, so callers
  /// can be sure no further apply work runs after this resolves.
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    _stopRequested?.complete();
    await _loopCompleted?.future;
  }

  /// Drains every entry that is ready at call time, then returns.
  ///
  /// Does not subscribe to the gateway's changes and does not
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
      final batch = await _gateway.lease(
        maxBatch: SyncTuning.inboundWorkerBatchSize,
      );
      if (batch.isEmpty) return applied;
      applied += await _runBatch(batch);
    }
  }

  /// Drains until [stop]. A throw from one iteration — a lease, or the
  /// batch's acknowledgement, both of which leave the rows leased until
  /// their lease expires — is logged and the loop carries on after
  /// [_idleTick]. Ending the loop instead would leave every queued row
  /// stranded until the coordinator restarts, since nothing else calls
  /// [start] while the coordinator is running
  /// (`QueuedEventuallySettled` in `specs/tla/InboundQueue.tla`).
  Future<void> _loop() async {
    try {
      while (_running) {
        try {
          await _iterate();
        } catch (error, stackTrace) {
          _logging.error(
            LogDomain.sync,
            error,
            stackTrace: stackTrace,
            subDomain: '$_logSub.loop',
          );
          await _pauseAfterError();
        }
      }
    } finally {
      _running = false;
      _loopCompleted?.complete();
    }
  }

  Future<void> _iterate() async {
    await _waitUntilIdleOrStopped();
    if (!_running) return;

    // Subscribe to the gateway's changes BEFORE leasing so an enqueue
    // that lands during the lease cannot be missed: if the subscription
    // were attached after an empty lease, the signal for an enqueue in
    // that gap would land on a dead stream.
    final changeTrigger = Completer<void>();
    final changeSub = _gateway.changes.listen((_) {
      if (!changeTrigger.isCompleted) changeTrigger.complete();
    });

    final List<InboundQueueEntry> batch;
    try {
      batch = await _gateway.lease(
        maxBatch: SyncTuning.inboundWorkerBatchSize,
      );
      if (batch.isEmpty) {
        await _waitForWork(changeTrigger.future);
        return;
      }
    } finally {
      await changeSub.cancel();
    }
    await _runBatch(batch);
  }

  /// Waits [_idleTick] or until [stop], so a persistent failure does not
  /// spin the loop.
  Future<void> _pauseAfterError() async {
    final stopFuture = _stopRequested?.future ?? Future<void>.value();
    await Future.any<void>([stopFuture, Future<void>.delayed(_idleTick)]);
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
    var appliedCount = 0;
    await _sequenceLogService.runWithDeferredMissingEntries(() async {
      // Phase 0 (optional): batch-parallel prepare. Prepare is
      // embarrassingly parallel — no shared state, entirely I/O-bound
      // (attachment downloads, gzip decode, JSON decode) — so fanning
      // it out via `Future.wait` collapses the batch-prepare latency
      // down to the slowest entry's critical path. Apply continues
      // sequentially so the journalDb writer lock still serialises
      // the actual DB writes.
      final batchPrepare = _prepareBatch;
      if (batchPrepare != null) {
        try {
          await batchPrepare(batch);
        } catch (error, stackTrace) {
          // A broken prepareBatch must not skip the apply phase — the
          // adapter already classifies prepare failures per entry, so
          // a throw here is an adapter bug. Log and continue: the
          // per-entry `_apply` call falls back to inline prepare.
          _logging.error(
            LogDomain.sync,
            error,
            stackTrace: stackTrace,
            subDomain: '$_logSub.prepareBatch',
          );
        }
      }

      // Phase 1: apply each entry outside any sync_db transaction —
      // apply may write to journal_db and we do not want sync_db
      // locked while journal_db does I/O. Accumulate outcomes so the
      // owner can record them in one go.
      final outcomes = <InboundEntryOutcome>[];
      for (final entry in batch) {
        final outcome = await _applyOne(entry);
        outcomes.add(InboundEntryOutcome(entry, outcome));
      }

      // Phase 2: acknowledge the batch. The owner coalesces every
      // queue-side write into a single sync_db transaction, so a slice
      // of 20 entries performs one commit instead of up to 20.
      appliedCount = await _gateway.settle(outcomes);
    });
    return appliedCount;
  }

  Future<ApplyOutcome> _applyOne(InboundQueueEntry entry) async {
    try {
      return await _costMeter.measure(
        SyncCostSection.apply,
        () => _apply(entry),
      );
    } catch (error, stackTrace) {
      _logging.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: '$_logSub.apply',
      );
      return ApplyOutcome.retriable;
    }
  }

  /// Races stop, a change signal, and a delay that matches the
  /// queue's earliest ready timestamp. Without the ready-aware delay,
  /// a queue that only contains rows with a future `nextDueAt` (every
  /// retry path — retriable, missingBase, decryptionPending)
  /// would round its intended 250 ms / 500 ms / 2 s backoff up to
  /// `_idleTick` (5 s by default), delaying recovery and starving the
  /// bootstrap back-pressure contract.
  ///
  /// When the queue is fully drained ([InboundQueueGateway.earliestReadyAt]
  /// returns null) the loop relies on the change signal to wake
  /// it on the next enqueue. A multiplied tick (`_idleTick × 12`) is
  /// kept purely as a safety net for missed signals, so an empty queue
  /// no longer wakes every five seconds — that polled wake-up was the
  /// dominant inbound_event_queue read in production traces (8 k+ idle
  /// peeks per day, ~1 k seconds of cumulative DB time).
  Future<void> _waitForWork(Future<void> changeFuture) async {
    final stopFuture = _stopRequested?.future ?? Future<void>.value();
    final readyAt = await _gateway.earliestReadyAt();
    final nowMs = clock.now().millisecondsSinceEpoch;
    final Duration delay;
    if (readyAt == null) {
      delay = _idleTick * 12;
    } else {
      final deltaMs = readyAt - nowMs;
      delay = deltaMs <= 0
          ? const Duration(milliseconds: 1)
          : Duration(milliseconds: deltaMs);
    }
    final tickFuture = Future<void>.delayed(delay);
    await Future.any<void>([stopFuture, changeFuture, tickFuture]);
  }
}
