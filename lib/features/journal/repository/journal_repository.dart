import 'dart:convert';

import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'journal_repository.g.dart';

/// App-facing facade for journal entity reads, writes, links, and deletes.
///
/// A thin coordination layer over the `getIt`-resolved `JournalDb`,
/// `PersistenceLogic`, and sync services (it is a facade, not DI-wired — deps
/// are looked up via `getIt`, not injected). Owns single- and bulk-ID loads,
/// entity create/update, entry-link writes (under a vector-clock scope), and
/// cascading cleanup such as clearing cover-art references on image delete.
class JournalRepository {
  JournalRepository();

  /// Clears coverArtId from any tasks that reference the deleted image
  Future<void> _clearCoverArtReferences(
    String imageId,
    PersistenceLogic persistenceLogic,
  ) async {
    final db = getIt<JournalDb>();
    // Find all entities that link TO this image (i.e., tasks that have this image linked)
    final linkedFromEntities = await db.getLinkedToEntities(imageId);

    for (final dbEntity in linkedFromEntities) {
      final entity = fromDbEntity(dbEntity);
      if (entity is Task && entity.data.coverArtId == imageId) {
        // Clear the coverArtId
        await persistenceLogic.updateTask(
          journalEntityId: entity.id,
          taskData: entity.data.copyWith(coverArtId: null),
        );
      }
    }
  }

  /// Loads a single entity by id, or null if it does not exist.
  Future<JournalEntity?> getJournalEntityById(String id) async {
    return getIt<JournalDb>().journalEntityById(id);
  }

  /// Bulk-fetch entities by id. Use this whenever the caller has more than
  /// one id at a time — collapses the classic `Future.wait(ids.map(byId))`
  /// fan-out into a single round-trip.
  Future<List<JournalEntity>> getJournalEntitiesByIds(
    Iterable<String> ids,
  ) async {
    final idSet = ids.toSet();
    if (idSet.isEmpty) return const <JournalEntity>[];
    return getIt<JournalDb>().getJournalEntitiesForIdsUnordered(idSet);
  }

  /// Updates only the `categoryId` on a single entity's metadata (pass null to
  /// clear it). Returns true even on a missing entity or a logged failure; only
  /// a not-found entity returns false. Callers that need cascading propagation
  /// to linked entries do that themselves (see `EntryController.updateCategoryId`).
  Future<bool> updateCategoryId(
    String journalEntityId, {
    required String? categoryId,
  }) async {
    try {
      final persistenceLogic = getIt<PersistenceLogic>();

      final journalEntity = await getIt<JournalDb>().journalEntityById(
        journalEntityId,
      );

      if (journalEntity == null) {
        return false;
      }

      await persistenceLogic.updateDbEntity(
        journalEntity.copyWith(
          meta: await persistenceLogic.updateMetadata(
            journalEntity.meta,
            categoryId: categoryId,
            clearCategoryId: categoryId == null,
          ),
        ),
      );
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'updateCategoryId',
      );
    }
    return true;
  }

  /// Soft-deletes an entity by stamping `deletedAt` on its metadata.
  ///
  /// Also handles side effects: when deleting an image used as task cover art
  /// the references are cleared first, the running timer is stopped if it is
  /// this entry, and the app badge is refreshed. Returns false only when the
  /// entity does not exist.
  Future<bool> deleteJournalEntity(
    String journalEntityId,
  ) async {
    try {
      final persistenceLogic = getIt<PersistenceLogic>();

      final journalEntity = await getIt<JournalDb>().journalEntityById(
        journalEntityId,
      );

      if (journalEntity == null) {
        return false;
      }

      // If deleting an image that is used as cover art, clear the coverArtId
      if (journalEntity is JournalImage) {
        await _clearCoverArtReferences(journalEntityId, persistenceLogic);
      }

      await persistenceLogic.updateDbEntity(
        journalEntity.copyWith(
          meta: await persistenceLogic.updateMetadata(
            journalEntity.meta,
            deletedAt: DateTime.now(),
          ),
        ),
      );

      // Stop timer if the deleted entry is currently running
      final timeService = getIt<TimeService>();
      if (timeService.getCurrent()?.id == journalEntityId) {
        await timeService.stop();
      }

      await getIt<NotificationService>().updateBadge();
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'deleteJournalEntity',
      );
    }

    return true;
  }

  /// Persists `updated` (including its metadata) through `PersistenceLogic`.
  /// Returns false on a logged failure.
  Future<bool> updateJournalEntity(JournalEntity updated) async {
    try {
      return await getIt<PersistenceLogic>().updateJournalEntity(
        updated,
        updated.meta,
      );
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'updateJournalEntity',
      );
      return false;
    }
  }

  /// Updates an entity's `dateFrom`/`dateTo` and, if it is the running timer,
  /// pushes the new range into the time service so the live duration stays in
  /// sync. Returns false only when the entity does not exist.
  Future<bool> updateJournalEntityDate(
    String journalEntityId, {
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    try {
      final persistenceLogic = getIt<PersistenceLogic>();

      final journalEntity = await getIt<JournalDb>().journalEntityById(
        journalEntityId,
      );

      if (journalEntity == null) {
        return false;
      }

      final updated = journalEntity.copyWith(
        meta: await persistenceLogic.updateMetadata(
          journalEntity.meta,
          dateFrom: dateFrom,
          dateTo: dateTo,
        ),
      );

      await persistenceLogic.updateDbEntity(updated);
      getIt<TimeService>().updateCurrent(updated);
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'updateJournalEntityDate',
      );
    }
    return true;
  }

  /// Creates a new text journal entry from `entryText`, optionally linked to
  /// `linkedId` and tagged with `categoryId`. Returns the created entity, or
  /// null on a logged failure.
  static Future<JournalEntity?> createTextEntry(
    EntryText entryText, {
    required DateTime started,
    required String id,
    String? linkedId,
    String? categoryId,
  }) async {
    try {
      final persistenceLogic = getIt<PersistenceLogic>();

      final journalEntity = JournalEntity.journalEntry(
        entryText: entryText,
        meta: await persistenceLogic.createMetadata(
          dateFrom: started,
          categoryId: categoryId,
        ),
      );

      await persistenceLogic.createDbEntity(journalEntity, linkedId: linkedId);

      return journalEntity;
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'createTextEntry',
      );
      return null;
    }
  }

  /// Creates a new image entry in the journal.
  ///
  /// Parameters:
  /// - [imageData]: The image data to create an entry for
  /// - [linkedId]: Optional ID of an entry to link this image to (e.g., a task)
  /// - [categoryId]: Optional category ID for the image
  /// - [onCreated]: Optional callback invoked after the image entry is created
  ///   (used for automatic image analysis triggering)
  static Future<JournalEntity?> createImageEntry(
    ImageData imageData, {
    String? linkedId,
    String? categoryId,
    void Function(JournalEntity)? onCreated,
  }) async {
    try {
      final persistenceLogic = getIt<PersistenceLogic>();

      final journalEntity = JournalEntity.journalImage(
        data: imageData,
        meta: await persistenceLogic.createMetadata(
          dateFrom: imageData.capturedAt,
          dateTo: imageData.capturedAt,
          uuidV5Input: json.encode(imageData),
          flag: EntryFlag.import,
          categoryId: categoryId,
        ),
        geolocation: imageData.geolocation,
      );
      await persistenceLogic.createDbEntity(
        journalEntity,
        linkedId: linkedId,
        shouldAddGeolocation: false,
      );

      // Invoke callback after successful creation
      onCreated?.call(journalEntity);

      return journalEntity;
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'createImageEntry',
      );
    }

    return null;
  }

  /// Upserts an entry link, but only when a meaningful field actually changed
  /// (see [debugHasChange]) — an unchanged link returns false on a fast path
  /// without reserving a vector clock.
  ///
  /// A real change runs inside a vector-clock scope so the bump, the local
  /// notification, and the outbox sync message stay consistent; the VC is only
  /// committed when the upsert wrote a row. Returns true when a row was written.
  Future<bool> updateLink(EntryLink link) async {
    final journalDb = getIt<JournalDb>();
    final existing = await journalDb.entryLinkById(link.id);

    if (existing != null && !_hasChange(existing, link)) {
      // No VC reserved yet — fast path.
      return false;
    }

    // Wrap in VC scope: if upsertEntryLink returns 0 (identical row already
    // exists), release the reservation and let the burn handler broadcast
    // an unresolvable hint so peers skip the gap instead of round-tripping
    // via backfill.
    return getIt<VectorClockService>().withVcScope<bool>(
      () async {
        final updated = link.copyWith(
          updatedAt: DateTime.now(),
          vectorClock: await getIt<VectorClockService>().getNextVectorClock(),
        );

        final res = await journalDb.upsertEntryLink(updated);
        if (res == 0) return false;
        getIt<UpdateNotifications>().notify({
          link.fromId,
          link.toId,
          linkNotification,
        });
        try {
          await getIt<OutboxService>().enqueueMessage(
            SyncMessage.entryLink(
              entryLink: updated,
              status: SyncEntryStatus.update,
            ),
          );
        } catch (error, stackTrace) {
          getIt<DomainLogger>().error(
            LogDomain.sync,
            error,
            message:
                'outbox enqueue failed after updateLink; VC already committed',
            stackTrace: stackTrace,
            subDomain: 'updateLink.enqueue',
          );
        }
        return true;
      },
      commitWhen: (ok) => ok,
    );
  }

  /// Test-only seam for [_hasChange] — the pure six-field link comparator.
  @visibleForTesting
  bool debugHasChange(EntryLink existing, EntryLink incoming) =>
      _hasChange(existing, incoming);

  bool _hasChange(EntryLink existing, EntryLink incoming) {
    final existingHidden = existing.hidden ?? false;
    final incomingHidden = incoming.hidden ?? false;
    final existingCollapsed = existing.collapsed ?? false;
    final incomingCollapsed = incoming.collapsed ?? false;

    return existing.fromId != incoming.fromId ||
        existing.toId != incoming.toId ||
        existing.createdAt != incoming.createdAt ||
        existing.deletedAt != incoming.deletedAt ||
        existingHidden != incomingHidden ||
        existingCollapsed != incomingCollapsed;
  }

  /// Deletes the link from `fromId` to `toId` and notifies both endpoints so
  /// their linked-entries lists refresh.
  Future<int> removeLink({
    required String fromId,
    required String toId,
  }) async {
    final res = getIt<JournalDb>().deleteLink(fromId, toId);
    getIt<UpdateNotifications>().notify({fromId, toId, linkNotification});
    return res;
  }

  /// Returns the entities that link *to* `linkedTo` (incoming / "linked from"
  /// direction). Contrast with [getLinkedEntities], which returns the outgoing
  /// targets.
  Future<List<JournalEntity>> getLinkedToEntities({
    required String linkedTo,
  }) async {
    final db = getIt<JournalDb>();
    final items = await db.getLinkedToEntities(linkedTo);
    return items.map(fromDbEntity).toList();
  }

  /// Returns the entities that `linkedTo` links *to* (outgoing direction).
  /// Contrast with [getLinkedToEntities], which returns the incoming sources.
  Future<List<JournalEntity>> getLinkedEntities({
    required String linkedTo,
  }) async {
    return getIt<JournalDb>().getLinkedEntities(linkedTo);
  }

  /// Returns all JournalImage entries linked to the given task.
  ///
  /// This is a convenience method that filters the linked entities
  /// to only include images, useful for reference image selection.
  Future<List<JournalImage>> getLinkedImagesForTask(String taskId) async {
    final linkedEntities = await getLinkedEntities(linkedTo: taskId);
    return linkedEntities.whereType<JournalImage>().toList();
  }

  /// Returns the outgoing [EntryLink]s from `linkedFrom`, deduplicated by
  /// target id and ordered by the target entity's (editable) `dateFrom`
  /// descending — so re-dating a linked entry reorders the list. Hidden links
  /// are excluded unless `includeHidden` is set.
  Future<List<EntryLink>> getLinksFromId(
    String linkedFrom, {
    bool includeHidden = false,
  }) async {
    final linksByToId = <String, EntryLink>{};

    final res = await getIt<JournalDb>()
        .linksFromId(linkedFrom, includeHidden ? [false, true] : [false])
        .get();

    for (final link in res.map(entryLinkFromLinkedDbEntry)) {
      linksByToId[link.toId] = link;
    }

    if (linksByToId.isEmpty) {
      // Avoid the follow-up `id IN ()` ordering query when there are no links.
      return const <EntryLink>[];
    }

    // sort by the (editable) date from, descending, to allow for changing the
    // start date of the linked entries and get the list reordered accordingly
    final sortedToIds = await getIt<JournalDb>()
        .getJournalEntityIdsSortedByDateFromDesc(
          linksByToId.keys.toList(growable: false),
        );

    return sortedToIds.map((id) => linksByToId[id]).nonNulls.toList();
  }
}

@riverpod
JournalRepository journalRepository(Ref ref) => JournalRepository();
