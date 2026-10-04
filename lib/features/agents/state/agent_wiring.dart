import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/agent_runtime_registry.dart';
import 'package:lotti/features/agents/wake/project_update_slots.dart';
import 'package:lotti/features/agents/wake/wake_audit.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/logic/repositories/project_repository.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:riverpod/riverpod.dart';

/// Re-arms a project agent whenever the drain refuses one of its update
/// slots' wakes. The scheduled-wake manager consumes a slot before the wake
/// reaches the drain, so a refusal — the day's budget used up, a claim that
/// could not be written — would otherwise leave a stale report with no slot
/// pending until some unrelated change armed one.
void wireProjectSlotRefusals(Ref ref, WakeOrchestrator orchestrator) {
  final rearm = rearmRefusedProjectSlot(ref);
  final subscription = orchestrator.runCompletions.listen((completion) {
    final error = completion.error;
    final agentId = completion.agentId;
    if (error is! WakeRefusedError ||
        agentId == null ||
        !completion.triggerTokens.contains(ProjectUpdateSlots.triggerToken)) {
      return;
    }
    unawaited(
      rearm(agentId, error.cause).catchError((Object error, StackTrace st) {
        developer.log(
          'failed to re-arm a refused project update slot',
          name: 'wireProjectSlotRefusals',
          error: error,
          stackTrace: st,
        );
      }),
    );
  });
  ref.onDispose(subscription.cancel);
}

/// Wires the wake executor into the orchestrator, routing to the appropriate
/// workflow based on the agent's `kind` field.
///
/// [retireIfSuperseded] is the task-agent wake gate
/// (`TaskAgentRetirement.retireIfSuperseded`): it returns `true` when it
/// retired the agent about to wake, which then does not run.
void wireWakeExecutor(
  Ref ref,
  WakeOrchestrator orchestrator,
  TaskAgentWorkflow workflow,
  UpdateNotifications updateNotifications, {
  required Future<bool> Function(String agentId) retireIfSuperseded,
}) {
  orchestrator.wakeExecutor = (agentId, runKey, triggers, threadId) async {
    final agentService = ref.read(agentServiceProvider);
    final identity = await agentService.getAgent(agentId);
    if (identity == null) return null;

    // Route to appropriate workflow based on agent kind.
    if (identity.kind == AgentKinds.templateImprover) {
      final improverWorkflow = ref.read(improverAgentWorkflowProvider);
      final result = await improverWorkflow.execute(
        agentIdentity: identity,
        runKey: runKey,
        threadId: threadId,
      );

      if (!result.success) {
        throw WakeFailedException(
          kind: 'improver',
          reason: result.error ?? 'wake failed',
        );
      }

      await _notifyWakeCompletion(
        ref,
        agentId: agentId,
        updateNotifications: updateNotifications,
      );

      return result.mutatedEntries;
    }

    if (identity.kind == AgentKinds.projectAgent) {
      final projectWorkflow = ref.read(projectAgentWorkflowProvider);
      final result = await projectWorkflow.execute(
        agentIdentity: identity,
        runKey: runKey,
        triggerTokens: triggers,
        threadId: threadId,
      );

      if (!result.success) {
        throw WakeFailedException(
          kind: 'project',
          reason: result.error ?? 'wake failed',
        );
      }

      await _notifyWakeCompletion(
        ref,
        agentId: agentId,
        updateNotifications: updateNotifications,
      );

      return result.mutatedEntries;
    }

    if (identity.kind == AgentKinds.eventAgent) {
      final eventWorkflow = ref.read(eventAgentWorkflowProvider);
      final result = await eventWorkflow.execute(
        agentIdentity: identity,
        runKey: runKey,
        triggerTokens: triggers,
        threadId: threadId,
      );

      if (!result.success) {
        throw WakeFailedException(
          kind: 'event',
          reason: result.error ?? 'wake failed',
        );
      }

      await _notifyWakeCompletion(
        ref,
        agentId: agentId,
        updateNotifications: updateNotifications,
        extraTokens: triggers,
      );

      return result.mutatedEntries;
    }

    // Kinds contributed by their owning feature (see agentWakeRunnersProvider).
    // Consulted before the task-agent default so an owning feature can add a
    // kind without this file naming it.
    final registeredRunner = ref.read(agentWakeRunnersProvider)[identity.kind];
    if (registeredRunner != null) {
      final result = await registeredRunner(
        agentIdentity: identity,
        runKey: runKey,
        triggerTokens: triggers,
        threadId: threadId,
      );

      if (!result.success) {
        throw WakeFailedException(
          kind: identity.kind,
          reason: result.error ?? 'wake failed',
        );
      }

      await _notifyWakeCompletion(
        ref,
        agentId: agentId,
        updateNotifications: updateNotifications,
        extraTokens: triggers,
      );

      // Kinds whose workflows manage their own report freshness propagate
      // the verdict (the goal-only condition, generalized for the
      // relationship kind — ADR 0059 Decision 2). The day agent stays on
      // the bare-list return: its workflows never set `reportUpdated`, and
      // the drain engine reads a bare list as "report fresh".
      return identity.kind == AgentKinds.goalAgent ||
              identity.kind == AgentKinds.relationshipAgent
          ? WakeExecutorResult(
              result.mutatedEntries,
              reportUpdated: result.reportUpdated,
            )
          : result.mutatedEntries;
    }

    // Default: task agent workflow. A task agent that lost its task to
    // another agent (ADR 0104) is retired here instead of running: the sync
    // pass may not have run yet on this device, and the loser must not write
    // a report or proposals the task's agent also writes.
    if (identity.kind == AgentKinds.taskAgent &&
        await retireIfSuperseded(agentId)) {
      return null;
    }
    final result = await workflow.execute(
      agentIdentity: identity,
      runKey: runKey,
      triggerTokens: triggers,
      threadId: threadId,
    );

    // Propagate workflow-level failures to the orchestrator by throwing.
    // WakeOrchestrator converts executor exceptions into failed wake-run
    // status, ensuring run-log accuracy.
    if (!result.success) {
      throw WakeFailedException(
        kind: 'task',
        reason: result.error ?? 'wake failed',
      );
    }

    final extraTokens = <String>{};
    try {
      final taskLinks = await ref
          .read(agentRepositoryProvider)
          .getLinksFrom(
            agentId,
            type: AgentLinkTypes.agentTask,
          );
      if (taskLinks.isNotEmpty) {
        final primaryTaskLink = taskLinks.toList()
          ..sort((a, b) {
            final byCreatedAt = b.createdAt.compareTo(a.createdAt);
            if (byCreatedAt != 0) {
              return byCreatedAt;
            }
            return b.id.compareTo(a.id);
          });
        final taskId = primaryTaskLink.first.toId;
        extraTokens.add(taskId);

        final project = await ref
            .read(projectRepositoryProvider)
            .getProjectForTask(taskId);
        final projectId = project?.meta.id;
        if (projectId != null) {
          extraTokens.add(projectId);
        }
      }
    } catch (error, stackTrace) {
      developer.log(
        'Failed to resolve task/project wake notification tokens '
        '(errorType=${error.runtimeType})',
        name: 'agentInitialization',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
    }

    await _notifyWakeCompletion(
      ref,
      agentId: agentId,
      updateNotifications: updateNotifications,
      extraTokens: extraTokens,
    );

    return result.mutatedEntries;
  };
}

/// Notify the update stream so all detail providers self-invalidate.
///
/// Include the templateId (if assigned) so template-level aggregate
/// providers also refresh. Wrapped in try/catch so a lookup failure
/// doesn't mark a successfully completed wake as failed.
Future<void> _notifyWakeCompletion(
  Ref ref, {
  required String agentId,
  required UpdateNotifications updateNotifications,
  Set<String> extraTokens = const {},
}) async {
  String? templateId;
  try {
    final templateService = ref.read(agentTemplateServiceProvider);
    final template = await templateService.getTemplateForAgent(agentId);
    templateId = template?.id;
  } catch (error, stackTrace) {
    developer.log(
      'Failed to resolve template for wake notification '
      '(errorType=${error.runtimeType})',
      name: 'agentInitialization',
      error: error.runtimeType,
      stackTrace: stackTrace,
    );
  }

  updateNotifications.notifyUiOnly({
    agentId,
    ?templateId,
    agentNotification,
    ...extraTokens,
  });
}

/// Hands the agent repository to the [SyncEventProcessor] and its backfill
/// handler, so incoming agent entities and links are stored and backfill
/// requests for them answered.
///
/// This is sync's only hard dependency on the agent feature, and it needs
/// nothing but the agent database: `agentInitialization` calls it before it
/// resolves any runtime provider, so a runtime that fails to build or start
/// can never leave sync unable to store another device's agents. The runtime
/// half is [wireSyncEventProcessor].
void wireAgentSyncRepository(Ref ref, SyncEventProcessor? processor) {
  if (processor == null) return;
  final repository = ref.read(agentRepositoryProvider);
  processor.agentRepository = repository;
  processor.backfillResponseHandler.agentRepository = repository;
  ref.onDispose(() {
    processor.agentRepository = null;
    processor.backfillResponseHandler.agentRepository = null;
  });
}

/// Wires the wake runtime into the [SyncEventProcessor] so that incoming
/// lifecycle changes (pause/destroy from another device) restore/remove
/// subscriptions. The repository comes earlier, from
/// [wireAgentSyncRepository].
///
/// [retireSupersededTaskAgents] runs the retirement pass
/// (`TaskAgentRetirement.retireSuperseded`) for a task whose `agent_task`
/// link or task agent the processor has just applied.
void wireSyncEventProcessor(
  Ref ref,
  WakeOrchestrator orchestrator,
  SyncEventProcessor? processor, {
  required Future<void> Function(String taskId) retireSupersededTaskAgents,
}) {
  if (processor == null) return;
  processor
    ..wakeOrchestrator = orchestrator
    ..agentWakeCoordinator = ref.read(agentWakeCoordinatorProvider)
    // Feature-owned runtime mirrors (goal agents today): a synced-in
    // identity is offered to each contributor so subscriptions follow the
    // agent onto this device mid-session.
    ..runtimeMaintenance = ref.read(agentRuntimeMaintenanceProvider)
    ..retireSupersededTaskAgents = retireSupersededTaskAgents
    ..armProjectUpdate = armProjectUpdate(ref);
  ref.onDispose(() {
    processor
      ..wakeOrchestrator = null
      ..agentWakeCoordinator = null
      ..runtimeMaintenance = const []
      ..retireSupersededTaskAgents = null
      ..armProjectUpdate = null;
  });
}
