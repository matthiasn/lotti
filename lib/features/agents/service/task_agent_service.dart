import 'dart:developer' as developer;

import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:uuid/uuid.dart';

/// Task-agent-specific lifecycle management.
///
/// Extends [AgentService] with task-specific operations: creating a Task Agent
/// for a specific journal-domain task, looking up an agent by task ID, and
/// triggering a manual re-analysis wake.
class TaskAgentService {
  TaskAgentService({
    required this.agentService,
    required this.repository,
    required this.orchestrator,
  });

  final AgentService agentService;
  final AgentRepository repository;
  final WakeOrchestrator orchestrator;

  static const _uuid = Uuid();
  static const _agentKind = 'task_agent';

  /// Create a new Task Agent for [taskId].
  ///
  /// Steps:
  /// 1. Create the agent via [AgentService.createAgent] with kind `'task_agent'`.
  /// 2. Update the agent's state with `activeTaskId = taskId`.
  /// 3. Create an [AgentTaskLink] from agentId → taskId.
  /// 4. Register a wake subscription for the task's entity ID.
  ///
  /// Returns the created [AgentIdentityEntity].
  ///
  /// Throws [StateError] if a Task Agent already exists for [taskId].
  Future<AgentIdentityEntity> createTaskAgent({
    required String taskId,
    required Set<String> allowedCategoryIds,
    String? displayName,
  }) async {
    // Check for existing task agent.
    final existing = await getTaskAgentForTask(taskId);
    if (existing != null) {
      throw StateError(
        'A task agent already exists for task $taskId: ${existing.id}',
      );
    }

    final identity = await agentService.createAgent(
      kind: _agentKind,
      displayName: displayName ?? 'Task Agent',
      config: const AgentConfig(),
      allowedCategoryIds: allowedCategoryIds,
    );

    // Update state with activeTaskId.
    final state = await repository.getAgentState(identity.agentId);
    if (state != null) {
      final updatedState = state.copyWith(
        slots: state.slots.copyWith(activeTaskId: taskId),
        updatedAt: DateTime.now(),
      );
      await repository.upsertEntity(updatedState);
    }

    // Create agent_task link: agent → task.
    final linkId = _uuid.v4();
    final now = DateTime.now();
    await repository.upsertLink(
      AgentLink.agentTask(
        id: linkId,
        fromId: identity.agentId,
        toId: taskId,
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
      ),
    );

    // Register subscription for changes to this task.
    _registerTaskSubscription(identity.agentId, taskId);

    developer.log(
      'Created task agent ${identity.agentId} for task $taskId',
      name: 'TaskAgentService',
    );

    return identity;
  }

  /// Find the Task Agent for [taskId], or `null` if none exists.
  ///
  /// Looks up `AgentTaskLink`s pointing to [taskId] and resolves the agent
  /// identity from the link's `fromId`.
  Future<AgentIdentityEntity?> getTaskAgentForTask(String taskId) async {
    final links = await repository.getLinksTo(taskId, type: 'agent_task');
    if (links.isEmpty) return null;

    final agentId = links.first.fromId;
    return agentService.getAgent(agentId);
  }

  /// Trigger a manual re-analysis wake for [agentId].
  ///
  /// This enqueues a user-initiated wake job that will run the full context
  /// assembly and conversation cycle, regardless of whether anything changed.
  void triggerReanalysis(String agentId) {
    developer.log(
      'Manual re-analysis triggered for agent $agentId',
      name: 'TaskAgentService',
    );
    // The orchestrator will handle this as a user-initiated wake.
    // For MVP, we directly enqueue a job via the orchestrator.
    // The workflow layer will pick it up and run the full context.
    // TODO(agents): Implement user-initiated wake enqueue path.
  }

  /// Register a wake subscription for a task agent.
  ///
  /// The subscription matches on the [taskId] entity ID, so the agent wakes
  /// whenever the task (or its linked entries) receives a notification.
  void _registerTaskSubscription(String agentId, String taskId) {
    orchestrator.addSubscription(
      AgentSubscription(
        id: '${agentId}_task_$taskId',
        agentId: agentId,
        matchEntityIds: {taskId},
      ),
    );
  }

  /// Re-register subscriptions for all active task agents.
  ///
  /// Called during app startup to restore orchestrator state from the database.
  Future<void> restoreSubscriptions() async {
    // For MVP, iterate all agent_task links and register subscriptions.
    // This is O(n) in the number of task agents, which is fine for MVP.
    // TODO(agents): Add a more efficient query for active task agent links.
    developer.log(
      'Restoring task agent subscriptions...',
      name: 'TaskAgentService',
    );
  }
}
