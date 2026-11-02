import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/util/agent_error_logging.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/on_device_embedding/on_device_embedding_repository.dart';
import 'package:lotti/features/ai/service/embedding_processor.dart';
import 'package:lotti/utils/consts.dart';

/// Embeds an agent's current report — its one-liner, TLDR and body — for
/// vector search, keyed to the entity it is about, [subjectId]: a task for
/// the task agent, an event for the event agent. The report lands in its
/// subject's category and replaces every earlier report embedded for that
/// subject (see [EmbeddingProcessor.processAgentReport]), so a search hit on
/// it resolves to the subject.
///
/// Only while embeddings are on and the model is downloaded, as for every
/// other embedding; without the pipeline ([embeddingStore] or
/// [embeddingRepository] null) it does nothing. Never throws: a failure is
/// handed to [logError] and the wake that wrote the report stands.
Future<void> embedAgentReport({
  required EmbeddingStore? embeddingStore,
  required OnDeviceEmbeddingRepository? embeddingRepository,
  required JournalDb journalDb,
  required String reportId,
  required String reportContent,
  required String subjectId,
  required LogErrorCallback logError,
  String? reportTldr,
  String? reportOneLiner,
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
      content: reportContent,
      tldr: reportTldr,
      oneLiner: reportOneLiner,
      taskId: subjectId,
      subtype: AgentReportScopes.current,
      journalDb: journalDb,
      embeddingStore: store,
      embeddingRepository: repo,
    );
  } catch (e, s) {
    logError('failed to embed agent report', error: e, stackTrace: s);
  }
}
