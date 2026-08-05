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
import 'package:lotti/features/agents/database/agent_db_conversions.dart';
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

/// The individual payload family represented by a [ReSyncFailure].
enum ReSyncItemType {
  journalEntity,
  entryLink,
  agentEntity,
  agentLink,
}

/// One historical-sync item that could not be prepared or queued.
///
/// The failed action is retained only for the lifetime of the result so the UI
/// can retry this item without sweeping the successful history again.
class ReSyncFailure {
  ReSyncFailure({
    required ReSyncPhase phase,
    required ReSyncItemType itemType,
    required String itemId,
    required Object error,
    required StackTrace stackTrace,
    required Future<void> Function() retryAction,
    required DomainLogger logger,
  }) : this._(
         retryAction,
         logger,
         phase: phase,
         itemType: itemType,
         itemId: itemId,
         error: error,
         stackTrace: stackTrace,
       );

  ReSyncFailure._(
    this._retryAction,
    this._logger, {
    required this.phase,
    required this.itemType,
    required this.itemId,
    required this.error,
    required this.stackTrace,
  });

  final ReSyncPhase phase;
  final ReSyncItemType itemType;
  final String itemId;
  final Object error;
  final StackTrace stackTrace;
  final Future<void> Function() _retryAction;
  final DomainLogger _logger;

  Future<ReSyncFailure?> _retry() async {
    try {
      await _retryAction();
      return null;
    } catch (retryError, retryStackTrace) {
      _logFailure(
        retryError,
        retryStackTrace,
        attempt: 'retry',
      );
      return ReSyncFailure(
        phase: phase,
        itemType: itemType,
        itemId: itemId,
        error: retryError,
        stackTrace: retryStackTrace,
        retryAction: _retryAction,
        logger: _logger,
      );
    }
  }

  void _logFailure(
    Object failure,
    StackTrace failureStackTrace, {
    required String attempt,
  }) {
    _logger.error(
      LogDomain.sync,
      failure,
      stackTrace: failureStackTrace,
      subDomain: 'reSyncInterval.item',
      message:
          'Historical sync $attempt failed '
          'itemType=${itemType.name} itemId=$itemId',
    );
  }
}

/// Outcome of one historical-sync sweep or failed-item retry.
class ReSyncResult {
  ReSyncResult({
    required this.succeeded,
    required List<ReSyncFailure> failures,
  }) : failures = List.unmodifiable(failures);

  static final empty = ReSyncResult(succeeded: 0, failures: []);

  final int succeeded;
  final List<ReSyncFailure> failures;

  int get total => succeeded + failures.length;
  bool get hasFailures => failures.isNotEmpty;

  /// Retries only the items that failed in this result.
  ///
  /// [onProgress] reports each affected phase independently so callers can
  /// keep a long targeted retry visibly moving.
  Future<ReSyncResult> retryFailures({
    ReSyncProgressCallback? onProgress,
  }) async {
    var retriedSuccessfully = 0;
    final remaining = <ReSyncFailure>[];
    final failuresByPhase = <ReSyncPhase, List<ReSyncFailure>>{};
    for (final failure in failures) {
      failuresByPhase.putIfAbsent(failure.phase, () => []).add(failure);
    }

    for (final phaseFailures in failuresByPhase.entries) {
      var processed = 0;
      var failed = 0;
      final total = phaseFailures.value.length;
      onProgress?.call(
        ReSyncProgress(
          phase: phaseFailures.key,
          processed: 0,
          total: total,
          isComplete: false,
        ),
      );
      for (final failure in phaseFailures.value) {
        final nextFailure = await failure._retry();
        processed++;
        if (nextFailure == null) {
          retriedSuccessfully++;
        } else {
          failed++;
          remaining.add(nextFailure);
        }
        onProgress?.call(
          ReSyncProgress(
            phase: phaseFailures.key,
            processed: processed,
            total: total,
            isComplete: processed == total,
            failed: failed,
          ),
        );
      }
    }
    return ReSyncResult(
      succeeded: succeeded + retriedSuccessfully,
      failures: remaining,
    );
  }
}

/// A snapshot emitted while [Maintenance.reSyncInterval] visits one phase.
class ReSyncProgress {
  const ReSyncProgress({
    required this.phase,
    required this.processed,
    required this.isComplete,
    this.total,
    this.failed = 0,
  });

  final ReSyncPhase phase;
  final int processed;
  final int? total;
  final bool isComplete;
  final int failed;

  int get succeeded => processed - failed;
}

/// Receives progress snapshots from [Maintenance.reSyncInterval].
typedef ReSyncProgressCallback = void Function(ReSyncProgress progress);

class _ReSyncFailureCollector {
  _ReSyncFailureCollector(this._logger);

  final DomainLogger _logger;
  var _succeeded = 0;
  final List<ReSyncFailure> _failures = [];

  ReSyncResult get result => ReSyncResult(
    succeeded: _succeeded,
    failures: _failures,
  );

  Future<bool> attempt({
    required ReSyncPhase phase,
    required ReSyncItemType itemType,
    required String itemId,
    required Future<void> Function() action,
  }) async {
    try {
      await action();
      _succeeded++;
      return true;
    } catch (error, stackTrace) {
      final failure = ReSyncFailure(
        phase: phase,
        itemType: itemType,
        itemId: itemId,
        error: error,
        stackTrace: stackTrace,
        retryAction: action,
        logger: _logger,
      ).._logFailure(error, stackTrace, attempt: 'enqueue');
      _failures.add(failure);
      return false;
    }
  }

  void defer({
    required ReSyncPhase phase,
    required ReSyncItemType itemType,
    required String itemId,
    required String dependencyItemId,
    required Future<void> Function() retryAction,
  }) {
    final error = StateError(
      'Historical sync deferred because parent item '
      '$dependencyItemId was not queued',
    );
    final stackTrace = StackTrace.current;
    final failure = ReSyncFailure(
      phase: phase,
      itemType: itemType,
      itemId: itemId,
      error: error,
      stackTrace: stackTrace,
      retryAction: retryAction,
      logger: _logger,
    ).._logFailure(error, stackTrace, attempt: 'defer');
    _failures.add(failure);
  }
}

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
  ///
  /// A failure preparing or enqueueing one row is logged and returned in the
  /// [ReSyncResult]; it never prevents later rows or phases from running. The
  /// result retains retry actions for only those failed rows.
  Future<ReSyncResult> reSyncInterval({
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
      return ReSyncResult.empty;
    }

    final outboxService = getIt<OutboxService>();
    final failures = _ReSyncFailureCollector(getIt<DomainLogger>());
    final vectorClockService = getIt<VectorClockService>();
    final hostId = await vectorClockService.getHost();
    const pageSize = 100;

    if (includeJournalEntities) {
      var processed = 0;
      var failed = 0;
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
              failed: failed,
            ),
          );
          break;
        }

        final pageEntryIds = dbEntities.map((row) => row.id).toSet();
        final allPageLinkRows = await _db
            .linksFromIds(
              pageEntryIds.toList(),
            )
            .get();
        final linkRowsByFromId = <String, List<LinkedDbEntry>>{};
        for (final row in allPageLinkRows) {
          linkRowsByFromId.putIfAbsent(row.fromId, () => []).add(row);
        }

        for (final dbEntity in dbEntities) {
          JournalEntity? preparedEntry;
          var parentQueued = false;
          final queued = await failures.attempt(
            phase: ReSyncPhase.journalEntities,
            itemType: ReSyncItemType.journalEntity,
            itemId: dbEntity.id,
            action: () async {
              final entry = preparedEntry ??= fromDbEntity(dbEntity);
              await outboxService.enqueueMessageOrThrow(
                SyncMessage.journalEntity(
                  id: entry.id,
                  vectorClock: entry.meta.vectorClock,
                  jsonPath: relativeEntityPath(entry),
                  status: SyncEntryStatus.update,
                  originatingHostId: hostId,
                  // A re-sync targets a peer that may hold none of this
                  // history — typically a freshly provisioned device.
                  // `update` status is correct (the entry is not new here),
                  // but JSON alone would leave that peer with image and audio
                  // entries it can never render, so the media rides along.
                  includeAttachments: true,
                ),
              );
              parentQueued = true;
            },
          );
          processed++;
          if (!queued) failed++;

          final entryLinkRows = linkRowsByFromId[dbEntity.id] ?? const [];
          for (final entryLinkRow in entryLinkRows) {
            EntryLink? preparedLink;
            Future<void> enqueueLink() async {
              if (!parentQueued) {
                throw StateError(
                  'Parent journal entity ${dbEntity.id} is not queued',
                );
              }
              final entryLink = preparedLink ??= entryLinkFromLinkedDbEntry(
                entryLinkRow,
              );
              await outboxService.enqueueMessageOrThrow(
                SyncMessage.entryLink(
                  status: SyncEntryStatus.update,
                  entryLink: entryLink,
                ),
              );
            }

            if (!queued) {
              failures.defer(
                phase: ReSyncPhase.journalEntities,
                itemType: ReSyncItemType.entryLink,
                itemId: entryLinkRow.id,
                dependencyItemId: dbEntity.id,
                retryAction: enqueueLink,
              );
              processed++;
              failed++;
              continue;
            }

            final linkQueued = await failures.attempt(
              phase: ReSyncPhase.journalEntities,
              itemType: ReSyncItemType.entryLink,
              itemId: entryLinkRow.id,
              action: enqueueLink,
            );
            processed++;
            if (!linkQueued) failed++;
          }
        }

        onProgress?.call(
          ReSyncProgress(
            phase: ReSyncPhase.journalEntities,
            processed: processed,
            isComplete: false,
            failed: failed,
          ),
        );
      }
    }

    // A re-sync is the only path that sends agent data, so it is also the last
    // point at which a row saved without a vector clock can still be fixed.
    // Such a row is applied by the peer but skipped by the sequence log
    // (sync_event_processor_agent_handlers.dart:599), so it lands invisible to
    // gap detection and backfill.
    // Stamping here rather than in a preflight sweep keeps the repair inside
    // the interval the user actually chose: a "Last 30 days" run must not
    // enqueue years of legacy agent history just because those rows happen to
    // lack a clock. The stamped row is persisted before enqueueing so peers
    // never receive a clockless payload. Its retry closure retains that
    // stamped value, avoiding a second clock increment after an enqueue-only
    // failure; a persistence failure simply retries the same preparation.
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
        itemsFetcher: (limit, offset) =>
            agentRepository.getEntityRowsInInterval(
              start: start,
              end: end,
              limit: limit,
              offset: offset,
            ),
        enqueueAction: (row) async {
          AgentDomainEntity? preparedEntity;
          return failures.attempt(
            phase: ReSyncPhase.agentEntities,
            itemType: ReSyncItemType.agentEntity,
            itemId: row.id,
            action: () async {
              var toSend = preparedEntity ??= AgentDbConversions.fromEntityRow(
                row,
              );
              toSend = await stampIfClockless(
                toSend,
                toSend.vectorClock,
                (e) => vectorClockService.withVcScope<AgentDomainEntity>(
                  () async {
                    final stamped = e.copyWith(
                      vectorClock: await vectorClockService.getNextVectorClock(
                        previous: e.vectorClock,
                      ),
                    );
                    await agentRepository.upsertEntity(stamped);
                    return stamped;
                  },
                ),
              );
              preparedEntity = toSend;
              await outboxService.enqueueMessageOrThrow(
                SyncMessage.agentEntity(
                  agentEntity: toSend,
                  status: SyncEntryStatus.update,
                ),
              );
            },
          );
        },
        pageSize: pageSize,
        onProgress:
            ({
              required int processed,
              required int total,
              required bool isComplete,
              required int failed,
            }) {
              onProgress?.call(
                ReSyncProgress(
                  phase: ReSyncPhase.agentEntities,
                  processed: processed,
                  total: total,
                  isComplete: isComplete,
                  failed: failed,
                ),
              );
            },
      );

      await _reSyncPaginated(
        countFetcher: () => agentRepository.countLinksInInterval(
          start: start,
          end: end,
        ),
        itemsFetcher: (limit, offset) => agentRepository.getLinkRowsInInterval(
          start: start,
          end: end,
          limit: limit,
          offset: offset,
        ),
        enqueueAction: (row) async {
          agent_model.AgentLink? preparedLink;
          return failures.attempt(
            phase: ReSyncPhase.agentLinks,
            itemType: ReSyncItemType.agentLink,
            itemId: row.id,
            action: () async {
              var toSend = preparedLink ??= AgentDbConversions.fromLinkRow(row);
              toSend = await stampIfClockless(
                toSend,
                toSend.vectorClock,
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
              preparedLink = toSend;
              await outboxService.enqueueMessageOrThrow(
                SyncMessage.agentLink(
                  agentLink: toSend,
                  status: SyncEntryStatus.update,
                ),
              );
            },
          );
        },
        pageSize: pageSize,
        onProgress:
            ({
              required int processed,
              required int total,
              required bool isComplete,
              required int failed,
            }) {
              onProgress?.call(
                ReSyncProgress(
                  phase: ReSyncPhase.agentLinks,
                  processed: processed,
                  total: total,
                  isComplete: isComplete,
                  failed: failed,
                ),
              );
            },
      );
    }
    return failures.result;
  }

  Future<void> _reSyncPaginated<T>({
    required Future<int> Function() countFetcher,
    required Future<List<T>> Function(int limit, int offset) itemsFetcher,
    required Future<bool> Function(T item) enqueueAction,
    required int pageSize,
    void Function({
      required int processed,
      required int total,
      required bool isComplete,
      required int failed,
    })?
    onProgress,
  }) async {
    final count = await countFetcher();
    if (count == 0) {
      onProgress?.call(
        processed: 0,
        total: 0,
        isComplete: true,
        failed: 0,
      );
      return;
    }

    final pages = (count / pageSize).ceil();
    var processed = 0;
    var failed = 0;
    onProgress?.call(
      processed: 0,
      total: count,
      isComplete: false,
      failed: 0,
    );
    for (var page = 0; page < pages; page++) {
      final items = await itemsFetcher(pageSize, page * pageSize);
      for (final item in items) {
        final queued = await enqueueAction(item);
        if (!queued) failed++;
      }
      processed += items.length;
      onProgress?.call(
        processed: processed,
        total: count,
        isComplete: page == pages - 1,
        failed: failed,
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
