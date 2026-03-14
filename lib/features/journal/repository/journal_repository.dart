import 'dart:async';
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
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/lru_cache.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'journal_repository.g.dart';

class JournalRepository {
  JournalRepository({
    UpdateNotifications? updateNotifications,
  }) : _updateNotifications =
           updateNotifications ?? getIt<UpdateNotifications>() {
    _updateSubscription = _updateNotifications.updateStream.listen(
      _invalidateCaches,
    );
  }

  final UpdateNotifications _updateNotifications;
  StreamSubscription<Set<String>>? _updateSubscription;
  final LruCache<String, JournalEntity?> _journalEntityByIdCache =
      LruCache<String, JournalEntity?>(1000);
  final Map<String, Future<JournalEntity?>> _journalEntityByIdInFlight =
      <String, Future<JournalEntity?>>{};
  final LruCache<String, List<JournalEntity>> _linkedEntitiesCache =
      LruCache<String, List<JournalEntity>>(256);
  final Map<String, Future<List<JournalEntity>>> _linkedEntitiesInFlight =
      <String, Future<List<JournalEntity>>>{};
  final LruCache<String, List<JournalEntity>> _linkedToEntitiesCache =
      LruCache<String, List<JournalEntity>>(256);
  final Map<String, Future<List<JournalEntity>>> _linkedToEntitiesInFlight =
      <String, Future<List<JournalEntity>>>{};
  int _cacheEpoch = 0;

  Future<void> dispose() async {
    await _updateSubscription?.cancel();
  }

  void _invalidateCaches(Set<String> affectedIds) {
    _cacheEpoch++;

    if (affectedIds.isEmpty) {
      _journalEntityByIdCache.clear();
    } else {
      affectedIds.forEach(_journalEntityByIdCache.remove);
    }

    // Linked-entity results depend on both link rows and child-entity state,
    // so conservatively drop the full list caches on any journal update.
    _journalEntityByIdInFlight.clear();
    _linkedEntitiesCache.clear();
    _linkedEntitiesInFlight.clear();
    _linkedToEntitiesCache.clear();
    _linkedToEntitiesInFlight.clear();
  }

  void _storeLinkedEntities(List<JournalEntity> entities) {
    for (final entity in entities) {
      _journalEntityByIdCache[entity.meta.id] = entity;
    }
  }

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

  Future<JournalEntity?> getJournalEntityById(String id) async {
    final cached = _journalEntityByIdCache.getEntry(id);
    if (cached.found) {
      return cached.value;
    }

    final inFlight = _journalEntityByIdInFlight[id];
    if (inFlight != null) {
      return inFlight;
    }

    final epoch = _cacheEpoch;
    late final Future<JournalEntity?> future;
    future = getIt<JournalDb>()
        .journalEntityById(id)
        .then((entity) {
          if (epoch == _cacheEpoch) {
            _journalEntityByIdCache[id] = entity;
          }
          return entity;
        })
        .whenComplete(() {
          if (identical(_journalEntityByIdInFlight[id], future)) {
            _journalEntityByIdInFlight.remove(id);
          }
        });

    _journalEntityByIdInFlight[id] = future;
    return future;
  }

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
      getIt<LoggingService>().captureException(
        exception,
        domain: 'JournalRepository',
        subDomain: 'updateCategoryId',
        stackTrace: stackTrace,
      );
    }
    return true;
  }

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
      getIt<LoggingService>().captureException(
        exception,
        domain: 'JournalRepository',
        subDomain: 'deleteJournalEntity',
        stackTrace: stackTrace,
      );
    }

    return true;
  }

  Future<bool> updateJournalEntity(JournalEntity updated) async {
    try {
      return await getIt<PersistenceLogic>().updateJournalEntity(
        updated,
        updated.meta,
      );
    } catch (exception, stackTrace) {
      getIt<LoggingService>().captureException(
        exception,
        domain: 'JournalRepository',
        subDomain: 'updateJournalEntity',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

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
      getIt<LoggingService>().captureException(
        exception,
        domain: 'JournalRepository',
        subDomain: 'updateJournalEntityDate',
        stackTrace: stackTrace,
      );
    }
    return true;
  }

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
      getIt<LoggingService>().captureException(
        exception,
        domain: 'JournalRepository',
        subDomain: 'createTextEntry',
        stackTrace: stackTrace,
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
      getIt<LoggingService>().captureException(
        exception,
        domain: 'JournalRepository',
        subDomain: 'createImageEntry',
        stackTrace: stackTrace,
      );
    }

    return null;
  }

  Future<bool> updateLink(EntryLink link) async {
    final journalDb = getIt<JournalDb>();
    final existing = await journalDb.entryLinkById(link.id);

    if (existing != null && !_hasChange(existing, link)) {
      return false;
    }

    final updated = link.copyWith(
      updatedAt: DateTime.now(),
      vectorClock: await getIt<VectorClockService>().getNextVectorClock(),
    );

    final res = await journalDb.upsertEntryLink(updated);
    getIt<UpdateNotifications>().notify({link.fromId, link.toId});

    await getIt<OutboxService>().enqueueMessage(
      SyncMessage.entryLink(
        entryLink: updated,
        status: SyncEntryStatus.update,
      ),
    );
    return res != 0;
  }

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

  Future<int> removeLink({
    required String fromId,
    required String toId,
  }) async {
    final res = getIt<JournalDb>().deleteLink(fromId, toId);
    getIt<UpdateNotifications>().notify({fromId, toId});
    return res;
  }

  Future<List<JournalEntity>> getLinkedToEntities({
    required String linkedTo,
  }) async {
    final cached = _linkedToEntitiesCache[linkedTo];
    if (cached != null) {
      return cached;
    }

    final inFlight = _linkedToEntitiesInFlight[linkedTo];
    if (inFlight != null) {
      return inFlight;
    }

    final epoch = _cacheEpoch;
    late final Future<List<JournalEntity>> future;
    future = getIt<JournalDb>()
        .getLinkedToEntities(linkedTo)
        .then((items) => items.map(fromDbEntity).toList(growable: false))
        .then((entities) {
          if (epoch == _cacheEpoch) {
            _linkedToEntitiesCache[linkedTo] = entities;
            _storeLinkedEntities(entities);
          }
          return entities;
        })
        .whenComplete(() {
          if (identical(_linkedToEntitiesInFlight[linkedTo], future)) {
            _linkedToEntitiesInFlight.remove(linkedTo);
          }
        });

    _linkedToEntitiesInFlight[linkedTo] = future;
    return future;
  }

  Future<List<JournalEntity>> getLinkedEntities({
    required String linkedTo,
  }) async {
    final cached = _linkedEntitiesCache[linkedTo];
    if (cached != null) {
      return cached;
    }

    final inFlight = _linkedEntitiesInFlight[linkedTo];
    if (inFlight != null) {
      return inFlight;
    }

    final epoch = _cacheEpoch;
    late final Future<List<JournalEntity>> future;
    future = getIt<JournalDb>()
        .getLinkedEntities(linkedTo)
        .then(List<JournalEntity>.unmodifiable)
        .then((entities) {
          if (epoch == _cacheEpoch) {
            _linkedEntitiesCache[linkedTo] = entities;
            _storeLinkedEntities(entities);
          }
          return entities;
        })
        .whenComplete(() {
          if (identical(_linkedEntitiesInFlight[linkedTo], future)) {
            _linkedEntitiesInFlight.remove(linkedTo);
          }
        });

    _linkedEntitiesInFlight[linkedTo] = future;
    return future;
  }

  /// Returns all JournalImage entries linked to the given task.
  ///
  /// This is a convenience method that filters the linked entities
  /// to only include images, useful for reference image selection.
  Future<List<JournalImage>> getLinkedImagesForTask(String taskId) async {
    final linkedEntities = await getLinkedEntities(linkedTo: taskId);
    return linkedEntities.whereType<JournalImage>().toList();
  }

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
JournalRepository journalRepository(Ref ref) {
  final repository = JournalRepository();
  ref.onDispose(repository.dispose);
  return repository;
}
