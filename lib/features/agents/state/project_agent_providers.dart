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
