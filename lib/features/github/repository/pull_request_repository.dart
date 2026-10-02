import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/github/domain/pull_request_ref.dart';
import 'package:lotti/features/github/domain/pull_request_write_rule.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/write_on_stored.dart';
import 'package:uuid/uuid.dart';

/// The pull request entries of tasks: linking, unlinking, and storing what
/// a refresh observed.
class PullRequestRepository {
  PullRequestRepository({
    required JournalDb journalDb,
    required PersistenceLogic persistenceLogic,
    required JournalRepository journalRepository,
  }) : _db = journalDb,
       _persistence = persistenceLogic,
       _journal = journalRepository;

  final JournalDb _db;
  final PersistenceLogic _persistence;
  final JournalRepository _journal;

  /// The live pull requests linked from [taskId], oldest number first.
  Future<List<PullRequestEntry>> forTask(String taskId) async {
    final linked = await _db.getLinkedEntities(taskId);
    return linked
        .whereType<PullRequestEntry>()
        .where((e) => !e.isDeleted)
        .toList()
      ..sort((a, b) => a.data.number.compareTo(b.data.number));
  }

  /// Whether [ref] is already linked to [taskId].
  Future<bool> isLinked({
    required String taskId,
    required PullRequestRef ref,
  }) async => (await forTask(taskId)).any((e) => e.data.key == ref.key);

  /// Links [ref] to [taskId] with what the link's first read observed.
  ///
  /// Returns null when [ref] is already linked to the task: one entry per
  /// task and pull request.
  Future<PullRequestEntry?> link({
    required String taskId,
    required PullRequestRef ref,
    PullRequestSnapshot? snapshot,
  }) async {
    if (await isLinked(taskId: taskId, ref: ref)) return null;

    final now = clock.now();
    final entry = PullRequestEntry(
      meta: Metadata(
        id: const Uuid().v1(),
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: PullRequestData(
        owner: ref.owner,
        repo: ref.repo,
        number: ref.number,
        snapshot: snapshot,
      ),
    );
    final created = await _persistence.createDbEntity(
      entry,
      linkedId: taskId,
      shouldAddGeolocation: false,
    );
    return (created ?? false) ? entry : null;
  }

  /// Stores [observation] on entry [entryId] if it should replace what is
  /// stored ([shouldWritePullRequestObservation]); returns whether it did.
  ///
  /// The write is built on the stored row and applies only while that row
  /// is still stored ([writeOnStored]): a version that synced in meanwhile
  /// is decided again, so an older observation never replaces a newer one,
  /// and an unlinked entry, which [writeOnStored] does not read, is never
  /// written (`Persist` in `specs/tla/PullRequestSnapshot.tla`).
  Future<bool> persistObservation(
    String entryId,
    PullRequestSnapshot observation,
  ) async {
    var written = false;
    final stored = await writeOnStored(
      journalDb: _db,
      persistenceLogic: _persistence,
      id: entryId,
      build: (stored) async {
        written = false;
        if (stored is! PullRequestEntry ||
            !shouldWritePullRequestObservation(stored, observation)) {
          return null;
        }
        written = true;
        return stored.copyWith(
          meta: await _persistence.updateMetadata(stored.meta),
          data: stored.data.copyWith(snapshot: observation),
        );
      },
    );
    return stored && written;
  }

  /// Unlinks the pull request: the entry is deleted like any other.
  Future<bool> unlink(String entryId) => _journal.deleteJournalEntity(entryId);
}
