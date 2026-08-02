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
  /// Non-fatal: failures do not affect the wake cycle. Availability failures
  /// defer the latest report per task until the endpoint's retry time.
  /// Called as fire-and-forget via [unawaited] after report persistence.
  Future<void> _embedAgentReport({
    required String reportId,
    required String reportContent,
    required String taskId,
    String? previousReportId,
    bool isRetry = false,
  }) async {
    final store = embeddingStore;
    final repo = embeddingRepository;
    if (store == null || repo == null) return;
    if (!isRetry) {
      _latestReportEmbeddingIds.remove(taskId);
      _pendingReportEmbeddings.remove(taskId);
    } else if (_latestReportEmbeddingIds[taskId] != reportId) {
      return;
    }

    try {
      final baseUrl = await this.aiConfigRepository.resolveOllamaBaseUrl();
      if (baseUrl == null) return;
      if (!isRetry) {
        _latestReportEmbeddingIds[taskId] = reportId;
        _pendingReportEmbeddings.remove(taskId);
      }

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
      _completeAgentReportEmbedding(taskId, reportId);
    } on OllamaEmbeddingAvailabilityException catch (e, stackTrace) {
      if (_latestReportEmbeddingIds[taskId] != reportId) return;
      _deferAgentReportEmbedding(
        _PendingReportEmbedding(
          reportId: reportId,
          reportContent: reportContent,
          taskId: taskId,
          previousReportId: previousReportId,
          retryAt: e.retryAt,
        ),
      );
      if (e is OllamaEmbeddingCooldownException) {
        // The shared repository records sampled, counted cooldown summaries.
        // A stack trace per optional report would recreate the outage-driven
        // log amplification that the availability circuit is meant to stop.
        if (!e.shouldLogSummary) return;
        _logError(
          'optional agent report embedding paused; counted cooldown summary',
          error: e,
        );
        return;
      }
      _logError(
        'optional agent report embedding paused; retry scheduled',
        error: e,
        stackTrace: stackTrace,
      );
    } catch (e, s) {
      _completeAgentReportEmbedding(taskId, reportId);
      _logError('failed to embed agent report', error: e, stackTrace: s);
    }
  }

  void _completeAgentReportEmbedding(String taskId, String reportId) {
    if (_latestReportEmbeddingIds[taskId] == reportId) {
      _latestReportEmbeddingIds.remove(taskId);
    }
  }

  void _deferAgentReportEmbedding(_PendingReportEmbedding pending) {
    _pendingReportEmbeddings[pending.taskId] = pending;
    unawaited(_retryAgentReportEmbedding(pending));
  }

  Future<void> _retryAgentReportEmbedding(
    _PendingReportEmbedding pending,
  ) async {
    final remaining = pending.retryAt.difference(clock.now());
    await _reportEmbeddingDelay(
      remaining.isNegative ? Duration.zero : remaining,
    );
    if (!identical(_pendingReportEmbeddings[pending.taskId], pending) ||
        _latestReportEmbeddingIds[pending.taskId] != pending.reportId) {
      return;
    }

    _pendingReportEmbeddings.remove(pending.taskId);
    await _embedAgentReport(
      reportId: pending.reportId,
      reportContent: pending.reportContent,
      taskId: pending.taskId,
      previousReportId: pending.previousReportId,
      isRetry: true,
    );
  }
}

class _PendingReportEmbedding {
  const _PendingReportEmbedding({
    required this.reportId,
    required this.reportContent,
    required this.taskId,
    required this.previousReportId,
    required this.retryAt,
  });

  final String reportId;
  final String reportContent;
  final String taskId;
  final String? previousReportId;
  final DateTime retryAt;
}
