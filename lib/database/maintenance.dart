import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/editor_state_service.dart';

class Maintenance {
  final JournalDb _db = getIt<JournalDb>();

  /// Backs up `agent.sqlite`, closes the registered [AgentDatabase], and
  /// removes the file together with its WAL, shared-memory and rollback
  /// journal companions.
  ///
  /// Closing first matters: an unlinked file stays open for every service
  /// holding the handle, and a `-wal` left beside a freshly created file is
  /// replayed into it on the next launch. Every holder is left with a closed
  /// handle, which is why the caller quits the app right after — the next
  /// launch starts from an empty agent database and the backup.
  Future<void> deleteAgentDb() async {
    final file = await getDatabaseFile(agentDbFileName);
    if (file.existsSync()) {
      await createDbBackup(agentDbFileName);
    } else {
      getIt<DomainLogger>().log(
        LogDomain.database,
        'Database file $agentDbFileName does not exist',
        subDomain: 'deleteAgentDb',
      );
    }
    if (getIt.isRegistered<AgentDatabase>()) {
      await getIt<AgentDatabase>().close();
    }
    // Companions are removed even when the main file is gone: a leftover
    // `-wal` would be replayed into the database created on the next launch.
    _deleteWithCompanions(file);
  }

  /// Drops the drafts the editor holds in memory, cancelling their pending
  /// debounced writes, then empties the drafts database through its live
  /// connection — otherwise a draft the user just discarded would be
  /// restored into the editor, or written back moments later.
  Future<void> clearEditorDb() async {
    // Drop the in-memory drafts first: a debounced write that fired while
    // the rows were being deleted would land after them.
    if (getIt.isRegistered<EditorStateService>()) {
      getIt<EditorStateService>().resetDrafts();
    }
    await _emptyDatabase(getIt<EditorDb>(), subDomain: 'clearEditorDb');
  }

  /// Empties the sync database — outbox, sequence log, host activity, inbound
  /// queue, queue markers, onboarding rounds and watermarks — through its
  /// live connection.
  Future<void> clearSyncDb() =>
      _emptyDatabase(getIt<SyncDatabase>(), subDomain: 'clearSyncDb');

  /// Deletes every row of every table in [db] and reclaims the space, on the
  /// connection the app is using.
  ///
  /// Unlinking the file instead would leave every service holding the old
  /// handle writing into a ghost inode until restart, and an orphaned `-wal`
  /// beside the file created on the next launch. Emptying the tables keeps
  /// every handle valid, takes effect immediately, and ends with the same
  /// schema and no rows. Tables come from `sqlite_master`, not Drift's
  /// `allTables`, because the sync watermarks are created by raw migration
  /// SQL and would otherwise be skipped.
  Future<void> _emptyDatabase(
    GeneratedDatabase db, {
    required String subDomain,
  }) async {
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    final names = [for (final row in tables) row.read<String>('name')];
    await db.transaction(() async {
      for (final name in names) {
        await db.customStatement('DELETE FROM "$name"');
      }
    });
    await db.customStatement('VACUUM');
    // Raw statements bypass Drift's stream invalidation; tell every watched
    // query (the outbox count behind the sync badge, for one) that its
    // tables changed, or it would show the pre-reset value until the next
    // ordinary write.
    db.notifyUpdates({
      for (final name in names) TableUpdate(name, kind: UpdateKind.delete),
    });
    getIt<DomainLogger>().log(
      LogDomain.database,
      'Emptied ${names.length} table(s)',
      subDomain: subDomain,
    );
  }

  /// Removes [file] and the `-wal`, `-shm` and `-journal` companions SQLite
  /// keeps beside it. Call only on a closed database.
  static void _deleteWithCompanions(File file) {
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      final companion = File('${file.path}$suffix');
      if (companion.existsSync()) {
        companion.deleteSync();
      }
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

  /// Removes the FTS index file and its companions. Call only after the
  /// registered [Fts5Db] has been closed; [recreateFts5] does.
  Future<void> deleteFts5Db() async {
    final file = await getDatabaseFile(fts5DbFileName);
    final existed = file.existsSync();
    // Companions go regardless, so an orphaned `-wal` cannot be replayed
    // into the index rebuilt next.
    _deleteWithCompanions(file);
    getIt<DomainLogger>().log(
      LogDomain.database,
      existed
          ? 'FTS5 database DELETED'
          : 'Database file $fts5DbFileName does not exist',
      subDomain: existed ? 'recreateFts5' : 'deleteFts5Db',
    );
  }

  Future<void> recreateFts5({void Function(double)? onProgress}) async {
    // Close before unlinking: a file removed under an open connection keeps
    // being written by that connection until restart.
    await getIt<Fts5Db>().close();
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

    getIt
      ..unregister<Fts5Db>()
      ..registerSingleton<Fts5Db>(Fts5Db());

    final fts5Db = getIt<Fts5Db>();

    final entryCount = await _db.getJournalCount();
    var completed = 0;
    var lastReportedProgress = 0;

    // Walk the journal by rowid rather than OFFSET: an OFFSET page re-scans
    // every row before it, which makes a full rebuild quadratic in the
    // journal's size. The order does not matter to the index.
    var lastRowId = 0;
    while (true) {
      final rows = await _db
          .customSelect(
            'SELECT rowid AS rid, * FROM journal '
            'WHERE deleted = 0 AND rowid > ? ORDER BY rowid LIMIT ?',
            variables: [
              Variable.withInt(lastRowId),
              Variable.withInt(_ftsRebuildChunk),
            ],
            readsFrom: {_db.journal},
          )
          .get();
      if (rows.isEmpty) break;

      for (final row in rows) {
        lastRowId = row.read<int>('rid');
        await fts5Db.insertText(fromDbEntity(_db.journal.map(row.data)));
        completed++;

        final currentProgress = entryCount > 0 ? completed / entryCount : 0.0;
        final currentPercentage = (currentProgress * 100).round();
        if (currentPercentage > lastReportedProgress) {
          lastReportedProgress = currentPercentage;
          onProgress?.call(currentProgress);
          getIt<DomainLogger>().log(
            LogDomain.database,
            'Progress: $currentPercentage%, $completed/$entryCount',
            subDomain: 'recreateFts5',
          );
        }
      }
    }
  }

  /// Rows read per round trip while rebuilding the search index.
  static const int _ftsRebuildChunk = 500;
}
