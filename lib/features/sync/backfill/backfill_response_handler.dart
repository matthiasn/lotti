import 'package:lotti/database/database.dart';
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

/// Handler for incoming backfill requests and responses.
/// Responds to backfill requests from other devices by looking up entries
/// in the sequence log and sending them (or a "deleted" response if purged).
class BackfillResponseHandler {
  BackfillResponseHandler({
    required JournalDb journalDb,
    required SyncSequenceLogService sequenceLogService,
    required OutboxService outboxService,
    required LoggingService loggingService,
    required VectorClockService vectorClockService,
  })  : _journalDb = journalDb,
        _sequenceLogService = sequenceLogService,
        _outboxService = outboxService,
        _loggingService = loggingService,
        _vectorClockService = vectorClockService;

  final JournalDb _journalDb;
  final SyncSequenceLogService _sequenceLogService;
  final OutboxService _outboxService;
  final LoggingService _loggingService;
  final VectorClockService _vectorClockService;

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
        'handleBackfillRequest: processing ${entriesToProcess.length} of ${request.entries.length} entries from=${request.requesterId}${truncated ? ' (truncated)' : ''}',
        domain: 'SYNC_BACKFILL',
        subDomain: 'handleRequest',
      );

      var responded = 0;
      var skipped = 0;
      // Track payloads already sent in this batch to avoid sending the same
      // entry multiple times when multiple counters map to the same payload.
      final sentPayloads = <String>{};

      for (final entry in entriesToProcess) {
        final result = await _processBackfillEntry(
          hostId: entry.hostId,
          counter: entry.counter,
          sentPayloads: sentPayloads,
        );
        if (result) {
          responded++;
        } else {
          skipped++;
        }
      }

      _loggingService.captureEvent(
        'handleBackfillRequest: responded=$responded skipped=$skipped of ${request.entries.length} dedupedPayloads=${sentPayloads.length}',
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
    final myHost = await _vectorClockService.getHost();
    // Look up in our sequence log
    final logEntry = await _sequenceLogService.getEntryByHostAndCounter(
      hostId,
      counter,
    );

    if (logEntry == null || logEntry.entryId == null) {
      // We don't have this entry in our log
      // Check if we're the originator - if so, respond with unresolvable
      // since no one else can answer for our own counters
      if (myHost != null && hostId == myHost) {
        await _sendUnresolvableResponse(hostId: hostId, counter: counter);
        return true;
      }
      // Not our counter - ignore, another device might have it
      return false;
    }

    final payloadId = logEntry.entryId!;
    final payloadType =
        SyncSequencePayloadType.values.elementAt(logEntry.payloadType);

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
          // VC doesn't contain the counter - entry was modified since this
          // counter was created. Send BackfillResponse hint so the receiver
          // can map (hostId, counter) → entryId.
          if (myHost != null && hostId == myHost) {
            await _sendUnresolvableResponse(
              hostId: hostId,
              counter: counter,
              payloadType: payloadType,
            );
          } else {
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
          if (myHost != null && hostId == myHost) {
            await _sendUnresolvableResponse(
              hostId: hostId,
              counter: counter,
              payloadType: payloadType,
            );
          } else {
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
        }

        return true;
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
