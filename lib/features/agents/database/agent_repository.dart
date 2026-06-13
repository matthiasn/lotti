import 'package:lotti/features/agents/database/agent_attention_projection.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_proposal_ledger.dart';
import 'package:lotti/features/agents/database/agent_repo_core.dart';
import 'package:lotti/features/agents/database/agent_repo_evolution.dart';
import 'package:lotti/features/agents/database/agent_repo_internals.dart';
import 'package:lotti/features/agents/database/agent_repo_links.dart';
import 'package:lotti/features/agents/database/agent_repo_queries.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:meta/meta.dart';

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
  final AgentProposalLedger _ledger;
  late final AgentAttentionProjection _projection;
  late final AgentRepoQueries _queries;
  late final AgentRepoEvolution _evolution;

  /// Test-only seam for `sqliteInClauseChunks` — the pure dedup-and-chunk
  /// iterator that guards every batched `IN (...)` query against SQLite's
  /// `SQLITE_MAX_VARIABLE_NUMBER` cap. The chunk size is exposed alongside so
  /// property tests can assert the no-chunk-exceeds-the-limit invariant
  /// without hard-coding the constant.
  @visibleForTesting
  static const int debugInClauseChunkSize = sqliteInClauseChunkSize;

  /// Test-only seam for `sqliteInClauseChunks`.
  @visibleForTesting
  static Iterable<List<T>> debugSqliteInClauseChunks<T>(Iterable<T> values) =>
      sqliteInClauseChunks(values);

  // ── Core: entity CRUD + shared batched reads ───────────────────────────────

  Future<T> runInTransaction<T>(Future<T> Function() action) =>
      _core.runInTransaction(action);

  Future<void> upsertEntity(AgentDomainEntity entity) =>
      _core.upsertEntity(entity);

  Future<AgentDomainEntity?> getEntity(String id) => _core.getEntity(id);

  Future<Map<String, AgentDomainEntity>> getEntitiesByIds(
    Iterable<String> ids,
  ) => _core.getEntitiesByIds(ids);

  Future<List<AgentDomainEntity>> getEntitiesByAgentId(
    String agentId, {
    String? type,
    int limit = -1,
  }) => _core.getEntitiesByAgentId(agentId, type: type, limit: limit);

  Future<List<({String id, DateTime createdAt, DateTime capturedAt})>>
  getCaptureEventMetaByAgentId(String agentId) =>
      _core.getCaptureEventMetaByAgentId(agentId);

  Future<AgentStateEntity?> getAgentState(String agentId) =>
      _core.getAgentState(agentId);

  Future<List<AgentMessageEntity>> getAgentMessages(String agentId) =>
      _core.getAgentMessages(agentId);

  Future<Map<String, AgentStateEntity>> getAgentStatesByAgentIds(
    List<String> agentIds,
  ) => _core.getAgentStatesByAgentIds(agentIds);

  Future<AgentIdentityEntity?> getActiveAgentByKindAndActiveDayId({
    required String kind,
    required String activeDayId,
  }) => _core.getActiveAgentByKindAndActiveDayId(
    kind: kind,
    activeDayId: activeDayId,
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

  Future<List<StandingAgreementEntity>> getStandingAgreementsForWindow({
    required DateTime start,
    required DateTime end,
    Set<StandingAgreementStatus> statuses = const {
      StandingAgreementStatus.active,
    },
    Set<StandingAgreementScope>? scopes,
    int limit = 200,
  }) => _projection.getStandingAgreementsForWindow(
    start: start,
    end: end,
    statuses: statuses,
    scopes: scopes,
    limit: limit,
  );

  Future<void> rebuildAttentionClaimProjection() =>
      _projection.rebuildAttentionClaimProjection();

  Future<void> rebuildStandingAgreementProjection() =>
      _projection.rebuildStandingAgreementProjection();

  // ── Queries: reports, templates, soul documents, messages ──────────────────

  Future<List<AgentMessageEntity>> getMessagesByKind(
    String agentId,
    AgentMessageKind kind, {
    int? limit,
  }) => _queries.getMessagesByKind(agentId, kind, limit: limit);

  Future<List<AgentMessageEntity>> getMessagesForThread(
    String agentId,
    String threadId, {
    int? limit,
  }) => _queries.getMessagesForThread(agentId, threadId, limit: limit);

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

  Future<List<AgentDomainEntity>> getEntitiesWithNullVectorClock() =>
      _evolution.getEntitiesWithNullVectorClock();

  Future<int> countEntitiesWithNullVectorClock() =>
      _evolution.countEntitiesWithNullVectorClock();

  Future<List<AgentDomainEntity>> getAllEntities() =>
      _evolution.getAllEntities();

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

  Future<EvolutionSessionRecapEntity?> getEvolutionSessionRecap(
    String sessionId,
  ) => _evolution.getEvolutionSessionRecap(sessionId);

  Future<List<EvolutionNoteEntity>> getEvolutionNotes(
    String templateId, {
    int limit = 50,
  }) => _evolution.getEvolutionNotes(templateId, limit: limit);

  Future<int> countChangedSinceForTemplate(
    String templateId,
    DateTime? since,
  ) => _evolution.countChangedSinceForTemplate(templateId, since);

  Future<void> updateWakeRunRating(
    String runKey, {
    required double rating,
    required DateTime ratedAt,
  }) =>
      _evolution.updateWakeRunRating(runKey, rating: rating, ratedAt: ratedAt);

  Future<List<ChangeSetEntity>> getPendingChangeSets(
    String agentId, {
    String? taskId,
    int limit = 20,
  }) => _evolution.getPendingChangeSets(agentId, taskId: taskId, limit: limit);

  Future<List<ChangeDecisionEntity>> getRecentDecisions(
    String agentId, {
    String? taskId,
    int limit = 20,
  }) => _evolution.getRecentDecisions(agentId, taskId: taskId, limit: limit);

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

  Future<List<model.AgentLink>> getAllLinks() => _links.getAllLinks();

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

  Future<List<WakeRunLogData>> getWakeRunsInWindow({
    required DateTime since,
    required DateTime until,
  }) => _links.getWakeRunsInWindow(since: since, until: until);

  Future<WakeRunLogData?> getWakeRun(String runKey) =>
      _links.getWakeRun(runKey);

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

  Future<List<WakeTokenUsageEntity>> getTokenUsageForTemplateSince(
    String templateId, {
    required DateTime since,
  }) => _links.getTokenUsageForTemplateSince(templateId, since: since);

  Future<List<WakeTokenUsageEntity>> getGlobalTokenUsageSince({
    required DateTime since,
  }) => _links.getGlobalTokenUsageSince(since: since);

  Future<int> abandonOrphanedWakeRuns() => _links.abandonOrphanedWakeRuns();

  Future<void> insertSagaOp({required SagaLogData entry}) =>
      _links.insertSagaOp(entry: entry);

  Future<void> updateSagaStatus(
    String operationId,
    String status, {
    String? lastError,
  }) => _links.updateSagaStatus(operationId, status, lastError: lastError);

  Future<List<SagaLogData>> getPendingSagaOps() => _links.getPendingSagaOps();

  Future<void> hardDeleteAgent(String agentId) =>
      _links.hardDeleteAgent(agentId);
}
