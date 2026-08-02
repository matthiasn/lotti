import 'package:drift/drift.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';

/// Batched hard deletes for the derived rows retention may forget.
///
/// **Scope: day-status events**, which carry no causal entanglement and so can
/// be deleted row by row. Observations sit inside the agent's `messagePrev`
/// DAG and need an ancestor-closed set plus the edges into it, which is
/// `AgentRepoObservationRetention`'s job.
///
/// **Hard delete, no tombstone.** A tombstone per pruned row would grow the
/// sync payload in exactly the dimension retention exists to shrink, and there
/// is nothing to converge on: every device applies the same deterministic rule
/// to the same synced rows and reaches the same conclusion on its own. A row
/// sitting on the boundary may survive a few hours longer on one device than
/// another; for derived, observational data that is invisible.
///
/// Every method deletes at most `batchSize * maxBatchesPerSweep` rows and
/// returns how many it removed, so a sweep is bounded, resumable, and safe to
/// interrupt: each batch is its own statement, and whatever is left is
/// collected by the next sweep.
/// Splits [ids] into runs of at most [size] so a delete never exceeds
/// SQLite's host-parameter cap.
///
/// Exceeding it throws, which rolls back the surrounding transaction and
/// leaves every start-up retrying the same batch — retention that never makes
/// progress, which is worse than not sweeping at all.
///
/// Shared by every retention sweep that deletes by id list.
Iterable<List<String>> chunkForStatement(List<String> ids, int size) sync* {
  for (var start = 0; start < ids.length; start += size) {
    final end = start + size > ids.length ? ids.length : start + size;
    yield ids.sublist(start, end);
  }
}

class AgentRepoRetention {
  AgentRepoRetention(this._db);

  final AgentDatabase _db;

  /// Deletes day-status events created before [cutoff], **keeping the newest
  /// one per day**.
  ///
  /// The newest event is not residue: `dayAgentPersonaProvider` reads it to
  /// decide how a day is presented, so deleting every event for an old day
  /// silently changes what that day looks like when the user scrolls back.
  /// Keeping one row per day still turns an unbounded pile into a bounded
  /// one — the events are raised several times a day, and only the last is
  /// read after the digest has consumed them.
  ///
  /// `subtype` holds the **day id** for a status event, so the correlated
  /// lookup is already per day. It is scoped by `agent_id` as well: two agents
  /// can raise events for the same day, and without that scoping one agent's
  /// newer event would license deleting another agent's last one.
  ///
  /// Both sides carry `deleted_at IS NULL` so the predicate matches the
  /// `idx_agent_entities_active_type_sub_created_id` partial index. Without it
  /// SQLite falls back to the broad `idx_agent_entities_type` and every batch
  /// rescans the whole status-event history — twenty times per sweep.
  ///
  /// Returns the ids removed, so the caller can reclaim their JSON sidecars —
  /// the database row is only half of what a synced entity leaves behind.
  Future<List<String>> pruneDayStatusEventsBefore(
    DateTime cutoff, {
    required int batchSize,
    required int maxBatches,
  }) => _batchedIds(
    maxBatches: maxBatches,
    run: () => _db.transaction(() async {
      final victims = [
        for (final row
            in await _db
                .customSelect(
                  'SELECT e.id FROM agent_entities AS e '
                  'WHERE e.type = ?1 AND e.created_at < ?2 '
                  'AND e.deleted_at IS NULL '
                  'AND EXISTS ( '
                  '  SELECT 1 FROM agent_entities AS newer '
                  '  WHERE newer.type = ?1 AND newer.subtype = e.subtype '
                  '  AND newer.agent_id = e.agent_id '
                  '  AND newer.deleted_at IS NULL '
                  '  AND (newer.created_at > e.created_at '
                  '       OR (newer.created_at = e.created_at AND newer.id > e.id)) '
                  ') LIMIT ?3',
                  variables: [
                    const Variable<String>(AgentEntityTypes.dayStatusEvent),
                    Variable<DateTime>(cutoff),
                    Variable<int>(batchSize),
                  ],
                  readsFrom: {_db.agentEntities},
                )
                .get())
          row.read<String>('id'),
      ];
      if (victims.isEmpty) return const <String>[];
      await _deleteByIds(victims);
      return victims;
    }),
  );

  /// Host-parameter budget per statement; SQLite's default cap is 999.
  static const _maxVariablesPerStatement = 400;

  Future<void> _deleteByIds(List<String> ids) async {
    for (final chunk in chunkForStatement(ids, _maxVariablesPerStatement)) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      await _db.customUpdate(
        'DELETE FROM agent_entities WHERE id IN ($placeholders)',
        variables: [for (final id in chunk) Variable<String>(id)],
        updateKind: UpdateKind.delete,
      );
    }
  }

  /// Accumulates ids until a batch comes back empty or [maxBatches] is
  /// reached.
  Future<List<String>> _batchedIds({
    required int maxBatches,
    required Future<List<String>> Function() run,
  }) async {
    final all = <String>[];
    for (var batch = 0; batch < maxBatches; batch++) {
      final removed = await run();
      if (removed.isEmpty) break;
      all.addAll(removed);
    }
    return all;
  }
}
