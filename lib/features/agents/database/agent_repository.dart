import 'package:drift/drift.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_db_conversions.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;

/// Typed CRUD repository wrapping [AgentDatabase] and [AgentDbConversions].
///
/// All entity reads go through [AgentDbConversions.fromEntityRow] and all
/// entity writes go through [AgentDbConversions.toEntityCompanion]. Link reads
/// go through [AgentDbConversions.fromLinkRow] and link writes go through
/// [AgentDbConversions.toLinkCompanion].
///
/// Wake-run log and saga log rows are plain Drift data classes and are read
/// and written directly without an intermediate domain conversion.
class AgentRepository {
  AgentRepository(this._db);

  final AgentDatabase _db;

  // ── Entity CRUD ────────────────────────────────────────────────────────────

  /// Insert or replace an [AgentDomainEntity] using the `id` as the conflict
  /// target (ON CONFLICT REPLACE semantics via [InsertMode.insertOrReplace]).
  Future<void> upsertEntity(AgentDomainEntity entity) async {
    final companion = AgentDbConversions.toEntityCompanion(entity);
    await _db.into(_db.agentEntities).insertOnConflictUpdate(companion);
  }

  /// Fetch a single entity by its [id], or `null` if not found.
  Future<AgentDomainEntity?> getEntity(String id) async {
    final rows = await _db.getAgentEntityById(id).get();
    if (rows.isEmpty) return null;
    return AgentDbConversions.fromEntityRow(rows.first);
  }

  /// Fetch all non-deleted entities for [agentId], optionally filtered by
  /// [type] (the string value stored in the `type` column, e.g. `'agentMessage'`).
  Future<List<AgentDomainEntity>> getEntitiesByAgentId(
    String agentId, {
    String? type,
  }) async {
    final List<AgentEntity> rows;
    if (type != null) {
      rows = await _db.getAgentEntitiesByType(agentId, type).get();
    } else {
      rows = await _db.getAgentEntitiesByAgentId(agentId).get();
    }
    return rows.map(AgentDbConversions.fromEntityRow).toList();
  }

  /// Fetch the latest [AgentStateEntity] for [agentId], or `null` if none
  /// exists.
  ///
  /// Queries by `type = 'agentState'` and casts the first result.
  Future<AgentStateEntity?> getAgentState(String agentId) async {
    final rows = await _db.getAgentEntitiesByType(agentId, 'agentState').get();
    if (rows.isEmpty) return null;
    final entity = AgentDbConversions.fromEntityRow(rows.first);
    return entity.mapOrNull(agentState: (e) => e);
  }

  /// Fetch messages for [agentId] filtered by [kind], optionally capped at
  /// [limit] rows (most-recent first).
  Future<List<AgentMessageEntity>> getMessagesByKind(
    String agentId,
    AgentMessageKind kind, {
    int? limit,
  }) async {
    final List<AgentEntity> rows;
    if (limit != null) {
      rows = await _db
          .getAgentEntitiesByTypeAndSubtype(
            agentId,
            'agentMessage',
            kind.name,
            limit,
          )
          .get();
    } else {
      rows = await _db
          .getAgentEntitiesByTypeAndSubtype(
            agentId,
            'agentMessage',
            kind.name,
            // SQLite does not accept NULL for LIMIT in this query; use a large
            // sentinel to mean "all rows".
            0x7FFFFFFF,
          )
          .get();
    }
    return rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<AgentMessageEntity>()
        .toList();
  }

  /// Fetch messages for [agentId] in a specific [threadId], optionally capped
  /// at [limit] rows (most-recent first).
  Future<List<AgentMessageEntity>> getMessagesForThread(
    String agentId,
    String threadId, {
    int? limit,
  }) async {
    // The drift named queries do not expose a thread-id filter directly, so
    // fall back to a type-filtered fetch and filter in Dart.
    final rows =
        await _db.getAgentEntitiesByType(agentId, 'agentMessage').get();
    final messages = rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<AgentMessageEntity>()
        .where((m) => m.threadId == threadId)
        .toList();
    if (limit != null && messages.length > limit) {
      return messages.take(limit).toList();
    }
    return messages;
  }

  /// Fetch the latest [AgentReportEntity] for [agentId] in [scope], or `null`
  /// if none exists.
  ///
  /// First resolves the report-head pointer, then fetches the actual report by
  /// its ID.
  Future<AgentReportEntity?> getLatestReport(
    String agentId,
    String scope,
  ) async {
    final head = await getReportHead(agentId, scope);
    if (head == null) return null;

    final entity = await getEntity(head.reportId);
    return entity?.mapOrNull(agentReport: (e) => e);
  }

  /// Fetch the [AgentReportHeadEntity] for [agentId] in [scope], or `null` if
  /// none exists.
  Future<AgentReportHeadEntity?> getReportHead(
    String agentId,
    String scope,
  ) async {
    final rows =
        await _db.getAgentEntitiesByType(agentId, 'agentReportHead').get();
    for (final row in rows) {
      final entity = AgentDbConversions.fromEntityRow(row);
      final head = entity.mapOrNull(agentReportHead: (e) => e);
      if (head != null && head.scope == scope) return head;
    }
    return null;
  }

  /// Fetch all agent identity entities (type = 'agent'), excluding deleted.
  ///
  /// Returns all agents regardless of their lifecycle state.
  Future<List<AgentIdentityEntity>> getAllAgentIdentities() async {
    final rows = await _db.getAllAgentIdentities().get();
    return rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<AgentIdentityEntity>()
        .toList();
  }

  // ── Link CRUD ──────────────────────────────────────────────────────────────

  /// Insert or replace a link using the unique `(from_id, to_id, type)`
  /// constraint.
  Future<void> upsertLink(model.AgentLink link) async {
    final companion = AgentDbConversions.toLinkCompanion(link);
    await _db.into(_db.agentLinks).insertOnConflictUpdate(companion);
  }

  /// Fetch non-deleted links originating from [fromId], optionally filtered
  /// by [type] (the string stored in the `agent_links.type` column, e.g.
  /// `'agent_state'`).
  Future<List<model.AgentLink>> getLinksFrom(
    String fromId, {
    String? type,
  }) async {
    final List<AgentLink> rows;
    if (type != null) {
      rows = await _db.getAgentLinksByFromIdAndType(fromId, type).get();
    } else {
      rows = await _db.getAgentLinksByFromId(fromId).get();
    }
    return rows.map(AgentDbConversions.fromLinkRow).toList();
  }

  /// Fetch non-deleted links pointing to [toId], optionally filtered by
  /// [type].
  Future<List<model.AgentLink>> getLinksTo(
    String toId, {
    String? type,
  }) async {
    final List<AgentLink> rows;
    if (type != null) {
      rows = await _db.getAgentLinksByToIdAndType(toId, type).get();
    } else {
      rows = await _db.getAgentLinksByToId(toId).get();
    }
    return rows.map(AgentDbConversions.fromLinkRow).toList();
  }

  // ── Wake run log ───────────────────────────────────────────────────────────

  /// Insert a new [WakeRunLogData] entry.
  Future<void> insertWakeRun({required WakeRunLogData entry}) async {
    await _db
        .into(_db.wakeRunLog)
        .insertOnConflictUpdate(entry.toCompanion(true));
  }

  /// Update the [status], and optionally [completedAt] and [errorMessage], for
  /// the wake run identified by [runKey].
  Future<void> updateWakeRunStatus(
    String runKey,
    String status, {
    DateTime? completedAt,
    String? errorMessage,
  }) async {
    await (_db.update(_db.wakeRunLog)..where((t) => t.runKey.equals(runKey)))
        .write(
      WakeRunLogCompanion(
        status: Value(status),
        completedAt:
            completedAt != null ? Value(completedAt) : const Value.absent(),
        errorMessage:
            errorMessage != null ? Value(errorMessage) : const Value.absent(),
      ),
    );
  }

  /// Fetch a single wake-run entry by [runKey], or `null` if not found.
  Future<WakeRunLogData?> getWakeRun(String runKey) async {
    final rows = await _db.getWakeRunByKey(runKey).get();
    if (rows.isEmpty) return null;
    return rows.first;
  }

  // ── Saga log ───────────────────────────────────────────────────────────────

  /// Insert a new [SagaLogData] entry.
  Future<void> insertSagaOp({required SagaLogData entry}) async {
    await _db.into(_db.sagaLog).insertOnConflictUpdate(entry.toCompanion(true));
  }

  /// Update the [status], and optionally [lastError], for the saga operation
  /// identified by [operationId].
  Future<void> updateSagaStatus(
    String operationId,
    String status, {
    String? lastError,
  }) async {
    await (_db.update(_db.sagaLog)
          ..where((t) => t.operationId.equals(operationId)))
        .write(
      SagaLogCompanion(
        status: Value(status),
        lastError: lastError != null ? Value(lastError) : const Value.absent(),
      ),
    );
  }

  /// Fetch all saga operations whose status is `'pending'`, ordered by
  /// [SagaLogData.createdAt] ascending.
  Future<List<SagaLogData>> getPendingSagaOps() async {
    return _db.getPendingSagaOps().get();
  }

  // ── Hard delete ─────────────────────────────────────────────────────────

  /// Permanently delete **all** data for [agentId]: entities, links, saga ops,
  /// and wake-run log entries.
  ///
  /// This is irreversible. Only call for agents whose lifecycle is
  /// [AgentLifecycle.destroyed].
  Future<void> hardDeleteAgent(String agentId) async {
    // Saga ops reference wake_run_log via run_key, so delete them first.
    await _db.deleteAgentSagaOps(agentId);
    await _db.deleteAgentWakeRuns(agentId);
    await _db.deleteAgentLinks(agentId);
    await _db.deleteAgentEntities(agentId);
  }
}
