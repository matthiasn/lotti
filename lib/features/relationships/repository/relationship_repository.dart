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

  /// Returns all non-deleted relationships, newest tracking start first.
  Future<List<RelationshipEntry>> getRelationships() {
    return _journalDb.getRelationships();
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

    await _persistenceLogic.createLink(
      fromId: relationship.id,
      toId: checkIn.id,
      linkType: EntryLinkType.relationship,
    );
    return checkIn;
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
  /// When the relationship agent lands (plan v2 phases 4–5), this cascade
  /// must grow to cover the agent identity, its reports and nudges, and any
  /// pending reminder rows.
  Future<bool> deleteRelationship(String relationshipId) async {
    final relationship = await getRelationshipById(relationshipId);
    if (relationship == null) return false;

    final checkIns = await _journalDb.getCheckInsForRelationship(
      relationshipId,
    );
    final deletedAt = DateTime.now();
    for (final checkIn in checkIns) {
      await _softDelete(checkIn, deletedAt);
    }
    await _softDelete(relationship, deletedAt);

    _updateNotifications.notify({
      relationshipNotification,
      relationshipEntityUpdateNotification(relationshipId),
    });
    return true;
  }

  Future<void> _softDelete(JournalEntity entity, DateTime deletedAt) async {
    await _persistenceLogic.updateDbEntity(
      entity.copyWith(
        meta: await _persistenceLogic.updateMetadata(
          entity.meta,
          deletedAt: deletedAt,
        ),
      ),
    );
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
