import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/pull_request_data.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/github/domain/distinct_pull_requests.dart';
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

  /// The live pull requests linked from [taskId], one per pull request
  /// ([distinctPullRequests]), newest first.
  Future<List<PullRequestEntry>> forTask(String taskId) async =>
      distinctPullRequests(await _linked(taskId));

  Future<Iterable<PullRequestEntry>> _linked(String taskId) async =>
      (await _db.getLinkedEntities(taskId)).whereType<PullRequestEntry>();

  /// Entry [entryId] as stored now, or null once it is unlinked.
  Future<PullRequestEntry?> liveEntry(String entryId) async {
    final entry = await _db.journalEntityById(entryId);
    return entry is PullRequestEntry ? entry : null;
  }

  /// The tasks that hold each of [refs], by [PullRequestRef.key]; a pull
  /// request no task holds is absent. A pull request belongs to one task, so
  /// more than one holder means two devices linked it before they synced.
  Future<Map<String, Set<String>>> holdersOf(
    Iterable<PullRequestRef> refs,
  ) async {
    final keys = {for (final ref in refs) ref.key};
    if (keys.isEmpty) return const {};
    final rows = await _db.pullRequestAssignments(keys.toList()).get();
    final holders = <String, Set<String>>{};
    for (final row in rows) {
      final key = row.prKey;
      if (key != null) (holders[key] ??= {}).add(row.taskId);
    }
    return holders;
  }

  /// Links [ref] to [taskId] with what the link's first read observed —
  /// unless a task holds it already, this one or another.
  ///
  /// The check and the creation run as one step on this device (`Choose`
  /// in `specs/tla/PullRequestAssignment.tla`): the picker's list can be
  /// stale by the time the user picks, a paste lists nothing at all, and two
  /// pickers open at once must not both link. Another device can still link
  /// it to another task before the two sync; then both entries stay, and
  /// every device shows the double assignment.
  Future<PullRequestLinkAttempt> link({
    required String taskId,
    required PullRequestRef ref,
    PullRequestSnapshot? snapshot,
  }) => _serially(() async {
    final holders = (await holdersOf([ref]))[ref.key] ?? const <String>{};
    if (holders.isNotEmpty) return PullRequestLinkAttempt(heldBy: holders);

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
    return PullRequestLinkAttempt(linked: (created ?? false) ? entry : null);
  });

  /// One link at a time on this device, whichever repository instance asks.
  static Future<void> _tail = Future.value();

  static Future<T> _serially<T>(Future<T> Function() body) {
    final result = _tail.then((_) => body());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
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

  /// Unlinks pull request [ref] from [taskId]: every live entry of it is
  /// deleted like any other entry, including a duplicate another device
  /// created before the two synced, which would otherwise reappear.
  Future<bool> unlink({
    required String taskId,
    required PullRequestRef ref,
  }) async {
    var unlinked = false;
    for (final entry in await _linked(taskId)) {
      if (!entry.isDeleted && entry.data.key == ref.key) {
        unlinked = await _journal.deleteJournalEntity(entry.id) || unlinked;
      }
    }
    return unlinked;
  }
}

/// What [PullRequestRepository.link] did: [linked] is the new entry, or
/// [heldBy] names the tasks that hold the pull request already. Neither when
/// the creation itself failed.
class PullRequestLinkAttempt {
  const PullRequestLinkAttempt({this.linked, this.heldBy = const {}});

  final PullRequestEntry? linked;
  final Set<String> heldBy;
}
