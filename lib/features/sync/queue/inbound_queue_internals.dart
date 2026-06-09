part of 'inbound_event_queue.dart';

/// Internal row hydration, marker advancement, origin-ts scan and queue-depth
/// emission helpers for [InboundQueue]. Split from the main file for size; all
/// members are library-private.
extension InboundQueueInternals on InboundQueue {
  void _scheduleDepthEmit() {
    if (_depthCtl.isClosed) return;
    if (_inBatchMode > 0) {
      _batchDirty = true;
      return;
    }
    unawaited(_emitDepth());
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
}

/// Best-effort helper to extract `jsonPath` from the Lotti sync
/// message content. Returns null when the event is not a sync
/// payload or the content shape does not match (defensive against
/// SDK event shape drift). A null result means the row cannot be
/// resurrected by path — manual "Retry all" still works.
String? _extractJsonPath(Event event) {
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
