import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_token_usage.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'template_query_providers.g.dart';

/// List all non-deleted agent templates.
@riverpod
Future<List<AgentDomainEntity>> agentTemplates(Ref ref) async {
  final service = ref.watch(agentTemplateServiceProvider);
  return service.listTemplates();
}

/// List all evolution sessions across all templates.
///
/// Uses a single DB query instead of N per-template lookups.
/// Reactively rebuilds when any agent data changes.
@riverpod
Future<List<AgentDomainEntity>> allEvolutionSessions(Ref ref) async {
  ref.watch(agentUpdateStreamProvider(agentNotification));
  final repository = ref.watch(agentRepositoryProvider);
  final sessions = await repository.getAllEvolutionSessions();
  return sessions.cast<AgentDomainEntity>();
}

/// Fetch a single agent template by [templateId].
///
/// The returned entity is an [AgentTemplateEntity] (or `null`).
@riverpod
Future<AgentDomainEntity?> agentTemplate(
  Ref ref,
  String templateId,
) async {
  final service = ref.watch(agentTemplateServiceProvider);
  return service.getTemplate(templateId);
}

/// Fetch the active version for a template by [templateId].
///
/// The returned entity is an [AgentTemplateVersionEntity] (or `null`).
@riverpod
Future<AgentDomainEntity?> activeTemplateVersion(
  Ref ref,
  String templateId,
) async {
  final service = ref.watch(agentTemplateServiceProvider);
  return service.getActiveVersion(templateId);
}

/// Fetch the version history for a template by [templateId].
///
/// Each element is an [AgentTemplateVersionEntity].
@riverpod
Future<List<AgentDomainEntity>> templateVersionHistory(
  Ref ref,
  String templateId,
) async {
  final service = ref.watch(agentTemplateServiceProvider);
  return service.getVersionHistory(templateId);
}

/// Resolve the template assigned to an agent by [agentId].
///
/// The returned entity is an [AgentTemplateEntity] (or `null`).
@riverpod
Future<AgentDomainEntity?> templateForAgent(
  Ref ref,
  String agentId,
) async {
  ref.watch(agentUpdateStreamProvider(agentId));
  final service = ref.watch(agentTemplateServiceProvider);
  return service.getTemplateForAgent(agentId);
}

// ── Template-level aggregate token usage ──────────────────────────────────

/// Raw token usage records for all instances of a template.
///
/// Uses a SQL JOIN via `template_assignment` links to fetch all
/// [WakeTokenUsageEntity] records across every instance in a single query.
@riverpod
Future<List<AgentDomainEntity>> templateTokenUsageRecords(
  Ref ref,
  String templateId,
) async {
  ref.watch(agentUpdateStreamProvider(templateId));
  final repository = ref.watch(agentRepositoryProvider);
  final records = await repository.getTokenUsageForTemplate(
    templateId,
  );
  return records.cast<AgentDomainEntity>();
}

/// Aggregated token usage summaries for a template, grouped by model ID.
///
/// Derives from [templateTokenUsageRecordsProvider] and aggregates into
/// per-model summaries sorted by total tokens descending.
@riverpod
Future<List<AgentTokenUsageSummary>> templateTokenUsageSummaries(
  Ref ref,
  String templateId,
) async {
  final entities = await ref.watch(
    templateTokenUsageRecordsProvider(templateId).future,
  );
  final records = entities.whereType<WakeTokenUsageEntity>();
  return aggregateByModel(records);
}

/// Per-instance token usage breakdown for a template.
///
/// Groups token records by instance, then by model within each instance.
/// Returns full per-model summaries so each instance can render a
/// `TokenUsageTable` identical in structure to the aggregate view.
@riverpod
Future<List<InstanceTokenBreakdown>> templateInstanceTokenBreakdown(
  Ref ref,
  String templateId,
) async {
  final entities = await ref.watch(
    templateTokenUsageRecordsProvider(templateId).future,
  );
  final records = entities.whereType<WakeTokenUsageEntity>();

  // Group by agentId, then aggregate each group by model.
  final byAgent = <String, List<WakeTokenUsageEntity>>{};
  for (final r in records) {
    byAgent.putIfAbsent(r.agentId, () => []).add(r);
  }

  // Enrich with instance metadata
  final templateService = ref.watch(agentTemplateServiceProvider);
  final agents = await templateService.getAgentsForTemplate(templateId);

  return agents.map((agent) {
    final agentRecords = byAgent[agent.agentId] ?? [];
    final summaries = aggregateByModel(agentRecords);
    return InstanceTokenBreakdown(
      agentId: agent.id,
      displayName: agent.displayName,
      lifecycle: agent.lifecycle,
      summaries: summaries,
    );
  }).toList()..sort((a, b) => b.totalTokens.compareTo(a.totalTokens));
}

/// Recent reports from all instances of a template, newest-first.
@riverpod
Future<List<AgentDomainEntity>> templateRecentReports(
  Ref ref,
  String templateId,
) async {
  ref.watch(agentUpdateStreamProvider(templateId));
  final repository = ref.watch(agentRepositoryProvider);
  final reports = await repository.getRecentReportsByTemplate(
    templateId,
    limit: 20,
  );
  return reports.cast<AgentDomainEntity>();
}

/// Computed performance metrics for a template by [templateId].
@riverpod
Future<TemplatePerformanceMetrics> templatePerformanceMetrics(
  Ref ref,
  String templateId,
) async {
  final service = ref.watch(agentTemplateServiceProvider);
  return service.computeMetrics(templateId);
}

/// Fetch evolution sessions for a template, newest-first.
///
/// Each element is an [EvolutionSessionEntity].
@riverpod
Future<List<AgentDomainEntity>> evolutionSessions(
  Ref ref,
  String templateId,
) async {
  // Reactively rebuild when the template's data changes.
  ref.watch(agentUpdateStreamProvider(templateId));
  final service = ref.watch(agentTemplateServiceProvider);
  return service.getEvolutionSessions(templateId);
}

/// Fetch evolution notes for a template, newest-first.
///
/// Each element is an [EvolutionNoteEntity].
@riverpod
Future<List<AgentDomainEntity>> evolutionNotes(
  Ref ref,
  String templateId,
) async {
  ref.watch(agentUpdateStreamProvider(templateId));
  final service = ref.watch(agentTemplateServiceProvider);
  return service.getRecentEvolutionNotes(templateId);
}
