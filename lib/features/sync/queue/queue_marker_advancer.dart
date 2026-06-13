import 'package:drift/drift.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/queue/inbound_queue_models.dart';

/// Advances `queue_markers` after a queue row leaves the active set.
///
/// Collaborator of `InboundQueue`: [advanceIfNewer] is invoked from
/// inside the queue's `commitApplied` / `markSkipped` transactions so
/// the marker flip commits atomically with the row's status flip
/// (drift transactions are zone-based, so this class participates in
/// the caller's ambient transaction through the shared [SyncDatabase]).
class QueueMarkerAdvancer {
  QueueMarkerAdvancer(this._db);

  final SyncDatabase _db;

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
  ///
  /// Must be called inside the transaction that also flips [entry]'s
  /// status out of the active set; the caller owns that status flip.
  Future<bool> advanceIfNewer(InboundQueueEntry entry) async {
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
    // `t.status.isIn(...)` binds the three status values as
    // parameters; the planner can't see them at plan time, the
    // partial-index match fails, and the predicate falls back to a
    // rowid B-tree walk filtered by `room_id` + status equality. The
    // 2026-05-12 desktop super_slow log captured this as `SEARCH
    // inbound_event_queue` (no index name) at up to 862 ms per call.
    // Literal values mirror `InboundQueueStatuses.active` — the
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
}
