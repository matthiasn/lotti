import 'dart:convert';

import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'rating_repository.g.dart';

@riverpod
RatingRepository ratingRepository(Ref ref) {
  return RatingRepository();
}

class RatingRepository {
  final JournalDb _journalDb = getIt<JournalDb>();
  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();
  final _uuid = const Uuid();

  /// Creates or updates a rating for a target entry.
  ///
  /// If a rating already exists for [targetId], updates it.
  /// Otherwise, creates a new [RatingEntry] and links it via [RatingLink].
  Future<RatingEntry?> createOrUpdateRating({
    required String targetId,
    required List<RatingDimension> dimensions,
    String? note,
  }) async {
    try {
      final existing =
          await _journalDb.getRatingForTimeEntry(targetId);

      if (existing != null) {
        return _updateRating(
          existing: existing,
          dimensions: dimensions,
          note: note,
        );
      }

      // Look up the target entry to inherit its category
      final targetEntry = await _journalDb.journalEntityById(targetId);

      return _createRating(
        targetId: targetId,
        dimensions: dimensions,
        note: note,
        categoryId: targetEntry?.meta.categoryId,
      );
    } catch (exception, stackTrace) {
      getIt<LoggingService>().captureException(
        exception,
        domain: 'RatingRepository',
        subDomain: 'createOrUpdateRating',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Look up existing rating for a target entry.
  Future<RatingEntry?> getRatingForTargetEntry(String targetId) async {
    return _journalDb.getRatingForTimeEntry(targetId);
  }

  Future<RatingEntry?> _createRating({
    required String targetId,
    required List<RatingDimension> dimensions,
    String? note,
    String? categoryId,
    String catalogId = 'session',
  }) async {
    final now = DateTime.now();
    final ratingData = RatingData(
      targetId: targetId,
      dimensions: dimensions,
      catalogId: catalogId,
      note: note,
    );

    final journalEntity = JournalEntity.rating(
      data: ratingData,
      meta: await _persistenceLogic.createMetadata(
        dateFrom: now,
        dateTo: now,
        categoryId: categoryId,
        uuidV5Input: jsonEncode(['rating', targetId, catalogId]),
      ),
    );

    final persisted = await _persistenceLogic.createDbEntity(
      journalEntity,
      shouldAddGeolocation: false,
    );

    if (persisted != true) return null;

    // Create a RatingLink from the rating to the target entry.
    // If link creation fails, soft-delete the orphaned rating entity
    // to avoid leaving it dangling without a link.
    try {
      await _createRatingLink(
        fromId: journalEntity.meta.id,
        toId: targetId,
      );
    } catch (e, stackTrace) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'RatingRepository',
        subDomain: '_createRating.linkCleanup',
        stackTrace: stackTrace,
      );
      await _softDeleteEntity(journalEntity);
      return null;
    }

    return journalEntity as RatingEntry;
  }

  Future<RatingEntry?> _updateRating({
    required RatingEntry existing,
    required List<RatingDimension> dimensions,
    String? note,
  }) async {
    final updatedData = existing.data.copyWith(
      dimensions: dimensions,
      note: note,
    );

    final updatedMeta = await _persistenceLogic.updateMetadata(
      existing.meta,
    );

    final updated = existing.copyWith(
      meta: updatedMeta,
      data: updatedData,
    );

    final success = await _persistenceLogic.updateDbEntity(updated);
    if (success != true) return null;
    return updated;
  }

  Future<void> _createRatingLink({
    required String fromId,
    required String toId,
  }) async {
    final now = DateTime.now();
    final vectorClockService = getIt<VectorClockService>();

    final link = EntryLink.rating(
      id: _uuid.v1(),
      fromId: fromId,
      toId: toId,
      createdAt: now,
      updatedAt: now,
      hidden: false,
      vectorClock: await vectorClockService.getNextVectorClock(),
    );

    await _journalDb.upsertEntryLink(link);
    getIt<UpdateNotifications>().notify({fromId, toId});

    // Enqueue sync message separately so a sync failure doesn't
    // cause the caller to roll back an otherwise consistent local state.
    try {
      await getIt<OutboxService>().enqueueMessage(
        SyncMessage.entryLink(
          entryLink: link,
          status: SyncEntryStatus.initial,
        ),
      );
    } catch (e, stackTrace) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'RatingRepository',
        subDomain: '_createRatingLink.enqueue',
        stackTrace: stackTrace,
      );
    }
  }

  /// Soft-deletes a journal entity by setting its deletedAt timestamp.
  /// Used as compensating cleanup when link creation fails after
  /// the entity has already been persisted.
  Future<void> _softDeleteEntity(JournalEntity entity) async {
    try {
      await _persistenceLogic.updateDbEntity(
        entity.copyWith(
          meta: await _persistenceLogic.updateMetadata(
            entity.meta,
            deletedAt: DateTime.now(),
          ),
        ),
      );
    } catch (e, stackTrace) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'RatingRepository',
        subDomain: '_softDeleteEntity',
        stackTrace: stackTrace,
      );
    }
  }
}
