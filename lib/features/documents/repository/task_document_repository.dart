import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task_document_data.dart';
import 'package:lotti/classes/task_document_merge.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/logic/services/metadata_service.dart';
import 'package:lotti/logic/write_on_stored.dart';

/// The live documents among [linked], oldest first (ties by id), so a new
/// document joins the end of its task's section and none moves.
List<TaskDocumentEntry> liveTaskDocuments(Iterable<JournalEntity> linked) =>
    linked
        .whereType<TaskDocumentEntry>()
        .where((document) => !document.isDeleted)
        .toList()
      ..sort((a, b) {
        final byCreation = a.meta.createdAt.compareTo(b.meta.createdAt);
        return byCreation != 0 ? byCreation : a.id.compareTo(b.id);
      });

/// What [TaskDocumentRepository.writeVersion] came to.
enum TaskDocumentWriteStatus {
  /// The version is stored and the document shows it.
  written,

  /// The document no longer shows the version the write was based on: it
  /// moved on meanwhile, here or on another device. Nothing was changed.
  stale,

  /// There is no such live document.
  missing,

  /// Storing failed. Nothing was changed.
  failed,
}

/// The outcome of [TaskDocumentRepository.writeVersion], with the new
/// `version` when `status` is [TaskDocumentWriteStatus.written].
typedef TaskDocumentWriteResult = ({
  TaskDocumentWriteStatus status,
  TaskDocumentVersionEntry? version,
});

/// The documents of tasks (ADR 0167): creating them, writing their
/// versions, restoring, renaming and deleting.
///
/// A document is a [TaskDocumentEntry] linked from its task; its text lives
/// in append-only [TaskDocumentVersionEntry] rows, and the document only
/// names which one it shows. A write here is the user's own or the agent's,
/// each recorded as such; the agent's lands without a confirmation, over the
/// version it read, and the user goes back through the history.
class TaskDocumentRepository {
  TaskDocumentRepository({
    required JournalDb journalDb,
    required PersistenceLogic persistenceLogic,
    required JournalRepository journalRepository,
  }) : _db = journalDb,
       _persistence = persistenceLogic,
       _journal = journalRepository;

  final JournalDb _db;
  final PersistenceLogic _persistence;
  final JournalRepository _journal;

  /// The live documents linked from task [taskId], oldest first, so a new
  /// document joins the end of the task's section and none moves.
  Future<List<TaskDocumentEntry>> forTask(String taskId) async =>
      liveTaskDocuments(await _db.getLinkedEntities(taskId));

  /// Document [documentId] as stored now, or null once it is deleted.
  Future<TaskDocumentEntry?> document(String documentId) async {
    final entry = await _db.journalEntityById(documentId);
    return entry is TaskDocumentEntry ? entry : null;
  }

  /// Every live version of document [documentId], newest first.
  Future<List<TaskDocumentVersionEntry>> versions(String documentId) =>
      _db.getTaskDocumentVersions(documentId);

  /// The version [document] shows, or null before its first one.
  Future<TaskDocumentVersionEntry?> currentVersion(
    TaskDocumentEntry document,
  ) async {
    final currentId = document.data.current?.id;
    return currentId == null ? null : version(currentId);
  }

  /// Version [versionId], or null when there is no such version — the
  /// version another was written over, which need not be the one the
  /// document shows now.
  Future<TaskDocumentVersionEntry?> version(String versionId) async {
    final entry = await _db.journalEntityById(versionId);
    return entry is TaskDocumentVersionEntry ? entry : null;
  }

  /// Creates a document titled [title] on task [taskId], with no version
  /// yet, and returns it; null when the task does not exist or storing
  /// failed.
  ///
  /// The document takes the task's category and private flag, so it syncs,
  /// filters and hides with the task that holds it.
  ///
  /// [uuidV5Input] derives the document's id, for a creation that must
  /// happen once however often it is applied — a write from task chat
  /// (ADR 0075). The document that id names is returned when it is there
  /// already, and nothing is created; null when it was deleted since.
  Future<TaskDocumentEntry?> create({
    required String taskId,
    required String title,
    String? uuidV5Input,
  }) async {
    if (uuidV5Input != null) {
      final existing = await _byDerivedId(uuidV5Input);
      if (existing != null) {
        return existing is TaskDocumentEntry && !existing.isDeleted
            ? existing
            : null;
      }
    }
    final task = await _db.journalEntityById(taskId);
    if (task is! Task) return null;
    final meta = await _persistence.createMetadata(
      categoryId: task.meta.categoryId,
      private: task.meta.private,
      uuidV5Input: uuidV5Input,
    );
    final document = TaskDocumentEntry(
      meta: meta,
      data: TaskDocumentData(title: title),
    );
    final created = await _persistence.createDbEntity(
      document,
      linkedId: taskId,
      shouldAddGeolocation: false,
    );
    return (created ?? false) ? document : null;
  }

  /// Writes [markdown] as the next version of document [documentId] and
  /// makes the document show it — but only while the document still shows
  /// [baseVersionId], the version the text was written over (null for a
  /// first version).
  ///
  /// This is the compare-and-set ADR 0167 relies on: a hand edit opened on
  /// v3, or an agent version drafted against v3, never replaces a v4 that
  /// landed meanwhile. A base that no longer matches comes back
  /// [TaskDocumentWriteStatus.stale], with nothing changed. When the
  /// document moves on between storing the version row and pointing the
  /// document at it, the row is deleted again, so a version the document
  /// never showed does not linger in its history.
  ///
  /// [author] and the provenance fields are stored on the version as given.
  ///
  /// [uuidV5Input] derives the version's id, so a write from task chat applied
  /// twice — on two devices, or again after a crash — writes one version
  /// (ADR 0075). When the version that id names is there already, the
  /// effect happened, and it comes back [TaskDocumentWriteStatus.written]
  /// with nothing written. When it is there deleted, an earlier attempt
  /// found the document moved on and took its version back: it comes back
  /// [TaskDocumentWriteStatus.stale], as that attempt did.
  Future<TaskDocumentWriteResult> writeVersion({
    required String documentId,
    required String markdown,
    required TaskDocumentAuthor author,
    required String? baseVersionId,
    String? changeSummary,
    String? changeEffectKey,
    String? restoredFromVersionId,
    String? uuidV5Input,
  }) async {
    if (uuidV5Input != null) {
      final existing = await _byDerivedId(uuidV5Input);
      if (existing is TaskDocumentVersionEntry) {
        return existing.isDeleted
            ? _result(TaskDocumentWriteStatus.stale)
            : (status: TaskDocumentWriteStatus.written, version: existing);
      }
    }
    final stored = await document(documentId);
    if (stored == null) return _result(TaskDocumentWriteStatus.missing);
    if (stored.data.current?.id != baseVersionId) {
      return _result(TaskDocumentWriteStatus.stale);
    }

    final meta = await _persistence.createMetadata(
      categoryId: stored.meta.categoryId,
      private: stored.meta.private,
      uuidV5Input: uuidV5Input,
    );
    final version = TaskDocumentVersionEntry(
      meta: meta,
      data: TaskDocumentVersionData(
        documentId: documentId,
        number: (stored.data.current?.number ?? 0) + 1,
        markdown: markdown,
        author: author,
        baseVersionId: baseVersionId,
        changeSummary: changeSummary,
        changeEffectKey: changeEffectKey,
        restoredFromVersionId: restoredFromVersionId,
      ),
    );
    final created = await _persistence.createDbEntity(
      version,
      shouldAddGeolocation: false,
    );
    if (!(created ?? false)) return _result(TaskDocumentWriteStatus.failed);

    var movedOn = false;
    final pointed = await writeOnStored(
      journalDb: _db,
      persistenceLogic: _persistence,
      id: documentId,
      // Rebuilt on every version stored meanwhile, so the flag is set on
      // each pass and reflects the last one.
      build: (current) async {
        if (current is! TaskDocumentEntry ||
            current.data.current?.id != baseVersionId) {
          movedOn = true;
          return null;
        }
        movedOn = false;
        return current.copyWith(
          meta: await _persistence.updateMetadata(current.meta),
          data: current.data.copyWith(current: version.ref),
        );
      },
    );

    if (pointed && !movedOn) {
      return (status: TaskDocumentWriteStatus.written, version: version);
    }
    await _journal.deleteJournalEntity(version.id);
    if (movedOn) return _result(TaskDocumentWriteStatus.stale);
    return _result(
      await document(documentId) == null
          ? TaskDocumentWriteStatus.missing
          : TaskDocumentWriteStatus.failed,
    );
  }

  /// Writes the text of older version [versionId] as the next version of
  /// its document, written by the user — the restore keeps history whole
  /// instead of moving the document back. [baseVersionId] is the version
  /// the document showed when the user chose to restore, as for
  /// [writeVersion].
  Future<TaskDocumentWriteResult> restore({
    required String versionId,
    required String? baseVersionId,
  }) async {
    final older = await _db.journalEntityById(versionId);
    if (older is! TaskDocumentVersionEntry) {
      return _result(TaskDocumentWriteStatus.missing);
    }
    return writeVersion(
      documentId: older.data.documentId,
      markdown: older.data.markdown,
      author: TaskDocumentAuthor.user,
      baseVersionId: baseVersionId,
      restoredFromVersionId: older.id,
    );
  }

  /// Renames document [documentId] to [title]; returns whether the document
  /// is stored under that title afterwards. Built on the stored row, so a
  /// version written meanwhile is kept.
  Future<bool> rename(String documentId, String title) async {
    var found = true;
    final stored = await writeOnStored(
      journalDb: _db,
      persistenceLogic: _persistence,
      id: documentId,
      build: (current) async {
        found = current is TaskDocumentEntry;
        if (current is! TaskDocumentEntry || current.data.title == title) {
          return null;
        }
        return current.copyWith(
          meta: await _persistence.updateMetadata(current.meta),
          data: current.data.copyWith(title: title),
        );
      },
    );
    return stored && found;
  }

  /// Deletes document [documentId] and every version of it, like any other
  /// entry, so the deletion syncs; returns whether the document was deleted.
  /// Nothing reaches a version once its document is gone, so none is kept.
  Future<bool> delete(String documentId) async {
    for (final version in await versions(documentId)) {
      await _journal.deleteJournalEntity(version.id);
    }
    return _journal.deleteJournalEntity(documentId);
  }

  /// The entity the id derived from [uuidV5Input] names, deleted or not.
  Future<JournalEntity?> _byDerivedId(String uuidV5Input) async {
    final id = MetadataService.deterministicId(uuidV5Input);
    return (await _db.journalEntityMapForIdsIncludingDeleted([id]))[id];
  }

  static TaskDocumentWriteResult _result(TaskDocumentWriteStatus status) =>
      (status: status, version: null);
}
