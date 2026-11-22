import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task_document_data.dart';
import 'package:lotti/features/agents/model/task_document_source.dart';
import 'package:lotti/features/documents/repository/task_document_repository.dart';

/// The documents feature's side of [TaskDocumentSource]: what the task agent
/// reads of a task's documents, and the write of a document proposal the
/// user confirmed (ADR 0166), through [TaskDocumentRepository] — so an agent
/// version is the same compare-and-set as a hand edit, recorded as the
/// agent's.
class TaskDocumentAgentSource implements TaskDocumentSource {
  TaskDocumentAgentSource(this._repository);

  final TaskDocumentRepository _repository;

  @override
  Future<List<TaskDocumentSummary>> documentsOf(String taskId) async => [
    for (final document in await _repository.forTask(taskId))
      _summaryOf(document),
  ];

  @override
  Future<TaskDocumentText?> read({
    required String taskId,
    required String documentId,
  }) async {
    final document = await _ofTask(taskId, documentId);
    if (document == null) return null;
    final version = await _repository.currentVersion(document);
    return TaskDocumentText(
      summary: _summaryOf(document),
      markdown: version?.data.markdown ?? '',
    );
  }

  @override
  Future<TaskDocumentApplyOutcome> apply({
    required String taskId,
    required String markdown,
    required String documentUuidV5Input,
    required String versionUuidV5Input,
    String? documentId,
    String? newTitle,
    String? baseVersionId,
    String? changeSummary,
    String? changeEffectKey,
  }) async {
    final String targetId;
    var base = baseVersionId;
    if (documentId != null) {
      if (await _ofTask(taskId, documentId) == null) {
        return const TaskDocumentApplyRefused(
          reason: 'the task holds no such document any more',
          permanent: true,
        );
      }
      targetId = documentId;
    } else if (newTitle != null && newTitle.trim().isNotEmpty) {
      final created = await _repository.create(
        taskId: taskId,
        title: newTitle.trim(),
        uuidV5Input: documentUuidV5Input,
      );
      if (created == null) {
        return const TaskDocumentApplyRefused(
          reason: 'the document could not be created',
          permanent: false,
        );
      }
      targetId = created.id;
      // A new document is written over what it shows now: nothing, or — on a
      // second application — the version the first one wrote, which the
      // repository recognises by its derived id.
      base = created.data.current?.id;
    } else {
      return const TaskDocumentApplyRefused(
        reason: 'the proposal names neither a document nor a new title',
        permanent: true,
      );
    }

    final result = await _repository.writeVersion(
      documentId: targetId,
      markdown: markdown,
      author: TaskDocumentAuthor.agent,
      baseVersionId: base,
      changeSummary: changeSummary,
      changeEffectKey: changeEffectKey,
      uuidV5Input: versionUuidV5Input,
    );
    return switch (result.status) {
      TaskDocumentWriteStatus.written => TaskDocumentApplied(
        documentId: targetId,
        versionId: result.version!.id,
      ),
      TaskDocumentWriteStatus.stale => const TaskDocumentApplyRefused(
        reason:
            'the document changed after this version was drafted; ask for a '
            'new draft of the current version',
        permanent: true,
      ),
      TaskDocumentWriteStatus.missing => const TaskDocumentApplyRefused(
        reason: 'the document was deleted',
        permanent: true,
      ),
      TaskDocumentWriteStatus.failed => const TaskDocumentApplyRefused(
        reason: 'the version could not be stored',
        permanent: false,
      ),
    };
  }

  Future<TaskDocumentEntry?> _ofTask(String taskId, String documentId) async {
    for (final document in await _repository.forTask(taskId)) {
      if (document.id == documentId) return document;
    }
    return null;
  }

  static TaskDocumentSummary _summaryOf(TaskDocumentEntry document) =>
      TaskDocumentSummary(
        id: document.id,
        title: document.data.title,
        versionId: document.data.current?.id,
        versionNumber: document.data.current?.number,
      );
}
