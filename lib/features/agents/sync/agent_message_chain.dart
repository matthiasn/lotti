// The causal-DAG message append path — part of the agent_sync_service
// library so it shares the service's private raw-upsert and transaction
// machinery. `appendJoin` (public, mocked) stays on the class.
part of 'agent_sync_service.dart';

extension _AgentMessageChain on AgentSyncService {
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
}
