import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/service/project_agent_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';

/// Shared per-project serialization for provisioning and project deletion.
final projectAgentMutationCoordinatorProvider =
    Provider<ProjectAgentMutationCoordinator>(
      (_) => ProjectAgentMutationCoordinator(),
      name: 'projectAgentMutationCoordinatorProvider',
    );

/// The project-agent-specific service.
final projectAgentServiceProvider = Provider<ProjectAgentService>(
  projectAgentService,
  name: 'projectAgentServiceProvider',
);
ProjectAgentService projectAgentService(Ref ref) {
  final notifications = ref.watch(updateNotificationsProvider);
  final projectRepository = ref.watch(projectRepositoryProvider);
  return ProjectAgentService(
    agentService: ref.watch(agentServiceProvider),
    repository: ref.watch(agentRepositoryProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    projectExists: (projectId) async =>
        await projectRepository.getProjectById(projectId) != null,
    mutationCoordinator: ref.watch(projectAgentMutationCoordinatorProvider),
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
