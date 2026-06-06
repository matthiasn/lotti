part of 'task_agent_workflow.dart';

/// Persistence helpers of [TaskAgentWorkflow]: token usage and report
/// embeddings.
extension TaskAgentPersistenceHelpers on TaskAgentWorkflow {
  /// Persist token usage from a wake cycle as a synced entity.
  ///
  /// Non-fatal: failures are logged but do not abort the wake.
  Future<void> _persistTokenUsage({
    required InferenceUsage? usage,
    required String agentId,
    required String runKey,
    required String threadId,
    required String modelId,
    required _TemplateContext templateCtx,
    required DateTime now,
  }) async {
    if (usage == null || !usage.hasData) return;

    try {
      await syncService.upsertEntity(
        AgentDomainEntity.wakeTokenUsage(
          id: TaskAgentWorkflow._uuid.v4(),
          agentId: agentId,
          runKey: runKey,
          threadId: threadId,
          modelId: modelId,
          templateId: templateCtx.template.id,
          templateVersionId: templateCtx.version.id,
          soulDocumentId: templateCtx.soulVersion?.agentId,
          soulDocumentVersionId: templateCtx.soulVersion?.id,
          createdAt: now,
          vectorClock: null,
          inputTokens: usage.inputTokens,
          outputTokens: usage.outputTokens,
          thoughtsTokens: usage.thoughtsTokens,
          cachedInputTokens: usage.cachedInputTokens,
        ),
      );
    } catch (e, s) {
      _logError('failed to persist token usage', error: e, stackTrace: s);
    }
  }

  /// Embeds an agent report for vector search and supersedes the previous
  /// report's embedding if one exists.
  ///
  /// Non-fatal: failures are logged but do not affect the wake cycle.
  /// Called as fire-and-forget via [unawaited] after report persistence.
  Future<void> _embedAgentReport({
    required String reportId,
    required String reportContent,
    required String taskId,
    String? previousReportId,
  }) async {
    final store = embeddingStore;
    final repo = embeddingRepository;
    if (store == null || repo == null) return;

    try {
      final baseUrl = await this.aiConfigRepository.resolveOllamaBaseUrl();
      if (baseUrl == null) return;

      // Resolve the task's category for category-scoped search.
      final taskEntity = await journalDb.journalEntityById(taskId);
      final categoryId = taskEntity?.meta.categoryId ?? '';

      final didEmbed = await EmbeddingProcessor.processAgentReport(
        reportId: reportId,
        reportContent: reportContent,
        taskId: taskId,
        categoryId: categoryId,
        subtype: AgentReportScopes.current,
        embeddingStore: store,
        embeddingRepository: repo,
        baseUrl: baseUrl,
      );

      // Delete the old report's embedding only after the new one succeeds,
      // so we don't lose search coverage if the embedding call fails or
      // the content is too short.
      if (didEmbed && previousReportId != null) {
        await store.deleteEntityEmbeddings(previousReportId);
      }
    } catch (e, s) {
      _logError('failed to embed agent report', error: e, stackTrace: s);
    }
  }
}
