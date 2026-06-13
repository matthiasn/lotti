import 'dart:async';

import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/projection/derived_agent_state.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:uuid/uuid.dart';

part 'agent_message_chain.dart';
part 'agent_sync_sequence_recording.dart';

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

  static const _uuid = Uuid();

  /// The underlying repository for read-only operations.
  AgentRepository get repository => _repository;

  /// The local device's host id — the key this device's `GCounter` increments
  /// are attributed to (so per-host entries stay disjoint and merge losslessly).
  /// Sourced from [VectorClockService], which sets it during init; throws if it
  /// is somehow unset, which should not happen in a running app.
  Future<String> localHost() async {
    final host = await _vectorClockService.getHost();
    if (host == null) {
      throw StateError('VectorClockService has no host id for a counter bump');
    }
    return host;
  }

  /// Returns the active transaction context from the current [Zone], or
  /// `null` when called outside [runInTransaction].
  static _TransactionContext? get _currentTxContext =>
      Zone.current[_txKey] as _TransactionContext?;

  SyncSequenceLogService? get _sequenceLog =>
      sequenceLogService ??
      (getIt.isRegistered<SyncSequenceLogService>()
          ? getIt<SyncSequenceLogService>()
          : null);

  /// Upsert an [AgentDomainEntity] and enqueue a sync message unless
  /// [fromSync] is `true`.
  ///
  /// Local (non-sync) **message** writes are routed through the causal-DAG
  /// append path ([_appendMessage]) so every persisted message is chained into
  /// the log and advances the agent's head — no call site can bypass it. Local
  /// **agent-state** writes are routed through [_upsertAgentStatePreservingHead]
  /// so they can't clobber that head. Every other entity (and sync-received
  /// entities, which already carry their merged head) goes straight to the raw
  /// upsert.
  Future<void> upsertEntity(
    AgentDomainEntity entity, {
    bool fromSync = false,
  }) async {
    if (!fromSync && entity is AgentMessageEntity) {
      return _appendMessage(entity);
    }
    if (!fromSync && entity is AgentStateEntity) {
      return _upsertAgentStatePreservingHead(entity);
    }
    return _upsertEntityRaw(entity, fromSync: fromSync);
  }

  /// Persists a local [AgentStateEntity] write while preserving the
  /// append-path-owned `recentHeadMessageId`.
  ///
  /// `recentHeadMessageId` is maintained *exclusively* by [_appendMessage] — it
  /// is the only writer of that field. A workflow, however, computes its
  /// end-of-wake state update by `copyWith`-ing a snapshot it captured *before*
  /// it appended the wake's messages, so the head it carries is stale. Persisted
  /// verbatim, that write would reset the head the appends just advanced and
  /// fork the `messagePrev` DAG at the wake boundary (the next wake's first
  /// message would chain off the pre-wake head, not the real tip).
  ///
  /// So overlay the persisted head onto the write. The re-read and the write run
  /// in one [runInTransaction] so a concurrent message append can't advance the
  /// head between them and have this write clobber it back (the lost-update the
  /// preservation exists to prevent); read-your-writes inside the enclosing wake
  /// transaction also means the re-read reflects the head the appends advanced.
  /// The append path itself writes via [_upsertEntityRaw] and so bypasses this,
  /// keeping it the sole place the head moves. Sync-received state
  /// (`fromSync`) is left untouched — it carries the resolver-merged head.
  Future<void> _upsertAgentStatePreservingHead(AgentStateEntity entity) async {
    await runInTransaction(() async {
      final persisted = await _repository.getAgentState(entity.agentId);
      await _upsertEntityRaw(
        persisted == null
            ? entity
            : entity.copyWith(
                recentHeadMessageId: persisted.recentHeadMessageId,
              ),
      );
    });
  }

  /// Appends a milestone marker — a `system` message tagged with
  /// [AgentMessageMetadata.milestone] — to the agent's log.
  ///
  /// This is how a wake-completion watermark (`lastWakeAt`,
  /// `slots.lastOneOnOneAt`, …) is event-sourced: the marker's [createdAt] is
  /// the source of truth for the matching watermark, which the
  /// State-as-Projection fold (PR 4) derives as the `max(createdAt)` of markers
  /// carrying that milestone. Because it derives from the synced log rather than
  /// a last-writer-wins row, the watermark converges across devices — no missed
  /// or double ritual under a partition.
  ///
  /// The marker is routed through [upsertEntity] (so it chains into the causal
  /// DAG like any message). [threadId] defaults to the marker's own id, which
  /// suits the completion paths that have no wake thread (the dormant-skip wake
  /// and the improver one-on-one). Callers continue to write the cached
  /// watermark row alongside this marker; reads do not switch to the projection
  /// until the cutover (B6).
  Future<void> appendMilestone({
    required String agentId,
    required AgentMilestone milestone,
    required DateTime createdAt,
    String? threadId,
    String? runKey,
  }) {
    final id = _uuid.v4();
    return upsertEntity(
      AgentDomainEntity.agentMessage(
        id: id,
        agentId: agentId,
        threadId: threadId ?? id,
        kind: AgentMessageKind.system,
        createdAt: createdAt,
        vectorClock: null,
        metadata: AgentMessageMetadata(runKey: runKey, milestone: milestone),
      ),
    );
  }

  /// Returns the agent's state **reconciled against the log** — the read
  /// cutover (PR 4 B6). This is the read a wake must act on: it folds the log's
  /// watermarks + active slots over the cached row ([reconcileAgentState]) so a
  /// value the cache lost to last-writer-wins under a partition self-heals
  /// before the agent decides anything. Returns null when the agent has no
  /// state row yet.
  ///
  /// The reconcile reads only the watermarks (carried on `system` milestone
  /// markers) and active slots (the agent's outbound links) — it never touches
  /// the append-maintained head — so it loads just the markers, **not** the
  /// agent's full message log, which for a long-lived agent can be large. The
  /// marker load + the link load are independent, so they run concurrently.
  /// When the reconcile corrects a divergence the healed row is persisted (which
  /// also propagates the correction to peers); when nothing diverged it is a
  /// pure read with no write — no outbox churn on the common path (e.g. an
  /// existing agent with no markers yet reconciles to itself).
  ///
  /// Strictly for the wake critical path; UI/service reads stay on the raw
  /// cache via [AgentRepository.getAgentState] (eventual, self-healing).
  Future<AgentStateEntity?> reconciledAgentState(String agentId) async {
    final cache = await _repository.getAgentState(agentId);
    if (cache == null) return null;
    final (markers, links) = await (
      _repository.getMessagesByKind(agentId, AgentMessageKind.system),
      _repository.getLinksFrom(agentId),
    ).wait;
    final AgentStateEntity reconciled;
    try {
      reconciled = reconcileAgentState(
        cache: cache,
        messages: markers,
        links: links,
      );
    } catch (exception, stackTrace) {
      // The fold runs over a synced log that a peer may have corrupted
      // (duplicate id / cycle). A malformed log must not abort the wake — fall
      // back to the cached row; the projection self-heals once the log is
      // consistent again.
      getIt<DomainLogger>().error(
        LogDomain.sync,
        exception,
        message: 'reconcile fold failed for $agentId; using cached state',
        stackTrace: stackTrace,
        subDomain: 'agentSync.reconcile',
      );
      return cache;
    }
    if (reconciled != cache) {
      await upsertEntity(reconciled);
    }
    return reconciled;
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

  /// Appends a **join-by-continuation** node healing a fork (ADR 0018 rule 8):
  /// a `system` message [joinId] linked via `messagePrev` to *every* head in
  /// [parentIds], after which the agent's head advances to the join so the DAG
  /// re-converges to one tip and the on-device prefix re-warms.
  ///
  /// **Content-addressed and deterministic.** [joinId] (from `computeJoinId`)
  /// and each edge id (`msgprev-${joinId}-${parentId}`) derive purely from the
  /// sorted parent set, so two devices healing the same fork emit the same
  /// structural row (`threadId == joinId`, empty metadata) and edge set — no join
  /// storm. The join carries no payload; its parents live in the edges and its
  /// identity in the content-addressed id (the `sha256-v1:` prefix + a
  /// multi-parent `system` message is what marks a node as a join). Per-device
  /// sync envelope fields (`createdAt`, vector clock) are *not* canonicalized
  /// (deferred — inert while the projection orders by `(hostId, id)` with
  /// `hostId = ''` and joins are immutable); they never affect the merge, which
  /// is keyed by id.
  ///
  /// **Its own append path — never routed through [upsertEntity]/[_appendMessage]**,
  /// which chain a *single* parent off `recentHeadMessageId` and would both add a
  /// spurious `msgprev-${joinId}` edge and collide with the per-parent edge ids.
  ///
  /// **Idempotent and atomic.** Node, all *n* edges, and the head advance commit
  /// in one [runInTransaction]; the node is (re-)written only when absent, and
  /// the edges are idempotent by id. The head is advanced to [joinId] **only
  /// when it still points at one of the joined parents (or is unset)** —
  /// including when the join node arrived by sync, where the head still sits on
  /// a parent. If the head has since moved *past* the parents — e.g. the wake
  /// timed this heal out (the future is not cancellable) and the executor
  /// appended new messages first, or a newer message arrived — it is left alone:
  /// collapsing back to the join would move the head **backwards** and orphan
  /// that progress. The join node + edges are still recorded, so the residual
  /// fork heals on the next wake. Mirrors [_appendMessage]'s head maintenance
  /// via [_upsertEntityRaw], keeping the append path the sole head mover.
  Future<void> appendJoin({
    required String agentId,
    required String joinId,
    required List<String> parentIds,
    required DateTime at,
  }) async {
    // Defensive: a join heals ≥2 distinct heads (planJoin already gates this).
    final parents = parentIds.toSet().toList()..sort();
    if (parents.length < 2) return;
    await runInTransaction(() async {
      final existing = await _repository.getEntity(joinId);
      if (existing is! AgentMessageEntity) {
        await _upsertEntityRaw(
          AgentDomainEntity.agentMessage(
            id: joinId,
            agentId: agentId,
            threadId: joinId,
            kind: AgentMessageKind.system,
            createdAt: at,
            vectorClock: null,
            metadata: const AgentMessageMetadata(),
          ),
        );
      }
      for (final parentId in parents) {
        await upsertLink(
          AgentLink.messagePrev(
            id: 'msgprev-$joinId-$parentId',
            fromId: joinId,
            toId: parentId,
            createdAt: at,
            updatedAt: at,
            vectorClock: null,
          ),
        );
      }
      // Only collapse the head onto the join while it still sits on a joined
      // parent (or is unset). If it has moved on (a timed-out heal racing the
      // executor, or a newer append), advancing would regress the head and
      // orphan that progress — leave it; the residual fork heals next wake.
      final state = await _repository.getAgentState(agentId);
      final head = state?.recentHeadMessageId;
      if (state != null &&
          head != joinId &&
          (head == null || parents.contains(head))) {
        await _upsertEntityRaw(
          state.copyWith(recentHeadMessageId: joinId, updatedAt: at),
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
