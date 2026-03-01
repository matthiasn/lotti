import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
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
  final sets = await repo.getPendingChangeSets(agent.agentId, taskId: taskId);
  return _deduplicateChangeSets(sets);
}

/// Deduplicates change sets that have identical pending-item fingerprints.
///
/// When two wake cycles race, they may produce genuinely duplicate
/// [ChangeSetEntity] records in the DB. This collapses them at the
/// provider level by fingerprinting each set's pending items (toolName +
/// args) and keeping only the newest set per fingerprint.
List<AgentDomainEntity> _deduplicateChangeSets(
  List<AgentDomainEntity> sets,
) {
  if (sets.length <= 1) return sets;

  final seen = <String, AgentDomainEntity>{};

  for (final entity in sets) {
    if (entity is! ChangeSetEntity) {
      seen[entity.id] = entity;
      continue;
    }

    final fingerprint = entity.items
        .where((i) => i.status == ChangeItemStatus.pending)
        .map(ChangeItem.fingerprint)
        .toList()
      ..sort();

    // Sets with no pending items are fully resolved — keep each one
    // individually (keyed by entity ID) to avoid collapsing unrelated sets.
    final key = fingerprint.isEmpty ? entity.id : fingerprint.join('|');

    final existing = seen[key];
    if (existing == null) {
      seen[key] = entity;
    } else if (existing is ChangeSetEntity &&
        entity.createdAt.isAfter(existing.createdAt)) {
      seen[key] = entity;
    }
  }

  return seen.values.toList();
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
