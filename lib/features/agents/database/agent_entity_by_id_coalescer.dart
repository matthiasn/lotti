import 'dart:async';

import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:meta/meta.dart';

/// Signature of the batched read the coalescer folds single-id loads into.
/// Returns the found entities keyed by id; absent ids are simply missing.
typedef AgentEntitiesByIdsLoader =
    Future<Map<String, AgentDomainEntity>> Function(Iterable<String> ids);

/// Coalesces concurrent single-id `agent_entities` reads into one batched
/// `WHERE id IN (…)` round trip.
///
/// ## Why this exists
///
/// The 2026-06-16 → 2026-08-01 slow-query logs captured **92,787** hits on
/// `SELECT * FROM agent_entities WHERE id = ? AND deleted_at IS NULL` — 2,660 s
/// (44 min) of database time, the single largest shape in the corpus. The plan
/// was always a clean primary-key seek; the cost was the ~19 ms isolate
/// round trip, paid once per call.
///
/// The burst structure showed this could not be fixed at a call site: 80.7% of
/// calls arrived in seconds containing ≥ 20 calls, peaking at 606 in one
/// second, with a **median inter-arrival gap of 0.0 ms**. Calls dispatched
/// that close together are concurrent fan-out — many independent callers
/// (Riverpod provider families resolving one row each) firing in the same
/// turn — not one loop with a single place to batch.
///
/// So the batching lives here, below every caller. See
/// `docs/perf/2026-08-01_slow-queries-investigation.md`.
///
/// ## Transaction safety
///
/// Drift resolves the executor for a statement from `Zone.current`: inside
/// `db.transaction(...)` it forks a zone whose zone-value carries the
/// transaction executor (`DatabaseConnectionUser.resolvedEngine`, drift
/// 2.28.2 `connection_user.dart:96`). A batch that merged calls from inside a
/// transaction with calls from outside it would run the merged query on
/// whichever zone happened to flush it — reading *outside* the transaction and
/// breaking read-your-writes.
///
/// This is not hypothetical: `AgentRepoCore.upsertEntity` writes inside
/// `db.transaction(...)` and the attention/standing projection refresh it
/// invokes reads entities back by id within that same transaction.
///
/// Batches are therefore keyed by [Zone] identity, and the flush is scheduled
/// with [scheduleMicrotask] from the requesting zone so it *runs* in that zone.
/// Calls made inside a transaction batch only with each other and execute on
/// the transaction's executor; calls outside batch only with each other.
///
/// ## Batching window
///
/// One microtask — the same window `DataLoader` uses. Callers that already
/// await between their loads will not merge, which is correct: they are not
/// concurrent. Nothing is delayed by more than a microtask, so no caller pays
/// latency for the batching.
class AgentEntityByIdCoalescer {
  AgentEntityByIdCoalescer(this._loadByIds);

  final AgentEntitiesByIdsLoader _loadByIds;

  /// In-flight batches, one per requesting [Zone]. An entry exists only
  /// between the first [load] of a turn and that turn's flush, so this map is
  /// empty whenever the coalescer is idle.
  final Map<Zone, _PendingBatch> _batches = <Zone, _PendingBatch>{};

  /// Number of batches awaiting flush. Exposed so tests can assert the map
  /// does not leak entries after a flush rather than inferring it.
  @visibleForTesting
  int get pendingBatchCount => _batches.length;

  /// Resolves [id] to its entity, or `null` when no live row matches.
  ///
  /// Joins the current turn's batch for the calling zone, creating it (and
  /// scheduling its flush) if this is the turn's first load.
  Future<AgentDomainEntity?> load(String id) {
    final zone = Zone.current;
    final batch = _batches.putIfAbsent(zone, () {
      // Scheduled from `zone`, so the flush runs in `zone` and drift resolves
      // the same executor the caller would have used directly.
      scheduleMicrotask(() => _flush(zone));
      return _PendingBatch();
    });

    final completer = Completer<AgentDomainEntity?>();
    // Duplicate ids within a turn share one query result but keep separate
    // completers, so each caller still gets its own future.
    batch.waitersById
        .putIfAbsent(id, () => <Completer<AgentDomainEntity?>>[])
        .add(completer);
    return completer.future;
  }

  Future<void> _flush(Zone zone) async {
    // Remove before awaiting: loads issued while the batched query is in
    // flight must start a fresh batch rather than join one already dispatched.
    final batch = _batches.remove(zone);
    if (batch == null) return;

    final waitersById = batch.waitersById;
    try {
      final found = await _loadByIds(waitersById.keys.toList(growable: false));
      for (final entry in waitersById.entries) {
        final entity = found[entry.key];
        for (final waiter in entry.value) {
          waiter.complete(entity);
        }
      }
    } catch (_) {
      // A batch can fail for a reason that belongs to ONE id — most commonly a
      // row whose `serialized` payload fails to decode, which throws while
      // mapping the whole result set. Before coalescing, such a row failed only
      // its own `getEntity` call and every other id still resolved.
      //
      // Preserve that: fall back to loading each id on its own, so exactly the
      // offending ids see the error. This runs only on the error path, and it
      // is no more expensive than the pre-coalescing behaviour it restores.
      await _completeIndividually(waitersById);
    }
  }

  /// Error-path fallback: resolve each id with its own single-id load so one
  /// failing row cannot poison unrelated waiters in the same batch.
  Future<void> _completeIndividually(
    Map<String, List<Completer<AgentDomainEntity?>>> waitersById,
  ) async {
    await Future.wait(
      waitersById.entries.map((entry) async {
        try {
          final found = await _loadByIds(<String>[entry.key]);
          for (final waiter in entry.value) {
            waiter.complete(found[entry.key]);
          }
        } catch (error, stackTrace) {
          for (final waiter in entry.value) {
            waiter.completeError(error, stackTrace);
          }
        }
      }),
    );
  }
}

class _PendingBatch {
  final Map<String, List<Completer<AgentDomainEntity?>>> waitersById =
      <String, List<Completer<AgentDomainEntity?>>>{};
}
