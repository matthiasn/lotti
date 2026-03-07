import 'package:lotti/database/database.dart';
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
    @visibleForTesting Duration? responseCooldown,
  }) : _journalDb = journalDb,
       _sequenceLogService = sequenceLogService,
       _outboxService = outboxService,
       _loggingService = loggingService,
       _vectorClockService = vectorClockService,
       _responseCooldown =
           responseCooldown ?? SyncTuning.backfillResponseCooldown;

  final JournalDb _journalDb;
  final SyncSequenceLogService _sequenceLogService;
  final OutboxService _outboxService;
  final LoggingService _loggingService;
  final VectorClockService _vectorClockService;
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

    _loggingService.captureEvent(
      'sendUnresolvableResponse hostId=$hostId counter=$counter payloadType=$payloadType',
      domain: 'SYNC_BACKFILL',
      subDomain: 'unresolvable',
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
      _loggingService.captureEvent(
        'handleBackfillResponse: $payloadTypeName $payloadId not found locally, hint stored for when payload arrives',
        domain: 'SYNC_BACKFILL',
        subDomain: 'handleResponse',
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
      // Check if backfill is enabled
      final enabled = await isBackfillEnabled();
      if (!enabled) {
        _loggingService.captureEvent(
          'handleBackfillRequest: backfill disabled, ignoring ${request.entries.length} entries from=${request.requesterId}',
          domain: 'SYNC_BACKFILL',
          subDomain: 'handleRequest',
        );
        return;
      }

      // Clean expired cooldown entries at the start of each batch
      _cleanExpiredCooldowns();

      // Check rate limit before processing
      if (_isRateLimited()) {
        _loggingService.captureEvent(
          'handleBackfillRequest: rate limited, ignoring ${request.entries.length} entries from=${request.requesterId} ($responsesInWindow responses in current window)',
          domain: 'SYNC_BACKFILL',
          subDomain: 'rateLimited',
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

      _loggingService.captureEvent(
        'handleBackfillRequest: processing ${entriesToProcess.length} of ${request.entries.length} entries from=${request.requesterId}${truncated ? ' (truncated)' : ''} cooldownCache=${recentlyResponded.length}',
        domain: 'SYNC_BACKFILL',
        subDomain: 'handleRequest',
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
          continue;
        }

        // Stop if rate limit reached mid-batch
        if (_isRateLimited()) {
          rateLimitSkipped =
              entriesToProcess.length - responded - skipped - cooldownSkipped;
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

      _loggingService.captureEvent(
        'handleBackfillRequest: responded=$responded skipped=$skipped cooldownSkipped=$cooldownSkipped rateLimitSkipped=$rateLimitSkipped of ${request.entries.length} dedupedPayloads=${sentPayloads.length}',
        domain: 'SYNC_BACKFILL',
        subDomain: 'handleRequest',
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
    final logEntry = await _sequenceLogService.getEntryByHostAndCounter(
      hostId,
      counter,
    );

    if (logEntry == null || logEntry.entryId == null) {
      // We don't have this entry in our log
      // Check if we're the originator - if so, respond with unresolvable
      // since no one else can answer for our own counters
      final myHost = await _vectorClockService.getHost();
      if (myHost != null && hostId == myHost) {
        await _sendUnresolvableResponse(hostId: hostId, counter: counter);
        return true;
      }
      // Not our counter - ignore, another device might have it
      return false;
    }

    final payloadId = logEntry.entryId!;
    final payloadType = SyncSequencePayloadType.values.elementAt(
      logEntry.payloadType,
    );

    // Use the originatingHostId from the sequence log entry, or fall back to
    // the requested hostId.
    final originatingHostId = logEntry.originatingHostId ?? hostId;

    switch (payloadType) {
      case SyncSequencePayloadType.journalEntity:
        // Check if entry exists in journal
        final journalEntry = await _journalDb.journalEntityById(payloadId);

        if (journalEntry == null) {
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
          // VC doesn't contain the exact counter — the entry was modified
          // since this counter was created (superseded by a later VC).
          // Send a hint with payloadId so the receiver can map
          // (hostId, counter) → payloadId and mark it as backfilled.
          // This applies equally for own and foreign counters — previously
          // own counters were incorrectly marked "unresolvable" which
          // prevented resolution and caused amplification loops.
          await _outboxService.enqueueMessage(
            SyncMessage.backfillResponse(
              hostId: hostId,
              counter: counter,
              deleted: false,
              entryId: payloadId, // legacy compatibility (journal only)
              payloadType: payloadType,
              payloadId: payloadId,
            ),
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
          // Send hint — same logic as journalEntity above.
          // No legacy entryId field — entryLink was added after payloadId.
          await _outboxService.enqueueMessage(
            SyncMessage.backfillResponse(
              hostId: hostId,
              counter: counter,
              deleted: false,
              payloadType: payloadType,
              payloadId: payloadId,
            ),
          );
        }

        return true;
      case SyncSequencePayloadType.agentEntity:
        if (agentRepository == null) {
          _loggingService.captureEvent(
            'backfill: agentRepository not wired, skipping agentEntity $payloadId',
            domain: 'SYNC_BACKFILL',
            subDomain: 'processEntry',
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
          _loggingService.captureEvent(
            'backfill: agentRepository not wired, skipping agentLink $payloadId',
            domain: 'SYNC_BACKFILL',
            subDomain: 'processEntry',
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
      await _outboxService.enqueueMessage(
        SyncMessage.backfillResponse(
          hostId: hostId,
          counter: counter,
          deleted: false,
          payloadType: payloadType,
          payloadId: payloadId,
        ),
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

      _loggingService.captureEvent(
        'handleBackfillResponse hostId=${response.hostId} counter=${response.counter} deleted=${response.deleted} unresolvable=${response.unresolvable} payloadType=$payloadType payloadId=$payloadId entryId=${response.entryId}',
        domain: 'SYNC_BACKFILL',
        subDomain: 'handleResponse',
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
