import 'dart:async';

import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';

/// Per-chain transaction context, stored in a [Zone] value so that
/// concurrent transaction chains each have their own isolated buffer.
class _TransactionContext {
  final List<SyncMessage> pendingMessages = [];
  final List<Future<void> Function()> pendingSequenceBindings = [];
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
    required this._repository,
    required this._outboxService,
    required this._vectorClockService,
    this.sequenceLogService,
  });

  final AgentRepository _repository;
  final OutboxService _outboxService;
  final VectorClockService _vectorClockService;
  final SyncSequenceLogService? sequenceLogService;

  /// The underlying repository for read-only operations.
  AgentRepository get repository => _repository;

  /// Returns the active transaction context from the current [Zone], or
  /// `null` when called outside [runInTransaction].
  static _TransactionContext? get _currentTxContext =>
      Zone.current[_txKey] as _TransactionContext?;

  SyncSequenceLogService? get _sequenceLog =>
      sequenceLogService ??
      (getIt.isRegistered<SyncSequenceLogService>()
          ? getIt<SyncSequenceLogService>()
          : null);

  Future<void> _recordAgentEntitySequence(AgentDomainEntity entity) async {
    final service = _sequenceLog;
    final vectorClock = entity.vectorClock;
    if (service == null || vectorClock == null) return;
    try {
      await service.recordSentEntry(
        entryId: entity.id,
        vectorClock: vectorClock,
        payloadType: SyncSequencePayloadType.agentEntity,
      );
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.sync,
        exception,
        message:
            'sequence record failed after agent entity write; VC already committed',
        stackTrace: stackTrace,
        subDomain: 'agentSync.recordEntity',
      );
    }
  }

  Future<void> _recordAgentLinkSequence(AgentLink link) async {
    final service = _sequenceLog;
    final vectorClock = link.vectorClock;
    if (service == null || vectorClock == null) return;
    try {
      await service.recordSentEntry(
        entryId: link.id,
        vectorClock: vectorClock,
        payloadType: SyncSequencePayloadType.agentLink,
      );
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.sync,
        exception,
        message:
            'sequence record failed after agent link write; VC already committed',
        stackTrace: stackTrace,
        subDomain: 'agentSync.recordLink',
      );
    }
  }

  /// Upsert an [AgentDomainEntity] and enqueue a sync message unless
  /// [fromSync] is `true`.
  ///
  /// Local (non-sync) **message** writes are routed through the causal-DAG
  /// append path ([_appendMessage]) so every persisted message is chained into
  /// the log and advances the agent's head — no call site can bypass it. Every
  /// other entity (and sync-received messages, which already carry their edge)
  /// goes straight to the raw upsert.
  Future<void> upsertEntity(
    AgentDomainEntity entity, {
    bool fromSync = false,
  }) async {
    if (!fromSync && entity is AgentMessageEntity) {
      return _appendMessage(entity);
    }
    return _upsertEntityRaw(entity, fromSync: fromSync);
  }

  /// Raw upsert: VC-stamp, persist, and enqueue (or defer inside a
  /// transaction). Bypasses the message-append routing in [upsertEntity].
  ///
  /// When called inside [runInTransaction], the outbox enqueue is deferred
  /// until the outermost transaction commits. The reserved vector clock is
  /// also bound to the outer transaction's scope so a rollback releases the
  /// counter through the normal burn path instead of binding it to a payload
  /// that never committed.
  Future<void> _upsertEntityRaw(
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
        txCtx.pendingSequenceBindings.add(
          () => _recordAgentEntitySequence(stamped),
        );
        txCtx.pendingMessages.add(message);
      } else {
        await _recordAgentEntitySequence(stamped);
        await _enqueueOrBufferPostWrite(
          message,
          subDomain: 'upsertEntity.enqueue',
        );
      }
    });
  }

  /// Appends a local [message] to the agent's log, wiring it into the causal
  /// DAG: the message's `prevMessageId` and a `messagePrev` link point at the
  /// agent's current head (`AgentStateEntity.recentHeadMessageId`), and the head
  /// then advances to the new message.
  ///
  /// Reached from [upsertEntity] for every local message write, so chaining
  /// can't be bypassed. Messages chain *across wakes* into one continuous
  /// per-agent history (the first message of a brand-new agent is a root). The
  /// message, its link, and the advanced head commit atomically inside
  /// [runInTransaction].
  ///
  /// **Idempotent.** A repeat upsert of an already-persisted message id (a retry
  /// or a content update) re-persists the row with its *existing* edge and stops
  /// — it does not re-chain. Without this, the retry would re-point
  /// `prevMessageId` at the current head: for the just-appended head that is a
  /// self-link (`m → m`, a 1-cycle the projection rejects), for an older message
  /// a back-edge — either way a cycle that corrupts the canonical chain.
  ///
  /// This is the only place `recentHeadMessageId` is maintained — it is
  /// otherwise declared-but-unwritten. Concurrent multi-device appends off one
  /// head produce a fork (≥2 heads), which the projection tolerates; joins are
  /// deferred (PR 6). Internal writes use [_upsertEntityRaw] to avoid recursing
  /// back through the [upsertEntity] message router.
  Future<void> _appendMessage(AgentMessageEntity message) async {
    await runInTransaction(() async {
      // Idempotency guard — see the docstring. Preserve the persisted edge so a
      // content update doesn't drop it; never re-chain an existing message.
      final existing = await _repository.getEntity(message.id);
      if (existing is AgentMessageEntity) {
        await _upsertEntityRaw(
          message.copyWith(prevMessageId: existing.prevMessageId),
        );
        return;
      }

      final state = await _repository.getAgentState(message.agentId);
      var head = state?.recentHeadMessageId;

      // A legacy agent has a state row whose head pointer was never written; on
      // the first append, chain its existing prefix into one spine so history is
      // continuous, then extend it (the head is persisted below, so this never
      // re-runs). Skip entirely when there is no state row: there is no head to
      // maintain, and re-scanning every append — the advanced head is never
      // persisted without a state row — would be quadratic.
      if (state != null && head == null) {
        head = await _backfillMessageChain(message.agentId);
      }

      await _upsertEntityRaw(
        head == null ? message : message.copyWith(prevMessageId: head),
      );

      if (head != null) {
        await upsertLink(
          AgentLink.messagePrev(
            id: 'msgprev-${message.id}',
            fromId: message.id,
            toId: head,
            createdAt: message.createdAt,
            updatedAt: message.createdAt,
            vectorClock: null,
          ),
        );
      }

      if (state != null) {
        await _upsertEntityRaw(
          state.copyWith(
            recentHeadMessageId: message.id,
            updatedAt: message.createdAt,
          ),
        );
      }
    });
  }

  /// One-time migration for a legacy agent: chains its existing (edge-less)
  /// messages into a single spine ordered by `(createdAt, id)`, creating
  /// content-addressed `messagePrev` links. Returns the resulting head (the
  /// last message's id), or null when the agent has no messages yet.
  ///
  /// Only the links are written (not the messages), so history is **not**
  /// re-stamped or re-synced — just `n-1` new edges. Link ids are derived from
  /// the child id, so two devices backfilling the same agent converge on the
  /// same edges. Reached only on the first append of an agent whose state row
  /// has an unset head, so it runs at most once (the append then persists the
  /// head).
  Future<String?> _backfillMessageChain(String agentId) async {
    final messages = await _repository.getAgentMessages(agentId);
    if (messages.isEmpty) return null;
    messages.sort((a, b) {
      final byCreatedAt = a.createdAt.compareTo(b.createdAt);
      return byCreatedAt != 0 ? byCreatedAt : a.id.compareTo(b.id);
    });
    for (var i = 1; i < messages.length; i++) {
      await upsertLink(
        AgentLink.messagePrev(
          id: 'msgprev-${messages[i].id}',
          fromId: messages[i].id,
          toId: messages[i - 1].id,
          createdAt: messages[i].createdAt,
          updatedAt: messages[i].createdAt,
          vectorClock: null,
        ),
      );
    }
    return messages.last.id;
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
        txCtx.pendingSequenceBindings.add(
          () => _recordAgentLinkSequence(stamped),
        );
        txCtx.pendingMessages.add(message);
      } else {
        await _recordAgentLinkSequence(stamped);
        await _enqueueOrBufferPostWrite(
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
        txCtx.pendingSequenceBindings.add(
          () => _recordAgentLinkSequence(stamped),
        );
        txCtx.pendingMessages.add(message);
      } else {
        await _recordAgentLinkSequence(stamped);
        await _enqueueOrBufferPostWrite(
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
  Future<void> _enqueueOrBufferPostWrite(
    SyncMessage message, {
    required String subDomain,
  }) async {
    try {
      await _outboxService.enqueueMessage(message);
    } catch (exception, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.sync,
        exception,
        message: 'outbox enqueue failed after DB write; VC already committed',
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
      // Snapshot the buffer lengths so that if the inner savepoint rolls
      // back (throws) but the caller catches and continues, we discard
      // only the messages and sequence bindings added by this inner scope.
      // Without truncating bindings on rollback, the outer commit would
      // record a sent sequence row for a write that was rolled back.
      final messageSnapshot = existingCtx.pendingMessages.length;
      final sequenceSnapshot = existingCtx.pendingSequenceBindings.length;
      try {
        return await _repository.runInTransaction(action);
      } catch (_) {
        existingCtx.pendingMessages.removeRange(
          messageSnapshot,
          existingCtx.pendingMessages.length,
        );
        existingCtx.pendingSequenceBindings.removeRange(
          sequenceSnapshot,
          existingCtx.pendingSequenceBindings.length,
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
        for (final bindSequence in ctx.pendingSequenceBindings) {
          await bindSequence();
        }
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
      ctx.pendingSequenceBindings.clear();
    }
  }
}
