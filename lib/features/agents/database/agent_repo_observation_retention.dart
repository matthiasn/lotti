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

  /// Threads carrying at least one observation older than [cutoff], oldest
  /// first, capped at [limit].
  Future<List<({String agentId, String threadId})>> threadsWithAgedObservations(
    DateTime cutoff, {
    required int limit,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT agent_id, thread_id FROM agent_entities '
          'WHERE type = ?1 AND subtype = ?2 AND created_at < ?3 '
          'AND deleted_at IS NULL AND thread_id IS NOT NULL '
          'ORDER BY agent_id, thread_id LIMIT ?4',
          variables: [
            const Variable<String>(AgentEntityTypes.agentMessage),
            const Variable<String>(_observationSubtype),
            Variable<DateTime>(cutoff),
            Variable<int>(limit),
          ],
          readsFrom: {_db.agentEntities},
        )
        .get();
    return [
      for (final row in rows)
        (
          agentId: row.read<String>('agent_id'),
          threadId: row.read<String>('thread_id'),
        ),
    ];
  }

  /// Prunes one thread, returning what it deleted.
  ///
  /// The whole thread's message list is loaded because ancestor-closure is a
  /// property of the chain from its root, not of any one row — a query that
  /// selected only aged rows could not tell a prunable prefix from a prunable
  /// middle. [maxMessages] bounds that read; a thread longer than it is left
  /// for a later sweep rather than partially reasoned about, since a truncated
  /// view would hide the parents that block a delete.
  Future<ObservationSweepResult> pruneThread({
    required String agentId,
    required String threadId,
    required DateTime cutoff,
    required int limit,
    required int maxMessages,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT id, subtype, created_at FROM agent_entities '
          'WHERE agent_id = ?1 AND thread_id = ?2 AND type = ?3 '
          'AND deleted_at IS NULL ORDER BY created_at, id LIMIT ?4',
          variables: [
            Variable<String>(agentId),
            Variable<String>(threadId),
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
    final plan = planObservationPrune(
      messages: [
        for (final row in rows)
          PrunableMessage(
            id: row.read<String>('id'),
            createdAt: row.read<DateTime>('created_at'),
            isObservation:
                row.readNullable<String>('subtype') == _observationSubtype,
            parentIds: parents[row.read<String>('id')] ?? const [],
          ),
      ],
      cutoff: cutoff,
      protectedIds: await _protectedMessageIds(agentId),
      limit: limit,
    );
    if (plan.isEmpty) return const ObservationSweepResult.empty();

    return _db.transaction(() async {
      final linkIds = await _deleteLinksInto(plan.messageIds);
      await _deleteEntities(plan.messageIds);
      return ObservationSweepResult(
        messageIds: plan.messageIds,
        linkIds: linkIds,
      );
    });
  }

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
