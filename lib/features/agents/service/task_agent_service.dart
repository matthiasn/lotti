import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart'
    show
        AgentInferenceSetupMode,
        AgentInferenceSetupOrigin,
        AgentLifecycle,
        WakeInitiator,
        WakeReason;
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
  /// [additionalWakeTokens] are extra entity IDs merged into the creation
  /// wake's trigger tokens — e.g. an already-transcribed audio entry, so the
  /// agent's first turn attends to the spoken capture the same way a
  /// `transcriptionComplete` wake would after an in-task recording.
  ///
  /// Throws [StateError] if a Task Agent already exists for [taskId].
  Future<AgentIdentityEntity> createTaskAgent({
    required String taskId,
    required Set<String> allowedCategoryIds,
    String? templateId,
    String? profileId,
    AgentInferenceSetupOrigin? setupOrigin,
    String? setupOriginEntityId,
    String? displayName,
    bool awaitContent = false,
    Set<String> additionalWakeTokens = const {},
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
        final primaryLink = linksForTask.selectPrimary();
        throw StateError(
          'A task agent already exists for task $taskId '
          '(agent ${primaryLink.fromId})',
        );
      }

      final templateProfileId = templateEntity.profileId;
      final categoryHasNoDefault =
          setupOrigin == AgentInferenceSetupOrigin.categorySnapshot &&
          profileId == null;
      final baseProfileId = categoryHasNoDefault
          ? null
          : profileId ?? templateProfileId;
      final effectiveOrigin = profileId != null
          ? (setupOrigin ?? AgentInferenceSetupOrigin.user)
          : !categoryHasNoDefault && templateProfileId != null
          ? AgentInferenceSetupOrigin.templateSnapshot
          : (setupOrigin ?? AgentInferenceSetupOrigin.user);
      final inferenceSetup = AgentInferenceSetup(
        mode: baseProfileId == null
            ? AgentInferenceSetupMode.disabled
            : AgentInferenceSetupMode.configured,
        origin: effectiveOrigin,
        baseProfileId: baseProfileId,
        originEntityId: profileId != null
            ? setupOriginEntityId
            : !categoryHasNoDefault && templateProfileId != null
            ? resolvedTemplateId
            : setupOriginEntityId,
      );
      final createdIdentity = await agentService.createAgent(
        kind: _agentKind,
        displayName: displayName ?? 'Task Agent',
        config: AgentConfig(
          modelId: templateEntity.modelId,
          profileId: baseProfileId,
          inferenceSetup: inferenceSetup,
          automaticUpdatesEnabled: true,
        ),
        allowedCategoryIds: allowedCategoryIds,
      );
      final identity = inferenceSetup.mode == AgentInferenceSetupMode.disabled
          ? createdIdentity.copyWith(
              lifecycle: AgentLifecycle.dormant,
              updatedAt: clock.now(),
            )
          : createdIdentity;
      if (!identical(identity, createdIdentity)) {
        await syncService.upsertEntity(identity);
      }

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
        awaitingContent: awaitContent,
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

    final inferenceEnabled =
        identity.config.inferenceSetup?.mode !=
        AgentInferenceSetupMode.disabled;
    if (inferenceEnabled) {
      _registerTaskSubscription(identity.agentId, taskId);
    }

    // Mirror the persisted awaitingContent flag in the orchestrator so that
    // subscription notifications for a brand-new blank task do not surface a
    // 2-minute throttle countdown in the UI.
    //
    // Always enqueue the creation wake. The content gate in
    // WakeOrchestrator._shouldSkipForAwaitingContent() will defer execution
    // for blank tasks and immediately activate agents whose task already has
    // meaningful content.
    if (inferenceEnabled) {
      orchestrator
        ..setAwaitingContent(identity.agentId, awaiting: awaitContent)
        ..enqueueManualWake(
          agentId: identity.agentId,
          reason: WakeReason.creation.name,
          triggerTokens: {taskId, ...additionalWakeTokens},
        );
    }

    domainLogger?.log(
      LogDomain.agentRuntime,
      'created task agent ${DomainLogger.sanitizeId(identity.agentId)} '
      'for task ${DomainLogger.sanitizeId(taskId)}'
      '${awaitContent ? ' (awaiting content)' : ''}',
      subDomain: 'lifecycle',
    );

    return identity;
  }

  /// Find the Task Agent for [taskId], or `null` if none exists.
  ///
  /// Looks up `AgentTaskLink`s pointing to [taskId] and resolves the agent
  /// identity from the link's `fromId`.
  Future<AgentIdentityEntity?> getTaskAgentForTask(String taskId) async {
    final links = await repository.getLinksTo(
      taskId,
      type: AgentLinkTypes.agentTask,
    );
    if (links.isEmpty) return null;

    final agentId = links.selectPrimary().fromId;
    return agentService.getAgent(agentId);
  }

  /// Persist the complete inference setup for an existing task agent.
  ///
  /// Disabled setup is mirrored to the legacy-aware dormant lifecycle and
  /// cancels pending automatic work. Re-enabling a setup only reactivates an
  /// agent that was dormant because its previous typed setup was disabled;
  /// an independently paused legacy/configured agent stays paused.
  Future<void> updateAgentInferenceSetup({
    required String agentId,
    required AgentInferenceSetup setup,
  }) async {
    if (setup.mode == AgentInferenceSetupMode.configured &&
        setup.baseProfileId == null &&
        setup.thinkingModelOverrideId == null) {
      throw ArgumentError.value(
        setup,
        'setup',
        'Configured setup requires a profile or thinking model',
      );
    }

    late AgentIdentityEntity previous;
    late AgentIdentityEntity updated;
    await syncService.runInTransaction(() async {
      final identity = await agentService.getAgent(agentId);
      if (identity == null) {
        throw StateError('Agent $agentId not found');
      }
      previous = identity;
      final wasInferenceDisabled =
          identity.config.inferenceSetup?.mode ==
          AgentInferenceSetupMode.disabled;
      final lifecycle = setup.mode == AgentInferenceSetupMode.disabled
          ? AgentLifecycle.dormant
          : wasInferenceDisabled && identity.lifecycle == AgentLifecycle.dormant
          ? AgentLifecycle.active
          : identity.lifecycle;
      updated = identity.copyWith(
        lifecycle: lifecycle,
        config: identity.config.copyWith(
          profileId: setup.mode == AgentInferenceSetupMode.configured
              ? setup.baseProfileId
              : null,
          inferenceSetup: setup,
        ),
        updatedAt: clock.now(),
      );
      await syncService.upsertEntity(updated);
    });

    if (setup.mode == AgentInferenceSetupMode.disabled) {
      orchestrator.disableAutomaticUpdatesRuntime(agentId);
    } else if (previous.config.inferenceSetup?.mode ==
            AgentInferenceSetupMode.disabled &&
        updated.lifecycle == AgentLifecycle.active &&
        updated.config.automaticUpdatesEnabledEffective) {
      await restoreSubscriptionsForAgent(agentId, restoreCountdown: false);
    }

    domainLogger?.log(
      LogDomain.agentRuntime,
      'updated inference setup for ${DomainLogger.sanitizeId(agentId)} '
      'to ${setup.mode.name}',
      subDomain: 'lifecycle',
    );
  }

  /// Enable or disable subscription-triggered automatic task updates.
  ///
  /// Turning this on restores subscriptions but never enqueues a wake or
  /// replays changes received while it was off. Turning it off clears the
  /// countdown and queued subscription jobs while preserving manual wakes.
  Future<void> updateAutomaticUpdates({
    required String agentId,
    required bool enabled,
  }) async {
    late AgentIdentityEntity identity;
    await syncService.runInTransaction(() async {
      final current = await agentService.getAgent(agentId);
      if (current == null) {
        throw StateError('Agent $agentId not found');
      }
      identity = current;
      if (enabled &&
          identity.config.inferenceSetup?.mode ==
              AgentInferenceSetupMode.disabled) {
        throw StateError(
          'Choose an inference setup before enabling automation',
        );
      }

      final updated = identity.copyWith(
        config: identity.config.copyWith(automaticUpdatesEnabled: enabled),
        updatedAt: clock.now(),
      );
      await syncService.upsertEntity(updated);
    });

    if (enabled && identity.lifecycle == AgentLifecycle.active) {
      orchestrator.enableAutomaticUpdatesRuntime(agentId);
      await restoreSubscriptionsForAgent(agentId, restoreCountdown: false);
    } else {
      orchestrator.disableAutomaticUpdatesRuntime(agentId);
    }

    domainLogger?.log(
      LogDomain.agentRuntime,
      'automatic updates ${enabled ? 'enabled' : 'disabled'} for '
      '${DomainLogger.sanitizeId(agentId)}',
      subDomain: 'lifecycle',
    );
  }

  /// Update the base inference profile and clear any direct model override.
  Future<void> updateAgentProfile({
    required String agentId,
    required String? profileId,
  }) async {
    await updateAgentInferenceSetup(
      agentId: agentId,
      setup: AgentInferenceSetup(
        mode: profileId == null
            ? AgentInferenceSetupMode.disabled
            : AgentInferenceSetupMode.configured,
        origin: AgentInferenceSetupOrigin.user,
        baseProfileId: profileId,
      ),
    );
  }

  /// Set or clear the persistent direct thinking-model override.
  Future<void> updateAgentThinkingModelOverride({
    required String agentId,
    required String? modelConfigId,
  }) async {
    final identity = await agentService.getAgent(agentId);
    if (identity == null) {
      throw StateError('Agent $agentId not found');
    }
    final current = identity.config.inferenceSetup;
    final baseProfileId = current?.mode == AgentInferenceSetupMode.configured
        ? current?.baseProfileId
        : identity.config.profileId;
    final next = modelConfigId == null && baseProfileId == null
        ? const AgentInferenceSetup(
            mode: AgentInferenceSetupMode.disabled,
            origin: AgentInferenceSetupOrigin.user,
          )
        : AgentInferenceSetup(
            mode: AgentInferenceSetupMode.configured,
            origin: current?.origin ?? AgentInferenceSetupOrigin.user,
            baseProfileId: baseProfileId,
            thinkingModelOverrideId: modelConfigId,
            originEntityId: current?.originEntityId,
          );
    await updateAgentInferenceSetup(agentId: agentId, setup: next);
  }

  /// Trigger a manual re-analysis wake for [agentId].
  ///
  /// This enqueues a user-initiated wake job that will run the full context
  /// assembly and conversation cycle, regardless of whether anything changed.
  void triggerReanalysis(String agentId) {
    domainLogger?.log(
      LogDomain.agentRuntime,
      'manual reanalysis triggered for ${DomainLogger.sanitizeId(agentId)}',
      subDomain: 'lifecycle',
    );
    orchestrator.enqueueManualWake(
      agentId: agentId,
      reason: WakeReason.reanalysis.name,
      initiator: WakeInitiator.user,
    );
  }

  /// Cancel a scheduled wake for [agentId].
  ///
  /// Clears the throttle deadline, cancels the deferred drain timer, and
  /// removes any queued subscription jobs — so no automatic wake will fire.
  void cancelScheduledWake(String agentId) {
    domainLogger?.log(
      LogDomain.agentRuntime,
      'scheduled wake cancelled for ${DomainLogger.sanitizeId(agentId)}',
      subDomain: 'lifecycle',
    );
    agentService.cancelPendingWake(agentId);
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
        deferPropagatedMatches: false,
      ),
    );
  }

  /// Re-register wake subscriptions for a single agent.
  ///
  /// Call this after resuming a paused agent so that automatic
  /// wake-on-task-change is restored for the current session.
  Future<void> restoreSubscriptionsForAgent(
    String agentId, {
    bool restoreCountdown = true,
  }) async {
    final links = await repository.getLinksFrom(
      agentId,
      type: AgentLinkTypes.agentTask,
    );
    for (final link in links) {
      _registerTaskSubscription(agentId, link.toId);
    }
    if (restoreCountdown) {
      await _hydrateThrottleDeadline(agentId);
    }
    domainLogger?.log(
      LogDomain.agentRuntime,
      'restored ${links.length} subscriptions '
      'for ${DomainLogger.sanitizeId(agentId)}',
      subDomain: 'restore',
    );
  }

  /// Read the persisted `nextWakeAt` from the agent's state entity and
  /// restore the matching in-memory queue job plus throttle deadline.
  ///
  /// Also mirrors the persisted `awaitingContent` flag so the orchestrator
  /// can skip surfacing a 2-minute countdown for blank tasks across app
  /// restarts.
  Future<void> _hydrateThrottleDeadline(String agentId) async {
    final state = await repository.getAgentState(agentId);
    _hydrateThrottleDeadlineFromState(agentId, state);
  }

  void _hydrateThrottleDeadlineFromState(
    String agentId,
    AgentStateEntity? state,
  ) {
    final deadline = state?.nextWakeAt;
    if (deadline != null) {
      orchestrator.restorePendingWake(agentId: agentId, dueAt: deadline);
    }
    orchestrator.setAwaitingContent(
      agentId,
      awaiting: state?.awaitingContent ?? false,
    );
    // Note: we intentionally do NOT call clearThrottle when nextWakeAt is
    // null. A concurrent _onBatch notification may have already scheduled a
    // deferred drain timer for this agent (between _registerTaskSubscription
    // and this async call). Calling clearThrottle would cancel that timer
    // and leave the queued job permanently stuck.
  }

  Future<Map<String, AgentStateEntity>?> _loadStatesForRestore(
    List<AgentIdentityEntity> agents,
  ) async {
    if (agents.isEmpty) return const {};
    try {
      return await repository.getAgentStatesByAgentIds([
        for (final agent in agents) agent.agentId,
      ]);
    } catch (_) {
      return null;
    }
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
      LogDomain.agentRuntime,
      'restoring task agent subscriptions...',
      subDomain: 'restore',
    );

    final activeAgents = await agentService.listAgents(
      lifecycle: AgentLifecycle.active,
    );
    final taskAgents = activeAgents
        .where(
          (agent) =>
              agent.kind == _agentKind &&
              agent.config.automaticUpdatesEnabledEffective &&
              agent.config.inferenceSetup?.mode !=
                  AgentInferenceSetupMode.disabled,
        )
        .toList(growable: false);
    final statesByAgentId = await _loadStatesForRestore(taskAgents);

    var count = 0;
    for (final agent in taskAgents) {
      try {
        final links = await repository.getLinksFrom(
          agent.agentId,
          type: AgentLinkTypes.agentTask,
        );

        for (final link in links) {
          _registerTaskSubscription(agent.agentId, link.toId);
          count++;
        }

        // Restore persisted deferred wake work so due deadlines survive app
        // restarts and backgrounding.
        final state = statesByAgentId == null
            ? await repository.getAgentState(agent.agentId)
            : statesByAgentId[agent.agentId];
        _hydrateThrottleDeadlineFromState(agent.agentId, state);
      } catch (e, s) {
        final msg =
            'failed to restore subscriptions '
            'for ${DomainLogger.sanitizeId(agent.agentId)}';
        if (domainLogger != null) {
          domainLogger!.error(
            LogDomain.agentRuntime,
            e,
            message: msg,
            stackTrace: s,
          );
        } else {
          developer.log(
            '$msg (errorType=${e.runtimeType})',
            name: 'TaskAgentService',
            error: e.runtimeType,
            stackTrace: s,
          );
        }
      }
    }

    domainLogger?.log(
      LogDomain.agentRuntime,
      'restored $count task agent subscriptions',
      subDomain: 'restore',
    );
  }
}
