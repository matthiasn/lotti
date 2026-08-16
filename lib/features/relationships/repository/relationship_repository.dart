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
  Future<RelationshipEntry?> getRelationshipById(String id) async {
    final entity = await _journalDb.journalEntityById(id);
    return entity is RelationshipEntry ? entity : null;
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

  /// Removes the [RelationshipLink] between the relationship and [taskId]
  /// in whichever direction it exists, leaving any other link type between
  /// the same pair intact (the `removeTypedLink` contract, ADR 0042).
  ///
  /// Deliberately not routed through `JournalRepository.removeTypedLink`:
  /// that method notifies unconditionally per call, which for this
  /// two-direction removal would emit two notifications even when nothing
  /// was removed. One conditional notification after both deletes keeps the
  /// providers from reloading on a no-op unlink.
  Future<bool> unlinkTask({
    required String relationshipId,
    required String taskId,
  }) async {
    final linkTypeName = entryLinkTypeDbName(EntryLinkType.relationship);
    final removed =
        await _journalDb.deleteTypedLink(relationshipId, taskId, linkTypeName) +
        await _journalDb.deleteTypedLink(taskId, relationshipId, linkTypeName);
    if (removed > 0) {
      _updateNotifications.notify({relationshipId, taskId, linkNotification});
    }
    return removed > 0;
  }

  // ── Update ─────────────────────────────────────────────────────────────────

  /// Saves an updated relationship entity. Bumps the vector clock and
  /// enqueues sync via [PersistenceLogic].
  ///
  /// No manual notification: `updateDbEntity` already emits the entity's
  /// `affectedIds`, which carry both the relationship id (the detail
  /// provider's token) and [relationshipNotification] (the list provider's).
  Future<bool> updateRelationship(RelationshipEntry relationship) async {
    final updatedMeta = await _persistenceLogic.updateMetadata(
      relationship.meta,
    );
    final updated = relationship.copyWith(meta: updatedMeta);
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
  /// The cascade resolves check-ins through the *unfiltered* query: the
  /// private-entry display preference must not scope a deletion, or a user
  /// browsing with private entries hidden would tombstone the person and
  /// leave their private check-ins alive and syncing forever.
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
  /// Returns whether the *relationship itself* was tombstoned. A check-in
  /// whose tombstone is rejected is logged and skipped rather than failing
  /// the call: the relationship is already gone, so no live query reaches it
  /// and reporting failure would send the caller back to a page that no
  /// longer resolves.
  Future<bool> deleteRelationship(String relationshipId) async {
    final relationship = await getRelationshipById(relationshipId);
    if (relationship == null) return false;

    final checkIns = await _journalDb.getAllCheckInsForRelationship(
      relationshipId,
    );
    final deletedAt = DateTime.now();
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
    return true;
  }

  /// Soft-deletes a single check-in. Returns false when [checkInId] does not
  /// resolve to a live check-in, or when the tombstone write is rejected.
  /// Providers reload through the tombstone's `affectedIds`, which carry the
  /// relationship id.
  Future<bool> deleteCheckIn(String checkInId) async {
    final entity = await _journalDb.journalEntityById(checkInId);
    if (entity is! CheckInEntry || entity.isDeleted) return false;
    return _softDelete(entity, DateTime.now());
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
    persistenceLogic: getIt<PersistenceLogic>(),
    updateNotifications: getIt<UpdateNotifications>(),
  ),
  name: 'relationshipRepositoryProvider',
);
