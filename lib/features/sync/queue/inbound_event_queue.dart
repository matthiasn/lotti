import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_event_classifier.dart';
import 'package:lotti/features/sync/state/sync_activity_signaler.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

export 'package:lotti/database/sync_db.dart' show InboundEventProducer;

/// Public result of a queue-side enqueue call. `accepted + dupes +
/// filteredOutByType + deferredPendingDecryption` always equals the
/// number of events passed in.
class EnqueueResult {
  const EnqueueResult({
    required this.accepted,
    required this.duplicatesDropped,
    required this.filteredOutByType,
    required this.deferredPendingDecryption,
    required this.oldestTsAccepted,
    required this.newestTsAccepted,
  });

  final int accepted;
  final int duplicatesDropped;

  /// Rejected because [MatrixEventClassifier.isSyncPayloadEvent] was
  /// false — state events, redactions, etc. (F4).
  final int filteredOutByType;

  /// Rejected because the Matrix event was still encrypted at enqueue
  /// time. The caller (usually `PendingDecryptionPen`) is expected to
  /// retain the event and re-submit once decryption completes (F3).
  final int deferredPendingDecryption;

  final int oldestTsAccepted;
  final int newestTsAccepted;

  static const empty = EnqueueResult(
    accepted: 0,
    duplicatesDropped: 0,
    filteredOutByType: 0,
    deferredPendingDecryption: 0,
    oldestTsAccepted: 0,
    newestTsAccepted: 0,
  );
}

/// Retry classification the worker hands back to the queue.
enum RetryReason {
  missingBase,
  retriable,
  decryptionPending,

  /// Waiting for an attachment JSON (descriptor or agent entity
  /// payload) to land on disk. Retried with a longer backoff ladder
  /// and a wall-clock timeout instead of the generic attempt cap —
  /// see `ApplyOutcome.pendingAttachment`.
  pendingAttachment,
}

/// A queue row materialised for the worker. [rawJson] is the bytes the
/// worker passes to `Event.fromJson(room, ...)` at apply time; the
/// queue itself does not keep SDK objects alive.
class InboundQueueEntry {
  const InboundQueueEntry({
    required this.queueId,
    required this.eventId,
    required this.roomId,
    required this.originTs,
    required this.producer,
    required this.enqueuedAt,
    required this.attempts,
    required this.leaseUntil,
    required this.rawJson,
  });

  final int queueId;
  final String eventId;
  final String roomId;
  final int originTs;
  final InboundEventProducer producer;
  final int enqueuedAt;
  final int attempts;
  final int leaseUntil;
  final String rawJson;

  /// Materialises the stored event against the given [room]. The room
  /// must belong to the same client the event was enqueued from.
  Event toEvent(Room room) {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    return Event.fromJson(decoded, room);
  }
}

class QueueDepthSignal {
  const QueueDepthSignal({
    required this.total,
    required this.byProducer,
    required this.oldestEnqueuedAt,
    this.abandoned = 0,
  });

  /// Active depth — `enqueued` + `leased` + `retrying`. Never
  /// includes `applied` or `abandoned` rows so "queue is empty"
  /// still means "nothing to drain."
  final int total;
  final Map<InboundEventProducer, int> byProducer;
  final int? oldestEnqueuedAt;

  /// Count of abandoned ledger rows — sync events the worker gave
  /// up on after exhausting retries. Feeds the Sync Settings badge
  /// + "Retry skipped" action.
  final int abandoned;
}

class QueueStats {
  const QueueStats({
    required this.total,
    required this.byProducer,
    required this.readyNow,
    required this.oldestEnqueuedAt,
    this.applied = 0,
    this.abandoned = 0,
    this.retrying = 0,
  });

  /// Active-queue depth — rows the worker can still drain (`enqueued`
  /// + `leased` + `retrying`). Excludes `applied` and `abandoned` so
  /// callers that throttle against depth (bootstrap back-pressure,
  /// UI) do not inflate their numbers with the ledger history.
  final int total;
  final Map<InboundEventProducer, int> byProducer;
  final int readyNow;
  final int? oldestEnqueuedAt;

  /// Count of `status='applied'` rows — the ledger of everything the
  /// queue has successfully committed. Diagnostic / UI only.
  final int applied;

  /// Count of `status='abandoned'` rows — events the worker gave up
  /// on. Resurrection via `AttachmentIndex.pathRecorded` or
  /// `JournalDb.updateStream` (or a user-triggered retry) flips them
  /// back to `enqueued`.
  final int abandoned;

  /// Count of `status='retrying'` rows with a future `next_due_at`.
  final int retrying;
}

const _logDomain = 'sync';
const _logSubEnqueue = 'queue.enqueue';
const _logSubCommit = 'queue.commit';
const _logSubRetry = 'queue.retry';
const _logSubSkip = 'queue.skip';
const _logSubPrune = 'queue.prune';
const _logSubResurrect = 'queue.resurrect';

// Status constants mirroring the `status` column values on
// `inbound_event_queue`. Lifecycle diagram:
//
//     enqueued ─► leased ─┬─► applied  (commitApplied)
//         ▲               ├─► retrying ─► leased ...
//         │               └─► abandoned (markSkipped after max attempts)
//         │
//         └── resurrectByPath / resurrectAll (from abandoned)
const _statusEnqueued = 'enqueued';
const _statusLeased = 'leased';
const _statusRetrying = 'retrying';
const _statusApplied = 'applied';
const _statusAbandoned = 'abandoned';

// Statuses the worker can still drain. Peek + clamp queries filter
// on this set so the applied ledger (bounded only by retention, not
// by correctness) never touches the hot paths.
const List<String> _activeStatuses = <String>[
  _statusEnqueued,
  _statusLeased,
  _statusRetrying,
];

// Peek eligibility. Includes `leased` so crash recovery works: a
// worker that died mid-apply left its rows in `leased` state with a
// non-zero `lease_until`. Once that timestamp elapses the row is
// peekable again (the `lease_until <= now` predicate in
// `peekBatchReady` still gates it). Under normal operation the
// worker transitions `leased` → `applied`/`retrying`/`abandoned`
// via its outcome switch, so this set is effectively `enqueued` +
// `retrying` most of the time.
const List<String> _peekStatuses = <String>[
  _statusEnqueued,
  _statusRetrying,
  _statusLeased,
];

/// Durable inbound queue for Matrix sync events. See §3 of
/// `docs/sync/2026-04-21_inbound_event_queue_implementation_plan.md`.
class InboundQueue {
  InboundQueue({
    required SyncDatabase db,
    required LoggingService logging,
    Duration? leaseDuration,
    SyncActivitySignaler? activitySignaler,
  }) : _db = db,
       _logging = logging,
       _activitySignaler = activitySignaler,
       _leaseDuration = leaseDuration ?? SyncTuning.inboundWorkerLeaseDuration;

  final SyncDatabase _db;
  final LoggingService _logging;
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

  void _scheduleDepthEmit() {
    if (_depthCtl.isClosed) return;
    if (_inBatchMode > 0) {
      _batchDirty = true;
      return;
    }
    unawaited(_emitDepth());
  }

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

    _logging.captureEvent(
      'queue.enqueue producer=${producer.name} '
      'accepted=$accepted dupes=$duplicates '
      'filteredOutByType=$filteredOut '
      'deferredPendingDecryption=$deferred',
      domain: _logDomain,
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

  InboundQueueEntry _entryFromRow(
    InboundEventQueueItem row,
    int leaseUntil,
  ) => InboundQueueEntry(
    queueId: row.queueId,
    eventId: row.eventId,
    roomId: row.roomId,
    originTs: row.originTs,
    producer: _producerFromName(row.producer),
    enqueuedAt: row.enqueuedAt,
    attempts: row.attempts,
    leaseUntil: leaseUntil,
    rawJson: row.rawJson,
  );

  InboundEventProducer _producerFromName(String name) {
    for (final p in InboundEventProducer.values) {
      if (p.name == name) return p;
    }
    return InboundEventProducer.live;
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

    _logging.captureEvent(
      'queue.commit pipeline=queue '
      'eventId=${entry.eventId} '
      'originTs=${entry.originTs} '
      'markerAdvanced=$markerAdvanced',
      domain: _logDomain,
      subDomain: _logSubCommit,
    );
    _activitySignaler?.pulseRx();
    _scheduleDepthEmit();
  }

  /// Advances `queue_markers` for [entry]'s room if the candidate
  /// timestamp — clamped against any still-active queue rows for the
  /// same room — strictly moves the marker forward. Bypasses
  /// `TimelineEventOrdering.isNewer` because `isNewer` treats a null
  /// stored event id as "no marker" — but the marker can legitimately
  /// carry a non-zero timestamp with a null event id (right after a
  /// placeholder advance). Guarding on the timestamp directly, with
  /// the durable event id as a tiebreaker only when both sides are
  /// durable, prevents a later durable event with an older timestamp
  /// from regressing `lastAppliedTs` (F2).
  ///
  /// The clamp: an older row still in `enqueued`/`leased`/`retrying`
  /// for the same room pins the candidate marker at `oldestActive −
  /// 1`. This is what makes bounded retries safe under the ledger
  /// model — a poison row held as `abandoned` *does not* pin the
  /// marker (it is out of the active set by design), but the same
  /// event is still visible in the ledger for diagnostics and can be
  /// resurrected by signal or user action.
  Future<bool> _advanceMarkerIfNewer(InboundQueueEntry entry) async {
    final marker = await (_db.select(
      _db.queueMarkers,
    )..where((t) => t.roomId.equals(entry.roomId))).getSingleOrNull();

    // Probe the oldest still-active row for this room, excluding the
    // row we're about to transition out of the active set (commit or
    // abandon — caller is responsible for the status flip already).
    final oldestActive = await _oldestActiveOriginTs(
      roomId: entry.roomId,
      excludeQueueId: entry.queueId,
    );
    final clampedCandidateTs = oldestActive == null
        ? entry.originTs
        : (entry.originTs < oldestActive ? entry.originTs : oldestActive - 1);

    final storedTs = marker?.lastAppliedTs ?? 0;
    final storedEventId = marker?.lastAppliedEventId;
    final shouldAdvance =
        storedTs == 0 ||
        clampedCandidateTs > storedTs ||
        (clampedCandidateTs == entry.originTs &&
            entry.originTs == storedTs &&
            (storedEventId == null ||
                entry.eventId.compareTo(storedEventId) > 0));

    if (!shouldAdvance) return false;

    // Only attach a durable event id when the candidate ts matches
    // the entry itself (i.e. we were not clamped). A clamp by some
    // older active row means the marker advances to `oldestActive -
    // 1`, which does not correspond to a specific event — leave the
    // event id slot null so later commits can attach a real one.
    final attachEventId =
        clampedCandidateTs == entry.originTs && entry.eventId.startsWith(r'$');
    final nextSeq = (marker?.lastAppliedCommitSeq ?? 0) + 1;
    await _db
        .into(_db.queueMarkers)
        .insertOnConflictUpdate(
          QueueMarkersCompanion.insert(
            roomId: entry.roomId,
            lastAppliedEventId: Value(
              attachEventId ? entry.eventId : marker?.lastAppliedEventId,
            ),
            lastAppliedTs: Value(clampedCandidateTs),
            lastAppliedCommitSeq: Value(nextSeq),
          ),
        );
    return true;
  }

  /// Returns the minimum `origin_ts` among active (`enqueued`,
  /// `leased`, `retrying`) rows for [roomId], excluding the row with
  /// `queue_id = excludeQueueId` so the in-flight commit/abandon
  /// does not pin the marker against itself. Null when no other
  /// active row exists.
  Future<int?> _oldestActiveOriginTs({
    required String roomId,
    required int excludeQueueId,
  }) async {
    final table = _db.inboundEventQueue;
    final minTs = table.originTs.min();
    // `status IN ('enqueued','leased','retrying')` is inlined as a
    // literal SQL fragment via `CustomExpression` so the SQLite planner
    // can prove this query's WHERE implies the partial index's WHERE
    // clause (`idx_inbound_event_queue_active_room_ts`, declared
    // `WHERE status IN ('enqueued','leased','retrying')`). Drift's
    // `t.status.isIn(_clampStatuses)` binds the three status values as
    // parameters; the planner can't see them at plan time, the
    // partial-index match fails, and the predicate falls back to a
    // rowid B-tree walk filtered by `room_id` + status equality. The
    // 2026-05-12 desktop super_slow log captured this as `SEARCH
    // inbound_event_queue` (no index name) at up to 862 ms per call.
    // Literal values mirror `_statusEnqueued`, `_statusLeased`, and
    // `_statusRetrying` declared at the top of this file — the
    // partial-index DDL in `lib/database/sync_db.dart` uses the same
    // string literals.
    final row =
        await (_db.selectOnly(table)
              ..addColumns([minTs])
              ..where(
                table.roomId.equals(roomId) &
                    const CustomExpression<bool>(
                      "status IN ('enqueued','leased','retrying')",
                    ) &
                    table.queueId.equals(excludeQueueId).not(),
              ))
            .getSingle();
    return row.read(minTs);
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
    _logging.captureEvent(
      'queue.retry eventId=${entry.eventId} '
      'reason=${reason.name} '
      'attempts=${entry.attempts + 1} '
      'nextDueAtMs=$nextDueAt',
      domain: _logDomain,
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
    _logging.captureEvent(
      'queue.skip eventId=${entry.eventId} reason=$resolvedReason '
      'markerAdvanced=$markerAdvanced',
      domain: _logDomain,
      subDomain: _logSubSkip,
    );
    _scheduleDepthEmit();
  }

  // ----------------------------------------------------------- resurrect

  /// Flips abandoned rows whose `json_path` matches [path] back to
  /// `enqueued` so the worker re-attempts them. Intended for the
  /// `AttachmentIndex.pathRecorded` signal — when an attachment JSON
  /// finally lands on disk, the sibling event whose apply failed
  /// with a descriptor-missing error is automatically un-parked.
  ///
  /// [hardCap] caps per-row resurrections so a truly poison event
  /// cannot thrash the worker forever. Rows with
  /// `resurrection_count >= hardCap` are skipped; the user can still
  /// discard them manually from the Skipped-events page.
  ///
  /// Returns the number of rows resurrected.
  Future<int> resurrectByPath(
    String path, {
    int hardCap = 50,
  }) async {
    return _resurrectWhere(
      (t) => t.jsonPath.equals(path),
      hardCap: hardCap,
      diagnostic: 'path=$path',
    );
  }

  /// Maximum number of paths bound per `json_path IN (...)` chunk in
  /// [resurrectByPaths]. SQLite's default `SQLITE_MAX_VARIABLE_NUMBER`
  /// is 999; chunking at 900 leaves headroom for the implicit
  /// `resurrection_count` parameter and any future additions to
  /// `_resurrectWhere` without bumping into the cap.
  static const int _resurrectByPathsChunkSize = 900;

  /// Bulk variant of [resurrectByPath] — flips abandoned rows whose
  /// `json_path` is in [paths] back to `enqueued`. Issues one
  /// SELECT + transactional UPDATE round-trip per
  /// [_resurrectByPathsChunkSize] batch.
  ///
  /// Backs the coordinator's debounced `pathRecorded` subscriber: a
  /// burst of attachment downloads (matrix-sync catch-up) used to fan
  /// out N independent per-path SELECT/UPDATE pairs, each queuing
  /// behind the previous transaction's writer lock. The 2026-05-12
  /// desktop super_slow log captured this as 222 hits/day of
  /// `inbound_event_queue WHERE status='abandoned' AND
  /// resurrection_count<? AND json_path=?` at ~384 ms each, ten or
  /// more landing in the same millisecond span. Collapsing the burst
  /// into one `WHERE json_path IN (...)` query removes the wait
  /// chain entirely.
  ///
  /// Chunking guards against SQLite's host-variable limit (default
  /// 999) so a very large catch-up batch — e.g. an initial sync that
  /// downloads thousands of attachments while abandoned ledger rows
  /// were waiting — cannot trip the cap. Each chunk still resurrects
  /// in one DB round-trip; the cumulative wall cost grows linearly
  /// with chunk count, never exponentially.
  ///
  /// Empty input returns 0 without touching the database. Duplicate
  /// paths are deduplicated to keep each IN-list short.
  Future<int> resurrectByPaths(
    Iterable<String> paths, {
    int hardCap = 50,
  }) async {
    final uniquePaths = paths.toSet();
    if (uniquePaths.isEmpty) return 0;

    final pathList = uniquePaths.toList(growable: false);
    var totalResurrected = 0;
    for (
      var start = 0;
      start < pathList.length;
      start += _resurrectByPathsChunkSize
    ) {
      final end = start + _resurrectByPathsChunkSize > pathList.length
          ? pathList.length
          : start + _resurrectByPathsChunkSize;
      final chunk = pathList.sublist(start, end);
      totalResurrected += await _resurrectWhere(
        (t) => t.jsonPath.isIn(chunk),
        hardCap: hardCap,
        diagnostic: 'paths=${chunk.length}',
      );
    }
    return totalResurrected;
  }

  /// Resurrects every abandoned row for the current (and any other)
  /// room that is still below [hardCap]. Used by the Skipped-events
  /// page's "Retry all" action.
  Future<int> resurrectAll({int hardCap = 50}) async {
    return _resurrectWhere(
      null,
      hardCap: hardCap,
      diagnostic: 'scope=all',
    );
  }

  /// Flips abandoned rows whose most recent retry reason matches
  /// [reasonName] back to `enqueued`. Used by the coordinator's
  /// `UpdateNotifications.updateStream` subscriber: every
  /// journal-db update fans out a targeted-enough resurrection for
  /// `missingBase` rows without building a per-entity tracker.
  ///
  /// Broader-than-ideal: any journal update triggers a resurrection
  /// pass across all rooms' missingBase rows. The [hardCap] still
  /// prevents thrash on a genuinely poisoned event; a finer-grained
  /// mapping (e.g. blocking-entry-id column) can ship in a follow-up
  /// if the broad pass proves too chatty.
  Future<int> resurrectByReason(
    String reasonName, {
    int hardCap = 50,
  }) async {
    return _resurrectWhere(
      (t) => t.lastErrorReason.equals(reasonName),
      hardCap: hardCap,
      diagnostic: 'reason=$reasonName',
    );
  }

  Future<int> _resurrectWhere(
    Expression<bool> Function(InboundEventQueue t)? extraWhere, {
    required int hardCap,
    required String diagnostic,
  }) async {
    final table = _db.inboundEventQueue;
    final nowMs = clock.now().millisecondsSinceEpoch;

    // Collect the target rows first so the bump of `resurrection_count`
    // and the log line reflect the rows that actually changed.
    //
    // `status = 'abandoned'` is inlined as a literal SQL fragment via
    // `CustomExpression` so the SQLite planner can prove this query's
    // WHERE implies the partial indices'
    // (`idx_inbound_event_queue_abandoned_path`,
    // `idx_inbound_event_queue_abandoned_reason`,
    // `idx_inbound_event_queue_abandoned_reason_resurrection`),
    // each declared with the literal `WHERE status = 'abandoned'`.
    // Drift's `t.status.equals(_statusAbandoned)` binds the value as a
    // parameter; the planner can't see it at plan time, the
    // partial-index match fails, and resurrectByReason / resurrectByPath
    // fall back to scanning the full append-only ledger. The
    // 2026-05-09 desktop slow_queries log captured this shape at
    // 107 hits/day in the 200–877 ms band even with the v17 partial
    // index in place.
    final selectQuery = _db.select(table)
      ..where(
        (t) =>
            const CustomExpression<bool>("status = 'abandoned'") &
            t.resurrectionCount.isSmallerThanValue(hardCap),
      );
    if (extraWhere != null) {
      selectQuery.where(extraWhere);
    }
    final rows = await selectQuery.get();
    if (rows.isEmpty) {
      return 0;
    }

    final ids = rows.map((r) => r.queueId).toList();
    final updated = await _db.transaction(() async {
      // A single UPDATE flips every eligible row; looping per-row
      // would pay the round-trip cost N times.
      // Reset `enqueued_at` so any pendingAttachment retries triggered
      // by the resurrected row get a fresh wall-clock deadline. Without
      // this, a row abandoned by `pendingAttachmentTimeout` would be
      // re-abandoned on its next worker pass because the elapsed
      // calculation in `InboundWorker._maybeRetry` is anchored to the
      // original enqueue time.
      final custom = await _db.customUpdate(
        'UPDATE inbound_event_queue '
        'SET status = ?, '
        '    resurrection_count = resurrection_count + 1, '
        '    attempts = 0, '
        '    next_due_at = 0, '
        '    lease_until = 0, '
        '    enqueued_at = ?, '
        '    last_error_reason = NULL, '
        '    abandoned_at = NULL '
        'WHERE queue_id IN (${List.filled(ids.length, '?').join(', ')})',
        variables: [
          Variable.withString(_statusEnqueued),
          Variable.withInt(nowMs),
          ...ids.map(Variable.withInt),
        ],
        updates: {table},
      );
      return custom;
    });

    _logging.captureEvent(
      'queue.resurrect $diagnostic '
      'count=$updated hardCap=$hardCap '
      'nowMs=$nowMs',
      domain: _logDomain,
      subDomain: _logSubResurrect,
    );
    if (updated > 0) {
      _scheduleDepthEmit();
    }
    return updated;
  }

  // ---------------------------------------------------------------- prune

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
        '  AND status IN (?, ?, ?)',
        variables: [
          Variable.withString(_statusAbandoned),
          Variable.withInt(nowMs),
          Variable.withString('strandedRoom'),
          Variable.withString(currentRoomId),
          Variable.withString(_statusEnqueued),
          Variable.withString(_statusLeased),
          Variable.withString(_statusRetrying),
        ],
        updates: {_db.inboundEventQueue},
      );
    });
    if (moved > 0) {
      _logging.captureEvent(
        'queue.prune currentRoom=$currentRoomId abandoned=$moved',
        domain: _logDomain,
        subDomain: _logSubPrune,
      );
      _scheduleDepthEmit();
    }
    return moved;
  }

  /// Best-effort helper to extract `jsonPath` from the Lotti sync
  /// message content. Returns null when the event is not a sync
  /// payload or the content shape does not match (defensive against
  /// SDK event shape drift). A null result means the row cannot be
  /// resurrected by path — manual "Retry all" still works.
  static String? _extractJsonPath(Event event) {
    try {
      final content = event.content;
      final raw = content['jsonPath'] ?? content['json_path'];
      if (raw is String && raw.isNotEmpty) {
        return raw.startsWith('/') ? raw : '/$raw';
      }
    } catch (_) {
      // Intentionally empty: diagnostic-only; adapter will still
      // record the path on apply failure if we miss it here.
    }
    return null;
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

  Future<int> _countTotal() async {
    final table = _db.inboundEventQueue;
    final count = table.queueId.count();
    final row =
        await (_db.selectOnly(table)
              ..addColumns([count])
              ..where(table.status.isIn(_activeStatuses)))
            .getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> _emitDepth() async {
    // Coalesce rapid successive calls so only one stats() scan is in
    // flight at a time; callers that arrive during the scan simply flip
    // the "rerun" flag so the final state is eventually emitted.
    if (_depthCtl.isClosed) return;
    if (_emitInFlight) {
      _emitPendingRerun = true;
      return;
    }
    _emitInFlight = true;
    try {
      do {
        _emitPendingRerun = false;
        QueueStats snapshot;
        try {
          snapshot = await stats();
        } catch (_) {
          // The stats call issues multiple aggregate queries; if
          // dispose() closes the controller (and the test tears down
          // the DB) during one of those async gaps, drift throws.
          // Swallow here because the emission is strictly diagnostic.
          if (_depthCtl.isClosed) return;
          rethrow;
        }
        // Re-check after the async gap — dispose() may have closed the
        // controller while we were computing stats (common in test
        // teardown, where the assertion completes before the fire-and-
        // forget `_emitDepth` that was kicked off from enqueue/commit).
        if (_depthCtl.isClosed) return;
        _depthCtl.add(
          QueueDepthSignal(
            total: snapshot.total,
            byProducer: snapshot.byProducer,
            oldestEnqueuedAt: snapshot.oldestEnqueuedAt,
            abandoned: snapshot.abandoned,
          ),
        );
      } while (_emitPendingRerun && !_depthCtl.isClosed);
    } finally {
      _emitInFlight = false;
    }
  }

  bool _emitInFlight = false;
  bool _emitPendingRerun = false;
}
