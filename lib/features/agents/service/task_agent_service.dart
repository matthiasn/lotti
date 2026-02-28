import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart'
    show AgentLifecycle, WakeReason;
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/services/domain_logging.dart';
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
    required this.syncService,
    this.domainLogger,
  });

  final AgentService agentService;
  final AgentRepository repository;
  final WakeOrchestrator orchestrator;

  /// Sync-aware write service. All entity/link writes go through this so
  /// they are automatically enqueued for cross-device sync.
  final AgentSyncService syncService;

  /// Optional domain logger for structured, PII-safe logging.
  final DomainLogger? domainLogger;

  static const _uuid = Uuid();
  static const String _agentKind = AgentKinds.taskAgent;

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
    String? templateId,
    String? displayName,
  }) async {
    // Resolve template: use the provided ID or fall back to the first
    // available template from the repository.
    final resolvedTemplateId = templateId ?? await _resolveDefaultTemplateId();
    if (resolvedTemplateId == null) {
      throw StateError(
        'No template available. Seed defaults or provide a templateId.',
      );
    }

    final identity = await syncService.runInTransaction(() async {
      // All validation inside the transaction to prevent TOCTOU races.

      // Validate that the resolved template actually exists.
      final templateEntity = await repository.getEntity(resolvedTemplateId);
      if (templateEntity is! AgentTemplateEntity ||
          templateEntity.deletedAt != null) {
        throw StateError(
          'Template $resolvedTemplateId not found or is not a template entity.',
        );
      }

      // Definitive duplicate check to prevent concurrent createTaskAgent
      // calls from both committing.
      final linksForTask = await repository.getLinksTo(
        taskId,
        type: AgentLinkTypes.agentTask,
      );
      if (linksForTask.isNotEmpty) {
        final primaryLink = _selectPrimaryTaskLink(linksForTask);
        throw StateError(
          'A task agent already exists for task $taskId '
          '(agent ${primaryLink.fromId})',
        );
      }

      final identity = await agentService.createAgent(
        kind: _agentKind,
        displayName: displayName ?? 'Task Agent',
        config: AgentConfig(modelId: templateEntity.modelId),
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
      await syncService.upsertEntity(updatedState);

      // Create agent_task link: agent → task.
      final taskLinkId = _uuid.v4();
      await syncService.upsertLink(
        AgentLink.agentTask(
          id: taskLinkId,
          fromId: identity.agentId,
          toId: taskId,
          createdAt: now,
          updatedAt: now,
          vectorClock: null,
        ),
      );

      // Create template_assignment link: template → agent.
      final templateLinkId = _uuid.v4();
      await syncService.upsertLink(
        AgentLink.templateAssignment(
          id: templateLinkId,
          fromId: resolvedTemplateId,
          toId: identity.agentId,
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
      reason: WakeReason.creation.name,
      triggerTokens: {taskId},
    );

    domainLogger?.log(
      LogDomains.agentRuntime,
      'created task agent ${DomainLogger.sanitizeId(identity.agentId)} '
      'for task ${DomainLogger.sanitizeId(taskId)}',
      subDomain: 'lifecycle',
    );

    return identity;
  }

  /// Find the Task Agent for [taskId], or `null` if none exists.
  ///
  /// Looks up `AgentTaskLink`s pointing to [taskId] and resolves the agent
  /// identity from the link's `fromId`.
  Future<AgentIdentityEntity?> getTaskAgentForTask(String taskId) async {
    final links =
        await repository.getLinksTo(taskId, type: AgentLinkTypes.agentTask);
    if (links.isEmpty) return null;

    final agentId = _selectPrimaryTaskLink(links).fromId;
    return agentService.getAgent(agentId);
  }

  /// Trigger a manual re-analysis wake for [agentId].
  ///
  /// This enqueues a user-initiated wake job that will run the full context
  /// assembly and conversation cycle, regardless of whether anything changed.
  void triggerReanalysis(String agentId) {
    domainLogger?.log(
      LogDomains.agentRuntime,
      'manual reanalysis triggered for ${DomainLogger.sanitizeId(agentId)}',
      subDomain: 'lifecycle',
    );
    orchestrator.enqueueManualWake(
      agentId: agentId,
      reason: WakeReason.reanalysis.name,
    );
  }

  /// Cancel a scheduled wake for [agentId].
  ///
  /// Clears the throttle deadline, cancels the deferred drain timer, and
  /// removes any queued subscription jobs — so no automatic wake will fire.
  void cancelScheduledWake(String agentId) {
    domainLogger?.log(
      LogDomains.agentRuntime,
      'scheduled wake cancelled for ${DomainLogger.sanitizeId(agentId)}',
      subDomain: 'lifecycle',
    );
    orchestrator.clearThrottle(agentId);
    orchestrator.queue.removeByAgent(agentId);
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

  /// Re-register wake subscriptions for a single agent.
  ///
  /// Call this after resuming a paused agent so that automatic
  /// wake-on-task-change is restored for the current session.
  Future<void> restoreSubscriptionsForAgent(String agentId) async {
    final links = await repository.getLinksFrom(
      agentId,
      type: AgentLinkTypes.agentTask,
    );
    for (final link in links) {
      _registerTaskSubscription(agentId, link.toId);
    }
    await _hydrateThrottleDeadline(agentId);
    domainLogger?.log(
      LogDomains.agentRuntime,
      'restored ${links.length} subscriptions '
      'for ${DomainLogger.sanitizeId(agentId)}',
      subDomain: 'restore',
    );
  }

  /// Read the persisted `nextWakeAt` from the agent's state entity and
  /// restore it into the orchestrator's in-memory throttle cache.
  Future<void> _hydrateThrottleDeadline(String agentId) async {
    final state = await repository.getAgentState(agentId);
    final deadline = state?.nextWakeAt;
    if (deadline != null) {
      orchestrator.setThrottleDeadline(agentId, deadline);
    }
    // Note: we intentionally do NOT call clearThrottle when nextWakeAt is
    // null. A concurrent _onBatch notification may have already scheduled a
    // deferred drain timer for this agent (between _registerTaskSubscription
    // and this async call). Calling clearThrottle would cancel that timer
    // and leave the queued job permanently stuck.
  }

  /// Returns the ID of the best default template, or `null` if none exist.
  ///
  /// Prefers the well-known Laura template if it exists, otherwise falls back
  /// to the most recently created template. This ensures a predictable default
  /// even when the user has deleted and recreated templates.
  Future<String?> _resolveDefaultTemplateId() async {
    final templates = await repository.getAllTemplates();
    if (templates.isEmpty) return null;

    // Prefer the seeded Laura template as the default.
    final laura = templates.where((t) => t.id == lauraTemplateId).firstOrNull;
    if (laura != null) return laura.id;

    return templates.first.id;
  }

  /// Re-register subscriptions for all active task agents.
  ///
  /// Called during app startup to restore orchestrator state from the database.
  /// Iterates all active agent identities, finds their `agent_task` links, and
  /// registers wake subscriptions for each.
  Future<void> restoreSubscriptions() async {
    domainLogger?.log(
      LogDomains.agentRuntime,
      'restoring task agent subscriptions...',
      subDomain: 'restore',
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
          type: AgentLinkTypes.agentTask,
        );

        for (final link in links) {
          _registerTaskSubscription(agent.agentId, link.toId);
          count++;
        }

        // Hydrate the throttle deadline from persisted state so the
        // cooldown window survives app restarts and backgrounding.
        await _hydrateThrottleDeadline(agent.agentId);
      } catch (e, s) {
        domainLogger?.error(
          LogDomains.agentRuntime,
          'failed to restore subscriptions '
          'for ${DomainLogger.sanitizeId(agent.agentId)}',
          error: e,
          stackTrace: s,
        );
      }
    }

    domainLogger?.log(
      LogDomains.agentRuntime,
      'restored $count task agent subscriptions',
      subDomain: 'restore',
    );
  }

  AgentLink _selectPrimaryTaskLink(List<AgentLink> links) {
    final sorted = links.toList()
      ..sort((a, b) {
        final createdAtComparison = b.createdAt.compareTo(a.createdAt);
        if (createdAtComparison != 0) {
          return createdAtComparison;
        }
        return b.id.compareTo(a.id);
      });

    if (sorted.length > 1) {
      domainLogger?.log(
        LogDomains.agentRuntime,
        'multiple task-agent links found; choosing latest '
        '${DomainLogger.sanitizeId(sorted.first.id)}',
        subDomain: 'resolve',
      );
    }

    return sorted.first;
  }
}
