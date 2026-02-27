import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/service/change_set_confirmation_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/workflow/task_tool_dispatcher.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'change_set_providers.g.dart';

/// Fetches pending (and partially resolved) change sets for a given task.
///
/// Resolves the task's agent via [taskAgentProvider], then watches the
/// [agentUpdateStreamProvider] for reactive invalidation, and finally
/// queries the repository.
@riverpod
Future<List<AgentDomainEntity>> pendingChangeSets(
  Ref ref,
  String taskId,
) async {
  final agent =
      ref.watch(taskAgentProvider(taskId)).value?.mapOrNull(agent: (a) => a);

  if (agent == null) return [];

  // Watch the agent's update stream so this provider rebuilds when the
  // agent's data changes (e.g., after a wake produces new change sets).
  ref.watch(agentUpdateStreamProvider(agent.agentId));

  final repo = ref.watch(agentRepositoryProvider);
  return repo.getPendingChangeSets(agent.agentId, taskId: taskId);
}

/// Provides a [ChangeSetConfirmationService] with all dependencies resolved.
@riverpod
ChangeSetConfirmationService changeSetConfirmationService(Ref ref) {
  return ChangeSetConfirmationService(
    syncService: ref.watch(agentSyncServiceProvider),
    toolDispatcher: TaskToolDispatcher(
      journalDb: ref.watch(journalDbProvider),
      journalRepository: ref.watch(journalRepositoryProvider),
      checklistRepository: ref.watch(checklistRepositoryProvider),
      labelsRepository: ref.watch(labelsRepositoryProvider),
    ),
  );
}
