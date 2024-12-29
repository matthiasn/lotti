import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'journal_repository.g.dart';

class JournalRepository {
  JournalRepository();

  static Future<bool> updateCategoryId(
    String journalEntityId, {
    required String? categoryId,
  }) async {
    try {
      final persistenceLogic = getIt<PersistenceLogic>();

      final journalEntity =
          await getIt<JournalDb>().journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      await persistenceLogic.updateDbEntity(
        journalEntity.copyWith(
          meta: await persistenceLogic.updateMetadata(
            journalEntity.meta,
            categoryId: categoryId,
          ),
        ),
      );
    } catch (exception, stackTrace) {
      getIt<LoggingDb>().captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'updateCategoryId',
        stackTrace: stackTrace,
      );
    }
    return true;
  }

  static Future<bool> deleteJournalEntity(
    String journalEntityId,
  ) async {
    try {
      final persistenceLogic = getIt<PersistenceLogic>();

      final journalEntity =
          await getIt<JournalDb>().journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      await persistenceLogic.updateDbEntity(
        journalEntity.copyWith(
          meta: await persistenceLogic.updateMetadata(
            journalEntity.meta,
            deletedAt: DateTime.now(),
          ),
        ),
      );

      await getIt<NotificationService>().updateBadge();
    } catch (exception, stackTrace) {
      getIt<LoggingDb>().captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'deleteJournalEntity',
        stackTrace: stackTrace,
      );
    }

    return true;
  }

  static Future<bool> updateJournalEntityDate(
    String journalEntityId, {
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    try {
      final persistenceLogic = getIt<PersistenceLogic>();

      final journalEntity =
          await getIt<JournalDb>().journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      await persistenceLogic.updateDbEntity(
        journalEntity.copyWith(
          meta: await persistenceLogic.updateMetadata(
            journalEntity.meta,
            dateFrom: dateFrom,
            dateTo: dateTo,
          ),
        ),
      );
    } catch (exception, stackTrace) {
      getIt<LoggingDb>().captureException(
        exception,
        domain: 'persistence_logic',
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
  }) async {
    try {
      final persistenceLogic = getIt<PersistenceLogic>();

      final journalEntity = JournalEntity.journalEntry(
        entryText: entryText,
        meta: await persistenceLogic.createMetadata(dateFrom: started),
      );

      await persistenceLogic.createDbEntity(journalEntity, linkedId: linkedId);

      return journalEntity;
    } catch (exception, stackTrace) {
      getIt<LoggingDb>().captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createTextEntry',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  static Future<JournalEntity?> createImageEntry(
    ImageData imageData, {
    String? linkedId,
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
        ),
        geolocation: imageData.geolocation,
      );
      await persistenceLogic.createDbEntity(
        journalEntity,
        linkedId: linkedId,
        shouldAddGeolocation: false,
      );
      return journalEntity;
    } catch (exception, stackTrace) {
      getIt<LoggingDb>().captureException(
        exception,
        domain: 'persistence_logic',
        subDomain: 'createImageEntry',
        stackTrace: stackTrace,
      );
    }

    return null;
  }

  Future<bool> updateLink(EntryLink link) async {
    final updated = link.copyWith(
      updatedAt: DateTime.now(),
      vectorClock: await getIt<VectorClockService>().getNextVectorClock(),
    );

    final res = await getIt<JournalDb>().upsertEntryLink(updated);
    getIt<UpdateNotifications>().notify({link.fromId, link.toId});

    await getIt<OutboxService>().enqueueMessage(
      SyncMessage.entryLink(
        entryLink: updated,
        status: SyncEntryStatus.update,
      ),
    );
    return res != 0;
  }

  Future<bool> toggleHideLink({
    required String fromId,
    required String toId,
  }) async {
    final now = DateTime.now();

    final link = EntryLink.basic(
      id: uuid.v1(),
      fromId: fromId,
      toId: toId,
      createdAt: now,
      updatedAt: now,
      hidden: false,
      vectorClock: await getIt<VectorClockService>().getNextVectorClock(),
    );

    final res = await getIt<JournalDb>().upsertEntryLink(link);
    getIt<UpdateNotifications>().notify({link.fromId, link.toId});

    await getIt<OutboxService>().enqueueMessage(
      SyncMessage.entryLink(
        entryLink: link,
        status: SyncEntryStatus.initial,
      ),
    );
    return res != 0;
  }

  Future<int> removeLink({
    required String fromId,
    required String toId,
  }) async {
    final res = getIt<JournalDb>().removeLink(fromId: fromId, toId: toId);
    getIt<UpdateNotifications>().notify({fromId, toId});
    return res;
  }

  Future<List<EntryLink>> getLinksFromId(
    String linkedFrom, {
    bool includeHidden = false,
  }) async {
    final res = await getIt<JournalDb>()
        .linksFromId(
          linkedFrom,
          includeHidden ? [false, true] : [false],
        )
        .get();

    return res.map(entryLinkFromLinkedDbEntry).toList();
  }
}

@riverpod
JournalRepository journalRepository(Ref ref) => JournalRepository();
