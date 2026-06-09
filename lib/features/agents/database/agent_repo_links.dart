part of 'agent_repository.dart';

mixin _AgentRepoLinks on _AgentRepositoryBase {
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
      // The SQL `deleted_at` / `updated_at` columns AND the
      // `serialized` JSON both need to carry the tombstone, otherwise
      // readers that decode the link from `serialized` (e.g. the
      // sequence-log population queries `getAgentLinksInInterval` and
      // `getAgentLinksWithNullVectorClock`, which return raw rows
      // without a deleted_at filter) see a SQL-soft-deleted row whose
      // JSON still describes an active link. `json_set` mutates the
      // JSON in-place so the two stay consistent.
      final nowIso = now.toIso8601String();
      final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
      final typeSql = type == AgentLinkTypes.soulAssignment
          ? 'soul_assignment'
          : 'improver_target';
      if (type == AgentLinkTypes.soulAssignment) {
        await _db.customStatement(
          'UPDATE agent_links '
          'SET deleted_at = ?, updated_at = ?, '
          '    serialized = json_set(serialized, '
          r"      '$.deletedAt', ?, "
          r"      '$.updatedAt', ?) "
          "WHERE type = 'soul_assignment' "
          '  AND deleted_at IS NULL '
          '  AND from_id = ? '
          '  AND id != ?',
          [nowSeconds, nowSeconds, nowIso, nowIso, link.fromId, link.id],
        );
      } else {
        // improverTarget — UNIQUE on (to_id).
        await _db.customStatement(
          'UPDATE agent_links '
          'SET deleted_at = ?, updated_at = ?, '
          '    serialized = json_set(serialized, '
          r"      '$.deletedAt', ?, "
          r"      '$.updatedAt', ?) "
          "WHERE type = 'improver_target' "
          '  AND deleted_at IS NULL '
          '  AND to_id = ? '
          '  AND id != ?',
          [nowSeconds, nowSeconds, nowIso, nowIso, link.toId, link.id],
        );
      }
      // The partial unique index `idx_agent_links_unique_from_to_type`
      // on (from_id, to_id, type) — all types except `message_payload` —
      // applies regardless of `deleted_at`, so the soft-delete above
      // does NOT free the natural-key slot when an existing row has
      // the exact same `(type, from_id, to_id)` triple but a
      // different `id` (e.g. the same soul↔template binding
      // resynced from another device after a data restore). Drift's
      // `insertOnConflictUpdate` emits `ON CONFLICT(id) DO UPDATE`,
      // so a non-primary-key UNIQUE violation throws 2067 instead of
      // upserting. Hard-delete any exact-natural-key rows with a
      // different id inside the same transaction so the INSERT can
      // claim the slot. The soft-delete tombstone is preserved for
      // rows whose natural key differs (e.g. different to_id on a
      // soul_assignment re-binding) — only exact-duplicate rows that
      // were already headed to the tombstone are dropped.
      await _db.customStatement(
        'DELETE FROM agent_links '
        'WHERE type = ? '
        '  AND from_id = ? '
        '  AND to_id = ? '
        '  AND id != ?',
        [typeSql, link.fromId, link.toId, link.id],
      );
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
    } on SqliteException catch (e, st) {
      if (e.resultCode == 19) {
        _domainLogger?.error(
          LogDomain.agentRuntime,
          e,
          message:
              'agent_links unique constraint violated for '
              'toId=${DomainLogger.sanitizeId(link.toId)}',
          stackTrace: st,
          subDomain: 'AgentRepository.insertLinkExclusive',
        );
        throw DuplicateInsertException('agent_links', link.toId);
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
  @override
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
  /// Issues chunked `IN (...)` queries instead of N separate lookups. IDs not
  /// present in the result map have no matching links.
  @override
  Future<Map<String, List<model.AgentLink>>> getLinksToMultiple(
    List<String> toIds, {
    required String type,
  }) async {
    final result = <String, List<model.AgentLink>>{};
    for (final chunk in _sqliteInClauseChunks(toIds)) {
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            'SELECT * FROM agent_links '
            'WHERE to_id IN ($placeholders) '
            'AND type = ? AND deleted_at IS NULL',
            variables: [
              ...chunk.map(Variable.withString),
              Variable.withString(type),
            ],
            readsFrom: {_db.agentLinks},
          )
          .get();

      for (final row in rows) {
        final link = AgentDbConversions.fromLinkRow(
          await _db.agentLinks.mapFromRow(row),
        );
        (result[link.toId] ??= []).add(link);
      }
    }
    return result;
  }

  /// Batch-fetch non-deleted links originating from any of [fromIds] with a
  /// given [type], returned as a map from `fromId` → links.
  ///
  /// This is the `from_id` companion to [getLinksToMultiple]. It is used by
  /// list hydration paths that need template → soul assignment links without
  /// issuing one `SELECT * FROM agent_links WHERE from_id = ? ...` per row.
  Future<Map<String, List<model.AgentLink>>> getLinksFromMultiple(
    List<String> fromIds, {
    required String type,
  }) async {
    final result = <String, List<model.AgentLink>>{};
    for (final chunk in _sqliteInClauseChunks(fromIds)) {
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            'SELECT * FROM agent_links '
            'WHERE from_id IN ($placeholders) '
            'AND type = ? AND deleted_at IS NULL',
            variables: [
              ...chunk.map(Variable.withString),
              Variable.withString(type),
            ],
            readsFrom: {_db.agentLinks},
          )
          .get();

      for (final row in rows) {
        final link = AgentDbConversions.fromLinkRow(
          await _db.agentLinks.mapFromRow(row),
        );
        (result[link.fromId] ??= []).add(link);
      }
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
    } on SqliteException catch (e, st) {
      if (e.resultCode == 19) {
        _domainLogger?.error(
          LogDomain.agentRuntime,
          e,
          message:
              'wake_run_log unique constraint violated for '
              'runKey=${DomainLogger.sanitizeId(entry.runKey)}',
          stackTrace: st,
          subDomain: 'AgentRepository.insertWakeRun',
        );
        throw DuplicateInsertException('wake_run_log', entry.runKey);
      }
      rethrow;
    }
  }

  /// Update the [status], and optionally [startedAt], [completedAt] and
  /// [errorMessage], for the wake run identified by [runKey].
  ///
  /// Fire-and-forget on a missing [runKey]: the update silently writes zero
  /// rows. This is deliberate — status transitions are emitted from runtime
  /// paths (timeouts, error handlers, shutdown hooks) that may race run-log
  /// cleanup, and a late transition for a vanished run must not crash the
  /// caller. Contrast with `updateWakeRunTemplate`, which throws
  /// [StateError] because template resolution happens once, early, where a
  /// missing row indicates a real bug.
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
  /// `getRecentReportsByTemplate`.
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
    } on SqliteException catch (e, st) {
      if (e.resultCode == 19) {
        _domainLogger?.error(
          LogDomain.agentRuntime,
          e,
          message:
              'saga_log unique constraint violated for '
              'operationId=${DomainLogger.sanitizeId(entry.operationId)}',
          stackTrace: st,
          subDomain: 'AgentRepository.insertSagaOp',
        );
        throw DuplicateInsertException('saga_log', entry.operationId);
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
