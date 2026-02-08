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

  /// Creates or updates a rating for a time entry.
  ///
  /// If a rating already exists for [timeEntryId], updates it.
  /// Otherwise, creates a new [RatingEntry] and links it via [RatingLink].
  Future<RatingEntry?> createOrUpdateRating({
    required String timeEntryId,
    required List<RatingDimension> dimensions,
    String? note,
  }) async {
    try {
      final existing = await _journalDb.getRatingForTimeEntry(timeEntryId);

      if (existing != null) {
        return _updateRating(
          existing: existing,
          dimensions: dimensions,
          note: note,
        );
      }

      return _createRating(
        timeEntryId: timeEntryId,
        dimensions: dimensions,
        note: note,
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

  /// Look up existing rating for a time entry.
  Future<RatingEntry?> getRatingForTimeEntry(String timeEntryId) async {
    return _journalDb.getRatingForTimeEntry(timeEntryId);
  }

  Future<RatingEntry?> _createRating({
    required String timeEntryId,
    required List<RatingDimension> dimensions,
    String? note,
  }) async {
    final now = DateTime.now();
    final ratingData = RatingData(
      timeEntryId: timeEntryId,
      dimensions: dimensions,
      note: note,
    );

    final journalEntity = JournalEntity.rating(
      data: ratingData,
      meta: await _persistenceLogic.createMetadata(
        dateFrom: now,
        dateTo: now,
      ),
    );

    final persisted = await _persistenceLogic.createDbEntity(
      journalEntity,
      shouldAddGeolocation: false,
    );

    if (persisted != true) return null;

    // Create a RatingLink from the rating to the time entry
    await _createRatingLink(
      fromId: journalEntity.meta.id,
      toId: timeEntryId,
    );

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

    await _persistenceLogic.updateDbEntity(updated);
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

    await getIt<OutboxService>().enqueueMessage(
      SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.initial,
      ),
    );
  }
}
