import 'package:drift/drift.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_cache.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_tracer.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// Handles INCOMING backfill responses and the resolution of pending hints for
/// the sync sequence log.
///
/// Owns the status-transition rules for backfill responses (deleted /
/// unresolvable / hint) and the verify-and-mark-backfilled flow. Reset paths
/// that may shorten many hosts' watermarks clear the shared
/// [SyncSequenceCache] watermark and materialized-bound maps.
class SyncSequenceBackfillResponder {
  SyncSequenceBackfillResponder({
    required this._syncDatabase,
    required this._cache,
    required this._tracer,
  });

  final SyncDatabase _syncDatabase;
  final SyncSequenceCache _cache;
  final SyncSequenceTracer _tracer;

  /// Applies the outcome of a peer's answer to one of our backfill requests for
  /// `(hostId, counter)`. A [deleted] response marks the counter as
  /// permanently gone (skipped if we have meanwhile received/backfilled it), an
  /// [unresolvable] response retires it, and otherwise the response confirms a
  /// payload we should now expect via the normal receive path. Keeps the
  /// sequence-log status in step so the row stops being re-requested.
  Future<void> handleBackfillResponse({
    required String hostId,
    required int counter,
    required bool deleted,
    bool unresolvable = false,
    String? entryId,
    SyncSequencePayloadType payloadType = SyncSequencePayloadType.journalEntity,
  }) async {
    if (deleted) {
      final existing = await _syncDatabase.getEntryByHostAndCounter(
        hostId,
        counter,
      );
      if (existing != null &&
          (existing.status == SyncSequenceStatus.received.index ||
              existing.status == SyncSequenceStatus.backfilled.index)) {
        _tracer.trace(
          'handleBackfillResponse: deleted ignored for '
          'hostId=$hostId counter=$counter — existing status='
          '${SyncSequenceStatus.values[existing.status]}',
          subDomain: 'sequence.backfillResponse',
        );
        return;
      }

      // Mark as deleted - the entry was purged and cannot be backfilled
      await _syncDatabase.updateSequenceStatus(
        hostId,
        counter,
        SyncSequenceStatus.deleted,
      );

      _tracer.trace(
        'handleBackfillResponse hostId=$hostId counter=$counter deleted=true',
        subDomain: 'sequence.backfillResponse',
      );
      return;
    }

    if (unresolvable) {
      // Classify the incoming `unresolvable=true` as [burned]: a backfill
      // response carrying that flag is only ever sent by the originating host
      // for its own counter (foreign-host requests get covering hints, never
      // `unresolvable`), and the originator is authoritative for its own
      // counters, so this is a clean non-event rather than a receiver give-up.
      // Upsert (not update-only) because a proactive burn broadcast from the
      // originator frequently arrives on a peer that has not yet materialized
      // `(hostId, counter)` — gap detection hasn't run for this host yet, no
      // covered-VC hint has referenced the counter, and so on. An
      // `updateSequenceStatus` call would silently no-op in that common case
      // and drop the authoritative marker, sending the peer back into reactive
      // backfill later when the gap eventually surfaces.
      //
      // Do NOT downgrade rows that already have an authoritative success
      // state (received / backfilled / deleted) — if the peer obtained
      // the payload through another route, that's strictly better than
      // the originator's burn hint and should win. An already-[burned] row
      // is likewise left alone: it is terminal, and re-writing it would only
      // churn `updated_at` and re-emit a trace for an unchanged status.
      final existing = await _syncDatabase.getEntryByHostAndCounter(
        hostId,
        counter,
      );
      if (existing != null &&
          (existing.status == SyncSequenceStatus.received.index ||
              existing.status == SyncSequenceStatus.backfilled.index ||
              existing.status == SyncSequenceStatus.deleted.index ||
              existing.status == SyncSequenceStatus.burned.index)) {
        _tracer.trace(
          'handleBackfillResponse: unresolvable ignored for '
          'hostId=$hostId counter=$counter — existing status='
          '${SyncSequenceStatus.values[existing.status]}',
          subDomain: 'sequence.backfillResponse',
        );
        return;
      }

      final now = DateTime.now();
      await _syncDatabase.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: Value(hostId),
          counter: Value(counter),
          // Clear any stale payload mapping for the same reason as in
          // [markOwnCounterUnresolvable]: the burn marker asserts no entity is
          // bound to this counter, so a lingering entry_id must not survive.
          entryId: const Value(null),
          payloadType: Value(payloadType.index),
          status: Value(SyncSequenceStatus.burned.index),
          createdAt: Value(existing?.createdAt ?? now),
          updatedAt: Value(now),
        ),
      );

      _tracer.trace(
        'handleBackfillResponse hostId=$hostId counter=$counter '
        'unresolvable=true → burned',
        subDomain: 'sequence.backfillResponse',
      );
      return;
    }

    // Non-deleted response: store the entryId hint without changing status.
    // The actual backfill confirmation happens when we verify the entry exists.
    final existing = await _syncDatabase.getEntryByHostAndCounter(
      hostId,
      counter,
    );

    if (existing == null) {
      // Entry doesn't exist in our log - insert with entryId hint and mark
      // as "requested" since we're receiving a response to a backfill request.
      // The actual backfilled status is set when we verify the entry exists.
      final now = DateTime.now();
      await _syncDatabase.recordSequenceEntry(
        SyncSequenceLogCompanion(
          hostId: Value(hostId),
          counter: Value(counter),
          entryId: Value(entryId),
          payloadType: Value(payloadType.index),
          status: Value(SyncSequenceStatus.requested.index),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      _tracer.trace(
        'handleBackfillResponse: stored hint hostId=$hostId counter=$counter entryId=$entryId (new entry)',
        subDomain: 'sequence.backfillHint',
      );
      return;
    }

    // Don't overwrite already received/backfilled/deleted entries, and never
    // reopen a [burned] row: burned is the authoritative terminal non-event,
    // and a later hint covering a *different* entity on our own counter must
    // not resurrect it (see backfill_response_handler's covering-hint guard).
    if (existing.status == SyncSequenceStatus.received.index ||
        existing.status == SyncSequenceStatus.backfilled.index ||
        existing.status == SyncSequenceStatus.deleted.index ||
        existing.status == SyncSequenceStatus.burned.index) {
      _tracer.trace(
        'handleBackfillResponse: entry already has status=${SyncSequenceStatus.values[existing.status]} hostId=$hostId counter=$counter',
        subDomain: 'sequence.backfillResponse',
      );
      return;
    }

    // When an unresolvable entry receives a valid hint, reset to requested
    // so it can be verified. This handles the case where the first response
    // incorrectly marked it unresolvable but a later response has the answer.
    final newStatus = existing.status == SyncSequenceStatus.unresolvable.index
        ? SyncSequenceStatus.requested.index
        : existing.status;

    final now = DateTime.now();
    await _syncDatabase.recordSequenceEntry(
      SyncSequenceLogCompanion(
        hostId: Value(hostId),
        counter: Value(counter),
        entryId: Value(entryId),
        payloadType: Value(payloadType.index),
        status: Value(newStatus),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(now),
      ),
    );

    if (existing.status == SyncSequenceStatus.unresolvable.index) {
      _tracer.trace(
        'handleBackfillResponse: reopened unresolvable entry hostId=$hostId counter=$counter entryId=$entryId',
        subDomain: 'sequence.backfillReopened',
      );
    }

    _tracer.trace(
      'handleBackfillResponse: stored hint hostId=$hostId counter=$counter entryId=$entryId (status=${SyncSequenceStatus.values[newStatus]})',
      subDomain: 'sequence.backfillHint',
    );
  }

  /// Verify that we have an entry locally and its VC covers the requested
  /// (hostId, counter), then mark as backfilled.
  ///
  /// Returns true if verified and marked as backfilled.
  Future<bool> verifyAndMarkBackfilled({
    required String hostId,
    required int counter,
    required String entryId,
    required VectorClock entryVectorClock,
    SyncSequencePayloadType payloadType = SyncSequencePayloadType.journalEntity,
  }) async {
    // Verify the entry's VC covers the requested (hostId, counter)
    final vcCounter = entryVectorClock.vclock[hostId];
    if (vcCounter == null || vcCounter < counter) {
      _tracer.trace(
        'verifyAndMarkBackfilled: entry $entryId VC does not cover $hostId:$counter (vc[$hostId]=$vcCounter)',
        subDomain: 'sequence.backfillVerify',
      );
      return false;
    }

    // Look up the sequence log entry
    final existing = await _syncDatabase.getEntryByHostAndCounter(
      hostId,
      counter,
    );

    if (existing == null ||
        (existing.status != SyncSequenceStatus.missing.index &&
            existing.status != SyncSequenceStatus.requested.index)) {
      // Already processed or doesn't exist
      return false;
    }

    // Mark as backfilled. Preserve `existing.createdAt` so post-mortems
    // and the slow-query-friendly `(status, created_at)` partial index
    // continue to reflect when gap detection first flagged this counter
    // — overwriting it with `now` was hiding the real detection time
    // behind the verify timestamp (see the 2026-04-25 catch-up audit).
    final now = DateTime.now();
    await _syncDatabase.recordSequenceEntry(
      SyncSequenceLogCompanion(
        hostId: Value(hostId),
        counter: Value(counter),
        entryId: Value(entryId),
        payloadType: Value(payloadType.index),
        status: Value(SyncSequenceStatus.backfilled.index),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(now),
      ),
    );

    _tracer.trace(
      'verifyAndMarkBackfilled: confirmed hostId=$hostId counter=$counter entryId=$entryId',
      subDomain: 'sequence.backfillVerified',
    );
    return true;
  }

  /// Resolve any pending backfill hints for the given entryId.
  /// Called after receiving an entry via sync to check if it resolves
  /// any pending (hostId, counter) requests.
  Future<int> resolvePendingHints({
    required SyncSequencePayloadType payloadType,
    required String payloadId,
    required VectorClock payloadVectorClock,
  }) async {
    final pendingEntries = await _syncDatabase.getPendingEntriesByPayloadId(
      payloadType: payloadType,
      payloadId: payloadId,
    );

    var resolved = 0;
    for (final pending in pendingEntries) {
      final verified = await verifyAndMarkBackfilled(
        hostId: pending.hostId,
        counter: pending.counter,
        entryId: payloadId,
        entryVectorClock: payloadVectorClock,
        payloadType: payloadType,
      );
      if (verified) {
        resolved++;
      }
    }

    if (resolved > 0) {
      _tracer.trace(
        'resolvePendingHints: resolved $resolved pending entries for type=$payloadType id=$payloadId',
        subDomain: 'sequence.backfillResolved',
      );
    }

    return resolved;
  }

  /// Reset entries marked as unresolvable that now have a known payload
  /// (entryId) back to "missing" so they can be re-requested.
  /// Returns the number of entries reset.
  Future<int> resetUnresolvableEntries() async {
    final count = await _syncDatabase.resetUnresolvableWithKnownPayload();

    if (count > 0) {
      _cache
        ..clearLastCounterCache()
        ..clearMaterializedUpperBound();
      _tracer.trace(
        'resetUnresolvableEntries: reset $count entries back to missing',
        subDomain: 'sequence.resetUnresolvable',
      );
    }

    return count;
  }

  /// Reset every `unresolvable` row back to `missing`, regardless of
  /// whether an `entry_id` is already known locally. Used by the Backfill
  /// Settings "Ask peers for unresolvable entries" action to re-open the
  /// row for the normal backfill sweep — once a peer responds with a
  /// payload hint, `handleBackfillResponse` fills in `entry_id` and
  /// eventually flips the row to `received`/`backfilled`.
  ///
  /// Semantically stronger than [resetUnresolvableEntries]; prefer this
  /// one when a user explicitly wants to re-query peers for rows whose
  /// originating host is dead but which a currently-alive peer may
  /// still have.
  Future<int> resetAllUnresolvableEntries() async {
    final count = await _syncDatabase.resetAllUnresolvableEntries();

    if (count > 0) {
      _cache
        ..clearLastCounterCache()
        ..clearMaterializedUpperBound();
      _tracer.trace(
        'resetAllUnresolvableEntries: reset $count entries back to missing',
        subDomain: 'sequence.resetAllUnresolvable',
      );
    }

    return count;
  }
}
