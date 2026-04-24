import 'dart:async';

import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';

/// Per-chain transaction context, stored in a [Zone] value so that
/// concurrent transaction chains each have their own isolated buffer.
class _TransactionContext {
  final List<SyncMessage> pendingMessages = [];
}

/// Zone key used to look up the active [_TransactionContext].
const Symbol _txKey = #AgentSyncService_txKey;

/// Sync-aware write wrapper around [AgentRepository].
///
/// All **local** mutations go through this service so that each write is
/// automatically enqueued for cross-device sync via the outbox. Incoming sync
/// writes (from `SyncEventProcessor`) go directly to [AgentRepository] to
/// avoid echo loops — they do not pass through this service.
///
/// When `fromSync` is `true`, the outbox enqueue is skipped. This flag is
/// available for test flexibility but is not used in production; the incoming
/// sync path calls the repository directly instead.
///
/// ## Transaction awareness
///
/// When writes occur inside [runInTransaction], outbox messages are buffered
/// in a zone-local context and only flushed after the **outermost**
/// transaction commits successfully. If the transaction rolls back (throws),
/// the buffered messages are discarded, preventing ghost outbox entries for
/// writes that never committed.
///
/// Nesting is supported: inner [runInTransaction] calls detect the existing
/// zone context and delegate to the repository (Drift uses savepoints).
/// Only the outermost call flushes or discards the buffer.
///
/// Concurrent transaction chains are safe: each outermost [runInTransaction]
/// runs in its own [Zone] with an isolated [_TransactionContext], so
/// overlapping chains cannot corrupt each other's buffers.
///
/// Read operations are delegated to [repository] directly.
class AgentSyncService {
  AgentSyncService({
    required AgentRepository repository,
    required OutboxService outboxService,
    required VectorClockService vectorClockService,
  }) : _repository = repository,
       _outboxService = outboxService,
       _vectorClockService = vectorClockService;

  final AgentRepository _repository;
  final OutboxService _outboxService;
  final VectorClockService _vectorClockService;

  /// The underlying repository for read-only operations.
  AgentRepository get repository => _repository;

  /// Returns the active transaction context from the current [Zone], or
  /// `null` when called outside [runInTransaction].
  static _TransactionContext? get _currentTxContext =>
      Zone.current[_txKey] as _TransactionContext?;

  /// Upsert an [AgentDomainEntity] and enqueue a sync message unless
  /// [fromSync] is `true`.
  ///
  /// When called inside [runInTransaction], the outbox enqueue is deferred
  /// until the outermost transaction commits. The reserved vector clock is
  /// also bound to the outer transaction's scope so a rollback rewinds the
  /// counter without burning a Matrix-event-less slot.
  Future<void> upsertEntity(
    AgentDomainEntity entity, {
    bool fromSync = false,
  }) async {
    if (fromSync) {
      await _repository.upsertEntity(entity);
      return;
    }
    await _vectorClockService.withVcScope<void>(() async {
      final stamped = entity.copyWith(
        vectorClock: await _vectorClockService.getNextVectorClock(
          previous: entity.vectorClock,
        ),
      );
      await _repository.upsertEntity(stamped);
      // DB write succeeded — the VC is now baked into the persisted row
      // and MUST commit. Swallow any outbox failure so the scope's
      // default-commit-on-normal-return can fire.
      final message = SyncMessage.agentEntity(
        agentEntity: stamped,
        status: SyncEntryStatus.update,
      );
      final txCtx = _currentTxContext;
      if (txCtx != null) {
        txCtx.pendingMessages.add(message);
      } else {
        await _enqueuePostWrite(
          message,
          subDomain: 'upsertEntity.enqueue',
        );
      }
    });
  }

  /// Upsert an [AgentLink] and enqueue a sync message unless [fromSync]
  /// is `true`.
  ///
  /// When called inside [runInTransaction], the outbox enqueue is deferred
  /// until the outermost transaction commits. The reserved vector clock is
  /// also bound to the outer transaction's scope so a rollback rewinds the
  /// counter without burning a Matrix-event-less slot.
  Future<void> upsertLink(
    AgentLink link, {
    bool fromSync = false,
  }) async {
    if (fromSync) {
      await _repository.upsertLink(link);
      return;
    }
    await _vectorClockService.withVcScope<void>(() async {
      final stamped = link.copyWith(
        vectorClock: await _vectorClockService.getNextVectorClock(
          previous: link.vectorClock,
        ),
      );
      await _repository.upsertLink(stamped);
      // DB write succeeded — commit-on-write invariant: swallow outbox
      // failures so the scope still commits.
      final message = SyncMessage.agentLink(
        agentLink: stamped,
        status: SyncEntryStatus.update,
      );
      final txCtx = _currentTxContext;
      if (txCtx != null) {
        txCtx.pendingMessages.add(message);
      } else {
        await _enqueuePostWrite(
          message,
          subDomain: 'upsertLink.enqueue',
        );
      }
    });
  }

  /// Insert an [AgentLink] exclusively — throws a
  /// `DuplicateInsertException` if a unique constraint is violated (e.g. the
  /// partial unique index on `improver_target` links). On success, enqueues a
  /// sync message unless [fromSync] is `true`. A unique-constraint failure
  /// rolls back the reserved vector clock via the surrounding scope — the DB
  /// write never happened, so the counter was never claimed on disk.
  Future<void> insertLinkExclusive(
    AgentLink link, {
    bool fromSync = false,
  }) async {
    if (fromSync) {
      await _repository.insertLinkExclusive(link);
      return;
    }
    await _vectorClockService.withVcScope<void>(() async {
      final stamped = link.copyWith(
        vectorClock: await _vectorClockService.getNextVectorClock(
          previous: link.vectorClock,
        ),
      );
      await _repository.insertLinkExclusive(stamped);
      // Insert succeeded — commit-on-write invariant applies.
      final message = SyncMessage.agentLink(
        agentLink: stamped,
        status: SyncEntryStatus.update,
      );
      final txCtx = _currentTxContext;
      if (txCtx != null) {
        txCtx.pendingMessages.add(message);
      } else {
        await _enqueuePostWrite(
          message,
          subDomain: 'insertLinkExclusive.enqueue',
        );
      }
    });
  }

  /// Run a post-DB-write outbox enqueue that MUST NOT propagate failures.
  ///
  /// Once [_repository] has accepted the row, the reserved VC counter is
  /// baked into the persisted entity. Letting an outbox exception propagate
  /// out of the surrounding [VectorClockService.withVcScope] would trigger
  /// a release — re-handing the same counter to a different entity on the
  /// next reservation (cross-entity collision on disk). Log, swallow,
  /// return. The gap on receivers is transient and backfill resolves it.
  Future<void> _enqueuePostWrite(
    SyncMessage message, {
    required String subDomain,
  }) async {
    try {
      await _outboxService.enqueueMessage(message);
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomains.sync,
        'outbox enqueue failed after DB write; VC already committed',
        error: exception,
        stackTrace: stackTrace,
        subDomain: subDomain,
      );
    }
  }

  /// Run [action] inside a database transaction with post-commit outbox flush.
  ///
  /// All [upsertEntity] and [upsertLink] calls within [action] buffer their
  /// outbox messages in a zone-local context. On successful commit of the
  /// **outermost** transaction, the buffered messages are flushed to the
  /// outbox. On failure (exception), the buffer is discarded so no ghost
  /// messages are enqueued for rolled-back writes.
  ///
  /// Nesting is supported: inner calls detect the existing zone context and
  /// delegate to the repository (which uses savepoints). If an inner call
  /// throws (savepoint rollback), the messages it buffered are removed from
  /// the shared buffer — even if the caller catches the exception and
  /// continues in the outer transaction. Only the outermost call creates the
  /// zone and performs the final flush/discard.
  ///
  /// Concurrent chains are safe: each outermost call runs in its own [Zone]
  /// with an isolated buffer.
  Future<T> runInTransaction<T>(Future<T> Function() action) async {
    final existingCtx = _currentTxContext;
    if (existingCtx != null) {
      // Nested: piggyback on the outermost chain's zone/buffer.
      // Snapshot the buffer length so that if the inner savepoint rolls back
      // (throws) but the caller catches and continues, we discard only the
      // messages added by this inner scope — preventing ghost outbox entries
      // for writes that were rolled back by the savepoint.
      final snapshot = existingCtx.pendingMessages.length;
      try {
        return await _repository.runInTransaction(action);
      } catch (_) {
        existingCtx.pendingMessages.removeRange(
          snapshot,
          existingCtx.pendingMessages.length,
        );
        rethrow;
      }
    }

    // Outermost: create an isolated context in a new zone, wrapped in a VC
    // scope so every vector clock reserved inside the transaction rolls back
    // if the transaction throws. Without this, a rollback would discard the
    // buffered outbox messages but leave the persisted counter advanced,
    // producing a gap on receivers for counters that never rode a Matrix event.
    final ctx = _TransactionContext();
    Object? deferredEnqueueError;
    StackTrace? deferredEnqueueStack;
    try {
      final result = await _vectorClockService.withVcScope<T>(() async {
        final value = await runZoned(
          () => _repository.runInTransaction(action),
          zoneValues: {_txKey: ctx},
        );
        // Transaction committed → every VC reserved inside the transaction
        // is baked into persisted rows and MUST commit. Outbox-flush
        // failures beyond this point are deferred: we capture them and
        // rethrow OUTSIDE the VC scope so a transient enqueue error does
        // not trigger the scope's catch-and-release path and re-hand the
        // same counter to another entity on the next write.
        for (final msg in ctx.pendingMessages) {
          try {
            await _outboxService.enqueueMessage(msg);
          } catch (e, s) {
            deferredEnqueueError ??= e;
            deferredEnqueueStack ??= s;
          }
        }
        return value;
      });
      if (deferredEnqueueError != null) {
        Error.throwWithStackTrace(
          deferredEnqueueError!,
          deferredEnqueueStack!,
        );
      }
      return result;
    } finally {
      ctx.pendingMessages.clear();
    }
  }
}
