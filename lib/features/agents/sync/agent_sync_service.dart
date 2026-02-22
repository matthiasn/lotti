import 'dart:async';

import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';

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
  })  : _repository = repository,
        _outboxService = outboxService;

  final AgentRepository _repository;
  final OutboxService _outboxService;

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
  /// until the outermost transaction commits.
  Future<void> upsertEntity(
    AgentDomainEntity entity, {
    bool fromSync = false,
  }) async {
    await _repository.upsertEntity(entity);
    if (!fromSync) {
      final message = SyncMessage.agentEntity(
        agentEntity: entity,
        status: SyncEntryStatus.update,
      );
      final txCtx = _currentTxContext;
      if (txCtx != null) {
        txCtx.pendingMessages.add(message);
      } else {
        await _outboxService.enqueueMessage(message);
      }
    }
  }

  /// Upsert an [AgentLink] and enqueue a sync message unless [fromSync]
  /// is `true`.
  ///
  /// When called inside [runInTransaction], the outbox enqueue is deferred
  /// until the outermost transaction commits.
  Future<void> upsertLink(
    AgentLink link, {
    bool fromSync = false,
  }) async {
    await _repository.upsertLink(link);
    if (!fromSync) {
      final message = SyncMessage.agentLink(
        agentLink: link,
        status: SyncEntryStatus.update,
      );
      final txCtx = _currentTxContext;
      if (txCtx != null) {
        txCtx.pendingMessages.add(message);
      } else {
        await _outboxService.enqueueMessage(message);
      }
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

    // Outermost: create an isolated context in a new zone.
    final ctx = _TransactionContext();
    try {
      final result = await runZoned(
        () => _repository.runInTransaction(action),
        zoneValues: {_txKey: ctx},
      );
      // Flush only after successful commit of the outermost transaction.
      // Process all messages even if individual enqueues fail, so that a
      // single failure doesn't silently drop the rest of the batch.
      Object? firstError;
      StackTrace? firstStack;
      for (final msg in ctx.pendingMessages) {
        try {
          await _outboxService.enqueueMessage(msg);
        } catch (e, s) {
          firstError ??= e;
          firstStack ??= s;
        }
      }
      if (firstError != null) {
        Error.throwWithStackTrace(firstError, firstStack!);
      }
      return result;
    } finally {
      ctx.pendingMessages.clear();
    }
  }
}
