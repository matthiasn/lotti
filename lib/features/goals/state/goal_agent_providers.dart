import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_trigger_tokens.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/change_set_confirmation_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/agent_runtime_registry.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart'
    show WakeRunCompletion;
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_reader.dart';
import 'package:lotti/features/goals/model/goal_checkin_source.dart';
import 'package:lotti/features/goals/repository/goal_repository.dart';
import 'package:lotti/features/goals/runtime/goal_agent_phase_a.dart';
import 'package:lotti/features/goals/runtime/goal_runtime_maintenance.dart';
import 'package:lotti/features/goals/service/goal_agent_service.dart';
import 'package:lotti/features/goals/service/goal_chat_service.dart';
import 'package:lotti/features/goals/service/goal_checkin_compactor.dart';
import 'package:lotti/features/goals/service/goal_checkin_notifier.dart';
import 'package:lotti/features/goals/service/goal_mirror_service.dart';
import 'package:lotti/features/goals/service/goal_spec_revision_service.dart';
import 'package:lotti/features/goals/sync/goal_signal_sync_dispatcher.dart';
import 'package:lotti/features/goals/ui/goal_routes.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/features/goals/workflow/goal_agent_workflow.dart';
import 'package:lotti/features/goals/workflow/goal_tool_dispatcher.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/nudges/logic/nudge_banner_snooze.dart';
import 'package:lotti/features/nudges/model/nudge_banner_entry.dart';
import 'package:lotti/features/nudges/model/nudge_entity_view.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/db_notification.dart'
    show UpdateNotifications, agentNotification;
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/consts.dart';

/// Goal-agent runtime wiring (the Daily OS plug-in pattern: providers live
/// in the owning feature; `features/agents` never imports goals).

final goalSignalReaderProvider = Provider<GoalSignalReader>(
  (ref) => GoalSignalReader(
    journalDb: ref.watch(journalDbProvider),
    timeService: getIt.isRegistered<TimeService>()
        ? getIt<TimeService>()
        : null,
  ),
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
    // New evidence after today's earlier tick dirties the standing report
    // without necessarily transitioning the status — persist the stale
    // watermark so the detail page shows the badge and Update now CTA.
    onReportStale: (agentId) =>
        ref.read(agentServiceProvider).markReportStale(agentId),
    onReportRefreshNeeded: (agentId) => ref
        .read(goalAgentServiceProvider)
        .scheduleAutomaticReportRefresh(agentId),
  ),
  name: 'goalAgentPhaseAProvider',
);

/// Journal-side goal persistence, or null where the journal stack is not
/// registered.
///
/// Nullable on purpose. The agent tier is authoritative for evaluation and
/// must not acquire a hard dependency on journal infrastructure — a goal whose
/// mirror is unavailable is still a working goal, and the startup backfill
/// repairs it. Making this non-null turned every agent-tier test into one that
/// had to stand up `PersistenceLogic` to construct a provider it never used.
final goalRepositoryProvider = Provider<GoalRepository?>((ref) {
  if (!getIt.isRegistered<JournalDb>() ||
      !getIt.isRegistered<PersistenceLogic>() ||
      !getIt.isRegistered<MetadataService>()) {
    return null;
  }
  return GoalRepository(
    journalDb: getIt<JournalDb>(),
    persistenceLogic: getIt<PersistenceLogic>(),
    metadataService: getIt<MetadataService>(),
  );
}, name: 'goalRepositoryProvider');

final goalMirrorServiceProvider = Provider<GoalMirrorService?>((ref) {
  final repository = ref.watch(goalRepositoryProvider);
  if (repository == null) return null;
  return GoalMirrorService(
    goalRepository: repository,
    agentRepository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  );
}, name: 'goalMirrorServiceProvider');

final goalAgentServiceProvider = Provider<GoalAgentService>(
  (ref) => GoalAgentService(
    agentService: ref.watch(agentServiceProvider),
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
    updateNotifications: getIt<UpdateNotifications>(),
    goalMirrorService: ref.watch(goalMirrorServiceProvider),
  ),
  name: 'goalAgentServiceProvider',
);

final goalChatServiceProvider = Provider<GoalChatService>(
  (ref) => GoalChatService(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
  ),
  name: 'goalChatServiceProvider',
);

/// Distills check-ins for the agent. Null where the AI stack is unavailable.
final Provider<GoalCheckInCompactor?> goalCheckInCompactorProvider =
    Provider<GoalCheckInCompactor?>(
      (ref) => GoalCheckInCompactor(
        inferenceRepository: ref.watch(cloudInferenceRepositoryProvider),
        syncService: ref.watch(agentSyncServiceProvider),
      ),
      name: 'goalCheckInCompactorProvider',
    );

/// Reads a goal's check-ins out of the journal for the headless workflow.
///
/// A function rather than a repository handle, so the agent tier depends on
/// the shape of the data and not on the journal stack.
final Provider<GoalCheckInSourceReader?> goalCheckInSourceReaderProvider =
    Provider<GoalCheckInSourceReader?>((ref) {
      final repository = ref.watch(goalRepositoryProvider);
      if (repository == null) return null;
      return (agentId) async {
        final goalId = repository.goalIdForAgent(agentId);
        final links = await getIt<JournalDb>().linksFromIds([goalId]).get();
        final ids = links.map((link) => link.toId).toSet();
        if (ids.isEmpty) return const [];
        final entities = await getIt<JournalDb>().getJournalEntitiesForIds(ids);
        return [
          for (final entity in entities)
            if (entity is JournalAudio || entity is JournalEntry)
              if (entity.entryText?.plainText.trim() ?? '' case final text
                  when text.isNotEmpty)
                GoalCheckInSource(
                  entryId: entity.meta.id,
                  recordedAt: entity.meta.dateFrom,
                  text: text,
                ),
        ];
      };
    }, name: 'goalCheckInSourceReaderProvider');

final goalAgentWorkflowProvider = Provider<GoalAgentWorkflow>(
  (ref) => GoalAgentWorkflow(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    phaseA: ref.watch(goalAgentPhaseAProvider),
    conversationRepository: ref.watch(conversationRepositoryProvider.notifier),
    cloudInferenceRepository: ref.watch(cloudInferenceRepositoryProvider),
    aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
    checkInCompactor: ref.watch(goalCheckInCompactorProvider),
    checkInSourceReader: ref.watch(goalCheckInSourceReaderProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  ),
  name: 'goalAgentWorkflowProvider',
);

/// The goals contribution to `agentWakeRunnersProvider` — merged with the
/// other features' maps in `buildProviderOverrides`. An unmerged map means
/// goal wakes silently fall back to the task-agent workflow, which the
/// bootstrap regression test pins against.
///
/// The router: an escalation token or explicit report-refresh token selects
/// the fact-grounded LLM tier (Phase B); every other wake — cadence, signals,
/// creation — runs the deterministic €0 tier (ADR 0054's two-tier contract).
final goalAgentWakeRunnersProvider = Provider<Map<String, AgentWakeRunner>>(
  (ref) => <String, AgentWakeRunner>{
    AgentKinds.goalAgent:
        ({
          required agentIdentity,
          required runKey,
          required triggerTokens,
          required threadId,
        }) {
          final chatMessageId = goalChatMessageIdFromTriggerTokens(
            triggerTokens,
          );
          if (chatMessageId != null) {
            return ref
                .read(goalAgentWorkflowProvider)
                .executeUserMessage(
                  agentIdentity: agentIdentity,
                  runKey: runKey,
                  triggerTokens: triggerTokens,
                  threadId: threadId,
                  messageId: chatMessageId,
                );
          }
          return goalEscalationPeriodFromTriggerTokens(triggerTokens) != null ||
                  goalReportRefreshRequested(triggerTokens)
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
                    );
        },
  },
  name: 'goalAgentWakeRunnersProvider',
);

/// The goals contribution to `agentRuntimeMaintenanceProvider`.
final Provider<GoalCheckInNotifier?> goalCheckInNotifierProvider =
    Provider<GoalCheckInNotifier?>((ref) {
      final repository = ref.watch(goalRepositoryProvider);
      if (repository == null) return null;
      return GoalCheckInNotifier(
        goalRepository: repository,
        agentService: ref.watch(agentServiceProvider),
        updateNotifications: getIt<UpdateNotifications>(),
      );
    }, name: 'goalCheckInNotifierProvider');

final goalRuntimeMaintenanceProvider = Provider<GoalRuntimeMaintenance>(
  (ref) => GoalRuntimeMaintenance(
    agentService: ref.watch(agentServiceProvider),
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    goalAgentService: ref.watch(goalAgentServiceProvider),
    goalMirrorService: ref.watch(goalMirrorServiceProvider),
    checkInNotifier: ref.watch(goalCheckInNotifierProvider),
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
    // A synced-batch Phase A run persists new attainment without any UI
    // notification — surface it to the health projections.
    onAgentEvaluated: (agentId) =>
        ref.read(updateNotificationsProvider).notify({agentId}),
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

/// Revision minting for accepted `propose_goal_revision_v2` proposals.
final goalSpecRevisionServiceProvider = Provider<GoalSpecRevisionService>(
  (ref) => GoalSpecRevisionService(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    goalMirrorService: ref.watch(goalMirrorServiceProvider),
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
              if (!GoalAgentToolNames.isGoalRevisionProposal(item.toolName)) {
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
                  .refreshAfterRevision(
                    agentId: changeSet.agentId,
                    criteria: version.criteria,
                  );
              // The revision sweep superseded the old spec's banners, but
              // the banner provider's per-agent stream dependency is
              // registered after an async gap and cannot be relied on —
              // refresh both surfaces explicitly.
              ref
                ..invalidate(activeGoalNudgesProvider)
                ..invalidate(goalNudgeHistoryProvider);
            },
      ),
      name: 'goalChangeSetConfirmationServiceProvider',
    );

/// The ACTIVE goal banners across all active goal agents, newest first —
/// the goal kind's registered source for the shared banner dock
/// (`nudgeBannerSourcesProvider`, merged in `app_bootstrap.dart`).
///
/// Watches the agent-level notification token so wake writes refresh it;
/// interaction writes go through the sync service (which deliberately
/// does not notify), so the UI handlers invalidate this provider after
/// visibility/rating actions.
final FutureProvider<List<NudgeBannerEntry>> activeGoalNudgesProvider =
    FutureProvider.autoDispose<List<NudgeBannerEntry>>((ref) async {
      // The banner mounts are unconditional on their host pages, so the
      // rollout flag gates HERE: with the unified Goals surface off → no
      // banners, even for ads that synced in from a device that has the
      // feature enabled — a banner tap would target a `/goals` route that
      // NavService normalizes away.
      final unifiedGoalsEnabled =
          ref.watch(configFlagProvider(enableUnifiedGoalsFlag)).value ?? false;
      if (!unifiedGoalsEnabled) return const [];
      final lifecycleListener = AppLifecycleListener(
        onResume: ref.invalidateSelf,
      );
      ref
        ..onDispose(lifecycleListener.dispose)
        ..watch(agentUpdateStreamProvider(agentNotification));
      final agents = await ref
          .watch(agentServiceProvider)
          .listAgents(lifecycle: AgentLifecycle.active);
      final repository = ref.watch(agentRepositoryProvider);
      final entries = <NudgeBannerEntry>[];
      final now = clock.now();
      DateTime? nextDeadline;
      void considerDeadline(DateTime? deadline) {
        if (deadline == null || !deadline.isAfter(now)) return;
        if (nextDeadline == null || deadline.isBefore(nextDeadline!)) {
          nextDeadline = deadline;
        }
      }

      for (final identity in agents) {
        if (identity.kind != AgentKinds.goalAgent) continue;
        ref.watch(agentUpdateStreamProvider(identity.agentId));
        // A banner created under a superseded spec can sync in AFTER the
        // revision sweep ran — its own provenance is the fence (Phase A
        // also sweeps it to `superseded` on the next wake).
        final head = await repository.getEntity(
          goalSpecHeadId(identity.agentId),
        );
        // The head must RESOLVE: a dangling pointer (partial sync) is
        // not a live spec, and a tagged banner validated against it
        // would render with no goal statement behind it.
        final headVersion = head is GoalSpecHeadEntity
            ? await repository.getEntity(head.versionId)
            : null;
        final activeVersionId = headVersion is GoalSpecVersionEntity
            ? headVersion.id
            : null;
        final nudges = (await repository.getEntitiesByAgentId(
          identity.agentId,
          type: AgentEntityTypes.goalNudge,
        )).whereType<GoalNudgeEntity>();
        for (final nudge in nudges) {
          final origin = nudge.provenance['specVersionId'];
          if (nudge.deletedAt != null ||
              nudge.status != NudgeStatus.active ||
              (origin is String &&
                  (activeVersionId == null || origin != activeVersionId))) {
            continue;
          }
          // Staleness ENDS a banner; snoozes and day dismissals only quiet
          // the SHELL dock. Hidden-from-the-bar rows therefore stay in this
          // list — the dock and the shell's reserved lane apply
          // `visibleNudgeBannerEntries` per surface, while the goal detail
          // page keeps the banner and captions it with the return
          // countdown. Deadlines still arm self-invalidation so every
          // surface refreshes when a quiet interval passes.
          considerDeadline(nudge.staleAt);
          if (nudge.staleAt != null && !now.isBefore(nudge.staleAt!)) continue;
          final view = NudgeEntityView.of(nudge)!;
          considerDeadline(nudgeBannerSnoozedUntil(view));
          if (nudgeBannerIsDismissedForDay(view, now)) {
            considerDeadline(nudgeBannerNextLocalMidnight(now));
          }
          entries.add((
            nudge: view,
            subjectTitle: headVersion is GoalSpecVersionEntity
                ? headVersion.title
                : identity.displayName,
            kind: NudgeBannerKind.goal,
            tapRoute: goalDetailPath(identity.agentId),
          ));
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
      if (nextDeadline != null) {
        final timer = Timer(
          nextDeadline!.difference(now),
          ref.invalidateSelf,
        );
        ref.onDispose(timer.cancel);
      }
      return entries;
    }, name: 'activeGoalNudgesProvider');

/// One goal's claim on a habit: the agent and its display title.
typedef GoalHabitMembership = ({String agentId, String title});

/// Goal titles per habit id across every ACTIVE goal agent — the source of
/// the detail page's "also in {goal}" suffix (design handover §5: a habit
/// appears under every goal it belongs to; recorded once, reflected
/// everywhere — so each card names the other goals sharing its habit).
final FutureProvider<Map<String, List<GoalHabitMembership>>>
goalHabitMembershipsProvider = FutureProvider.autoDispose((ref) async {
  // Spec revisions arrive as agent-entity writes; the shared notification
  // token refreshes the join when any goal's criteria change.
  ref.watch(agentUpdateStreamProvider(agentNotification));
  final agents = await ref.watch(activeGoalAgentsProvider.future);
  final repository = ref.watch(agentRepositoryProvider);
  // Two batched round trips — all heads, then all referenced versions —
  // instead of two awaited lookups per goal in sequence: the shared
  // notification token retriggers this join on every wake/report/chat
  // write, and per-goal awaits bypass the repository's same-turn
  // coalescing.
  final heads = await repository.getEntitiesByIds([
    for (final identity in agents) goalSpecHeadId(identity.agentId),
  ]);
  final versionIdByAgent = <String, String>{
    for (final identity in agents)
      if (heads[goalSpecHeadId(identity.agentId)] case GoalSpecHeadEntity(
        :final versionId,
      ))
        identity.agentId: versionId,
  };
  final versions = await repository.getEntitiesByIds(
    versionIdByAgent.values.toList(),
  );
  final memberships = <String, List<GoalHabitMembership>>{};
  for (final identity in agents) {
    final specEntity = versions[versionIdByAgent[identity.agentId]];
    if (specEntity is! GoalSpecVersionEntity) continue;
    final title = specEntity.title.trim().isNotEmpty
        ? specEntity.title
        : identity.displayName;
    for (final habitId in goalCriterionHabitIds(specEntity.criteria)) {
      memberships.putIfAbsent(habitId, () => []).add((
        agentId: identity.agentId,
        title: title,
      ));
    }
  }
  return memberships;
}, name: 'goalHabitMembershipsProvider');

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

/// The goal's PAST ads — every terminal nudge, newest outcome first —
/// for the detail page's durable interaction history (ADR 0055: past
/// ads and their outcomes remain browsable; only `draft`/`ready`
/// pipeline rows and generation failures stay internal).
final FutureProviderFamily<List<GoalNudgeEntity>, String>
goalNudgeHistoryProvider = FutureProvider.autoDispose
    .family<List<GoalNudgeEntity>, String>((ref, agentId) async {
      ref.watch(agentUpdateStreamProvider(agentId));
      final repository = ref.watch(agentRepositoryProvider);
      const shown = {
        NudgeStatus.dismissed,
        NudgeStatus.retired,
        NudgeStatus.expired,
        NudgeStatus.superseded,
      };
      // The timestamp of the CURRENT terminal state: a reactivated row
      // keeps its old retiredAt, so null-coalescing across all stamps
      // would file a re-expired banner under its first retirement.
      // updatedAt is mutable bookkeeping (exposure flushes bump it) and
      // only a legacy fallback.
      DateTime outcomeAt(GoalNudgeEntity n) => switch (n.status) {
        NudgeStatus.dismissed => n.dismissedAt ?? n.updatedAt,
        NudgeStatus.retired => n.retiredAt ?? n.updatedAt,
        NudgeStatus.expired => n.expiredAt ?? n.updatedAt,
        NudgeStatus.superseded => n.supersededAt ?? n.updatedAt,
        _ => n.updatedAt,
      };
      return (await repository.getEntitiesByAgentId(
            agentId,
            type: AgentEntityTypes.goalNudge,
          ))
          .whereType<GoalNudgeEntity>()
          .where((n) => n.deletedAt == null && shown.contains(n.status))
          .toList()
        ..sort((a, b) => outcomeAt(b).compareTo(outcomeAt(a)));
    }, name: 'goalNudgeHistoryProvider');

/// Health-at-a-glance for one goal agent: the latest register verdict,
/// the standing report's one-liner, and whether a revision proposal
/// waits for review.
typedef GoalAgentHealth = ({
  GoalTrackStatus? trackStatus,
  double? attainment,
  String? reportOneLiner,
  int pendingProposals,
  GoalSpecVersionEntity? spec,
  // The direction of travel across the two most recent registers — the
  // list row's arrow. Null until there are two registers to compare.
  GoalHealthDirection? direction,
  // Rolling-window habit goals only (from the latest register): days-to-
  // recovery, and the buffer before the oldest success ages out when at rate.
  // Null for calendar/metric goals and composites.
  int? deficit,
  int? buffer,
});

/// Whether comparing consecutive period registers' attainment is a sound
/// trend signal for [criterion]. Only rolling windows accumulate continuously;
/// day, calendar-week and calendar-month windows reset attainment at each
/// period boundary, so a consecutive-register delta there is a period reset,
/// not a decline. Composites require every child to be sound.
bool _attainmentTrendIsSound(GoalCriterion criterion) => switch (criterion) {
  GoalCriterionMetric(:final window) ||
  GoalCriterionMeasurable(:final window) ||
  GoalCriterionHabit(:final window) ||
  GoalCriterionCategoryTime(:final window) ||
  GoalCriterionLabelTime(:final window) => window is GoalWindowRollingDays,
  GoalCriterionAllOf(:final criteria) ||
  GoalCriterionAnyOf(:final criteria) ||
  GoalCriterionAtLeastCount(:final criteria) => criteria.every(
    _attainmentTrendIsSound,
  ),
};

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
                // No live spec (partial sync, dangling head) withholds
                // health entirely — stale attainment beside a blank goal
                // statement would misreport worse than an empty card.
                (row) =>
                    row.deletedAt == null &&
                    spec != null &&
                    row.specVersionId == spec.id,
              )
              .toList()
            ..sort((a, b) => b.periodKey.compareTo(a.periodKey));
      final latest = registers.firstOrNull;

      final latestReport = await repository.getLatestReport(
        agentId,
        AgentReportScopes.current,
      );
      // A standing report for a SUPERSEDED spec version must not caption
      // the revised statement. Scoped by the report's own spec-version
      // provenance (clock-skew-proof); reports predating that field fall
      // back to the mint-time comparison.
      final reportSpecId = latestReport?.provenance['specVersionId'];
      final reportMatchesSpec =
          latestReport != null &&
          spec != null &&
          (reportSpecId is String
              ? reportSpecId == spec.id
              : !latestReport.createdAt.isBefore(spec.createdAt));
      final report = reportMatchesSpec ? latestReport : null;

      final pending = await repository.getPendingChangeSets(
        agentId,
        taskId: agentId,
      );

      // Direction: the latest register's attainment against the one before
      // it (registers are the two most-recent non-deleted registers for the
      // ACTIVE spec version, filtered above). A small deadband keeps noise
      // from flickering the arrow; null until there are two to compare.
      //
      // Withheld when EITHER register is insufficient-data (attainment is not
      // judgeable there — a downward arrow beside "Not enough data" would
      // guilt-trip over a gap the policy says must not be judged), and only
      // computed when the goal's windows accumulate continuously. Calendar
      // and day windows RESET attainment each period, so subtracting
      // consecutive registers would emit a false decline at every boundary
      // (a weekly goal finishing at 1.0 then on-pace Monday at 0.33 is not
      // "down"); only rolling windows carry a sound cross-register trend.
      GoalHealthDirection? direction;
      if (registers.length >= 2 &&
          spec != null &&
          _attainmentTrendIsSound(spec.criteria) &&
          registers[0].trackStatus != GoalTrackStatus.insufficientData &&
          registers[1].trackStatus != GoalTrackStatus.insufficientData) {
        const deadband = 0.02;
        final delta = registers[0].attainment - registers[1].attainment;
        direction = delta > deadband
            ? GoalHealthDirection.up
            : delta < -deadband
            ? GoalHealthDirection.down
            : GoalHealthDirection.flat;
      }

      return (
        trackStatus: latest?.trackStatus,
        attainment: latest?.attainment,
        reportOneLiner: report?.oneLiner,
        pendingProposals: pending.length,
        spec: spec,
        direction: direction,
        deficit: latest?.deficit,
        buffer: latest?.buffer,
      );
    }, name: 'goalAgentHealthProvider');

/// Whether a REPORT-PRODUCING wake for the agent is executing right now.
///
/// Report wakes run in dedicated workspaces — the manual/automation refresh
/// in [goalReportRefreshTriggerToken] and escalations in per-period
/// `goal-escalation:<period>` workspaces — so this is the running-state the
/// failure line yields to. The agent-wide running flag would blink the line
/// away for every chat reply and Phase A subscription tick.
final StreamProviderFamily<bool, String> goalReportWakeInFlightProvider =
    StreamProvider.autoDispose.family<bool, String>(
      goalReportWakeInFlight,
      name: 'goalReportWakeInFlightProvider',
    );
Stream<bool> goalReportWakeInFlight(Ref ref, String agentId) async* {
  final runner = ref.watch(wakeRunnerProvider);
  bool matches() {
    if (!runner.isRunning(agentId)) return false;
    final workspaceKey = runner.workspaceKeyFor(agentId);
    return workspaceKey == goalReportRefreshTriggerToken ||
        isGoalEscalationWorkspace(workspaceKey);
  }

  yield matches();
  yield* runner.runningAgentIds.map((_) => matches()).distinct();
}

/// The latest decisive outcome of this goal's REPORT-PRODUCING wakes.
///
/// Filters the orchestrator's completion broadcast to this agent's decisive
/// runs ([WakeRunCompletion.isDecisive]: completed, failed, or the executor
/// timeout — a superseded/cancelled abort is bookkeeping for a replaced run
/// and neither surfaces nor clears anything), narrowed to the wakes that can
/// actually change the standing read: explicit report refreshes (the
/// Update-now button, the automation's armed refresh and its deferred
/// coalescing arm) and escalations. Chat runs and the €0 Phase A
/// subscription wakes share the same agent id but never touch the report: a
/// failed chat must not print "Last update failed" on the read card, and
/// the subscription wakes completing every few seconds must not silently
/// clear a refresh failure that is still true. A completed report wake that
/// says it did NOT advance the report (`reportUpdated == false` — e.g.
/// inference finished without publishing) is dropped for the same reason.
///
/// Kept alive for the app session ([Ref.keepAlive]): the broadcast stream
/// does not replay, so an autoDisposing subscription would forget a surfaced
/// failure the moment the watching page navigates away. Outcomes from before
/// an app restart are still not replayed — the durable record is the
/// `wake_run_log` row.
final StreamProviderFamily<WakeRunCompletion, String>
goalReportWakeOutcomeProvider = StreamProvider.autoDispose
    .family<WakeRunCompletion, String>(
      goalReportWakeOutcome,
      name: 'goalReportWakeOutcomeProvider',
    );
Stream<WakeRunCompletion> goalReportWakeOutcome(Ref ref, String agentId) {
  ref.keepAlive();
  final orchestrator = ref.watch(wakeOrchestratorProvider);
  return orchestrator.runCompletions.where(
    (completion) =>
        completion.agentId == agentId &&
        completion.isDecisive &&
        completion.reportUpdated != false &&
        (goalReportRefreshRequested(completion.triggerTokens) ||
            goalDeferredReportRefreshRequested(completion.triggerTokens) ||
            goalEscalationPeriodFromTriggerTokens(completion.triggerTokens) !=
                null),
  );
}
