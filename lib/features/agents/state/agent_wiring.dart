import 'dart:developer' as developer;

import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:riverpod/riverpod.dart';

/// Wires the wake executor into the orchestrator, routing to the appropriate
/// workflow based on the agent's `kind` field.
void wireWakeExecutor(
  Ref ref,
  WakeOrchestrator orchestrator,
  TaskAgentWorkflow workflow,
  UpdateNotifications updateNotifications,
) {
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
        throw StateError(result.error ?? 'Improver agent wake failed');
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
        throw StateError(result.error ?? 'Project agent wake failed');
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
        throw StateError(result.error ?? 'Event agent wake failed');
      }

      await _notifyWakeCompletion(
        ref,
        agentId: agentId,
        updateNotifications: updateNotifications,
        extraTokens: triggers,
      );

      return result.mutatedEntries;
    }

    if (identity.kind == AgentKinds.dayAgent) {
      final dayWorkflow = ref.read(dayAgentWorkflowProvider);
      final result = await dayWorkflow.execute(
        agentIdentity: identity,
        runKey: runKey,
        triggerTokens: triggers,
        threadId: threadId,
      );

      if (!result.success) {
        throw StateError(result.error ?? 'Day agent wake failed');
      }

      await _notifyWakeCompletion(
        ref,
        agentId: agentId,
        updateNotifications: updateNotifications,
        extraTokens: triggers,
      );

      return result.mutatedEntries;
    }

    // Default: task agent workflow.
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
      throw StateError(result.error ?? 'Task agent wake failed');
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

/// Wires the agent repository and wake orchestrator into the
/// [SyncEventProcessor] so that incoming agent data is persisted and incoming
/// lifecycle changes (pause/destroy from another device) restore/remove
/// subscriptions.
void wireSyncEventProcessor(
  Ref ref,
  WakeOrchestrator orchestrator,
  SyncEventProcessor? processor,
) {
  if (processor == null) return;
  final repository = ref.read(agentRepositoryProvider);
  processor
    ..agentRepository = repository
    ..wakeOrchestrator = orchestrator;
  // Also wire the agent repository into the backfill handler so it can
  // look up agent entities and links when responding to backfill requests.
  processor.backfillResponseHandler.agentRepository = repository;
  ref.onDispose(() {
    processor
      ..agentRepository = null
      ..wakeOrchestrator = null;
    processor.backfillResponseHandler.agentRepository = null;
  });
}
