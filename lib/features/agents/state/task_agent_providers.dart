import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_agent_providers.g.dart';

/// The task-agent-specific service.
@Riverpod(keepAlive: true)
TaskAgentService taskAgentService(Ref ref) {
  return TaskAgentService(
    agentService: ref.watch(agentServiceProvider),
    repository: ref.watch(agentRepositoryProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  );
}

/// Fetch the Task Agent for a given journal-domain [taskId].
///
/// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.
@riverpod
Future<AgentDomainEntity?> taskAgent(
  Ref ref,
  String taskId,
) async {
  final service = ref.watch(taskAgentServiceProvider);
  return service.getTaskAgentForTask(taskId);
}
