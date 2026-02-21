import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
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

    final identity = await repository.runInTransaction(() async {
      final identity = await agentService.createAgent(
        kind: _agentKind,
        displayName: displayName ?? 'Task Agent',
        config: const AgentConfig(),
        allowedCategoryIds: allowedCategoryIds,
      );

      // Update state with activeTaskId.
      final state = await repository.getAgentState(identity.agentId);
      if (state == null) {
        throw StateError(
          'Agent ${identity.agentId} was just created but has no state entity',
        );
      }

      final now = clock.now();
      final updatedState = state.copyWith(
        slots: state.slots.copyWith(activeTaskId: taskId),
        updatedAt: now,
      );
      await repository.upsertEntity(updatedState);

      // Create agent_task link: agent → task.
      final linkId = _uuid.v4();
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

      return identity;
    });

    // Register subscription for changes to this task.
    _registerTaskSubscription(identity.agentId, taskId);

    // Enqueue the initial wake so the agent runs immediately after creation.
    orchestrator.enqueueManualWake(
      agentId: identity.agentId,
      reason: 'creation',
      triggerTokens: {taskId},
    );

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
    orchestrator.enqueueManualWake(
      agentId: agentId,
      reason: 'reanalysis',
    );
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
  /// Iterates all active agent identities, finds their `agent_task` links, and
  /// registers wake subscriptions for each.
  Future<void> restoreSubscriptions() async {
    developer.log(
      'Restoring task agent subscriptions...',
      name: 'TaskAgentService',
    );

    final activeAgents = await agentService.listAgents(
      lifecycle: AgentLifecycle.active,
    );

    var count = 0;
    for (final agent in activeAgents) {
      if (agent.kind != _agentKind) continue;

      try {
        final links = await repository.getLinksFrom(
          agent.agentId,
          type: 'agent_task',
        );

        for (final link in links) {
          _registerTaskSubscription(agent.agentId, link.toId);
          count++;
        }
      } catch (e, s) {
        developer.log(
          'Failed to restore subscriptions for agent ${agent.agentId}',
          name: 'TaskAgentService',
          error: e,
          stackTrace: s,
        );
      }
    }

    developer.log(
      'Restored $count task agent subscriptions',
      name: 'TaskAgentService',
    );
  }
}
