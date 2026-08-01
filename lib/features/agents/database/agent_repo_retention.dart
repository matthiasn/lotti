import 'package:drift/drift.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';

/// Batched hard deletes for the derived rows retention may forget.
///
/// **Scope: day-status events.** Observations are classified as bounded (see
/// `AgentRetentionPolicy`) but are deliberately NOT swept here. They sit inside
/// the agent's causal message DAG — `message_prev` edges, agent-state heads,
/// and content-addressed payloads shared through `messagePayload` links — and
/// removing one safely means answering what happens to each of those, which is
/// a subsystem's worth of invariants rather than another `DELETE`. Day-status
/// events carry no such entanglement.
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

  /// Deletes day-status events created before [cutoff], **keeping the newest
  /// one per day**.
  ///
  /// The newest event is not residue: `dayAgentPersonaProvider` reads it to
  /// decide how a day is presented, so deleting every event for an old day
  /// silently changes what that day looks like when the user scrolls back.
  /// Keeping one row per day still turns an unbounded pile into a bounded
  /// one — the events are raised several times a day, and only the last is
  /// read after the digest has consumed them.
  Future<int> pruneDayStatusEventsBefore(
    DateTime cutoff, {
    required int batchSize,
    required int maxBatches,
  }) => _batched(
    maxBatches: maxBatches,
    run: () => _db.customUpdate(
      'DELETE FROM agent_entities WHERE id IN ( '
      'SELECT e.id FROM agent_entities AS e '
      'WHERE e.type = ?1 AND e.created_at < ?2 '
      'AND EXISTS ( '
      '  SELECT 1 FROM agent_entities AS newer '
      '  WHERE newer.type = ?1 AND newer.subtype = e.subtype '
      '  AND (newer.created_at > e.created_at '
      '       OR (newer.created_at = e.created_at AND newer.id > e.id)) '
      ') LIMIT ?3)',
      variables: [
        const Variable<String>(AgentEntityTypes.dayStatusEvent),
        Variable<DateTime>(cutoff),
        Variable<int>(batchSize),
      ],
      updateKind: UpdateKind.delete,
    ),
  );

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
