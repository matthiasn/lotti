import 'dart:developer' as developer;

import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_token_usage.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/agents/workflow/template_evolution_workflow.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/util/profile_seeding_service.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart'
    show journalDbProvider, loggingServiceProvider, outboxServiceProvider;
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'agent_providers.g.dart';

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
  final loggingService = ref.watch(loggingServiceProvider);
  final logger = DomainLogger(loggingService: loggingService);

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

/// The agent database instance (lazy singleton).
@Riverpod(keepAlive: true)
AgentDatabase agentDatabase(Ref ref) {
  final db = AgentDatabase();
  ref.onDispose(db.close);
  return db;
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

/// Whether a specific agent is currently running.
///
/// Yields the initial synchronous value, then updates reactively whenever the
/// agent starts or stops running.
@riverpod
Stream<bool> agentIsRunning(Ref ref, String agentId) async* {
  final runner = ref.watch(wakeRunnerProvider);
  yield runner.isRunning(agentId);
  yield* runner.runningAgentIds.map((ids) => ids.contains(agentId)).distinct();
}

/// Stream that emits when a specific agent's data changes (from sync or local
/// wake). Detail providers watch this to self-invalidate.
///
/// Returns the raw `Set<String>` from `UpdateNotifications` rather than `void`
/// because Riverpod deduplicates `AsyncData` values using `==`. Since
/// `null == null`, a `Stream<void>` would only notify watchers on the first
/// emission. Each `Set` instance is identity-distinct, ensuring every
/// notification triggers a provider rebuild.
@riverpod
Stream<Set<String>> agentUpdateStream(Ref ref, String agentId) {
  final notifications = ref.watch(updateNotificationsProvider);
  return notifications.updateStream.where((ids) => ids.contains(agentId));
}

/// The wake orchestrator (notification listener + subscription matching).
@Riverpod(keepAlive: true)
WakeOrchestrator wakeOrchestrator(Ref ref) {
  final notifications = ref.watch(maybeUpdateNotificationsProvider);
  void Function(String agentId)? onPersistedStateChanged;
  if (notifications != null) {
    onPersistedStateChanged = (agentId) {
      // Use update-only notifications so these state writes don't feed back
      // into the orchestrator's local wake-trigger stream.
      notifications.notify({agentId, agentNotification}, fromSync: true);
    };
  }
  return WakeOrchestrator(
    repository: ref.watch(agentRepositoryProvider),
    queue: ref.watch(wakeQueueProvider),
    runner: ref.watch(wakeRunnerProvider),
    domainLogger: ref.watch(domainLoggerProvider),
    onPersistedStateChanged: onPersistedStateChanged,
  );
}

/// The high-level agent service.
@Riverpod(keepAlive: true)
AgentService agentService(Ref ref) {
  return AgentService(
    repository: ref.watch(agentRepositoryProvider),
    orchestrator: ref.watch(wakeOrchestratorProvider),
    syncService: ref.watch(agentSyncServiceProvider),
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

/// List all non-deleted agent templates.
@riverpod
Future<List<AgentDomainEntity>> agentTemplates(Ref ref) async {
  final service = ref.watch(agentTemplateServiceProvider);
  return service.listTemplates();
}

/// List all agent identity instances.
@riverpod
Future<List<AgentDomainEntity>> allAgentInstances(Ref ref) async {
  final service = ref.watch(agentServiceProvider);
  final agents = await service.listAgents();
  return agents.cast<AgentDomainEntity>();
}

/// List all evolution sessions across all templates.
@riverpod
Future<List<AgentDomainEntity>> allEvolutionSessions(Ref ref) async {
  final templateService = ref.watch(agentTemplateServiceProvider);
  final templates = await templateService.listTemplates();
  final templateIds = templates
      .map((t) => t.mapOrNull(agentTemplate: (tpl) => tpl.id))
      .whereType<String>()
      .toList();

  final sessionLists = await Future.wait(
    templateIds.map(templateService.getEvolutionSessions),
  );

  final sessions = sessionLists.expand((items) => items).toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return sessions.cast<AgentDomainEntity>();
}

/// Fetch a single agent template by [templateId].
///
/// The returned entity is an [AgentTemplateEntity] (or `null`).
@riverpod
Future<AgentDomainEntity?> agentTemplate(
  Ref ref,
  String templateId,
) async {
  final service = ref.watch(agentTemplateServiceProvider);
  return service.getTemplate(templateId);
}

/// Fetch the active version for a template by [templateId].
///
/// The returned entity is an [AgentTemplateVersionEntity] (or `null`).
@riverpod
Future<AgentDomainEntity?> activeTemplateVersion(
  Ref ref,
  String templateId,
) async {
  final service = ref.watch(agentTemplateServiceProvider);
  return service.getActiveVersion(templateId);
}

/// Fetch the version history for a template by [templateId].
///
/// Each element is an [AgentTemplateVersionEntity].
@riverpod
Future<List<AgentDomainEntity>> templateVersionHistory(
  Ref ref,
  String templateId,
) async {
  final service = ref.watch(agentTemplateServiceProvider);
  return service.getVersionHistory(templateId);
}

/// Resolve the template assigned to an agent by [agentId].
///
/// The returned entity is an [AgentTemplateEntity] (or `null`).
@riverpod
Future<AgentDomainEntity?> templateForAgent(
  Ref ref,
  String agentId,
) async {
  ref.watch(agentUpdateStreamProvider(agentId));
  final service = ref.watch(agentTemplateServiceProvider);
  return service.getTemplateForAgent(agentId);
}

/// Resolve the model ID used for a specific wake thread.
///
/// Looks up the wake run by [threadId] (which equals the run key), then
/// resolves the template version to read the `modelId` that was configured
/// when that version was created.
@riverpod
Future<String?> modelIdForThread(
  Ref ref,
  String agentId,
  String threadId,
) async {
  final repository = ref.watch(agentRepositoryProvider);

  final wakeRun = await repository.getWakeRun(threadId);
  if (wakeRun?.templateVersionId != null) {
    final versionEntity =
        await repository.getEntity(wakeRun!.templateVersionId!);
    final version = versionEntity?.mapOrNull(agentTemplateVersion: (v) => v);
    if (version?.modelId != null) return version!.modelId;
  }

  return null;
}

/// Fetch the latest report for an agent by [agentId].
///
/// Returns [AgentDomainEntity] (variant: [AgentReportEntity]) or `null`.
@riverpod
Future<AgentDomainEntity?> agentReport(
  Ref ref,
  String agentId,
) async {
  ref.watch(agentUpdateStreamProvider(agentId));
  final service = ref.watch(agentServiceProvider);
  return service.getAgentReport(agentId);
}

/// Fetch agent state for an agent by [agentId].
///
/// Returns [AgentDomainEntity] (variant: [AgentStateEntity]) or `null`.
@riverpod
Future<AgentDomainEntity?> agentState(
  Ref ref,
  String agentId,
) async {
  ref.watch(agentUpdateStreamProvider(agentId));
  final repository = ref.watch(agentRepositoryProvider);
  return repository.getAgentState(agentId);
}

/// Fetch agent identity by [agentId].
///
/// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.
@riverpod
Future<AgentDomainEntity?> agentIdentity(
  Ref ref,
  String agentId,
) async {
  ref.watch(agentUpdateStreamProvider(agentId));
  final service = ref.watch(agentServiceProvider);
  return service.getAgent(agentId);
}

/// Fetch recent messages for an agent by [agentId].
///
/// Returns up to 50 of the most recent message entities (all kinds),
/// ordered most-recent first. Each element is an [AgentDomainEntity] of
/// variant [AgentMessageEntity].
@riverpod
Future<List<AgentDomainEntity>> agentRecentMessages(
  Ref ref,
  String agentId,
) async {
  ref.watch(agentUpdateStreamProvider(agentId));
  final repository = ref.watch(agentRepositoryProvider);

  // The DB query returns rows sorted by created_at DESC with the given limit,
  // so no in-memory sort is needed.
  final entities = await repository.getEntitiesByAgentId(
    agentId,
    type: AgentEntityTypes.agentMessage,
    limit: 50,
  );

  return entities.whereType<AgentMessageEntity>().toList();
}

/// Raw token usage records for an agent.
///
/// Shared base provider that fetches `WakeTokenUsageEntity` records once;
/// both [agentTokenUsageSummariesProvider] and [tokenUsageForThreadProvider]
/// derive their state from this to avoid redundant database queries.
@riverpod
Future<List<AgentDomainEntity>> agentTokenUsageRecords(
  Ref ref,
  String agentId,
) async {
  ref.watch(agentUpdateStreamProvider(agentId));
  final repository = ref.watch(agentRepositoryProvider);
  final records = await repository.getTokenUsageForAgent(agentId, limit: 10000);
  return records.cast<AgentDomainEntity>();
}

/// Aggregated token usage summaries for an agent, grouped by model ID.
///
/// Derives from [agentTokenUsageRecordsProvider] and aggregates into
/// per-model summaries sorted by total tokens descending.
@riverpod
Future<List<AgentTokenUsageSummary>> agentTokenUsageSummaries(
  Ref ref,
  String agentId,
) async {
  final entities =
      await ref.watch(agentTokenUsageRecordsProvider(agentId).future);
  final records = entities.whereType<WakeTokenUsageEntity>();

  final map = <String, AgentTokenUsageSummary>{};
  for (final r in records) {
    final existing = map[r.modelId];
    map[r.modelId] = AgentTokenUsageSummary(
      modelId: r.modelId,
      inputTokens: (existing?.inputTokens ?? 0) + (r.inputTokens ?? 0),
      outputTokens: (existing?.outputTokens ?? 0) + (r.outputTokens ?? 0),
      thoughtsTokens: (existing?.thoughtsTokens ?? 0) + (r.thoughtsTokens ?? 0),
      cachedInputTokens:
          (existing?.cachedInputTokens ?? 0) + (r.cachedInputTokens ?? 0),
      wakeCount: (existing?.wakeCount ?? 0) + 1,
    );
  }

  return map.values.toList()
    ..sort((a, b) => b.totalTokens.compareTo(a.totalTokens));
}

/// Aggregated token usage summary for a specific thread.
///
/// Derives from [agentTokenUsageRecordsProvider], filters by [threadId],
/// and folds into a single [AgentTokenUsageSummary].
/// Returns `null` if no records match.
@riverpod
Future<AgentTokenUsageSummary?> tokenUsageForThread(
  Ref ref,
  String agentId,
  String threadId,
) async {
  final entities =
      await ref.watch(agentTokenUsageRecordsProvider(agentId).future);
  final threadRecords = entities
      .whereType<WakeTokenUsageEntity>()
      .where((r) => r.threadId == threadId)
      .toList();
  if (threadRecords.isEmpty) return null;

  return threadRecords.fold<AgentTokenUsageSummary>(
    AgentTokenUsageSummary(modelId: threadRecords.first.modelId),
    (summary, r) => AgentTokenUsageSummary(
      modelId: summary.modelId,
      inputTokens: summary.inputTokens + (r.inputTokens ?? 0),
      outputTokens: summary.outputTokens + (r.outputTokens ?? 0),
      thoughtsTokens: summary.thoughtsTokens + (r.thoughtsTokens ?? 0),
      cachedInputTokens: summary.cachedInputTokens + (r.cachedInputTokens ?? 0),
      wakeCount: summary.wakeCount + 1,
    ),
  );
}

// ── Template-level aggregate token usage ──────────────────────────────────

/// Raw token usage records for all instances of a template.
///
/// Uses a SQL JOIN via `template_assignment` links to fetch all
/// [WakeTokenUsageEntity] records across every instance in a single query.
@riverpod
Future<List<AgentDomainEntity>> templateTokenUsageRecords(
  Ref ref,
  String templateId,
) async {
  ref.watch(agentUpdateStreamProvider(templateId));
  final repository = ref.watch(agentRepositoryProvider);
  final records = await repository.getTokenUsageForTemplate(
    templateId,
  );
  return records.cast<AgentDomainEntity>();
}

/// Aggregated token usage summaries for a template, grouped by model ID.
///
/// Derives from [templateTokenUsageRecordsProvider] and aggregates into
/// per-model summaries sorted by total tokens descending.
@riverpod
Future<List<AgentTokenUsageSummary>> templateTokenUsageSummaries(
  Ref ref,
  String templateId,
) async {
  final entities =
      await ref.watch(templateTokenUsageRecordsProvider(templateId).future);
  final records = entities.whereType<WakeTokenUsageEntity>();

  final map = <String, AgentTokenUsageSummary>{};
  for (final r in records) {
    final existing = map[r.modelId];
    map[r.modelId] = AgentTokenUsageSummary(
      modelId: r.modelId,
      inputTokens: (existing?.inputTokens ?? 0) + (r.inputTokens ?? 0),
      outputTokens: (existing?.outputTokens ?? 0) + (r.outputTokens ?? 0),
      thoughtsTokens: (existing?.thoughtsTokens ?? 0) + (r.thoughtsTokens ?? 0),
      cachedInputTokens:
          (existing?.cachedInputTokens ?? 0) + (r.cachedInputTokens ?? 0),
      wakeCount: (existing?.wakeCount ?? 0) + 1,
    );
  }

  return map.values.toList()
    ..sort((a, b) => b.totalTokens.compareTo(a.totalTokens));
}

/// Per-instance token usage breakdown for a template.
///
/// Groups token records by instance, then by model within each instance.
/// Returns full per-model summaries so each instance can render a
/// `TokenUsageTable` identical in structure to the aggregate view.
@riverpod
Future<List<InstanceTokenBreakdown>> templateInstanceTokenBreakdown(
  Ref ref,
  String templateId,
) async {
  final entities =
      await ref.watch(templateTokenUsageRecordsProvider(templateId).future);
  final records = entities.whereType<WakeTokenUsageEntity>();

  // Group by agentId → modelId → AgentTokenUsageSummary
  final byAgent = <String, Map<String, AgentTokenUsageSummary>>{};
  for (final r in records) {
    final modelMap = byAgent.putIfAbsent(r.agentId, () => {});
    final existing = modelMap[r.modelId];
    modelMap[r.modelId] = AgentTokenUsageSummary(
      modelId: r.modelId,
      inputTokens: (existing?.inputTokens ?? 0) + (r.inputTokens ?? 0),
      outputTokens: (existing?.outputTokens ?? 0) + (r.outputTokens ?? 0),
      thoughtsTokens: (existing?.thoughtsTokens ?? 0) + (r.thoughtsTokens ?? 0),
      cachedInputTokens:
          (existing?.cachedInputTokens ?? 0) + (r.cachedInputTokens ?? 0),
      wakeCount: (existing?.wakeCount ?? 0) + 1,
    );
  }

  // Enrich with instance metadata
  final templateService = ref.watch(agentTemplateServiceProvider);
  final agents = await templateService.getAgentsForTemplate(templateId);

  return agents.map((agent) {
    final summaries = (byAgent[agent.agentId]?.values.toList() ?? [])
      ..sort((a, b) => b.totalTokens.compareTo(a.totalTokens));
    return InstanceTokenBreakdown(
      agentId: agent.id,
      displayName: agent.displayName,
      lifecycle: agent.lifecycle,
      summaries: summaries,
    );
  }).toList()
    ..sort((a, b) => b.totalTokens.compareTo(a.totalTokens));
}

/// Recent reports from all instances of a template, newest-first.
@riverpod
Future<List<AgentDomainEntity>> templateRecentReports(
  Ref ref,
  String templateId,
) async {
  ref.watch(agentUpdateStreamProvider(templateId));
  final repository = ref.watch(agentRepositoryProvider);
  final reports = await repository.getRecentReportsByTemplate(
    templateId,
    limit: 20,
  );
  return reports.cast<AgentDomainEntity>();
}

/// Loads the text content of an [AgentMessagePayloadEntity] by its ID.
///
/// Returns the `text` field from the payload content map, or `null` if the
/// payload doesn't exist or has no text.
@riverpod
Future<String?> agentMessagePayloadText(
  Ref ref,
  String payloadId,
) async {
  final repository = ref.watch(agentRepositoryProvider);
  final entity = await repository.getEntity(payloadId);
  if (entity is AgentMessagePayloadEntity) {
    final text = entity.content['text'];
    if (text is String && text.isNotEmpty) return text;
  }
  return null;
}

/// Fetch recent messages grouped by thread ID for an agent.
///
/// Returns a map of threadId → list of [AgentMessageEntity] sorted
/// chronologically within each thread. Threads are sorted most-recent-first
/// (by the latest message in each thread).
@riverpod
Future<Map<String, List<AgentDomainEntity>>> agentMessagesByThread(
  Ref ref,
  String agentId,
) async {
  ref.watch(agentUpdateStreamProvider(agentId));
  final repository = ref.watch(agentRepositoryProvider);
  final entities = await repository.getEntitiesByAgentId(
    agentId,
    type: AgentEntityTypes.agentMessage,
    limit: 200,
  );
  final messages = entities.whereType<AgentMessageEntity>().toList();
  final grouped = <String, List<AgentDomainEntity>>{};
  for (final msg in messages) {
    grouped.putIfAbsent(msg.threadId, () => []).add(msg);
  }
  // Sort each thread chronologically (oldest first within thread).
  for (final thread in grouped.values) {
    thread.sort((a, b) {
      final aMsg = a as AgentMessageEntity;
      final bMsg = b as AgentMessageEntity;
      return aMsg.createdAt.compareTo(bMsg.createdAt);
    });
  }

  // Sort threads most-recent-first by the latest message in each thread.
  final sortedEntries = grouped.entries.toList()
    ..sort((a, b) {
      final aLatest = (a.value.last as AgentMessageEntity).createdAt;
      final bLatest = (b.value.last as AgentMessageEntity).createdAt;
      return bLatest.compareTo(aLatest);
    });

  return Map.fromEntries(sortedEntries);
}

/// Fetch recent observation messages for an agent by [agentId].
///
/// Returns only messages with kind [AgentMessageKind.observation], ordered
/// most-recent first.
@riverpod
Future<List<AgentDomainEntity>> agentObservationMessages(
  Ref ref,
  String agentId,
) async {
  ref.watch(agentUpdateStreamProvider(agentId));
  final repository = ref.watch(agentRepositoryProvider);
  final entities = await repository.getEntitiesByAgentId(
    agentId,
    type: AgentEntityTypes.agentMessage,
    limit: 200,
  );
  return entities
      .whereType<AgentMessageEntity>()
      .where((msg) => msg.kind == AgentMessageKind.observation)
      .toList();
}

/// Fetch all report snapshots for an agent by [agentId], most-recent first.
///
/// Each wake overwrites the report, so older snapshots let the user trace
/// how the report evolved over time.
@riverpod
Future<List<AgentDomainEntity>> agentReportHistory(
  Ref ref,
  String agentId,
) async {
  ref.watch(agentUpdateStreamProvider(agentId));
  final repository = ref.watch(agentRepositoryProvider);
  final entities = await repository.getEntitiesByAgentId(
    agentId,
    type: AgentEntityTypes.agentReport,
    limit: 50,
  );
  return entities.whereType<AgentReportEntity>().toList();
}

/// Computed performance metrics for a template by [templateId].
@riverpod
Future<TemplatePerformanceMetrics> templatePerformanceMetrics(
  Ref ref,
  String templateId,
) async {
  final service = ref.watch(agentTemplateServiceProvider);
  return service.computeMetrics(templateId);
}

/// The template evolution workflow with all dependencies resolved.
///
/// Includes the multi-turn session dependencies ([AgentTemplateService],
/// [AgentSyncService]) alongside the legacy single-turn dependencies.
@Riverpod(keepAlive: true)
TemplateEvolutionWorkflow templateEvolutionWorkflow(Ref ref) {
  return TemplateEvolutionWorkflow(
    conversationRepository: ref.watch(conversationRepositoryProvider.notifier),
    aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
    cloudInferenceRepository: ref.watch(cloudInferenceRepositoryProvider),
    templateService: ref.watch(agentTemplateServiceProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    updateNotifications: ref.watch(updateNotificationsProvider),
  );
}

/// Fetch evolution sessions for a template, newest-first.
///
/// Each element is an [EvolutionSessionEntity].
@riverpod
Future<List<AgentDomainEntity>> evolutionSessions(
  Ref ref,
  String templateId,
) async {
  // Reactively rebuild when the template's data changes.
  ref.watch(agentUpdateStreamProvider(templateId));
  final service = ref.watch(agentTemplateServiceProvider);
  return service.getEvolutionSessions(templateId);
}

/// Fetch evolution notes for a template, newest-first.
///
/// Each element is an [EvolutionNoteEntity].
@riverpod
Future<List<AgentDomainEntity>> evolutionNotes(
  Ref ref,
  String templateId,
) async {
  ref.watch(agentUpdateStreamProvider(templateId));
  final service = ref.watch(agentTemplateServiceProvider);
  return service.getRecentEvolutionNotes(templateId);
}

/// The task agent workflow with all dependencies resolved.
@Riverpod(keepAlive: true)
TaskAgentWorkflow taskAgentWorkflow(Ref ref) {
  return TaskAgentWorkflow(
    agentRepository: ref.watch(agentRepositoryProvider),
    conversationRepository: ref.watch(conversationRepositoryProvider.notifier),
    aiInputRepository: ref.watch(aiInputRepositoryProvider),
    aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
    journalDb: ref.watch(journalDbProvider),
    cloudInferenceRepository: ref.watch(cloudInferenceRepositoryProvider),
    journalRepository: ref.watch(journalRepositoryProvider),
    checklistRepository: ref.watch(checklistRepositoryProvider),
    labelsRepository: ref.watch(labelsRepositoryProvider),
    syncService: ref.watch(agentSyncServiceProvider),
    templateService: ref.watch(agentTemplateServiceProvider),
    domainLogger: ref.watch(domainLoggerProvider),
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

  // 4. Wire the sync event processor for cross-device agent data.
  _wireSyncEventProcessor(
    ref,
    orchestrator,
    syncEventProcessor,
  );

  // 5. Seed default templates, profiles, and restore subscriptions.
  await templateService.seedDefaults();
  await ProfileSeedingService(
    aiConfigRepository: ref.watch(aiConfigRepositoryProvider),
  ).seedDefaults();
  await taskAgentService.restoreSubscriptions();
}

/// Wires [TaskAgentWorkflow.execute] into the orchestrator's [WakeExecutor]
/// callback so that [WakeOrchestrator.processNext] delegates to the workflow.
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

    // Notify the update stream so all detail providers self-invalidate.
    // Include the templateId (if assigned) so template-level aggregate
    // providers also refresh. Wrapped in try/catch so a lookup failure
    // doesn't mark a successfully completed wake as failed.
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

    updateNotifications.notify({
      agentId,
      if (templateId != null) templateId,
      agentNotification,
    });

    return result.mutatedEntries;
  };
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
  ref.onDispose(() {
    processor
      ..agentRepository = null
      ..wakeOrchestrator = null;
  });
}
