import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/providers/service_providers.dart';

/// The journal `type`s a person's timeline holds through a [RelationshipLink]
/// besides their check-ins and tasks: notes, voice notes, photos and
/// meetings (ADR 0138).
///
/// Check-ins are not resolved through this set — they are read through the
/// indexed `subtype` column, as everywhere in the feature — and tasks keep
/// their own read, so a timeline read never deserializes either.
const personTimelineEntryTypes = {
  'JournalEntry',
  'JournalAudio',
  'JournalImage',
  'JournalEvent',
};

/// The live [RelationshipLink]s from [personId] to anything, read from
/// `linked_entries` — the link rows that make an entry part of the person's
/// timeline. A `BasicLink` from the person is deliberately not one: it
/// carries the avatar and banner pictures and dictation takes, none of which
/// the user put on the timeline.
Future<Set<String>> personTimelineLinkTargets(
  JournalDb journalDb,
  String personId,
) async {
  final links = await journalDb.typedLinksForTaskIds(
    {personId},
    types: {entryLinkTypeDbName(EntryLinkType.relationship)},
  );
  return {
    for (final link in links)
      if (link.fromId == personId &&
          link.deletedAt == null &&
          link.hidden != true)
        link.toId,
  };
}

/// Every live note, voice note, photo and meeting on [personId]'s timeline,
/// private ones included — the agent's and the delete cascade's read, which
/// a display preference must never scope (the reason
/// `getAllCheckInsForRelationship` is unfiltered).
Future<List<JournalEntity>> allPersonTimelineEntries(
  JournalDb journalDb,
  String personId,
) async {
  final ids = await personTimelineLinkTargets(journalDb, personId);
  if (ids.isEmpty) return const [];
  final rows = await journalDb
      .journalEntitiesByIdsUnorderedAllPrivate(ids.toList(growable: false))
      .get();
  return [
    for (final row in rows)
      if (personTimelineEntryTypes.contains(row.type) && !row.deleted)
        fromDbEntity(row),
  ];
}

/// Soft-deletes every live [RelationshipLink] between [personId] and
/// [otherId], in either direction, leaving other link types intact. Each
/// tombstone goes through [JournalRepository.updateLink], so it receives a
/// new vector clock, enters the sync outbox and notifies both endpoints.
/// Returns whether a link was found and every tombstone was written.
Future<bool> tombstoneRelationshipLinks({
  required JournalDb journalDb,
  required JournalRepository journalRepository,
  required String personId,
  required String otherId,
}) async {
  final links = await journalDb.typedLinksForTaskIds(
    {personId, otherId},
    types: {entryLinkTypeDbName(EntryLinkType.relationship)},
  );
  final matching = links.where(
    (link) =>
        link.deletedAt == null &&
        ((link.fromId == personId && link.toId == otherId) ||
            (link.fromId == otherId && link.toId == personId)),
  );
  final deletedAt = clock.now();
  var found = false;
  var updated = true;
  for (final link in matching) {
    found = true;
    updated =
        await journalRepository.updateLink(
          link.copyWith(deletedAt: deletedAt, hidden: true),
        ) &&
        updated;
  }
  return found && updated;
}

/// Reads and writes what sits on a person's timeline besides check-ins and
/// tasks: notes about them, voice notes, photos and meetings (ADR 0138).
///
/// An entry is on the timeline when a [RelationshipLink] runs from the person
/// to it. Every entry written here inherits the person's category and
/// privacy, like a check-in does.
class PersonTimelineRepository {
  PersonTimelineRepository({
    required this._journalDb,
    required this._journalRepository,
    required this._persistenceLogic,
  });

  final JournalDb _journalDb;
  final JournalRepository _journalRepository;
  final PersistenceLogic _persistenceLogic;

  /// The live notes, voice notes, photos and meetings on [personId]'s
  /// timeline, in no particular order — the timeline builder sorts. Respects
  /// the private-entry filter: this is a display read.
  Future<List<JournalEntity>> getTimelineEntries(String personId) async {
    final ids = await personTimelineLinkTargets(_journalDb, personId);
    return _journalDb.getLiveEntitiesOfTypesByIds(
      ids,
      types: personTimelineEntryTypes,
    );
  }

  /// Puts [entryId] on [personId]'s timeline. The link write notifies both
  /// endpoints, so the person's page reloads without a manual notification.
  Future<bool> addToTimeline({
    required String personId,
    required String entryId,
  }) {
    return _persistenceLogic.createLink(
      fromId: personId,
      toId: entryId,
      linkType: EntryLinkType.relationship,
    );
  }

  /// Takes [entryId] off [personId]'s timeline without deleting it.
  Future<bool> removeFromTimeline({
    required String personId,
    required String entryId,
  }) {
    return tombstoneRelationshipLinks(
      journalDb: _journalDb,
      journalRepository: _journalRepository,
      personId: personId,
      otherId: entryId,
    );
  }

  /// Writes a note about [person] — background, where you met, a gift idea —
  /// and puts it on their timeline. A [pinned] note is starred, which is
  /// what places it under the person's *About*. Returns null when nothing
  /// was written; a note whose timeline link fails is removed again, so no
  /// note about a person is left where the person's page cannot reach it.
  Future<JournalEntry?> createNote({
    required RelationshipEntry person,
    required String text,
    bool pinned = false,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final note = JournalEntity.journalEntry(
      entryText: EntryText(plainText: trimmed),
      meta: await _persistenceLogic.createMetadata(
        dateFrom: clock.now(),
        categoryId: person.meta.categoryId,
        private: person.meta.private,
        starred: pinned,
      ),
    );
    if (!(await _persistenceLogic.createDbEntity(note) ?? false)) return null;
    final written = note as JournalEntry;
    if (await addToTimeline(personId: person.meta.id, entryId: note.meta.id)) {
      return written;
    }
    await deleteNote(written);
    return null;
  }

  /// Pins [note] under the person's *About*, or unpins it.
  Future<bool> setPinned(JournalEntry note, {required bool pinned}) =>
      updateNote(
        note,
        text: note.entryText?.plainText ?? '',
        pinned: pinned,
      );

  /// Saves new words for [note], and whether it is pinned. Blank words are
  /// refused: a note emptied in its sheet is deleted there, not saved blank.
  Future<bool> updateNote(
    JournalEntry note, {
    required String text,
    required bool pinned,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final result = await _persistenceLogic.updateDbEntity(
      note.copyWith(
        entryText: EntryText(plainText: trimmed),
        meta: await _persistenceLogic.updateMetadata(
          note.meta.copyWith(starred: pinned),
        ),
      ),
    );
    return result ?? false;
  }

  /// Deletes [note]. Its timeline link is left to the generic delete model,
  /// whose readers already skip a deleted target.
  Future<bool> deleteNote(JournalEntry note) async {
    final result = await _persistenceLogic.updateDbEntity(
      note.copyWith(
        meta: await _persistenceLogic.updateMetadata(
          note.meta,
          deletedAt: clock.now(),
        ),
      ),
    );
    return result ?? false;
  }
}

final personTimelineRepositoryProvider = Provider<PersonTimelineRepository>(
  (ref) => PersonTimelineRepository(
    journalDb: ref.read(journalDbProvider),
    journalRepository: ref.watch(journalRepositoryProvider),
    persistenceLogic: ref.read(persistenceLogicProvider),
  ),
  name: 'personTimelineRepositoryProvider',
);
