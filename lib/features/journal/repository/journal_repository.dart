import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/services/task_summary_refresh_service.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'journal_repository.g.dart';

class JournalRepository {
  JournalRepository(this._ref);

  final Ref _ref;

  /// Triggers a task summary refresh for all tasks linked to the given checklist
  Future<void> _triggerTaskSummaryRefreshForChecklist(
      String checklistId) async {
    await _ref
        .read(taskSummaryRefreshServiceProvider)
        .triggerTaskSummaryRefreshForChecklist(
          checklistId: checklistId,
          callingDomain: 'JournalRepository',
        );
  }

  Future<JournalEntity?> getJournalEntityById(String id) async {
    return getIt<JournalDb>().journalEntityById(id);
  }

  Future<bool> updateCategoryId(
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

      final journalEntity =
          await getIt<JournalDb>().journalEntityById(journalEntityId);

      if (journalEntity == null) {
        return false;
      }

      // If deleting a checklist item, trigger task summary refresh
      if (journalEntity is ChecklistItem) {
        for (final checklistId in journalEntity.data.linkedChecklists) {
          await _triggerTaskSummaryRefreshForChecklist(checklistId);
        }
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

      final journalEntity =
          await getIt<JournalDb>().journalEntityById(journalEntityId);

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

  static Future<JournalEntity?> createImageEntry(
    ImageData imageData, {
    String? linkedId,
    String? categoryId,
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
    final items =
        await getIt<JournalDb>().linkedToJournalEntities(linkedTo).get();
    return items.map(fromDbEntity).toList();
  }

  Future<List<JournalEntity>> getLinkedEntities({
    required String linkedTo,
  }) async {
    final items = await getIt<JournalDb>().getLinkedEntities(linkedTo);
    return items;
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

    // sort by the (editable) date from, descending, to allow for changing the
    // start date of the linked entries and get the list reordered accordingly
    final sortedToIds = await getIt<JournalDb>()
        .journalEntityIdsByDateFromDesc(linksByToId.keys.toList())
        .get();

    return sortedToIds.map((id) => linksByToId[id]).nonNulls.toList();
  }
}

@riverpod
JournalRepository journalRepository(Ref ref) => JournalRepository(ref);
