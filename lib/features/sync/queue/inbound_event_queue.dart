import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_event_classifier.dart';
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
enum RetryReason { missingBase, retriable, decryptionPending }

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
    required this.attempts,
    required this.leaseUntil,
    required this.rawJson,
  });

  final int queueId;
  final String eventId;
  final String roomId;
  final int originTs;
  final InboundEventProducer producer;
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
  });

  final int total;
  final Map<InboundEventProducer, int> byProducer;
  final int? oldestEnqueuedAt;
}

class QueueStats {
  const QueueStats({
    required this.total,
    required this.byProducer,
    required this.readyNow,
    required this.oldestEnqueuedAt,
  });

  final int total;
  final Map<InboundEventProducer, int> byProducer;
  final int readyNow;
  final int? oldestEnqueuedAt;
}

const _logDomain = 'sync';
const _logSubEnqueue = 'queue.enqueue';
const _logSubCommit = 'queue.commit';
const _logSubRetry = 'queue.retry';
const _logSubSkip = 'queue.skip';
const _logSubPrune = 'queue.prune';

/// Durable inbound queue for Matrix sync events. See §3 of
/// `docs/sync/2026-04-21_inbound_event_queue_implementation_plan.md`.
class InboundQueue {
  InboundQueue({
    required SyncDatabase db,
    required LoggingService logging,
    Duration? leaseDuration,
  }) : _db = db,
       _logging = logging,
       _leaseDuration = leaseDuration ?? SyncTuning.inboundWorkerLeaseDuration;

  final SyncDatabase _db;
  final LoggingService _logging;
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
  /// drainers cannot double-apply.
  Future<List<InboundQueueEntry>> peekBatchReady({
    int maxBatch = SyncTuning.inboundWorkerBatchSize,
  }) async {
    final nowMs = clock.now().millisecondsSinceEpoch;
    final leaseUntilMs = nowMs + _leaseDuration.inMilliseconds;

    return _db.transaction(() async {
      final query = _db.select(_db.inboundEventQueue)
        ..where(
          (t) =>
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
      await (_db.update(_db.inboundEventQueue)
            ..where((t) => t.queueId.isIn(ids)))
          .write(InboundEventQueueCompanion(leaseUntil: Value(leaseUntilMs)));
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

  /// Atomically deletes [entry] from the queue and, if the entry's
  /// timestamp strictly advances the stored marker (with the durable
  /// event id as the tiebreaker on equal timestamps), updates
  /// `queue_markers` for the room. Both operations land in one
  /// `sync_db` transaction so a crash between them cannot leave the
  /// marker pointing past a row still in the queue (F2 + F5).
  Future<void> commitApplied(InboundQueueEntry entry) async {
    var markerAdvanced = false;
    await _db.transaction(() async {
      await (_db.delete(
        _db.inboundEventQueue,
      )..where((t) => t.queueId.equals(entry.queueId))).go();
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
    _scheduleDepthEmit();
  }

  /// Advances `queue_markers` for [entry]'s room if [entry]'s timestamp
  /// strictly moves the marker forward. Bypasses
  /// `TimelineEventOrdering.isNewer` because `isNewer` treats a null
  /// stored event id as "no marker" — but the marker can legitimately
  /// carry a non-zero timestamp with a null event id (right after a
  /// placeholder advance). Guarding on the timestamp directly, with
  /// the durable event id as a tiebreaker only when both sides are
  /// durable, prevents a later durable event with an older timestamp
  /// from regressing `lastAppliedTs` (F2).
  Future<bool> _advanceMarkerIfNewer(InboundQueueEntry entry) async {
    final marker = await (_db.select(
      _db.queueMarkers,
    )..where((t) => t.roomId.equals(entry.roomId))).getSingleOrNull();

    final storedTs = marker?.lastAppliedTs ?? 0;
    final storedEventId = marker?.lastAppliedEventId;
    final shouldAdvance =
        storedTs == 0 ||
        entry.originTs > storedTs ||
        (entry.originTs == storedTs &&
            (storedEventId == null ||
                entry.eventId.compareTo(storedEventId) > 0));

    if (!shouldAdvance) return false;

    final isDurable = entry.eventId.startsWith(r'$');
    final nextSeq = (marker?.lastAppliedCommitSeq ?? 0) + 1;
    await _db
        .into(_db.queueMarkers)
        .insertOnConflictUpdate(
          QueueMarkersCompanion.insert(
            roomId: entry.roomId,
            lastAppliedEventId: Value(
              isDurable ? entry.eventId : marker?.lastAppliedEventId,
            ),
            lastAppliedTs: Value(entry.originTs),
            lastAppliedCommitSeq: Value(nextSeq),
          ),
        );
    return true;
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
  }

  /// Permanently drops an entry the worker classifies as unrecoverable
  /// and advances the per-room marker past it, so producers that
  /// resume from the marker do not re-fetch the same poison event
  /// indefinitely. Advancement uses the same monotonic guard as
  /// `commitApplied` — older rows cannot regress the marker.
  Future<void> markSkipped(
    InboundQueueEntry entry, {
    String? reason,
  }) async {
    var markerAdvanced = false;
    await _db.transaction(() async {
      await (_db.delete(
        _db.inboundEventQueue,
      )..where((t) => t.queueId.equals(entry.queueId))).go();
      markerAdvanced = await _advanceMarkerIfNewer(entry);
    });
    _logging.captureEvent(
      'queue.skip eventId=${entry.eventId} reason=${reason ?? 'unspecified'} '
      'markerAdvanced=$markerAdvanced',
      domain: _logDomain,
      subDomain: _logSubSkip,
    );
    _scheduleDepthEmit();
  }

  // ---------------------------------------------------------------- prune

  /// Deletes every entry whose `roomId` does not match [currentRoomId].
  /// Call on session bootstrap and whenever the active sync room
  /// changes. Returns the number of rows removed (F6).
  Future<int> pruneStrandedEntries(String currentRoomId) async {
    final deleted = await (_db.delete(
      _db.inboundEventQueue,
    )..where((t) => t.roomId.equals(currentRoomId).not())).go();
    if (deleted > 0) {
      _logging.captureEvent(
        'queue.prune currentRoom=$currentRoomId deleted=$deleted',
        domain: _logDomain,
        subDomain: _logSubPrune,
      );
      _scheduleDepthEmit();
    }
    return deleted;
  }

  // ---------------------------------------------------------------- stats

  Future<QueueStats> stats() async {
    final nowMs = clock.now().millisecondsSinceEpoch;
    final table = _db.inboundEventQueue;
    final countCol = table.queueId.count();
    final oldestCol = table.enqueuedAt.min();

    // One aggregate for totals + oldest enqueue timestamp.
    final totalRow = await (_db.selectOnly(
      table,
    )..addColumns([countCol, oldestCol])).getSingle();
    final total = totalRow.read(countCol) ?? 0;
    final oldest = totalRow.read(oldestCol);

    // Group-by aggregate for per-producer counts.
    final byProducer = <InboundEventProducer, int>{};
    if (total > 0) {
      final producerRows =
          await (_db.selectOnly(table)
                ..addColumns([table.producer, countCol])
                ..groupBy([table.producer]))
              .get();
      for (final row in producerRows) {
        final name = row.read(table.producer);
        final c = row.read(countCol) ?? 0;
        if (name != null && c > 0) {
          byProducer[_producerFromName(name)] = c;
        }
      }
    }

    // Aggregate for the ready-now counter.
    final readyRow =
        await (_db.selectOnly(table)
              ..addColumns([countCol])
              ..where(
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
          'FROM inbound_event_queue',
        )
        .getSingleOrNull();
    if (row == null) return null;
    final value = row.data['ready_at'];
    return value is int ? value : null;
  }

  Future<int> _countTotal() async {
    final count = _db.inboundEventQueue.queueId.count();
    final row = await (_db.selectOnly(
      _db.inboundEventQueue,
    )..addColumns([count])).getSingle();
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
