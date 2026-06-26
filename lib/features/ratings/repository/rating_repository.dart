import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:uuid/uuid.dart';

/// Provides the singleton [RatingRepository] used by controllers and UI.
final Provider<RatingRepository> ratingRepositoryProvider =
    Provider.autoDispose<RatingRepository>(
      ratingRepository,
      name: 'ratingRepositoryProvider',
    );
RatingRepository ratingRepository(Ref ref) {
  return RatingRepository();
}

/// Persistence layer for ratings.
///
/// A rating is stored as a [RatingEntry] journal entity plus a [RatingLink]
/// connecting it to the entry being rated. The repository keeps those two
/// writes consistent: the link is created inside a vector-clock scope so a
/// no-op upsert releases the reserved counter, and a failed link triggers a
/// compensating soft-delete of the orphaned rating. Sync enqueue and sequence
/// logging are best-effort and never roll back an already-persisted local row.
class RatingRepository {
  final JournalDb _journalDb = getIt<JournalDb>();
  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();
  final _uuid = const Uuid();

  SyncSequenceLogService? get _sequenceLogService =>
      getIt.isRegistered<SyncSequenceLogService>()
      ? getIt<SyncSequenceLogService>()
      : null;

  Future<void> _recordLinkSequence(EntryLink link) async {
    final service = _sequenceLogService;
    final vectorClock = link.vectorClock;
    if (service == null || vectorClock == null) return;
    try {
      await service.recordSentEntryLink(
        linkId: link.id,
        vectorClock: vectorClock,
      );
    } catch (error, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.sync,
        error,
        message:
            'sequence record failed after rating link write; VC already committed',
        stackTrace: stackTrace,
        subDomain: '_createRatingLink.recordSent',
      );
    }
  }

  /// Creates or updates a rating for a target entry.
  ///
  /// Looks up any existing rating for ([targetId], [catalogId]). If one
  /// exists, its dimensions and note are updated in place. Otherwise a new
  /// [RatingEntry] is created — inheriting the target entry's category — and
  /// a [RatingLink] from the rating to the target is written.
  ///
  /// The rating's id is deterministic (uuid v5 over
  /// `['rating', targetId, catalogId]`), so the same target/catalog pair
  /// always resolves to the same entity across devices. Returns the persisted
  /// [RatingEntry], or `null` on any failure (errors are logged, not thrown).
  Future<RatingEntry?> createOrUpdateRating({
    required String targetId,
    required List<RatingDimension> dimensions,
    String catalogId = 'session',
    String? note,
  }) async {
    try {
      final existing = await _journalDb.getRatingForTimeEntry(
        targetId,
        catalogId: catalogId,
      );

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
        catalogId: catalogId,
        note: note,
        categoryId: targetEntry?.meta.categoryId,
      );
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.ratings,
        exception,
        stackTrace: stackTrace,
        subDomain: 'createOrUpdateRating',
      );
      return null;
    }
  }

  /// Look up existing rating for a target entry with the given [catalogId].
  Future<RatingEntry?> getRatingForTargetEntry(
    String targetId, {
    String catalogId = 'session',
  }) async {
    return _journalDb.getRatingForTimeEntry(targetId, catalogId: catalogId);
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
      getIt<DomainLogger>().error(
        LogDomain.ratings,
        e,
        stackTrace: stackTrace,
        subDomain: '_createRating.linkCleanup',
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

  /// Writes the [RatingLink] from a rating entity ([fromId]) to its target
  /// ([toId]) under a vector-clock scope.
  ///
  /// The scope commits only when the upsert actually changed a row
  /// (`commitWhen: (ok) => ok`); a no-op upsert releases the reserved counter
  /// so peers receive an unresolvable hint and skip the gap without a backfill.
  /// On a successful write it records the sent sequence, notifies listeners,
  /// and best-effort enqueues the sync message — outbox/sequence failures are
  /// logged but do not roll back the committed link.
  Future<void> _createRatingLink({
    required String fromId,
    required String toId,
  }) async {
    final vectorClockService = getIt<VectorClockService>();

    // Wrap the VC reservation in a scope: if upsertEntryLink turns out to be
    // a no-op (row already exists unchanged), the scope releases and the
    // burn handler proactively broadcasts an unresolvable hint for the
    // reserved counter — peers skip the gap without a backfill round-trip.
    await vectorClockService.withVcScope<bool>(
      () async {
        final now = DateTime.now();
        final link = EntryLink.rating(
          id: _uuid.v1(),
          fromId: fromId,
          toId: toId,
          createdAt: now,
          updatedAt: now,
          hidden: false,
          vectorClock: await vectorClockService.getNextVectorClock(),
        );

        final res = await _journalDb.upsertEntryLink(link);
        if (res == 0) return false;
        await _recordLinkSequence(link);
        getIt<UpdateNotifications>().notify({fromId, toId});

        // Enqueue sync message separately so a sync failure doesn't
        // cause the caller to roll back an otherwise consistent local
        // state — and doesn't trigger a VC release (the link is already
        // persisted; the reserved counter is baked into disk).
        try {
          await getIt<OutboxService>().enqueueMessage(
            SyncMessage.entryLink(
              entryLink: link,
              status: SyncEntryStatus.initial,
            ),
          );
        } catch (e, stackTrace) {
          getIt<DomainLogger>().error(
            LogDomain.sync,
            e,
            message:
                'outbox enqueue failed after _createRatingLink; '
                'VC already committed',
            stackTrace: stackTrace,
            subDomain: '_createRatingLink.enqueue',
          );
        }
        return true;
      },
      commitWhen: (ok) => ok,
    );
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
      getIt<DomainLogger>().error(
        LogDomain.ratings,
        e,
        stackTrace: stackTrace,
        subDomain: '_softDeleteEntity',
      );
    }
  }
}
