import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/services/logging_service.dart';
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
  })  : _journalDb = journalDb,
        _sequenceLogService = sequenceLogService,
        _outboxService = outboxService,
        _loggingService = loggingService;

  final JournalDb _journalDb;
  final SyncSequenceLogService _sequenceLogService;
  final OutboxService _outboxService;
  final LoggingService _loggingService;

  /// Handle an incoming batched backfill request from another device.
  /// Iterates over all requested entries and for each:
  /// - If we have the entry: re-send it via normal sync
  /// - If the entry was deleted/purged: send a deleted response
  /// - If we don't have it in our log: ignore (another device may have it)
  Future<void> handleBackfillRequest(SyncBackfillRequest request) async {
    try {
      _loggingService.captureEvent(
        'handleBackfillRequest: ${request.entries.length} entries from=${request.requesterId}',
        domain: 'SYNC_BACKFILL',
        subDomain: 'handleRequest',
      );

      var responded = 0;
      var skipped = 0;

      for (final entry in request.entries) {
        final result = await _processBackfillEntry(
          hostId: entry.hostId,
          counter: entry.counter,
        );
        if (result) {
          responded++;
        } else {
          skipped++;
        }
      }

      _loggingService.captureEvent(
        'handleBackfillRequest: responded=$responded skipped=$skipped of ${request.entries.length}',
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
  Future<bool> _processBackfillEntry({
    required String hostId,
    required int counter,
  }) async {
    // Look up in our sequence log
    final logEntry = await _sequenceLogService.getEntryByHostAndCounter(
      hostId,
      counter,
    );

    if (logEntry == null || logEntry.entryId == null) {
      // We don't have this entry in our log - ignore
      // Another device might have it and can respond
      return false;
    }

    // Check if entry exists in journal
    final journalEntry = await _journalDb.journalEntityById(logEntry.entryId!);

    if (journalEntry == null) {
      // Entry was deleted/purged - respond with deleted status
      await _outboxService.enqueueMessage(
        SyncMessage.backfillResponse(
          hostId: hostId,
          counter: counter,
          deleted: true,
        ),
      );
      return true;
    }

    // Entry exists - re-send it via normal sync mechanism
    // The sequence log will be updated when the recipient receives the entry
    final jsonPath = relativeEntityPath(journalEntry);

    await _outboxService.enqueueMessage(
      SyncMessage.journalEntity(
        id: journalEntry.meta.id,
        jsonPath: jsonPath,
        vectorClock: journalEntry.meta.vectorClock,
        status: SyncEntryStatus.update,
      ),
    );

    return true;
  }

  /// Handle an incoming backfill response from another device.
  /// Updates the sequence log status based on the response.
  Future<void> handleBackfillResponse(SyncBackfillResponse response) async {
    try {
      _loggingService.captureEvent(
        'handleBackfillResponse hostId=${response.hostId} counter=${response.counter} deleted=${response.deleted} entryId=${response.entryId}',
        domain: 'SYNC_BACKFILL',
        subDomain: 'handleResponse',
      );

      await _sequenceLogService.handleBackfillResponse(
        hostId: response.hostId,
        counter: response.counter,
        deleted: response.deleted,
        entryId: response.entryId,
      );
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
