import 'package:drift/drift.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_db_conversions.dart';
import 'package:lotti/features/agents/database/agent_repository_exception.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:sqlite3/sqlite3.dart' show SqliteException;

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

  /// Run [action] inside a database transaction.
  ///
  /// All operations within the callback are committed atomically; if any
  /// operation throws, the entire transaction is rolled back. Drift supports
  /// nested transactions via savepoints.
  Future<T> runInTransaction<T>(Future<T> Function() action) {
    return _db.transaction(action);
  }

  // ── Entity CRUD ────────────────────────────────────────────────────────────

  /// Insert or update an [AgentDomainEntity] using the `id` as the conflict
  /// target (ON CONFLICT DO UPDATE — updates supplied columns in place).
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

  /// Fetch non-deleted entities for [agentId], optionally filtered by [type]
  /// (the string value stored in the `type` column, e.g. `'agentMessage'`).
  ///
  /// Results are always sorted newest-first (`created_at DESC`). Pass [limit]
  /// to cap the number of rows returned (defaults to unlimited).
  Future<List<AgentDomainEntity>> getEntitiesByAgentId(
    String agentId, {
    String? type,
    int limit = -1,
  }) async {
    final List<AgentEntity> rows;
    if (type != null) {
      rows = await _db.getAgentEntitiesByType(agentId, type, limit).get();
    } else {
      rows = await _db.getAgentEntitiesByAgentId(agentId, limit).get();
    }
    return rows.map(AgentDbConversions.fromEntityRow).toList();
  }

  /// Fetch the latest [AgentStateEntity] for [agentId], or `null` if none
  /// exists.
  ///
  /// Queries by `type = 'agentState'` and casts the first result.
  Future<AgentStateEntity?> getAgentState(String agentId) async {
    final rows =
        await _db.getAgentEntitiesByType(agentId, 'agentState', 1).get();
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
    final rows = await _db
        .getAgentEntitiesByTypeAndSubtype(
          agentId,
          'agentMessage',
          kind.name,
          limit ?? -1,
        )
        .get();
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
    final rows = await _db
        .getAgentMessagesByThread(
          agentId,
          threadId,
          limit ?? -1,
        )
        .get();
    return rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<AgentMessageEntity>()
        .toList();
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
    final rows = await _db
        .getAgentEntitiesByTypeAndSubtype(agentId, 'agentReportHead', scope, 1)
        .get();
    if (rows.isEmpty) return null;
    final entity = AgentDbConversions.fromEntityRow(rows.first);
    return entity.mapOrNull(agentReportHead: (e) => e);
  }

  // ── Template queries ─────────────────────────────────────────────────────

  /// Fetch all non-deleted [AgentTemplateEntity] rows, newest first.
  Future<List<AgentTemplateEntity>> getAllTemplates() async {
    final rows = await _db.getAllAgentTemplates().get();
    return rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<AgentTemplateEntity>()
        .toList();
  }

  /// Fetch the [AgentTemplateHeadEntity] for [templateId], or `null` if none
  /// exists.
  Future<AgentTemplateHeadEntity?> getTemplateHead(String templateId) async {
    final rows = await _db
        .getAgentEntitiesByType(templateId, 'agentTemplateHead', 1)
        .get();
    if (rows.isEmpty) return null;
    final entity = AgentDbConversions.fromEntityRow(rows.first);
    return entity.mapOrNull(agentTemplateHead: (e) => e);
  }

  /// Resolve the active [AgentTemplateVersionEntity] for [templateId] by
  /// following the head pointer.
  ///
  /// Returns `null` if no head or no version entity is found.
  Future<AgentTemplateVersionEntity?> getActiveTemplateVersion(
    String templateId,
  ) async {
    final head = await getTemplateHead(templateId);
    if (head == null) return null;

    final entity = await getEntity(head.versionId);
    return entity?.mapOrNull(agentTemplateVersion: (e) => e);
  }

  /// Determine the next version number for a template.
  ///
  /// Returns 1 if no versions exist yet.
  Future<int> getNextTemplateVersionNumber(String templateId) async {
    final rows = await _db
        .getAgentEntitiesByType(templateId, 'agentTemplateVersion', -1)
        .get();
    if (rows.isEmpty) return 1;

    final versions = rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<AgentTemplateVersionEntity>()
        .map((v) => v.version);
    return versions.isEmpty ? 1 : versions.reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Update the template-related columns on a wake-run log entry.
  Future<void> updateWakeRunTemplate(
    String runKey,
    String templateId,
    String templateVersionId,
  ) async {
    await (_db.update(_db.wakeRunLog)..where((t) => t.runKey.equals(runKey)))
        .write(
      WakeRunLogCompanion(
        templateId: Value(templateId),
        templateVersionId: Value(templateVersionId),
      ),
    );
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

  /// Fetch all non-deleted agent entities, ordered by `created_at` ascending.
  ///
  /// Used by the maintenance sync step to enqueue all agent entities for
  /// cross-device synchronization.
  Future<List<AgentDomainEntity>> getAllEntities() async {
    final rows = await _db.getAllAgentEntities().get();
    return rows.map(AgentDbConversions.fromEntityRow).toList();
  }

  // ── Evolution queries ──────────────────────────────────────────────────────

  /// Fetch the N most recent reports from all instances assigned to
  /// [templateId] via `template_assignment` links.
  Future<List<AgentReportEntity>> getRecentReportsByTemplate(
    String templateId, {
    int limit = 10,
  }) async {
    final rows = await _db.getRecentReportsByTemplate(templateId, limit).get();
    return rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<AgentReportEntity>()
        .toList();
  }

  /// Fetch the N most recent observation messages from all instances assigned
  /// to [templateId] via `template_assignment` links.
  Future<List<AgentMessageEntity>> getRecentObservationsByTemplate(
    String templateId, {
    int limit = 10,
  }) async {
    final rows =
        await _db.getRecentObservationsByTemplate(templateId, limit).get();
    return rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<AgentMessageEntity>()
        .toList();
  }

  /// Fetch evolution sessions for [templateId], newest-first.
  Future<List<EvolutionSessionEntity>> getEvolutionSessions(
    String templateId, {
    int limit = 10,
  }) async {
    final rows =
        await _db.getEvolutionSessionsByTemplate(templateId, limit).get();
    return rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<EvolutionSessionEntity>()
        .toList();
  }

  /// Fetch evolution notes for [templateId], newest-first.
  Future<List<EvolutionNoteEntity>> getEvolutionNotes(
    String templateId, {
    int limit = 50,
  }) async {
    final rows =
        await _db.getEvolutionNotesByTemplate(templateId, limit).get();
    return rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<EvolutionNoteEntity>()
        .toList();
  }

  /// Count entities changed since [since] for instances of [templateId].
  ///
  /// Returns 0 if [since] is `null` (no previous acknowledgement).
  Future<int> countChangedSinceForTemplate(
    String templateId,
    DateTime? since,
  ) async {
    if (since == null) return 0;
    return _db
        .countEntitiesChangedSinceForTemplate(templateId, since)
        .getSingle();
  }

  /// Update the user rating on a wake-run log entry.
  Future<void> updateWakeRunRating(
    String runKey, {
    required double rating,
    required DateTime ratedAt,
  }) async {
    await (_db.update(_db.wakeRunLog)..where((t) => t.runKey.equals(runKey)))
        .write(
      WakeRunLogCompanion(
        userRating: Value(rating),
        ratedAt: Value(ratedAt),
      ),
    );
  }

  // ── Link CRUD ──────────────────────────────────────────────────────────────

  /// Insert or update a link using on-conflict update semantics against the
  /// primary key (`id`).
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

  /// Fetch all non-deleted agent links, ordered by `created_at` ascending.
  ///
  /// Used by the maintenance sync step to enqueue all agent links for
  /// cross-device synchronization.
  Future<List<model.AgentLink>> getAllLinks() async {
    final rows = await _db.getAllAgentLinks().get();
    return rows.map(AgentDbConversions.fromLinkRow).toList();
  }

  // ── Wake run log ───────────────────────────────────────────────────────────

  /// Insert a new [WakeRunLogData] entry.
  ///
  /// Throws [DuplicateInsertException] if the run key already exists.
  Future<void> insertWakeRun({required WakeRunLogData entry}) async {
    try {
      await _db.into(_db.wakeRunLog).insert(entry.toCompanion(true));
    } on SqliteException catch (e) {
      if (e.resultCode == 19) {
        throw DuplicateInsertException('wake_run_log', entry.runKey, e);
      }
      rethrow;
    }
  }

  /// Update the [status], and optionally [startedAt], [completedAt] and
  /// [errorMessage], for the wake run identified by [runKey].
  Future<void> updateWakeRunStatus(
    String runKey,
    String status, {
    DateTime? startedAt,
    DateTime? completedAt,
    String? errorMessage,
  }) async {
    await (_db.update(_db.wakeRunLog)..where((t) => t.runKey.equals(runKey)))
        .write(
      WakeRunLogCompanion(
        status: Value(status),
        startedAt: startedAt != null ? Value(startedAt) : const Value.absent(),
        completedAt:
            completedAt != null ? Value(completedAt) : const Value.absent(),
        errorMessage:
            errorMessage != null ? Value(errorMessage) : const Value.absent(),
      ),
    );
  }

  /// Fetch wake-run entries for a specific template, ordered by
  /// `created_at DESC`, capped at [limit] rows.
  Future<List<WakeRunLogData>> getWakeRunsForTemplate(
    String templateId, {
    int limit = 500,
  }) async {
    return _db.getWakeRunsByTemplateId(templateId, limit).get();
  }

  /// Fetch a single wake-run entry by [runKey], or `null` if not found.
  Future<WakeRunLogData?> getWakeRun(String runKey) async {
    final rows = await _db.getWakeRunByKey(runKey).get();
    if (rows.isEmpty) return null;
    return rows.first;
  }

  // ── Saga log ───────────────────────────────────────────────────────────────

  /// Insert a new [SagaLogData] entry.
  ///
  /// Throws [DuplicateInsertException] if the operation ID already exists.
  Future<void> insertSagaOp({required SagaLogData entry}) async {
    try {
      await _db.into(_db.sagaLog).insert(entry.toCompanion(true));
    } on SqliteException catch (e) {
      if (e.resultCode == 19) {
        throw DuplicateInsertException('saga_log', entry.operationId, e);
      }
      rethrow;
    }
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
    await _db.transaction(() async {
      // Saga ops reference wake_run_log via run_key, so delete them first.
      await _db.deleteAgentSagaOps(agentId);
      await _db.deleteAgentWakeRuns(agentId);
      await _db.deleteAgentLinks(agentId);
      await _db.deleteAgentEntities(agentId);
    });
  }
}
