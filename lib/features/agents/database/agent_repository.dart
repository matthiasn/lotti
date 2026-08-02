import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/database/agent_attention_projection.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_proposal_ledger.dart';
import 'package:lotti/features/agents/database/agent_repo_core.dart';
import 'package:lotti/features/agents/database/agent_repo_evolution.dart';
import 'package:lotti/features/agents/database/agent_repo_links.dart';
import 'package:lotti/features/agents/database/agent_repo_observation_retention.dart';
import 'package:lotti/features/agents/database/agent_repo_queries.dart';
import 'package:lotti/features/agents/database/agent_repo_retention.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/services/domain_logging.dart';

/// The claim and standing-agreement inputs a day planner needs for a window,
/// returned by [AgentRepository.getAttentionPlanningInputsForWindow].
class AttentionPlanningInputs {
  const AttentionPlanningInputs({
    required this.claims,
    required this.standingAgreements,
  });

  const AttentionPlanningInputs.empty()
    : claims = const [],
      standingAgreements = const [];

  final List<AttentionRequestEntity> claims;
  final List<StandingAgreementEntity> standingAgreements;

  bool get isEmpty => claims.isEmpty && standingAgreements.isEmpty;
}

/// Typed CRUD repository wrapping [AgentDatabase] and `AgentDbConversions`.
///
/// The repository is a thin delegating facade: every public method forwards to
/// one of the collaborator classes in this directory, each of which owns a
/// cohesive slice of the persistence surface:
///
///  * [AgentRepoCore] — entity CRUD, transactions, shared batched reads.
///  * [AgentRepoQueries] — report/template/soul-document/message queries.
///  * [AgentRepoEvolution] — evolution sessions, scheduled wakes, change sets.
///  * [AgentRepoLinks] — link CRUD, wake-run log, saga log, hard delete.
///  * [AgentRepoRetention] — batched hard deletes of derived rows past the
///    retention policy.
///  * [AgentAttentionProjection] — attention-claim / standing-agreement
///    projection reads plus the rebuild/refresh machinery.
///  * [AgentProposalLedger] — the proposal-ledger assembly query.
///
/// All entity reads go through `AgentDbConversions.fromEntityRow` and all
/// entity writes through `AgentDbConversions.toEntityCompanion`. Link reads go
/// through `AgentDbConversions.fromLinkRow` and link writes through
/// `AgentDbConversions.toLinkCompanion`. Wake-run log and saga log rows are
/// plain Drift data classes and are read and written directly without an
/// intermediate domain conversion.
class AgentRepository {
  AgentRepository(AgentDatabase db, {DomainLogger? domainLogger})
    : _core = AgentRepoCore(db),
      _links = AgentRepoLinks(db, domainLogger),
      _retention = AgentRepoRetention(db),
      _observationRetention = AgentRepoObservationRetention(db),
      _ledger = AgentProposalLedger(db) {
    // Core ↔ projection form a cycle: the projection hydrates source rows via
    // `core.getEntitiesByIds`, and `core.upsertEntity` refreshes the projection
    // after writes. Construct the projection with core, then wire it back into
    // core's late field.
    _projection = AgentAttentionProjection(db, _core);
    _core.projection = _projection;
    _queries = AgentRepoQueries(db, _core, _links);
    _evolution = AgentRepoEvolution(db, _core, _ledger);
  }

  final AgentRepoCore _core;
  final AgentRepoLinks _links;
  final AgentRepoRetention _retention;
  final AgentRepoObservationRetention _observationRetention;
  final AgentProposalLedger _ledger;
  late final AgentAttentionProjection _projection;
  late final AgentRepoQueries _queries;
  late final AgentRepoEvolution _evolution;

  /// Returns the monotonic capture representation shared by persistence and
  /// sync-envelope creation.
  ///
  /// Older peers may omit both `dayId` and `parseCompletedAt`. Preserve the
  /// locally materialized values when present; otherwise derive the capture
  /// day exactly once from its timestamp.
  static CaptureEntity normalizeCaptureForWrite(
    CaptureEntity entity, {
    CaptureEntity? existing,
  }) {
    final stableDayId = entity.dayId.isNotEmpty
        ? entity.dayId
        : existing != null && existing.dayId.isNotEmpty
        ? existing.dayId
        : dayAgentIdForDate(entity.capturedAt);
    return entity.copyWith(
      dayId: stableDayId,
      parseCompletedAt: entity.parseCompletedAt ?? existing?.parseCompletedAt,
    );
  }

  // ── Core: entity CRUD + shared batched reads ───────────────────────────────

  Future<T> runInTransaction<T>(Future<T> Function() action) =>
      _core.runInTransaction(action);

  Future<void> upsertEntity(AgentDomainEntity entity) =>
      _core.upsertEntity(entity);

  Future<AgentDomainEntity?> getEntity(String id) => _core.getEntity(id);

  Future<Map<String, AgentDomainEntity>> getEntitiesByIds(
    Iterable<String> ids,
  ) => _core.getEntitiesByIds(ids);

  Future<Map<String, AgentDomainEntity>> getEntitiesByIdsIncludingDeleted(
    Iterable<String> ids,
  ) => _core.getEntitiesByIdsIncludingDeleted(ids);

  Future<List<AgentDomainEntity>> getEntitiesByAgentId(
    String agentId, {
    String? type,
    int limit = -1,
  }) => _core.getEntitiesByAgentId(agentId, type: type, limit: limit);

  /// Entities of [type] for [agentId] narrowed to one [subtype], served by the
  /// `(agent_id, type, subtype, …)` index.
  Future<List<AgentDomainEntity>> getEntitiesByAgentIdAndSubtype(
    String agentId, {
    required String type,
    required String subtype,
    int limit = -1,
  }) => _core.getEntitiesByAgentIdAndSubtype(
    agentId,
    type: type,
    subtype: subtype,
    limit: limit,
  );

  /// Entities of [type] for [agentId] whose subtype is any of [subtypes].
  Future<List<AgentDomainEntity>> getEntitiesByAgentIdAndSubtypes(
    String agentId, {
    required String type,
    required Iterable<String> subtypes,
  }) => _core.getEntitiesByAgentIdAndSubtypes(
    agentId,
    type: type,
    subtypes: subtypes,
  );

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
  }) => _core.getCaptureEventMetaForDay(agentId: agentId, dayId: dayId);

  Future<AgentStateEntity?> getAgentState(String agentId) =>
      _core.getAgentState(agentId);

  Future<List<AgentMessageEntity>> getAgentMessages(String agentId) =>
      _core.getAgentMessages(agentId);

  Future<Map<String, AgentStateEntity>> getAgentStatesByAgentIds(
    List<String> agentIds,
  ) => _core.getAgentStatesByAgentIds(agentIds);

  /// Latest state per agent, restricted to agents with a pending wake.
  /// See [AgentRepoCore.getAgentStatesWithPendingWakes].
  Future<Map<String, AgentStateEntity>> getAgentStatesWithPendingWakes(
    List<String> agentIds, {
    Iterable<String> alsoIncludeAgentIds = const <String>[],
  }) => _core.getAgentStatesWithPendingWakes(
    agentIds,
    alsoIncludeAgentIds: alsoIncludeAgentIds,
  );

  Future<Map<String, SoulDocumentVersionEntity>>
  getActiveSoulDocumentVersionsBySoulIds(List<String> soulIds) =>
      _core.getActiveSoulDocumentVersionsBySoulIds(soulIds);

  // ── Attention / standing-agreement projection ──────────────────────────────

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
  }) => _projection.getAttentionClaimsForWindow(
    start: start,
    end: end,
    statuses: statuses,
    limit: limit,
  );

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
  }) => _projection.getAttentionClaimsForTarget(
    targetKind: targetKind,
    targetId: targetId,
    statuses: statuses,
    limit: limit,
  );

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
  }) => _projection.getAttentionPlanningInputsForWindow(
    start: start,
    end: end,
    claimStatuses: claimStatuses,
    agreementStatuses: agreementStatuses,
    agreementScopes: agreementScopes,
    claimLimit: claimLimit,
    agreementLimit: agreementLimit,
  );

  // ── Queries: reports, templates, soul documents, messages ──────────────────

  Future<List<AgentMessageEntity>> getMessagesByKind(
    String agentId,
    AgentMessageKind kind, {
    int? limit,
  }) => _queries.getMessagesByKind(agentId, kind, limit: limit);

  Future<List<DayStatusEventEntity>> getDayStatusEventsSince(
    DateTime since, {
    int? limit,
  }) => _queries.getDayStatusEventsSince(since, limit: limit);

  Future<List<DayStatusEventEntity>> getDayStatusEventsSinceNewestFirst(
    DateTime since, {
    required int limit,
  }) => _queries.getDayStatusEventsSinceNewestFirst(since, limit: limit);

  Future<AgentReportEntity?> getLatestReport(String agentId, String scope) =>
      _queries.getLatestReport(agentId, scope);

  Future<Map<String, AgentReportEntity>> getLatestReportsByAgentIds(
    List<String> agentIds,
    String scope,
  ) => _queries.getLatestReportsByAgentIds(agentIds, scope);

  Future<AgentReportEntity?> getLatestProjectReportForProjectId(
    String projectId,
  ) => _queries.getLatestProjectReportForProjectId(projectId);

  Future<Map<String, AgentReportEntity>> getLatestTaskReportsForTaskIds(
    List<String> taskIds,
  ) => _queries.getLatestTaskReportsForTaskIds(taskIds);

  Future<AgentReportHeadEntity?> getReportHead(String agentId, String scope) =>
      _queries.getReportHead(agentId, scope);

  Future<List<AgentTemplateEntity>> getAllTemplates() =>
      _queries.getAllTemplates();

  Future<AgentTemplateHeadEntity?> getTemplateHead(String templateId) =>
      _queries.getTemplateHead(templateId);

  Future<AgentTemplateVersionEntity?> getActiveTemplateVersion(
    String templateId,
  ) => _queries.getActiveTemplateVersion(templateId);

  Future<int> getNextTemplateVersionNumber(String templateId) =>
      _queries.getNextTemplateVersionNumber(templateId);

  Future<SoulDocumentEntity?> getSoulDocument(String soulId) =>
      _queries.getSoulDocument(soulId);

  Future<List<SoulDocumentEntity>> getAllSoulDocuments() =>
      _queries.getAllSoulDocuments();

  Future<SoulDocumentHeadEntity?> getSoulDocumentHead(String soulId) =>
      _queries.getSoulDocumentHead(soulId);

  Future<SoulDocumentVersionEntity?> getActiveSoulDocumentVersion(
    String soulId,
  ) => _queries.getActiveSoulDocumentVersion(soulId);

  Future<List<SoulDocumentVersionEntity>> getSoulDocumentVersions(
    String soulId, {
    int limit = -1,
  }) => _queries.getSoulDocumentVersions(soulId, limit: limit);

  Future<int> getNextSoulDocumentVersionNumber(String soulId) =>
      _queries.getNextSoulDocumentVersionNumber(soulId);

  Future<void> updateWakeRunTemplate(
    String runKey,
    String templateId,
    String templateVersionId, {
    String? resolvedModelId,
    String? soulId,
    String? soulVersionId,
  }) => _queries.updateWakeRunTemplate(
    runKey,
    templateId,
    templateVersionId,
    resolvedModelId: resolvedModelId,
    soulId: soulId,
    soulVersionId: soulVersionId,
  );

  // ── Evolution: sessions, scheduled wakes, change sets ──────────────────────

  Future<List<AgentStateEntity>> getDueScheduledAgentStates(DateTime now) =>
      _evolution.getDueScheduledAgentStates(now);

  Future<List<ScheduledWakeEntity>> getDueScheduledWakeRecords(DateTime now) =>
      _evolution.getDueScheduledWakeRecords(now);

  Future<List<ScheduledWakeEntity>> getPendingScheduledWakeRecords() =>
      _evolution.getPendingScheduledWakeRecords();

  Future<List<AgentIdentityEntity>> getAllAgentIdentities() =>
      _evolution.getAllAgentIdentities();

  Future<List<AgentIdentityEntity>> getAgentIdentitiesByLifecycle(
    AgentLifecycle lifecycle,
  ) => _evolution.getAgentIdentitiesByLifecycle(lifecycle);

  Future<List<AgentDomainEntity>> getEntitiesWithNullVectorClock() =>
      _evolution.getEntitiesWithNullVectorClock();

  Future<int> countEntitiesWithNullVectorClock() =>
      _evolution.countEntitiesWithNullVectorClock();

  Future<List<AgentDomainEntity>> getEntitiesInInterval({
    required DateTime start,
    required DateTime end,
    required int limit,
    required int offset,
  }) => _evolution.getEntitiesInInterval(
    start: start,
    end: end,
    limit: limit,
    offset: offset,
  );

  Future<int> countEntitiesInInterval({
    required DateTime start,
    required DateTime end,
  }) => _evolution.countEntitiesInInterval(start: start, end: end);

  Future<int> countEntitiesByType({required String type}) =>
      _evolution.countEntitiesByType(type: type);

  Future<List<AgentReportEntity>> getRecentReportsByTemplate(
    String templateId, {
    int limit = 10,
  }) => _evolution.getRecentReportsByTemplate(templateId, limit: limit);

  Future<List<AgentMessageEntity>> getRecentObservationsByTemplate(
    String templateId, {
    int limit = 10,
  }) => _evolution.getRecentObservationsByTemplate(templateId, limit: limit);

  Future<List<EvolutionSessionEntity>> getEvolutionSessions(
    String templateId, {
    int limit = 10,
  }) => _evolution.getEvolutionSessions(templateId, limit: limit);

  Future<List<EvolutionSessionEntity>> getAllEvolutionSessions() =>
      _evolution.getAllEvolutionSessions();

  Future<List<EvolutionSessionRecapEntity>> getEvolutionSessionRecaps(
    String templateId, {
    int limit = 50,
  }) => _evolution.getEvolutionSessionRecaps(templateId, limit: limit);

  Future<List<EvolutionNoteEntity>> getEvolutionNotes(
    String templateId, {
    int limit = 50,
  }) => _evolution.getEvolutionNotes(templateId, limit: limit);

  Future<int> countChangedSinceForTemplate(
    String templateId,
    DateTime? since,
  ) => _evolution.countChangedSinceForTemplate(templateId, since);

  Future<List<ChangeSetEntity>> getPendingChangeSets(
    String agentId, {
    String? taskId,
    int limit = 20,
  }) => _evolution.getPendingChangeSets(agentId, taskId: taskId, limit: limit);

  Future<ProposalLedger> getProposalLedger(
    String agentId, {
    required String taskId,
    int changeSetFetchLimit = 200,
    int resolvedLimit = 50,
  }) => _evolution.getProposalLedger(
    agentId,
    taskId: taskId,
    changeSetFetchLimit: changeSetFetchLimit,
    resolvedLimit: resolvedLimit,
  );

  Future<List<ChangeDecisionEntity>> getRecentDecisionsForTemplate(
    String templateId, {
    required DateTime since,
    int limit = 500,
  }) => _evolution.getRecentDecisionsForTemplate(
    templateId,
    since: since,
    limit: limit,
  );

  Future<model.AgentLink?> getLinkById(String id) => _evolution.getLinkById(id);

  // ── Links: link CRUD, wake-run log, saga log, hard delete ──────────────────

  Future<void> upsertLink(model.AgentLink link) => _links.upsertLink(link);

  Future<void> insertLinkExclusive(model.AgentLink link) =>
      _links.insertLinkExclusive(link);

  Future<List<model.AgentLink>> getLinksFrom(String fromId, {String? type}) =>
      _links.getLinksFrom(fromId, type: type);

  Future<List<model.AgentLink>> getLinksTo(String toId, {String? type}) =>
      _links.getLinksTo(toId, type: type);

  Future<Map<String, List<model.AgentLink>>> getLinksToMultiple(
    List<String> toIds, {
    required String type,
  }) => _links.getLinksToMultiple(toIds, type: type);

  Future<Map<String, List<model.AgentLink>>> getLinksFromMultiple(
    List<String> fromIds, {
    required String type,
  }) => _links.getLinksFromMultiple(fromIds, type: type);

  Future<List<model.AgentLink>> getLinksWithNullVectorClock() =>
      _links.getLinksWithNullVectorClock();

  Future<Set<String>> getTaskIdsWithAgentLink() =>
      _links.getTaskIdsWithAgentLink();

  Future<int> countLinksWithNullVectorClock() =>
      _links.countLinksWithNullVectorClock();

  Future<List<model.AgentLink>> getLinksInInterval({
    required DateTime start,
    required DateTime end,
    required int limit,
    required int offset,
  }) => _links.getLinksInInterval(
    start: start,
    end: end,
    limit: limit,
    offset: offset,
  );

  Future<int> countLinksInInterval({
    required DateTime start,
    required DateTime end,
  }) => _links.countLinksInInterval(start: start, end: end);

  Future<void> insertWakeRun({required WakeRunLogData entry}) =>
      _links.insertWakeRun(entry: entry);

  Future<void> updateWakeRunStatus(
    String runKey,
    String status, {
    DateTime? startedAt,
    DateTime? completedAt,
    String? errorMessage,
  }) => _links.updateWakeRunStatus(
    runKey,
    status,
    startedAt: startedAt,
    completedAt: completedAt,
    errorMessage: errorMessage,
  );

  Future<List<WakeRunLogData>> getWakeRunsForTemplate(
    String templateId, {
    int limit = 500,
  }) => _links.getWakeRunsForTemplate(templateId, limit: limit);

  Future<int> countWakeRunsForTemplate(String templateId) =>
      _links.countWakeRunsForTemplate(templateId);

  Future<AggregateWakeRunMetricsByTemplateIdResult> aggregateWakeRunMetrics(
    String templateId,
  ) => _links.aggregateWakeRunMetrics(templateId);

  Future<SumTokenUsageByTemplateResult> sumTokenUsageForTemplate(
    String templateId,
  ) => _links.sumTokenUsageForTemplate(templateId);

  Future<SumTokenUsageByTemplateSinceResult> sumTokenUsageForTemplateSince(
    String templateId, {
    required DateTime since,
  }) => _links.sumTokenUsageForTemplateSince(templateId, since: since);

  Future<List<WakeRunLogData>> getWakeRunsForTemplateInWindow(
    String templateId, {
    required DateTime since,
    required DateTime until,
  }) => _links.getWakeRunsForTemplateInWindow(
    templateId,
    since: since,
    until: until,
  );

  Future<WakeRunLogData?> getWakeRunByThreadId(
    String agentId,
    String threadId,
  ) => _links.getWakeRunByThreadId(agentId, threadId);

  Future<List<WakeTokenUsageEntity>> getTokenUsageForAgent(
    String agentId, {
    int limit = 500,
  }) => _links.getTokenUsageForAgent(agentId, limit: limit);

  Future<List<WakeTokenUsageEntity>> getTokenUsageForTemplate(
    String templateId, {
    int limit = 10000,
  }) => _links.getTokenUsageForTemplate(templateId, limit: limit);

  Future<int> abandonOrphanedWakeRuns() => _links.abandonOrphanedWakeRuns();

  /// Permanently deletes every row for [agentId].
  ///
  /// Deletes rows directly rather than through `upsertEntity`, so it must drop
  /// the cached identity list itself — otherwise the destroyed agent keeps
  /// appearing in [getAllAgentIdentities] until an unrelated identity write
  /// happens to invalidate it.
  Future<({List<String> entityIds, List<String> linkIds})> hardDeleteAgent(
    String agentId,
  ) async {
    final removed = await _links.hardDeleteAgent(agentId);
    _core.invalidateAgentIdentitiesCache();
    return removed;
  }

  // ── Retention ───────────────────────────────────────────────────────────

  /// Deletes day-status events created before [cutoff], keeping each day's
  /// newest. Returns the removed ids so their sidecars can be reclaimed.
  Future<List<String>> pruneDayStatusEventsBefore(
    DateTime cutoff, {
    required int batchSize,
    required int maxBatches,
  }) => _retention.pruneDayStatusEventsBefore(
    cutoff,
    batchSize: batchSize,
    maxBatches: maxBatches,
  );

  /// Agents holding at least one observation older than [cutoff], after
  /// [afterAgentId] in id order.
  Future<List<String>> agentsWithAgedObservations(
    DateTime cutoff, {
    required int limit,
    String? afterAgentId,
  }) => _observationRetention.agentsWithAgedObservations(
    cutoff,
    limit: limit,
    afterAgentId: afterAgentId,
  );

  /// Prunes one agent's aged observations and the `messagePrev` edges into
  /// them. Returns the removed ids so their sidecars can be reclaimed.
  Future<ObservationSweepResult> pruneAgentObservations({
    required String agentId,
    required DateTime cutoff,
    required int limit,
    required int maxMessages,
  }) => _observationRetention.pruneAgent(
    agentId: agentId,
    cutoff: cutoff,
    limit: limit,
    maxMessages: maxMessages,
  );
}
