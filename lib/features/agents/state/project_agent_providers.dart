import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/service/project_agent_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';

/// The project-agent-specific service.
final projectAgentServiceProvider = Provider<ProjectAgentService>(
  projectAgentService,
  name: 'projectAgentServiceProvider',
);
ProjectAgentService projectAgentService(Ref ref) {
  final notifications = ref.watch(updateNotificationsProvider);
  return ProjectAgentService(
    agentService: ref.watch(agentServiceProvider),
    repository: ref.watch(agentRepositoryProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    domainLogger: ref.watch(domainLoggerProvider),
    cancellationCoordinator: ref.watch(
      projectActivityCancellationCoordinatorProvider,
    ),
    onPersistedStateChanged: persistedStateChangedNotifier(notifications),
  );
}

/// Fetch the Project Agent for a given journal-domain projectId.
///
/// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.
/// Watches the update stream so the UI rebuilds when an agent-project link
/// arrives via sync.
final FutureProviderFamily<AgentDomainEntity?, String> projectAgentProvider =
    FutureProvider.autoDispose.family<AgentDomainEntity?, String>(
      projectAgent,
      name: 'projectAgentProvider',
    );
Future<AgentDomainEntity?> projectAgent(Ref ref, String projectId) async {
  ref.watch(agentUpdateStreamProvider(projectId));
  final service = ref.watch(projectAgentServiceProvider);
  return service.getProjectAgentForProject(projectId);
}
