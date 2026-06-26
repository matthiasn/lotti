import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';

/// The task-agent-specific service.
final taskAgentServiceProvider = Provider<TaskAgentService>(
  taskAgentService,
  name: 'taskAgentServiceProvider',
);
TaskAgentService taskAgentService(Ref ref) {
  return TaskAgentService(
    agentService: ref.watch(agentServiceProvider),
    repository: ref.watch(agentRepositoryProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  );
}

/// Fetch the Task Agent for a given journal-domain taskId.
///
/// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.
/// Watches the update stream so the UI rebuilds when an agent-task link
/// arrives via sync (the notification includes the taskId).
final FutureProviderFamily<AgentDomainEntity?, String> taskAgentProvider =
    FutureProvider.autoDispose.family<AgentDomainEntity?, String>(
      taskAgent,
      name: 'taskAgentProvider',
    );
Future<AgentDomainEntity?> taskAgent(
  Ref ref,
  String taskId,
) async {
  ref.watch(agentUpdateStreamProvider(taskId));
  final service = ref.watch(taskAgentServiceProvider);
  return service.getTaskAgentForTask(taskId);
}
