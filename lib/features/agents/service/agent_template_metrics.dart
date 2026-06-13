import 'package:lotti/features/agents/database/agent_database.dart'
    show WakeRunLogData;
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/service/agent_template_crud.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';

/// Performance metrics and evolution-data gathering for agent templates.
///
/// Computes per-template wake metrics via SQL aggregation and fetches the
/// reports, observations, notes, sessions, and change counts needed to build
/// an evolution session context. Shared reads (template version history,
/// linked agents) are delegated to [AgentTemplateCrud].
class AgentTemplateMetrics {
  AgentTemplateMetrics({
    required this.repository,
    required this.syncService,
    required this.crud,
  });

  final AgentRepository repository;
  final AgentSyncService syncService;
  final AgentTemplateCrud crud;

  /// Compute performance metrics for a template using SQL aggregation.
  ///
  /// All counts, sums, and min/max timestamps are computed in a single
  /// database query, avoiding the need to load all rows into memory.
  Future<TemplatePerformanceMetrics> computeMetrics(
    String templateId,
  ) async {
    final (agg, agents, totalWakes) = await (
      repository.aggregateWakeRunMetrics(templateId),
      crud.getAgentsForTemplate(templateId),
      repository.countWakeRunsForTemplate(templateId),
    ).wait;

    final terminalCount = agg.successCount + agg.failureCount;
    final successRate = terminalCount > 0
        ? agg.successCount / terminalCount
        : 0.0;
    final durationSumMs = agg.durationSumMs ?? 0;
    final averageDuration = agg.durationCount > 0
        ? Duration(milliseconds: durationSumMs ~/ agg.durationCount)
        : null;

    return TemplatePerformanceMetrics(
      templateId: templateId,
      totalWakes: totalWakes,
      successCount: agg.successCount,
      failureCount: agg.failureCount,
      successRate: successRate,
      averageDuration: averageDuration,
      firstWakeAt: agg.firstWakeAt,
      lastWakeAt: agg.lastWakeAt,
      activeInstanceCount: agents
          .where((a) => a.lifecycle == AgentLifecycle.active)
          .length,
    );
  }

  /// Return the uncapped lifetime wake count for [templateId].
  Future<int> getLifetimeWakeCount(String templateId) {
    return repository.countWakeRunsForTemplate(templateId);
  }

  /// Fetch wake runs for [templateId] in the inclusive `[since, until]`
  /// window.
  Future<List<WakeRunLogData>> getWakeRunsInWindow(
    String templateId, {
    required DateTime since,
    required DateTime until,
  }) {
    return repository.getWakeRunsForTemplateInWindow(
      templateId,
      since: since,
      until: until,
    );
  }

  /// Fetch token usage for [templateId] created on or after [since].
  Future<List<WakeTokenUsageEntity>> getTokenUsageSince(
    String templateId, {
    required DateTime since,
  }) {
    return repository.getTokenUsageForTemplateSince(
      templateId,
      since: since,
    );
  }

  // ── Evolution data fetching ─────────────────────────────────────────────

  /// Fetch the N most recent reports from all instances of this template.
  Future<List<AgentReportEntity>> getRecentInstanceReports(
    String templateId, {
    int limit = 10,
  }) {
    return repository.getRecentReportsByTemplate(templateId, limit: limit);
  }

  /// Fetch the N most recent observation messages from all instances of this
  /// template.
  Future<List<AgentMessageEntity>> getRecentInstanceObservations(
    String templateId, {
    int limit = 10,
  }) {
    return repository.getRecentObservationsByTemplate(templateId, limit: limit);
  }

  /// Fetch evolution notes for a template, newest-first.
  Future<List<EvolutionNoteEntity>> getRecentEvolutionNotes(
    String templateId, {
    int limit = 50,
  }) {
    return repository.getEvolutionNotes(templateId, limit: limit);
  }

  /// Fetch evolution sessions for a template, newest-first.
  Future<List<EvolutionSessionEntity>> getEvolutionSessions(
    String templateId, {
    int limit = 10,
  }) {
    return repository.getEvolutionSessions(templateId, limit: limit);
  }

  /// Fetch persisted recaps for completed ritual sessions, newest-first.
  Future<List<EvolutionSessionRecapEntity>> getEvolutionSessionRecaps(
    String templateId, {
    int limit = 50,
  }) {
    return repository.getEvolutionSessionRecaps(templateId, limit: limit);
  }

  /// Fetch the recap for a single ritual session.
  Future<EvolutionSessionRecapEntity?> getEvolutionSessionRecap(
    String sessionId,
  ) {
    return repository.getEvolutionSessionRecap(sessionId);
  }

  /// Count entities changed since [since] for all instances of [templateId].
  Future<int> countChangesSince(String templateId, DateTime? since) {
    return repository.countChangedSinceForTemplate(templateId, since);
  }

  /// Gather all data needed for an evolution session context in parallel.
  ///
  /// This fetches metrics, version history, instance reports/observations,
  /// evolution notes, sessions, observation payloads, and change counts in
  /// as few sequential round-trips as possible.
  Future<EvolutionDataBundle> gatherEvolutionData(String templateId) async {
    // First batch: all independent queries in parallel.
    final results = await (
      computeMetrics(templateId),
      crud.getVersionHistory(templateId, limit: 5),
      getRecentInstanceReports(templateId),
      getRecentInstanceObservations(templateId),
      getRecentEvolutionNotes(templateId, limit: 30),
      getEvolutionSessions(templateId),
    ).wait;

    final metrics = results.$1;
    final recentVersions = results.$2;
    final reports = results.$3;
    final observations = results.$4;
    final notes = results.$5;
    final sessions = results.$6;

    // Second batch: depends on first batch results.
    final payloadIds = observations
        .map((obs) => obs.contentEntryId)
        .whereType<String>();
    final payloadEntitiesFuture = Future.wait(
      payloadIds.map(repository.getEntity),
    );

    final lastSessionDate = sessions.isNotEmpty
        ? sessions.first.createdAt
        : null;
    final changesSinceFuture = countChangesSince(templateId, lastSessionDate);

    final batchResults = await (payloadEntitiesFuture, changesSinceFuture).wait;

    final observationPayloads = <String, AgentMessagePayloadEntity>{
      for (final entity
          in batchResults.$1.whereType<AgentMessagePayloadEntity>())
        entity.id: entity,
    };

    return EvolutionDataBundle(
      metrics: metrics,
      recentVersions: recentVersions,
      instanceReports: reports,
      instanceObservations: observations,
      pastNotes: notes,
      sessions: sessions,
      observationPayloads: observationPayloads,
      changesSinceLastSession: batchResults.$2,
    );
  }

  /// Checks whether any templates, template versions, or agent configs
  /// reference the given [profileId].
  ///
  /// Returns `true` if the profile is in use and should not be deleted.
  Future<bool> profileInUse(String profileId) async {
    final templates = await repository.getAllTemplates();
    for (final t in templates) {
      if (t.profileId == profileId) return true;
    }

    // Check all template versions in parallel.
    final allVersions = await Future.wait(
      templates.map((t) => crud.getVersionHistory(t.id, limit: 1000000)),
    );
    if (allVersions.any(
      (versions) => versions.any((v) => v.profileId == profileId),
    )) {
      return true;
    }

    // Check agent identity configs.
    final agents = await repository.getAllAgentIdentities();
    for (final agent in agents) {
      if (agent.config.profileId == profileId) return true;
    }

    return false;
  }
}
