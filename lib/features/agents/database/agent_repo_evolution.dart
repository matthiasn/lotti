import 'package:drift/drift.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_db_conversions.dart';
import 'package:lotti/features/agents/database/agent_proposal_ledger.dart';
import 'package:lotti/features/agents/database/agent_repo_core.dart';
import 'package:lotti/features/agents/database/agent_repo_internals.dart';
import 'package:lotti/features/agents/database/agent_repository.dart'
    show AgentRepository;
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/agents/model/proposal_ledger.dart';

/// Evolution-session, scheduled-wake, change-set, and link-discovery queries of
/// [AgentRepository]. Collaborator extracted from the former
/// `_AgentRepoEvolution` mixin; the repository keeps thin delegators so mocks
/// keep intercepting.
///
/// Depends on [AgentRepoCore] for entity hydration and on
/// [AgentProposalLedger] for the heavy proposal-ledger assembly exposed via
/// [getProposalLedger].
class AgentRepoEvolution {
  AgentRepoEvolution(this._db, this._core, this._ledger);

  final AgentDatabase _db;
  final AgentRepoCore _core;
  final AgentProposalLedger _ledger;

  /// Agent states whose self-scheduled `scheduledWakeAt` is at or before [now],
  /// i.e. the state-level scheduled wakes the manager should enqueue. For the
  /// separate workspace-scoped wake records see [getPendingScheduledWakeRecords].
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

  /// Fetch pending [ScheduledWakeEntity] records whose `scheduledAt` is at or
  /// before [now] (ADR 0022 Decision 12).
  ///
  /// Unlike [getDueScheduledAgentStates] these carry an explicit workspace key
  /// and trigger tokens, so a day-scoped wake (e.g. the morning pre-warm)
  /// restores with full day context instead of riding the single, clobberable
  /// `AgentStateEntity.scheduledWakeAt`.
  Future<List<ScheduledWakeEntity>> getDueScheduledWakeRecords(
    DateTime now,
  ) async {
    final rows = await _db
        .getDueScheduledWakeRecords(now.toIso8601String())
        .get();
    return rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<ScheduledWakeEntity>()
        .toList();
  }

  /// Fetch all still-pending [ScheduledWakeEntity] records regardless of when
  /// they fire, ordered by `scheduledAt`.
  ///
  /// Unlike [getDueScheduledWakeRecords] (which bounds on `scheduledAt <= now`
  /// to fire wakes), this surfaces future records too — it backs the
  /// Settings → Agents → Pending Wakes diagnostic list, where the planner's
  /// outstanding day pre-warms must be visible before they come due.
  Future<List<ScheduledWakeEntity>> getPendingScheduledWakeRecords() async {
    final rows = await _db.getPendingScheduledWakeRecords().get();
    return rows
        .map(AgentDbConversions.fromEntityRow)
        .whereType<ScheduledWakeEntity>()
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
    final entity = await _core.getEntity(evolutionSessionRecapId(sessionId));
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
    final dbLimit = taskId != null ? limit * overFetchMultiplier : limit;
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
    final dbLimit = taskId != null ? limit * overFetchMultiplier : limit;
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

  /// Build a [ProposalLedger] for [taskId] under [agentId]. See
  /// [AgentProposalLedger.getProposalLedger].
  Future<ProposalLedger> getProposalLedger(
    String agentId, {
    required String taskId,
    int changeSetFetchLimit = 200,
    int resolvedLimit = 50,
  }) => _ledger.getProposalLedger(
    agentId,
    taskId: taskId,
    changeSetFetchLimit: changeSetFetchLimit,
    resolvedLimit: resolvedLimit,
  );

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
}
