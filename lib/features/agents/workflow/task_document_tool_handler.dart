import 'package:lotti/features/agents/model/task_document_source.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/tools/change_effect.dart';
import 'package:uuid/uuid.dart';

/// The roles of what a document write creates, from which the
/// [ChangeEffect] derives their ids — so applying it twice creates once.
const taskDocumentEffectRole = 'task-document';
const taskDocumentVersionEffectRole = 'task-document-version';

/// Applies a `write_document_version` to task [taskId] through [source]
/// (ADR 0167): the markdown becomes the document's next version, the
/// agent's, over the version it was written against.
///
/// [effect] names a write that came from task chat, whose change item may be
/// applied more than once; the document and version it writes take ids
/// derived from it, and its key is stored as the version's provenance.
/// Without one — a task agent wake, which writes as it runs — the ids are
/// derived from a key that is unique to this call.
///
/// A refusal that applying again could only repeat — the document moved on,
/// or is gone — is [ToolExecutionResult.nonRetryable], so a chat's change
/// item is withdrawn instead of left to fail again.
Future<ToolExecutionResult> applyDocumentVersion({
  required TaskDocumentSource? source,
  required String taskId,
  required Map<String, dynamic> args,
  required ChangeEffect? effect,
}) async {
  const tool = TaskAgentToolNames.writeDocumentVersion;
  if (source == null) {
    return const ToolExecutionResult(
      success: false,
      output: 'Error: $tool is not configured.',
      errorMessage: '$tool is not configured',
    );
  }
  final markdown = args['markdown'];
  final documentId = args['documentId'];
  final newTitle = args['newTitle'];
  if (markdown is! String ||
      markdown.trim().isEmpty ||
      (documentId is! String && newTitle is! String)) {
    return const ToolExecutionResult(
      success: false,
      output:
          'Error: "markdown" and either "documentId" or "newTitle" are '
          'required.',
      errorMessage: 'Type validation failed for the document version',
      nonRetryable: true,
    );
  }
  final baseVersionId = args['baseVersionId'];
  final changeSummary = args['changeSummary'];
  final effectOrOwn =
      effect ?? ChangeEffect(key: 'document-write:${const Uuid().v4()}');

  final outcome = await source.apply(
    taskId: taskId,
    markdown: markdown,
    documentId: documentId is String ? documentId : null,
    newTitle: documentId is String ? null : newTitle as String,
    baseVersionId: baseVersionId is String ? baseVersionId : null,
    changeSummary: changeSummary is String ? changeSummary : null,
    changeEffectKey: effect?.key,
    documentUuidV5Input: effectOrOwn.entityInput(taskDocumentEffectRole),
    versionUuidV5Input: effectOrOwn.entityInput(taskDocumentVersionEffectRole),
  );
  return switch (outcome) {
    TaskDocumentApplied(:final documentId) => ToolExecutionResult(
      success: true,
      output: 'Document `$documentId` now shows this version.',
      mutatedEntityId: documentId,
    ),
    TaskDocumentApplyRefused(:final reason, :final permanent) =>
      ToolExecutionResult(
        success: false,
        output: 'Error: $reason.',
        errorMessage: 'Document version refused',
        nonRetryable: permanent,
      ),
  };
}
