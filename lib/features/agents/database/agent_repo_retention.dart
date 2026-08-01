import 'package:drift/drift.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/service/agent_retention_policy.dart';

/// Batched hard deletes for the derived rows retention may forget.
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
class AgentRepoRetention {
  AgentRepoRetention(this._db);

  final AgentDatabase _db;

  /// Deletes day-status events created before [cutoff].
  Future<int> pruneDayStatusEventsBefore(
    DateTime cutoff, {
    required int batchSize,
    required int maxBatches,
  }) => _batched(
    maxBatches: maxBatches,
    run: () => _db.customUpdate(
      'DELETE FROM agent_entities WHERE id IN ( '
      'SELECT id FROM agent_entities '
      'WHERE type = ?1 AND created_at < ?2 LIMIT ?3)',
      variables: [
        const Variable<String>(AgentEntityTypes.dayStatusEvent),
        Variable<DateTime>(cutoff),
        Variable<int>(batchSize),
      ],
      updateKind: UpdateKind.delete,
    ),
  );

  /// Deletes observation messages beyond the newest [keepPerAgent] **per
  /// agent**, together with the payload rows they own.
  ///
  /// The payloads are the reason this cannot be a plain `DELETE`: each
  /// observation is a message row plus an `agentMessagePayload` row carrying
  /// its text, and the payload is the larger of the two. Deleting only the
  /// message would leave the bytes behind forever with nothing pointing at
  /// them — retention that grows the store.
  ///
  /// Rank is per `(agent_id)` partition by `created_at DESC, id DESC`, the same
  /// total order the read path uses, so "kept" here means exactly the rows a
  /// read could still return.
  Future<int> pruneObservationsBeyond({
    required int keepPerAgent,
    required int batchSize,
    required int maxBatches,
  }) => _batched(
    maxBatches: maxBatches,
    run: () => _db.transaction(() async {
      final victims = await _db
          .customSelect(
            'SELECT id, json_extract(serialized, ?1) AS payload_id '
            'FROM agent_entities WHERE type = ?2 AND subtype = ?3 '
            'AND id NOT IN ('
            '  SELECT id FROM ('
            '    SELECT id, ROW_NUMBER() OVER ('
            '      PARTITION BY agent_id ORDER BY created_at DESC, id DESC'
            '    ) AS rank FROM agent_entities '
            '    WHERE type = ?2 AND subtype = ?3 '
            '  ) WHERE rank <= ?4 '
            ') LIMIT ?5',
            variables: [
              const Variable<String>(r'$.contentEntryId'),
              const Variable<String>(AgentEntityTypes.agentMessage),
              Variable<String>(observationSubtype),
              Variable<int>(keepPerAgent),
              Variable<int>(batchSize),
            ],
            readsFrom: {_db.agentEntities},
          )
          .get();
      if (victims.isEmpty) return 0;

      final messageIds = <String>[];
      final payloadIds = <String>[];
      for (final row in victims) {
        messageIds.add(row.read<String>('id'));
        final payloadId = row.read<String?>('payload_id');
        if (payloadId != null) payloadIds.add(payloadId);
      }
      // Payloads first: a crash between the two statements must not leave a
      // message whose text is already gone. Losing the payload while the
      // message survives would render an observation as "(no content)"; the
      // other order only leaves an orphan the next sweep collects.
      if (payloadIds.isNotEmpty) {
        await _deleteByIds(payloadIds);
      }
      return _deleteByIds(messageIds);
    }),
  );

  /// Deletes wake-run log rows created before [cutoff].
  Future<int> pruneWakeRunsBefore(
    DateTime cutoff, {
    required int batchSize,
    required int maxBatches,
  }) => _batched(
    maxBatches: maxBatches,
    run: () => _db.customUpdate(
      'DELETE FROM wake_run_log WHERE run_key IN ( '
      'SELECT run_key FROM wake_run_log WHERE created_at < ?1 LIMIT ?2)',
      variables: [
        Variable<DateTime>(cutoff),
        Variable<int>(batchSize),
      ],
      updateKind: UpdateKind.delete,
    ),
  );

  Future<int> _deleteByIds(List<String> ids) {
    final placeholders = List.filled(ids.length, '?').join(',');
    return _db.customUpdate(
      'DELETE FROM agent_entities WHERE id IN ($placeholders)',
      variables: [for (final id in ids) Variable<String>(id)],
      updateKind: UpdateKind.delete,
    );
  }

  /// Runs [run] until it stops removing rows or [maxBatches] is reached.
  Future<int> _batched({
    required int maxBatches,
    required Future<int> Function() run,
  }) async {
    var total = 0;
    for (var batch = 0; batch < maxBatches; batch++) {
      final removed = await run();
      if (removed == 0) break;
      total += removed;
    }
    return total;
  }
}
