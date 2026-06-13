import 'package:lotti/features/agents/database/agent_database.dart'
    show WakeRunLogData;
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/service/agent_template_crud.dart';
import 'package:lotti/features/agents/service/agent_template_metrics.dart';
import 'package:lotti/features/agents/service/agent_template_seeding.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';

/// Thrown when a template cannot be deleted because active agents reference it.
class TemplateInUseException implements Exception {
  const TemplateInUseException({
    required this.templateId,
    required this.activeCount,
  });

  final String templateId;
  final int activeCount;

  @override
  String toString() =>
      'TemplateInUseException: cannot delete template $templateId — '
      '$activeCount active instance(s)';
}

/// Bundled result of [AgentTemplateService.gatherEvolutionData].
///
/// Contains all data needed to build an evolution session context, fetched
/// in parallel for efficiency.
class EvolutionDataBundle {
  const EvolutionDataBundle({
    required this.metrics,
    required this.recentVersions,
    required this.instanceReports,
    required this.instanceObservations,
    required this.pastNotes,
    required this.sessions,
    required this.observationPayloads,
    required this.changesSinceLastSession,
  });

  final TemplatePerformanceMetrics metrics;
  final List<AgentTemplateVersionEntity> recentVersions;
  final List<AgentReportEntity> instanceReports;
  final List<AgentMessageEntity> instanceObservations;
  final List<EvolutionNoteEntity> pastNotes;
  final List<EvolutionSessionEntity> sessions;
  final Map<String, AgentMessagePayloadEntity> observationPayloads;
  final int changesSinceLastSession;

  /// Compute the next session number from the existing sessions.
  int get nextSessionNumber =>
      sessions.fold(
        0,
        (max, s) => s.sessionNumber > max ? s.sessionNumber : max,
      ) +
      1;
}

/// Well-known template IDs for seeded defaults.
const lauraTemplateId = 'template-laura-001';
const tomTemplateId = 'template-tom-001';
const dayAgentTemplateId = 'template-day-agent-001';
const projectTemplateId = 'template-project-001';
const improverTemplateId = 'template-improver-001';
const metaImproverTemplateId = 'template-meta-improver-001';
const kDefaultAgentTemplateModelId = 'models/gemini-3-flash-preview';

/// High-level service for agent template management.
///
/// Provides operations for creating, versioning, listing, and managing
/// agent templates — reusable blueprints that define an agent's directives,
/// model, and category bindings.
///
/// The service is a thin facade: it instantiates three collaborators
/// ([AgentTemplateCrud], [AgentTemplateMetrics], [AgentTemplateSeeding]) and
/// delegates every public method to the one that owns it. Metrics and seeding
/// share the CRUD collaborator for template reads and version writes.
class AgentTemplateService {
  AgentTemplateService({
    required this.repository,
    required this.syncService,
  });

  final AgentRepository repository;
  final AgentSyncService syncService;

  late final AgentTemplateCrud _crud = AgentTemplateCrud(
    repository: repository,
    syncService: syncService,
  );

  late final AgentTemplateMetrics _metrics = AgentTemplateMetrics(
    repository: repository,
    syncService: syncService,
    crud: _crud,
  );

  late final AgentTemplateSeeding _seeding = AgentTemplateSeeding(
    repository: repository,
    syncService: syncService,
    crud: _crud,
  );

  // ── CRUD ────────────────────────────────────────────────────────────────

  /// Create a new template with its initial version and head pointer.
  Future<AgentTemplateEntity> createTemplate({
    required String displayName,
    required AgentTemplateKind kind,
    required String modelId,
    required String directives,
    required String authoredBy,
    String generalDirective = '',
    String reportDirective = '',
    Set<String> categoryIds = const {},
    String? templateId,
    String? profileId,
  }) => _crud.createTemplate(
    displayName: displayName,
    kind: kind,
    modelId: modelId,
    directives: directives,
    authoredBy: authoredBy,
    generalDirective: generalDirective,
    reportDirective: reportDirective,
    categoryIds: categoryIds,
    templateId: templateId,
    profileId: profileId,
  );

  /// Update template-level fields (display name, model ID).
  Future<AgentTemplateEntity> updateTemplate({
    required String templateId,
    String? displayName,
    String? modelId,
    String? profileId,
    bool clearProfileId = false,
  }) => _crud.updateTemplate(
    templateId: templateId,
    displayName: displayName,
    modelId: modelId,
    profileId: profileId,
    clearProfileId: clearProfileId,
  );

  /// Create a new version of an existing template.
  Future<AgentTemplateVersionEntity> createVersion({
    required String templateId,
    required String directives,
    required String authoredBy,
    String generalDirective = '',
    String reportDirective = '',
  }) => _crud.createVersion(
    templateId: templateId,
    directives: directives,
    authoredBy: authoredBy,
    generalDirective: generalDirective,
    reportDirective: reportDirective,
  );

  /// Fetch a single template by its [templateId].
  Future<AgentTemplateEntity?> getTemplate(String templateId) =>
      _crud.getTemplate(templateId);

  /// List all non-deleted templates.
  Future<List<AgentTemplateEntity>> listTemplates() => _crud.listTemplates();

  /// Fetch the active version for a template.
  Future<AgentTemplateVersionEntity?> getActiveVersion(String templateId) =>
      _crud.getActiveVersion(templateId);

  /// Resolve the template assigned to an agent via a templateAssignment link.
  Future<AgentTemplateEntity?> getTemplateForAgent(String agentId) =>
      _crud.getTemplateForAgent(agentId);

  /// Resolve assigned templates for multiple agents in bulk.
  Future<Map<String, AgentTemplateEntity>> getTemplatesForAgents(
    Iterable<String> agentIds,
  ) => _crud.getTemplatesForAgents(agentIds);

  /// Reverse lookup: find all agent instances assigned to a template.
  Future<List<AgentIdentityEntity>> getAgentsForTemplate(String templateId) =>
      _crud.getAgentsForTemplate(templateId);

  /// List templates whose category IDs contain [categoryId].
  Future<List<AgentTemplateEntity>> listTemplatesForCategory(
    String categoryId,
  ) => _crud.listTemplatesForCategory(categoryId);

  /// Soft-delete a template.
  Future<void> deleteTemplate(String templateId) =>
      _crud.deleteTemplate(templateId);

  /// Move the head pointer to an existing version.
  Future<void> rollbackToVersion({
    required String templateId,
    required String versionId,
  }) => _crud.rollbackToVersion(templateId: templateId, versionId: versionId);

  /// Fetch versions for a template, sorted newest-first.
  Future<List<AgentTemplateVersionEntity>> getVersionHistory(
    String templateId, {
    int limit = 100,
  }) => _crud.getVersionHistory(templateId, limit: limit);

  // ── Metrics & evolution data ──────────────────────────────────────────────

  /// Compute performance metrics for a template using SQL aggregation.
  Future<TemplatePerformanceMetrics> computeMetrics(String templateId) =>
      _metrics.computeMetrics(templateId);

  /// Return the uncapped lifetime wake count for [templateId].
  Future<int> getLifetimeWakeCount(String templateId) =>
      _metrics.getLifetimeWakeCount(templateId);

  /// Fetch wake runs for [templateId] in the inclusive `[since, until]` window.
  Future<List<WakeRunLogData>> getWakeRunsInWindow(
    String templateId, {
    required DateTime since,
    required DateTime until,
  }) => _metrics.getWakeRunsInWindow(templateId, since: since, until: until);

  /// Fetch token usage for [templateId] created on or after [since].
  Future<List<WakeTokenUsageEntity>> getTokenUsageSince(
    String templateId, {
    required DateTime since,
  }) => _metrics.getTokenUsageSince(templateId, since: since);

  /// Fetch the N most recent reports from all instances of this template.
  Future<List<AgentReportEntity>> getRecentInstanceReports(
    String templateId, {
    int limit = 10,
  }) => _metrics.getRecentInstanceReports(templateId, limit: limit);

  /// Fetch the N most recent observation messages from all instances of this
  /// template.
  Future<List<AgentMessageEntity>> getRecentInstanceObservations(
    String templateId, {
    int limit = 10,
  }) => _metrics.getRecentInstanceObservations(templateId, limit: limit);

  /// Fetch evolution notes for a template, newest-first.
  Future<List<EvolutionNoteEntity>> getRecentEvolutionNotes(
    String templateId, {
    int limit = 50,
  }) => _metrics.getRecentEvolutionNotes(templateId, limit: limit);

  /// Fetch evolution sessions for a template, newest-first.
  Future<List<EvolutionSessionEntity>> getEvolutionSessions(
    String templateId, {
    int limit = 10,
  }) => _metrics.getEvolutionSessions(templateId, limit: limit);

  /// Fetch persisted recaps for completed ritual sessions, newest-first.
  Future<List<EvolutionSessionRecapEntity>> getEvolutionSessionRecaps(
    String templateId, {
    int limit = 50,
  }) => _metrics.getEvolutionSessionRecaps(templateId, limit: limit);

  /// Fetch the recap for a single ritual session.
  Future<EvolutionSessionRecapEntity?> getEvolutionSessionRecap(
    String sessionId,
  ) => _metrics.getEvolutionSessionRecap(sessionId);

  /// Count entities changed since [since] for all instances of [templateId].
  Future<int> countChangesSince(String templateId, DateTime? since) =>
      _metrics.countChangesSince(templateId, since);

  /// Gather all data needed for an evolution session context in parallel.
  Future<EvolutionDataBundle> gatherEvolutionData(String templateId) =>
      _metrics.gatherEvolutionData(templateId);

  /// Checks whether any templates, template versions, or agent configs
  /// reference the given [profileId].
  Future<bool> profileInUse(String profileId) =>
      _metrics.profileInUse(profileId);

  // ── Seeding ───────────────────────────────────────────────────────────────

  /// Idempotent seed of default templates.
  Future<void> seedDefaults() => _seeding.seedDefaults();

  /// Populate `generalDirective` and `reportDirective` on existing template
  /// versions where both fields are empty.
  Future<void> seedDirectiveFields() => _seeding.seedDirectiveFields();

  /// Advances existing Shepherd templates to the capture/reconcile directive.
  Future<void> seedDayAgentCaptureReconcileDirective() =>
      _seeding.seedDayAgentCaptureReconcileDirective();
}
