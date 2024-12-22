import 'dart:convert';

import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/notification_service.dart';

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
}
