import 'dart:async';
import 'package:drift/drift.dart';
import 'package:lotti/features/agents/database/agent_attention_projection.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_db_conversions.dart';
import 'package:lotti/features/agents/database/agent_entity_by_id_coalescer.dart';
import 'package:lotti/features/agents/database/agent_repo_internals.dart';
import 'package:lotti/features/agents/database/agent_repo_queries.dart'
    show AgentRepoQueries;
import 'package:lotti/features/agents/database/agent_repository.dart'
    show AgentRepository;
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';

/// Entity CRUD, transaction scoping, and the shared batched-read primitives for
/// [AgentRepository]. Collaborator extracted from the former `_AgentRepoCore`
/// mixin; the repository keeps thin delegators so mocks keep intercepting.
///
/// [upsertEntity] refreshes the attention/standing projections through
/// [AgentAttentionProjection], which is injected lazily because the projection
/// in turn reads source rows via [getEntitiesByIds] on this class.
class AgentRepoCore {
  AgentRepoCore(this._db);

  final AgentDatabase _db;

  /// Folds concurrent [getEntity] calls into batched `id IN (…)` reads. Keyed
  /// by zone internally so batching never crosses a drift transaction
  /// boundary — see [AgentEntityByIdCoalescer].
  late final AgentEntityByIdCoalescer _byIdCoalescer = AgentEntityByIdCoalescer(
    getEntitiesByIds,
  );

  /// Cached result of `AgentRepoEvolution.getAllAgentIdentities`.
  ///
  /// Agent identities change rarely but are re-read constantly: the 2026-06/07
  /// slow-query logs show 1,734 full reads of every agent in 14 days (87.4 s at
  /// ~50 ms each — well above the round-trip floor, because ~900 fat rows are
  /// decoded from JSON each time). The read is not bursty (1,449 of 1,587
  /// occurrences are isolated), so microtask coalescing does nothing for it;
  /// what helps is not repeating the work when nothing changed.
  List<AgentIdentityEntity>? _agentIdentitiesCache;

  /// Bumped by every invalidation.
  ///
  /// A load that started before an invalidation must not install its result
  /// afterwards — otherwise a write that lands mid-flight is silently undone
  /// and the pre-write list is served until the *next* write. The generation
  /// captured before the query is compared after it, and a stale load is
  /// discarded rather than cached.
  int _agentIdentitiesGeneration = 0;

  /// Zone marker set for the duration of a transaction, so a load that runs
  /// inside one does not install its result in the shared cache.
  ///
  /// A transaction can read identities after writing one and then roll back;
  /// caching that read would publish a row the database no longer has.
  /// Transaction-local reads are still correct — they just do not populate the
  /// cache.
  static const _inTransactionKey = #agentRepoCoreInTransaction;

  static bool get _isInTransaction => Zone.current[_inTransactionKey] == true;

  /// Returns the cached identity list, or populates it via [load].
  Future<List<AgentIdentityEntity>> cachedAgentIdentities(
    Future<List<AgentIdentityEntity>> Function() load,
  ) async {
    final cached = _agentIdentitiesCache;
    if (cached != null) return cached;

    final generation = _agentIdentitiesGeneration;
    final loaded = await load();

    // Discard the result rather than caching it if an identity write landed
    // while the query was in flight, or if this ran inside a transaction whose
    // writes may still roll back. The caller still gets the rows it asked for.
    if (generation == _agentIdentitiesGeneration && !_isInTransaction) {
      _agentIdentitiesCache = loaded;
    }
    return loaded;
  }

  /// Drops the cached identity list.
  ///
  /// Called by every path that can change which identities exist: identity
  /// upserts (including soft deletes, which are upserts with `deletedAt` set)
  /// and [AgentRepository.hardDeleteAgent], which deletes rows directly and
  /// therefore never reaches [_upsertEntity].
  void invalidateAgentIdentitiesCache() {
    _agentIdentitiesCache = null;
    _agentIdentitiesGeneration++;
  }

  /// The projection collaborator used by [upsertEntity] to keep the local
  /// attention/standing indexes in sync. Wired by [AgentRepository] after both
  /// collaborators are constructed (Core ↔ projection form a cycle).
  late final AgentAttentionProjection projection;

  /// Run [action] inside a database transaction.
  ///
  /// All operations within the callback are committed atomically; if any
  /// operation throws, the entire transaction is rolled back. Drift supports
  /// nested transactions via savepoints.
  Future<T> runInTransaction<T>(Future<T> Function() action) async {
    // Nested calls share the outermost scope's state, so only the transaction
    // that actually commits does the invalidating.
    final inherited = Zone.current[_txnStateKey] as _TransactionState?;
    final state = inherited ?? _TransactionState();
    try {
      return await _db.transaction(
        () => runZoned(
          action,
          zoneValues: {_inTransactionKey: true, _txnStateKey: state},
        ),
      );
    } finally {
      // Invalidate once the transaction has actually committed, not just when
      // the write inside it returned. An identity write nested in a caller's
      // transaction invalidates while still uncommitted, and a concurrent
      // reader — in a different zone, so not suppressed — can repopulate the
      // cache from the pre-commit snapshot before the commit lands. Nothing
      // would invalidate again, so that stale list would be served until the
      // next identity write.
      //
      // Only when an identity was actually written: AgentSyncService routes
      // every message and state write through here, so invalidating on any
      // transaction would clear the cache continuously during a wake, exactly
      // when identities are read most.
      if (inherited == null && state.identityWritten) {
        invalidateAgentIdentitiesCache();
      }
    }
  }

  /// Runs [action] with the transaction zone values set, so
  /// [cachedAgentIdentities] knows not to publish a transaction-local read and
  /// [runInTransaction] can tell whether an identity was written.
  static Future<T> _markInTransaction<T>(Future<T> Function() action) {
    final state = Zone.current[_txnStateKey] as _TransactionState?;
    return runZoned(
      action,
      zoneValues: {_inTransactionKey: true, _txnStateKey: ?state},
    );
  }

  /// Records, per outermost transaction, whether an identity was written.
  static const _txnStateKey = #agentRepoCoreTransactionState;

  // ── Entity CRUD ────────────────────────────────────────────────────────────

  /// Insert or update an [AgentDomainEntity] using the `id` as the conflict
  /// target (ON CONFLICT DO UPDATE — updates supplied columns in place).
  ///
  /// Capture parse completion and its materialized day scope are monotonic
  /// across whole-row writes. Older peers serialize neither field, so an
  /// otherwise newer legacy rewrite must not erase a locally observed
  /// successful parse or move a near-midnight capture after a timezone change.
  Future<void> upsertEntity(AgentDomainEntity entity) async {
    if (entity is CaptureEntity) {
      await _db.transaction(
        () => _markInTransaction(() async {
          final existing = await getEntity(entity.id);
          final entityToWrite = AgentRepository.normalizeCaptureForWrite(
            entity,
            existing: existing is CaptureEntity ? existing : null,
          );
          await _upsertEntity(entityToWrite);
        }),
      );
      return;
    }
    await _upsertEntity(entity);
  }

  Future<void> _upsertEntity(AgentDomainEntity entity) async {
    // Any identity write — including a soft delete, which is an upsert with
    // `deletedAt` set — makes the cached list stale.
    //
    // Invalidated on **both** sides of the write. Before, so nothing keeps
    // serving the pre-write list. After, because a read starting inside the
    // window captures the bumped generation, reads the not-yet-committed
    // snapshot — `agent.sqlite` runs a two-isolate read pool in production —
    // and would install it; a successful write never invalidates again, so
    // that stale list would be served until the next identity write.
    //
    // Not unit-covered: reproducing the interleaving needs a real read pool,
    // and the in-memory test databases bypass pooling entirely
    // (`openDbConnection`), so an in-memory test would pass either way.
    final isIdentity = entity is AgentIdentityEntity;
    if (isIdentity) {
      invalidateAgentIdentitiesCache();
      (Zone.current[_txnStateKey] as _TransactionState?)?.identityWritten =
          true;
    }
    try {
      await _writeEntity(entity);
    } finally {
      // The write's own transaction (if any) has committed by here. When this
      // upsert is itself nested in a caller's transaction, that outer one
      // invalidates again on commit — see [runInTransaction].
      if (isIdentity) invalidateAgentIdentitiesCache();
    }
  }

  Future<void> _writeEntity(AgentDomainEntity entity) async {
    final companion = AgentDbConversions.toEntityCompanion(entity);
    final affectsAttentionClaims = affectsAttentionClaimProjection(entity);
    final affectsStandingAgreements = affectsStandingAgreementProjection(
      entity,
    );
    if (!affectsAttentionClaims && !affectsStandingAgreements) {
      await _db.into(_db.agentEntities).insertOnConflictUpdate(companion);
      return;
    }

    await _db.transaction(
      () => _markInTransaction(() async {
        await _db.into(_db.agentEntities).insertOnConflictUpdate(companion);
        if (affectsAttentionClaims) {
          await projection.refreshAttentionClaimProjectionForEntity(entity);
        }
        if (affectsStandingAgreements) {
          await projection.refreshStandingAgreementProjectionForEntity(entity);
        }
      }),
    );
  }

  /// Fetch a single entity by its [id], or `null` if not found.
  ///
  /// Calls issued within the same event-loop turn are **coalesced** into one
  /// `WHERE id IN (…)` round trip by [AgentEntityByIdCoalescer] rather than one round
  /// trip each. Callers see no behavioural difference — the returned future
  /// still completes with that id's entity or `null`.
  ///
  /// This exists because the fan-out is structural, not local: the
  /// 2026-06/07 slow-query logs captured 92,787 hits on
  /// `SELECT * FROM agent_entities WHERE id = ?` with a *median inter-arrival
  /// gap of 0.0 ms* and bursts of 606 in a single second — the signature of
  /// many independent callers (Riverpod provider families resolving one row
  /// each) firing concurrently, not of one loop that could be batched at its
  /// call site. The plan was always a clean primary-key seek; the cost was
  /// ~19 ms of isolate round trip per call. Coalescing at this layer fixes
  /// every such caller at once, including ones that have no single place to
  /// batch.
  ///
  /// See `docs/perf/2026-08-01_slow-queries-investigation.md`.
  Future<AgentDomainEntity?> getEntity(String id) => _byIdCoalescer.load(id);

  /// Batch-fetch non-deleted entities for every id in [ids]. Returns
  /// the matched entities keyed by their `id` column so the caller can
  /// look them up without iterating; ids that have no row (or whose
  /// row is soft-deleted) are simply absent from the map.
  ///
  /// Issues one `WHERE id IN (?, …)` query per
  /// [sqliteInClauseChunkSize] batch against the primary-key index
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
  Future<Map<String, AgentDomainEntity>> getEntitiesByIds(
    Iterable<String> ids,
  ) => _entitiesByIds(ids, includeDeleted: false);

  /// Like [getEntitiesByIds], but tombstoned rows are returned too (with
  /// `deletedAt` set). For callers whose write decision depends on whether a
  /// register was deliberately deleted — e.g. the week-rollup recompute must
  /// see the tombstone to avoid resurrecting it, which the deleted-filtered
  /// read structurally cannot support.
  Future<Map<String, AgentDomainEntity>> getEntitiesByIdsIncludingDeleted(
    Iterable<String> ids,
  ) => _entitiesByIds(ids, includeDeleted: true);

  Future<Map<String, AgentDomainEntity>> _entitiesByIds(
    Iterable<String> ids, {
    required bool includeDeleted,
  }) async {
    final result = <String, AgentDomainEntity>{};
    for (final chunk in sqliteInClauseChunks(ids)) {
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final deletedFilter = includeDeleted ? '' : ' AND deleted_at IS NULL';
      final rows = await _db
          .customSelect(
            'SELECT * FROM agent_entities '
            'WHERE id IN ($placeholders)$deletedFilter',
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

  /// Fetch the newest non-deleted entity per agent for [agentIds] filtered by
  /// [type] (and optionally [subtype]). Shared batched read used by the
  /// state/head latest-per-agent lookups in this class and in
  /// [AgentRepoQueries].
  /// [outerPredicate] is appended to the outer `WHERE rn = 1` — i.e. it filters
  /// the *winning* row per agent, after ranking. Filtering inside the ranked
  /// subquery instead would be a correctness bug: it could promote an older row
  /// that satisfies the predicate over a newer one that does not, resurrecting
  /// state the newest row had cleared.
  Future<List<AgentDomainEntity>> latestEntitiesByAgentIds({
    required Iterable<String> agentIds,
    required String type,
    String? subtype,
    String outerPredicate = '',
  }) async {
    final result = <AgentDomainEntity>[];
    // Every chunk binds its own ids plus the type, the optional subtype, and
    // whatever `outerPredicate` needs — all against one 999-variable budget.
    final reserved = 1 + (subtype == null ? 0 : 1);
    for (final chunk in sqliteInClauseChunks(agentIds, reserve: reserved)) {
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
                $outerPredicate
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
  /// Entities of [type] for [agentId] narrowed to one [subtype].
  ///
  /// Served by `idx_agent_entities_agent_type_sub`, so cost tracks the rows
  /// actually returned rather than everything the agent owns. This is what
  /// makes a day-scoped read of a long-lived agent's captures or status
  /// events viable — the alternative is loading the agent's whole history and
  /// filtering in Dart.
  Future<List<AgentDomainEntity>> getEntitiesByAgentIdAndSubtype(
    String agentId, {
    required String type,
    required String subtype,
    int limit = -1,
  }) async {
    final rows = await _db
        .getAgentEntitiesByTypeAndSubtype(agentId, type, subtype, limit)
        .get();
    return rows.map(AgentDbConversions.fromEntityRow).toList();
  }

  /// Entities of [type] for [agentId] whose subtype is any of [subtypes].
  ///
  /// The multi-value form of [getEntitiesByAgentIdAndSubtype], for callers
  /// that want a bounded *range* of day-scoped rows — a plan lookback window,
  /// say — in one round trip rather than one query per day.
  Future<List<AgentDomainEntity>> getEntitiesByAgentIdAndSubtypes(
    String agentId, {
    required String type,
    required Iterable<String> subtypes,
  }) async {
    final result = <AgentDomainEntity>[];
    for (final chunk in sqliteInClauseChunks(subtypes)) {
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            'SELECT * FROM agent_entities '
            'INDEXED BY idx_agent_entities_agent_type_sub '
            'WHERE agent_id = ? AND type = ? '
            'AND subtype IN ($placeholders) '
            'AND deleted_at IS NULL '
            'ORDER BY created_at DESC, id DESC',
            variables: [
              Variable.withString(agentId),
              Variable.withString(type),
              for (final subtype in chunk) Variable.withString(subtype),
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
  /// entities in [dayId] — id, workspace day, and the two timestamps that fix
  /// an event's log position — **without** materializing the large transcript.
  ///
  /// The day planner is a single long-lived agent, so its capture history grows
  /// without bound. The day-scoped subtype predicate keeps both the index walk
  /// and returned metadata bounded to the active workspace; transcripts are
  /// pulled in lazily for just the post-cutoff tail (see
  /// `AgentLogCompactor.resolveInlineContent`).
  Future<
    List<
      ({
        String id,
        String dayId,
        DateTime createdAt,
        DateTime capturedAt,
      })
    >
  >
  getCaptureEventMetaForDay({
    required String agentId,
    required String dayId,
  }) async {
    final rows = await _db
        .customSelect(
          r"SELECT id, json_extract(serialized, '$.dayId') AS day_id, "
          r"json_extract(serialized, '$.createdAt') AS created_at, "
          r"json_extract(serialized, '$.capturedAt') AS captured_at "
          'FROM agent_entities '
          'WHERE agent_id = ? AND type = ? AND subtype = ? '
          'AND deleted_at IS NULL',
          variables: [
            Variable.withString(agentId),
            Variable.withString(AgentEntityTypes.capture),
            Variable.withString(dayId),
          ],
          readsFrom: {_db.agentEntities},
        )
        .get();
    final metas =
        <
          ({
            String id,
            String dayId,
            DateTime createdAt,
            DateTime capturedAt,
          })
        >[];
    for (final row in rows) {
      final createdAtRaw = row.read<String?>('created_at');
      final capturedAtRaw = row.read<String?>('captured_at');
      if (createdAtRaw == null || capturedAtRaw == null) continue;
      final createdAt = DateTime.tryParse(createdAtRaw);
      final capturedAt = DateTime.tryParse(capturedAtRaw);
      if (createdAt == null || capturedAt == null) continue;
      metas.add((
        id: row.read<String>('id'),
        dayId: row.read<String?>('day_id') ?? '',
        createdAt: createdAt,
        capturedAt: capturedAt,
      ));
    }
    return metas;
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
    final latestEntities = await latestEntitiesByAgentIds(
      agentIds: agentIds,
      type: AgentEntityTypes.agentState,
    );
    return {
      for (final entity in latestEntities)
        if (entity case final AgentStateEntity state) state.agentId: state,
    };
  }

  /// The latest [AgentStateEntity] per agent, **restricted to agents that
  /// actually have a wake pending** — either a self-requested `nextWakeAt` or a
  /// state-level `scheduledWakeAt`.
  ///
  /// [getAgentStatesByAgentIds] returns the latest state for every agent, and
  /// the pending-wakes screen then discards the overwhelming majority of them.
  /// On an install with ~900 agents that is ~900 rows decoded from JSON on
  /// every agent-update notification; the 2026-06/07 slow-query logs show 2,050
  /// full-population reads of this shape in 14 days (`args=901`), each around
  /// 32 ms. The predicate is applied *after* ranking, so an agent whose newest
  /// state cleared its wake is correctly excluded.
  Future<Map<String, AgentStateEntity>> getAgentStatesWithPendingWakes(
    List<String> agentIds, {
    Iterable<String> alsoIncludeAgentIds = const <String>[],
  }) async {
    final withWakes = await latestEntitiesByAgentIds(
      agentIds: agentIds,
      type: AgentEntityTypes.agentState,
      outerPredicate:
          r"AND (json_extract(serialized, '$.nextWakeAt') IS NOT NULL "
          r"OR json_extract(serialized, '$.scheduledWakeAt') IS NOT NULL)",
    );
    final result = <String, AgentStateEntity>{
      for (final entity in withWakes)
        if (entity case final AgentStateEntity state) state.agentId: state,
    };

    // Agents whose wake lives in a separate `ScheduledWakeEntity` row rather
    // than on the state itself still need their state hydrated. They are read
    // as their own query rather than folded into the predicate above: an
    // inclusion list bound into every chunk shares the statement's variable
    // budget with the chunk itself, so a large enough list could overflow it
    // on a platform built with SQLite's older 999-variable cap. A second,
    // separately chunked query has no such interaction, and only runs when
    // there is something to include.
    final alsoInclude = alsoIncludeAgentIds
        .toSet()
        .where((id) => !result.containsKey(id))
        .toList(growable: false);
    if (alsoInclude.isEmpty) return result;

    final named = await latestEntitiesByAgentIds(
      agentIds: alsoInclude,
      type: AgentEntityTypes.agentState,
    );
    for (final entity in named) {
      if (entity case final AgentStateEntity state) {
        result[state.agentId] = state;
      }
    }
    return result;
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
    final latestHeads = await latestEntitiesByAgentIds(
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
}

/// Per-transaction bookkeeping for [AgentRepoCore.runInTransaction].
class _TransactionState {
  bool identityWritten = false;
}
