part of 'database.dart';

/// Task document query surface for [JournalDb] (ADR 0167): a document's
/// versions, resolved through the denormalized `subtype` column, which
/// carries the owning document id for `TaskDocumentVersion` rows — the goal
/// snapshot precedent, served by `idx_journal_type_subtype`.
mixin _JournalDbTaskDocumentQueries on _$JournalDb {
  /// Every live version of document [documentId], newest first by
  /// [compareTaskDocumentVersionRefs] — the order the merge picks the
  /// current version by, so the first row is the one a merged document
  /// shows when its versions all synced.
  ///
  /// Not private-filtered: a version is only ever read through its
  /// document, which the private filter has already let through.
  Future<List<TaskDocumentVersionEntry>> getTaskDocumentVersions(
    String documentId,
  ) async {
    final rows =
        await (select(journal)..where(
              (t) =>
                  t.type.equals('TaskDocumentVersion') &
                  t.subtype.equals(documentId) &
                  t.deleted.equals(false),
            ))
            .get();
    return rows.map(fromDbEntity).whereType<TaskDocumentVersionEntry>().toList()
      ..sort((a, b) => compareTaskDocumentVersionRefs(b.ref, a.ref));
  }
}
