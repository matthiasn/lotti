import 'dart:io';

import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/features/sync/queue/inbound_worker.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

const _logDomain = 'sync';
const _logSub = 'queue.apply';

/// Bridges [InboundWorker] to the existing
/// [SyncEventProcessor.prepare]/[SyncEventProcessor.apply] path.
///
/// The queue keeps events as JSON and hands the worker an
/// [InboundQueueEntry]. This adapter materialises the Event against the
/// current Room, runs prepare outside a write transaction, and runs
/// apply inside a short `journalDb.transaction` — mirroring the P1
/// freeze fix the legacy pipeline already shipped (PR #2981).
class QueueApplyAdapter {
  QueueApplyAdapter({
    required SyncEventProcessor processor,
    required JournalDb journalDb,
    required LoggingService logging,
  }) : _processor = processor,
       _journalDb = journalDb,
       _logging = logging;

  final SyncEventProcessor _processor;
  final JournalDb _journalDb;
  final LoggingService _logging;

  /// Returns an [InboundApplyFn] ready to wire into an [InboundWorker].
  InboundApplyFn bind() => _applyOne;

  Future<ApplyOutcome> _applyOne(
    InboundQueueEntry entry,
    Room room,
  ) async {
    // Step 1 — materialise the Event. `Event.fromJson` requires a live
    // Room reference; we do not attempt to recover from a throw here
    // because the stored JSON is produced by `Event.toJson()` from a
    // fully-decrypted event (F3) so construction failures imply the
    // row is unrecoverable.
    final Event event;
    try {
      event = entry.toEvent(room);
    } catch (error, stackTrace) {
      _logging.captureException(
        error,
        domain: _logDomain,
        subDomain: '$_logSub.deserialise',
        stackTrace: stackTrace,
      );
      return ApplyOutcome.permanentSkip;
    }

    // Step 2 — prepare outside the writer transaction. Downloads,
    // gzip-decompresses, decodes sync payload. FileSystem / network
    // failures are retriable; SyncEventProcessor returns null when the
    // payload is undeserialisable (ArgumentError / FormatException
    // paths inside prepare).
    final PreparedSyncEvent? prepared;
    try {
      prepared = await _processor.prepare(event: event);
    } on FileSystemException catch (error, stackTrace) {
      _logging.captureException(
        error,
        domain: _logDomain,
        subDomain: '$_logSub.prepare.retriable',
        stackTrace: stackTrace,
      );
      return ApplyOutcome.retriable;
    } catch (error, stackTrace) {
      // Unknown error classes (TypeError, StateError, ArgumentError,
      // …) are not transient; retrying them just burns attempts and
      // keeps the entry in the queue until maxAttempts gives up. Treat
      // them as permanent so a logic bug does not stall the worker.
      _logging.captureException(
        error,
        domain: _logDomain,
        subDomain: '$_logSub.prepare.failed',
        stackTrace: stackTrace,
      );
      return ApplyOutcome.permanentSkip;
    }
    if (prepared == null) {
      _logging.captureEvent(
        'queue.apply.undeserialisable eventId=${entry.eventId}',
        domain: _logDomain,
        subDomain: _logSub,
      );
      return ApplyOutcome.permanentSkip;
    }

    // Step 3 — apply inside the writer transaction. Short by design
    // (pure DB work); attachment I/O already resolved above.
    try {
      await _journalDb.transaction(() async {
        await _processor.apply(
          prepared: prepared!,
          journalDb: _journalDb,
        );
      });
      return ApplyOutcome.applied;
    } on FileSystemException catch (error, stackTrace) {
      _logging.captureException(
        error,
        domain: _logDomain,
        subDomain: '$_logSub.apply.retriable',
        stackTrace: stackTrace,
      );
      return ApplyOutcome.retriable;
    } catch (error, stackTrace) {
      // Apply runs pure DB writes on pre-resolved state. A throw here
      // is almost always a logic bug or schema mismatch, not a
      // transient failure; retrying it just burns attempts. Skip
      // permanently so the worker moves on.
      _logging.captureException(
        error,
        domain: _logDomain,
        subDomain: '$_logSub.apply.failed',
        stackTrace: stackTrace,
      );
      return ApplyOutcome.permanentSkip;
    }
  }
}
