part of 'agent_repository.dart';

mixin _AgentRepoQueries on _AgentRepositoryBase {
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
  /// Issues chunked SQL queries that keep only the newest matching head per
  /// agent, then a chunked report-id fetch instead of 2N individual lookups.
  /// Agents without a report are omitted from the result.
  Future<Map<String, AgentReportEntity>> getLatestReportsByAgentIds(
    List<String> agentIds,
    String scope,
  ) async {
    if (agentIds.isEmpty) return {};

    final reportIdsByAgentId = <String, String>{};
    final latestHeads = await _latestEntitiesByAgentIds(
      agentIds: agentIds,
      type: AgentEntityTypes.agentReportHead,
      subtype: scope,
    );
    for (final entity in latestHeads) {
      final head = entity.mapOrNull(agentReportHead: (e) => e);
      if (head != null) {
        reportIdsByAgentId[head.agentId] = head.reportId;
      }
    }

    final allReportIds = reportIdsByAgentId.values.toSet();
    if (allReportIds.isEmpty) return {};

    final reportsById = <String, AgentReportEntity>{};
    final entitiesById = await getEntitiesByIds(allReportIds);
    for (final entity in entitiesById.values) {
      if (entity case final AgentReportEntity report) {
        reportsById[report.id] = report;
      }
    }

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
}
