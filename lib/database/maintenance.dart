import 'dart:async';
import 'dart:io';

import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/common.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/editor_db.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as agent_model;
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/file_utils.dart';

/// One database family visited while historical sync messages are enqueued.
enum ReSyncPhase {
  journalEntities,
  agentEntities,
  agentLinks,
}

/// A snapshot emitted while [Maintenance.reSyncInterval] visits one phase.
class ReSyncProgress {
  const ReSyncProgress({
    required this.phase,
    required this.processed,
    required this.isComplete,
    this.total,
  });

  final ReSyncPhase phase;
  final int processed;
  final int? total;
  final bool isComplete;
}

/// Receives progress snapshots from [Maintenance.reSyncInterval].
typedef ReSyncProgressCallback = void Function(ReSyncProgress progress);

class Maintenance {
  final JournalDb _db = getIt<JournalDb>();

  /// Re-enqueue persisted entries within [start]..[end] so peers can backfill.
  ///
  /// [includeJournalEntities] controls whether the journal+entry-link sweep
  /// runs. [includeAgentEntities] controls whether the agent entity+link sweep
  /// runs. Both default to `true` to preserve the original behavior; the
  /// Re-sync Messages UI exposes these as checkboxes so the user can skip the
  /// agent sweep when it would otherwise enqueue tens of thousands of agent
  /// rows during a fresh device's catch-up.
  ///
  /// At least one flag must be `true`; if both are `false` the call is a
  /// no-op and emits a single MAINTENANCE log entry so the skip is visible
  /// in the sync log.
  ///
  /// [onProgress] reports the active phase after each database page. Journal
  /// totals stay unknown until that phase completes because its existing
  /// empty-page sentinel deliberately avoids an unbounded precount.
  Future<void> reSyncInterval({
    required DateTime start,
    required DateTime end,
    required AgentRepository agentRepository,
    bool includeJournalEntities = true,
    bool includeAgentEntities = true,
    ReSyncProgressCallback? onProgress,
  }) async {
    if (!includeJournalEntities && !includeAgentEntities) {
      getIt<DomainLogger>().log(
        LogDomain.database,
        'reSyncInterval skipped — both entity-type filters disabled',
        subDomain: 'reSyncInterval',
      );
      return;
    }

    final outboxService = getIt<OutboxService>();
    final vectorClockService = getIt<VectorClockService>();
    final hostId = await vectorClockService.getHost();
    const pageSize = 100;

    if (includeJournalEntities) {
      var processed = 0;
      onProgress?.call(
        const ReSyncProgress(
          phase: ReSyncPhase.journalEntities,
          processed: 0,
          isComplete: false,
        ),
      );

      // 1. Re-sync journal entities and their links.
      //
      // The unbounded `countJournalEntries()` precount was misleading
      // (it counts every entry, not just the interval) and unnecessary
      // because the page loop already terminates on the first empty page.
      // Drive the pagination off the empty-page sentinel instead, and
      // batch link lookups per page so a single round-trip serves the
      // whole page instead of one query per entry (was N+1 on long
      // intervals).
      for (var page = 0; ; page++) {
        final dbEntities = await _db
            .orderedJournalInterval(start, end, pageSize, page * pageSize)
            .get();
        if (dbEntities.isEmpty) {
          onProgress?.call(
            ReSyncProgress(
              phase: ReSyncPhase.journalEntities,
              processed: processed,
              total: processed,
              isComplete: true,
            ),
          );
          break;
        }

        final entries = entityStreamMapper(dbEntities);
        final pageEntryIds = entries.map((e) => e.meta.id).toSet();
        final allPageLinks = await _db.linksForEntryIds(pageEntryIds);
        final linksByFromId = <String, List<EntryLink>>{};
        for (final link in allPageLinks) {
          linksByFromId.putIfAbsent(link.fromId, () => []).add(link);
        }

        for (final entry in entries) {
          final jsonPath = relativeEntityPath(entry);

          await outboxService.enqueueMessageOrThrow(
            SyncMessage.journalEntity(
              id: entry.id,
              vectorClock: entry.meta.vectorClock,
              jsonPath: jsonPath,
              status: SyncEntryStatus.update,
              originatingHostId: hostId,
              // A re-sync targets a peer that may hold none of this history —
              // typically a freshly provisioned device. `update` status is
              // correct (the entry is not new here), but JSON alone would
              // leave that peer with image and audio entries it can never
              // render, so the media rides along.
              includeAttachments: true,
            ),
          );
          processed++;

          final entryLinks = linksByFromId[entry.meta.id] ?? const [];
          for (final entryLink in entryLinks) {
            await outboxService.enqueueMessageOrThrow(
              SyncMessage.entryLink(
                status: SyncEntryStatus.update,
                entryLink: entryLink,
              ),
            );
            processed++;
          }
        }

        onProgress?.call(
          ReSyncProgress(
            phase: ReSyncPhase.journalEntities,
            processed: processed,
            isComplete: false,
          ),
        );
      }
    }

    // A re-sync is the only path that sends agent data, so it is also the last
    // point at which a row saved without a vector clock can still be fixed.
    // Such a row is applied by the peer but skipped by the sequence log
    // (sync_event_processor_agent_handlers.dart:599), so it lands invisible to
    // gap detection and backfill.
    //
    // Stamping here rather than in a preflight sweep keeps the repair inside
    // the interval the user actually chose: a "Last 30 days" run must not
    // enqueue years of legacy agent history just because those rows happen to
    // lack a clock. Enqueue before persist, so a throw leaves the row still
    // null-clocked and therefore retryable on the next run.
    Future<T> stampIfClockless<T>(
      T item,
      Object? clock,
      Future<T> Function(T item) stamp,
    ) async => clock == null ? await stamp(item) : item;

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
        enqueueAction: (entity) async {
          final toSend = await stampIfClockless(
            entity,
            entity.vectorClock,
            (e) => vectorClockService.withVcScope<AgentDomainEntity>(() async {
              final stamped = e.copyWith(
                vectorClock: await vectorClockService.getNextVectorClock(
                  previous: e.vectorClock,
                ),
              );
              await agentRepository.upsertEntity(stamped);
              return stamped;
            }),
          );
          await outboxService.enqueueMessageOrThrow(
            SyncMessage.agentEntity(
              agentEntity: toSend,
              status: SyncEntryStatus.update,
            ),
          );
        },
        pageSize: pageSize,
        onProgress:
            ({
              required int processed,
              required int total,
              required bool isComplete,
            }) {
              onProgress?.call(
                ReSyncProgress(
                  phase: ReSyncPhase.agentEntities,
                  processed: processed,
                  total: total,
                  isComplete: isComplete,
                ),
              );
            },
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
        enqueueAction: (link) async {
          final toSend = await stampIfClockless(
            link,
            link.vectorClock,
            (l) => vectorClockService.withVcScope<agent_model.AgentLink>(
              () async {
                final stamped = l.copyWith(
                  vectorClock: await vectorClockService.getNextVectorClock(
                    previous: l.vectorClock,
                  ),
                );
                await agentRepository.upsertLink(stamped);
                return stamped;
              },
            ),
          );
          await outboxService.enqueueMessageOrThrow(
            SyncMessage.agentLink(
              agentLink: toSend,
              status: SyncEntryStatus.update,
            ),
          );
        },
        pageSize: pageSize,
        onProgress:
            ({
              required int processed,
              required int total,
              required bool isComplete,
            }) {
              onProgress?.call(
                ReSyncProgress(
                  phase: ReSyncPhase.agentLinks,
                  processed: processed,
                  total: total,
                  isComplete: isComplete,
                ),
              );
            },
      );
    }
  }

  Future<void> _reSyncPaginated<T>({
    required Future<int> Function() countFetcher,
    required Future<List<T>> Function(int limit, int offset) itemsFetcher,
    required Future<void> Function(T item) enqueueAction,
    required int pageSize,
    void Function({
      required int processed,
      required int total,
      required bool isComplete,
    })?
    onProgress,
  }) async {
    final count = await countFetcher();
    if (count == 0) {
      onProgress?.call(processed: 0, total: 0, isComplete: true);
      return;
    }

    final pages = (count / pageSize).ceil();
    var processed = 0;
    onProgress?.call(processed: 0, total: count, isComplete: false);
    for (var page = 0; page < pages; page++) {
      final items = await itemsFetcher(pageSize, page * pageSize);
      for (final item in items) {
        await enqueueAction(item);
      }
      processed += items.length;
      onProgress?.call(
        processed: processed,
        total: count,
        isComplete: page == pages - 1,
      );
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
