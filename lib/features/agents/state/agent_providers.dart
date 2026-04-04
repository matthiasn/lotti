import 'dart:async';
import 'dart:developer' as developer;

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/feedback_extraction_service.dart';
import 'package:lotti/features/agents/service/improver_agent_service.dart';
import 'package:lotti/features/agents/service/project_activity_monitor.dart';
import 'package:lotti/features/agents/state/agent_workflow_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/scheduled_wake_manager.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/features/ai/util/skill_seeding_service.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart'
    show journalDbProvider, loggingServiceProvider, outboxServiceProvider;
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:lotti/features/agents/state/agent_query_providers.dart';
export 'package:lotti/features/agents/state/agent_workflow_providers.dart';
export 'package:lotti/features/agents/state/template_query_providers.dart';

part 'agent_providers.g.dart';

void Function(String) persistedStateChangedNotifier(
  UpdateNotifications notifications,
) {
  return (agentId) {
    notifications.notifyUiOnly({agentId, agentNotification});
  };
}

/// Optional UpdateNotifications service from GetIt.
@Riverpod(keepAlive: true)
UpdateNotifications? maybeUpdateNotifications(Ref ref) {
  if (!getIt.isRegistered<UpdateNotifications>()) {
    return null;
  }
  return getIt<UpdateNotifications>();
}

/// Required UpdateNotifications service for agent runtime wiring.
@Riverpod(keepAlive: true)
UpdateNotifications updateNotifications(Ref ref) {
  final notifications = ref.watch(maybeUpdateNotificationsProvider);
  if (notifications == null) {
    throw StateError('UpdateNotifications is not registered in GetIt');
  }
  return notifications;
}

/// Optional sync processor dependency for cross-device agent wiring.
@Riverpod(keepAlive: true)
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
@Riverpod(keepAlive: true)
DomainLogger domainLogger(Ref ref) {
  // Use the GetIt-registered instance so sync components (also GetIt-managed)
  // share the same DomainLogger and benefit from config flag toggles.
  // Falls back to a fresh instance in tests where GetIt is not configured.
  final logger = getIt.isRegistered<DomainLogger>()
      ? getIt<DomainLogger>()
      : DomainLogger(loggingService: ref.watch(loggingServiceProvider));

  // Mutate enabledDomains in-place on flag changes — no provider rebuild.
  void listenFlag(String flagName, String domain) {
    ref.listen(configFlagProvider(flagName), (_, next) {
      if (next.value ?? false) {
        logger.enabledDomains.add(domain);
      } else {
        logger.enabledDomains.remove(domain);
      }
    });

    // Seed the initial value synchronously from the current state.
    final initial = ref.read(configFlagProvider(flagName));
    if (initial.value ?? false) {
      logger.enabledDomains.add(domain);
    }
  }

  listenFlag(logAgentRuntimeFlag, LogDomains.agentRuntime);
  listenFlag(logAgentWorkflowFlag, LogDomains.agentWorkflow);
  listenFlag(logSyncFlag, LogDomains.sync);
  return logger;
}

/// The agent database instance (singleton via GetIt).
@Riverpod(keepAlive: true)
AgentDatabase agentDatabase(Ref ref) {
  return getIt<AgentDatabase>();
}

/// The agent repository wrapping the database.
@Riverpod(keepAlive: true)
AgentRepository agentRepository(Ref ref) {
  return AgentRepository(ref.watch(agentDatabaseProvider));
}

/// Sync-aware write wrapper for agent entities and links.
@Riverpod(keepAlive: true)
AgentSyncService agentSyncService(Ref ref) {
  return AgentSyncService(
    repository: ref.watch(agentRepositoryProvider),
    outboxService: ref.watch(outboxServiceProvider),
    vectorClockService: getIt<VectorClockService>(),
  );
}

/// The in-memory wake queue.
@Riverpod(keepAlive: true)
WakeQueue wakeQueue(Ref ref) {
  return WakeQueue();
}

/// The single-flight wake runner.
@Riverpod(keepAlive: true)
WakeRunner wakeRunner(Ref ref) {
  final runner = WakeRunner();
  ref.onDispose(runner.dispose);
  return runner;
}

/// The wake orchestrator (notification listener + subscription matching).
@Riverpod(keepAlive: true)
WakeOrchestrator wakeOrchestrator(Ref ref) {
  final notifications = ref.watch(maybeUpdateNotificationsProvider);
  void Function(String agentId)? onPersistedStateChanged;
  if (notifications != null) {
    onPersistedStateChanged = (agentId) {
      notifications.notifyUiOnly({agentId, agentNotification});
    };
  }
  return WakeOrchestrator(
    repository: ref.watch(agentRepositoryProvider),
    queue: ref.watch(wakeQueueProvider),
    runner: ref.watch(wakeRunnerProvider),
    domainLogger: ref.watch(domainLoggerProvider),
    onPersistedStateChanged: onPersistedStateChanged,
    syncEntityWriter: (entity) =>
        ref.read(agentSyncServiceProvider).upsertEntity(entity),
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
  );
}

/// The scheduled wake manager for time-based agent wakes.
@Riverpod(keepAlive: true)
ScheduledWakeManager scheduledWakeManager(Ref ref) {
  final notifications = ref.watch(updateNotificationsProvider);
  final manager = ScheduledWakeManager(
    repository: ref.watch(agentRepositoryProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    domainLogger: ref.watch(domainLoggerProvider),
    onPersistedStateChanged: persistedStateChangedNotifier(notifications),
  );
  ref.onDispose(manager.stop);
  return manager;
}

/// Tracks local project/task changes and marks project reports stale without
/// waking the project agent immediately.
@Riverpod(keepAlive: true)
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
@Riverpod(keepAlive: true)
AgentService agentService(Ref ref) {
  final notifications = ref.watch(updateNotificationsProvider);
  return AgentService(
    repository: ref.watch(agentRepositoryProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    onPersistedStateChanged: persistedStateChangedNotifier(notifications),
  );
}

/// The agent template service.
@Riverpod(keepAlive: true)
AgentTemplateService agentTemplateService(Ref ref) {
  return AgentTemplateService(
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
  );
}

/// The feedback extraction service.
@Riverpod(keepAlive: true)
FeedbackExtractionService feedbackExtractionService(Ref ref) {
  return FeedbackExtractionService(
    agentRepository: ref.watch(agentRepositoryProvider),
    templateService: ref.watch(agentTemplateServiceProvider),
  );
}

/// The improver agent service.
@Riverpod(keepAlive: true)
ImproverAgentService improverAgentService(Ref ref) {
  final notifications = ref.watch(updateNotificationsProvider);
  return ImproverAgentService(
    agentService: ref.watch(agentServiceProvider),
    agentTemplateService: ref.watch(agentTemplateServiceProvider),
    repository: ref.watch(agentRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
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
@Riverpod(keepAlive: true)
Future<void> agentInitialization(Ref ref) async {
  final enableAgents = ref.watch(configFlagProvider(enableAgentsFlag));
  final isEnabled = enableAgents.value ?? false;

  // When keepAlive is true, Riverpod re-executes the provider body whenever a
  // watched dependency (here: the config flag) changes. The re-execution
  // disposes the prior state (triggering ref.onDispose → orchestrator.stop()),
  // so toggling the flag off correctly tears down the running infrastructure.
  if (!isEnabled) {
    developer.log(
      'Agents disabled, skipping initialization',
      name: 'agentInitialization',
    );
    return;
  }

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
  _wireWakeExecutor(
    ref,
    orchestrator,
    workflow,
    updateNotifications,
  );

  // 3. Start the orchestrator on the local update stream.
  await orchestrator.start(updateNotifications.localUpdateStream);

  // 3.5. Start the scheduled wake manager.
  ref.watch(scheduledWakeManagerProvider).start();

  // 3.6. Track project-linked activity without triggering immediate wakes.
  projectActivityMonitor.start();

  // 4. Wire the sync event processor for cross-device agent data.
  _wireSyncEventProcessor(
    ref,
    orchestrator,
    syncEventProcessor,
  );

  // 5. Seed default templates, profiles, and skills in parallel, then
  //    upgrade existing profiles with skill assignments and restore
  //    subscriptions (which depends on templates being seeded).
  final aiConfigRepo = ref.watch(aiConfigRepositoryProvider);
  final profileSeeder = ProfileSeedingService(
    aiConfigRepository: aiConfigRepo,
  );
  await Future.wait([
    templateService.seedDefaults(),
    profileSeeder.seedDefaults(),
    SkillSeedingService(aiConfigRepository: aiConfigRepo).seedDefaults(),
  ]);
  // Backfill skill assignments on existing default profiles.
  await profileSeeder.upgradeExisting();
  await Future.wait([
    taskAgentService.restoreSubscriptions(),
    ref.read(projectAgentServiceProvider).restoreSubscriptions(),
  ]);
}

/// Wires the wake executor into the orchestrator, routing to the appropriate
/// workflow based on the agent's `kind` field.
void _wireWakeExecutor(
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
        'Failed to resolve task/project wake notification tokens: $error',
        name: 'agentInitialization',
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
      'Failed to resolve template for wake notification: $error',
      name: 'agentInitialization',
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
void _wireSyncEventProcessor(
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
  processor.backfillResponseHandler?.agentRepository = repository;
  ref.onDispose(() {
    processor
      ..agentRepository = null
      ..wakeOrchestrator = null;
    processor.backfillResponseHandler?.agentRepository = null;
  });
}
