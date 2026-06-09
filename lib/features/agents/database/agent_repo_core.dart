part of 'agent_repository.dart';

mixin _AgentRepoCore on _AgentRepositoryBase {
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
    final affectsAttentionClaims = _affectsAttentionClaimProjection(entity);
    final affectsStandingAgreements = _affectsStandingAgreementProjection(
      entity,
    );
    if (!affectsAttentionClaims && !affectsStandingAgreements) {
      await _db.into(_db.agentEntities).insertOnConflictUpdate(companion);
      return;
    }

    await _db.transaction(() async {
      await _db.into(_db.agentEntities).insertOnConflictUpdate(companion);
      if (affectsAttentionClaims) {
        await _refreshAttentionClaimProjectionForEntity(entity);
      }
      if (affectsStandingAgreements) {
        await _refreshStandingAgreementProjectionForEntity(entity);
      }
    });
  }

  /// Fetch a single entity by its [id], or `null` if not found.
  @override
  Future<AgentDomainEntity?> getEntity(String id) async {
    final rows = await _db.getAgentEntityById(id).get();
    if (rows.isEmpty) return null;
    return AgentDbConversions.fromEntityRow(rows.first);
  }

  /// Batch-fetch non-deleted entities for every id in [ids]. Returns
  /// the matched entities keyed by their `id` column so the caller can
  /// look them up without iterating; ids that have no row (or whose
  /// row is soft-deleted) are simply absent from the map.
  ///
  /// Issues one `WHERE id IN (?, …)` query per
  /// [_sqliteInClauseChunkSize] batch against the primary-key index
  /// instead of N per-id round-trips. The 2026-05-10 desktop
  /// slow_queries log captured 2 484 hits/day for `SELECT * FROM
  /// agent_entities WHERE id = ? AND deleted_at IS NULL` — all from
  /// the per-row `Future.wait` fan-out in `_collectObservationPayloads`
  /// (project_agent_workflow.dart and task_agent_workflow.dart). The
  /// plan was a clean PK seek; the cost was the writer-lock queue
  /// wait piling up behind each independent isolate hop.
  ///
  /// Chunking guards the bulk path against SQLite's host-variable
  /// limit (default 999): an unbounded caller (e.g.
  /// `_collectObservationPayloads` on a project agent with thousands
  /// of pending observations) would otherwise throw `SqliteException
  /// (too many SQL variables)` once the IN-list exceeded 999 entries.
  /// At the production chunk size the worst case is still one round-
  /// trip per ~900 ids, which is dramatically cheaper than the
  /// per-id fan-out it replaces.
  ///
  /// Empty input returns an empty map without touching the database.
  @override
  Future<Map<String, AgentDomainEntity>> getEntitiesByIds(
    Iterable<String> ids,
  ) async {
    final result = <String, AgentDomainEntity>{};
    for (final chunk in _sqliteInClauseChunks(ids)) {
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            'SELECT * FROM agent_entities '
            'WHERE id IN ($placeholders) AND deleted_at IS NULL',
            variables: chunk.map(Variable.withString).toList(),
            readsFrom: {_db.agentEntities},
          )
          .get();
      for (final row in rows) {
        final entityRow = await _db.agentEntities.mapFromRow(row);
        // `agentEntities.id` is the column the IN-list filters against,
        // so it doubles as the stable result-map key without having to
        // re-enter the Freezed union to extract a per-variant id field.
        result[entityRow.id] = AgentDbConversions.fromEntityRow(entityRow);
      }
    }
    return result;
  }

  @override
  Future<List<AgentDomainEntity>> _latestEntitiesByAgentIds({
    required Iterable<String> agentIds,
    required String type,
    String? subtype,
  }) async {
    final result = <AgentDomainEntity>[];
    for (final chunk in _sqliteInClauseChunks(agentIds)) {
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final subtypePredicate = subtype == null ? '' : 'AND subtype = ? ';
      final rows = await _db
          .customSelect(
            '''
              SELECT id, agent_id, type, subtype, thread_id, created_at,
                updated_at, deleted_at, serialized, schema_version
              FROM (
                SELECT agent_entities.*,
                  ROW_NUMBER() OVER (
                    PARTITION BY agent_id
                    ORDER BY created_at DESC, id DESC
                  ) AS rn
                FROM agent_entities
                WHERE agent_id IN ($placeholders)
                  AND type = ?
                  $subtypePredicate
                  AND deleted_at IS NULL
              )
              WHERE rn = 1
            ''',
            variables: [
              ...chunk.map(Variable.withString),
              Variable.withString(type),
              if (subtype != null) Variable.withString(subtype),
            ],
            readsFrom: {_db.agentEntities},
          )
          .get();

      for (final row in rows) {
        result.add(
          AgentDbConversions.fromEntityRow(
            await _db.agentEntities.mapFromRow(row),
          ),
        );
      }
    }
    return result;
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

  /// Lightweight ordering metadata for [agentId]'s non-deleted `capture`
  /// entities — id + the two timestamps that fix an event's log position —
  /// **without** materializing the (potentially large) transcript.
  ///
  /// The day planner is a single long-lived agent, so its capture history grows
  /// without bound. The compaction substrate only needs each capture's id and
  /// position to order the log and run the checkpoint completeness check (which
  /// keys on id, not content); transcripts are pulled in lazily for just the
  /// post-cutoff tail (see `AgentLogCompactor.resolveInlineContent`). Reading
  /// only these columns keeps per-wake cost flat instead of O(all captures).
  Future<List<({String id, DateTime createdAt, DateTime capturedAt})>>
  getCaptureEventMetaByAgentId(String agentId) async {
    final rows = await _db
        .customSelect(
          r"SELECT id, json_extract(serialized, '$.createdAt') AS created_at, "
          r"json_extract(serialized, '$.capturedAt') AS captured_at "
          'FROM agent_entities '
          'WHERE agent_id = ? AND type = ? AND deleted_at IS NULL',
          variables: [
            Variable.withString(agentId),
            Variable.withString(AgentEntityTypes.capture),
          ],
          readsFrom: {_db.agentEntities},
        )
        .get();
    final metas = <({String id, DateTime createdAt, DateTime capturedAt})>[];
    for (final row in rows) {
      final createdAtRaw = row.read<String?>('created_at');
      final capturedAtRaw = row.read<String?>('captured_at');
      if (createdAtRaw == null || capturedAtRaw == null) continue;
      final createdAt = DateTime.tryParse(createdAtRaw);
      final capturedAt = DateTime.tryParse(capturedAtRaw);
      if (createdAt == null || capturedAt == null) continue;
      metas.add((
        id: row.read<String>('id'),
        createdAt: createdAt,
        capturedAt: capturedAt,
      ));
    }
    return metas;
  }

  /// See `AgentAttentionProjection`.
  Future<List<AttentionRequestEntity>> getAttentionClaimsForWindow({
    required DateTime start,
    required DateTime end,
    Set<AttentionClaimStatus> statuses = const {
      AttentionClaimStatus.open,
      AttentionClaimStatus.proposed,
      AttentionClaimStatus.partiallySatisfied,
      AttentionClaimStatus.deferred,
    },
    int limit = 200,
  }) => getAttentionClaimsForWindowImpl(
    start: start,
    end: end,
    statuses: statuses,
    limit: limit,
  );

  /// See `AgentAttentionProjection`.
  Future<List<AttentionRequestEntity>> getAttentionClaimsForTarget({
    required String targetKind,
    required String targetId,
    Set<AttentionClaimStatus> statuses = const {
      AttentionClaimStatus.open,
      AttentionClaimStatus.proposed,
      AttentionClaimStatus.partiallySatisfied,
      AttentionClaimStatus.deferred,
    },
    int limit = 50,
  }) => getAttentionClaimsForTargetImpl(
    targetKind: targetKind,
    targetId: targetId,
    statuses: statuses,
    limit: limit,
  );

  /// See `AgentAttentionProjection`.
  Future<AttentionPlanningInputs> getAttentionPlanningInputsForWindow({
    required DateTime start,
    required DateTime end,
    Set<AttentionClaimStatus> claimStatuses = const {
      AttentionClaimStatus.open,
      AttentionClaimStatus.proposed,
      AttentionClaimStatus.partiallySatisfied,
      AttentionClaimStatus.deferred,
    },
    Set<StandingAgreementStatus> agreementStatuses = const {
      StandingAgreementStatus.active,
    },
    Set<StandingAgreementScope>? agreementScopes,
    int claimLimit = 200,
    int agreementLimit = 200,
  }) => getAttentionPlanningInputsForWindowImpl(
    start: start,
    end: end,
    claimStatuses: claimStatuses,
    agreementStatuses: agreementStatuses,
    agreementScopes: agreementScopes,
    claimLimit: claimLimit,
    agreementLimit: agreementLimit,
  );

  /// See `AgentAttentionProjection`.
  Future<List<StandingAgreementEntity>> getStandingAgreementsForWindow({
    required DateTime start,
    required DateTime end,
    Set<StandingAgreementStatus> statuses = const {
      StandingAgreementStatus.active,
    },
    Set<StandingAgreementScope>? scopes,
    int limit = 200,
  }) => getStandingAgreementsForWindowImpl(
    start: start,
    end: end,
    statuses: statuses,
    scopes: scopes,
    limit: limit,
  );

  /// See `AgentAttentionProjection`.
  Future<void> rebuildAttentionClaimProjection() =>
      rebuildAttentionClaimProjectionImpl();

  /// See `AgentAttentionProjection`.
  Future<void> rebuildStandingAgreementProjection() =>
      rebuildStandingAgreementProjectionImpl();

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

  /// All non-deleted messages for [agentId], across threads. Used by the
  /// causal-DAG backfill to chain a legacy (edge-less) message prefix. The
  /// underlying query orders newest-first; callers that need chronological
  /// order sort by `(createdAt, id)` themselves.
  Future<List<AgentMessageEntity>> getAgentMessages(String agentId) async {
    // Delegates to the generic fetcher with its default unbounded limit (-1) —
    // a one-time backfill needs the full history. The `type` filter guarantees
    // every row is a message; `whereType` only narrows the static type.
    final entities = await getEntitiesByAgentId(
      agentId,
      type: AgentEntityTypes.agentMessage,
    );
    return entities.whereType<AgentMessageEntity>().toList();
  }

  /// Batch-fetch the latest [AgentStateEntity] for each agent in [agentIds].
  ///
  /// Issues chunked SQL queries that keep only the newest state row per
  /// `agentId`. Agents without a state are omitted.
  Future<Map<String, AgentStateEntity>> getAgentStatesByAgentIds(
    List<String> agentIds,
  ) async {
    final latestEntities = await _latestEntitiesByAgentIds(
      agentIds: agentIds,
      type: AgentEntityTypes.agentState,
    );
    return {
      for (final entity in latestEntities)
        if (entity case final AgentStateEntity state) state.agentId: state,
    };
  }

  /// Fetch the newest active agent identity of [kind] whose latest state has
  /// `AgentSlots.activeDayId == activeDayId`.
  ///
  /// This keeps the day-agent lookup in SQL instead of loading every active
  /// day-agent state into Dart and filtering in memory.
  Future<AgentIdentityEntity?> getActiveAgentByKindAndActiveDayId({
    required String kind,
    required String activeDayId,
  }) async {
    final rows = await _db
        .customSelect(
          r'''
            SELECT identity.*
            FROM agent_entities AS identity
            INNER JOIN agent_entities AS state
              ON state.id = (
                SELECT latest_state.id
                FROM agent_entities AS latest_state
                WHERE latest_state.agent_id = identity.agent_id
                  AND latest_state.type = ?
                  AND latest_state.deleted_at IS NULL
                ORDER BY latest_state.created_at DESC, latest_state.id DESC
                LIMIT 1
              )
            WHERE identity.type = 'agent'
              AND identity.subtype = ?
              AND identity.deleted_at IS NULL
              AND json_extract(identity.serialized, '$.lifecycle') = ?
              AND json_extract(state.serialized, '$.slots.activeDayId') = ?
            ORDER BY identity.created_at DESC, identity.agent_id DESC
            LIMIT 1
          ''',
          variables: [
            Variable.withString(AgentEntityTypes.agentState),
            Variable.withString(kind),
            Variable.withString(AgentLifecycle.active.name),
            Variable.withString(activeDayId),
          ],
          readsFrom: {_db.agentEntities},
        )
        .get();
    if (rows.isEmpty) return null;

    final entity = AgentDbConversions.fromEntityRow(
      await _db.agentEntities.mapFromRow(rows.first),
    );
    return entity.mapOrNull(agent: (agent) => agent);
  }

  /// Batch-resolve the active [SoulDocumentVersionEntity] for each soul id.
  ///
  /// Mirrors `getActiveSoulDocumentVersion` but avoids the head lookup +
  /// version lookup pair per soul when a caller is hydrating a list view.
  /// The head row per soul follows the same newest-first query order as
  /// `getSoulDocumentHead`, with that filtering performed by SQL.
  Future<Map<String, SoulDocumentVersionEntity>>
  getActiveSoulDocumentVersionsBySoulIds(List<String> soulIds) async {
    final versionIdsBySoulId = <String, String>{};
    final latestHeads = await _latestEntitiesByAgentIds(
      agentIds: soulIds,
      type: AgentEntityTypes.soulDocumentHead,
    );
    for (final entity in latestHeads) {
      final head = entity.mapOrNull(soulDocumentHead: (e) => e);
      if (head != null) {
        versionIdsBySoulId[head.agentId] = head.versionId;
      }
    }

    if (versionIdsBySoulId.isEmpty) {
      return {};
    }

    final entitiesById = await getEntitiesByIds(versionIdsBySoulId.values);
    return {
      for (final entry in versionIdsBySoulId.entries)
        if (entitiesById[entry.value] case final SoulDocumentVersionEntity v)
          entry.key: v,
    };
  }

  /// Fetch messages for [agentId] filtered by [kind], optionally capped at
  /// [limit] rows (most-recent first).
}
