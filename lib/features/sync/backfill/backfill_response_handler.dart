import 'dart:async';

import 'package:lotti/database/database.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/state/backfill_config_controller.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:meta/meta.dart';

/// Handler for incoming backfill requests and responses.
/// Responds to backfill requests from other devices by looking up entries
/// in the sequence log and sending them (or a "deleted" response if purged).
///
/// Includes a per-counter response cooldown to prevent the same counter from
/// being responded to repeatedly across multiple request cycles (N-device
/// amplification prevention).
class BackfillResponseHandler {
  BackfillResponseHandler({
    required JournalDb journalDb,
    required SyncSequenceLogService sequenceLogService,
    required OutboxService outboxService,
    required LoggingService loggingService,
    required VectorClockService vectorClockService,
    DomainLogger? domainLogger,
    @visibleForTesting Duration? responseCooldown,
  }) : _journalDb = journalDb,
       _sequenceLogService = sequenceLogService,
       _outboxService = outboxService,
       _loggingService = loggingService,
       _vectorClockService = vectorClockService,
       _domainLogger = domainLogger,
       _responseCooldown =
           responseCooldown ?? SyncTuning.backfillResponseCooldown;

  final JournalDb _journalDb;
  final SyncSequenceLogService _sequenceLogService;
  final OutboxService _outboxService;
  final LoggingService _loggingService;
  final VectorClockService _vectorClockService;
  final DomainLogger? _domainLogger;
  final Duration _responseCooldown;

  /// Agent repository, injected after construction to avoid circular
  /// dependency. When set, backfill can look up agent entities and links.
  AgentRepository? agentRepository;

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
      LogDomains.sync,
      message,
      subDomain: subDomain ?? 'backfill',
    );
  }

  /// Build the cooldown cache key for a (hostId, counter) pair.
  static String _cooldownKey(String hostId, int counter) => '$hostId:$counter';

  /// Check if a (hostId, counter) pair was recently responded to.
  /// Returns true if the pair is within the cooldown period.
  bool _isRecentlyResponded(String hostId, int counter) {
    final lastResponse = recentlyResponded[_cooldownKey(hostId, counter)];
    if (lastResponse == null) return false;
    return DateTime.now().difference(lastResponse) < _responseCooldown;
  }

  /// Record that a (hostId, counter) pair was responded to.
  void _recordResponse(String hostId, int counter) {
    recentlyResponded[_cooldownKey(hostId, counter)] = DateTime.now();
  }

  /// Periodically clean expired entries from the cooldown cache.
  /// Called at the start of each request batch.
  void _cleanExpiredCooldowns() {
    final now = DateTime.now();
    recentlyResponded.removeWhere(
      (_, timestamp) => now.difference(timestamp) >= _responseCooldown,
    );
  }

  /// Check if the rate limit has been reached for the current time window.
  bool _isRateLimited() {
    final now = DateTime.now();
    if (windowStart == null ||
        now.difference(windowStart!) >= SyncTuning.backfillResponseRateWindow) {
      // Start a new window
      windowStart = now;
      responsesInWindow = 0;
      return false;
    }
    return responsesInWindow >= SyncTuning.backfillResponseRateLimit;
  }

  /// Send a "deleted" backfill response indicating the payload no longer exists.
  Future<void> _sendDeletedResponse({
    required String hostId,
    required int counter,
    required SyncSequencePayloadType payloadType,
  }) async {
    await _outboxService.enqueueMessage(
      SyncMessage.backfillResponse(
        hostId: hostId,
        counter: counter,
        deleted: true,
        payloadType: payloadType,
      ),
    );
  }

  /// Send an "unresolvable" backfill response indicating the originating host
  /// cannot resolve its own counter (e.g., it was superseded before being recorded).
  Future<void> _sendUnresolvableResponse({
    required String hostId,
    required int counter,
    SyncSequencePayloadType? payloadType,
  }) async {
    await _outboxService.enqueueMessage(
      SyncMessage.backfillResponse(
        hostId: hostId,
        counter: counter,
        deleted: false,
        unresolvable: true,
        payloadType: payloadType,
      ),
    );

    _trace(
      'sendUnresolvableResponse hostId=$hostId counter=$counter payloadType=$payloadType',
      subDomain: 'backfill.unresolvable',
    );
  }

  /// Load the vector clock for a payload by type and ID.
  /// Used to verify covering entries before using them.
  Future<VectorClock?> _loadPayloadVectorClock({
    required String payloadId,
    required SyncSequencePayloadType payloadType,
  }) async {
    switch (payloadType) {
      case SyncSequencePayloadType.journalEntity:
        final entry = await _journalDb.journalEntityById(payloadId);
        return entry?.meta.vectorClock;
      case SyncSequencePayloadType.entryLink:
        final link = await _journalDb.entryLinkById(payloadId);
        return link?.vectorClock;
      case SyncSequencePayloadType.agentEntity:
        return (await agentRepository?.getEntity(payloadId))?.vectorClock;
      case SyncSequencePayloadType.agentLink:
        return (await agentRepository?.getLinkById(payloadId))?.vectorClock;
    }
  }

  Future<SyncSequenceLogItem?> _findVerifiedCoveringEntry({
    required String hostId,
    required int requestedCounter,
    required int searchFromCounter,
  }) async {
    var nextCounter = searchFromCounter;

    while (true) {
      final covering = await _sequenceLogService.getNearestCoveringEntry(
        hostId,
        nextCounter,
      );

      if (covering == null || covering.entryId == null) {
        return null;
      }

      final payloadType = SyncSequencePayloadType.values.elementAt(
        covering.payloadType,
      );
      final coveringVc = await _loadPayloadVectorClock(
        payloadId: covering.entryId!,
        payloadType: payloadType,
      );
      final coveringVcCounter = coveringVc?.vclock[hostId];

      if (coveringVcCounter != null && coveringVcCounter >= requestedCounter) {
        _trace(
          'using verified covering entry '
          'hostId=$hostId requestedCounter=$requestedCounter '
          'coveringCounter=${covering.counter} '
          'coveringVcCounter=$coveringVcCounter '
          'payloadId=${covering.entryId}',
          subDomain: 'backfill.coveringFallback',
        );
        return covering;
      }

      _trace(
        'covering entry VC does not cover counter, skipping to next '
        'hostId=$hostId requestedCounter=$requestedCounter '
        'coveringCounter=${covering.counter} '
        'payloadId=${covering.entryId} '
        'coveringVcCounter=$coveringVcCounter',
        subDomain: 'backfill.coveringRejected',
      );

      nextCounter = covering.counter + 1;
    }
  }

  /// When the VC doesn't contain the exact counter, decide whether to send
  /// a hint (VC is ahead, so the entry supersedes the counter) or an
  /// unresolvable response (VC is behind, so the mapping is permanently
  /// wrong and will never self-heal).
  Future<void> _sendHintOrUnresolvable({
    required String hostId,
    required int counter,
    required String payloadId,
    required SyncSequencePayloadType payloadType,
    required int? vcCounter,
    String? legacyEntryId,
  }) async {
    final myHost = await _vectorClockService.getHost();
    if (myHost != null &&
        hostId == myHost &&
        (vcCounter == null || vcCounter < counter)) {
      _trace(
        'VC permanently behind counter, sending unresolvable '
        'hostId=$hostId counter=$counter '
        'payloadId=$payloadId vcCounter=$vcCounter',
        subDomain: 'backfill.vcBehind',
      );
      await _sendUnresolvableResponse(
        hostId: hostId,
        counter: counter,
        payloadType: payloadType,
      );
      return;
    }

    await _outboxService.enqueueMessage(
      SyncMessage.backfillResponse(
        hostId: hostId,
        counter: counter,
        deleted: false,
        entryId: legacyEntryId,
        payloadType: payloadType,
        payloadId: payloadId,
      ),
    );
  }

  /// Attempt to verify a payload exists locally and mark as backfilled.
  /// Loads the payload using [loadPayload], extracts its vector clock using
  /// [getVectorClock], and verifies/marks backfilled if found.
  Future<void> _tryVerifyAndMarkBackfilled<T>({
    required String hostId,
    required int counter,
    required String payloadId,
    required SyncSequencePayloadType payloadType,
    required Future<T?> Function() loadPayload,
    required VectorClock? Function(T) getVectorClock,
    required String payloadTypeName,
  }) async {
    final payload = await loadPayload();

    if (payload != null) {
      final vc = getVectorClock(payload);
      if (vc != null) {
        await _sequenceLogService.verifyAndMarkBackfilled(
          hostId: hostId,
          counter: counter,
          entryId: payloadId,
          entryVectorClock: vc,
          payloadType: payloadType,
        );
      }
    } else {
      _trace(
        '$payloadTypeName $payloadId not found locally, hint stored for when payload arrives',
        subDomain: 'backfill.response',
      );
    }
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

      // Limit entries to process to prevent outbox flooding
      final entriesToProcess =
          request.entries.length > SyncTuning.maxBackfillResponseBatchSize
          ? request.entries
                .take(SyncTuning.maxBackfillResponseBatchSize)
                .toList()
          : request.entries;

      final truncated =
          request.entries.length > SyncTuning.maxBackfillResponseBatchSize;

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
      _loggingService.captureException(
        e,
        domain: 'SYNC_BACKFILL',
        subDomain: 'handleRequest',
        stackTrace: st,
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
    // counter silently mis-maps state on the requester's side. For own-host
    // misses we therefore send `unresolvable` immediately — our sequence
    // log is authoritative for our own counters, so any miss is
    // definitively a burn.
    final myHost = await _vectorClockService.getHost();
    final isOwnHost = myHost != null && hostId == myHost;

    if (logEntry != null && logEntry.entryId != null) {
      final payloadType = SyncSequencePayloadType.values.elementAt(
        logEntry.payloadType,
      );
      final payloadVc = await _loadPayloadVectorClock(
        payloadId: logEntry.entryId!,
        payloadType: payloadType,
      );
      final vcCounter = payloadVc?.vclock[hostId];

      // An exact row is only safe to answer from when the current payload VC
      // still covers the requested counter. Otherwise the row is stale.
      if (payloadVc != null && (vcCounter == null || vcCounter < counter)) {
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
      _trace(
        'directLookup miss hostId=$hostId counter=$counter '
        'exists=${logEntry != null} entryId=${logEntry?.entryId} '
        'status=${logEntry?.status}',
        subDomain: 'backfill.directLookup',
      );

      if (isOwnHost) {
        // Burn: our sequence log has no entry for this own-host counter,
        // so no write ever carried it. Covering by a later (necessarily
        // different) entity would misattribute unrelated state to this
        // counter on the requester's side — always wrong for own-host
        // burns. Send unresolvable so the requester marks `status=5` and
        // skips the covering lookup entirely.
        _trace(
          'own-host miss → unresolvable (no covering attempted) '
          'hostId=$hostId counter=$counter',
          subDomain: 'backfill.unresolvable',
        );
        await _sendUnresolvableResponse(hostId: hostId, counter: counter);
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

    final resolvedLogEntry = logEntry;
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
          sentPayloads.add(payloadId);
          final jsonPath = relativeEntityPath(journalEntry);

          await _outboxService.enqueueMessage(
            SyncMessage.journalEntity(
              id: journalEntry.meta.id,
              jsonPath: jsonPath,
              vectorClock: journalEntry.meta.vectorClock,
              status: SyncEntryStatus.update,
              originatingHostId: originatingHostId,
            ),
          );
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
          sentPayloads.add(payloadId);

          await _outboxService.enqueueMessage(
            SyncMessage.entryLink(
              entryLink: link,
              status: SyncEntryStatus.update,
              originatingHostId: originatingHostId,
            ),
          );
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
          loadPayload: () => agentRepository!.getLinkById(payloadId),
          getVectorClock: (link) => link.vectorClock,
          buildSyncMessage: (link) => SyncMessage.agentLink(
            status: SyncEntryStatus.update,
            agentLink: link,
            originatingHostId: originatingHostId,
          ),
          typeName: 'agentLink',
        );
    }
  }

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
      sentPayloads.add(payloadId);
      await _outboxService.enqueueMessage(buildSyncMessage(payload));
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
        }
      }
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'SYNC_BACKFILL',
        subDomain: 'handleResponse',
        stackTrace: st,
      );
    }
  }
}
