import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/service/project_agent_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'project_agent_providers.g.dart';

/// The project-agent-specific service.
@Riverpod(keepAlive: true)
ProjectAgentService projectAgentService(Ref ref) {
  return ProjectAgentService(
    agentService: ref.watch(agentServiceProvider),
    repository: ref.watch(agentRepositoryProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  );
}

/// Fetch the Project Agent for a given journal-domain [projectId].
///
/// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.
/// Watches the update stream so the UI rebuilds when an agent-project link
/// arrives via sync.
@riverpod
Future<AgentDomainEntity?> projectAgent(
  Ref ref,
  String projectId,
) async {
  ref.watch(agentUpdateStreamProvider(projectId));
  final service = ref.watch(projectAgentServiceProvider);
  return service.getProjectAgentForProject(projectId);
}

/// Lightweight project-agent report freshness state for project UI surfaces.
class ProjectAgentSummaryState {
  const ProjectAgentSummaryState({
    required this.agentId,
    required this.hasReport,
    this.pendingProjectActivityAt,
    this.scheduledWakeAt,
  });

  final String agentId;
  final bool hasReport;
  final DateTime? pendingProjectActivityAt;
  final DateTime? scheduledWakeAt;

  bool get isSummaryOutdated => hasReport && pendingProjectActivityAt != null;
}

/// Fetches summary freshness data for the project's provisioned agent.
final FutureProviderFamily<ProjectAgentSummaryState?, String>
projectAgentSummaryProvider = FutureProvider.autoDispose
    .family<ProjectAgentSummaryState?, String>((
      ref,
      projectId,
    ) async {
      final agentEntity = await ref.watch(
        projectAgentProvider(projectId).future,
      );
      final identity = agentEntity?.mapOrNull(agent: (agent) => agent);
      if (identity == null) return null;

      final stateEntity = await ref.watch(
        agentStateProvider(identity.agentId).future,
      );
      final reportEntity = await ref.watch(
        agentReportProvider(identity.agentId).future,
      );

      final state = stateEntity?.mapOrNull(
        agentState: (agentState) => agentState,
      );
      final report = reportEntity?.mapOrNull(
        agentReport: (agentReport) => agentReport,
      );

      return ProjectAgentSummaryState(
        agentId: identity.agentId,
        hasReport: report != null && report.content.trim().isNotEmpty,
        pendingProjectActivityAt: state?.slots.pendingProjectActivityAt,
        scheduledWakeAt: state?.scheduledWakeAt,
      );
    });
