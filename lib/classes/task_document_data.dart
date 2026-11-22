import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_document_data.freezed.dart';
part 'task_document_data.g.dart';

/// Payload of a `JournalEntity.taskDocument`: a markdown document a task
/// holds, linked to that task by an `EntryLink` (ADR 0166).
///
/// The text is not stored here. It lives in append-only
/// [TaskDocumentVersionData] rows, and this row only names the [title] and
/// the [current] version. Two concurrent versions of this row merge without
/// a conflict — see `mergeConcurrentTaskDocumentVersions`.
@freezed
abstract class TaskDocumentData with _$TaskDocumentData {
  const factory TaskDocumentData({
    /// What the document is called on the task, e.g. "Client one-pager".
    required String title,

    /// The version the document shows; null until its first version is
    /// written.
    TaskDocumentVersionRef? current,
  }) = _TaskDocumentData;

  factory TaskDocumentData.fromJson(Map<String, dynamic> json) =>
      _$TaskDocumentDataFromJson(json);
}

/// Which version a document shows, with what the merge of two concurrent
/// document rows orders by.
///
/// [number] and [createdAt] repeat fields of the version row so that a
/// merge — a pure function over two document rows — never has to read the
/// versions themselves.
@freezed
abstract class TaskDocumentVersionRef with _$TaskDocumentVersionRef {
  const factory TaskDocumentVersionRef({
    /// The id of the `JournalEntity.taskDocumentVersion` row.
    required String id,

    /// The version's number, as shown ("v3").
    required int number,

    /// When the version was written: its `meta.createdAt`.
    required DateTime createdAt,
  }) = _TaskDocumentVersionRef;

  factory TaskDocumentVersionRef.fromJson(Map<String, dynamic> json) =>
      _$TaskDocumentVersionRefFromJson(json);
}

/// Who wrote a version.
enum TaskDocumentAuthor {
  /// Written by the user: a hand edit, or a restore of an older version.
  user,

  /// Drafted by the task's agent and confirmed by the user.
  agent,
}

/// Payload of a `JournalEntity.taskDocumentVersion`: the full text of one
/// version of a document. Written once and never changed (ADR 0166), so two
/// devices can never conflict over it.
@freezed
abstract class TaskDocumentVersionData with _$TaskDocumentVersionData {
  const factory TaskDocumentVersionData({
    /// The `JournalEntity.taskDocument` this is a version of. Stored as the
    /// row's subtype, so a document's versions are an indexed lookup.
    required String documentId,

    /// One more than the version it was written over. Two devices writing
    /// over the same version at once both get the same number; the merge
    /// still orders them (see [TaskDocumentVersionRef]).
    required int number,

    /// The document's full text, as markdown.
    required String markdown,

    @JsonKey(unknownEnumValue: TaskDocumentAuthor.user)
    required TaskDocumentAuthor author,

    /// The version this one was written over; null for a first version.
    String? baseVersionId,

    /// What changed, in a sentence: the agent's summary of its proposal, or
    /// empty for a hand edit.
    String? changeSummary,

    /// For an agent version, the change set and item it was confirmed from:
    /// its provenance.
    String? changeSetId,
    String? changeItemId,

    /// For a restore, the older version whose text this repeats.
    String? restoredFromVersionId,
  }) = _TaskDocumentVersionData;

  factory TaskDocumentVersionData.fromJson(Map<String, dynamic> json) =>
      _$TaskDocumentVersionDataFromJson(json);
}
