import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart';

class Maintenance {
  final JournalDb _db = getIt<JournalDb>();

  Future<void> reSyncInterval({
    required DateTime start,
    required DateTime end,
  }) async {
    final outboxService = getIt<OutboxService>();
    final count = await _db.countJournalEntries().getSingle();
    const pageSize = 100;
    final pages = (count / pageSize).ceil();

    for (var page = 0; page <= pages; page++) {
      final dbEntities = await _db
          .orderedJournalInterval(start, end, pageSize, page * pageSize)
          .get();
      if (dbEntities.isEmpty) {
        return;
      }

      final entries = entityStreamMapper(dbEntities);

      for (final entry in entries) {
        final jsonPath = relativeEntityPath(entry);

        await outboxService.enqueueMessage(
          SyncMessage.journalEntity(
            id: entry.id,
            vectorClock: entry.meta.vectorClock,
            jsonPath: jsonPath,
            status: SyncEntryStatus.update,
          ),
        );

        final entryLinks = await _db.linksForEntryIds({entry.meta.id});
        for (final entryLink in entryLinks) {
          await outboxService.enqueueMessage(
            SyncMessage.entryLink(
              status: SyncEntryStatus.update,
              entryLink: entryLink,
            ),
          );
        }
      }
    }
  }

  Future<void> deleteEditorDb() async {
    final file = await getDatabaseFile(editorDbFileName);
    file.deleteSync();
  }

  Future<void> purgeAudioModels() async {
    final documentsDir = getDocumentsDirectory();
    final file = File(join(documentsDir.path, 'huggingface'));
    if (file.existsSync()) {
      file.deleteSync(recursive: true);
    }
  }

  Future<void> deleteLoggingDb() async {
    final file = await getDatabaseFile(loggingDbFileName);
    file.deleteSync();
  }

  Future<void> deleteSyncDb() async {
    final file = await getDatabaseFile(syncDbFileName);
    file.deleteSync();
  }

  Future<void> deleteFts5Db() async {
    final file = await getDatabaseFile(fts5DbFileName);
    file.deleteSync();

    getIt<LoggingService>().captureEvent(
      'FTS5 database DELETED',
      domain: 'MAINTENANCE',
      subDomain: 'recreateFts5',
    );
  }

  Future<void> recreateFts5({void Function(double)? onProgress}) async {
    try {
      await deleteFts5Db();
    } catch (e, stackTrace) {
      getIt<LoggingService>().captureException(
        e,
        domain: 'MAINTENANCE',
        subDomain: 'deleteFts5Db',
        stackTrace: stackTrace,
      );
    }

    await getIt<Fts5Db>().close();

    getIt
      ..unregister<Fts5Db>()
      ..registerSingleton<Fts5Db>(Fts5Db());

    final fts5Db = getIt<Fts5Db>();

    final entryCount = await _db.getJournalCount();
    const pageSize = 500;
    final pages = (entryCount / pageSize).ceil();
    var completed = 0;
    var lastReportedProgress = 0;

    for (var page = 0; page <= pages; page++) {
      final dbEntities =
          await _db.orderedJournal(pageSize, page * pageSize).get();

      final entries = entityStreamMapper(dbEntities);

      for (var i = 0; i < entries.length; i++) {
        final entry = entries[i];
        await fts5Db.insertText(entry);
        completed++;

        // Calculate current progress percentage
        final currentProgress = entryCount > 0 ? (completed / entryCount) : 0.0;
        final currentPercentage = (currentProgress * 100).round();

        // Only update if we've moved to a new percentage point
        if (currentPercentage > lastReportedProgress) {
          lastReportedProgress = currentPercentage;
          onProgress?.call(currentProgress);

          // Add a small delay to make the progress visible
          await Future<void>.delayed(const Duration(milliseconds: 10));

          getIt<LoggingService>().captureEvent(
            'Progress: $currentPercentage%, $completed/$entryCount',
            domain: 'MAINTENANCE',
            subDomain: 'recreateFts5',
          );
        }
      }
    }
  }
}
