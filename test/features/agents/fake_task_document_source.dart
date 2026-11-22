import 'package:lotti/features/agents/model/task_document_source.dart';

/// One call of [FakeTaskDocumentSource.apply], as it was made.
typedef TaskDocumentApplyCall = ({
  String taskId,
  String markdown,
  String documentUuidV5Input,
  String versionUuidV5Input,
  String? documentId,
  String? newTitle,
  String? baseVersionId,
  String? changeSummary,
  String? changeEffectKey,
});

/// A [TaskDocumentSource] that answers what a test sets and records what
/// the agent side asked of it.
class FakeTaskDocumentSource implements TaskDocumentSource {
  /// What [documentsOf] answers.
  List<TaskDocumentSummary> documents = const [];

  /// What [read] answers, by document id.
  Map<String, TaskDocumentText> texts = const {};

  /// What [apply] answers.
  TaskDocumentApplyOutcome applyOutcome = const TaskDocumentApplied(
    documentId: 'doc-1',
    versionId: 'version-2',
  );

  final List<TaskDocumentApplyCall> applied = [];

  @override
  Future<List<TaskDocumentSummary>> documentsOf(String taskId) async =>
      documents;

  @override
  Future<TaskDocumentText?> read({
    required String taskId,
    required String documentId,
  }) async => texts[documentId];

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
    applied.add((
      taskId: taskId,
      markdown: markdown,
      documentUuidV5Input: documentUuidV5Input,
      versionUuidV5Input: versionUuidV5Input,
      documentId: documentId,
      newTitle: newTitle,
      baseVersionId: baseVersionId,
      changeSummary: changeSummary,
      changeEffectKey: changeEffectKey,
    ));
    return applyOutcome;
  }
}
