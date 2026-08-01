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

  /// Deletes observations bounded by BOTH a per-agent count and an age
  /// ceiling, together with the payload rows and causal links they own.
  ///
  /// **Two bounds, because neither is sufficient alone.** Daily OS writes
  /// observations under a fresh `day_agent:<dayId>` identity every day, and
  /// each goes cold permanently — so a per-agent count would let one more
  /// agent, with up to [keepPerAgent] rows of its own, appear every day
  /// forever. The count bounds the long-lived coordinator's recency; the
  /// [cutoff] reaps the accumulating per-day identities.
  ///
  /// **Three row families, not one.** Each observation is a message, an
  /// `agentMessagePayload` carrying its text (the larger of the two), and a
  /// `message_prev` link into the causal chain. Deleting only the message
  /// would leave the bytes and the link behind forever with nothing pointing
  /// at them — retention that grows the store.
  ///
  /// Rank is per `(agent_id)` partition by `created_at DESC, id DESC`, the same
  /// total order the read path uses, so "kept" here means exactly the rows a
  /// read could still return.
  Future<int> pruneObservations({
    required int keepPerAgent,
    required DateTime cutoff,
    required int batchSize,
    required int maxBatches,
  }) => _batched(
    maxBatches: maxBatches,
    run: () => _db.transaction(() async {
      final victims = await _db
          .customSelect(
            'SELECT id, json_extract(serialized, ?1) AS payload_id '
            'FROM agent_entities WHERE type = ?2 AND subtype = ?3 '
            'AND (created_at < ?6 OR id NOT IN ('
            '  SELECT id FROM ('
            '    SELECT id, ROW_NUMBER() OVER ('
            '      PARTITION BY agent_id ORDER BY created_at DESC, id DESC'
            '    ) AS rank FROM agent_entities '
            '    WHERE type = ?2 AND subtype = ?3 '
            '  ) WHERE rank <= ?4 '
            ')) LIMIT ?5',
            variables: [
              const Variable<String>(r'$.contentEntryId'),
              const Variable<String>(AgentEntityTypes.agentMessage),
              Variable<String>(observationSubtype),
              Variable<int>(keepPerAgent),
              Variable<int>(batchSize),
              Variable<DateTime>(cutoff),
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
      // `_appendMessage` writes a `message_prev` link for every observation
      // once the agent has a head. Leaving those behind would keep the link
      // table growing exactly as the entity table stopped, and would leave the
      // fork projection walking edges whose parents no longer exist.
      await _deleteLinksTouching([...messageIds, ...payloadIds]);
      return _deleteByIds(messageIds);
    }),
  );

  /// Removes every link with a pruned entity at either end.
  Future<void> _deleteLinksTouching(List<String> ids) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await _db.customUpdate(
      'DELETE FROM agent_links '
      'WHERE from_id IN ($placeholders) OR to_id IN ($placeholders)',
      variables: [
        for (final id in [...ids, ...ids]) Variable<String>(id),
      ],
      updateKind: UpdateKind.delete,
    );
  }

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
