import 'package:drift/drift.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_db_conversions.dart';
import 'package:lotti/features/agents/database/agent_repository_exception.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
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

  /// Multiplier for SQL LIMIT when post-query Dart filtering is applied.
  /// Over-fetching compensates for rows discarded during in-memory filtering.
  static const _overFetchMultiplier = 5;

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
    final rows = await _db
        .getAgentEntitiesByType(agentId, AgentEntityTypes.agentState, 1)
        .get();
    if (rows.isEmpty) return null;
    final entity = AgentDbConversions.fromEntityRow(rows.first);
    return entity.mapOrNull(agentState: (e) => e);
  }

  /// Batch-fetch the latest [AgentStateEntity] for each agent in [agentIds].
  ///
  /// Issues a single SQL query ordered newest-first, then keeps the first
  /// state row seen per `agentId`. Agents without a state are omitted.
  Future<Map<String, AgentStateEntity>> getAgentStatesByAgentIds(
    List<String> agentIds,
  ) async {
    if (agentIds.isEmpty) return {};

    final placeholders = List.filled(agentIds.length, '?').join(', ');
    final rows = await _db
        .customSelect(
          'SELECT * FROM agent_entities '
          'WHERE agent_id IN ($placeholders) '
          "AND type = '${AgentEntityTypes.agentState}' "
          'AND deleted_at IS NULL '
          'ORDER BY created_at DESC',
          variables: agentIds.map(Variable.withString).toList(),
          readsFrom: {_db.agentEntities},
        )
        .get();

    final statesByAgentId = <String, AgentStateEntity>{};
    for (final row in rows) {
      final entity = AgentDbConversions.fromEntityRow(
        await _db.agentEntities.mapFromRow(row),
      );
      final state = entity.mapOrNull(agentState: (e) => e);
      if (state != null) {
        statesByAgentId.putIfAbsent(state.agentId, () => state);
      }
    }

    return statesByAgentId;
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
          AgentEntityTypes.agentMessage,
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

  /// Batch-fetch the latest report for each agent in [agentIds] under [scope].
  ///
  /// Issues two SQL queries (one for heads, one for reports) instead of 2N
  /// individual lookups. Agents without a report are omitted from the result.
  Future<Map<String, AgentReportEntity>> getLatestReportsByAgentIds(
    List<String> agentIds,
    String scope,
  ) async {
    if (agentIds.isEmpty) return {};

    // 1. Batch-fetch report heads.
    final headPlaceholders = List.filled(agentIds.length, '?').join(', ');
    final headRows = await _db
        .customSelect(
          'SELECT * FROM agent_entities '
          'WHERE agent_id IN ($headPlaceholders) '
          "AND type = '${AgentEntityTypes.agentReportHead}' "
          'AND subtype = ? '
          'AND deleted_at IS NULL '
          'ORDER BY created_at DESC',
          variables: [
            ...agentIds.map(Variable.withString),
            Variable.withString(scope),
          ],
          readsFrom: {_db.agentEntities},
        )
        .get();

    // Map agent_id → report head → reportId.
    final reportIdsByAgentId = <String, String>{};
    final allReportIds = <String>{};
    for (final row in headRows) {
      final entity = AgentDbConversions.fromEntityRow(
        await _db.agentEntities.mapFromRow(row),
      );
      final head = entity.mapOrNull(agentReportHead: (e) => e);
      if (head != null) {
        reportIdsByAgentId.putIfAbsent(head.agentId, () {
          allReportIds.add(head.reportId);
          return head.reportId;
        });
      }
    }

    if (allReportIds.isEmpty) return {};

    // 2. Batch-fetch the actual report entities.
    final reportPlaceholders = List.filled(allReportIds.length, '?').join(', ');
    final reportRows = await _db
        .customSelect(
          'SELECT * FROM agent_entities '
          'WHERE id IN ($reportPlaceholders) AND deleted_at IS NULL',
          variables: allReportIds.map(Variable.withString).toList(),
          readsFrom: {_db.agentEntities},
        )
        .get();

    final reportsById = <String, AgentReportEntity>{};
    for (final row in reportRows) {
      final entity = AgentDbConversions.fromEntityRow(
        await _db.agentEntities.mapFromRow(row),
      );
      final report = entity.mapOrNull(agentReport: (e) => e);
      if (report != null) {
        reportsById[report.id] = report;
      }
    }

    // 3. Assemble agent_id → report map.
    final result = <String, AgentReportEntity>{};
    for (final entry in reportIdsByAgentId.entries) {
      final report = reportsById[entry.value];
      if (report != null) {
        result[entry.key] = report;
      }
    }
    return result;
  }

  /// Fetch the latest usable current-scope project report for [projectId].
  ///
  /// A project can have multiple historical `agent_project` links. The newest
  /// link wins, using the shared primary-selection order (`createdAt DESC`,
  /// then `id DESC`). If that linked agent has no current report or its report
  /// body is empty, older linked project agents are tried in order.
  Future<AgentReportEntity?> getLatestProjectReportForProjectId(
    String projectId,
  ) async {
    final links = (await getLinksTo(
      projectId,
      type: AgentLinkTypes.agentProject,
    )).orderedPrimaryFirst();

    for (final link in links) {
      final report = await getLatestReport(
        link.fromId,
        AgentReportScopes.current,
      );
      if (report != null && report.content.trim().isNotEmpty) {
        return report;
      }
    }

    return null;
  }

  /// Batch-fetch the latest current-scope task-agent report for each task in
  /// [taskIds], keyed by journal task ID.
  ///
  /// The task selection path is:
  /// 1. batch-resolve all `agent_task` links for the task IDs
  /// 2. pick the primary link per task using the shared canonical ordering
  /// 3. batch-fetch the current report for those agent IDs
  ///
  /// Tasks without an assigned agent or current report are omitted.
  Future<Map<String, AgentReportEntity>> getLatestTaskReportsForTaskIds(
    List<String> taskIds,
  ) async {
    if (taskIds.isEmpty) return {};

    final linksByTaskId = await getLinksToMultiple(
      taskIds,
      type: AgentLinkTypes.agentTask,
    );

    final agentIdsByTaskId = <String, String>{};
    final agentIds = <String>{};

    for (final entry in linksByTaskId.entries) {
      final links = entry.value;
      if (links.isEmpty) {
        continue;
      }

      final primaryLink = links.selectPrimary();
      agentIdsByTaskId[entry.key] = primaryLink.fromId;
      agentIds.add(primaryLink.fromId);
    }

    if (agentIds.isEmpty) return {};

    final reportsByAgentId = await getLatestReportsByAgentIds(
      agentIds.toList(),
      AgentReportScopes.current,
    );

    final result = <String, AgentReportEntity>{};
    for (final entry in agentIdsByTaskId.entries) {
      final report = reportsByAgentId[entry.value];
      if (report != null) {
        result[entry.key] = report;
      }
    }

    return result;
  }

  /// Fetch the [AgentReportHeadEntity] for [agentId] in [scope], or `null` if
  /// none exists.
  Future<AgentReportHeadEntity?> getReportHead(
    String agentId,
    String scope,
  ) async {
    final rows = await _db
        .getAgentEntitiesByTypeAndSubtype(
          agentId,
          AgentEntityTypes.agentReportHead,
          scope,
          1,
        )
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
        .getAgentEntitiesByType(
          templateId,
          AgentEntityTypes.agentTemplateHead,
          1,
        )
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
        .getAgentEntitiesByType(
          templateId,
          AgentEntityTypes.agentTemplateVersion,
          -1,
        )
        .get();
    if (rows.isEmpty) return 1;

    final versions = rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<AgentTemplateVersionEntity>()
        .map((v) => v.version);
    return versions.isEmpty ? 1 : versions.reduce((a, b) => a > b ? a : b) + 1;
  }

  // ── soul document ──────────────────────────────────────────────────────

  /// Fetch a [SoulDocumentEntity] by its ID.
  ///
  /// Returns `null` if no entity with [soulId] exists or if it is not a
  /// soul document.
  Future<SoulDocumentEntity?> getSoulDocument(String soulId) async {
    final entity = await getEntity(soulId);
    return entity?.mapOrNull(soulDocument: (e) => e);
  }

  /// Fetch all [SoulDocumentEntity] records (the soul palette).
  Future<List<SoulDocumentEntity>> getAllSoulDocuments() async {
    final rows = await _db
        .getAgentEntitiesByTypeGlobal(AgentEntityTypes.soulDocument)
        .get();
    return rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<SoulDocumentEntity>()
        .toList();
  }

  /// Fetch the [SoulDocumentHeadEntity] for [soulId].
  ///
  /// Returns `null` if no head pointer exists for the given soul.
  Future<SoulDocumentHeadEntity?> getSoulDocumentHead(String soulId) async {
    final rows = await _db
        .getAgentEntitiesByType(
          soulId,
          AgentEntityTypes.soulDocumentHead,
          1,
        )
        .get();
    if (rows.isEmpty) return null;
    final entity = AgentDbConversions.fromEntityRow(rows.first);
    return entity.mapOrNull(soulDocumentHead: (e) => e);
  }

  /// Resolve the active [SoulDocumentVersionEntity] for [soulId] by following
  /// the head pointer.
  ///
  /// Returns `null` if no head or no version entity is found.
  Future<SoulDocumentVersionEntity?> getActiveSoulDocumentVersion(
    String soulId,
  ) async {
    final head = await getSoulDocumentHead(soulId);
    if (head == null) return null;

    final entity = await getEntity(head.versionId);
    return entity?.mapOrNull(soulDocumentVersion: (e) => e);
  }

  /// Fetch version history for a soul document, newest first.
  Future<List<SoulDocumentVersionEntity>> getSoulDocumentVersions(
    String soulId, {
    int limit = -1,
  }) async {
    final rows = await _db
        .getAgentEntitiesByType(
          soulId,
          AgentEntityTypes.soulDocumentVersion,
          limit,
        )
        .get();
    return rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<SoulDocumentVersionEntity>()
        .toList();
  }

  /// Determine the next version number for a soul document.
  ///
  /// Returns 1 if no versions exist yet.
  ///
  /// Note: this uses local `max + 1`, matching the template version pattern
  /// ([getNextTemplateVersionNumber]). On concurrent multi-device writes the
  /// version number may collide, but entity IDs remain globally unique via
  /// UUID. The version number is a display hint, not a uniqueness key.
  Future<int> getNextSoulDocumentVersionNumber(String soulId) async {
    final rows = await _db
        .getAgentEntitiesByType(
          soulId,
          AgentEntityTypes.soulDocumentVersion,
          -1,
        )
        .get();
    if (rows.isEmpty) return 1;

    final versions = rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<SoulDocumentVersionEntity>()
        .map((v) => v.version);
    return versions.isEmpty ? 1 : versions.reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Update the template-related columns on a wake-run log entry.
  ///
  /// When [resolvedModelId] is provided, it is persisted alongside the
  /// template provenance so that `modelIdForThread` can return the actual
  /// model used even for failed/incomplete wakes.
  ///
  /// When [soulId] and [soulVersionId] are provided, soul provenance is
  /// recorded alongside the template provenance.
  Future<void> updateWakeRunTemplate(
    String runKey,
    String templateId,
    String templateVersionId, {
    String? resolvedModelId,
    String? soulId,
    String? soulVersionId,
  }) async {
    final updatedRows =
        await (_db.update(
          _db.wakeRunLog,
        )..where((t) => t.runKey.equals(runKey))).write(
          WakeRunLogCompanion(
            templateId: Value(templateId),
            templateVersionId: Value(templateVersionId),
            resolvedModelId: resolvedModelId != null
                ? Value(resolvedModelId)
                : const Value.absent(),
            soulId: soulId != null ? Value(soulId) : const Value.absent(),
            soulVersionId: soulVersionId != null
                ? Value(soulVersionId)
                : const Value.absent(),
          ),
        );

    if (updatedRows == 0) {
      throw StateError('No wake_run_log row found for runKey: $runKey');
    }
  }

  /// Fetch agent states whose `scheduledWakeAt` is at or before [now].
  ///
  /// Uses a single SQL query with `json_extract` on the serialized column
  /// to avoid an N+1 fetch pattern.
  Future<List<AgentStateEntity>> getDueScheduledAgentStates(
    DateTime now,
  ) async {
    final rows = await _db
        .getDueScheduledAgentStates(now.toIso8601String())
        .get();
    return rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<AgentStateEntity>()
        .toList();
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

  /// Fetch agent entities (including soft-deleted) whose serialized
  /// `vectorClock` is null, ordered by `created_at` ascending.
  ///
  /// Used by the backfill maintenance step to stamp vector clocks on entities
  /// created before the clock-stamping fix. Includes tombstones so that
  /// deletes are also propagated to other devices.
  Future<List<AgentDomainEntity>> getEntitiesWithNullVectorClock() async {
    final rows = await _db.getAgentEntitiesWithNullVectorClock().get();
    return rows.map(AgentDbConversions.fromEntityRow).toList();
  }

  /// Count agent entities (including soft-deleted) whose serialized
  /// `vectorClock` is null.
  Future<int> countEntitiesWithNullVectorClock() {
    return _db.countAgentEntitiesWithNullVectorClock().getSingle();
  }

  /// Fetch all non-deleted agent entities, ordered by `created_at` ascending.
  ///
  /// Used by the maintenance sync step to enqueue all agent entities for
  /// cross-device synchronization.
  Future<List<AgentDomainEntity>> getAllEntities() async {
    final rows = await _db.getAllAgentEntities().get();
    return rows.map(AgentDbConversions.fromEntityRow).toList();
  }

  /// Fetches agent entities (including soft-deleted) updated in the
  /// half-open interval [start, end), paginated.
  Future<List<AgentDomainEntity>> getEntitiesInInterval({
    required DateTime start,
    required DateTime end,
    required int limit,
    required int offset,
  }) async {
    final rows = await _db
        .getAgentEntitiesInInterval(start, end, limit, offset)
        .get();
    return rows.map(AgentDbConversions.fromEntityRow).toList();
  }

  /// Counts agent entities (including soft-deleted) updated in the
  /// half-open interval [start, end).
  Future<int> countEntitiesInInterval({
    required DateTime start,
    required DateTime end,
  }) {
    return _db.countAgentEntitiesInInterval(start, end).getSingle();
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
    final rows = await _db
        .getRecentObservationsByTemplate(templateId, limit)
        .get();
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
    final rows = await _db
        .getEvolutionSessionsByTemplate(templateId, limit)
        .get();
    return rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<EvolutionSessionEntity>()
        .toList();
  }

  /// Fetch all evolution sessions across all non-deleted templates,
  /// newest-first.
  ///
  /// Uses an INNER JOIN against `agent_entities` (type = 'agentTemplate') to
  /// exclude orphan sessions whose parent template has been soft-deleted.
  Future<List<EvolutionSessionEntity>> getAllEvolutionSessions() async {
    final rows = await _db.getAllEvolutionSessions().get();
    return rows
        .map((r) => AgentDbConversions.fromEntityRow(r.es))
        .whereType<EvolutionSessionEntity>()
        .toList();
  }

  /// Fetch persisted evolution session recaps for [templateId], newest-first.
  Future<List<EvolutionSessionRecapEntity>> getEvolutionSessionRecaps(
    String templateId, {
    int limit = 50,
  }) async {
    final rows = await _db
        .getAgentEntitiesByType(
          templateId,
          AgentEntityTypes.evolutionSessionRecap,
          limit,
        )
        .get();
    return rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<EvolutionSessionRecapEntity>()
        .toList();
  }

  /// Fetch the persisted recap for [sessionId], if one exists.
  Future<EvolutionSessionRecapEntity?> getEvolutionSessionRecap(
    String sessionId,
  ) async {
    final entity = await getEntity(evolutionSessionRecapId(sessionId));
    return entity?.mapOrNull(evolutionSessionRecap: (recap) => recap);
  }

  /// Fetch evolution notes for [templateId], newest-first.
  Future<List<EvolutionNoteEntity>> getEvolutionNotes(
    String templateId, {
    int limit = 50,
  }) async {
    final rows = await _db.getEvolutionNotesByTemplate(templateId, limit).get();
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
  ///
  /// Throws [StateError] if [runKey] does not match any existing row.
  Future<void> updateWakeRunRating(
    String runKey, {
    required double rating,
    required DateTime ratedAt,
  }) async {
    final updatedRows =
        await (_db.update(
          _db.wakeRunLog,
        )..where((t) => t.runKey.equals(runKey))).write(
          WakeRunLogCompanion(
            userRating: Value(rating),
            ratedAt: Value(ratedAt),
          ),
        );

    if (updatedRows == 0) {
      throw StateError('No wake_run_log row found for runKey: $runKey');
    }
  }

  // ── Change set queries ──────────────────────────────────────────────────────

  /// Fetch pending or partially-resolved change sets for [agentId],
  /// optionally filtered by [taskId].
  ///
  /// The persisted field is historically named `taskId`, but stores the target
  /// entity ID for both task-scoped and project-scoped proposals.
  ///
  /// Returns newest-first, capped at [limit]. The [taskId] filter is applied
  /// in Dart because it lives inside the serialized JSON data column, not in a
  /// dedicated indexed column. At current volumes (single agent, limit ≤ 20)
  /// this is adequate; a dedicated column + DB-level filter is a future
  /// optimization if query counts grow.
  Future<List<ChangeSetEntity>> getPendingChangeSets(
    String agentId, {
    String? taskId,
    int limit = 20,
  }) async {
    // When filtering by taskId in Dart, over-fetch from DB to compensate for
    // rows that will be discarded. Without a dedicated taskId column we cannot
    // filter at the SQL level.
    final dbLimit = taskId != null ? limit * _overFetchMultiplier : limit;
    final rows = await _db.getPendingChangeSetsForAgent(agentId, dbLimit).get();
    var results = rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<ChangeSetEntity>()
        .toList();
    if (taskId != null) {
      results = results.where((cs) => cs.taskId == taskId).toList();
    }
    return results.take(limit).toList();
  }

  /// Fetch recent change decisions for [agentId], optionally filtered by
  /// [taskId].
  ///
  /// The persisted field is historically named `taskId`, but stores the target
  /// entity ID for both task-scoped and project-scoped decisions.
  ///
  /// Returns newest-first, capped at [limit]. The [taskId] filter is applied
  /// in Dart (same rationale as [getPendingChangeSets]). Used by the context
  /// builder to assemble decision history for the agent's system prompt.
  Future<List<ChangeDecisionEntity>> getRecentDecisions(
    String agentId, {
    String? taskId,
    int limit = 20,
  }) async {
    final dbLimit = taskId != null ? limit * _overFetchMultiplier : limit;
    final rows = await _db.getRecentDecisionsForAgent(agentId, dbLimit).get();
    var results = rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<ChangeDecisionEntity>()
        .toList();
    if (taskId != null) {
      results = results.where((d) => d.taskId == taskId).toList();
    }
    return results.take(limit).toList();
  }

  /// Build a [ProposalLedger] for [taskId] under [agentId] — every
  /// [ChangeItem] the agent has ever produced for this task, annotated with
  /// its current lifecycle status and (if resolved) who resolved it.
  ///
  /// The ledger feeds two consumers:
  ///
  ///  * the LLM prompt (`TaskAgentWorkflow._formatProposalLedger`), so the
  ///    agent sees a single status-sorted view of its own history and can
  ///    avoid duplicate proposals or explicitly retract stale ones;
  ///  * the consolidated `AgentSuggestionsPanel` UI, which renders only
  ///    open items and exposes resolved history in a collapsed activity
  ///    strip.
  ///
  /// Open entries are extracted from pending/partiallyResolved change sets.
  /// Resolved entries come from all change sets (including resolved and
  /// expired ones) joined with their [ChangeDecisionEntity] records, and
  /// are capped at [resolvedLimit] most-recent decisions to keep the LLM
  /// prompt bounded.
  Future<ProposalLedger> getProposalLedger(
    String agentId, {
    required String taskId,
    int changeSetFetchLimit = 200,
    int resolvedLimit = 50,
  }) async {
    // Three independent table scans — run in parallel to keep wall-clock
    // bounded on cold sqlite access. The dedicated pending query is what
    // guarantees an old-but-still-open consolidated change set is never
    // dropped by the recent-history cap: `getChangeSetsForAgent` is
    // newest-first and would otherwise bury a long-lived open set past
    // `changeSetFetchLimit` once enough resolved history accumulates.
    final results = await Future.wait([
      _db
          .getPendingChangeSetsForAgent(
            agentId,
            changeSetFetchLimit * _overFetchMultiplier,
          )
          .get(),
      _db.getChangeSetsForAgent(agentId, changeSetFetchLimit).get(),
      _db
          .getRecentDecisionsForAgent(
            agentId,
            resolvedLimit * _overFetchMultiplier,
          )
          .get(),
    ]);
    final pendingRows = results[0];
    final recentRows = results[1];
    final decisionRows = results[2];

    final pendingSets = pendingRows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<ChangeSetEntity>()
        .where((cs) => cs.taskId == taskId)
        .toList();
    final recentSets = recentRows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<ChangeSetEntity>()
        .where((cs) => cs.taskId == taskId);

    final setsById = <String, ChangeSetEntity>{
      for (final cs in recentSets) cs.id: cs,
      // Pending wins the union: its rows are freshly queried by status
      // and may reflect state that newer resolved rows have not yet
      // picked up if a confirmation landed between the two scans.
      for (final cs in pendingSets) cs.id: cs,
    };
    final allSets = setsById.values.toList();

    if (allSets.isEmpty) return const ProposalLedger.empty();

    final decisions = decisionRows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<ChangeDecisionEntity>()
        .where((d) => d.taskId == taskId)
        .toList();

    final decisionByKey = <String, ChangeDecisionEntity>{};
    for (final d in decisions) {
      decisionByKey['${d.changeSetId}:${d.itemIndex}'] = d;
    }

    final open = <LedgerEntry>[];
    final resolved = <LedgerEntry>[];

    for (final set in allSets) {
      for (var i = 0; i < set.items.length; i++) {
        final item = set.items[i];
        final decision = decisionByKey['${set.id}:$i'];
        final entry = LedgerEntry(
          changeSetId: set.id,
          itemIndex: i,
          toolName: item.toolName,
          args: item.args,
          humanSummary: item.humanSummary,
          fingerprint: ChangeItem.fingerprint(item),
          status: item.status,
          createdAt: set.createdAt,
          resolvedAt: decision?.createdAt ?? set.resolvedAt,
          resolvedBy: decision?.actor,
          verdict: decision?.verdict,
          reason: decision?.retractionReason ?? decision?.rejectionReason,
          groupId: item.groupId,
        );
        if (entry.isOpen) {
          open.add(entry);
        } else {
          resolved.add(entry);
        }
      }
    }

    open.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    resolved.sort((a, b) {
      final aResolved = a.resolvedAt ?? a.createdAt;
      final bResolved = b.resolvedAt ?? b.createdAt;
      return bResolved.compareTo(aResolved);
    });

    return ProposalLedger(
      open: open,
      resolved: resolved.take(resolvedLimit).toList(),
      pendingSets: pendingSets,
    );
  }

  /// Fetch change decisions across all instances of [templateId] created on
  /// or after [since].
  ///
  /// Uses a JOIN between `agent_links` (template_assignment) and
  /// `agent_entities` (changeDecision) to retrieve decisions in a single query,
  /// avoiding per-agent N+1 lookups. The [since] filter is applied in SQL.
  Future<List<ChangeDecisionEntity>> getRecentDecisionsForTemplate(
    String templateId, {
    required DateTime since,
    int limit = 500,
  }) async {
    final rows = await _db
        .getRecentDecisionsByTemplate(templateId, since, limit)
        .get();
    return rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<ChangeDecisionEntity>()
        .toList();
  }

  // ── Link CRUD ──────────────────────────────────────────────────────────────

  /// Fetch a single link by its [id], or `null` if not found.
  Future<model.AgentLink?> getLinkById(String id) async {
    final rows = await _db.getAgentLinkById(id).get();
    if (rows.isEmpty) return null;
    return AgentDbConversions.fromLinkRow(rows.first);
  }

  /// Insert or update a link using on-conflict update semantics against the
  /// primary key (`id`).
  ///
  /// `agent_links` additionally carries two partial unique indexes that
  /// `insertOnConflictUpdate`'s primary-key-only ON CONFLICT clause does
  /// NOT handle:
  ///  - `idx_unique_soul_per_template` on `(from_id)` where
  ///    `type = 'soul_assignment' AND deleted_at IS NULL`.
  ///  - `idx_unique_improver_per_template` on `(to_id)` where
  ///    `type = 'improver_target' AND deleted_at IS NULL`.
  ///
  /// When a sync-incoming link carries the same `from_id` / `to_id` as an
  /// existing active row but a different `id`, the insert hits the
  /// partial unique index and throws `SqliteException(2067)`. The v6
  /// migration uses the same pattern to de-duplicate pre-existing rows:
  /// we preemptively soft-delete the conflicting active row under the
  /// same transaction, then insert. The soft-deleted row stays in the
  /// table for audit, and the new incoming link takes over the unique
  /// slot for that template.
  ///
  /// Skipping this step leaves the sync apply path throwing retriable
  /// apply errors that exhaust after 10 attempts and mark the queue row
  /// `abandoned` — a silent data drop even though the payload itself
  /// is valid.
  Future<void> upsertLink(model.AgentLink link) async {
    final companion = AgentDbConversions.toLinkCompanion(link);
    final type = AgentDbConversions.linkType(link);
    final needsUniqueSlotHandoff =
        link.deletedAt == null &&
        (type == AgentLinkTypes.soulAssignment ||
            type == AgentLinkTypes.improverTarget);

    if (!needsUniqueSlotHandoff) {
      await _db.into(_db.agentLinks).insertOnConflictUpdate(companion);
      return;
    }

    await _db.transaction(() async {
      final now = DateTime.now();
      final softDelete = AgentLinksCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      );
      if (type == AgentLinkTypes.soulAssignment) {
        await (_db.update(_db.agentLinks)
              ..where(
                (t) =>
                    t.type.equals(AgentLinkTypes.soulAssignment) &
                    t.deletedAt.isNull() &
                    t.fromId.equals(link.fromId) &
                    t.id.equals(link.id).not(),
              ))
            .write(softDelete);
      } else {
        // improverTarget — UNIQUE on (to_id).
        await (_db.update(_db.agentLinks)
              ..where(
                (t) =>
                    t.type.equals(AgentLinkTypes.improverTarget) &
                    t.deletedAt.isNull() &
                    t.toId.equals(link.toId) &
                    t.id.equals(link.id).not(),
              ))
            .write(softDelete);
      }
      await _db.into(_db.agentLinks).insertOnConflictUpdate(companion);
    });
  }

  /// Insert a link exclusively — throws [DuplicateInsertException] if a
  /// unique constraint is violated (e.g. the partial unique index on
  /// `improver_target` links).
  Future<void> insertLinkExclusive(model.AgentLink link) async {
    final companion = AgentDbConversions.toLinkCompanion(link);
    try {
      await _db.into(_db.agentLinks).insert(companion);
    } on SqliteException catch (e) {
      if (e.resultCode == 19) {
        throw DuplicateInsertException('agent_links', link.toId, e);
      }
      rethrow;
    }
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

  /// Batch-fetch non-deleted links pointing to any of [toIds] with a given
  /// [type], returned as a map from `toId` → links.
  ///
  /// Issues a single SQL query with `IN (...)` instead of N separate lookups.
  /// IDs not present in the result map have no matching links.
  Future<Map<String, List<model.AgentLink>>> getLinksToMultiple(
    List<String> toIds, {
    required String type,
  }) async {
    if (toIds.isEmpty) return {};

    final placeholders = List.filled(toIds.length, '?').join(', ');
    final rows = await _db
        .customSelect(
          'SELECT * FROM agent_links '
          'WHERE to_id IN ($placeholders) AND type = ? AND deleted_at IS NULL',
          variables: [
            ...toIds.map(Variable.withString),
            Variable.withString(type),
          ],
          readsFrom: {_db.agentLinks},
        )
        .get();

    final result = <String, List<model.AgentLink>>{};
    for (final row in rows) {
      final link = AgentDbConversions.fromLinkRow(
        await _db.agentLinks.mapFromRow(row),
      );
      (result[link.toId] ??= []).add(link);
    }
    return result;
  }

  /// Fetch agent links (including soft-deleted) whose serialized
  /// `vectorClock` is null, ordered by `created_at` ascending.
  ///
  /// Used by the backfill maintenance step to stamp vector clocks on links
  /// created before the clock-stamping fix. Includes tombstones so that
  /// deletes are also propagated to other devices.
  Future<List<model.AgentLink>> getLinksWithNullVectorClock() async {
    final rows = await _db.getAgentLinksWithNullVectorClock().get();
    return rows.map(AgentDbConversions.fromLinkRow).toList();
  }

  /// Returns the set of journal task IDs that have a non-deleted `agent_task`
  /// link. Used by the task filter to distinguish assigned vs unassigned tasks.
  Future<Set<String>> getTaskIdsWithAgentLink() async {
    final rows = await _db.getAgentTaskLinkToIds().get();
    return rows.toSet();
  }

  /// Count agent links (including soft-deleted) whose serialized
  /// `vectorClock` is null.
  Future<int> countLinksWithNullVectorClock() {
    return _db.countAgentLinksWithNullVectorClock().getSingle();
  }

  /// Fetch all non-deleted agent links, ordered by `created_at` ascending.
  ///
  /// Used by the maintenance sync step to enqueue all agent links for
  /// cross-device synchronization.
  Future<List<model.AgentLink>> getAllLinks() async {
    final rows = await _db.getAllAgentLinks().get();
    return rows.map(AgentDbConversions.fromLinkRow).toList();
  }

  /// Fetches agent links (including soft-deleted) updated in the
  /// half-open interval [start, end), paginated.
  Future<List<model.AgentLink>> getLinksInInterval({
    required DateTime start,
    required DateTime end,
    required int limit,
    required int offset,
  }) async {
    final rows = await _db
        .getAgentLinksInInterval(start, end, limit, offset)
        .get();
    return rows.map(AgentDbConversions.fromLinkRow).toList();
  }

  /// Counts agent links (including soft-deleted) updated in the
  /// half-open interval [start, end).
  Future<int> countLinksInInterval({
    required DateTime start,
    required DateTime end,
  }) {
    return _db.countAgentLinksInInterval(start, end).getSingle();
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
    await (_db.update(
      _db.wakeRunLog,
    )..where((t) => t.runKey.equals(runKey))).write(
      WakeRunLogCompanion(
        status: Value(status),
        startedAt: startedAt != null ? Value(startedAt) : const Value.absent(),
        completedAt: completedAt != null
            ? Value(completedAt)
            : const Value.absent(),
        errorMessage: errorMessage != null
            ? Value(errorMessage)
            : const Value.absent(),
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

  /// Count all wake runs for [templateId] with no presentation cap.
  Future<int> countWakeRunsForTemplate(String templateId) {
    return _db.countWakeRunsByTemplateId(templateId).getSingle();
  }

  /// Aggregate wake-run metrics (success/failure counts, duration stats,
  /// first/last timestamps) for [templateId] in a single SQL query.
  Future<AggregateWakeRunMetricsByTemplateIdResult> aggregateWakeRunMetrics(
    String templateId,
  ) {
    return _db.aggregateWakeRunMetricsByTemplateId(templateId).getSingle();
  }

  /// Sum token usage (input, output, thoughts) for all instances of
  /// [templateId] in a single SQL query.
  Future<SumTokenUsageByTemplateResult> sumTokenUsageForTemplate(
    String templateId,
  ) {
    return _db.sumTokenUsageByTemplate(templateId).getSingle();
  }

  /// Sum token usage for all instances of [templateId] created on or
  /// after [since].
  Future<SumTokenUsageByTemplateSinceResult> sumTokenUsageForTemplateSince(
    String templateId, {
    required DateTime since,
  }) {
    return _db.sumTokenUsageByTemplateSince(templateId, since).getSingle();
  }

  /// Fetch wake runs for [templateId] within the inclusive window.
  Future<List<WakeRunLogData>> getWakeRunsForTemplateInWindow(
    String templateId, {
    required DateTime since,
    required DateTime until,
  }) {
    return _db.getWakeRunsByTemplateInWindow(templateId, since, until).get();
  }

  /// Fetch all wake runs across all agents within the inclusive window.
  Future<List<WakeRunLogData>> getWakeRunsInWindow({
    required DateTime since,
    required DateTime until,
  }) {
    return _db.getWakeRunsInWindow(since, until).get();
  }

  /// Fetch a single wake-run entry by [runKey], or `null` if not found.
  Future<WakeRunLogData?> getWakeRun(String runKey) async {
    final rows = await _db.getWakeRunByKey(runKey).get();
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// Fetch the most recent wake-run entry for [agentId] and [threadId],
  /// or `null`.
  Future<WakeRunLogData?> getWakeRunByThreadId(
    String agentId,
    String threadId,
  ) async {
    final rows = await _db.getWakeRunByThreadId(agentId, threadId).get();
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// Fetch token usage records for [agentId], ordered most-recent first.
  ///
  /// Returns deserialized `WakeTokenUsageEntity` records from the
  /// `agent_entities` table.
  Future<List<WakeTokenUsageEntity>> getTokenUsageForAgent(
    String agentId, {
    int limit = 500,
  }) async {
    final rows = await _db.getTokenUsageByAgentId(agentId, limit).get();
    return rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<WakeTokenUsageEntity>()
        .toList();
  }

  /// Fetch token usage records for all instances of [templateId].
  ///
  /// Uses a SQL JOIN via `template_assignment` links — same pattern as
  /// [getRecentReportsByTemplate].
  Future<List<WakeTokenUsageEntity>> getTokenUsageForTemplate(
    String templateId, {
    int limit = 10000,
  }) async {
    final rows = await _db.getTokenUsageByTemplateId(templateId, limit).get();
    return rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<WakeTokenUsageEntity>()
        .toList();
  }

  /// Fetch token usage records for all instances of [templateId] created on or
  /// after [since].
  Future<List<WakeTokenUsageEntity>> getTokenUsageForTemplateSince(
    String templateId, {
    required DateTime since,
  }) async {
    final rows = await _db
        .getTokenUsageByTemplateSince(templateId, since)
        .get();
    return rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<WakeTokenUsageEntity>()
        .toList();
  }

  /// Fetch all token usage records across all agents created on or after
  /// [since].
  ///
  /// Used by the global token stats view to compute daily aggregates without
  /// filtering by template or agent.
  Future<List<WakeTokenUsageEntity>> getGlobalTokenUsageSince({
    required DateTime since,
  }) async {
    final rows = await _db.getGlobalTokenUsageSince(since).get();
    return rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<WakeTokenUsageEntity>()
        .toList();
  }

  /// Mark any wake runs still in `running` status as `abandoned`.
  ///
  /// Called on startup to clean up runs left behind by a hot restart or crash.
  /// Returns the number of rows updated.
  Future<int> abandonOrphanedWakeRuns() async {
    return (_db.update(_db.wakeRunLog)..where(
          (t) => t.status.equals(WakeRunStatus.running.name),
        ))
        .write(
          WakeRunLogCompanion(
            status: Value(WakeRunStatus.abandoned.name),
            errorMessage: const Value(
              'Marked as abandoned on startup (orphaned run)',
            ),
          ),
        );
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
    await (_db.update(
      _db.sagaLog,
    )..where((t) => t.operationId.equals(operationId))).write(
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
