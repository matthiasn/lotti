import 'dart:async';
import 'dart:io';

import 'package:lotti/database/common.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

class Maintenance {
  final JournalDb _db = getIt<JournalDb>();

  Future<void> deleteAgentDb() async {
    final file = await getDatabaseFile(agentDbFileName);
    if (file.existsSync()) {
      await createDbBackup(agentDbFileName);
      file.deleteSync();
      // Delete WAL companion files created when SQLite WAL mode is enabled
      final shmFile = File('${file.path}-shm');
      final walFile = File('${file.path}-wal');
      if (shmFile.existsSync()) shmFile.deleteSync();
      if (walFile.existsSync()) walFile.deleteSync();
    } else {
      getIt<DomainLogger>().log(
        LogDomain.database,
        'Database file $agentDbFileName does not exist',
        subDomain: 'deleteAgentDb',
      );
    }
  }

  Future<void> deleteEditorDb() async {
    final file = await getDatabaseFile(editorDbFileName);
    if (file.existsSync()) {
      file.deleteSync();
    } else {
      getIt<DomainLogger>().log(
        LogDomain.database,
        'Database file $editorDbFileName does not exist',
        subDomain: 'deleteEditorDb',
      );
    }
  }

  Future<void> deleteSyncDb() async {
    final file = await getDatabaseFile(syncDbFileName);
    if (file.existsSync()) {
      file.deleteSync();
    } else {
      getIt<DomainLogger>().log(
        LogDomain.database,
        'Database file $syncDbFileName does not exist',
        subDomain: 'deleteSyncDb',
      );
    }
  }

  /// One-shot purge of `sent` outbox rows older than [retention].
  ///
  /// Deletes in chunks of [chunkSize] so the writer lock is released
  /// between batches and concurrent enqueue/claim/watch can interleave.
  /// Runs `VACUUM` after a non-empty purge to reclaim disk — this is
  /// the user-triggered Maintenance path; the periodic background prune
  /// in `OutboxService.runPrune` skips VACUUM because it typically
  /// releases only a day's worth of rows.
  ///
  /// Surfaces progress via [onProgress] (running deletion total). The
  /// final count is also logged under domain `MAINTENANCE`,
  /// subDomain `purgeSentOutbox` so a single purge run is easy to find
  /// in the log later.
  ///
  /// [now] is forwarded to the underlying chunked prune so tests can
  /// pin the cutoff to a deterministic instant. Production callers
  /// leave it null and pay the real-clock cutoff.
  Future<int> purgeSentOutboxItems({
    Duration retention = const Duration(days: 7),
    int chunkSize = 5000,
    void Function(int deletedSoFar)? onProgress,
    DateTime? now,
  }) async {
    final syncDb = getIt<SyncDatabase>();
    final deleted = await syncDb.pruneSentOutboxItemsChunked(
      retention: retention,
      chunkSize: chunkSize,
      vacuumWhenDone: true,
      onProgress: onProgress,
      now: now,
    );
    getIt<DomainLogger>().log(
      LogDomain.database,
      'purgeSentOutbox removed=$deleted '
      'retentionDays=${retention.inDays} '
      'chunkSize=$chunkSize',
      subDomain: 'purgeSentOutbox',
    );
    return deleted;
  }

  Future<void> deleteFts5Db() async {
    final file = await getDatabaseFile(fts5DbFileName);
    var deleted = false;
    if (file.existsSync()) {
      file.deleteSync();
      deleted = true;
    } else {
      getIt<DomainLogger>().log(
        LogDomain.database,
        'Database file $fts5DbFileName does not exist',
        subDomain: 'deleteFts5Db',
      );
    }

    if (deleted) {
      getIt<DomainLogger>().log(
        LogDomain.database,
        'FTS5 database DELETED',
        subDomain: 'recreateFts5',
      );
    }
  }

  Future<void> recreateFts5({void Function(double)? onProgress}) async {
    try {
      await deleteFts5Db();
    } catch (e, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.database,
        e,
        stackTrace: stackTrace,
        subDomain: 'deleteFts5Db',
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
      final dbEntities = await _db
          .orderedJournal(pageSize, page * pageSize)
          .get();

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

          getIt<DomainLogger>().log(
            LogDomain.database,
            'Progress: $currentPercentage%, $completed/$entryCount',
            subDomain: 'recreateFts5',
          );
        }
      }
    }
  }
}
