import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_db_conversions.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as agent_model;
import 'package:lotti/features/agents/state/agent_providers.dart'
    show agentRepositoryProvider;
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart'
    show journalDbProvider, outboxServiceProvider;
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

/// A snapshot emitted while [HistoricalSyncService.reSyncInterval] visits one phase.
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

/// Receives progress snapshots from [HistoricalSyncService.reSyncInterval].
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
    required Set<String> dependencyItemIds,
    required Future<void> Function() retryAction,
  }) {
    final error = StateError(
      'Historical sync deferred because dependencies '
      '${dependencyItemIds.join(', ')} were not queued',
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

Set<String> _blockedDependencies(
  Map<String, bool> queueState,
  String fromId,
  String toId,
) => {fromId, toId}.where((id) => queueState[id] == false).toSet();

/// Stages persisted journal and agent history into the Sync outbox.
///
/// Database and repository collaborators own raw row access. This service owns
/// the Sync-specific orchestration around decoding, dependency ordering,
/// progress, per-item failure isolation, and targeted retry.
class HistoricalSyncService {
  factory HistoricalSyncService({
    required JournalDb journalDb,
    required AgentRepository agentRepository,
    required OutboxService outboxService,
    required VectorClockService vectorClockService,
    required DomainLogger logger,
  }) => HistoricalSyncService._(
    journalDb: journalDb,
    agentRepository: agentRepository,
    outboxService: outboxService,
    vectorClockService: vectorClockService,
    logger: logger,
  );

  HistoricalSyncService._({
    required this._journalDb,
    required this._agentRepository,
    required this._outboxService,
    required this._vectorClockService,
    required this._logger,
  });

  final JournalDb _journalDb;
  final AgentRepository _agentRepository;
  final OutboxService _outboxService;
  final VectorClockService _vectorClockService;
  final DomainLogger _logger;

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
  /// no-op and emits a single Sync log entry so the skip is visible
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
    bool includeJournalEntities = true,
    bool includeAgentEntities = true,
    ReSyncProgressCallback? onProgress,
  }) async {
    if (!includeJournalEntities && !includeAgentEntities) {
      _logger.log(
        LogDomain.sync,
        'reSyncInterval skipped — both entity-type filters disabled',
        subDomain: 'reSyncInterval',
      );
      return ReSyncResult.empty;
    }

    final failures = _ReSyncFailureCollector(_logger);
    final hostId = await _vectorClockService.getHost();
    const pageSize = 100;

    if (includeJournalEntities) {
      var processed = 0;
      var failed = 0;
      final entryQueueState = <String, bool>{};
      final pendingLinkRows = <LinkedDbEntry>[];
      onProgress?.call(
        const ReSyncProgress(
          phase: ReSyncPhase.journalEntities,
          processed: 0,
          isComplete: false,
        ),
      );

      // Queue every journal row before its links. The full interval's queue
      // state must be known before a link can safely decide whether either
      // endpoint failed, including a target that lives on a later page.
      for (var page = 0; ; page++) {
        final dbEntities = await _journalDb
            .orderedJournalInterval(start, end, pageSize, page * pageSize)
            .get();
        if (dbEntities.isEmpty) break;

        final pageEntryIds = dbEntities.map((row) => row.id).toList();
        for (final id in pageEntryIds) {
          entryQueueState[id] = false;
        }
        pendingLinkRows.addAll(
          await _journalDb.linkRowsFromIdsIncludingHidden(pageEntryIds),
        );

        for (final dbEntity in dbEntities) {
          JournalEntity? preparedEntry;
          final queued = await failures.attempt(
            phase: ReSyncPhase.journalEntities,
            itemType: ReSyncItemType.journalEntity,
            itemId: dbEntity.id,
            action: () async {
              final entry = preparedEntry ??= fromDbEntity(dbEntity);
              await _outboxService.enqueueMessageOrThrow(
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
              entryQueueState[dbEntity.id] = true;
            },
          );
          processed++;
          if (!queued) failed++;
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

      for (final entryLinkRow in pendingLinkRows) {
        EntryLink? preparedLink;
        Future<void> enqueueLink() async {
          final blocked = _blockedDependencies(
            entryQueueState,
            entryLinkRow.fromId,
            entryLinkRow.toId,
          );
          if (blocked.isNotEmpty) {
            throw StateError(
              'Journal link dependencies ${blocked.join(', ')} are not queued',
            );
          }
          final entryLink = preparedLink ??= entryLinkFromLinkedDbEntry(
            entryLinkRow,
          );
          await _outboxService.enqueueMessageOrThrow(
            SyncMessage.entryLink(
              status: SyncEntryStatus.update,
              entryLink: entryLink,
            ),
          );
        }

        final blocked = _blockedDependencies(
          entryQueueState,
          entryLinkRow.fromId,
          entryLinkRow.toId,
        );
        if (blocked.isNotEmpty) {
          failures.defer(
            phase: ReSyncPhase.journalEntities,
            itemType: ReSyncItemType.entryLink,
            itemId: entryLinkRow.id,
            dependencyItemIds: blocked,
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

      onProgress?.call(
        ReSyncProgress(
          phase: ReSyncPhase.journalEntities,
          processed: processed,
          total: processed,
          isComplete: true,
          failed: failed,
        ),
      );
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
      final agentEntityQueueState = <String, bool>{};
      // 2. Re-sync agent entities and links updated in the same interval.
      await _reSyncPaginated(
        countFetcher: () => _agentRepository.countEntitiesInInterval(
          start: start,
          end: end,
        ),
        itemsFetcher: (limit, offset) =>
            _agentRepository.getEntityRowsInInterval(
              start: start,
              end: end,
              limit: limit,
              offset: offset,
            ),
        enqueueAction: (row) async {
          agentEntityQueueState[row.id] = false;
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
                (e) => _vectorClockService.withVcScope<AgentDomainEntity>(
                  () async {
                    final stamped = e.copyWith(
                      vectorClock: await _vectorClockService.getNextVectorClock(
                        previous: e.vectorClock,
                      ),
                    );
                    await _agentRepository.upsertEntity(stamped);
                    return stamped;
                  },
                ),
              );
              preparedEntity = toSend;
              await _outboxService.enqueueMessageOrThrow(
                SyncMessage.agentEntity(
                  agentEntity: toSend,
                  status: SyncEntryStatus.update,
                ),
              );
              agentEntityQueueState[row.id] = true;
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
        countFetcher: () => _agentRepository.countLinksInInterval(
          start: start,
          end: end,
        ),
        itemsFetcher: (limit, offset) => _agentRepository.getLinkRowsInInterval(
          start: start,
          end: end,
          limit: limit,
          offset: offset,
        ),
        enqueueAction: (row) async {
          agent_model.AgentLink? preparedLink;
          Future<void> enqueueLink() async {
            final blocked = _blockedDependencies(
              agentEntityQueueState,
              row.fromId,
              row.toId,
            );
            if (blocked.isNotEmpty) {
              throw StateError(
                'Agent link dependencies ${blocked.join(', ')} are not queued',
              );
            }
            var toSend = preparedLink ??= AgentDbConversions.fromLinkRow(row);
            toSend = await stampIfClockless(
              toSend,
              toSend.vectorClock,
              (l) => _vectorClockService.withVcScope<agent_model.AgentLink>(
                () async {
                  final stamped = l.copyWith(
                    vectorClock: await _vectorClockService.getNextVectorClock(
                      previous: l.vectorClock,
                    ),
                  );
                  await _agentRepository.upsertLink(stamped);
                  return stamped;
                },
              ),
            );
            preparedLink = toSend;
            await _outboxService.enqueueMessageOrThrow(
              SyncMessage.agentLink(
                agentLink: toSend,
                status: SyncEntryStatus.update,
              ),
            );
          }

          final blocked = _blockedDependencies(
            agentEntityQueueState,
            row.fromId,
            row.toId,
          );
          if (blocked.isNotEmpty) {
            failures.defer(
              phase: ReSyncPhase.agentLinks,
              itemType: ReSyncItemType.agentLink,
              itemId: row.id,
              dependencyItemIds: blocked,
              retryAction: enqueueLink,
            );
            return false;
          }
          return failures.attempt(
            phase: ReSyncPhase.agentLinks,
            itemType: ReSyncItemType.agentLink,
            itemId: row.id,
            action: enqueueLink,
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
}

/// Sync-owned historical staging service assembled from the app's shared
/// persistence and outbox providers.
final historicalSyncServiceProvider = Provider<HistoricalSyncService>(
  (ref) => HistoricalSyncService(
    journalDb: ref.watch(journalDbProvider),
    agentRepository: ref.watch(agentRepositoryProvider),
    outboxService: ref.watch(outboxServiceProvider),
    vectorClockService: getIt<VectorClockService>(),
    logger: getIt<DomainLogger>(),
  ),
  name: 'historicalSyncServiceProvider',
);
