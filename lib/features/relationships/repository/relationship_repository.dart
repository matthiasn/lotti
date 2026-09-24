import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';

/// One People-list row: the relationship plus its most recent check-in time
/// (null when no check-in exists yet).
typedef RelationshipListItem = ({
  RelationshipEntry relationship,

  /// The newest check-in, so the list can say what the last contact was
  /// (`Call · Today 12:44`), not only when.
  CheckInEntry? lastCheckIn,
});

/// The instant of the newest check-in, or null for a person without one.
extension RelationshipListItemRecency on RelationshipListItem {
  DateTime? get lastCheckInAt => lastCheckIn?.meta.dateFrom;
}

/// Whether [entity] is something a check-in holds as one of its entries: a
/// typed comment, a recording or a photo.
bool isCheckInEntryKind(JournalEntity entity) =>
    entity is JournalEntry || entity is JournalAudio || entity is JournalImage;

/// Repository for relationship and check-in CRUD (ADR 0038).
///
/// Relationships are [JournalEntity.relationship] entities and check-ins are
/// [JournalEntity.checkIn] entities, both stored in the journal table.
/// Check-ins are bound to their relationship twice, deliberately: a
/// [RelationshipLink] row in linked_entries (so the relationship timeline
/// uses the existing linked-entries machinery) and the denormalized
/// `CheckInData.relationshipId` (so `affectedIds` emits a precise wake token
/// and the `subtype` column supports indexed check-in queries).
class RelationshipRepository {
  RelationshipRepository({
    required this._journalDb,
    required this._journalRepository,
    required this._persistenceLogic,
  });

  final JournalDb _journalDb;
  final JournalRepository _journalRepository;
  final PersistenceLogic _persistenceLogic;

  // ── Fetch ──────────────────────────────────────────────────────────────────

  /// The UI's read of a relationship: null when [id] is not a relationship,
  /// and null for a private one while private entries are hidden.
  ///
  /// `journalEntityById` deliberately bypasses the private filter (it is the
  /// single-id read the whole app shares), so the gate lives here: without it
  /// a stale or hand-typed `/people/<private-id>` route would render the
  /// person's name, status and cadence even though the People list hides them.
  ///
  /// Runtime and cascade callers must use
  /// [getRelationshipByIdUnfiltered] instead — see its doc for why a display
  /// preference must never scope them.
  Future<RelationshipEntry?> getRelationshipById(String id) async {
    final entity = await getRelationshipByIdUnfiltered(id);
    if (entity == null) return null;
    if ((entity.meta.private ?? false) &&
        !await _journalDb.getConfigFlag(privateFlag)) {
      return null;
    }
    return entity;
  }

  /// The runtime's and the delete cascade's read of a relationship: the
  /// private-entry *display* preference deliberately does not scope it, for
  /// the same reason [getAllCheckInsForRelationship] is unfiltered.
  ///
  /// Two concrete failures the gate would cause here: a private person's
  /// agent would derive a different cadence register (or none at all) on
  /// devices that hide private entries, so peers would never converge; and
  /// [deleteRelationship] would answer "not found" for a person the user is
  /// deleting through the generic journal path, leaving the relationship and
  /// every check-in alive and syncing forever.
  Future<RelationshipEntry?> getRelationshipByIdUnfiltered(String id) async {
    final entity = await _journalDb.journalEntityById(id);
    return entity is RelationshipEntry ? entity : null;
  }

  /// Returns all non-deleted relationships with their newest check-in,
  /// most recently interacted-with first (plan v2 phase 2). People without a
  /// check-in yet sort by tracking start instead, so a freshly added person
  /// starts at the top rather than the bottom.
  Future<List<RelationshipListItem>> getRelationshipsByRecency() async {
    final relationships = await _journalDb.getRelationships();
    final latestByRelationship = await _journalDb.latestCheckIns();

    DateTime recency(RelationshipListItem item) =>
        item.lastCheckInAt ?? item.relationship.meta.dateFrom;

    return [
      for (final relationship in relationships)
        (
          relationship: relationship,
          lastCheckIn: latestByRelationship[relationship.id],
        ),
    ]..sort((a, b) => recency(b).compareTo(recency(a)));
  }

  /// Returns all non-deleted check-ins for a relationship, newest first.
  Future<List<CheckInEntry>> getCheckInsForRelationship(String relationshipId) {
    return _journalDb.getCheckInsForRelationship(relationshipId);
  }

  /// Every non-deleted check-in, private ones included — the agent's view
  /// (cadence must not depend on the private-display preference, or devices
  /// with different settings would derive different registers) and the
  /// delete cascade's view.
  Future<List<CheckInEntry>> getAllCheckInsForRelationship(
    String relationshipId,
  ) {
    return _journalDb.getAllCheckInsForRelationship(relationshipId);
  }

  /// Tasks linked to the relationship in either direction (ADR 0038 §3 —
  /// "RelationshipLink both ways"): the relationship → task links this
  /// repository writes plus any task → relationship link created from the
  /// task side. Newest task first.
  ///
  /// Scoped to `RelationshipLink` rows, so this returns exactly the set
  /// [unlinkTask] can remove — a task reachable only through some other link
  /// type would otherwise render with an unlink action that always fails.
  /// Link tombstones and hidden links are excluded, matching the generic
  /// linked-entries queries.
  Future<List<Task>> getLinkedTasks(String relationshipId) async {
    final links = await _journalDb.typedLinksForTaskIds(
      {relationshipId},
      types: {entryLinkTypeDbName(EntryLinkType.relationship)},
    );
    final linkedIds = <String>{
      for (final link in links)
        if (link.deletedAt == null && link.hidden != true)
          if (link.fromId == relationshipId) link.toId else link.fromId,
    }..remove(relationshipId);
    if (linkedIds.isEmpty) return const [];

    // Check-in links share the same type, so the task subset is resolved from
    // the indexed `type` column before any payload is deserialized.
    final tasks = await _journalDb.getLiveTasksByIds(linkedIds);
    return tasks..sort((a, b) => b.meta.dateFrom.compareTo(a.meta.dateFrom));
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  /// Creates a new relationship entity. `meta.dateFrom` is when tracking
  /// starts (ADR 0038) — the baseline for the first cadence reminder until a
  /// check-in exists (ADR 0039).
  ///
  /// [id], when given, is the entity id the person is created under instead
  /// of a freshly minted one. The contact import mints a person's id the
  /// moment the contact is ticked, so the review step can draw them in the
  /// persona accent that id hashes to — the colour they keep once created —
  /// and hands the same id here. Left null, the id is minted as usual.
  ///
  /// Persisted via [PersistenceLogic], which handles vector clocks, sync
  /// outbox enqueuing, and notification emission.
  Future<RelationshipEntry?> createRelationship({
    required RelationshipData data,
    EntryText? entryText,
    String? categoryId,
    String? id,
  }) async {
    final started = clock.now();
    final meta = await _persistenceLogic.createMetadata(
      dateFrom: started,
      dateTo: started,
      categoryId: categoryId,
      // Chosen before the clock is reserved: the reservation must name the id
      // the person is written under, or crash recovery burns their counter.
      id: id,
    );
    final relationship = RelationshipEntry(
      meta: meta,
      data: data.withClampedImageFraming,
      entryText: entryText,
    );
    final success = await _persistenceLogic.createDbEntity(relationship);
    return (success ?? false) ? relationship : null;
  }

  /// Creates a check-in for [CheckInData.relationshipId] and links it to the
  /// relationship with a [RelationshipLink] (relationship → check-in, the
  /// [ProjectLink] direction). Returns null when the relationship does not
  /// resolve to a live relationship entity.
  ///
  /// The interaction time is `meta.dateFrom`/`dateTo`; the narrative lives in
  /// [entryText].
  ///
  /// The check-in inherits the relationship's category *and* its `private`
  /// flag: a check-in is a note about the person, so it must not outlive the
  /// person's privacy. `createDbEntity` only inherits privacy from a
  /// `linkedId` passed to it, and the `RelationshipLink` here is written
  /// separately, so the flag is set on the metadata up front.
  Future<CheckInEntry?> createCheckIn({
    required CheckInData data,
    EntryText? entryText,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final relationship = await getRelationshipById(data.relationshipId);
    if (relationship == null || relationship.isDeleted) return null;

    final started = dateFrom ?? clock.now();
    final meta = await _persistenceLogic.createMetadata(
      dateFrom: started,
      dateTo: dateTo ?? started,
      categoryId: relationship.categoryId,
      private: relationship.meta.private,
    );
    final checkIn = CheckInEntry(
      meta: meta,
      data: data,
      entryText: entryText,
    );

    final created = await _persistenceLogic.createDbEntity(checkIn);
    if (!(created ?? false)) return null;

    // The check-in is already persisted (and readable via the denormalized
    // subtype), so a failed link write must not surface as "save failed" —
    // a retry would duplicate the check-in.
    try {
      await _persistenceLogic.createLink(
        fromId: relationship.id,
        toId: checkIn.id,
        linkType: EntryLinkType.relationship,
      );
    } catch (error, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.persistence,
        error,
        message: 'RelationshipLink write failed after check-in was persisted',
        stackTrace: stackTrace,
        subDomain: 'createCheckIn',
      );
    }
    return checkIn;
  }

  /// Saves an updated check-in (data, narrative, or interaction time — the
  /// caller passes the entity with `meta.dateFrom`/`dateTo` already set).
  /// Bumps the vector clock and enqueues sync via [PersistenceLogic]; the
  /// relationship's providers reload through the check-in's `affectedIds`,
  /// which carry the relationship id.
  Future<bool> updateCheckIn(CheckInEntry checkIn) async {
    final updatedMeta = await _persistenceLogic.updateMetadata(checkIn.meta);
    final result = await _persistenceLogic.updateDbEntity(
      checkIn.copyWith(meta: updatedMeta),
    );
    return result ?? false;
  }

  // ── Check-in entries ───────────────────────────────────────────────────────

  /// The entries of each of [checkInIds], in the order they were added:
  /// typed comments,
  /// recordings and photos, each linked check-in → entry with a
  /// [BasicLink]. A check-in's own `entryText` (the narrative check-ins were
  /// saved with before they held entries) is not among them — callers show
  /// it as the check-in's first entry.
  ///
  /// Deliberately unfiltered by the private-entry display preference, like
  /// [getAllCheckInsForRelationship]: the agent reads this, and devices with
  /// different display settings must give it the same context. Deleted
  /// entries and hidden links are left out, and so is anything linked from a
  /// check-in that is not a comment, recording or photo.
  Future<Map<String, List<JournalEntity>>> getAllEntriesForCheckIns(
    Set<String> checkInIds,
  ) async {
    if (checkInIds.isEmpty) return const {};
    final links =
        (await _journalDb
                .linksFromIds(checkInIds.toList(growable: false))
                .get())
            .map(entryLinkFromLinkedDbEntry)
            .whereType<BasicLink>();
    final targets = {for (final link in links) link.toId};
    final byId = {
      for (final row
          in targets.isEmpty
              ? const <JournalDbEntity>[]
              : await _journalDb
                    .journalEntitiesByIdsUnorderedAllPrivate(
                      targets.toList(growable: false),
                    )
                    .get())
        if (fromDbEntity(row) case final JournalEntity entity
            when isCheckInEntryKind(entity))
          entity.id: entity,
    };
    // Ordered by when each entry was added to the check-in — the link's
    // creation — not by the entry's own date: a photo taken last week and
    // attached today is today's addition.
    final addedAt = <String, Map<String, DateTime>>{};
    for (final link in links) {
      addedAt.putIfAbsent(link.fromId, () => {})[link.toId] = link.createdAt;
    }
    final result = <String, List<JournalEntity>>{
      for (final id in checkInIds) id: <JournalEntity>[],
    };
    for (final link in links) {
      final entity = byId[link.toId];
      final entries = result[link.fromId];
      if (entity == null || entries == null) continue;
      if (entries.every((e) => e.id != entity.id)) entries.add(entity);
    }
    for (final MapEntry(:key, value: entries) in result.entries) {
      final added = addedAt[key] ?? const {};
      entries.sort(
        (a, b) => (added[a.id] ?? a.meta.createdAt).compareTo(
          added[b.id] ?? b.meta.createdAt,
        ),
      );
    }
    return result;
  }

  /// Each photo's description, by photo id, for those of [imageIds] that
  /// have one: the newest image analysis written for it (ADR 0062
  /// Decision 2), its short summary where the model wrote one, else the
  /// analysis itself. A photo with no analysis is absent — the renderer says
  /// so rather than reading silence.
  ///
  /// The analysis is its own AI response, linked photo → response; the
  /// photo's own text is read with the photo. Deleted responses and
  /// tombstoned links are skipped.
  Future<Map<String, String>> getImageDescriptions(Set<String> imageIds) async {
    if (imageIds.isEmpty) return const {};
    final links =
        (await _journalDb.linksFromIds(imageIds.toList(growable: false)).get())
            .map(entryLinkFromLinkedDbEntry)
            .where((link) => link.deletedAt == null)
            .toList();
    if (links.isEmpty) return const {};
    final analyses = {
      for (final row
          in await _journalDb
              .journalEntitiesByIdsUnorderedAllPrivate(
                {for (final link in links) link.toId}.toList(growable: false),
              )
              .get())
        if (fromDbEntity(row) case final AiResponseEntry response
            when response.data.type == AiResponseType.imageAnalysis)
          response.id: response,
    };
    final newest = <String, AiResponseEntry>{};
    for (final link in links) {
      final response = analyses[link.toId];
      if (response == null) continue;
      final current = newest[link.fromId];
      if (current == null ||
          response.meta.dateFrom.isAfter(current.meta.dateFrom)) {
        newest[link.fromId] = response;
      }
    }
    return {
      for (final MapEntry(:key, value: response) in newest.entries)
        if (_descriptionOf(response) case final String text) key: text,
    };
  }

  static String? _descriptionOf(AiResponseEntry response) {
    for (final text in [response.data.tldr, response.data.response]) {
      final trimmed = text?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  /// The display read of one check-in's entries, oldest first: like
  /// [getAllEntriesForCheckIns], but a private entry is left out while
  /// private entries are hidden.
  Future<List<JournalEntity>> getCheckInEntries(String checkInId) async =>
      (await getEntriesForCheckIns({checkInId}))[checkInId] ?? const [];

  /// [getCheckInEntries] for several check-ins at once.
  Future<Map<String, List<JournalEntity>>> getEntriesForCheckIns(
    Set<String> checkInIds,
  ) async {
    final entries = await getAllEntriesForCheckIns(checkInIds);
    if (await _journalDb.getConfigFlag(privateFlag)) return entries;
    return {
      for (final MapEntry(:key, :value) in entries.entries)
        key: [
          for (final entry in value)
            if (!(entry.meta.private ?? false)) entry,
        ],
    };
  }

  /// Starts a comment on [checkIn]: an empty entry of its own, linked from
  /// the check-in and inheriting its category and privacy, for the user to
  /// write in place — the way a task's text entry starts. Returns null when
  /// the entry could not be written.
  ///
  /// The check-in is not touched here: an empty comment is no evidence. Its
  /// words are, and the check-in is saved again once they are written (see
  /// [touchCheckIn]).
  Future<JournalEntity?> startCommentOnCheckIn(CheckInEntry checkIn) async {
    final entry = JournalEntity.journalEntry(
      entryText: const EntryText(plainText: ''),
      meta: await _persistenceLogic.createMetadata(
        dateFrom: clock.now(),
        categoryId: checkIn.meta.categoryId,
        private: checkIn.meta.private,
      ),
    );
    final created = await _persistenceLogic.createDbEntity(
      entry,
      linkedId: checkIn.id,
    );
    return (created ?? false) ? entry : null;
  }

  /// Removes the comment [entryId] when it is still blank — started from a
  /// check-in's bar and left without a word. A blank comment is no evidence
  /// and must not be counted or synced as one. Returns whether it was
  /// removed; a comment with words, or anything else, is left alone.
  Future<bool> discardCommentIfBlank(String entryId) async {
    final entity = await _journalDb.journalEntityById(entryId);
    if (entity is! JournalEntry || entity.isDeleted) return false;
    if ((entity.entryText?.plainText.trim() ?? '').isNotEmpty) return false;
    return _softDelete(entity, clock.now());
  }

  /// Makes existing recordings or photos — the composer's takes — entries
  /// of [checkInId], and touches the check-in once when any link was
  /// written. A link that fails is logged and the rest go on: the check-in
  /// is already saved, and what it holds is whatever did link. Returns
  /// whether every link was written.
  Future<bool> attachEntriesToCheckIn({
    required String checkInId,
    required List<String> entryIds,
  }) async {
    var linkedAny = false;
    var linkedAll = true;
    for (final entryId in entryIds) {
      var linked = false;
      try {
        linked = await _persistenceLogic.createLink(
          fromId: checkInId,
          toId: entryId,
        );
      } catch (error, stackTrace) {
        getIt<DomainLogger>().error(
          LogDomain.persistence,
          error,
          message: 'check-in entry link failed for $entryId',
          stackTrace: stackTrace,
          subDomain: 'attachEntriesToCheckIn',
        );
      }
      linkedAny |= linked;
      linkedAll &= linked;
    }
    if (linkedAny) {
      // Past this point everything is saved: a touch that throws must not
      // surface as a failed save, which a retry would answer with a
      // duplicate check-in. The next change touches it again.
      try {
        await touchCheckIn(checkInId);
      } catch (error, stackTrace) {
        getIt<DomainLogger>().error(
          LogDomain.persistence,
          error,
          message: 'check-in touch failed after attaching entries',
          stackTrace: stackTrace,
          subDomain: 'attachEntriesToCheckIn',
        );
      }
    }
    return linkedAll;
  }

  /// Records that [checkInId]'s evidence changed — an entry was added, or a
  /// recording's transcript or a photo's description arrived — by saving the
  /// check-in again, which advances its `updatedAt`.
  ///
  /// The relationship agent reads `updatedAt` as "evidence last changed"
  /// (`RelationshipCadenceDerivation.lastEvidenceAt`), so the briefing goes
  /// out of date and is written again; and the save syncs, so every device
  /// sees the same signal. Returns false when [checkInId] is not a live
  /// check-in or the write was rejected.
  ///
  /// A rejected write is read and tried once more: the usual cause is a
  /// synced edit of the same check-in landing in between, whose newer
  /// vector clock the second save builds on. Losing the touch would leave
  /// the briefing blind to the new entry, so a second rejection is logged.
  Future<bool> touchCheckIn(String checkInId) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final entity = await _journalDb.journalEntityById(checkInId);
      if (entity is! CheckInEntry || entity.isDeleted) return false;
      if (await updateCheckIn(entity)) return true;
    }
    getIt<DomainLogger>().error(
      LogDomain.persistence,
      'check-in touch rejected twice for $checkInId',
      message: 'the briefing will not see this evidence change',
      subDomain: 'touchCheckIn',
    );
    return false;
  }

  /// Touches every live check-in that holds [entryId] as an entry — the
  /// signal that a recording's transcript or a photo's description arrived
  /// after the check-in was saved. See [touchCheckIn].
  Future<void> touchCheckInsHolding(String entryId) async {
    final parents = await _journalDb.parentLinkedEntityIds(entryId).get();
    for (final parentId in parents.toSet()) {
      await touchCheckIn(parentId);
    }
  }

  // ── Task links ─────────────────────────────────────────────────────────────

  /// Links [taskId] to the relationship with a [RelationshipLink]
  /// (relationship → task, the direction this repository writes).
  /// [PersistenceLogic] notifies both endpoints, so the detail providers
  /// reload without a manual notification.
  Future<bool> linkTask({
    required String relationshipId,
    required String taskId,
  }) {
    return _persistenceLogic.createLink(
      fromId: relationshipId,
      toId: taskId,
      linkType: EntryLinkType.relationship,
    );
  }

  /// Soft-deletes every live [RelationshipLink] between the relationship and
  /// [taskId], in either direction, while leaving other link types intact.
  /// Each tombstone goes through [JournalRepository.updateLink] so it receives
  /// a new vector clock, enters the sync outbox, and notifies both endpoints.
  Future<bool> unlinkTask({
    required String relationshipId,
    required String taskId,
  }) async {
    final links = await _journalDb.typedLinksForTaskIds(
      {relationshipId, taskId},
      types: {entryLinkTypeDbName(EntryLinkType.relationship)},
    );
    final matchingLinks = links.where(
      (link) =>
          link.deletedAt == null &&
          ((link.fromId == relationshipId && link.toId == taskId) ||
              (link.fromId == taskId && link.toId == relationshipId)),
    );
    final deletedAt = clock.now();
    var found = false;
    var updated = true;
    for (final link in matchingLinks) {
      found = true;
      updated =
          await _journalRepository.updateLink(
            link.copyWith(deletedAt: deletedAt, hidden: true),
          ) &&
          updated;
    }
    return found && updated;
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  /// Saves an updated relationship entity. Bumps the vector clock and
  /// enqueues sync via [PersistenceLogic].
  ///
  /// No manual notification: `updateDbEntity` already emits the entity's
  /// `affectedIds`, which carry both the relationship id (the detail
  /// provider's token) and [relationshipNotification] (the list provider's).
  ///
  /// Avatar and banner framing is clamped on the way through
  /// ([RelationshipImageFraming]): this method is the single write path for
  /// an edited person, so a crop that came out of a gesture with a rounding
  /// slip is corrected once here rather than defended against at every size
  /// the avatar is later drawn at.
  Future<bool> updateRelationship(RelationshipEntry relationship) async {
    final updatedMeta = await _persistenceLogic.updateMetadata(
      relationship.meta,
    );
    final updated = relationship.copyWith(
      meta: updatedMeta,
      data: relationship.data.withClampedImageFraming,
    );
    final result = await _persistenceLogic.updateDbEntity(updated);
    return result ?? false;
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  /// Soft-deletes a relationship and cascades to its check-ins, so no
  /// orphaned data about the person survives (ADR 0037 §5).
  ///
  /// The relationship is tombstoned *before* its check-ins: an interruption
  /// mid-cascade then leaves a few orphaned (but unqueryable from any live
  /// relationship) check-in rows behind, rather than a live relationship with
  /// a partially-deleted timeline. The check-ins are resolved via the
  /// denormalized `subtype` column, not link traversal, so once the
  /// relationship is gone no list or detail query reaches them.
  ///
  /// Both the relationship and its check-ins resolve through the
  /// *unfiltered* reads: the private-entry display preference must not scope
  /// a deletion, or a user browsing with private entries hidden would delete
  /// a person and be told nothing happened — while the relationship and every
  /// check-in stayed alive and syncing forever. The generic journal delete
  /// path reaches this method for exactly such a person.
  ///
  /// The `RelationshipLink` rows that bound each check-in to the relationship
  /// are intentionally left untouched: the app's generic delete model leaves
  /// link rows to consumers (which already filter on the entity's
  /// `deletedAt`), and this feature's own queries resolve check-ins via the
  /// denormalized `subtype` column rather than link traversal. A future
  /// change that introduced a link-only consumer would need to handle the
  /// tombstones explicitly.
  ///
  /// The agent leg of the cascade (ADR 0059 Decision 7 — identity, reports,
  /// nudges, wake records) is NOT here: it lives in
  /// `RelationshipAgentService.handleRelationshipDeleted`, invoked
  /// best-effort by the delete surfaces, because this repository must not
  /// depend on the agent service. Callers that reach this method through the
  /// generic journal delete path get the same eventual consistency: a
  /// deleted relationship's agent goes quiet (Phase A early-returns on the
  /// tombstone) until its teardown runs.
  ///
  /// Returns whether the *relationship itself* was tombstoned. A check-in
  /// whose tombstone is rejected is logged and skipped rather than failing
  /// the call: the relationship is already gone, so no live query reaches it
  /// and reporting failure would send the caller back to a page that no
  /// longer resolves.
  Future<bool> deleteRelationship(String relationshipId) async {
    final relationship = await getRelationshipByIdUnfiltered(relationshipId);
    if (relationship == null) return false;

    final checkIns = await _journalDb.getAllCheckInsForRelationship(
      relationshipId,
    );
    final deletedAt = clock.now();
    // Tombstone the relationship first so a half-finished cascade reads as
    // "gone" rather than "live with missing check-ins".
    if (!await _softDelete(relationship, deletedAt)) return false;

    for (final checkIn in checkIns) {
      if (!await _softDelete(checkIn, deletedAt)) {
        getIt<DomainLogger>().error(
          LogDomain.persistence,
          'check-in tombstone rejected for ${checkIn.id}',
          message: 'orphaned check-in left behind by relationship cascade',
          subDomain: 'deleteRelationship',
        );
      }
    }
    await _softDeleteEntriesOf(
      {for (final c in checkIns) c.id},
      deletedAt,
      personId: relationshipId,
    );
    return true;
  }

  /// Tombstones the entries the check-ins in [checkInIds] hold — the
  /// recordings, comments and photos about the person (ADR 0037: deleting
  /// leaves no orphaned data about them). An entry that also belongs to
  /// something else that is still live, such as a photo attached to a task
  /// too, is left alone; a link from something already deleted — another
  /// check-in of this person deleted earlier — does not keep it. A rejected
  /// tombstone is logged and skipped, like a check-in's.
  ///
  /// [personId] is the person the check-ins belong to: a dictation is
  /// recorded against the person before its check-in exists, so its
  /// recording carries a link from the person too, and that link is the
  /// check-in's, not another owner's.
  Future<void> _softDeleteEntriesOf(
    Set<String> checkInIds,
    DateTime deletedAt, {
    required String personId,
  }) async {
    final owners = {...checkInIds, personId};
    final entries = await getAllEntriesForCheckIns(checkInIds);
    for (final entry in entries.values.expand((e) => e).toSet()) {
      final others = {
        for (final id in await _journalDb.parentLinkedEntityIds(entry.id).get())
          if (!owners.contains(id)) id,
      };
      if (others.isNotEmpty &&
          (await _journalDb
                  .journalEntitiesByIdsUnorderedAllPrivate(
                    others.toList(growable: false),
                  )
                  .get())
              .isNotEmpty) {
        continue;
      }
      if (!await _softDelete(entry, deletedAt)) {
        getIt<DomainLogger>().error(
          LogDomain.persistence,
          'check-in entry tombstone rejected for ${entry.id}',
          message: 'orphaned check-in entry left behind by a delete',
          subDomain: '_softDeleteEntriesOf',
        );
      }
    }
  }

  /// Soft-deletes a single check-in and the entries it alone holds. Returns
  /// false when [checkInId] does not resolve to a live check-in, or when the
  /// check-in's own tombstone write is rejected.
  /// Providers reload through the tombstone's `affectedIds`, which carry the
  /// relationship id.
  Future<bool> deleteCheckIn(String checkInId) async {
    final entity = await _journalDb.journalEntityById(checkInId);
    if (entity is! CheckInEntry || entity.isDeleted) return false;
    final deletedAt = clock.now();
    if (!await _softDelete(entity, deletedAt)) return false;
    await _softDeleteEntriesOf(
      {checkInId},
      deletedAt,
      personId: entity.data.relationshipId,
    );
    return true;
  }

  /// Writes a tombstone for [entity]. Returns false when the write was
  /// rejected — `updateDbEntity` answers false when the vector-clock
  /// comparison loses to a concurrent sync, and null when it swallowed an
  /// exception. Neither may be reported to the caller as a deletion.
  Future<bool> _softDelete(JournalEntity entity, DateTime deletedAt) async {
    final result = await _persistenceLogic.updateDbEntity(
      entity.copyWith(
        meta: await _persistenceLogic.updateMetadata(
          entity.meta,
          deletedAt: deletedAt,
        ),
      ),
    );
    return result ?? false;
  }
}

final relationshipRepositoryProvider = Provider<RelationshipRepository>(
  (ref) => RelationshipRepository(
    journalDb: getIt<JournalDb>(),
    // Constructed bare like every other JournalRepository call site — the
    // class resolves its own dependencies via getIt and is not itself
    // registered there.
    journalRepository: JournalRepository(),
    persistenceLogic: getIt<PersistenceLogic>(),
  ),
  name: 'relationshipRepositoryProvider',
);
