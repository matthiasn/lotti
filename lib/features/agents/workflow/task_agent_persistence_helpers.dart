part of 'task_agent_workflow.dart';

/// Persistence helpers of [TaskAgentWorkflow]: report embeddings.
extension TaskAgentPersistenceHelpers on TaskAgentWorkflow {
  /// Embeds an agent report for vector search, in its task's category, and
  /// makes it the task's only report there
  /// (see [EmbeddingProcessor.processAgentReport]).
  ///
  /// Only while embeddings are on and the model is downloaded, as for every
  /// other embedding. Non-fatal: failures are logged but do not affect the
  /// wake cycle. Called as fire-and-forget via [unawaited] after report
  /// persistence.
  Future<void> _embedAgentReport({
    required String reportId,
    required String reportContent,
    required String taskId,
  }) async {
    final store = embeddingStore;
    final repo = embeddingRepository;
    if (store == null || repo == null) return;

    try {
      if (!await journalDb.getConfigFlag(enableEmbeddingsFlag) ||
          !await repo.isInstalled()) {
        return;
      }

      await EmbeddingProcessor.processAgentReport(
        reportId: reportId,
        reportContent: reportContent,
        taskId: taskId,
        subtype: AgentReportScopes.current,
        journalDb: journalDb,
        embeddingStore: store,
        embeddingRepository: repo,
      );
    } catch (e, s) {
      logError('failed to embed agent report', error: e, stackTrace: s);
    }
  }
}
