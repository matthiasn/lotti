part of 'task_agent_workflow.dart';

/// Persistence helpers of [TaskAgentWorkflow]: report embeddings.
extension TaskAgentPersistenceHelpers on TaskAgentWorkflow {
  /// Embeds an agent report — its one-liner, TLDR and body — for vector
  /// search, in its task's category, and makes it the task's only report
  /// there (see [EmbeddingProcessor.processAgentReport]).
  ///
  /// Only while embeddings are on and the model is downloaded, as for every
  /// other embedding. Non-fatal: failures are logged but do not affect the
  /// wake cycle. Called as fire-and-forget via [unawaited] after report
  /// persistence.
  Future<void> _embedAgentReport({
    required String reportId,
    required String reportContent,
    required String taskId,
    String? reportTldr,
    String? reportOneLiner,
  }) => embedAgentReport(
    embeddingStore: embeddingStore,
    embeddingRepository: embeddingRepository,
    journalDb: journalDb,
    reportId: reportId,
    reportContent: reportContent,
    subjectId: taskId,
    reportTldr: reportTldr,
    reportOneLiner: reportOneLiner,
    logError: logError,
  );
}
