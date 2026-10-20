import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/providers/service_providers.dart';

/// What [PersonTimelineRepository.getRecordingSummaries] answers: each
/// recording's leading line by recording id, and the ids of the summaries
/// those lines came from.
typedef RecordingSummaries = ({
  Map<String, String> oneLiners,
  Set<String> summaryIds,
});

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

/// When [personId]'s timeline last changed shape — the newest write to a
/// [RelationshipLink] from the person, a tombstone included — or null when
/// there is none. Adding an older note, or taking an entry off, changes what
/// the briefing reads without touching any entry's own `updatedAt`, so the
/// agent counts this as evidence too.
Future<DateTime?> personTimelineLinksChangedAt(
  JournalDb journalDb,
  String personId,
) async {
  // Removed links included: a tombstone's write is when the entry left.
  final links = await journalDb.linksForEntryIdsBidirectionalIncludingRemoved(
    {personId},
  );
  DateTime? newest;
  for (final link in links) {
    if (link is! RelationshipLink || link.fromId != personId) continue;
    if (newest == null || link.updatedAt.isAfter(newest)) {
      newest = link.updatedAt;
    }
  }
  return newest;
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

  static const RecordingSummaries _noSummaries = (
    oneLiners: <String, String>{},
    summaryIds: <String>{},
  );

  /// The one line each recording in [audioIds] leads with on the page: the
  /// `oneLiner` of its newest audio summary, for the recordings that have
  /// one — and the ids of the summaries read, for the detail to watch.
  ///
  /// Read with the person's detail, in two bulk reads, rather than by each
  /// row once it is on screen: a row that fetched its own line first showed
  /// three lines of transcript and then shrank, and under a lazy list rows
  /// do that every time they scroll back into view — the history drifted
  /// under the reader. With the line in the detail, a row is its data.
  Future<RecordingSummaries> getRecordingSummaries(Set<String> audioIds) async {
    if (audioIds.isEmpty) return _noSummaries;
    final links =
        (await _journalDb.linksFromIds(audioIds.toList(growable: false)).get())
            .map(entryLinkFromLinkedDbEntry)
            .whereType<BasicLink>()
            .where((link) => link.hidden != true)
            .toList(growable: false);
    if (links.isEmpty) return _noSummaries;
    final rows = await _journalDb.journalEntitiesByIdsUnorderedAllPrivate([
      for (final link in links) link.toId,
    ]).get();
    final summaries = <String, AiResponseEntry>{
      for (final row in rows)
        if (fromDbEntity(row) case final AiResponseEntry summary
            when summary.data.type == AiResponseType.audioSummary &&
                summary.meta.deletedAt == null)
          summary.id: summary,
    };
    // Newest wins, as everywhere a summary is read: a recording summarized
    // again keeps the earlier one, and the row leads with the latest.
    final newest = <String, AiResponseEntry>{};
    for (final link in links) {
      final summary = summaries[link.toId];
      if (summary == null) continue;
      final current = newest[link.fromId];
      if (current == null ||
          summary.meta.dateFrom.isAfter(current.meta.dateFrom)) {
        newest[link.fromId] = summary;
      }
    }
    return (
      oneLiners: {
        for (final MapEntry(key: audioId, value: summary) in newest.entries)
          if (summary.data.oneLiner?.trim() case final line?
              when line.isNotEmpty)
            audioId: line,
      },
      summaryIds: {for (final summary in newest.values) summary.id},
    );
  }

  /// Saves [summary] as recording [audioId]'s audio summary, written by
  /// [modelId]: the line its timeline row — a voice note's, or that of the
  /// check-in holding it — leads with. It is an ordinary
  /// audio summary — linked from the recording, so it shares its privacy and
  /// sits where every reader of a recording's summary looks, newest first.
  /// Answers whether it was written.
  Future<bool> saveRecordingSummary({
    required String audioId,
    required String summary,
    required String modelId,
    String? categoryId,
  }) async {
    final created = await _persistenceLogic.createAiResponseEntry(
      data: AiResponseData(
        model: modelId,
        systemMessage: '',
        prompt: '',
        thoughts: '',
        response: summary,
        oneLiner: summary,
        type: AiResponseType.audioSummary,
      ),
      linkedId: audioId,
      categoryId: categoryId,
    );
    return created != null;
  }

  /// Whether [entryId] is on [personId]'s timeline: a live
  /// [RelationshipLink] runs from the person to it.
  Future<bool> isOnTimeline({
    required String personId,
    required String entryId,
  }) async =>
      (await personTimelineLinkTargets(_journalDb, personId)).contains(entryId);

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
    final written = await _writeOnTimeline(person, note);
    return written is JournalEntry ? written : null;
  }

  /// Plans a meeting with [person]: a planned event titled [title] from
  /// [start] for [duration], on their timeline. Like any event with a span
  /// it lands on the Daily OS Day view, and because it is linked from a
  /// person it does so whether or not the Events feature is on. Returns null
  /// when nothing was written, for a blank title or a duration that is not
  /// positive; an event whose timeline link fails is removed again, as a
  /// note is.
  Future<JournalEvent?> createMeeting({
    required RelationshipEntry person,
    required String title,
    required DateTime start,
    required Duration duration,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty || duration <= Duration.zero) return null;
    final meeting = JournalEntity.event(
      data: EventData(title: trimmed, stars: 0, status: EventStatus.planned),
      entryText: const EntryText(plainText: ''),
      meta: await _persistenceLogic.createMetadata(
        dateFrom: start,
        dateTo: start.add(duration),
        categoryId: person.meta.categoryId,
        private: person.meta.private,
      ),
    );
    final written = await _writeOnTimeline(person, meeting);
    return written is JournalEvent ? written : null;
  }

  /// Saves [entity] and links it from [person]. An entity whose link is
  /// refused or throws is deleted again — a retry would otherwise write a
  /// second copy, and the first would sit where the person's page cannot
  /// reach it. Returns the saved entity, or null when nothing stands.
  Future<JournalEntity?> _writeOnTimeline(
    RelationshipEntry person,
    JournalEntity entity,
  ) async {
    if (!(await _persistenceLogic.createDbEntity(entity) ?? false)) {
      return null;
    }
    bool linked;
    try {
      linked = await addToTimeline(
        personId: person.meta.id,
        entryId: entity.meta.id,
      );
    } catch (_) {
      // A link write that throws is as refused as one that answers false.
      linked = false;
    }
    if (linked) return entity;
    await _delete(entity);
    return null;
  }

  /// Saves [entryId] again so its `updatedAt` advances — what the agent
  /// reads as "this evidence changed" — when something it holds arrived
  /// later, such as a photo's description. Answers whether it was saved.
  Future<bool> touch(String entryId) async {
    final entity = await _journalDb.journalEntityById(entryId);
    if (entity == null || entity.meta.deletedAt != null) return false;
    final result = await _persistenceLogic.updateDbEntity(
      entity.copyWith(
        meta: await _persistenceLogic.updateMetadata(entity.meta),
      ),
    );
    return result ?? false;
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
  Future<bool> deleteNote(JournalEntry note) => _delete(note);

  Future<bool> _delete(JournalEntity entity) async {
    final result = await _persistenceLogic.updateDbEntity(
      entity.copyWith(
        meta: await _persistenceLogic.updateMetadata(
          entity.meta,
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
