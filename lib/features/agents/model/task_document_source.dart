/// One document of a task as the task agent sees it: which one, what it is
/// called, and which version it shows — not its text, which is read on
/// request ([TaskDocumentSource.read], ADR 0167 decision 7).
class TaskDocumentSummary {
  const TaskDocumentSummary({
    required this.id,
    required this.title,
    this.versionId,
    this.versionNumber,
  });

  final String id;
  final String title;

  /// The version the document shows; both null before its first one.
  final String? versionId;
  final int? versionNumber;
}

/// The text of the version a document shows, with what identifies it.
class TaskDocumentText {
  const TaskDocumentText({
    required this.summary,
    required this.markdown,
  });

  final TaskDocumentSummary summary;

  /// Empty for a document with no version yet.
  final String markdown;
}

/// What applying a confirmed document proposal came to.
sealed class TaskDocumentApplyOutcome {
  const TaskDocumentApplyOutcome();
}

/// The proposed text is the document's current version: written now, or
/// already, by an earlier application of the same confirmation.
class TaskDocumentApplied extends TaskDocumentApplyOutcome {
  const TaskDocumentApplied({
    required this.documentId,
    required this.versionId,
  });

  final String documentId;
  final String versionId;
}

/// Nothing was written. [permanent] when applying again could only fail the
/// same way — the document moved on past the version the proposal was
/// drafted against, or was deleted — so the proposal is withdrawn rather
/// than left for another try.
class TaskDocumentApplyRefused extends TaskDocumentApplyOutcome {
  const TaskDocumentApplyRefused({
    required this.reason,
    required this.permanent,
  });

  /// For the model and the log, in English.
  final String reason;
  final bool permanent;
}

/// A task's documents, for the task agent: what it may read during a wake,
/// and where a document proposal the user confirmed is written.
///
/// The port the task agent depends on; the documents feature, which ranks
/// above agents, implements it, and the composition root wires it. Unwired,
/// the agent is never offered the document tools.
abstract interface class TaskDocumentSource {
  /// The live documents of [taskId], oldest first.
  Future<List<TaskDocumentSummary>> documentsOf(String taskId);

  /// The current text of document [documentId] of [taskId]; null when the
  /// task holds no such document.
  Future<TaskDocumentText?> read({
    required String taskId,
    required String documentId,
  });

  /// Writes [markdown] as the next version of document [documentId] of
  /// [taskId] — or, with [newTitle] instead, creates a document with it as
  /// the first version — as the agent's, confirmed by the user.
  ///
  /// The version is written over [baseVersionId], the one the proposal was
  /// drafted against, and only while the document still shows it. The two
  /// inputs derive the ids of what this creates, so applying the same
  /// confirmation twice writes once ([TaskDocumentApplied] either way).
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
  });
}
