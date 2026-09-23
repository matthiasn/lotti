import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/notifications_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:lotti/features/ai_consumption/repository/consumption_repository.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/onboarding/onboarding_sync_service.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/state/backfill_config_controller.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:meta/meta.dart';

part 'backfill_response_builders.dart';

/// How [BackfillResponseHandler.settleOwnCounter] left an own-host counter.
enum OwnCounterSettlement {
  /// Its named payload covers it: bound to that payload and resent.
  bound,

  /// No payload carries it: burned, and the room was told so.
  burned,

  /// Not decidable yet: a live write may still land it, its reservation does
  /// not name the payload, or the payload's store is not wired yet.
  deferred,

  /// Something else already bound or burned it; nothing was done.
  alreadySettled,
}

/// Handler for incoming backfill requests and responses.
/// Responds to backfill requests from other devices by looking up entries
/// in the sequence log and sending them (or a "deleted" response if purged).
///
/// Includes a per-counter response cooldown to prevent the same counter from
/// being responded to repeatedly across multiple request cycles (N-device
/// amplification prevention).
class BackfillResponseHandler {
  BackfillResponseHandler({
    required this._journalDb,
    required this._sequenceLogService,
    required this._outboxService,
    required this._loggingService,
    required this._vectorClockService,
    this._domainLogger,
    this._notificationsDb,
    this._onboardingSyncService,
    @visibleForTesting Duration? responseCooldown,
  }) : _responseCooldown =
           responseCooldown ?? SyncTuning.backfillResponseCooldown;

  final JournalDb _journalDb;
  final SyncSequenceLogService _sequenceLogService;
  final OutboxService _outboxService;
  final DomainLogger _loggingService;
  final VectorClockService _vectorClockService;
  final DomainLogger? _domainLogger;
  final NotificationsDb? _notificationsDb;
  final OnboardingSyncService? _onboardingSyncService;
  final Duration _responseCooldown;

  /// Agent repository, injected after construction to avoid circular
  /// dependency. When set, backfill can look up agent entities and links.
  ///
  /// Own counters whose settlement waited for this store are settled again
  /// once it is wired.
  AgentRepository? get agentRepository => _agentRepository;
  set agentRepository(AgentRepository? repository) {
    _agentRepository = repository;
    _retrySettlementAwaitingStore();
  }

  AgentRepository? _agentRepository;

  /// Consumption repository, injected after construction (same rationale as
  /// [agentRepository]). When set, backfill can look up consumption events.
  ConsumptionRepository? get consumptionRepository => _consumptionRepository;
  set consumptionRepository(ConsumptionRepository? repository) {
    _consumptionRepository = repository;
    _retrySettlementAwaitingStore();
  }

  ConsumptionRepository? _consumptionRepository;

  /// Set when an orphaned own counter could not be settled because its
  /// payload store was not wired yet.
  bool _settlementAwaitsStore = false;

  /// Tracks recently-responded (hostId, counter) pairs with their timestamp
  /// to prevent duplicate responses across request cycles.
  @visibleForTesting
  final recentlyResponded = <String, DateTime>{};

  /// Track total responses in the current time window for rate limiting.
  @visibleForTesting
  int responsesInWindow = 0;
  @visibleForTesting
  DateTime? windowStart;

  /// Log a backfill trace message to the sync domain logger (separate file).
  void _trace(String message, {String? subDomain}) {
    _domainLogger?.log(
      LogDomain.sync,
      message,
      subDomain: subDomain ?? 'backfill',
    );
  }

  /// Settle an own-host counter that nothing has bound yet: no row, a
  /// `reserved` row, or a released (`burnPending`) one. This is the single
  /// decision every own-counter path uses — the backfill responder, the VC
  /// release handler and startup reconciliation — and it is what
  /// `specs/tla/SyncSequence.tla` model-checks as `Settle` and `Respond`:
  ///
  /// 1. If the reservation names its payload (on the row, in the settings
  ///    database record kept when the row insert failed, or in the live
  ///    process's pending map) and that payload's own-host clock covers the
  ///    counter, the write landed — or a later write of the same payload
  ///    superseded it. Bind the counter and resend the payload.
  /// 2. Otherwise, if this process may still land the counter, or the
  ///    payload's store is not wired yet, defer.
  /// 3. Otherwise, if a `reserved` row does not name its payload, nothing can
  ///    prove it either way: defer.
  /// 4. Otherwise no payload carries the counter: burn it authoritatively.
  ///
  /// Whether the counter is pending is read before the payload clock. A
  /// counter that is not pending cannot become pending again, so its payload
  /// cannot land between the two reads and turn a burn into a false one.
  ///
  /// [sentPayloads] deduplicates resends within one request batch.
  Future<OwnCounterSettlement> settleOwnCounter({
    required String hostId,
    required int counter,
    Set<String>? sentPayloads,
  }) async => _settleOwnCounter(
    hostId: hostId,
    counter: counter,
    row: await _sequenceLogService.getEntryByHostAndCounter(hostId, counter),
    sentPayloads: sentPayloads,
  );

  /// [settleOwnCounter] for a caller that has already read the counter's
  /// sequence [row].
  Future<OwnCounterSettlement> _settleOwnCounter({
    required String hostId,
    required int counter,
    required SyncSequenceLogItem? row,
    Set<String>? sentPayloads,
  }) async {
    final status = row == null ? null : SyncSequenceStatus.values[row.status];
    if (status != null &&
        status != SyncSequenceStatus.reserved &&
        status != SyncSequenceStatus.burnPending) {
      return OwnCounterSettlement.alreadySettled;
    }

    final pending = _vectorClockService.isPending(
      hostId: hostId,
      counter: counter,
    );
    // A reservation whose sequence-log insert failed lives in the settings
    // database until startup migrates it; it counts as a `reserved` row.
    final fallback = row == null
        ? await _vectorClockService.unrecordedReservation(
            hostId: hostId,
            counter: counter,
          )
        : null;
    final reserved = status == SyncSequenceStatus.reserved || fallback != null;
    final rowEntryId = row?.entryId;
    final payload = rowEntryId != null
        ? (
            id: rowEntryId,
            type: SyncSequencePayloadType.values[row!.payloadType],
          )
        : fallback?.payload ??
              _vectorClockService.pendingPayload(
                hostId: hostId,
                counter: counter,
              );

    if (payload != null) {
      if (!_payloadStoreWired(payload.type)) {
        _settlementAwaitsStore = true;
        _trace(
          'settleOwnCounter deferred: ${payload.type.name} store not wired '
          'hostId=$hostId counter=$counter',
          subDomain: 'backfill.settle',
        );
        return OwnCounterSettlement.deferred;
      }
      final state = await _loadPayloadClockState(
        payloadId: payload.id,
        payloadType: payload.type,
      );
      final ownCounter = state.vectorClock?.vclock[hostId];
      if (state.exists && ownCounter != null && ownCounter >= counter) {
        // Resend first, bind after: the row stays unsettled until the payload
        // is durably queued, so a failed or interrupted resend is retried by
        // the next request or startup instead of hiding behind `received`.
        // A crash in between at worst sends the payload twice.
        final now = clock.now();
        await _answerFromEntry(
          hostId: hostId,
          counter: counter,
          entry: SyncSequenceLogItem(
            hostId: hostId,
            counter: counter,
            entryId: payload.id,
            payloadType: payload.type.index,
            originatingHostId: hostId,
            status: SyncSequenceStatus.received.index,
            createdAt: now,
            updatedAt: now,
            requestCount: 0,
          ),
          sentPayloads: sentPayloads ?? <String>{},
          durable: true,
        );
        final bound = await _sequenceLogService.bindOwnCounter(
          hostId: hostId,
          counter: counter,
          entryId: payload.id,
          payloadType: payload.type,
        );
        _trace(
          'settleOwnCounter resent hostId=$hostId counter=$counter '
          'payloadId=${payload.id} type=${payload.type.name} '
          'payloadCounter=$ownCounter bound=$bound',
          subDomain: 'backfill.settle',
        );
        return bound
            ? OwnCounterSettlement.bound
            : OwnCounterSettlement.alreadySettled;
      }
    }

    if (pending) {
      _trace(
        'settleOwnCounter deferred: reservation still live '
        'hostId=$hostId counter=$counter',
        subDomain: 'backfill.settle',
      );
      return OwnCounterSettlement.deferred;
    }
    if (reserved && payload == null) {
      _trace(
        'settleOwnCounter deferred: reservation names no payload '
        'hostId=$hostId counter=$counter',
        subDomain: 'backfill.settle',
      );
      return OwnCounterSettlement.deferred;
    }

    await _sendUnresolvableResponse(
      hostId: hostId,
      counter: counter,
      payloadType: payload?.type,
    );
    return OwnCounterSettlement.burned;
  }

  /// Startup reconciliation: settle every own counter an earlier process left
  /// unsettled — released reservations still `burnPending`, and `reserved`
  /// rows that name their payload. Reservations this process has made since
  /// it started are pending and stay deferred.
  Future<void> settleOrphanedOwnCounters() async {
    await _vectorClockService.initialized;
    final hostId = await _vectorClockService.getHost();
    if (hostId == null) return;
    _settlementAwaitsStore = false;
    final counters = await _sequenceLogService.settleableOwnCountersForHost(
      hostId: hostId,
    );
    if (counters.isEmpty) return;

    final outcomes = <OwnCounterSettlement, int>{};
    final sentPayloads = <String>{};
    for (final counter in counters) {
      try {
        final outcome = await settleOwnCounter(
          hostId: hostId,
          counter: counter,
          sentPayloads: sentPayloads,
        );
        outcomes[outcome] = (outcomes[outcome] ?? 0) + 1;
      } catch (error, stackTrace) {
        _loggingService.error(
          LogDomain.sync,
          error,
          message:
              'own counter settlement failed host=$hostId counter=$counter; '
              'it is retried on the next startup',
          stackTrace: stackTrace,
          subDomain: 'backfill.settle',
        );
      }
    }
    _loggingService.log(
      LogDomain.sync,
      'settleOrphanedOwnCounters host=$hostId attempted=${counters.length} '
      '${[for (final e in outcomes.entries) '${e.key.name}=${e.value}'].join(' ')}',
      subDomain: 'backfill.settle',
    );
  }

  bool _payloadStoreWired(SyncSequencePayloadType type) => switch (type) {
    SyncSequencePayloadType.journalEntity ||
    SyncSequencePayloadType.entryLink => true,
    SyncSequencePayloadType.agentEntity ||
    SyncSequencePayloadType.agentLink => _agentRepository != null,
    SyncSequencePayloadType.notification ||
    SyncSequencePayloadType.notificationStateUpdate => _notificationsDb != null,
    SyncSequencePayloadType.consumptionEvent => _consumptionRepository != null,
  };

  void _retrySettlementAwaitingStore() {
    if (!_settlementAwaitsStore) return;
    unawaited(
      settleOrphanedOwnCounters().catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        _loggingService.error(
          LogDomain.sync,
          error,
          message: 'own counter settlement retry failed',
          stackTrace: stackTrace,
          subDomain: 'backfill.settle',
        );
      }),
    );
  }

  /// Handle an incoming batched backfill request from another device.
  /// Iterates over all requested entries and for each:
  /// - If we have the entry: re-send it via normal sync
  /// - If the entry was deleted/purged: send a deleted response
  /// - If we don't have it in our log: ignore (another device may have it)
  ///
  /// Note: If backfill is disabled, requests are silently ignored to conserve
  /// bandwidth on metered/slow networks.
  Future<void> handleBackfillRequest(SyncBackfillRequest request) async {
    try {
      // Skip our own backfill requests — they echo back via the Matrix room
      // after the SentEventRegistry TTL expires. Without this guard, we'd
      // process our own requests in a hot-loop.
      await _vectorClockService.initialized;
      final myHost = await _vectorClockService.getHost();
      if (myHost != null && request.requesterId == myHost) {
        _trace(
          'skipping own request (${request.entries.length} entries)',
          subDomain: 'backfill.skipSelf',
        );
        return;
      }

      // Check if backfill is enabled
      final enabled = await isBackfillEnabled();
      if (!enabled) {
        _trace(
          'backfill disabled, ignoring ${request.entries.length} entries from=${request.requesterId}',
          subDomain: 'backfill.disabled',
        );
        return;
      }

      // Clean expired cooldown entries at the start of each batch
      _cleanExpiredCooldowns();

      // Check rate limit before processing
      if (_isRateLimited()) {
        _trace(
          'rate limited, ignoring ${request.entries.length} entries from=${request.requesterId} ($responsesInWindow responses in current window)',
          subDomain: 'backfill.rateLimited',
        );
        return;
      }

      final onboardingCoverage = await _onboardingSyncService
          ?.activeOutboundCoverageForRequester(request.requesterId);
      final coverageFilteredEntries = onboardingCoverage == null
          ? request.entries
          : request.entries
                .where(
                  (entry) =>
                      entry.counter > (onboardingCoverage[entry.hostId] ?? -1),
                )
                .toList();
      // Covered stale requests must not consume the response cap and hide a
      // genuine uncovered request later in the same event.
      final entriesToProcess =
          coverageFilteredEntries.length >
              SyncTuning.maxBackfillResponseBatchSize
          ? coverageFilteredEntries
                .take(SyncTuning.maxBackfillResponseBatchSize)
                .toList()
          : coverageFilteredEntries;

      final truncated =
          coverageFilteredEntries.length >
          SyncTuning.maxBackfillResponseBatchSize;

      _trace(
        'handleRequest: processing ${entriesToProcess.length} of ${request.entries.length} entries from=${request.requesterId}${truncated ? ' (truncated)' : ''} cooldownCache=${recentlyResponded.length}',
        subDomain: 'backfill.request',
      );

      var responded = 0;
      var skipped = 0;
      var cooldownSkipped = 0;
      var rateLimitSkipped = 0;
      // Track payloads already sent in this batch to avoid sending the same
      // entry multiple times when multiple counters map to the same payload.
      final sentPayloads = <String>{};

      for (final entry in entriesToProcess) {
        // Skip if recently responded to this (hostId, counter)
        if (_isRecentlyResponded(entry.hostId, entry.counter)) {
          cooldownSkipped++;
          _trace(
            'cooldown skip hostId=${entry.hostId} counter=${entry.counter}',
            subDomain: 'backfill.cooldownSkip',
          );
          continue;
        }

        // Stop if rate limit reached mid-batch
        if (_isRateLimited()) {
          rateLimitSkipped =
              entriesToProcess.length - responded - skipped - cooldownSkipped;
          _trace(
            'rate limited, stopping batch. rateLimitSkipped=$rateLimitSkipped',
            subDomain: 'backfill.rateLimitStop',
          );
          break;
        }

        final result = await _processBackfillEntry(
          hostId: entry.hostId,
          counter: entry.counter,
          sentPayloads: sentPayloads,
        );
        if (result) {
          responded++;
          _recordResponse(entry.hostId, entry.counter);
          responsesInWindow++;
        } else {
          skipped++;
        }
      }

      _trace(
        'handleRequest: responded=$responded skipped=$skipped cooldownSkipped=$cooldownSkipped rateLimitSkipped=$rateLimitSkipped of ${request.entries.length} dedupedPayloads=${sentPayloads.length}',
        subDomain: 'backfill.request',
      );
    } catch (e, st) {
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'handleRequest',
      );
    }
  }

  /// Handle an incoming backfill response from another device.
  ///
  /// For deleted responses: marks the entry as deleted (cannot be backfilled).
  ///
  /// For non-deleted responses: stores the entryId as a "hint", then verifies
  /// the entry exists locally and its VC covers the requested (hostId, counter)
  /// before marking as backfilled. This ensures we don't mark entries as
  /// backfilled until we actually have the data.
  Future<void> handleBackfillResponse(SyncBackfillResponse response) async {
    try {
      final payloadType =
          response.payloadType ?? SyncSequencePayloadType.journalEntity;
      final payloadId = response.payloadId ?? response.entryId;

      _trace(
        'handleResponse hostId=${response.hostId} counter=${response.counter} deleted=${response.deleted} unresolvable=${response.unresolvable} payloadType=$payloadType payloadId=$payloadId entryId=${response.entryId}',
        subDomain: 'backfill.response',
      );

      // First, store the hint (or mark as deleted/unresolvable for those responses)
      await _sequenceLogService.handleBackfillResponse(
        hostId: response.hostId,
        counter: response.counter,
        deleted: response.deleted,
        unresolvable: response.unresolvable ?? false,
        entryId: payloadId,
        payloadType: payloadType,
      );

      // For non-deleted, non-unresolvable responses, verify the entry exists
      // locally before marking as backfilled
      if (!response.deleted &&
          !(response.unresolvable ?? false) &&
          payloadId != null) {
        switch (payloadType) {
          case SyncSequencePayloadType.journalEntity:
            await _tryVerifyAndMarkBackfilled(
              hostId: response.hostId,
              counter: response.counter,
              payloadId: payloadId,
              payloadType: payloadType,
              loadPayload: () => _journalDb.journalEntityById(payloadId),
              getVectorClock: (entry) => entry.meta.vectorClock,
              payloadTypeName: 'journal entry',
            );
          case SyncSequencePayloadType.entryLink:
            await _tryVerifyAndMarkBackfilled(
              hostId: response.hostId,
              counter: response.counter,
              payloadId: payloadId,
              payloadType: payloadType,
              loadPayload: () => _journalDb.entryLinkById(payloadId),
              getVectorClock: (link) => link.vectorClock,
              payloadTypeName: 'entryLink',
            );
          case SyncSequencePayloadType.agentEntity:
            if (agentRepository != null) {
              await _tryVerifyAndMarkBackfilled(
                hostId: response.hostId,
                counter: response.counter,
                payloadId: payloadId,
                payloadType: payloadType,
                loadPayload: () => agentRepository!.getEntity(payloadId),
                getVectorClock: (entity) => entity.vectorClock,
                payloadTypeName: 'agentEntity',
              );
            }
          case SyncSequencePayloadType.agentLink:
            if (agentRepository != null) {
              await _tryVerifyAndMarkBackfilled(
                hostId: response.hostId,
                counter: response.counter,
                payloadId: payloadId,
                payloadType: payloadType,
                loadPayload: () => agentRepository!.getLinkById(payloadId),
                getVectorClock: (link) => link.vectorClock,
                payloadTypeName: 'agentLink',
              );
            }
          case SyncSequencePayloadType.notification:
            if (_notificationsDb != null) {
              await _tryVerifyAndMarkBackfilled(
                hostId: response.hostId,
                counter: response.counter,
                payloadId: payloadId,
                payloadType: payloadType,
                loadPayload: () => _notificationsDb.notificationById(
                  payloadId,
                ),
                getVectorClock: (notification) => notification.meta.vectorClock,
                payloadTypeName: 'notification',
              );
            }
          case SyncSequencePayloadType.notificationStateUpdate:
            if (_notificationsDb != null) {
              await _tryVerifyAndMarkBackfilled(
                hostId: response.hostId,
                counter: response.counter,
                payloadId: payloadId,
                payloadType: payloadType,
                loadPayload: () => _notificationsDb.notificationById(
                  payloadId,
                ),
                getVectorClock: (notification) => notification.meta.vectorClock,
                payloadTypeName: 'notificationStateUpdate',
              );
            }
          case SyncSequencePayloadType.consumptionEvent:
            if (consumptionRepository != null) {
              await _tryVerifyAndMarkBackfilled(
                hostId: response.hostId,
                counter: response.counter,
                payloadId: payloadId,
                payloadType: payloadType,
                loadPayload: () => consumptionRepository!.getEvent(payloadId),
                getVectorClock: (event) => event.vectorClock,
                payloadTypeName: 'consumptionEvent',
              );
            }
        }
      }
    } catch (e, st) {
      _loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: st,
        subDomain: 'handleResponse',
      );
    }
  }

  /// Process a single backfill entry request.
  /// Returns true if we responded, false if skipped.
  ///
  /// [sentPayloads] tracks payloads already sent in this batch to avoid
  /// sending the same entry multiple times when multiple counters map to
  /// the same payload.
  Future<bool> _processBackfillEntry({
    required String hostId,
    required int counter,
    required Set<String> sentPayloads,
  }) async {
    // Look up in our sequence log
    var logEntry = await _sequenceLogService.getEntryByHostAndCounter(
      hostId,
      counter,
    );

    // Own-host requests can ONLY be answered from a direct exact-match row
    // whose payload VC currently covers the requested counter. Covering by a
    // later entity is unsound for own-host burns: a burnt counter has no
    // recorded entity, so any "covering" candidate is necessarily a
    // DIFFERENT entity and its payload does not carry whatever the burnt
    // write would have mutated. Attributing that payload to the burnt
    // counter silently mis-maps state on the requester's side. An own counter
    // nothing has bound yet — no row, a reservation, or a released
    // reservation — is settled from its own named payload instead; see
    // [settleOwnCounter].
    final myHost = await _vectorClockService.getHost();
    final isOwnHost = myHost != null && hostId == myHost;

    final ownRowUnsettled =
        logEntry == null ||
        logEntry.status == SyncSequenceStatus.reserved.index ||
        logEntry.status == SyncSequenceStatus.burnPending.index;
    if (isOwnHost && ownRowUnsettled) {
      final OwnCounterSettlement outcome;
      try {
        outcome = await _settleOwnCounter(
          hostId: hostId,
          counter: counter,
          row: logEntry,
          sentPayloads: sentPayloads,
        );
      } catch (error, stackTrace) {
        // The row stays unsettled; the requester asks again.
        _loggingService.error(
          LogDomain.sync,
          error,
          message:
              'own counter settlement failed hostId=$hostId '
              'counter=$counter; left unsettled for a later request',
          stackTrace: stackTrace,
          subDomain: 'backfill.settle',
        );
        return false;
      }
      if (outcome != OwnCounterSettlement.alreadySettled) {
        return outcome != OwnCounterSettlement.deferred;
      }
      // Settled concurrently: answer from the row as it now stands.
      logEntry = await _sequenceLogService.getEntryByHostAndCounter(
        hostId,
        counter,
      );
    }

    if (logEntry != null && logEntry.entryId != null) {
      final payloadType = SyncSequencePayloadType.values.elementAt(
        logEntry.payloadType,
      );
      final payloadState = await _loadPayloadClockState(
        payloadId: logEntry.entryId!,
        payloadType: payloadType,
      );
      final vcCounter = payloadState.vectorClock?.vclock[hostId];

      // An exact row is only safe to answer from when the current payload VC
      // still covers the requested counter. A payload that exists without a
      // vector clock proves no counter at all. Missing/deleted payloads stay on
      // the per-type path below so they produce a deleted response instead.
      if (payloadState.exists && (vcCounter == null || vcCounter < counter)) {
        _trace(
          'exact entry VC does not cover counter, rejecting '
          'hostId=$hostId requestedCounter=$counter '
          'logCounter=${logEntry.counter} payloadId=${logEntry.entryId} '
          'vcCounter=$vcCounter',
          subDomain: 'backfill.exactRejected',
        );
        if (isOwnHost) {
          // Own-host: do not attempt covering. The stale row means the VC
          // regressed or the payload is orphaned — either way, the
          // counter is unresolvable from our authoritative position.
          await _sendUnresolvableResponse(
            hostId: hostId,
            counter: counter,
            payloadType: payloadType,
          );
          return true;
        }
        logEntry = await _findVerifiedCoveringEntry(
          hostId: hostId,
          requestedCounter: counter,
          searchFromCounter: counter + 1,
        );

        if (logEntry == null) {
          return false;
        }
      }
    }

    if (logEntry == null || logEntry.entryId == null) {
      final payloadType = logEntry == null
          ? null
          : SyncSequencePayloadType.values.elementAt(logEntry.payloadType);
      _trace(
        'directLookup miss hostId=$hostId counter=$counter '
        'exists=${logEntry != null} entryId=${logEntry?.entryId} '
        'status=${logEntry?.status} payloadType=$payloadType',
        subDomain: 'backfill.directLookup',
      );

      if (isOwnHost) {
        // An own counter whose row carries no payload, and which settlement
        // above left alone: it is already burned. Covering by a later
        // (necessarily different) entity would misattribute unrelated state
        // to this counter on the requester's side — always wrong for
        // own-host burns. Repeat the authoritative unresolvable marker.
        _trace(
          'own-host miss → unresolvable (no covering attempted) '
          'hostId=$hostId counter=$counter payloadType=$payloadType',
          subDomain: 'backfill.unresolvable',
        );
        await _sendUnresolvableResponse(
          hostId: hostId,
          counter: counter,
          payloadType: payloadType,
        );
        return true;
      }

      // Foreign-host counter: we are only a relay, not the originator. A
      // best-effort covering hint can still help the requester close the
      // gap if the covering entity coincidentally matches; otherwise skip.
      final covering = await _findVerifiedCoveringEntry(
        hostId: hostId,
        requestedCounter: counter,
        searchFromCounter: counter,
      );

      if (covering != null) {
        logEntry = covering;
      } else {
        _trace(
          'foreign-host counter not found, skipping '
          'hostId=$hostId counter=$counter myHost=$myHost',
          subDomain: 'backfill.notFound',
        );
        return false;
      }
    }

    return _answerFromEntry(
      hostId: hostId,
      counter: counter,
      entry: logEntry,
      sentPayloads: sentPayloads,
    );
  }

  /// Answer a request for `(hostId, counter)` from the payload [entry] names:
  /// resend the payload (once per batch, tracked in [sentPayloads]) plus a
  /// mapping hint when the payload's clock does not carry the exact counter,
  /// or a `deleted` response when the payload is gone.
  ///
  /// With [durable], a failure to enqueue the payload propagates instead of
  /// being logged and swallowed, so settlement can bind the counter only once
  /// the resend is durably queued.
  Future<bool> _answerFromEntry({
    required String hostId,
    required int counter,
    required SyncSequenceLogItem entry,
    required Set<String> sentPayloads,
    bool durable = false,
  }) async {
    final resolvedLogEntry = entry;
    final payloadId = resolvedLogEntry.entryId!;
    final payloadType = SyncSequencePayloadType.values.elementAt(
      resolvedLogEntry.payloadType,
    );

    // Use the originatingHostId from the sequence log entry, or fall back to
    // the requested hostId.
    final originatingHostId = resolvedLogEntry.originatingHostId ?? hostId;

    _trace(
      'found logEntry hostId=$hostId counter=$counter '
      'payloadId=$payloadId payloadType=$payloadType '
      'logCounter=${resolvedLogEntry.counter} origHost=$originatingHostId',
      subDomain: 'backfill.found',
    );

    switch (payloadType) {
      case SyncSequencePayloadType.journalEntity:
        // Check if entry exists in journal
        final journalEntry = await _journalDb.journalEntityById(payloadId);

        if (journalEntry == null) {
          _trace(
            'journal entry deleted '
            'hostId=$hostId counter=$counter payloadId=$payloadId',
            subDomain: 'backfill.deleted',
          );
          await _sendDeletedResponse(
            hostId: hostId,
            counter: counter,
            payloadType: payloadType,
          );
          return true;
        }

        // Only send the entry if not already sent in this batch.
        // This avoids sending the same entry multiple times when multiple
        // requested counters map to the same payload.
        if (!sentPayloads.contains(payloadId)) {
          final jsonPath = relativeEntityPath(journalEntry);

          await _enqueuePayload(
            durable: durable,
            SyncMessage.journalEntity(
              id: journalEntry.meta.id,
              jsonPath: jsonPath,
              vectorClock: journalEntry.meta.vectorClock,
              status: SyncEntryStatus.update,
              originatingHostId: originatingHostId,
              // The requester is missing this entry entirely, so it is also
              // missing any media the entry references — send the blob with
              // the JSON rather than leaving an unrenderable entry behind.
              includeAttachments: true,
            ),
          );
          sentPayloads.add(payloadId);
        }

        // Check if the entry's current VC contains the exact requested counter.
        // If yes, the entry arrival will automatically resolve this counter
        // via recordReceivedEntry, so we don't need to send a BackfillResponse.
        // Note: We check for exact match (==) not >= because recordReceivedEntry
        // only records counters that ARE in the VC, not historical counters.
        // This optimization significantly reduces redundant network traffic.
        final vcCounter = journalEntry.meta.vectorClock?.vclock[hostId];
        final vcContainsCounter = vcCounter != null && vcCounter == counter;

        if (!vcContainsCounter) {
          await _sendHintOrUnresolvable(
            hostId: hostId,
            counter: counter,
            payloadId: payloadId,
            payloadType: payloadType,
            vcCounter: vcCounter,
            legacyEntryId: payloadId,
          );
        }

        return true;
      case SyncSequencePayloadType.entryLink:
        final link = await _journalDb.entryLinkById(payloadId);

        if (link == null) {
          await _sendDeletedResponse(
            hostId: hostId,
            counter: counter,
            payloadType: payloadType,
          );
          return true;
        }

        // Only send the link if not already sent in this batch.
        if (!sentPayloads.contains(payloadId)) {
          await _enqueuePayload(
            durable: durable,
            SyncMessage.entryLink(
              entryLink: link,
              status: SyncEntryStatus.update,
              originatingHostId: originatingHostId,
            ),
          );
          sentPayloads.add(payloadId);
        }

        // Check if the link's current VC contains the exact requested counter.
        // If yes, skip the BackfillResponse as entry arrival handles it.
        final vcCounter = link.vectorClock?.vclock[hostId];
        final vcContainsCounter = vcCounter != null && vcCounter == counter;

        if (!vcContainsCounter) {
          await _sendHintOrUnresolvable(
            hostId: hostId,
            counter: counter,
            payloadId: payloadId,
            payloadType: payloadType,
            vcCounter: vcCounter,
          );
        }

        return true;
      case SyncSequencePayloadType.agentEntity:
        if (agentRepository == null) {
          _trace(
            'agentRepository not wired, skipping agentEntity $payloadId',
            subDomain: 'backfill.processEntry',
          );
          return false;
        }
        return _processAgentBackfillEntry<AgentDomainEntity>(
          hostId: hostId,
          counter: counter,
          payloadId: payloadId,
          payloadType: payloadType,
          originatingHostId: originatingHostId,
          sentPayloads: sentPayloads,
          durable: durable,
          loadPayload: () => agentRepository!.getEntity(payloadId),
          getVectorClock: (entity) => entity.vectorClock,
          buildSyncMessage: (entity) => SyncMessage.agentEntity(
            status: SyncEntryStatus.update,
            agentEntity: entity,
            originatingHostId: originatingHostId,
          ),
          typeName: 'agentEntity',
        );
      case SyncSequencePayloadType.agentLink:
        if (agentRepository == null) {
          _trace(
            'agentRepository not wired, skipping agentLink $payloadId',
            subDomain: 'backfill.processEntry',
          );
          return false;
        }
        return _processAgentBackfillEntry<AgentLink>(
          hostId: hostId,
          counter: counter,
          payloadId: payloadId,
          payloadType: payloadType,
          originatingHostId: originatingHostId,
          sentPayloads: sentPayloads,
          durable: durable,
          loadPayload: () => agentRepository!.getLinkById(payloadId),
          getVectorClock: (link) => link.vectorClock,
          buildSyncMessage: (link) => SyncMessage.agentLink(
            status: SyncEntryStatus.update,
            agentLink: link,
            originatingHostId: originatingHostId,
          ),
          typeName: 'agentLink',
        );
      case SyncSequencePayloadType.notification:
        final db = _notificationsDb;
        if (db == null) {
          _trace(
            'notificationsDb not wired, skipping notification $payloadId',
            subDomain: 'backfill.processEntry',
          );
          return false;
        }
        final notification = await db.notificationById(payloadId);
        if (notification == null) {
          await _sendDeletedResponse(
            hostId: hostId,
            counter: counter,
            payloadType: payloadType,
          );
          return true;
        }

        if (!sentPayloads.contains(payloadId)) {
          await _outboxService.enqueueNotification(
            notification,
            originatingHostId: originatingHostId,
            rethrowFailure: durable,
          );
          sentPayloads.add(payloadId);
        }

        final vcCounter = notification.meta.vectorClock.vclock[hostId];
        final vcContainsCounter = vcCounter != null && vcCounter == counter;

        if (!vcContainsCounter) {
          await _sendHintOrUnresolvable(
            hostId: hostId,
            counter: counter,
            payloadId: payloadId,
            payloadType: payloadType,
            vcCounter: vcCounter,
          );
        }

        return true;
      case SyncSequencePayloadType.notificationStateUpdate:
        final db = _notificationsDb;
        if (db == null) {
          _trace(
            'notificationsDb not wired, skipping notificationStateUpdate $payloadId',
            subDomain: 'backfill.processEntry',
          );
          return false;
        }
        final notification = await db.notificationById(payloadId);
        if (notification == null) {
          await _sendDeletedResponse(
            hostId: hostId,
            counter: counter,
            payloadType: payloadType,
          );
          return true;
        }

        if (!sentPayloads.contains('state:$payloadId')) {
          await _outboxService.enqueueNotificationStateUpdate(
            id: notification.meta.id,
            seenAt: notification.meta.seenAt,
            actedOnAt: notification.meta.actedOnAt,
            deletedAt: notification.meta.deletedAt,
            vectorClock: notification.meta.vectorClock,
            originatingHostId: originatingHostId,
            rethrowFailure: durable,
          );
          sentPayloads.add('state:$payloadId');
        }

        final vcCounter = notification.meta.vectorClock.vclock[hostId];
        final vcContainsCounter = vcCounter != null && vcCounter == counter;

        if (!vcContainsCounter) {
          await _sendHintOrUnresolvable(
            hostId: hostId,
            counter: counter,
            payloadId: payloadId,
            payloadType: payloadType,
            vcCounter: vcCounter,
          );
        }

        return true;
      case SyncSequencePayloadType.consumptionEvent:
        if (consumptionRepository == null) {
          _trace(
            'consumptionRepository not wired, skipping consumptionEvent '
            '$payloadId',
            subDomain: 'backfill.processEntry',
          );
          return false;
        }
        // Reuses the generic agent-backfill helper (immutable payload, inline
        // re-enqueue) — the "Agent" name is historical; it is type-generic.
        return _processAgentBackfillEntry<AiConsumptionEvent>(
          hostId: hostId,
          counter: counter,
          payloadId: payloadId,
          payloadType: payloadType,
          originatingHostId: originatingHostId,
          sentPayloads: sentPayloads,
          durable: durable,
          loadPayload: () => consumptionRepository!.getEvent(payloadId),
          getVectorClock: (event) => event.vectorClock,
          buildSyncMessage: (event) => SyncMessage.consumptionEvent(
            status: SyncEntryStatus.update,
            event: event,
            originatingHostId: originatingHostId,
          ),
          typeName: 'consumptionEvent',
        );
    }
  }

  /// Enqueue a payload resend; see [_answerFromEntry] for [durable].
  Future<void> _enqueuePayload(
    SyncMessage message, {
    required bool durable,
  }) => durable
      ? _outboxService.enqueueMessageOrThrow(message)
      : _outboxService.enqueueMessage(message);

  /// Shared helper for processing agent entity/link backfill entries.
  /// Follows the same pattern as journalEntity/entryLink cases.
  Future<bool> _processAgentBackfillEntry<T>({
    required String hostId,
    required int counter,
    required String payloadId,
    required SyncSequencePayloadType payloadType,
    required String originatingHostId,
    required Set<String> sentPayloads,
    required Future<T?> Function() loadPayload,
    required VectorClock? Function(T) getVectorClock,
    required SyncMessage Function(T) buildSyncMessage,
    required String typeName,
    bool durable = false,
  }) async {
    final payload = await loadPayload();

    if (payload == null) {
      await _sendDeletedResponse(
        hostId: hostId,
        counter: counter,
        payloadType: payloadType,
      );
      return true;
    }

    if (!sentPayloads.contains(payloadId)) {
      await _enqueuePayload(durable: durable, buildSyncMessage(payload));
      sentPayloads.add(payloadId);
    }

    final vc = getVectorClock(payload);
    final vcCounter = vc?.vclock[hostId];
    final vcContainsCounter = vcCounter != null && vcCounter == counter;

    if (!vcContainsCounter) {
      await _sendHintOrUnresolvable(
        hostId: hostId,
        counter: counter,
        payloadId: payloadId,
        payloadType: payloadType,
        vcCounter: vcCounter,
      );
    }

    return true;
  }
}
