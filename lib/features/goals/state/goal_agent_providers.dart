import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/goal_trigger_tokens.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/service/change_set_confirmation_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/agent_runtime_registry.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_reader.dart';
import 'package:lotti/features/goals/runtime/goal_agent_phase_a.dart';
import 'package:lotti/features/goals/runtime/goal_runtime_maintenance.dart';
import 'package:lotti/features/goals/service/goal_agent_service.dart';
import 'package:lotti/features/goals/service/goal_spec_revision_service.dart';
import 'package:lotti/features/goals/sync/goal_signal_sync_dispatcher.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/features/goals/workflow/goal_agent_workflow.dart';
import 'package:lotti/features/goals/workflow/goal_tool_dispatcher.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;

/// Goal-agent runtime wiring (the Daily OS plug-in pattern: providers live
/// in the owning feature; `features/agents` never imports goals).

final goalSignalReaderProvider = Provider<GoalSignalReader>(
  (ref) => GoalSignalReader(journalDb: ref.watch(journalDbProvider)),
  name: 'goalSignalReaderProvider',
);

final goalAgentPhaseAProvider = Provider<GoalAgentPhaseA>(
  (ref) => GoalAgentPhaseA(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    signalReader: ref.watch(goalSignalReaderProvider),
    // A locally armed escalation must not wait out the hourly poll.
    onEscalationArmed: () =>
        ref.read(scheduledWakeManagerProvider).requestCheck(),
  ),
  name: 'goalAgentPhaseAProvider',
);

final goalAgentServiceProvider = Provider<GoalAgentService>(
  (ref) => GoalAgentService(
    agentService: ref.watch(agentServiceProvider),
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
  ),
  name: 'goalAgentServiceProvider',
);

final goalAgentWorkflowProvider = Provider<GoalAgentWorkflow>(
  (ref) => GoalAgentWorkflow(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    phaseA: ref.watch(goalAgentPhaseAProvider),
    conversationRepository: ref.watch(conversationRepositoryProvider.notifier),
    cloudInferenceRepository: ref.watch(cloudInferenceRepositoryProvider),
    aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  ),
  name: 'goalAgentWorkflowProvider',
);

/// The goals contribution to `agentWakeRunnersProvider` — merged with the
/// other features' maps in `buildProviderOverrides`. An unmerged map means
/// goal wakes silently fall back to the task-agent workflow, which the
/// bootstrap regression test pins against.
///
/// The router: an escalation trigger token selects the lease-elected LLM
/// tier (Phase B); every other wake — cadence, signals, creation — runs
/// the deterministic €0 tier (ADR 0054's two-tier contract).
final goalAgentWakeRunnersProvider = Provider<Map<String, AgentWakeRunner>>(
  (ref) => <String, AgentWakeRunner>{
    AgentKinds.goalAgent:
        ({
          required agentIdentity,
          required runKey,
          required triggerTokens,
          required threadId,
        }) => goalEscalationPeriodFromTriggerTokens(triggerTokens) != null
        ? ref
              .read(goalAgentWorkflowProvider)
              .execute(
                agentIdentity: agentIdentity,
                runKey: runKey,
                triggerTokens: triggerTokens,
                threadId: threadId,
              )
        : ref
              .read(goalAgentPhaseAProvider)
              .execute(
                agentIdentity: agentIdentity,
                runKey: runKey,
                triggerTokens: triggerTokens,
                threadId: threadId,
              ),
  },
  name: 'goalAgentWakeRunnersProvider',
);

/// The goals contribution to `agentRuntimeMaintenanceProvider`.
final goalRuntimeMaintenanceProvider = Provider<GoalRuntimeMaintenance>(
  (ref) => GoalRuntimeMaintenance(
    agentService: ref.watch(agentServiceProvider),
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    goalAgentService: ref.watch(goalAgentServiceProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  ),
  name: 'goalRuntimeMaintenanceProvider',
);

final goalSignalSyncDispatcherProvider = Provider<GoalSignalSyncDispatcher>(
  (ref) => GoalSignalSyncDispatcher(
    agentService: ref.watch(agentServiceProvider),
    repository: ref.watch(agentRepositoryProvider),
    phaseA: ref.watch(goalAgentPhaseAProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  ),
  name: 'goalSignalSyncDispatcherProvider',
);

/// Constructed for app lifetime via `ref.listen` in the app shell (the
/// synced-audio listener pattern).
final goalSignalSyncListenerProvider = Provider<GoalSignalSyncListener>(
  (ref) {
    final listener = GoalSignalSyncListener(
      updateNotifications: ref.watch(updateNotificationsProvider),
      dispatcher: ref.watch(goalSignalSyncDispatcherProvider),
      domainLogger: ref.watch(domainLoggerProvider),
    )..start();
    ref.onDispose(listener.dispose);
    return listener;
  },
  name: 'goalSignalSyncListenerProvider',
);

/// Revision minting for accepted `propose_goal_revision` proposals.
final goalSpecRevisionServiceProvider = Provider<GoalSpecRevisionService>(
  (ref) => GoalSpecRevisionService(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
  ),
  name: 'goalSpecRevisionServiceProvider',
);

/// Goal-scoped confirmation service: accepting a revision proposal mints
/// the new spec version and moves the head via [GoalToolDispatcher];
/// rejection only records the decision. After a confirmed revision the
/// runtime re-registers the goal's signal subscriptions — the criteria
/// may now reference different signals.
final goalChangeSetConfirmationServiceProvider =
    Provider<ChangeSetConfirmationService>(
      (ref) => ChangeSetConfirmationService(
        syncService: ref.watch(agentSyncServiceProvider),
        toolDispatcher: GoalToolDispatcher(
          revisionService: ref.watch(goalSpecRevisionServiceProvider),
        ).dispatch,
        labelsRepository: ref.watch(labelsRepositoryProvider),
        domainLogger: ref.watch(domainLoggerProvider),
        onConfirmedDecision:
            ({required changeSet, required item, required decision}) async {
              if (item.toolName != GoalAgentToolNames.proposeGoalRevision) {
                return;
              }
              final repository = ref.read(agentRepositoryProvider);
              final head = await repository.getEntity(
                goalSpecHeadId(changeSet.agentId),
              );
              if (head is! GoalSpecHeadEntity) return;
              final version = await repository.getEntity(head.versionId);
              if (version is! GoalSpecVersionEntity) return;
              ref
                  .read(goalAgentServiceProvider)
                  .registerSignalSubscription(
                    changeSet.agentId,
                    version.criteria,
                  );
            },
      ),
      name: 'goalChangeSetConfirmationServiceProvider',
    );
