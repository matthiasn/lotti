import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task_document_data.dart';
import 'package:lotti/classes/vector_clock.dart';

/// The ref a document stores to show a version.
extension TaskDocumentVersionEntryRef on TaskDocumentVersionEntry {
  /// This version as a [TaskDocumentVersionRef]: its id, number and
  /// creation time, what [compareTaskDocumentVersionRefs] orders by.
  TaskDocumentVersionRef get ref => TaskDocumentVersionRef(
    id: meta.id,
    number: data.number,
    createdAt: meta.createdAt,
  );
}

/// Orders two version refs; positive when [a] is the newer version.
///
/// By [TaskDocumentVersionRef.number] first, then by when the version was
/// written, then by id. The id makes the order total: two devices that both
/// write over v3 at once each produce a v4, and every device must still pick
/// the same one. No version (`null`) is older than any.
int compareTaskDocumentVersionRefs(
  TaskDocumentVersionRef? a,
  TaskDocumentVersionRef? b,
) {
  if (a == null || b == null) {
    return (a == null ? 0 : 1) - (b == null ? 0 : 1);
  }
  final byNumber = a.number.compareTo(b.number);
  if (byNumber != 0) return byNumber;
  final byTime = a.createdAt.compareTo(b.createdAt);
  if (byTime != 0) return byTime;
  return a.id.compareTo(b.id);
}

/// The row every device writes for two concurrent versions of one task
/// document, whichever it held first (ADR 0167).
///
/// - The document shows the newer of the two current versions
///   ([compareTaskDocumentVersionRefs]). The other version keeps its own
///   row, so nothing is lost: it stays in the document's history.
/// - The title, and the rest of the row, come from the later edit by
///   `meta.updatedAt`, ties broken by the clock's canonical key.
/// - A deletion on either side survives: deleting is the user's explicit
///   act, and the versions remain as rows.
/// - The clock is the join of both.
///
/// Both orders of the arguments give the same row, so a merge needs no
/// message back. Two deletions are not handed here: the journal merges those
/// for every entry type.
TaskDocumentEntry mergeConcurrentTaskDocumentVersions(
  TaskDocumentEntry a,
  TaskDocumentEntry b,
) {
  final later = _laterEdit(a, b);
  final current =
      compareTaskDocumentVersionRefs(a.data.current, b.data.current) >= 0
      ? a.data.current
      : b.data.current;
  return later.copyWith(
    meta: later.meta.copyWith(
      deletedAt: later.meta.deletedAt ?? a.meta.deletedAt ?? b.meta.deletedAt,
      vectorClock: VectorClock.merge(a.meta.vectorClock, b.meta.vectorClock),
    ),
    data: later.data.copyWith(current: current),
  );
}

/// The row every device writes for two concurrent copies of one task
/// document version (ADR 0167): the same chat write applied on two
/// devices before either synced, both deriving the version's id from it.
///
/// A version's text never changes, so the copies differ only in when each
/// device wrote it, and in deletion: a device whose document moved on while
/// it wrote deletes its copy again. The live copy wins over a deleted one,
/// since the merged document may show that version — at worst a version the
/// document never showed stays in its history. Otherwise the later write by
/// `meta.updatedAt` wins, ties broken by the clock's canonical key. The clock
/// is the join of both.
///
/// Both orders of the arguments give the same row. Two deletions are not
/// handed here: the journal merges those for every entry type.
TaskDocumentVersionEntry mergeConcurrentTaskDocumentVersionRows(
  TaskDocumentVersionEntry a,
  TaskDocumentVersionEntry b,
) {
  final kept = a.isDeleted == b.isDeleted
      ? _laterEdit(a, b)
      : (a.isDeleted ? b : a);
  return kept.copyWith(
    meta: kept.meta.copyWith(
      vectorClock: VectorClock.merge(a.meta.vectorClock, b.meta.vectorClock),
    ),
  );
}

T _laterEdit<T extends JournalEntity>(T a, T b) {
  final byTime = a.meta.updatedAt.compareTo(b.meta.updatedAt);
  if (byTime != 0) return byTime > 0 ? a : b;
  return _clockKey(a).compareTo(_clockKey(b)) >= 0 ? a : b;
}

String _clockKey(JournalEntity e) => e.meta.vectorClock?.canonicalKey ?? '';
