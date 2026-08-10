import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/classes/goal_trigger_tokens.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
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
import 'package:lotti/features/goals/service/goal_nudge_interactions.dart';
import 'package:lotti/features/goals/service/goal_spec_revision_service.dart';
import 'package:lotti/features/goals/sync/goal_signal_sync_dispatcher.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/features/goals/workflow/goal_agent_workflow.dart';
import 'package:lotti/features/goals/workflow/goal_tool_dispatcher.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/db_notification.dart' show agentNotification;
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';

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
              final version = head is GoalSpecHeadEntity
                  ? await repository.getEntity(head.versionId)
                  : null;
              if (version is! GoalSpecVersionEntity) {
                // A confirmed revision whose head/version cannot be read
                // back leaves the runtime subscribed to the OLD criteria
                // until restart — visible, not silent.
                ref
                    .read(domainLoggerProvider)
                    .error(
                      LogDomain.agentRuntime,
                      StateError(
                        'goal spec unreadable after confirmed revision',
                      ),
                      subDomain: 'goalRevision',
                      message:
                          'signal re-registration skipped for '
                          '${changeSet.agentId}',
                    );
                return;
              }
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

/// The user's side of the ad contract: dismiss, rate, account exposure.
final goalNudgeInteractionsProvider = Provider<GoalNudgeInteractions>(
  (ref) => GoalNudgeInteractions(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
  ),
  name: 'goalNudgeInteractionsProvider',
);

/// One live goal banner: the nudge plus the goal it advertises for.
typedef GoalBannerEntry = ({GoalNudgeEntity nudge, String goalTitle});

/// The ACTIVE banners across all active goal agents, newest first.
///
/// Watches the agent-level notification token so wake writes refresh it;
/// interaction writes go through the sync service (which deliberately
/// does not notify), so the UI handlers invalidate this provider after
/// dismiss/rate.
final FutureProvider<List<GoalBannerEntry>> activeGoalNudgesProvider =
    FutureProvider.autoDispose<List<GoalBannerEntry>>((ref) async {
      // The banner mounts are unconditional on their host pages, so the
      // rollout flag gates HERE: agents off → no banners, even for ads
      // that synced in from a device that has the feature enabled.
      final agentsEnabled =
          ref.watch(configFlagProvider(enableAgentsPageFlag)).value ?? false;
      if (!agentsEnabled) return const [];
      ref.watch(agentUpdateStreamProvider(agentNotification));
      final agents = await ref
          .watch(agentServiceProvider)
          .listAgents(lifecycle: AgentLifecycle.active);
      final repository = ref.watch(agentRepositoryProvider);
      final entries = <GoalBannerEntry>[];
      for (final identity in agents) {
        if (identity.kind != AgentKinds.goalAgent) continue;
        ref.watch(agentUpdateStreamProvider(identity.agentId));
        final now = clock.now();
        final nudges =
            (await repository.getEntitiesByAgentId(
              identity.agentId,
              type: AgentEntityTypes.goalNudge,
            )).whereType<GoalNudgeEntity>().where(
              // Staleness is a contract, not a hope (ADR 0055): an ad
              // past its deadline stops RENDERING immediately, even
              // though only a later Phase B wake retires the row.
              (n) =>
                  n.deletedAt == null &&
                  n.status == GoalNudgeStatus.active &&
                  (n.staleAt == null || now.isBefore(n.staleAt!)),
            );
        for (final nudge in nudges) {
          entries.add((nudge: nudge, goalTitle: identity.displayName));
        }
      }
      entries.sort(
        (a, b) => (b.nudge.activatedAt ?? b.nudge.createdAt).compareTo(
          a.nudge.activatedAt ?? a.nudge.createdAt,
        ),
      );
      // The staleness deadline is honoured without an agent notification:
      // `now` was sampled once above, so a banner served before its
      // `staleAt` would otherwise keep rendering until some unrelated
      // event recomputed this provider. Re-evaluate at the earliest
      // deadline still ahead of us.
      final nextDeadline = entries
          .map((e) => e.nudge.staleAt)
          .whereType<DateTime>()
          .where((t) => t.isAfter(clock.now()))
          .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
      if (nextDeadline != null) {
        final timer = Timer(
          nextDeadline.difference(clock.now()),
          ref.invalidateSelf,
        );
        ref.onDispose(timer.cancel);
      }
      return entries;
    }, name: 'activeGoalNudgesProvider');

/// The active goal agents, for the settings list and approval surface.
final FutureProvider<List<AgentIdentityEntity>> activeGoalAgentsProvider =
    FutureProvider.autoDispose<List<AgentIdentityEntity>>((ref) async {
      ref.watch(agentUpdateStreamProvider(agentNotification));
      final agents = await ref
          .watch(agentServiceProvider)
          .listAgents(lifecycle: AgentLifecycle.active);
      return [
        for (final identity in agents)
          if (identity.kind == AgentKinds.goalAgent) identity,
      ];
    }, name: 'activeGoalAgentsProvider');

/// Fire-and-forget exposure flush, captured by the banner's tracker
/// while its element is live and safe to call from `dispose`.
typedef GoalNudgeInteractionsFlush =
    void Function(String nudgeId, Duration visibleFor);

final goalNudgeExposureFlushProvider = Provider<GoalNudgeInteractionsFlush>(
  (ref) {
    final interactions = ref.watch(goalNudgeInteractionsProvider);
    final logger = ref.watch(domainLoggerProvider);
    return (nudgeId, visibleFor) {
      // The dispose path cannot await this, so a persistence failure must
      // be contained here — logged, never an uncaught async error.
      unawaited(
        interactions.recordExposure(nudgeId, visibleFor: visibleFor).catchError(
          (Object e, StackTrace st) {
            logger.error(
              LogDomain.agentRuntime,
              e,
              stackTrace: st,
              subDomain: 'goalNudgeExposure',
              message: 'exposure flush for $nudgeId was not persisted',
            );
          },
        ),
      );
    };
  },
  name: 'goalNudgeExposureFlushProvider',
);

/// Health-at-a-glance for one goal agent: the latest register verdict,
/// the standing report's one-liner, and whether a revision proposal
/// waits for review.
typedef GoalAgentHealth = ({
  GoalTrackStatus? trackStatus,
  double? attainment,
  String? reportOneLiner,
  int pendingProposals,
  GoalSpecVersionEntity? spec,
});

final FutureProviderFamily<GoalAgentHealth, String> goalAgentHealthProvider =
    FutureProvider.autoDispose.family<GoalAgentHealth, String>((
      ref,
      agentId,
    ) async {
      ref.watch(agentUpdateStreamProvider(agentId));
      final repository = ref.watch(agentRepositoryProvider);

      final head = await repository.getEntity(goalSpecHeadId(agentId));
      final specEntity = head is GoalSpecHeadEntity
          ? await repository.getEntity(head.versionId)
          : null;
      final spec = specEntity is GoalSpecVersionEntity ? specEntity : null;

      final registers =
          (await repository.getEntitiesByAgentId(
                agentId,
                type: AgentEntityTypes.goalProgress,
              ))
              .whereType<GoalProgressEntity>()
              .where(
                // Only the active spec version's registers count: after a
                // revision is approved, showing the PREVIOUS goal's verdict
                // beside the new statement would misreport health until
                // Phase A writes the first register for the new version.
                (row) =>
                    row.deletedAt == null &&
                    (spec == null || row.specVersionId == spec.id),
              )
              .toList()
            ..sort((a, b) => b.periodKey.compareTo(a.periodKey));
      final latest = registers.firstOrNull;

      final latestReport = await repository.getLatestReport(
        agentId,
        AgentReportScopes.current,
      );
      // A standing report written BEFORE the active spec version was
      // minted describes the superseded goal — showing its one-liner
      // beside the revised statement would misreport, so it is withheld
      // until the revised goal's first report lands.
      final report =
          latestReport != null &&
              (spec == null || !latestReport.createdAt.isBefore(spec.createdAt))
          ? latestReport
          : null;

      final pending = await repository.getPendingChangeSets(
        agentId,
        taskId: agentId,
      );

      return (
        trackStatus: latest?.trackStatus,
        attainment: latest?.attainment,
        reportOneLiner: report?.oneLiner,
        pendingProposals: pending.length,
        spec: spec,
      );
    }, name: 'goalAgentHealthProvider');
