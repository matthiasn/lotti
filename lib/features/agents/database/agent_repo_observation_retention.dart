import 'package:drift/drift.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repo_retention.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/service/observation_prune_plan.dart';

/// One thread's worth of pruning, and what it removed.
class ObservationSweepResult {
  const ObservationSweepResult({
    required this.messageIds,
    required this.linkIds,
  });

  const ObservationSweepResult.empty()
    : messageIds = const [],
      linkIds = const [];

  /// Message rows deleted — returned so the caller can reclaim their JSON
  /// sidecars, which the database row is only half of.
  final List<String> messageIds;

  /// Link rows deleted, for the same reason.
  final List<String> linkIds;

  bool get isEmpty => messageIds.isEmpty && linkIds.isEmpty;
}

/// Prunes aged observations out of an agent's `messagePrev` log.
///
/// The decision of *what* may go is [planObservationPrune]'s, and lives apart
/// from the SQL so its invariants are testable without a database. This class
/// only supplies the thread's shape and executes the plan.
///
/// **Why the links go too.** `fork_healer` gates healing on
/// `danglingParentIds.isEmpty`. If a surviving message kept a `messagePrev`
/// edge to a pruned parent, the projection would report a permanent dangling
/// parent, healing would switch off for good, and the agent's context would
/// stop being bounded — the opposite of what retention is for. Deleting every
/// `messagePrev` edge that points *into* the pruned set leaves the oldest
/// survivor as a parentless root instead, which the projection reads as a
/// perfectly ordinary start of a log.
///
/// Because the plan is ancestor-closed, an edge whose *child* is pruned always
/// has a pruned parent too, so `to_id IN (pruned)` covers both the edges inside
/// the set and the one edge crossing its boundary.
///
/// **Payloads are not touched.** A payload is content-addressed and shared
/// through `messagePayload` links — it is user content that several messages
/// may reference, so deleting it with one of them destroys material the user
/// still has elsewhere. Only the pruned message's own edge to it is removed.
class AgentRepoObservationRetention {
  AgentRepoObservationRetention(this._db);

  final AgentDatabase _db;

  /// Host-parameter budget per statement; SQLite's default cap is 999.
  static const _maxVariablesPerStatement = 400;

  /// Agents holding at least one observation older than [cutoff], in id
  /// order, starting after [afterAgentId] and capped at [limit].
  ///
  /// The cursor is what stops a sweep starving: without it the same ordered
  /// prefix comes back every start, so one agent that cannot be pruned — its
  /// log too long to read, or its aged observations blocked — would hide every
  /// agent behind it forever.
  Future<List<String>> agentsWithAgedObservations(
    DateTime cutoff, {
    required int limit,
    String? afterAgentId,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT agent_id FROM agent_entities '
          'WHERE type = ?1 AND subtype = ?2 AND created_at < ?3 '
          'AND deleted_at IS NULL '
          '${afterAgentId == null ? '' : 'AND agent_id > ?5 '}'
          'ORDER BY agent_id LIMIT ?4',
          variables: [
            const Variable<String>(AgentEntityTypes.agentMessage),
            const Variable<String>(_observationSubtype),
            Variable<DateTime>(cutoff),
            Variable<int>(limit),
            if (afterAgentId != null) Variable<String>(afterAgentId),
          ],
          readsFrom: {_db.agentEntities},
        )
        .get();
    return [for (final row in rows) row.read<String>('agent_id')];
  }

  /// Prunes one **agent's whole message log**, returning what it deleted.
  ///
  /// Deliberately not per thread. `recentHeadMessageId` is per agent and
  /// `AgentSyncService._appendMessage` chains each wake's first message off
  /// the previous wake's tip — the sync service goes out of its way to stop a
  /// stale head forking the DAG "at the wake boundary" — so a `messagePrev`
  /// chain crosses thread ids. A per-thread slice would read a cross-thread
  /// parent as absent and prune its child, manufacturing exactly the fork
  /// ancestor-closure exists to prevent.
  ///
  /// [maxMessages] bounds the read; a log longer than it is left for a later
  /// sweep rather than partially reasoned about, since a truncated view hides
  /// the parents that block a delete.
  ///
  /// **The read, the plan and the delete share one transaction.** Inbound sync
  /// is wired before this start-up sweep, so an `AgentStateEntity` carrying a
  /// new `recentHeadMessageId` can land between reading the protected ids and
  /// running the delete — and that head may be a row the plan is about to
  /// take, leaving live state pointing at nothing.
  Future<ObservationSweepResult> pruneAgent({
    required String agentId,
    required DateTime cutoff,
    required int limit,
    required int maxMessages,
  }) => _db.transaction(() async {
    final rows = await _db
        .customSelect(
          'SELECT id, subtype, created_at, '
          r"json_extract(serialized, '$.prevMessageId') AS prev_message_id "
          'FROM agent_entities WHERE agent_id = ?1 AND type = ?2 '
          'AND deleted_at IS NULL ORDER BY created_at, id LIMIT ?3',
          variables: [
            Variable<String>(agentId),
            const Variable<String>(AgentEntityTypes.agentMessage),
            Variable<int>(maxMessages + 1),
          ],
          readsFrom: {_db.agentEntities},
        )
        .get();
    if (rows.isEmpty || rows.length > maxMessages) {
      return const ObservationSweepResult.empty();
    }

    final ids = [for (final row in rows) row.read<String>('id')];
    final parents = await _messagePrevParents(ids);
    // `prevMessageId` is kept *apart* from the link rows rather than unioned
    // into them: the two are different evidence. See `PrunableMessage`.
    final hints = <String, List<String>>{};
    for (final row in rows) {
      final prev = row.readNullable<String>('prev_message_id');
      if (prev == null) continue;
      final id = row.read<String>('id');
      if (parents[id]?.contains(prev) ?? false) continue;
      hints.putIfAbsent(id, () => []).add(prev);
    }
    final protectedIds = await _protectedMessageIds(agentId);
    if (protectedIds.isEmpty) {
      // No live head to protect means either this agent has no state row yet
      // or sync has not delivered one. Pruning now can delete the whole chain
      // including its tip, and a later state update would install
      // `recentHeadMessageId` for a row that no longer exists — a dangling
      // head `_appendMessage` would then chain off.
      return const ObservationSweepResult.empty();
    }

    final plan = planObservationPrune(
      messages: [
        for (final row in rows)
          PrunableMessage(
            id: row.read<String>('id'),
            createdAt: row.read<DateTime>('created_at'),
            isObservation:
                row.readNullable<String>('subtype') == _observationSubtype,
            parentIds: parents[row.read<String>('id')] ?? const [],
            hintedParentIds: hints[row.read<String>('id')] ?? const [],
          ),
      ],
      cutoff: cutoff,
      protectedIds: protectedIds,
      limit: limit,
    );
    if (plan.isEmpty) return const ObservationSweepResult.empty();

    final linkIds = await _deleteLinksInto(plan.messageIds);
    await _deleteEntities(plan.messageIds);
    return ObservationSweepResult(
      messageIds: plan.messageIds,
      linkIds: linkIds,
    );
  });

  /// `messagePrev` edges run child → parent, so `from_id` is the child.
  Future<Map<String, List<String>>> _messagePrevParents(
    List<String> messageIds,
  ) async {
    final parents = <String, List<String>>{};
    for (final chunk in chunkForStatement(
      messageIds,
      _maxVariablesPerStatement,
    )) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await _db
          .customSelect(
            'SELECT from_id, to_id FROM agent_links '
            "WHERE type = '${AgentLinkTypes.messagePrev}' "
            'AND deleted_at IS NULL AND from_id IN ($placeholders)',
            variables: [for (final id in chunk) Variable<String>(id)],
            readsFrom: {_db.agentLinks},
          )
          .get();
      for (final row in rows) {
        parents
            .putIfAbsent(row.read<String>('from_id'), () => <String>[])
            .add(row.read<String>('to_id'));
      }
    }
    return parents;
  }

  /// Message ids live state points at, which must outlive any sweep.
  Future<Set<String>> _protectedMessageIds(String agentId) async {
    final rows = await _db
        .customSelect(
          r"SELECT json_extract(serialized, '$.recentHeadMessageId') AS head, "
          r"json_extract(serialized, '$.latestSummaryMessageId') AS summary "
          'FROM agent_entities WHERE agent_id = ?1 AND type = ?2 '
          'AND deleted_at IS NULL',
          variables: [
            Variable<String>(agentId),
            const Variable<String>(AgentEntityTypes.agentState),
          ],
          readsFrom: {_db.agentEntities},
        )
        .get();
    return {
      for (final row in rows)
        ...[
          row.readNullable<String>('head'),
          row.readNullable<String>('summary'),
        ].nonNulls,
    };
  }

  /// Deletes every `messagePrev` edge pointing into [prunedIds], plus the
  /// pruned messages' own `messagePayload` edges (the payload rows themselves
  /// are shared content and stay).
  Future<List<String>> _deleteLinksInto(List<String> prunedIds) async {
    final linkIds = <String>[];
    for (final chunk in chunkForStatement(
      prunedIds,
      _maxVariablesPerStatement,
    )) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await _db
          .customSelect(
            'SELECT id FROM agent_links WHERE '
            "(type = '${AgentLinkTypes.messagePrev}' AND to_id IN ($placeholders)) "
            "OR (type = '${AgentLinkTypes.messagePayload}' "
            'AND from_id IN ($placeholders))',
            variables: [
              for (var pass = 0; pass < 2; pass++)
                for (final id in chunk) Variable<String>(id),
            ],
            readsFrom: {_db.agentLinks},
          )
          .get();
      linkIds.addAll([for (final row in rows) row.read<String>('id')]);
    }
    for (final chunk in chunkForStatement(linkIds, _maxVariablesPerStatement)) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      await _db.customUpdate(
        'DELETE FROM agent_links WHERE id IN ($placeholders)',
        variables: [for (final id in chunk) Variable<String>(id)],
        updateKind: UpdateKind.delete,
      );
    }
    return linkIds;
  }

  Future<void> _deleteEntities(List<String> ids) async {
    for (final chunk in chunkForStatement(ids, _maxVariablesPerStatement)) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      await _db.customUpdate(
        'DELETE FROM agent_entities WHERE id IN ($placeholders)',
        variables: [for (final id in chunk) Variable<String>(id)],
        updateKind: UpdateKind.delete,
      );
    }
  }
}

const _observationSubtype = 'observation';
