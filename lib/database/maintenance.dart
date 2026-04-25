import 'dart:async';
import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/file_utils.dart';

class Maintenance {
  final JournalDb _db = getIt<JournalDb>();

  /// Re-enqueue persisted entries within [start]..[end] so peers can backfill.
  ///
  /// [includeJournalEntities] controls whether the journal+entry-link sweep
  /// runs. [includeAgentEntities] controls whether the agent entity+link sweep
  /// runs. Both default to `true` to preserve the original behavior; the
  /// Resync Settings UI exposes these as checkboxes so the user can skip the
  /// agent sweep when it would otherwise enqueue tens of thousands of agent
  /// rows during a fresh device's catch-up.
  ///
  /// At least one flag must be `true`; if both are `false` the call is a
  /// no-op and emits a single MAINTENANCE log entry so the skip is visible
  /// in the sync log.
  Future<void> reSyncInterval({
    required DateTime start,
    required DateTime end,
    required AgentRepository agentRepository,
    bool includeJournalEntities = true,
    bool includeAgentEntities = true,
  }) async {
    if (!includeJournalEntities && !includeAgentEntities) {
      getIt<LoggingService>().captureEvent(
        'reSyncInterval skipped — both entity-type filters disabled',
        domain: 'MAINTENANCE',
        subDomain: 'reSyncInterval',
      );
      return;
    }

    final outboxService = getIt<OutboxService>();
    final vectorClockService = getIt<VectorClockService>();
    final hostId = await vectorClockService.getHost();
    const pageSize = 100;

    if (includeJournalEntities) {
      // 1. Re-sync journal entities and their links.
      final count = await _db.countJournalEntries().getSingle();
      final pages = (count / pageSize).ceil();

      for (var page = 0; page <= pages; page++) {
        final dbEntities = await _db
            .orderedJournalInterval(start, end, pageSize, page * pageSize)
            .get();
        if (dbEntities.isEmpty) {
          break;
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
              originatingHostId: hostId,
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

    if (includeAgentEntities) {
      // 2. Re-sync agent entities and links updated in the same interval.
      await _reSyncPaginated(
        countFetcher: () => agentRepository.countEntitiesInInterval(
          start: start,
          end: end,
        ),
        itemsFetcher: (limit, offset) => agentRepository.getEntitiesInInterval(
          start: start,
          end: end,
          limit: limit,
          offset: offset,
        ),
        enqueueAction: (entity) => outboxService.enqueueMessage(
          SyncMessage.agentEntity(
            agentEntity: entity,
            status: SyncEntryStatus.update,
          ),
        ),
        pageSize: pageSize,
      );

      await _reSyncPaginated(
        countFetcher: () => agentRepository.countLinksInInterval(
          start: start,
          end: end,
        ),
        itemsFetcher: (limit, offset) => agentRepository.getLinksInInterval(
          start: start,
          end: end,
          limit: limit,
          offset: offset,
        ),
        enqueueAction: (link) => outboxService.enqueueMessage(
          SyncMessage.agentLink(
            agentLink: link,
            status: SyncEntryStatus.update,
          ),
        ),
        pageSize: pageSize,
      );
    }
  }

  Future<void> _reSyncPaginated<T>({
    required Future<int> Function() countFetcher,
    required Future<List<T>> Function(int limit, int offset) itemsFetcher,
    required Future<void> Function(T item) enqueueAction,
    required int pageSize,
  }) async {
    final count = await countFetcher();
    if (count == 0) return;

    final pages = (count / pageSize).ceil();
    for (var page = 0; page < pages; page++) {
      final items = await itemsFetcher(pageSize, page * pageSize);
      for (final item in items) {
        await enqueueAction(item);
      }
    }
  }

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
      getIt<LoggingService>().captureEvent(
        'Database file $agentDbFileName does not exist',
        domain: 'MAINTENANCE',
        subDomain: 'deleteAgentDb',
      );
    }
  }

  Future<void> deleteEditorDb() async {
    final file = await getDatabaseFile(editorDbFileName);
    if (file.existsSync()) {
      file.deleteSync();
    } else {
      getIt<LoggingService>().captureEvent(
        'Database file $editorDbFileName does not exist',
        domain: 'MAINTENANCE',
        subDomain: 'deleteEditorDb',
      );
    }
  }

  Future<void> deleteSyncDb() async {
    final file = await getDatabaseFile(syncDbFileName);
    if (file.existsSync()) {
      file.deleteSync();
    } else {
      getIt<LoggingService>().captureEvent(
        'Database file $syncDbFileName does not exist',
        domain: 'MAINTENANCE',
        subDomain: 'deleteSyncDb',
      );
    }
  }

  Future<void> deleteFts5Db() async {
    final file = await getDatabaseFile(fts5DbFileName);
    var deleted = false;
    if (file.existsSync()) {
      file.deleteSync();
      deleted = true;
    } else {
      getIt<LoggingService>().captureEvent(
        'Database file $fts5DbFileName does not exist',
        domain: 'MAINTENANCE',
        subDomain: 'deleteFts5Db',
      );
    }

    if (deleted) {
      getIt<LoggingService>().captureEvent(
        'FTS5 database DELETED',
        domain: 'MAINTENANCE',
        subDomain: 'recreateFts5',
      );
    }
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
