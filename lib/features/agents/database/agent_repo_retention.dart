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

  /// Deletes message payloads older than [cutoff] that no message owns.
  ///
  /// A payload syncs as an entity in its own right, so a peer replaying an
  /// expired observation delivers the payload and the message as separate
  /// messages. The ingest guard drops the expired *message*, and the payload —
  /// which carries no timestamp relationship to any message the receiver can
  /// see — is materialized on its own. Nothing would ever collect it again,
  /// because the sweep finds payloads through their owning message's
  /// `contentEntryId`.
  ///
  /// Bounded by the same age as observations and by ownership, so a payload
  /// belonging to a live message of any kind is never touched.
  Future<int> pruneOrphanedPayloadsBefore(
    DateTime cutoff, {
    required int batchSize,
    required int maxBatches,
  }) => _batched(
    maxBatches: maxBatches,
    run: () => _db.customUpdate(
      'DELETE FROM agent_entities WHERE id IN ( '
      'SELECT p.id FROM agent_entities AS p '
      'WHERE p.type = ?1 AND p.created_at < ?2 '
      'AND NOT EXISTS ('
      '  SELECT 1 FROM agent_entities AS m '
      '  WHERE m.type = ?3 '
      '  AND json_extract(m.serialized, ?4) = p.id '
      ') LIMIT ?5)',
      variables: [
        const Variable<String>('agentMessagePayload'),
        Variable<DateTime>(cutoff),
        const Variable<String>(AgentEntityTypes.agentMessage),
        const Variable<String>(r'$.contentEntryId'),
        Variable<int>(batchSize),
      ],
      updateKind: UpdateKind.delete,
    ),
  );

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

  /// Host-parameter budget per statement.
  ///
  /// SQLite's default cap is 999. A full batch of observations is already two
  /// ids each (message + payload), and the link predicate binds its list
  /// twice — so an unchunked statement can reach ~2,000 parameters, throw, and
  /// roll back the whole transaction. Every start-up would then retry the same
  /// batch and retention would never make progress, which is worse than not
  /// sweeping at all.
  static const _maxVariablesPerStatement = 400;

  /// Removes every link with a pruned entity at either end.
  Future<void> _deleteLinksTouching(List<String> ids) async {
    // Halved again because this predicate binds its chunk twice.
    for (final chunk in _chunked(ids, _maxVariablesPerStatement ~/ 2)) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      await _db.customUpdate(
        'DELETE FROM agent_links '
        'WHERE from_id IN ($placeholders) OR to_id IN ($placeholders)',
        variables: [
          for (final id in [...chunk, ...chunk]) Variable<String>(id),
        ],
        updateKind: UpdateKind.delete,
      );
    }
  }

  Future<int> _deleteByIds(List<String> ids) async {
    var deleted = 0;
    for (final chunk in _chunked(ids, _maxVariablesPerStatement)) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      deleted += await _db.customUpdate(
        'DELETE FROM agent_entities WHERE id IN ($placeholders)',
        variables: [for (final id in chunk) Variable<String>(id)],
        updateKind: UpdateKind.delete,
      );
    }
    return deleted;
  }

  static Iterable<List<String>> _chunked(List<String> ids, int size) sync* {
    for (var start = 0; start < ids.length; start += size) {
      yield ids.sublist(
        start,
        start + size > ids.length ? ids.length : start + size,
      );
    }
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
