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
  /// defer the latest report per task until the endpoint's retry time. When a
  /// newer report coalesces that work, it inherits the last predecessor known
  /// to be searchable rather than the unembedded intermediate report. Every
  /// attempt checks the embeddings flag before provider work, and the write
  /// guard rechecks it between chunks so disabling the feature cancels an
  /// in-flight report without replacing stored vectors.
  /// Called as fire-and-forget via [unawaited] after report persistence.
  Future<void> _embedAgentReport({
    required String reportId,
    required String reportContent,
    required String taskId,
    required String agentId,
    String? previousReportId,
    bool isRetry = false,
    bool allowStaleTargetRetry = true,
  }) async {
    final store = embeddingStore;
    final repo = embeddingRepository;
    if (store == null || repo == null) return;
    var embeddingPredecessorId = previousReportId;
    if (!isRetry) {
      final activeReportId = _latestReportEmbeddingIds[taskId];
      if (activeReportId == previousReportId &&
          _reportEmbeddingPredecessorIds.containsKey(taskId)) {
        embeddingPredecessorId = _reportEmbeddingPredecessorIds[taskId];
      }
      _latestReportEmbeddingIds[taskId] = reportId;
      _reportEmbeddingPredecessorIds[taskId] = embeddingPredecessorId;
      _pendingReportEmbeddings.remove(taskId);
    } else if (_latestReportEmbeddingIds[taskId] != reportId) {
      return;
    }

    try {
      if (!await journalDb.getConfigFlag(enableEmbeddingsFlag)) {
        _completeAgentReportEmbedding(taskId, reportId);
        return;
      }
      final baseUrl = await this.aiConfigRepository.resolveOllamaBaseUrl();
      if (baseUrl == null) {
        _completeAgentReportEmbedding(taskId, reportId);
        return;
      }
      if (_latestReportEmbeddingIds[taskId] != reportId) return;

      // Resolve the task's category for category-scoped search.
      final taskEntity = await journalDb.journalEntityById(taskId);
      if (_latestReportEmbeddingIds[taskId] != reportId) return;
      final categoryId = taskEntity?.meta.categoryId ?? '';
      if (!await _isCurrentAgentReport(
        agentId: agentId,
        taskId: taskId,
        reportId: reportId,
        categoryId: categoryId,
      )) {
        await _retryStaleAgentReportTarget(
          reportId: reportId,
          reportContent: reportContent,
          taskId: taskId,
          agentId: agentId,
          previousReportId: embeddingPredecessorId,
          allowRetry: allowStaleTargetRetry,
        );
        return;
      }

      final didEmbed = await EmbeddingProcessor.processAgentReport(
        reportId: reportId,
        reportContent: reportContent,
        taskId: taskId,
        agentId: agentId,
        categoryId: categoryId,
        subtype: AgentReportScopes.current,
        embeddingStore: store,
        embeddingRepository: repo,
        baseUrl: baseUrl,
        writeGuard: () async =>
            await journalDb.getConfigFlag(enableEmbeddingsFlag) &&
            await _isCurrentAgentReport(
              agentId: agentId,
              taskId: taskId,
              reportId: reportId,
              categoryId: categoryId,
            ),
      );

      final isStillCurrent = await _isCurrentAgentReport(
        agentId: agentId,
        taskId: taskId,
        reportId: reportId,
        categoryId: categoryId,
      );
      if (!isStillCurrent) {
        if (didEmbed) {
          // Storage completed after one of the durable selectors changed.
          // Remove only the vector just written, then retry once against a
          // fresh task/category snapshot if this report still owns the local
          // claim.
          await store.deleteEntityEmbeddings(reportId);
        }
        await _retryStaleAgentReportTarget(
          reportId: reportId,
          reportContent: reportContent,
          taskId: taskId,
          agentId: agentId,
          previousReportId: embeddingPredecessorId,
          allowRetry: allowStaleTargetRetry,
        );
        return;
      }

      // Delete the old report's embedding only after the new one succeeds,
      // so we don't lose search coverage if the embedding call fails or
      // the content is too short.
      if (didEmbed) {
        // Once storage succeeds, a report arriving while predecessor cleanup
        // is still in flight must supersede this newly stored report, not the
        // older report that this operation is already deleting.
        _reportEmbeddingPredecessorIds[taskId] = reportId;
        if (embeddingPredecessorId != null) {
          await store.deleteEntityEmbeddings(embeddingPredecessorId);
        }
      }
      _completeAgentReportEmbedding(taskId, reportId);
    } on OllamaEmbeddingAvailabilityException catch (e, stackTrace) {
      if (_latestReportEmbeddingIds[taskId] != reportId) return;
      _deferAgentReportEmbedding(
        _PendingReportEmbedding(
          reportId: reportId,
          reportContent: reportContent,
          taskId: taskId,
          agentId: agentId,
          previousReportId: embeddingPredecessorId,
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

  /// Confirms the local claim, durable report head, and canonical task owner.
  Future<bool> _isCurrentAgentReport({
    required String agentId,
    required String taskId,
    required String reportId,
    required String categoryId,
  }) async {
    if (_latestReportEmbeddingIds[taskId] != reportId) return false;
    final durableHead = await agentRepository.getLatestReport(
      agentId,
      AgentReportScopes.current,
    );
    if (_latestReportEmbeddingIds[taskId] != reportId ||
        durableHead?.id != reportId) {
      return false;
    }
    final taskLinks = await agentRepository.getLinksTo(
      taskId,
      type: AgentLinkTypes.agentTask,
    );
    if (_latestReportEmbeddingIds[taskId] != reportId ||
        taskLinks.isEmpty ||
        taskLinks.selectPrimary().fromId != agentId) {
      return false;
    }
    final task = await journalDb.journalEntityById(taskId);
    return _latestReportEmbeddingIds[taskId] == reportId &&
        (task?.meta.categoryId ?? '') == categoryId;
  }

  Future<void> _retryStaleAgentReportTarget({
    required String reportId,
    required String reportContent,
    required String taskId,
    required String agentId,
    required String? previousReportId,
    required bool allowRetry,
  }) async {
    if (!allowRetry) {
      _completeAgentReportEmbedding(taskId, reportId);
      return;
    }
    await _embedAgentReport(
      reportId: reportId,
      reportContent: reportContent,
      taskId: taskId,
      agentId: agentId,
      previousReportId: previousReportId,
      isRetry: true,
      allowStaleTargetRetry: false,
    );
  }

  void _completeAgentReportEmbedding(String taskId, String reportId) {
    if (_latestReportEmbeddingIds[taskId] == reportId) {
      _latestReportEmbeddingIds.remove(taskId);
      _reportEmbeddingPredecessorIds.remove(taskId);
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
      agentId: pending.agentId,
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
    required this.agentId,
    required this.previousReportId,
    required this.retryAt,
  });

  final String reportId;
  final String reportContent;
  final String taskId;
  final String agentId;
  final String? previousReportId;
  final DateTime retryAt;
}
