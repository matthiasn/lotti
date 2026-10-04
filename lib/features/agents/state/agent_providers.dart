import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agent_wake_cadence.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/day_agent_trigger_tokens.dart';
import 'package:lotti/classes/goal_trigger_tokens.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/agents/service/agent_retention_service.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/service/agent_sidecar_reclaimer.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/feedback_extraction_service.dart';
import 'package:lotti/features/agents/service/improver_agent_service.dart';
import 'package:lotti/features/agents/service/project_activity_monitor.dart';
import 'package:lotti/features/agents/service/project_update_cadence.dart';
import 'package:lotti/features/agents/service/soul_document_service.dart';
import 'package:lotti/features/agents/state/agent_runtime_registry.dart';
import 'package:lotti/features/agents/state/agent_wiring.dart';
import 'package:lotti/features/agents/state/agent_workflow_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/sync/fork_healer.dart';
import 'package:lotti/features/agents/wake/agent_wake_coordinator.dart';
import 'package:lotti/features/agents/wake/project_update_slots.dart';
import 'package:lotti/features/agents/wake/scheduled_wake_manager.dart';
import 'package:lotti/features/agents/wake/sync_lease_gate.dart';
import 'package:lotti/features/agents/wake/wake_audit.dart';
import 'package:lotti/features/agents/wake/wake_intent_store.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/features/agents/workflow/task_wake_inputs.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/ai_runtime_settings_controller.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/features/ai/util/seed_tombstone_migration.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/repositories/project_repository.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/consts.dart';

export 'package:lotti/features/agents/state/agent_query_providers.dart';
export 'package:lotti/features/agents/state/agent_workflow_providers.dart';
export 'package:lotti/features/agents/state/template_query_providers.dart';

/// Builds the `onPersistedStateChanged` callback shared by the agent services
/// and managers.
///
/// When an agent mutates its persisted state, the returned callback fires a
/// UI-only [UpdateNotifications] ping (the given id plus the shared
/// [agentNotification] topic) so watching providers — e.g.
/// `agentUpdateStreamProvider`, the pending-wakes list — refresh without
/// kicking off another sync round-trip.
///
/// The id is whatever entity the watchers key on, not necessarily the agent:
/// `agentUpdateStreamProvider` is keyed by *whatever the consumer cares
/// about*, so `eventAgentProvider` waits on the event id and
/// `projectAgentProvider` on the project id. Callers that create or re-scope
/// an agent ping the domain id as well as the agent id — otherwise the
/// freshly created agent stays invisible, because nothing else in the agent
/// write path emits that token (`AgentSyncService` does not notify at all).
/// `DayAgentTriageService` already relies on this, pinging a task id.
///
/// Repeated calls coalesce: `notifyUiOnly` accumulates ids and emits one
/// batch per 100 ms window.
void Function(String) persistedStateChangedNotifier(
  UpdateNotifications notifications,
) {
  return (id) {
    notifications.notifyUiOnly({id, agentNotification});
  };
}

/// Reclaims the JSON sidecars of rows that have been hard-deleted or pruned.
///
/// A null documents directory (tests, headless) disables reclamation — a
/// missing file is never worth failing a delete or a sweep over.
final agentSidecarReclaimerProvider = Provider<AgentSidecarReclaimer>(
  agentSidecarReclaimer,
  name: 'agentSidecarReclaimerProvider',
);
AgentSidecarReclaimer agentSidecarReclaimer(Ref ref) => AgentSidecarReclaimer(
  documentsDirectory: getIt.isRegistered<Directory>()
      ? getIt<Directory>()
      : null,
  domainLogger: ref.watch(domainLoggerProvider),
);

/// Sync-aware write wrapper for agent entities and links.
final agentSyncServiceProvider = Provider<AgentSyncService>(
  agentSyncService,
  name: 'agentSyncServiceProvider',
);
AgentSyncService agentSyncService(Ref ref) {
  return AgentSyncService(
    repository: ref.watch(agentRepositoryProvider),
    outboxService: ref.watch(outboxServiceProvider),
    vectorClockService: ref.read(vectorClockServiceProvider),
  );
}

/// The in-memory wake queue.
final wakeQueueProvider = Provider<WakeQueue>(
  wakeQueue,
  name: 'wakeQueueProvider',
);
WakeQueue wakeQueue(Ref ref) {
  return WakeQueue();
}

/// The single-flight wake runner.
final wakeRunnerProvider = Provider<WakeRunner>(
  wakeRunner,
  name: 'wakeRunnerProvider',
);
WakeRunner wakeRunner(Ref ref) {
  final runner = WakeRunner();
  ref.onDispose(runner.dispose);
  return runner;
}

/// Builds the wake-start fork-healing hook (ADR 0018 rule 8): a [WakeStartHook]
/// that, at the start of each wake, heals the agent's fork via a [ForkHealer]
/// over [syncService] ([now] supplies the join timestamp). The healer is a
/// stateless wrapper built fresh per enabled invocation — [syncService] is
/// re-read each time so the hook never holds a stale instance across provider
/// rebuilds, and wiring the hook costs nothing while the flag stays off.
/// Extracted from [wakeOrchestrator] so the wiring is unit-testable.
///
/// [isEnabled] is consulted **per invocation** (the `enable_fork_healing`
/// config flag in production): the orchestrator captures this hook at
/// initialization, so a provider-rebuild-based flag would never reach the
/// executing instance. A throwing [isEnabled] propagates into the
/// orchestrator's existing hook guard (logged, wake proceeds — healing is an
/// optimization, never required).
WakeStartHook forkHealingHook(
  AgentSyncService Function() syncService,
  DateTime Function() now, {
  required Future<bool> Function() isEnabled,
}) {
  return (agentId, runKey, threadId) async {
    if (!await isEnabled()) return;
    final forkHealer = ForkHealer(syncService: syncService());
    await forkHealer.maybeHealFork(
      agentId: agentId,
      at: now(),
    );
  };
}

/// The wake orchestrator (notification listener + subscription matching).
final wakeOrchestratorProvider = Provider<WakeOrchestrator>(
  wakeOrchestrator,
  name: 'wakeOrchestratorProvider',
);
WakeOrchestrator wakeOrchestrator(Ref ref) {
  final notifications = ref.watch(maybeUpdateNotificationsProvider);
  void Function(String agentId)? onPersistedStateChanged;
  if (notifications != null) {
    onPersistedStateChanged = (agentId) {
      notifications.notifyUiOnly({agentId, agentNotification});
    };
  }
  // Fork healing (ADR 0018 rule 8), gated by the default-off
  // `enable_fork_healing` config flag — read inside the hook at each wake, so
  // a Settings toggle applies on the next wake without a restart.
  final onWakeStart = forkHealingHook(
    () => ref.read(agentSyncServiceProvider),
    clock.now,
    isEnabled: () =>
        ref.read(journalDbProvider).getConfigFlag(enableForkHealingFlag),
  );
  return WakeOrchestrator(
    repository: ref.watch(agentRepositoryProvider),
    queue: ref.watch(wakeQueueProvider),
    runner: ref.watch(wakeRunnerProvider),
    domainLogger: ref.watch(domainLoggerProvider),
    maxConcurrentWakes: () =>
        ref.read(aiRuntimeSettingsControllerProvider).agentWakeConcurrency,
    // Read on every match: a category or app-default change applies to the
    // next change without re-registering any agent.
    taskWakeCadenceResolver: ({required override, required categoryId}) =>
        resolveAgentWakeCadence(
          task: override,
          category: ref
              .read(entitiesCacheServiceProvider)
              ?.getCategoryById(categoryId)
              ?.agentWakeCadence,
          global: ref
              .read(aiRuntimeSettingsControllerProvider)
              .defaultWakeCadence,
        ),
    onPersistedStateChanged: onPersistedStateChanged,
    syncEntityWriter: (entity) =>
        ref.read(agentSyncServiceProvider).upsertEntity(entity),
    syncAgentStateUpdater: (agentId, update) =>
        ref.read(agentSyncServiceProvider).updateAgentState(agentId, update),
    onWakeStart: onWakeStart,
    localHostId: _localHostId,
    // Device-local, like the throttle deadline; guest worlds without a
    // settings database simply do not persist wake intents.
    intentStore: getIt.isRegistered<SettingsDb>()
        ? WakeIntentStore(
            settingsDb: ref.read(settingsDbProvider),
            domainLogger: ref.watch(domainLoggerProvider),
          )
        : null,
    taskContentChecker: (taskId) async {
      final journalDb = ref.read(journalDbProvider);

      // Check the task's own content (title and body text).
      final task = await journalDb.journalEntityById(taskId);
      if (task is Task) {
        if (task.data.title.trim().isNotEmpty) return true;
        if (task.entryText?.plainText.trim().isNotEmpty ?? false) return true;
      }

      // Check linked entries for content.
      final linked = await journalDb.getLinkedEntities(taskId);
      return linked.any(
        (e) => e.entryText?.plainText.trim().isNotEmpty ?? false,
      );
    },
    // An event "has content" once it carries a note or a linked photo/note —
    // a bare title must not trigger inference on a static memory.
    eventContentChecker: (eventId) async {
      final journalDb = ref.read(journalDbProvider);
      final event = await journalDb.journalEntityById(eventId);
      if (event is JournalEvent &&
          (event.entryText?.plainText.trim().isNotEmpty ?? false)) {
        return true;
      }
      final linked = await journalDb.getLinkedEntities(eventId);
      return linked.any(
        (e) =>
            e is JournalImage ||
            (e.entryText?.plainText.trim().isNotEmpty ?? false),
      );
    },
  );
}

/// This device's `VectorClockService` host id. `getHost()` reads a `late`
/// field the service only assigns in `init()`, so a cold start must await
/// initialisation first or throw LateInitializationError.
Future<String?> _localHostId() async {
  final vectorClock = getIt<VectorClockService>();
  await vectorClock.initialized;
  return vectorClock.getHost();
}

/// This device's watermark for [AgentWakeCoordinator]: the sync sequence
/// log's gap-free prefix per peer host, and for this host the last counter it
/// handed out — every local write is held locally.
Future<Map<String, int>> _wakeWatermark(Ref ref, Set<String> hosts) async {
  final watermark = await ref
      .read(syncDatabaseProvider)
      .contiguousWatermarks(hosts);
  final vectorClock = ref.read(vectorClockServiceProvider);
  final host = await _localHostId();
  if (host != null) watermark[host] = await vectorClock.lastReservedCounter();
  return watermark;
}

/// Cross-device coordination of task-agent wakes: of several devices about to
/// wake a task agent, one runs and the others stand down when its run reads
/// everything theirs would (`specs/tla/AgentWakeCoordination.tla`). Other
/// agent kinds have no inputs reader and run uncoordinated.
final agentWakeCoordinatorProvider = Provider<AgentWakeCoordinator>(
  agentWakeCoordinator,
  name: 'agentWakeCoordinatorProvider',
);
AgentWakeCoordinator agentWakeCoordinator(Ref ref) {
  final repository = ref.watch(agentRepositoryProvider);
  final coordinator = AgentWakeCoordinator(
    readInputs: (agentId) async {
      final identity = await repository.getEntity(agentId);
      if (identity is! AgentIdentityEntity ||
          identity.kind != AgentKinds.taskAgent) {
        return null;
      }
      final state = await repository.getAgentState(agentId);
      final taskId = state?.slots.activeTaskId;
      if (taskId == null) return null;
      return taskWakeInputs(
        journalDb: ref.read(journalDbProvider),
        agentRepository: repository,
        agentId: agentId,
        taskId: taskId,
      );
    },
    readWatermark: (hosts) => _wakeWatermark(ref, hosts),
    send: ref.watch(outboxServiceProvider).enqueueMessage,
    localHostId: _localHostId,
    domainLogger: ref.watch(domainLoggerProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
}

/// When a project agent updates on its own: one synced slot at a time, fired
/// on one device (`ProjectUpdateCadence`).
final projectUpdateCadenceProvider = Provider<ProjectUpdateCadence>(
  (ref) => ProjectUpdateCadence(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  ),
  name: 'projectUpdateCadenceProvider',
);

/// Arms a project agent's next update slot and makes the scheduled-wake
/// manager look at it, so a slot due within the hour gets its own wake-up
/// rather than waiting for the hourly scan.
Future<void> Function(String agentId) armProjectUpdate(Ref ref) =>
    (agentId) async {
      final armed = await ref.read(projectUpdateCadenceProvider).arm(agentId);
      if (armed != null) _announceProjectSlot(ref, agentId);
    };

/// Re-arms a project agent whose slot's wake the drain refused
/// (`ProjectUpdateCadence.rearmAfterRefusal`).
Future<void> Function(String agentId, WakeDecisionCause cause)
rearmRefusedProjectSlot(Ref ref) => (agentId, cause) async {
  final armed = await ref
      .read(projectUpdateCadenceProvider)
      .rearmAfterRefusal(agentId, cause);
  if (armed != null) _announceProjectSlot(ref, agentId);
};

/// Re-plans a project agent's pending update slot after its interval
/// changed (`ProjectUpdateCadence.replan`), for the interval control.
final replanProjectUpdateProvider =
    Provider<Future<void> Function(String agentId)>(
      (ref) => (agentId) async {
        await ref.read(projectUpdateCadenceProvider).replan(agentId);
        _announceProjectSlot(ref, agentId);
      },
      name: 'replanProjectUpdateProvider',
    );

void _announceProjectSlot(Ref ref, String agentId) {
  ref.read(scheduledWakeManagerProvider).requestCheck();
  // The countdown reads the slot; an agent-store write announces nothing.
  persistedStateChangedNotifier(ref.read(updateNotificationsProvider))(agentId);
}

/// Whether a connectivity report can reach the sync server: any link other
/// than none or Bluetooth.
bool reachesSyncServer(List<ConnectivityResult> results) => results.any(
  (result) =>
      result != ConnectivityResult.none &&
      result != ConnectivityResult.bluetooth,
);

/// Whether this device may claim or fire a leased project update slot now:
/// connected, with its sync inbox drained. Null where sync is not wired (a
/// guest world, a test), where there are no peers to race; the composition
/// root wires the sync feature's gate (`buildSyncLeaseGate`).
final syncLeaseGateProvider = Provider<SyncLeaseGate?>(
  (ref) => null,
  name: 'syncLeaseGateProvider',
);

/// The scheduled wake manager for time-based agent wakes.
final scheduledWakeManagerProvider = Provider<ScheduledWakeManager>(
  scheduledWakeManager,
  name: 'scheduledWakeManagerProvider',
);
ScheduledWakeManager scheduledWakeManager(Ref ref) {
  final notifications = ref.watch(updateNotificationsProvider);
  final domainLogger = ref.watch(domainLoggerProvider);
  final manager = ScheduledWakeManager(
    repository: ref.watch(agentRepositoryProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    domainLogger: domainLogger,
    onPersistedStateChanged: persistedStateChangedNotifier(notifications),
    // Lease-elected records: work that is shared rather than device-local,
    // where every device firing it means one inference billed per device for
    // a single result — the coordinator's morning digest, goal and
    // relationship escalations, and the recovery of an unanswered goal chat
    // message, which would otherwise be answered once per device (ADR 0069).
    // Everything else stays on the unleased path.
    requiresLease: (record) =>
        record.workspaceKey == coordinatorDigestWorkspaceKey ||
        isGoalEscalationWorkspace(record.workspaceKey) ||
        isGoalChatRecoveryWorkspace(record.workspaceKey) ||
        isRelationshipEscalationWorkspace(record.workspaceKey) ||
        isProjectUpdateWorkspace(record.workspaceKey),
    // A project's update slots follow the rules ProjectWakeGovernor.tla
    // checks: claimed and fired only while connected with the inbox drained,
    // re-claimed after a connection drop, and one run per agent however many
    // slots devices armed for one change.
    syncGate: ref.watch(syncLeaseGateProvider),
    requiresSyncGate: (record) => isProjectUpdateWorkspace(record.workspaceKey),
    exclusiveGroupOf: (record) =>
        isProjectUpdateWorkspace(record.workspaceKey) ? record.agentId : null,
    // A host id read before the vector clock service initialised would
    // throw; the manager would catch that as a per-record failure and leave a
    // due digest neither claimed nor fired until the next hourly tick.
    localHostId: _localHostId,
    // Repairs that must land before a pass reads what is due, rather than
    // after it. Retirement decides which agents may still wake — a day agent
    // whose day is over is `active` until it runs, so its overdue wake would
    // fire once per cold start and once per hourly tick thereafter. The digest
    // bootstrap can arm a record for an already-past slot when a run was
    // interrupted, which only fires promptly if it exists before the scan.
    // Read lazily: the contributors are not needed to build the manager, only
    // to run a pass. Each contributor contains its own optional failures; what
    // escapes is logged here rather than aborting the scan, because a repair
    // that cannot run must not also stop the wakes that are already due.
    beforeCheck: () async {
      for (final maintenance in ref.read(agentRuntimeMaintenanceProvider)) {
        try {
          await maintenance.beforeWakeScan();
        } catch (e, s) {
          domainLogger.error(
            LogDomain.agentRuntime,
            e,
            message:
                'failed pre-scan maintenance for '
                '${maintenance.runtimeType} before wake scan',
            stackTrace: s,
          );
        }
      }
    },
  );
  ref.onDispose(manager.stop);
  return manager;
}

/// Tracks local project/task changes, marks project reports stale and arms
/// their next update slot.
final projectActivityMonitorProvider = Provider<ProjectActivityMonitor>(
  projectActivityMonitor,
  name: 'projectActivityMonitorProvider',
);
ProjectActivityMonitor projectActivityMonitor(Ref ref) {
  final agentService = ref.watch(agentServiceProvider);
  final projectAgentService = ref.watch(projectAgentServiceProvider);
  final monitor = ProjectActivityMonitor(
    notifications: ref.watch(updateNotificationsProvider),
    agentRepository: ref.watch(agentRepositoryProvider),
    projectRepository: ref.watch(projectRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    mutationCoordinator: ref.watch(projectAgentMutationCoordinatorProvider),
    retireProjectAgent: (agentId) async {
      agentService
        ..abortRunningWake(agentId)
        ..cancelPendingWake(agentId);
      await agentService.destroyAgent(agentId);
    },
    updateProjectAgentScopes: (projectId, allowedCategoryIds) =>
        projectAgentService.updateProjectAgentScopes(
          projectId: projectId,
          allowedCategoryIds: allowedCategoryIds,
        ),
    armProjectUpdate: armProjectUpdate(ref),
    domainLogger: ref.watch(domainLoggerProvider),
  );
  ref.onDispose(() {
    unawaited(monitor.stop());
  });
  return monitor;
}

/// The high-level agent service.
final agentServiceProvider = Provider<AgentService>(
  agentService,
  name: 'agentServiceProvider',
);
AgentService agentService(Ref ref) {
  final notifications = ref.watch(updateNotificationsProvider);
  return AgentService(
    sidecarReclaimer: ref.watch(agentSidecarReclaimerProvider),
    repository: ref.watch(agentRepositoryProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    onPersistedStateChanged: persistedStateChangedNotifier(notifications),
  );
}

/// The agent template service.
final agentTemplateServiceProvider = Provider<AgentTemplateService>(
  agentTemplateService,
  name: 'agentTemplateServiceProvider',
);
AgentTemplateService agentTemplateService(Ref ref) {
  return AgentTemplateService(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
  );
}

/// The soul document service.
final soulDocumentServiceProvider = Provider<SoulDocumentService>(
  soulDocumentService,
  name: 'soulDocumentServiceProvider',
);
SoulDocumentService soulDocumentService(Ref ref) {
  return SoulDocumentService(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
  );
}

/// The feedback extraction service.
final feedbackExtractionServiceProvider = Provider<FeedbackExtractionService>(
  feedbackExtractionService,
  name: 'feedbackExtractionServiceProvider',
);
FeedbackExtractionService feedbackExtractionService(Ref ref) {
  return FeedbackExtractionService(
    agentRepository: ref.watch(agentRepositoryProvider),
    templateService: ref.watch(agentTemplateServiceProvider),
    soulDocumentService: ref.watch(soulDocumentServiceProvider),
  );
}

/// The improver agent service.
final improverAgentServiceProvider = Provider<ImproverAgentService>(
  improverAgentService,
  name: 'improverAgentServiceProvider',
);
ImproverAgentService improverAgentService(Ref ref) {
  final notifications = ref.watch(updateNotificationsProvider);
  return ImproverAgentService(
    agentService: ref.watch(agentServiceProvider),
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    onPersistedStateChanged: persistedStateChangedNotifier(notifications),
  );
}

/// Initializes the agent infrastructure. Not gated by a flag: it runs on
/// every device, from app start (`beamer_app.dart` listens to it).
///
/// This provider:
/// 1. Hands the agent repository to sync before it
///    builds any runtime provider, so a runtime that fails to build or start
///    never leaves sync unable to store another device's agents.
/// 2. Starts the [WakeOrchestrator] listening to
///    `UpdateNotifications.updateStream`.
/// 3. Restores task agent subscriptions from persisted state.
///
/// Must be watched (e.g. from a top-level widget or app initialization) to
/// take effect.
final agentInitializationProvider = FutureProvider<void>(
  agentInitialization,
  name: 'agentInitializationProvider',
);
Future<void> agentInitialization(Ref ref) async {
  developer.log(
    'Agents enabled, starting wake orchestrator',
    name: 'agentInitialization',
  );

  // Sync first, before any runtime provider is built: building one can
  // throw, and until the repository is wired every agent entity and link
  // arriving from another device fails to apply.
  final syncAttachment = ref.watch(agentSyncAttachmentProvider);
  syncAttachment?.attachRepository(ref);

  final orchestrator = ref.watch(wakeOrchestratorProvider);
  final workflow = ref.watch(taskAgentWorkflowProvider);
  final taskAgentService = ref.watch(taskAgentServiceProvider);
  final templateService = ref.watch(agentTemplateServiceProvider);
  final updateNotifications = ref.watch(updateNotificationsProvider);
  final projectActivityMonitor = ref.watch(projectActivityMonitorProvider);

  // Register the dispose callback before any async work so it is always
  // installed, even if an await below throws.
  ref.onDispose(() {
    developer.log(
      'Stopping wake orchestrator',
      name: 'agentInitialization',
    );
    orchestrator.stop();
  });

  // 0. Wire the wake runtime into the sync event processor, before anything
  //    below can await or throw, so synced lifecycle changes reach it.
  syncAttachment?.attachRuntime(
    ref,
    orchestrator,
    retireSupersededTaskAgents: (taskId) =>
        taskAgentService.retirement.retireSuperseded(taskId),
  );

  // 1. Mark any orphaned 'running' wake runs as 'abandoned' so the activity
  //    log is not confused by stale entries from a previous app lifecycle.
  final repository = ref.read(agentRepositoryProvider);
  final abandonedCount = await repository.abandonOrphanedWakeRuns();
  if (abandonedCount > 0) {
    developer.log(
      'Marked $abandonedCount orphaned wake run(s) as abandoned on startup',
      name: 'agentInitialization',
    );
  }

  // 2. Wire the workflow executor into the orchestrator.
  wireWakeExecutor(
    ref,
    orchestrator,
    workflow,
    updateNotifications,
    retireIfSuperseded: (agentId) =>
        taskAgentService.retirement.retireIfSuperseded(agentId),
  );

  // 2.25. A project slot whose wake the drain refused was already consumed;
  //       re-arm so a stale report is not left with no slot pending.
  wireProjectSlotRefusals(ref, orchestrator);

  // 2.5. Coordinate wakes with peer devices: a peer's claim or completion
  //      re-drains the jobs it held back.
  final coordinator = ref.watch(agentWakeCoordinatorProvider);
  orchestrator.coordinator = coordinator;
  coordinator.onPeerStateChanged = orchestrator.onPeerWakeStateChanged;

  // 3. Start the orchestrator on the local update stream.
  await orchestrator.start(updateNotifications.localUpdateStream);

  // 3.5. Start the scheduled wake manager.
  //
  // Retirement of finished day agents is wired into the manager's own
  // pre-check (`beforeCheck`), so it runs ahead of the immediate check here
  // and ahead of every hourly tick thereafter.
  ref.watch(scheduledWakeManagerProvider).start();

  // Keep feature maintenance reactive for the runtime's lifetime. A lazy
  // read in beforeCheck alone pauses its provider listeners between scans,
  // so a repaired inference configuration would not request an early retry.
  ref.watch(agentRuntimeMaintenanceProvider);

  // 3.6. Track project-linked activity without triggering immediate wakes.
  projectActivityMonitor.start();

  // 5. Seed default templates and profiles in parallel, then
  //    upgrade existing profiles with skill assignments and restore
  //    subscriptions (which depends on templates being seeded).
  //    Skills are not seeded — they live as code in the built-in skill
  //    registry (lib/features/ai/skills/built_in_skills.dart).
  final aiConfigRepo = ref.watch(aiConfigRepositoryProvider);
  final profileSeeder = ProfileSeedingService(
    aiConfigRepository: aiConfigRepo,
  );
  // Convert the 0.9.1067/0.9.1068 tombstone ledger first. This entry point
  // starts from `beamer_app` independently of `aiConfigInitializationProvider`,
  // so without it whichever runs first can re-seed — and sync — a bundled
  // profile whose deletion is still only recorded in the ledger. The migration
  // is idempotent: it clears the key, so the second caller is a no-op.
  await SeedTombstoneMigration(
    aiConfigRepository: ref.read(aiConfigRepositoryProvider),
    settingsDb: ref.read(settingsDbProvider),
  ).migrate();

  await Future.wait([
    templateService.seedDefaults(),
    profileSeeder.seedDefaults(),
  ]);
  // Seed soul documents and assign to templates (depends on templates above).
  await ref.read(soulDocumentServiceProvider).seedDefaults();
  // Backfill skill assignments on existing default profiles.
  await profileSeeder.upgradeExisting();
  // Each service bulk-loads its database inputs before entering its own agent
  // loop. A preload failure therefore produces one startup diagnostic instead
  // of one full error per persisted agent, then remains a provider failure so
  // Riverpod refresh/retry can rerun the idempotent restoration pass.
  try {
    // Contributors sit where day restoration used to, between task and project.
    // `Future.wait` builds its futures in list order and all three passes call
    // `restorePendingWake` on the one shared orchestrator, so the position is
    // observable — and this refactor has no reason to move it.
    await Future.wait<void>([
      taskAgentService.restoreSubscriptions(),
      for (final maintenance in ref.read(agentRuntimeMaintenanceProvider))
        maintenance.restoreSubscriptions(),
      ref.read(projectAgentServiceProvider).restoreSubscriptions(),
    ]);
    // Wakes a previous process owed but never finished — lost jobs and
    // interrupted runs. After the passes above, so their restored jobs only
    // merge.
    await orchestrator.restoreWakeIntents();
  } catch (error, stackTrace) {
    ref
        .read(domainLoggerProvider)
        .error(
          LogDomain.agentRuntime,
          error,
          message: 'agent runtime restoration aborted',
          stackTrace: stackTrace,
        );
    rethrow;
  }

  // Confirmed changes whose dispatch a previous process died in: each is
  // dispatched again and completes what the earlier run left
  // (`specs/tla/ChangeDispatchRecovery.tla`). A failure leaves the recorded
  // dispatches for the next start, and never holds the agents back.
  for (final resume in <Future<void> Function()>[
    () => ref.read(changeSetConfirmationServiceProvider).resumeInterrupted(),
    () => ref
        .read(projectChangeSetConfirmationServiceProvider)
        .resumeInterrupted(),
    () =>
        ref.read(eventChangeSetConfirmationServiceProvider).resumeInterrupted(),
  ]) {
    try {
      await resume();
    } catch (error, stackTrace) {
      ref
          .read(domainLoggerProvider)
          .error(
            LogDomain.agentRuntime,
            error,
            message: 'interrupted change dispatches not resumed',
            stackTrace: stackTrace,
          );
    }
  }

  // 6. Forget the derived rows past the retention policy. Last, and
  //    deliberately NOT awaited: housekeeping must never sit between the user
  //    and a ready app. The sweep is bounded, idempotent, and safe to
  //    interrupt, so a process kill mid-pass just leaves rows for next start.
  unawaited(
    AgentRetentionService(
      repository: ref.read(agentRepositoryProvider),
      domainLogger: ref.read(domainLoggerProvider),
      sidecarReclaimer: ref.read(agentSidecarReclaimerProvider),
    ).sweep(),
  );
}
