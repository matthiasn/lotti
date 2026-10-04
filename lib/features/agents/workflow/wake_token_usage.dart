import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/util/agent_error_logging.dart';
import 'package:lotti/features/agents/workflow/agent_template_context.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:uuid/uuid.dart';

/// Records one inference pass's token [usage] as a synced
/// [WakeTokenUsageEntity], attributed to the wake ([agentId], [runKey],
/// [threadId]), the model that ran, and — when the agent runs on a template —
/// the template, version and soul document behind it.
///
/// Does nothing when [usage] is null or carries no counts. The write is
/// bookkeeping: a failure goes to [logError] and is never rethrown, because a
/// lost usage row must not fail, or re-run, a wake whose outputs already
/// committed.
Future<void> persistWakeTokenUsage({
  required AgentSyncService syncService,
  required InferenceUsage? usage,
  required String agentId,
  required String runKey,
  required String threadId,
  required String modelId,
  required DateTime now,
  required LogErrorCallback logError,
  AgentTemplateContext? templateCtx,
}) async {
  if (usage == null || !usage.hasData) return;

  try {
    await syncService.upsertEntity(
      AgentDomainEntity.wakeTokenUsage(
        id: const Uuid().v4(),
        agentId: agentId,
        runKey: runKey,
        threadId: threadId,
        modelId: modelId,
        templateId: templateCtx?.template.id,
        templateVersionId: templateCtx?.version.id,
        soulDocumentId: templateCtx?.soulVersion?.agentId,
        soulDocumentVersionId: templateCtx?.soulVersion?.id,
        createdAt: now,
        vectorClock: null,
        inputTokens: usage.inputTokens,
        outputTokens: usage.outputTokens,
        thoughtsTokens: usage.thoughtsTokens,
        cachedInputTokens: usage.cachedInputTokens,
      ),
    );
  } catch (error, stackTrace) {
    logError(
      'failed to persist wake token usage',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
