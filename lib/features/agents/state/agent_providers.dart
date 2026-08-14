import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/day_agent_trigger_tokens.dart';
import 'package:lotti/classes/goal_trigger_tokens.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/service/agent_retention_service.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/service/agent_sidecar_reclaimer.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/feedback_extraction_service.dart';
import 'package:lotti/features/agents/service/improver_agent_service.dart';
import 'package:lotti/features/agents/service/project_activity_monitor.dart';
import 'package:lotti/features/agents/service/soul_document_service.dart';
import 'package:lotti/features/agents/state/agent_runtime_registry.dart';
import 'package:lotti/features/agents/state/agent_wiring.dart';
import 'package:lotti/features/agents/state/agent_workflow_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/sync/fork_healer.dart';
import 'package:lotti/features/agents/wake/scheduled_wake_manager.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/ai_runtime_settings_controller.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/features/ai/util/seed_tombstone_migration.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart'
    show journalDbProvider, loggingServiceProvider, outboxServiceProvider;
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

/// Optional UpdateNotifications service from GetIt.
final maybeUpdateNotificationsProvider = Provider<UpdateNotifications?>(
  maybeUpdateNotifications,
  name: 'maybeUpdateNotificationsProvider',
);
UpdateNotifications? maybeUpdateNotifications(Ref ref) {
  if (!getIt.isRegistered<UpdateNotifications>()) {
    return null;
  }
  return getIt<UpdateNotifications>();
}

/// Required UpdateNotifications service for agent runtime wiring.
final updateNotificationsProvider = Provider<UpdateNotifications>(
  updateNotifications,
  name: 'updateNotificationsProvider',
);
UpdateNotifications updateNotifications(Ref ref) {
  final notifications = ref.watch(maybeUpdateNotificationsProvider);
  if (notifications == null) {
    throw StateError('UpdateNotifications is not registered in GetIt');
  }
  return notifications;
}

/// Optional sync processor dependency for cross-device agent wiring.
final maybeSyncEventProcessorProvider = Provider<SyncEventProcessor?>(
  maybeSyncEventProcessor,
  name: 'maybeSyncEventProcessorProvider',
);
SyncEventProcessor? maybeSyncEventProcessor(Ref ref) {
  if (!getIt.isRegistered<SyncEventProcessor>()) {
    return null;
  }
  return getIt<SyncEventProcessor>();
}

/// Domain logger for agent runtime / workflow structured logging.
///
/// Uses `ref.listen` (not `ref.watch`) for config flag changes so that
/// toggling a logging domain mutates [DomainLogger.enabledDomains] in-place
/// without rebuilding the provider. This prevents a flag toggle from
/// cascading into orchestrator/workflow/service rebuilds and unintentionally
/// restarting the agent runtime.
final domainLoggerProvider = Provider<DomainLogger>(
  domainLogger,
  name: 'domainLoggerProvider',
);
DomainLogger domainLogger(Ref ref) {
  // Use the GetIt-registered instance so sync components (also GetIt-managed)
  // share the same DomainLogger and benefit from config flag toggles.
  // Falls back to a fresh instance in tests where GetIt is not configured.
  final logger = getIt.isRegistered<DomainLogger>()
      ? getIt<DomainLogger>()
      : DomainLogger(loggingService: ref.watch(loggingServiceProvider));

  // Mutate enabledDomains in-place on flag changes — no provider rebuild.
  void listenDomain(LogDomain domain) {
    ref.listen(configFlagProvider(domain.flagName), (_, next) {
      if (next.value ?? false) {
        logger.enabledDomains.add(domain);
      } else {
        logger.enabledDomains.remove(domain);
      }
    });

    // Seed the initial value synchronously from the current state.
    final initial = ref.read(configFlagProvider(domain.flagName));
    if (initial.value ?? false) {
      logger.enabledDomains.add(domain);
    }
  }

  LogDomain.values.forEach(listenDomain);
  return logger;
}

/// The agent database instance (singleton via GetIt).
final agentDatabaseProvider = Provider<AgentDatabase>(
  agentDatabase,
  name: 'agentDatabaseProvider',
);
AgentDatabase agentDatabase(Ref ref) {
  return getIt<AgentDatabase>();
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

/// The agent repository wrapping the database.
final agentRepositoryProvider = Provider<AgentRepository>(
  agentRepository,
  name: 'agentRepositoryProvider',
);
AgentRepository agentRepository(Ref ref) {
  return AgentRepository(
    ref.watch(agentDatabaseProvider),
    domainLogger: ref.watch(domainLoggerProvider),
  );
}

/// Sync-aware write wrapper for agent entities and links.
final agentSyncServiceProvider = Provider<AgentSyncService>(
  agentSyncService,
  name: 'agentSyncServiceProvider',
);
AgentSyncService agentSyncService(Ref ref) {
  return AgentSyncService(
    repository: ref.watch(agentRepositoryProvider),
    outboxService: ref.watch(outboxServiceProvider),
    vectorClockService: getIt<VectorClockService>(),
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
    onPersistedStateChanged: onPersistedStateChanged,
    syncEntityWriter: (entity) =>
        ref.read(agentSyncServiceProvider).upsertEntity(entity),
    syncAgentStateUpdater: (agentId, update) =>
        ref.read(agentSyncServiceProvider).updateAgentState(agentId, update),
    onWakeStart: onWakeStart,
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
    // The coordinator's morning digest is the one scheduled wake whose work
    // is shared rather than device-local: every device firing it means one
    // inference billed per device for a single result. Everything else stays
    // on the unleased path.
    // Lease-elected records: work that must run on exactly one device.
    requiresLease: (record) =>
        record.workspaceKey == coordinatorDigestWorkspaceKey ||
        isGoalEscalationWorkspace(record.workspaceKey),
    // `getHost()` reads a `late` field the service only assigns in `init()`,
    // so a cold start that reaches here first throws
    // LateInitializationError. The manager would catch that as a per-record
    // failure and leave a due digest neither claimed nor fired until the next
    // hourly tick.
    localHostId: () async {
      final vectorClock = getIt<VectorClockService>();
      await vectorClock.initialized;
      return vectorClock.getHost();
    },
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

/// Tracks local project/task changes and marks project reports stale while the
/// project subscription chooses the appropriate short or morning wake delay.
final projectActivityMonitorProvider = Provider<ProjectActivityMonitor>(
  projectActivityMonitor,
  name: 'projectActivityMonitorProvider',
);
ProjectActivityMonitor projectActivityMonitor(Ref ref) {
  final monitor = ProjectActivityMonitor(
    notifications: ref.watch(updateNotificationsProvider),
    agentRepository: ref.watch(agentRepositoryProvider),
    projectRepository: ref.watch(projectRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
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

/// Initializes the agent infrastructure when the `enableAgents` config flag
/// is enabled.
///
/// This provider:
/// 1. Watches the `enableAgents` config flag.
/// 2. When enabled, starts the [WakeOrchestrator] listening to
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

  final orchestrator = ref.watch(wakeOrchestratorProvider);
  final workflow = ref.watch(taskAgentWorkflowProvider);
  final taskAgentService = ref.watch(taskAgentServiceProvider);
  final templateService = ref.watch(agentTemplateServiceProvider);
  final updateNotifications = ref.watch(updateNotificationsProvider);
  final syncEventProcessor = ref.watch(maybeSyncEventProcessorProvider);
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
  );

  // 3. Start the orchestrator on the local update stream.
  await orchestrator.start(updateNotifications.localUpdateStream);

  // 3.5. Start the scheduled wake manager.
  //
  // Retirement of finished day agents is wired into the manager's own
  // pre-check (`beforeCheck`), so it runs ahead of the immediate check here
  // and ahead of every hourly tick thereafter.
  ref.watch(scheduledWakeManagerProvider).start();

  // 3.6. Track project-linked activity without triggering immediate wakes.
  projectActivityMonitor.start();

  // 4. Wire the sync event processor for cross-device agent data.
  wireSyncEventProcessor(
    ref,
    orchestrator,
    syncEventProcessor,
  );

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
    settingsDb: getIt<SettingsDb>(),
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
