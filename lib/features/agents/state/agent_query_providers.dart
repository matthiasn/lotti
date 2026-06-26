import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_token_usage.dart';
import 'package:lotti/features/agents/service/wake_prompt_reconstructor.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/workflow/prompt_record.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';

/// Whether a specific agent is currently running.
///
/// Yields the initial synchronous value, then updates reactively whenever the
/// agent starts or stops running.
final StreamProviderFamily<bool, String> agentIsRunningProvider = StreamProvider
    .autoDispose
    .family<bool, String>(
      agentIsRunning,
      name: 'agentIsRunningProvider',
    );
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
final StreamProviderFamily<Set<String>, String> agentUpdateStreamProvider =
    StreamProvider.autoDispose.family<Set<String>, String>(
      agentUpdateStream,
      name: 'agentUpdateStreamProvider',
    );
Stream<Set<String>> agentUpdateStream(Ref ref, String agentId) {
  final notifications = ref.watch(updateNotificationsProvider);
  return notifications.updateStream.where((ids) => ids.contains(agentId));
}

/// Fetch the latest report for an agent by agentId.
///
/// Returns [AgentDomainEntity] (variant: [AgentReportEntity]) or `null`.
final FutureProviderFamily<AgentDomainEntity?, String> agentReportProvider =
    FutureProvider.autoDispose.family<AgentDomainEntity?, String>(
      agentReport,
      name: 'agentReportProvider',
    );
Future<AgentDomainEntity?> agentReport(
  Ref ref,
  String agentId,
) async {
  ref.watch(agentUpdateStreamProvider(agentId));
  final service = ref.watch(agentServiceProvider);
  return service.getAgentReport(agentId);
}

/// Fetch agent state for an agent by agentId.
///
/// Returns [AgentDomainEntity] (variant: [AgentStateEntity]) or `null`.
final FutureProviderFamily<AgentDomainEntity?, String> agentStateProvider =
    FutureProvider.autoDispose.family<AgentDomainEntity?, String>(
      agentState,
      name: 'agentStateProvider',
    );
Future<AgentDomainEntity?> agentState(
  Ref ref,
  String agentId,
) async {
  ref.watch(agentUpdateStreamProvider(agentId));
  final repository = ref.watch(agentRepositoryProvider);
  return repository.getAgentState(agentId);
}

/// Fetch agent identity by agentId.
///
/// Returns [AgentDomainEntity] (variant: [AgentIdentityEntity]) or `null`.
final FutureProviderFamily<AgentDomainEntity?, String> agentIdentityProvider =
    FutureProvider.autoDispose.family<AgentDomainEntity?, String>(
      agentIdentity,
      name: 'agentIdentityProvider',
    );
Future<AgentDomainEntity?> agentIdentity(
  Ref ref,
  String agentId,
) async {
  ref.watch(agentUpdateStreamProvider(agentId));
  final service = ref.watch(agentServiceProvider);
  return service.getAgent(agentId);
}

/// Fetch recent messages for an agent by agentId.
///
/// Returns up to 50 of the most recent message entities (all kinds),
/// ordered most-recent first. Each element is an [AgentDomainEntity] of
/// variant [AgentMessageEntity].
final FutureProviderFamily<List<AgentDomainEntity>, String>
agentRecentMessagesProvider = FutureProvider.autoDispose
    .family<List<AgentDomainEntity>, String>(
      agentRecentMessages,
      name: 'agentRecentMessagesProvider',
    );
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

/// Conversation-order rank for messages sharing a wake's timestamp: the
/// system prompt leads, the user message follows, agent output comes next,
/// and bookkeeping rows (milestones, retractions) trail.
int _displayRank(AgentMessageEntity message) => switch (message.kind) {
  AgentMessageKind.system when message.contentEntryId != null => 0,
  AgentMessageKind.user => 1,
  AgentMessageKind.thought => 2,
  AgentMessageKind.action => 3,
  AgentMessageKind.toolResult => 4,
  AgentMessageKind.observation => 5,
  AgentMessageKind.summary => 6,
  AgentMessageKind.system => 7,
};

/// Fetch recent messages grouped by thread ID for an agent.
///
/// Returns a map of threadId → list of [AgentMessageEntity] sorted
/// chronologically within each thread (conversation-order tiebreak for rows
/// sharing the wake timestamp). Threads are sorted most-recent-first
/// (by the latest message in each thread).
final FutureProviderFamily<Map<String, List<AgentDomainEntity>>, String>
agentMessagesByThreadProvider = FutureProvider.autoDispose
    .family<Map<String, List<AgentDomainEntity>>, String>(
      agentMessagesByThread,
      name: 'agentMessagesByThreadProvider',
    );
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
  // Sort each thread chronologically (oldest first within thread). A wake
  // persists several rows with one shared timestamp (causality), so ties
  // break by conversation order — the system prompt before the user message,
  // bookkeeping rows (milestones, retractions) last — then by id for
  // determinism.
  for (final thread in grouped.values) {
    thread.sort((a, b) {
      final aMsg = a as AgentMessageEntity;
      final bMsg = b as AgentMessageEntity;
      final byTime = aMsg.createdAt.compareTo(bMsg.createdAt);
      if (byTime != 0) return byTime;
      final byRank = _displayRank(aMsg).compareTo(_displayRank(bMsg));
      if (byRank != 0) return byRank;
      return aMsg.id.compareTo(bMsg.id);
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

/// Fetch recent observation messages for an agent by agentId.
///
/// Returns only messages with kind [AgentMessageKind.observation], ordered
/// most-recent first.
final FutureProviderFamily<List<AgentDomainEntity>, String>
agentObservationMessagesProvider = FutureProvider.autoDispose
    .family<List<AgentDomainEntity>, String>(
      agentObservationMessages,
      name: 'agentObservationMessagesProvider',
    );
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

/// Fetch all report snapshots for an agent by agentId, most-recent first.
///
/// Each wake overwrites the report, so older snapshots let the user trace
/// how the report evolved over time.
final FutureProviderFamily<List<AgentDomainEntity>, String>
agentReportHistoryProvider = FutureProvider.autoDispose
    .family<List<AgentDomainEntity>, String>(
      agentReportHistory,
      name: 'agentReportHistoryProvider',
    );
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

/// Loads the text content of an [AgentMessagePayloadEntity] by its ID.
///
/// Legacy payloads return their `text` field directly. v2 prompt records
/// (ADR 0020) store only the prompt's non-derivable halves — the log block
/// is reconstructed on demand from the synced event log via
/// [WakePromptReconstructor]. Returns `null` if the payload doesn't exist
/// or has no renderable text.
final FutureProviderFamily<String?, String> agentMessagePayloadTextProvider =
    FutureProvider.autoDispose.family<String?, String>(
      agentMessagePayloadText,
      name: 'agentMessagePayloadTextProvider',
    );
Future<String?> agentMessagePayloadText(
  Ref ref,
  String payloadId,
) async {
  final repository = ref.watch(agentRepositoryProvider);
  final entity = await repository.getEntity(payloadId);
  if (entity is! AgentMessagePayloadEntity) return null;

  if (entity.content['promptFormat'] == promptRecordFormatV2) {
    final reconstructor = WakePromptReconstructor(
      syncService: ref.watch(agentSyncServiceProvider),
      domainLogger: ref.watch(domainLoggerProvider),
    );
    final reconstructed = await reconstructor.reconstruct(
      agentId: entity.agentId,
      content: entity.content,
    );
    if (reconstructed != null && reconstructed.isNotEmpty) {
      return reconstructed;
    }
  }

  final text = entity.content['text'];
  if (text is String && text.isNotEmpty) return text;
  return null;
}

/// List all agent identity instances.
final FutureProvider<List<AgentDomainEntity>> allAgentInstancesProvider =
    FutureProvider.autoDispose<List<AgentDomainEntity>>(
      allAgentInstances,
      name: 'allAgentInstancesProvider',
    );
Future<List<AgentDomainEntity>> allAgentInstances(Ref ref) async {
  final service = ref.watch(agentServiceProvider);
  final agents = await service.listAgents();
  return agents.cast<AgentDomainEntity>();
}

// ── Token usage providers ───────────────────────────────────────────────────

/// Raw token usage records for an agent.
///
/// Shared base provider that fetches `WakeTokenUsageEntity` records once;
/// both [agentTokenUsageSummariesProvider] and [tokenUsageForThreadProvider]
/// derive their state from this to avoid redundant database queries.
final FutureProviderFamily<List<AgentDomainEntity>, String>
agentTokenUsageRecordsProvider = FutureProvider.autoDispose
    .family<List<AgentDomainEntity>, String>(
      agentTokenUsageRecords,
      name: 'agentTokenUsageRecordsProvider',
    );
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
final FutureProviderFamily<List<AgentTokenUsageSummary>, String>
agentTokenUsageSummariesProvider = FutureProvider.autoDispose
    .family<List<AgentTokenUsageSummary>, String>(
      agentTokenUsageSummaries,
      name: 'agentTokenUsageSummariesProvider',
    );
Future<List<AgentTokenUsageSummary>> agentTokenUsageSummaries(
  Ref ref,
  String agentId,
) async {
  final entities = await ref.watch(
    agentTokenUsageRecordsProvider(agentId).future,
  );
  final records = entities.whereType<WakeTokenUsageEntity>();
  return aggregateByModel(records);
}

/// Aggregated token usage summary for a specific thread.
///
/// Derives from [agentTokenUsageRecordsProvider], filters by threadId,
/// and folds into a single [AgentTokenUsageSummary].
/// Returns `null` if no records match.
final FutureProviderFamily<AgentTokenUsageSummary?, (String, String)>
tokenUsageForThreadProvider = FutureProvider.autoDispose
    .family<AgentTokenUsageSummary?, (String, String)>(
      (ref, arg) => tokenUsageForThread(ref, arg.$1, arg.$2),
      name: 'tokenUsageForThreadProvider',
    );
Future<AgentTokenUsageSummary?> tokenUsageForThread(
  Ref ref,
  String agentId,
  String threadId,
) async {
  final entities = await ref.watch(
    agentTokenUsageRecordsProvider(agentId).future,
  );
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

/// Resolve the model ID used for a specific wake thread.
///
/// Resolution order:
/// 1. [WakeTokenUsageEntity] — the actual model used at runtime, persisted
///    when the wake completes. Authoritative for completed threads.
/// 2. `resolvedModelId` on the wake-run log — the model ID persisted at
///    wake start after profile resolution. Accurate for failed/incomplete
///    wakes that never recorded token usage.
/// 3. Wake-run template version — the `profileId` or `modelId` snapshot
///    captured when the wake started. Fallback for older wake runs that
///    predate the `resolvedModelId` column.
/// 4. Live agent config — `profile.thinkingModelId` or `config.modelId` from
///    the agent instance's current config. Only used for in-flight
///    threads where the wake run hasn't been created yet.
final FutureProviderFamily<String?, (String, String)> modelIdForThreadProvider =
    FutureProvider.autoDispose.family<String?, (String, String)>(
      (ref, arg) => modelIdForThread(ref, arg.$1, arg.$2),
      name: 'modelIdForThreadProvider',
    );
Future<String?> modelIdForThread(
  Ref ref,
  String agentId,
  String threadId,
) async {
  final repository = ref.watch(agentRepositoryProvider);
  final aiConfigRepo = ref.watch(aiConfigRepositoryProvider);

  // Tier 1: token usage records — the actual model used at runtime.
  final tokenEntities = await ref.watch(
    agentTokenUsageRecordsProvider(agentId).future,
  );
  final threadTokenRecords = tokenEntities
      .whereType<WakeTokenUsageEntity>()
      .where((r) => r.threadId == threadId)
      .toList();
  if (threadTokenRecords.isNotEmpty) {
    return threadTokenRecords.first.modelId;
  }

  // Tier 2: resolvedModelId persisted on the wake run at wake start.
  final wakeRun = await repository.getWakeRunByThreadId(agentId, threadId);
  if (wakeRun?.resolvedModelId != null) {
    return wakeRun!.resolvedModelId;
  }

  // Tier 3: wake-run template version — for older runs without
  // resolvedModelId.
  if (wakeRun?.templateVersionId != null) {
    final versionEntity = await repository.getEntity(
      wakeRun!.templateVersionId!,
    );
    final version = versionEntity?.mapOrNull(agentTemplateVersion: (v) => v);

    // Prefer the version's profile (reflects the model at wake time).
    final versionProfileId = version?.profileId;
    if (versionProfileId != null) {
      final profile = await aiConfigRepo.getConfigById(versionProfileId);
      if (profile is AiConfigInferenceProfile) {
        return profile.thinkingModelId;
      }
    }

    // Legacy: use the version's modelId directly.
    if (version?.modelId != null) return version!.modelId;
  }

  // Tier 4: live agent config — for in-flight threads with no wake run yet.
  final identity = await repository.getEntity(agentId);
  final config = identity?.mapOrNull(agent: (a) => a.config);
  final profileId = config?.profileId;
  if (profileId != null) {
    final profile = await aiConfigRepo.getConfigById(profileId);
    if (profile is AiConfigInferenceProfile) {
      return profile.thinkingModelId;
    }
  }

  // Legacy fallback: use the config's modelId directly.
  if (config?.modelId != null) return config!.modelId;

  return null;
}

// ── Shared helpers ──────────────────────────────────────────────────────────

/// Aggregates [WakeTokenUsageEntity] records by model ID into sorted
/// [AgentTokenUsageSummary] entries (total tokens descending).
List<AgentTokenUsageSummary> aggregateByModel(
  Iterable<WakeTokenUsageEntity> records,
) {
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
