import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_event_classifier.dart';
import 'package:lotti/features/sync/state/sync_activity_signaler.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';

export 'package:lotti/database/sync_db.dart' show InboundEventProducer;

part 'inbound_queue_resurrection.dart';
part 'inbound_queue_models.dart';
part 'inbound_queue_internals.dart';

/// Durable inbound queue for Matrix sync events. See §3 of
/// `docs/sync/2026-04-21_inbound_event_queue_implementation_plan.md`.
class InboundQueue {
  InboundQueue({
    required this._db,
    required this._logging,
    Duration? leaseDuration,
    this._activitySignaler,
  }) : _leaseDuration = leaseDuration ?? SyncTuning.inboundWorkerLeaseDuration;

  final SyncDatabase _db;
  final DomainLogger _logging;
  final SyncActivitySignaler? _activitySignaler;
  final Duration _leaseDuration;

  final StreamController<QueueDepthSignal> _depthCtl =
      StreamController<QueueDepthSignal>.broadcast();

  Stream<QueueDepthSignal> get depthChanges => _depthCtl.stream;

  Future<void> dispose() async {
    await _depthCtl.close();
  }

  /// Runs [body] inside a single `sync_db` transaction so a batch of
  /// `commitApplied` / `scheduleRetry` / `markSkipped` calls coalesce
  /// into one write transaction instead of one per entry. Drift nests
  /// internal per-method transactions as savepoints when the outermost
  /// caller has already opened a transaction — the coalescing happens
  /// transparently.
  ///
  /// While the body runs, intermediate `_emitDepth` calls are held
  /// back: firing them unawaited inside the transaction zone captures
  /// the transaction's executor, which is invalid after commit and
  /// trips drift's "transaction used after being closed" guard. A
  /// single post-commit emission fires if anything inside the body
  /// would have emitted.
  Future<T> runInTransaction<T>(Future<T> Function() body) async {
    // Only the OUTERMOST caller owns the dirty flag. A nested
    // runInTransaction (enqueueBatch from inside an outer batch, for
    // example) must not clear a dirty bit the outer batch already set,
    // or the outer finalizer would skip its post-commit emission.
    final isOutermost = _inBatchMode == 0;
    _inBatchMode++;
    if (isOutermost) {
      _batchDirty = false;
    }
    try {
      return await _db.transaction(body);
    } finally {
      _inBatchMode--;
      if (isOutermost && _batchDirty) {
        _batchDirty = false;
        // Fire outside the transaction zone so `stats()` uses the
        // root executor, not the now-closed transaction executor.
        unawaited(_emitDepth());
      }
    }
  }

  int _inBatchMode = 0;
  bool _batchDirty = false;

  // ---------------------------------------------------------------- enqueue

  Future<EnqueueResult> enqueueLive(Event event) =>
      enqueueBatch([event], producer: InboundEventProducer.live);

  Future<EnqueueResult> enqueueBatch(
    List<Event> events, {
    required InboundEventProducer producer,
  }) async {
    if (events.isEmpty) return EnqueueResult.empty;

    var accepted = 0;
    var duplicates = 0;
    var filteredOut = 0;
    var deferred = 0;
    var oldest = 0;
    var newest = 0;
    final nowMs = clock.now().millisecondsSinceEpoch;

    final toInsert = <({InboundEventQueueCompanion row, int ts})>[];
    for (final event in events) {
      // F3 must run before F4. A real `m.room.encrypted` event has
      // ciphertext-only content with no visible `msgtype`, so the
      // classifier would report it as a non-payload event and drop it
      // as `filteredOutByType` before it ever reaches the pen.
      // Deferring encrypted events first keeps them in the pen and
      // lets decryption turn them into a proper payload later.
      if (event.type == EventTypes.Encrypted) {
        deferred++;
        continue;
      }
      // F4: drop non-payload events at the boundary.
      if (!MatrixEventClassifier.isSyncPayloadEvent(event)) {
        filteredOut++;
        continue;
      }

      final ts = event.originServerTs.millisecondsSinceEpoch;
      toInsert.add((
        row: InboundEventQueueCompanion.insert(
          eventId: event.eventId,
          roomId: event.roomId ?? '',
          originTs: ts,
          producer: producer.name,
          rawJson: jsonEncode(event.toJson()),
          enqueuedAt: nowMs,
          // Enqueue in the drainable state; `peekBatchReady` will
          // flip it to `leased` atomically.
          status: const Value(_statusEnqueued),
          // Populate `json_path` from the Lotti sync payload when
          // present so `AttachmentIndex.pathRecorded` can match the
          // abandoned row later and resurrect it.
          jsonPath: Value(_extractJsonPath(event)),
        ),
        ts: ts,
      ));
    }

    if (toInsert.isNotEmpty) {
      await _db.transaction(() async {
        for (final candidate in toInsert) {
          final inserted = await _db
              .into(_db.inboundEventQueue)
              .insertReturningOrNull(
                candidate.row,
                mode: InsertMode.insertOrIgnore,
              );
          if (inserted == null) {
            duplicates++;
          } else {
            accepted++;
            // Only count bounds for events we actually inserted; duplicate
            // rows must not inflate the accepted window.
            if (oldest == 0 || candidate.ts < oldest) oldest = candidate.ts;
            if (candidate.ts > newest) newest = candidate.ts;
          }
        }
      });
    }

    _logging.log(
      LogDomain.sync,
      'queue.enqueue producer=${producer.name} '
      'accepted=$accepted dupes=$duplicates '
      'filteredOutByType=$filteredOut '
      'deferredPendingDecryption=$deferred',
      subDomain: _logSubEnqueue,
    );

    if (accepted > 0) {
      _scheduleDepthEmit();
    }

    return EnqueueResult(
      accepted: accepted,
      duplicatesDropped: duplicates,
      filteredOutByType: filteredOut,
      deferredPendingDecryption: deferred,
      oldestTsAccepted: oldest,
      newestTsAccepted: newest,
    );
  }

  /// Bootstrap producers write one page at a time through this entry
  /// point so the caller's back-pressure loop can await
  /// [waitForDrainAtMostTo] between pages.
  Future<EnqueueResult> appendBootstrapPage(List<Event> events) =>
      enqueueBatch(events, producer: InboundEventProducer.bootstrap);

  /// Completes when the queue depth drops to [depth] or below. Checked
  /// against the live [depthChanges] stream; completes immediately if
  /// the current depth already satisfies the condition.
  Future<void> waitForDrainAtMostTo(int depth, {Duration? timeout}) async {
    // Subscribe before counting so a depth signal that lands between the
    // initial count and the listener attachment cannot be missed.
    final completer = Completer<void>();
    final sub = depthChanges.listen((signal) {
      if (signal.total <= depth && !completer.isCompleted) {
        completer.complete();
      }
    });
    try {
      final current = await _countTotal();
      if (current <= depth) return;
      if (timeout != null) {
        await completer.future.timeout(timeout);
      } else {
        await completer.future;
      }
    } finally {
      await sub.cancel();
    }
  }

  // ------------------------------------------------------------------ peek

  /// Returns up to [maxBatch] entries ready now (origin_ts ascending,
  /// queue_id ascending on tie), stamping a durable lease so concurrent
  /// drainers cannot double-apply. Only `enqueued` / `retrying` rows
  /// are eligible — `applied` and `abandoned` rows stay put as the
  /// ledger history and the resurrection target, respectively.
  ///
  /// The default is [SyncTuning.peekBatchReadyDefault] (a generic upper
  /// bound for ad-hoc peek calls and tests). The InboundWorker passes
  /// its own `SyncTuning.inboundWorkerBatchSize` explicitly so the
  /// generic peek limit and the worker-specific drain policy can move
  /// independently.
  Future<List<InboundQueueEntry>> peekBatchReady({
    int maxBatch = SyncTuning.peekBatchReadyDefault,
  }) async {
    final nowMs = clock.now().millisecondsSinceEpoch;

    // Probe outside any transaction first. The idle worker fires this
    // every wake-up and the common case (queue fully drained) returns
    // empty — opening a sync_db transaction just to discover that
    // burns a BEGIN/COMMIT round trip per tick. Wrapping the SELECT in
    // a transaction was load-bearing only for the SELECT-then-UPDATE
    // atomicity below; with a single drainer (the worker), nothing
    // races against a no-op probe.
    //
    // Phrased as an `EXISTS`-style lookup (one column, `LIMIT 1`, no
    // ORDER BY): the partial index `idx_inbound_event_queue_ready` is
    // keyed on `(next_due_at, origin_ts, queue_id)`, so this becomes a
    // tight index seek that touches at most one entry. Selecting full
    // rows here would double the read cost on the active path because
    // the transaction below re-reads the same `maxBatch` rows.
    final probeTable = _db.inboundEventQueue;
    final probe = _db.selectOnly(probeTable)
      ..addColumns([probeTable.queueId])
      ..where(
        probeTable.status.isIn(_peekStatuses) &
            probeTable.nextDueAt.isSmallerOrEqualValue(nowMs) &
            probeTable.leaseUntil.isSmallerOrEqualValue(nowMs),
      )
      ..limit(1);
    final probeRow = await probe.getSingleOrNull();
    if (probeRow == null) return const <InboundQueueEntry>[];

    final leaseUntilMs = nowMs + _leaseDuration.inMilliseconds;
    return _db.transaction(() async {
      final query = _db.select(_db.inboundEventQueue)
        ..where(
          (t) =>
              t.status.isIn(_peekStatuses) &
              t.nextDueAt.isSmallerOrEqualValue(nowMs) &
              t.leaseUntil.isSmallerOrEqualValue(nowMs),
        )
        ..orderBy([
          (t) => OrderingTerm.asc(t.originTs),
          (t) => OrderingTerm.asc(t.queueId),
        ])
        ..limit(maxBatch);
      final rows = await query.get();
      if (rows.isEmpty) return const <InboundQueueEntry>[];
      final ids = rows.map((r) => r.queueId).toList();
      // Flip status to `leased` in the same transaction so a
      // concurrent peeker (should one exist) cannot double-claim the
      // rows; the lease timestamp is the crash-recovery fence.
      await (_db.update(
        _db.inboundEventQueue,
      )..where((t) => t.queueId.isIn(ids))).write(
        InboundEventQueueCompanion(
          leaseUntil: Value(leaseUntilMs),
          status: const Value(_statusLeased),
        ),
      );
      return [for (final r in rows) _entryFromRow(r, leaseUntilMs)];
    });
  }

  // ---------------------------------------------------------------- commit

  /// Flips [entry] to `status='applied'` (keeping the row as an
  /// append-only ledger entry) and — in the same transaction —
  /// advances `queue_markers` for the room if the candidate
  /// "completeBelow" timestamp beats the stored value. The row is
  /// retained for traceability; retention is owned by a follow-up
  /// pruner, not by the hot path.
  ///
  /// Clamping (the real correctness fix): the marker advancement
  /// considers the candidate `entry.originTs` but also the minimum
  /// `origin_ts` across *other* still-active rows for the same room.
  /// If an older row is still `enqueued`/`leased`/`retrying`, the
  /// marker stops just below it, so backfill never crosses a gap we
  /// have not actually applied — the hole closes automatically once
  /// every older active row commits or is abandoned.
  Future<void> commitApplied(InboundQueueEntry entry) async {
    var markerAdvanced = false;
    final nowMs = clock.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await (_db.update(
        _db.inboundEventQueue,
      )..where((t) => t.queueId.equals(entry.queueId))).write(
        InboundEventQueueCompanion(
          status: const Value(_statusApplied),
          committedAt: Value(nowMs),
          // Drop the lease so the row no longer counts against any
          // concurrent peeker; status already excludes it from peeks.
          leaseUntil: const Value(0),
        ),
      );
      markerAdvanced = await _advanceMarkerIfNewer(entry);
    });

    _logging.log(
      LogDomain.sync,
      'queue.commit pipeline=queue '
      'eventId=${entry.eventId} '
      'originTs=${entry.originTs} '
      'markerAdvanced=$markerAdvanced',
      subDomain: _logSubCommit,
    );
    _activitySignaler?.pulseRx();
    _scheduleDepthEmit();
  }

  // ----------------------------------------------------------------- retry

  Future<void> scheduleRetry(
    InboundQueueEntry entry,
    Duration backoff, {
    required RetryReason reason,
  }) async {
    final nowMs = clock.now().millisecondsSinceEpoch;
    final nextDueAt = nowMs + backoff.inMilliseconds;
    await (_db.update(
      _db.inboundEventQueue,
    )..where((t) => t.queueId.equals(entry.queueId))).write(
      InboundEventQueueCompanion(
        attempts: Value(entry.attempts + 1),
        nextDueAt: Value(nextDueAt),
        // Drop the lease so another drain iteration can pick up the
        // entry once the backoff elapses.
        leaseUntil: const Value(0),
        status: const Value(_statusRetrying),
        lastErrorReason: Value(reason.name),
      ),
    );
    _logging.log(
      LogDomain.sync,
      'queue.retry eventId=${entry.eventId} '
      'reason=${reason.name} '
      'attempts=${entry.attempts + 1} '
      'nextDueAtMs=$nextDueAt',
      subDomain: _logSubRetry,
    );
    // The retrying count is part of `QueueStats` and is observed by
    // diagnostics + tests; without an emit here, a leased→retrying
    // transition is invisible to depth subscribers until the next
    // unrelated mutation. `_scheduleDepthEmit` is batch-aware, so a
    // retry inside `runInTransaction` defers to the post-commit
    // emission instead of firing mid-transaction.
    _scheduleDepthEmit();
  }

  /// Flips [entry] to `status='abandoned'` when the worker gives up
  /// after exhausting retries. The row is kept as a durable record so
  /// resurrection triggers (attachment signal, journal update,
  /// user-initiated retry) can flip it back to `enqueued`. The marker
  /// advancement clamp ignores abandoned rows, so a single poison
  /// row cannot stall forward progress for every newer event.
  Future<void> markSkipped(
    InboundQueueEntry entry, {
    String? reason,
  }) async {
    var markerAdvanced = false;
    final nowMs = clock.now().millisecondsSinceEpoch;
    final resolvedReason = reason ?? 'unspecified';
    await _db.transaction(() async {
      await (_db.update(
        _db.inboundEventQueue,
      )..where((t) => t.queueId.equals(entry.queueId))).write(
        InboundEventQueueCompanion(
          status: const Value(_statusAbandoned),
          abandonedAt: Value(nowMs),
          lastErrorReason: Value(resolvedReason),
          leaseUntil: const Value(0),
        ),
      );
      markerAdvanced = await _advanceMarkerIfNewer(entry);
    });
    _logging.log(
      LogDomain.sync,
      'queue.skip eventId=${entry.eventId} reason=$resolvedReason '
      'markerAdvanced=$markerAdvanced',
      subDomain: _logSubSkip,
    );
    _scheduleDepthEmit();
  }

  // ----------------------------------------------------------- resurrect

  /// See [InboundQueueResurrection].
  Future<int> resurrectByPath(String path, {int hardCap = 50}) =>
      resurrectByPathImpl(path, hardCap: hardCap);

  /// See [InboundQueueResurrection].
  Future<int> resurrectByPaths(Iterable<String> paths, {int hardCap = 50}) =>
      resurrectByPathsImpl(paths, hardCap: hardCap);

  /// See [InboundQueueResurrection].
  Future<int> resurrectAll({int hardCap = 50}) =>
      resurrectAllImpl(hardCap: hardCap);

  /// See [InboundQueueResurrection].
  Future<int> resurrectByReason(String reasonName, {int hardCap = 50}) =>
      resurrectByReasonImpl(reasonName, hardCap: hardCap);

  /// Flips every *active* entry belonging to a room other than
  /// [currentRoomId] to `abandoned`, preserving the ledger but
  /// making sure the worker does not drain stale-room rows through
  /// the current session's `resolveRoom()` path. Applied rows stay
  /// untouched so historical-room traces remain readable; abandoned
  /// rows from other rooms stay in place too. Returns the number of
  /// rows transitioned to `abandoned`.
  Future<int> pruneStrandedEntries(String currentRoomId) async {
    final nowMs = clock.now().millisecondsSinceEpoch;
    final moved = await _db.transaction(() async {
      return _db.customUpdate(
        'UPDATE inbound_event_queue '
        'SET status = ?, '
        '    abandoned_at = ?, '
        '    last_error_reason = ?, '
        '    lease_until = 0 '
        'WHERE room_id != ? '
        "  AND status IN ('enqueued', 'leased', 'retrying')",
        variables: [
          Variable.withString(_statusAbandoned),
          Variable.withInt(nowMs),
          Variable.withString('strandedRoom'),
          Variable.withString(currentRoomId),
        ],
        updates: {_db.inboundEventQueue},
      );
    });
    if (moved > 0) {
      _logging.log(
        LogDomain.sync,
        'queue.prune currentRoom=$currentRoomId abandoned=$moved',
        subDomain: _logSubPrune,
      );
      _scheduleDepthEmit();
    }
    return moved;
  }

  // ---------------------------------------------------------------- stats

  /// Aggregate snapshot of queue state. `total` is the *active*
  /// depth (drainable rows); `applied` / `abandoned` / `retrying`
  /// carry the ledger breakdown for UI + diagnostics.
  ///
  /// Implementation note: a single `GROUP BY status, producer`
  /// aggregate replaces the prior four selectOnly aggregates. The
  /// previous shape did three full-table scans plus a TEMP B-TREE on
  /// every poll because no index covered `(status, producer)` —
  /// production slow-query log captured 1014 ms / 2244 ms hits at
  /// `_emitDepth` cadence. The v20 partial index
  /// `idx_inbound_event_queue_status_producer_enqueued` makes the
  /// pivot index-only over a tight key range, and Dart pivots the
  /// (≤ statuses × producers) result rows into the existing
  /// `QueueStats` shape.
  Future<QueueStats> stats() async {
    final nowMs = clock.now().millisecondsSinceEpoch;
    final table = _db.inboundEventQueue;
    final countCol = table.queueId.count();
    final oldestCol = table.enqueuedAt.min();

    // One aggregate scan: per (status, producer), get COUNT and
    // MIN(enqueued_at). Pivots into total/byProducer/oldest plus
    // applied/abandoned/retrying counts on the Dart side.
    final pivotRows =
        await (_db.selectOnly(table)
              ..addColumns([
                table.status,
                table.producer,
                countCol,
                oldestCol,
              ])
              ..groupBy([table.status, table.producer]))
            .get();

    var total = 0;
    var applied = 0;
    var abandoned = 0;
    var retrying = 0;
    int? oldest;
    final byProducer = <InboundEventProducer, int>{};

    for (final row in pivotRows) {
      final status = row.read(table.status);
      final producerName = row.read(table.producer);
      final cnt = row.read(countCol) ?? 0;
      if (cnt <= 0 || status == null || producerName == null) continue;
      final rowOldest = row.read(oldestCol);

      if (_activeStatuses.contains(status)) {
        total += cnt;
        final p = _producerFromName(producerName);
        byProducer[p] = (byProducer[p] ?? 0) + cnt;
        if (rowOldest != null && (oldest == null || rowOldest < oldest)) {
          oldest = rowOldest;
        }
      }
      switch (status) {
        case _statusApplied:
          applied += cnt;
        case _statusAbandoned:
          abandoned += cnt;
        case _statusRetrying:
          retrying += cnt;
      }
    }

    // Ready-now keeps its own probe: the predicate is
    // `status IN _peekStatuses AND next_due_at <= now AND
    // lease_until <= now`, which the (status, next_due_at,
    // lease_until) index satisfies as a per-status range scan and
    // does not align with the (status, producer, enqueued_at)
    // pivot's grouping.
    final readyRow =
        await (_db.selectOnly(table)
              ..addColumns([countCol])
              ..where(
                table.status.isIn(_peekStatuses) &
                    table.nextDueAt.isSmallerOrEqualValue(nowMs) &
                    table.leaseUntil.isSmallerOrEqualValue(nowMs),
              ))
            .getSingle();
    final readyNow = readyRow.read(countCol) ?? 0;

    return QueueStats(
      total: total,
      byProducer: byProducer,
      readyNow: readyNow,
      oldestEnqueuedAt: oldest,
      applied: applied,
      abandoned: abandoned,
      retrying: retrying,
    );
  }

  /// Returns the earliest wall-clock instant (ms since epoch) at which
  /// any queued row will become ready for `peekBatchReady`, or `null`
  /// when the queue is empty. "Ready" requires both `nextDueAt <= now`
  /// and `leaseUntil <= now`, so this returns the minimum across rows
  /// of `max(nextDueAt, leaseUntil)`. The worker uses this to compute
  /// an exact sleep duration instead of rounding every retry up to its
  /// `idleTick`.
  Future<int?> earliestReadyAt() async {
    final row = await _db
        .customSelect(
          'SELECT MIN(CASE WHEN next_due_at > lease_until '
          'THEN next_due_at ELSE lease_until END) AS ready_at '
          'FROM inbound_event_queue '
          "WHERE status IN ('enqueued', 'retrying', 'leased')",
        )
        .getSingleOrNull();
    if (row == null) return null;
    final value = row.data['ready_at'];
    return value is int ? value : null;
  }

  bool _emitInFlight = false;
  bool _emitPendingRerun = false;
}
