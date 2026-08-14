import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/consts.dart';

/// One People-list row: the relationship plus its most recent check-in time
/// (null when no check-in exists yet).
typedef RelationshipListItem = ({
  RelationshipEntry relationship,
  DateTime? lastCheckInAt,
});

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
    required this._persistenceLogic,
    required this._updateNotifications,
  });

  final JournalDb _journalDb;
  final PersistenceLogic _persistenceLogic;
  final UpdateNotifications _updateNotifications;

  // ── Fetch ──────────────────────────────────────────────────────────────────

  /// Returns a relationship by its entity ID, or null.
  ///
  /// A private relationship resolves to null while private entries are
  /// hidden. `journalEntityById` deliberately bypasses the private filter
  /// (it is the single-id read the whole app shares), so the gate lives
  /// here: without it a stale or hand-typed `/people/<private-id>` route
  /// would render the person's name, status and cadence even though the
  /// People list hides them.
  Future<RelationshipEntry?> getRelationshipById(String id) async {
    final entity = await _journalDb.journalEntityById(id);
    if (entity is! RelationshipEntry) return null;
    if ((entity.meta.private ?? false) &&
        !await _journalDb.getConfigFlag(privateFlag)) {
      return null;
    }
    return entity;
  }

  /// Returns all non-deleted relationships with their latest check-in time,
  /// most recently interacted-with first (plan v2 phase 2). People without a
  /// check-in yet sort by tracking start instead, so a freshly added person
  /// starts at the top rather than the bottom.
  Future<List<RelationshipListItem>> getRelationshipsByRecency() async {
    final relationships = await _journalDb.getRelationships();
    final latestByRelationship = await _journalDb.latestCheckInTimes();

    DateTime recency(RelationshipListItem item) =>
        item.lastCheckInAt ?? item.relationship.meta.dateFrom;

    return [
      for (final relationship in relationships)
        (
          relationship: relationship,
          lastCheckInAt: latestByRelationship[relationship.id],
        ),
    ]..sort((a, b) => recency(b).compareTo(recency(a)));
  }

  /// Returns all non-deleted check-ins for a relationship, newest first.
  Future<List<CheckInEntry>> getCheckInsForRelationship(String relationshipId) {
    return _journalDb.getCheckInsForRelationship(relationshipId);
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  /// Creates a new relationship entity. `meta.dateFrom` is when tracking
  /// starts (ADR 0038) — the baseline for the first cadence reminder until a
  /// check-in exists (ADR 0039).
  ///
  /// Persisted via [PersistenceLogic], which handles vector clocks, sync
  /// outbox enqueuing, and notification emission.
  Future<RelationshipEntry?> createRelationship({
    required RelationshipData data,
    EntryText? entryText,
    String? categoryId,
    DateTime? trackingStartedAt,
  }) async {
    final started = trackingStartedAt ?? DateTime.now();
    final meta = await _persistenceLogic.createMetadata(
      dateFrom: started,
      dateTo: started,
      categoryId: categoryId,
    );
    final relationship = RelationshipEntry(
      meta: meta,
      data: data,
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

    final started = dateFrom ?? DateTime.now();
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

  // ── Update ─────────────────────────────────────────────────────────────────

  /// Saves an updated relationship entity. Bumps the vector clock and
  /// enqueues sync via [PersistenceLogic].
  Future<bool> updateRelationship(RelationshipEntry relationship) async {
    final updatedMeta = await _persistenceLogic.updateMetadata(
      relationship.meta,
    );
    final updated = relationship.copyWith(meta: updatedMeta);
    final result = await _persistenceLogic.updateDbEntity(updated);
    if (result ?? false) {
      _updateNotifications.notify({
        relationshipEntityUpdateNotification(updated.id),
      });
    }
    return result ?? false;
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  /// Soft-deletes a relationship and cascades to its check-ins, so no
  /// orphaned data about the person survives (ADR 0037 §5).
  ///
  /// The `RelationshipLink` rows that bound each check-in to the relationship
  /// are intentionally left untouched: the app's generic delete model leaves
  /// link rows to consumers (which already filter on the entity's
  /// `deletedAt`), and this feature's own queries resolve check-ins via the
  /// denormalized `subtype` column rather than link traversal. A future
  /// change that introduced a link-only consumer would need to handle the
  /// tombstones explicitly.
  ///
  /// When the relationship agent lands (plan v2 phases 4–5), this cascade
  /// must grow to cover the agent identity, its reports and nudges, and any
  /// pending reminder rows.
  ///
  /// The cascade reads check-ins *unfiltered* by private visibility. The
  /// browsing query hides private check-ins while private mode is off, and
  /// cascading over that view would tombstone the person while their private
  /// check-ins survived — resurfacing as orphans the next time private
  /// entries are shown.
  ///
  /// Deletion is not atomic — the journal has no cross-entity transaction
  /// here — so it is ordered and idempotent instead: check-ins go first and
  /// the relationship is only tombstoned once all of them are down. A
  /// rejected write therefore leaves the person visible and returns false, so
  /// the caller reports the failure and a retry resumes on the check-ins that
  /// are still live rather than stranding them under a deleted person.
  Future<bool> deleteRelationship(String relationshipId) async {
    final relationship = await getRelationshipById(relationshipId);
    if (relationship == null) return false;

    final checkIns = await _journalDb.getAllCheckInsForRelationship(
      relationshipId,
    );
    final deletedAt = DateTime.now();
    var cascaded = true;
    for (final checkIn in checkIns) {
      cascaded = await _softDelete(checkIn, deletedAt) && cascaded;
    }
    final deleted = cascaded && await _softDelete(relationship, deletedAt);

    // Notify either way: a partial cascade still changed rows, and the list
    // and detail views must reflect what actually landed.
    _updateNotifications.notify({
      relationshipNotification,
      relationshipEntityUpdateNotification(relationshipId),
    });
    return deleted;
  }

  /// Soft-deletes a single check-in. Returns false when [checkInId] does not
  /// resolve to a live check-in, or when the tombstone write is rejected —
  /// the caller must not report a delete the database refused. Providers
  /// reload through the tombstone's `affectedIds`, which carry the
  /// relationship id.
  Future<bool> deleteCheckIn(String checkInId) async {
    final entity = await _journalDb.journalEntityById(checkInId);
    if (entity is! CheckInEntry || entity.isDeleted) return false;
    return _softDelete(entity, DateTime.now());
  }

  /// Writes a tombstone for [entity]. Returns whether the write was applied.
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
    persistenceLogic: getIt<PersistenceLogic>(),
    updateNotifications: getIt<UpdateNotifications>(),
  ),
  name: 'relationshipRepositoryProvider',
);
