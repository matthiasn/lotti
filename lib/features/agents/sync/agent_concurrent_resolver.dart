import 'dart:convert';

import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/sync/agent_lww_timestamp.dart';
import 'package:lotti/features/sync/g_counter.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// Which of two concurrent versions of the same entity/link id should win.
enum ConcurrentWinner {
  /// Keep the version already stored locally.
  local,

  /// Apply the version received over sync.
  incoming,
}

/// Deterministically resolves two **concurrent** versions of one id into a
/// single winner, so every replica converges on the same version regardless of
/// arrival order.
///
/// Consulted only when [VectorClock.compare] returns `VclockStatus.concurrent`
/// (neither version dominates). Resolution order:
///
/// 1. **Last-writer-wins on `updatedAt`** — the strictly-newer write wins.
/// 2. **Equal `updatedAt` → stable tiebreak** — a replica-independent canonical
///    comparison of the two vector clocks. Both replicas hold both clocks, so
///    both compute the same winner; on genuinely concurrent clocks this always
///    discriminates. The degenerate equal-clock case falls back to `local` so
///    the result is total.
///
/// Pure: depends only on its arguments and performs no I/O, so identical inputs
/// yield the same winner on every device — the convergence guarantee. (Bounding
/// a skewed physical clock that wins outright by a strictly-greater `updatedAt`
/// is a separate concern requiring a monotonic/hybrid clock; out of scope here.)
///
/// **Whole-version winner for non-counter fields.** This picks one version and
/// discards the loser's *non-counter* fields, so a concurrent non-counter edit
/// is LWW-lossy (the tiebreak only makes the loser agree across replicas). The
/// *cumulative* counters — `AgentStateEntity`'s `wakeCounter` and the `slots`
/// session counters — are per-host G-counters and are instead merged
/// element-wise by [mergeAgentStateCounters] (PR 2b), so no increment is ever
/// lost. (`processedCounterByHost` relocates to the sequence layer in PR 4.)
ConcurrentWinner resolveConcurrent({
  required VectorClock localVc,
  required VectorClock incomingVc,
  required DateTime localUpdatedAt,
  required DateTime incomingUpdatedAt,
}) {
  if (incomingUpdatedAt.isAfter(localUpdatedAt)) {
    return ConcurrentWinner.incoming;
  }
  if (localUpdatedAt.isAfter(incomingUpdatedAt)) {
    return ConcurrentWinner.local;
  }
  return VectorClock.compareCanonically(incomingVc, localVc) > 0
      ? ConcurrentWinner.incoming
      : ConcurrentWinner.local;
}

/// Whether message [ancestorId] is a proper ancestor of [descendantId] in
/// the replica's local `messagePrev` DAG. `false` also means "not known
/// here": the rows that would show it may not have synced yet.
typedef MessageAncestry = bool Function(String ancestorId, String descendantId);

/// A [MessageAncestry] that knows no order at all.
bool noKnownAncestry(String ancestorId, String descendantId) => false;

/// The agent's head pointer after merging two state versions' heads
/// (ADR 0076). The head is a register over the message DAG, not a
/// last-writer-wins field:
///
/// - an unset head carries no information, so the other one stands;
/// - of two heads, the one that descends from the other wins, so a merge
///   never moves the head back to an ancestor of the one it replaces;
/// - two heads with no order known here — a true fork, or messages and
///   edges still in flight — go by id, the greater first: the same pair
///   gives the same head on every replica, never by clock or arrival order.
///   The fork healer joins a true fork; an append chains off a tip past
///   whichever head this leaves (`AgentMessageDag.tipFrom`), so a head left
///   on a row whose child (and its edge) arrives later forks nothing.
String? mergeAgentHeads({
  required String? local,
  required String? incoming,
  required MessageAncestry isAncestor,
}) {
  if (incoming == null || incoming == local) return local;
  if (local == null) return incoming;
  if (isAncestor(local, incoming)) return incoming;
  if (isAncestor(incoming, local)) return local;
  return local.compareTo(incoming) >= 0 ? local : incoming;
}

/// The row a replica holding [local] persists after receiving [incoming]:
/// [local] itself (identical) when the local row stands, otherwise the row
/// to write in its place. This is the whole receive-path decision, shared by
/// `SyncEventProcessor` and the local write path in `AgentSyncService` so the
/// two can never resolve the same pair differently (ADR 0068).
///
/// - A missing clock on either side applies [incoming] — for agent state
///   with the two heads merged ([mergeAgentHeads]) — as does a known
///   variant arriving over a payload-less [AgentUnknownEntity] stub (unless
///   that would resurrect the stub's tombstone).
/// - Causal dominance decides next; a dominating [incoming] still has
///   [local]'s convergent fields joined in ([joinConvergentAgentFields]),
///   and keeps [local]'s agent head when that head is known ([isAncestor])
///   to descend from its own, or its own is unset (ADR 0076).
/// - A concurrent pair goes to [mergeConcurrentAgentEntities].
///
/// [isAncestor] answers for the local message DAG; the caller reads it
/// before the merge (`AgentMessageDag.ancestryOf`), so this stays pure: the
/// same pair and the same answers yield the same row on every device.
/// Throws [VclockException] for a malformed clock, which the caller handles.
AgentDomainEntity resolveAgentEntityVersions({
  required AgentDomainEntity local,
  required AgentDomainEntity incoming,
  MessageAncestry isAncestor = noKnownAncestry,
}) {
  final localVc = local.vectorClock;
  final incomingVc = incoming.vectorClock;
  if (localVc == null || incomingVc == null) {
    // An unclocked (legacy) version still applies, but its head is merged
    // like any other: an old build's row must not move the head back.
    if (local is! AgentStateEntity || incoming is! AgentStateEntity) {
      return incoming;
    }
    final head = mergeAgentHeads(
      local: local.recentHeadMessageId,
      incoming: incoming.recentHeadMessageId,
      isAncestor: isAncestor,
    );
    return head == incoming.recentHeadMessageId
        ? incoming
        : incoming.copyWith(recentHeadMessageId: head);
  }
  // A local row that decodes as the forward-compat `unknown` fallback is a
  // payload-less stub: an older build received a variant it did not know,
  // kept only the envelope fields, and re-serialized the row as `unknown`
  // with the incoming clock intact. A known incoming variant strictly refines
  // it regardless of clock order — keeping the stub would pin the stripped
  // row forever, because a re-delivery of the version it stubbed compares
  // `equal`. The one thing a stub carries faithfully is its tombstone, so a
  // deletion is never resurrected by an older live payload.
  if (local is AgentUnknownEntity &&
      incoming is! AgentUnknownEntity &&
      (local.deletedAt == null || incoming.deletedAt != null)) {
    return incoming;
  }
  final resolved = switch (VectorClock.compare(localVc, incomingVc)) {
    VclockStatus.a_gt_b || VclockStatus.equal => local,
    VclockStatus.b_gt_a => _keepDescendantHead(
      joinConvergentAgentFields(winner: incoming, other: local),
      local: local,
      isAncestor: isAncestor,
    ),
    VclockStatus.concurrent => mergeConcurrentAgentEntities(
      local: local,
      incoming: incoming,
      isAncestor: isAncestor,
    ),
  };
  return resolved == local ? local : resolved;
}

/// [dominating] — a received agent-state version that causally dominates
/// [local] — with [local]'s head kept when that head is known to descend
/// from the dominating one's, or the dominating one has none. A replica can
/// hold a head newer than the version that succeeds its row: a merge of a
/// concurrent pair keeps the winner's clock, and a head it took from the
/// other side is not covered by that clock. Other variants come back as
/// they are.
AgentDomainEntity _keepDescendantHead(
  AgentDomainEntity dominating, {
  required AgentDomainEntity local,
  required MessageAncestry isAncestor,
}) {
  if (dominating is! AgentStateEntity || local is! AgentStateEntity) {
    return dominating;
  }
  final localHead = local.recentHeadMessageId;
  final head = dominating.recentHeadMessageId;
  if (localHead == null || localHead == head) return dominating;
  if (head != null && !isAncestor(head, localHead)) return dominating;
  return dominating.copyWith(recentHeadMessageId: localHead);
}

/// Resolves two **concurrent** versions of one entity into the row to keep:
/// the type's override ([resolveConcurrentAgentEntityOverride]), then
/// [resolveConcurrent], with the per-type convergent fields joined — agent
/// state's G-counters ([mergeAgentStateCounters]) and head
/// ([mergeAgentHeads], ordered by [isAncestor]), and the nudge accumulators
/// ([mergeNudgeAccumulators]) — and change sets merged item by item
/// ([mergeConcurrentChangeSets]). A missing clock counts as empty.
AgentDomainEntity mergeConcurrentAgentEntities({
  required AgentDomainEntity local,
  required AgentDomainEntity incoming,
  MessageAncestry isAncestor = noKnownAncestry,
}) {
  final winnerSide =
      resolveConcurrentAgentEntityOverride(local: local, incoming: incoming) ??
      resolveConcurrent(
        localVc: local.vectorClock ?? _emptyClock,
        incomingVc: incoming.vectorClock ?? _emptyClock,
        localUpdatedAt: local.effectiveUpdatedAt,
        incomingUpdatedAt: incoming.effectiveUpdatedAt,
      );
  final winner = winnerSide == ConcurrentWinner.local ? local : incoming;
  return switch ((local, incoming)) {
    (final AgentStateEntity l, final AgentStateEntity i) =>
      mergeAgentStateCounters(
        winner: winner as AgentStateEntity,
        local: l,
        incoming: i,
      ).copyWith(
        recentHeadMessageId: mergeAgentHeads(
          local: l.recentHeadMessageId,
          incoming: i.recentHeadMessageId,
          isAncestor: isAncestor,
        ),
      ),
    (final GoalNudgeEntity l, final GoalNudgeEntity i) =>
      mergeGoalNudgeAccumulators(
        winner: winner as GoalNudgeEntity,
        local: l,
        incoming: i,
      ),
    (final RelationshipNudgeEntity l, final RelationshipNudgeEntity i) =>
      mergeRelationshipNudgeAccumulators(
        winner: winner as RelationshipNudgeEntity,
        local: l,
        incoming: i,
      ),
    (final ChangeSetEntity l, final ChangeSetEntity i) =>
      mergeConcurrentChangeSets(local: l, incoming: i) ?? winner,
    // A cross-variant pair (a goal nudge and a relationship nudge sharing an
    // id) is unreachable — their id shapes are disjoint at mint time — and
    // keeps the plain winner rather than joining histories across kinds.
    _ => winner,
  };
}

/// [winner] with [other]'s convergent agent-state fields joined in: the
/// G-counters by element-wise max, the report watermarks by latest instant.
/// Other variants come back unchanged.
///
/// Applied even when [winner] causally dominates [other]. A concurrent merge
/// joins counters into a row without moving its clock, so a version that
/// succeeds one side of that merge need not carry the other side's
/// increments; overwriting the merged row with it would lose them.
AgentDomainEntity joinConvergentAgentFields({
  required AgentDomainEntity winner,
  required AgentDomainEntity other,
}) => winner is AgentStateEntity && other is AgentStateEntity
    ? mergeAgentStateCounters(winner: winner, local: other, incoming: winner)
    : winner;

/// The row a **local** write of [write] persists over [persisted] (ADR
/// 0068). The caller stamps it with a clock that covers both [write]'s and
/// [persisted]'s, so every replica takes it as a successor of [persisted];
/// this function makes the fields match what the replicas then agree on.
///
/// - A write built on [persisted]'s clock (or a newer one) keeps its fields.
///   A write built on an older snapshot, or on no clock at all, did not see
///   [persisted]; its fields are resolved against it as if the two were
///   concurrent, so a stale write can neither revive a retraction nor beat
///   a newer timestamp it never saw.
/// - Agent state never lowers a G-counter or a report watermark. Its head
///   needs no ancestry here: every local head writer reads [persisted] in
///   the same transaction and builds on its head, so a write that moves the
///   head always covers [persisted] (ADR 0076).
/// - `updatedAt` never moves backwards, so the successor sorts after the row
///   it replaces on every replica, whatever the writer's clock says.
/// - A live row built afresh (no clock) over a removed one is a re-creation
///   under the same id — a day plan drafted again for a day whose plan was
///   deleted. Its writer read no row (reads hide tombstones), so it could not
///   build on the tombstone's clock; it keeps its fields, and the stamped
///   clock makes it the removal's successor everywhere (ADR 0081, addendum).
///
/// Append-only variants (last-writer-wins on `createdAt`) and a stub or
/// different variant in [persisted] keep [write]'s fields unchanged.
AgentDomainEntity resolveLocalAgentWrite({
  required AgentDomainEntity persisted,
  required AgentDomainEntity write,
}) {
  if (persisted is AgentUnknownEntity ||
      persisted.runtimeType != write.runtimeType ||
      !write.lwwOnUpdatedAt) {
    return write;
  }
  final recreates =
      persisted.deletedAt != null &&
      write.deletedAt == null &&
      write.vectorClock == null;
  final fields = recreates || _covers(write.vectorClock, persisted.vectorClock)
      ? write
      : mergeConcurrentAgentEntities(local: persisted, incoming: write);
  return joinConvergentAgentFields(
    winner: fields,
    other: persisted,
  ).withUpdatedAtNotBefore(persisted.effectiveUpdatedAt);
}

const _emptyClock = VectorClock(<String, int>{});

/// Whether a write built on [base] saw everything in [seen]. A malformed
/// clock proves nothing, so it does not cover.
bool _covers(VectorClock? base, VectorClock? seen) {
  if (seen == null) return true;
  if (base == null) return false;
  try {
    return switch (VectorClock.compare(base, seen)) {
      VclockStatus.a_gt_b || VclockStatus.equal => true,
      VclockStatus.b_gt_a || VclockStatus.concurrent => false,
    };
  } on VclockException {
    return false;
  }
}

/// Type-specific **monotonic** resolution for two *concurrent* versions of one
/// agent entity, applied BEFORE the generic [resolveConcurrent] LWW. Returns
/// `null` to defer to LWW. Pure and symmetric — both replicas pass the same
/// `(local, incoming)` pair and compute the same winner — so the result stays
/// convergent regardless of arrival order.
///
/// The rules close ADR 0022 conflict holes that raw wall-clock LWW on a
/// shared id mishandles:
///
/// - **Durable knowledge — retraction is terminal.** A concurrent retract must
///   not be revived by a concurrent edit/confirm of the same knowledge entry
///   (a later wall-clock edit would otherwise resurrect knowledge the user
///   deliberately removed). When exactly one side is retracted, it wins.
/// - **Scheduled wakes — a future reschedule beats a past consume.** A pending
///   pre-warm targeting a strictly-later instant wins over a concurrent consume
///   of an earlier instant, so a re-armed wake is not silently dropped.
///   For the **same** instant, consumption is terminal and wins in both
///   directions. Deferring to LWW there was the bug this replaces: a peer that
///   missed the consume can take over past `leaseUntil` and stamp a younger
///   pending claim, and `updatedAt` LWW would then let that claim beat the
///   completion — resurrecting a wake that already fired. Same-status
///   conflicts at one instant are what still defer.
/// - **Day summaries — earliest `createdAt` wins.** A day summary is the
///   planner's contemporaneous testimony about a day; plain LWW would let a
///   later (less contemporaneous, possibly stale-device) write silently
///   replace it. On concurrent versions the EARLIEST-created testimony is
///   canonical; a `createdAt` tie defers to [resolveConcurrent] (LWW, then the
///   canonical-clock tiebreak). Sequential (non-concurrent) within-window
///   self-rewrites are unaffected — they dominate by vector clock and never
///   reach this resolver.
/// - **Goal spec heads — higher version, then owner intent wins.** Disconnected
///   replicas can independently mint the same successor ordinal. A direct
///   owner edit outranks an agent-proposal approval at that ordinal, preventing
///   generic LWW from replacing explicit owner intent.
/// - **Evolution sessions — completed, then abandoned, then active.** Only
///   the device holding a session in memory completes it, and completing it
///   creates the version the session produced; any device abandons a session
///   it reads as active, for instance when it starts one of its own. A
///   completion therefore beats a concurrent abandonment, and a terminal
///   status beats `active`, so a session whose proposal was adopted is never
///   recorded as abandoned (ADR 0081, `specs/tla/EvolutionSession.tla`).
ConcurrentWinner? resolveConcurrentAgentEntityOverride({
  required AgentDomainEntity local,
  required AgentDomainEntity incoming,
}) {
  if (local is EvolutionSessionEntity && incoming is EvolutionSessionEntity) {
    final byStatus = _evolutionSessionRank(
      local.status,
    ).compareTo(_evolutionSessionRank(incoming.status));
    if (byStatus == 0) return null;
    return byStatus > 0 ? ConcurrentWinner.local : ConcurrentWinner.incoming;
  }
  if (local is PlannerKnowledgeEntity && incoming is PlannerKnowledgeEntity) {
    final localRetracted = local.status == KnowledgeStatus.retracted;
    final incomingRetracted = incoming.status == KnowledgeStatus.retracted;
    if (localRetracted == incomingRetracted) return null;
    return localRetracted ? ConcurrentWinner.local : ConcurrentWinner.incoming;
  }
  if (local is ScheduledWakeEntity && incoming is ScheduledWakeEntity) {
    final byTarget = local.scheduledAt.compareTo(incoming.scheduledAt);
    if (byTarget != 0) {
      return byTarget > 0 ? ConcurrentWinner.local : ConcurrentWinner.incoming;
    }
    // Consumption is terminal for a wake window. Without this, a peer that saw
    // the winning lease but missed the later `consumed` write could take over
    // past `leaseUntil` and write a fresh pending claim; generic updatedAt LWW
    // would then let that younger claim defeat the completion, and the peer
    // would bill a second briefing for a window it already knew was finished.
    // Re-arming the *next* window carries a later scheduledAt, so it is
    // decided above and never reaches here.
    final localConsumed = local.status == ScheduledWakeStatus.consumed;
    final incomingConsumed = incoming.status == ScheduledWakeStatus.consumed;
    if (localConsumed == incomingConsumed) return null;
    return localConsumed ? ConcurrentWinner.local : ConcurrentWinner.incoming;
  }
  if (local is DaySummaryEntity && incoming is DaySummaryEntity) {
    final byCreated = local.createdAt.compareTo(incoming.createdAt);
    if (byCreated == 0) return null;
    return byCreated < 0 ? ConcurrentWinner.local : ConcurrentWinner.incoming;
  }
  if (local is GoalSpecHeadEntity && incoming is GoalSpecHeadEntity) {
    final localVersion = specVersionOrdinal(local.versionId);
    final incomingVersion = specVersionOrdinal(incoming.versionId);
    if (localVersion != null &&
        incomingVersion != null &&
        localVersion != incomingVersion) {
      return localVersion > incomingVersion
          ? ConcurrentWinner.local
          : ConcurrentWinner.incoming;
    }
    if (localVersion == incomingVersion && localVersion != null) {
      final localOwner = isOwnerAuthoredGoalSpecVersionId(local.versionId);
      final incomingOwner = isOwnerAuthoredGoalSpecVersionId(
        incoming.versionId,
      );
      if (localOwner != incomingOwner) {
        return localOwner ? ConcurrentWinner.local : ConcurrentWinner.incoming;
      }
    }
    return null;
  }
  if (local is GoalProgressEntity && incoming is GoalProgressEntity) {
    // Registers are keyed by (agent, period) only, so an offline v1
    // evaluation and a v2 evaluation of the same day collide on one row.
    // The row computed under the NEWER spec version wins — timestamp LWW
    // could otherwise let the superseded evaluation hide current health.
    final localVersion = specVersionOrdinal(local.specVersionId);
    final incomingVersion = specVersionOrdinal(incoming.specVersionId);
    if (localVersion != null &&
        incomingVersion != null &&
        localVersion != incomingVersion) {
      return localVersion > incomingVersion
          ? ConcurrentWinner.local
          : ConcurrentWinner.incoming;
    }
    // Disconnected approvals mint the same ordinal under different ids
    // (spec-v2-aaaa vs spec-v2-bbbb). Neither is knowably the standing
    // head from here, but replicas MUST agree; the lexicographic pick is
    // stable and symmetric, and the next Phase A tick recomputes the
    // register under the actual head anyway (recompute-never-accumulate).
    if (local.specVersionId != incoming.specVersionId) {
      return local.specVersionId.compareTo(incoming.specVersionId) > 0
          ? ConcurrentWinner.local
          : ConcurrentWinner.incoming;
    }
    return null;
  }
  if (local is GoalNudgeEntity && incoming is GoalNudgeEntity) {
    return resolveConcurrentNudgeLifecycle(
      localStatus: local.status,
      incomingStatus: incoming.status,
      localActivationCount: local.activationCount,
      incomingActivationCount: incoming.activationCount,
    );
  }
  if (local is RelationshipNudgeEntity && incoming is RelationshipNudgeEntity) {
    return resolveConcurrentNudgeLifecycle(
      localStatus: local.status,
      incomingStatus: incoming.status,
      localActivationCount: local.activationCount,
      incomingActivationCount: incoming.activationCount,
    );
  }
  return null;
}

/// The nudge lifecycle dominance rules, shared by every nudge variant and
/// applied per-variant by [resolveConcurrentAgentEntityOverride] (ADR 0055
/// semantics, generalized by ADR 0059). Returns null to defer to LWW.
ConcurrentWinner? resolveConcurrentNudgeLifecycle({
  required NudgeStatus localStatus,
  required NudgeStatus incomingStatus,
  required int localActivationCount,
  required int incomingActivationCount,
}) {
  // Dismissal is terminal (ADR 0055): the user's "stop showing me this"
  // must not be revived by a concurrent re-activation or bookkeeping
  // write on another device — a fresh dismissal is a request for quiet.
  final localDismissed = localStatus == NudgeStatus.dismissed;
  final incomingDismissed = incomingStatus == NudgeStatus.dismissed;
  if (localDismissed != incomingDismissed) {
    return localDismissed ? ConcurrentWinner.local : ConcurrentWinner.incoming;
  }
  // Supersession is the subject itself moving on (a revised goal spec, a
  // changed relationship state) and outranks EVERYTHING below, including a
  // higher activation: an offline rerun of a stale banner must not
  // resurrect it beside the revised subject. (Only revision sweeps write
  // `superseded`, and superseded rows can never re-enter the rerun path,
  // so this cannot mask a legitimate same-subject reactivation.)
  final localSuperseded = localStatus == NudgeStatus.superseded;
  final incomingSuperseded = incomingStatus == NudgeStatus.superseded;
  if (localSuperseded != incomingSuperseded) {
    return localSuperseded ? ConcurrentWinner.local : ConcurrentWinner.incoming;
  }
  // The HIGHER activation is the newer run: its lifecycle metadata
  // (activatedAt, staleAt, runKey) must win whole-row selection, or a
  // peer's bookkeeping write for the PREVIOUS activation could win LWW
  // and stamp the fresh rerun with the old deadline. This also covers
  // genuine reactivation beating a same-subject terminal write.
  if (localActivationCount != incomingActivationCount) {
    return localActivationCount > incomingActivationCount
        ? ConcurrentWinner.local
        : ConcurrentWinner.incoming;
  }
  // Same activation: terminal states dominate concurrent live writes —
  // a device that retired/expired/superseded the banner must not lose to a
  // stale exposure flush or rating that copied the old `active` row.
  final localTerminal = _terminalNudgeStatuses.contains(localStatus);
  final incomingTerminal = _terminalNudgeStatuses.contains(incomingStatus);
  if (localTerminal != incomingTerminal) {
    return localTerminal ? ConcurrentWinner.local : ConcurrentWinner.incoming;
  }
  return null;
}

/// The ordinal in a spec version id (`agent:spec-v3-9f2c1a08` → 3), or
/// null for foreign id shapes — those fall back to LWW. Shared with the
/// goal-progress recompute, which must not build on a newer spec's row.
int? specVersionOrdinal(String specVersionId) {
  final match = RegExp(r'spec-v(\d+)').firstMatch(specVersionId);
  return match == null ? null : int.tryParse(match.group(1)!);
}

/// How final an evolution session status is: a concurrent pair keeps the
/// more final one ([resolveConcurrentAgentEntityOverride]).
int _evolutionSessionRank(EvolutionSessionStatus status) => switch (status) {
  EvolutionSessionStatus.active => 0,
  EvolutionSessionStatus.abandoned => 1,
  EvolutionSessionStatus.completed => 2,
};

/// The version of one agent link a replica keeps: [local], the row it
/// holds — a tombstone included — or [incoming], the version it received.
/// Returns [local] itself when it stands.
///
/// Causal dominance decides first; a concurrent pair goes to
/// [resolveConcurrent] (the later `updatedAt`, then the canonical clock).
/// A version without a clock carries no order and applies. The local write
/// path stamps every write as a successor of the row it replaces, tombstone
/// included, and never earlier than it (`AgentSyncService.upsertLink`), so
/// this order agrees with causality and every replica keeps the same
/// version in any arrival order (ADR 0081, `specs/tla/AgentLinks.tla`).
/// Pure, like [resolveAgentEntityVersions]. Throws [VclockException] for a
/// malformed clock, which the caller handles.
AgentLink resolveAgentLinkVersions({
  required AgentLink local,
  required AgentLink incoming,
}) {
  final localVc = local.vectorClock;
  final incomingVc = incoming.vectorClock;
  if (localVc == null || incomingVc == null) return incoming;
  return switch (VectorClock.compare(localVc, incomingVc)) {
    VclockStatus.a_gt_b || VclockStatus.equal => local,
    VclockStatus.b_gt_a => incoming,
    VclockStatus.concurrent =>
      resolveConcurrent(
                localVc: localVc,
                incomingVc: incomingVc,
                localUpdatedAt: local.updatedAt,
                incomingUpdatedAt: incoming.updatedAt,
              ) ==
              ConcurrentWinner.local
          ? local
          : incoming,
  };
}

const Set<NudgeStatus> _terminalNudgeStatuses = {
  NudgeStatus.retired,
  NudgeStatus.expired,
  NudgeStatus.superseded,
  NudgeStatus.failed,
};

/// Merges two **concurrent** versions of one change set item by item — the
/// change-set case of [mergeConcurrentAgentEntities] (ADR 0067).
///
/// A change set is edited on every device that shows it, and a whole-row
/// winner would drop the other device's decisions: an item confirmed and
/// applied there would read `pending` again everywhere and could be applied
/// a second time. For each index:
///
/// - the version that changed the item last wins — the higher
///   [ChangeItem.revision];
/// - at the same revision, or when either side carries no revision (an
///   older build wrote it, and drops the field), the more final status wins
///   ([ChangeItem.statusRank]): a confirm took effect, so it beats a
///   concurrent rejection or retraction, and any decision beats `pending`;
/// - on a status tie, the side that has a revision, which changed the item,
///   beats an older build's copy without one;
/// - otherwise a fixed order on the item's content decides.
///
/// Items one version appended beyond the other's are kept. The set status is
/// derived from the merged items — two closed versions (`resolved`,
/// `expired`) stay closed, so a row retired before retirement retracted its
/// items is not reopened — and `resolvedAt` is the later of the two (the
/// set's `createdAt` when neither had resolved it). The vector clock is the
/// join of both, so the merged row covers both versions: a later write on
/// either device dominates it, and a version that succeeds only one side is
/// concurrent with it and merges again.
///
/// Nothing here depends on the clocks' canonical order, only on the two
/// rows' contents, so the merged row does not depend on the order in which a
/// replica received the versions — the trap ADR 0068 names for a joined
/// clock under a clock tiebreak.
///
/// Returns `null` when the versions cannot be merged item by item — either
/// is a tombstone, or they disagree on which proposal an index holds — and
/// the whole-row winner decides.
ChangeSetEntity? mergeConcurrentChangeSets({
  required ChangeSetEntity local,
  required ChangeSetEntity incoming,
}) {
  if (local.deletedAt != null || incoming.deletedAt != null) return null;
  final common = local.items.length < incoming.items.length
      ? local.items.length
      : incoming.items.length;
  for (var i = 0; i < common; i++) {
    final a = local.items[i];
    final b = incoming.items[i];
    if (a.toolName != b.toolName || a.humanSummary != b.humanSummary) {
      return null;
    }
  }
  final longer = local.items.length >= incoming.items.length ? local : incoming;
  final items = [
    for (var i = 0; i < longer.items.length; i++)
      if (i < common)
        _mergeChangeItem(local.items[i], incoming.items[i])
      else
        longer.items[i],
  ];
  final bothClosed =
      !_isOpenChangeSetStatus(local.status) &&
      !_isOpenChangeSetStatus(incoming.status);
  final status = bothClosed
      ? (local.status.index >= incoming.status.index
            ? local.status
            : incoming.status)
      : ChangeItem.deriveSetStatus(items);
  final resolvedAt = status == ChangeSetStatus.resolved
      ? _latestInstant(local.resolvedAt, incoming.resolvedAt) ?? local.createdAt
      : null;
  return local.copyWith(
    items: items,
    status: status,
    resolvedAt: resolvedAt,
    vectorClock: VectorClock.merge(local.vectorClock, incoming.vectorClock),
  );
}

bool _isOpenChangeSetStatus(ChangeSetStatus status) =>
    status == ChangeSetStatus.pending ||
    status == ChangeSetStatus.partiallyResolved;

ChangeItem _mergeChangeItem(ChangeItem local, ChangeItem incoming) {
  final localRevision = local.revision;
  final incomingRevision = incoming.revision;
  // An item without a revision was last written by an older build, which
  // drops the field: its revision says nothing about order, so only the
  // status can decide.
  if (localRevision != null &&
      incomingRevision != null &&
      localRevision != incomingRevision) {
    return localRevision > incomingRevision ? local : incoming;
  }
  final byRank =
      ChangeItem.statusRank(local.status) -
      ChangeItem.statusRank(incoming.status);
  if (byRank != 0) return byRank > 0 ? local : incoming;
  // Same status, and only one side counted its change: that side changed
  // the item — a follow-up task's target rewrite, say — while the older
  // build's copy is the item as it was.
  if ((localRevision == null) != (incomingRevision == null)) {
    return localRevision != null ? local : incoming;
  }
  // A fixed order on content, not on clocks: the same pair gives the same
  // item on every replica, however the replica came to hold it.
  return jsonEncode(local.toJson()).compareTo(jsonEncode(incoming.toJson())) >=
          0
      ? local
      : incoming;
}

/// Merges the convergent (per-host G-counter) fields of two **concurrent**
/// [AgentStateEntity] versions into [winner]: each counter becomes the
/// element-wise max (CRDT join) of [local] and [incoming], so no increment from
/// either device is lost, while every *non-counter* field stays as the
/// deterministic LWW winner ([winner], chosen by [resolveConcurrent]).
///
/// The report freshness watermarks are also merged by maximum timestamp. They
/// represent observed events, so allowing the LWW loser to erase a newer
/// change/refresh watermark could incorrectly present an old report as fresh.
///
/// The winner's vector clock is kept deliberately: a future update that causally
/// dominates it necessarily saw — and (since every replica applies this same
/// merge symmetrically) merged — both sides, so its counters are a superset and
/// a later whole-row overwrite on the `b_gt_a` path loses nothing. Pure: same
/// inputs → same result on every device.
AgentStateEntity mergeAgentStateCounters({
  required AgentStateEntity winner,
  required AgentStateEntity local,
  required AgentStateEntity incoming,
}) {
  return winner.copyWith(
    wakeCounter: local.wakeCounter.merge(incoming.wakeCounter),
    reportStaleAt: _latestInstant(
      local.reportStaleAt,
      incoming.reportStaleAt,
    ),
    reportFreshAt: _latestInstant(
      local.reportFreshAt,
      incoming.reportFreshAt,
    ),
    slots: winner.slots.copyWith(
      totalSessionsCompleted: local.slots.totalSessionsCompleted.merge(
        incoming.slots.totalSessionsCompleted,
      ),
      weeklyReviewCount: local.slots.weeklyReviewCount.merge(
        incoming.slots.weeklyReviewCount,
      ),
    ),
  );
}

/// The accumulator and visibility fields every nudge variant shares — the
/// working set of [mergeNudgeAccumulators]. The variants are siblings in a
/// freezed union with no common nudge supertype, so thin per-variant
/// adapters ([mergeGoalNudgeAccumulators],
/// [mergeRelationshipNudgeAccumulators]) project into this view and apply
/// the merged view back via `copyWith`; the merge rules themselves exist
/// exactly once (ADR 0059).
typedef NudgeAccumulatorView = ({
  VectorClock? vectorClock,
  int activationCount,
  List<NudgeRating> ratings,
  List<NudgeSnooze> snoozeHistory,
  DateTime? snoozedUntil,
  NudgeBannerSnoozeDuration? lastSnoozeDuration,
  List<NudgeDayDismissal> dismissalHistory,
  DateTime? dismissedForDayAt,
  DateTime? staleAt,
  GCounter totalVisibleMs,
  GCounter impressionCount,
  DateTime? firstShownAt,
  DateTime? lastShownAt,
});

/// Merges the convergent fields of two **concurrent** versions of one
/// nudge into [winner] (chosen by [resolveConcurrent], possibly after
/// the lifecycle override): the per-host exposure G-counters
/// joined element-wise, the ratings histories unioned, and the
/// observed-event watermarks widened. Whole-row LWW alone would let the
/// losing device's visible-time, impressions and rating-prompt outcomes
/// vanish — and those accumulate across YEARS of activations (ADR 0055's
/// labeled library), so losing one side is permanent damage, not noise.
/// Snooze histories receive the same append-only union. For concurrent quiet
/// choices on the same activation, the later effective deadline wins current
/// visibility state while both interactions remain available for timing
/// analysis.
///
/// Ratings converge to ONE OUTCOME PER ACTIVATION (the ADR 0055
/// contract): the union is sorted by a total order (activation, ratedAt,
/// skipped, rating) and collapsed to the first entry per activation, so
/// two devices rating the same run before syncing keep the EARLIEST
/// outcome on both — deterministic, and a run is never counted twice in
/// reuse means or wear-out trajectories. Pure: same inputs → same result.
NudgeAccumulatorView mergeNudgeAccumulators({
  required NudgeAccumulatorView winner,
  required NudgeAccumulatorView local,
  required NudgeAccumulatorView incoming,
}) {
  // The sort is a TOTAL order over every distinguishing field: replicas
  // build this set local-first, so a comparator tie between distinct
  // records would let them serialize in different orders and diverge
  // permanently under equal-clock sync.
  final ratings = <NudgeRating>{...local.ratings, ...incoming.ratings}.toList()
    ..sort((a, b) {
      final byActivation = a.activation.compareTo(b.activation);
      if (byActivation != 0) return byActivation;
      final byRatedAt = a.ratedAt.compareTo(b.ratedAt);
      if (byRatedAt != 0) return byRatedAt;
      final bySkipped = (a.skipped ? 1 : 0).compareTo(b.skipped ? 1 : 0);
      if (bySkipped != 0) return bySkipped;
      return (a.rating ?? 0).compareTo(b.rating ?? 0);
    });
  final onePerActivation = <NudgeRating>[];
  for (final rating in ratings) {
    if (onePerActivation.isEmpty ||
        onePerActivation.last.activation != rating.activation) {
      onePerActivation.add(rating);
    }
  }
  final snoozes = <NudgeSnooze>[
    ...local.snoozeHistory,
    ...incoming.snoozeHistory,
  ]..sort(_compareNudgeSnoozes);
  final snoozesById = <String, NudgeSnooze>{};
  for (final snooze in snoozes) {
    snoozesById.putIfAbsent(snooze.id, () => snooze);
  }
  final mergedSnoozes = snoozesById.values.toList()
    ..sort((a, b) {
      final byTime = a.snoozedAt.compareTo(b.snoozedAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
  final dismissals =
      <NudgeDayDismissal>[
        ...local.dismissalHistory,
        ...incoming.dismissalHistory,
      ]..sort(
        (a, b) => _dayDismissalOrderKey(a).compareTo(
          _dayDismissalOrderKey(b),
        ),
      );
  final dismissalsById = <String, NudgeDayDismissal>{};
  for (final dismissal in dismissals) {
    dismissalsById.putIfAbsent(dismissal.id, () => dismissal);
  }
  final mergedDismissals = dismissalsById.values.toList()
    ..sort(
      (a, b) =>
          '${a.dismissedAt.toUtc().toIso8601String()}\u0000${a.id}'.compareTo(
            '${b.dismissedAt.toUtc().toIso8601String()}\u0000${b.id}',
          ),
    );
  final sameActivation = local.activationCount == incoming.activationCount;
  final snoozedUntil = sameActivation
      ? _latestInstant(local.snoozedUntil, incoming.snoozedUntil)
      : winner.snoozedUntil;
  NudgeSnooze? effectiveSnooze;
  if (snoozedUntil != null) {
    for (final event in mergedSnoozes) {
      if (event.snoozedUntil == snoozedUntil) effectiveSnooze = event;
    }
  }
  final activationCount = local.activationCount > incoming.activationCount
      ? local.activationCount
      : incoming.activationCount;
  final mergedStaleAt = sameActivation
      ? _latestInstant(local.staleAt, incoming.staleAt)
      : winner.staleAt;
  return (
    // The merged row observed BOTH branches, so its clock must be their
    // join: keeping only the winner's clock would let that device's next
    // (pre-merge) write causally dominate and overwrite the other
    // branch's accumulators through the ordinary non-concurrent path.
    vectorClock: VectorClock.merge(local.vectorClock, incoming.vectorClock),
    totalVisibleMs: local.totalVisibleMs.merge(incoming.totalVisibleMs),
    impressionCount: local.impressionCount.merge(incoming.impressionCount),
    ratings: onePerActivation,
    snoozeHistory: mergedSnoozes,
    snoozedUntil: snoozedUntil,
    lastSnoozeDuration: effectiveSnooze?.duration ?? winner.lastSnoozeDuration,
    dismissalHistory: mergedDismissals,
    staleAt: mergedStaleAt,
    dismissedForDayAt: sameActivation
        ? _latestInstant(
            local.dismissedForDayAt,
            incoming.dismissedForDayAt,
          )
        : winner.dismissedForDayAt,
    activationCount: activationCount,
    firstShownAt: _earliestInstant(local.firstShownAt, incoming.firstShownAt),
    lastShownAt: _latestInstant(local.lastShownAt, incoming.lastShownAt),
  );
}

/// [mergeNudgeAccumulators] applied to the [GoalNudgeEntity] variant.
GoalNudgeEntity mergeGoalNudgeAccumulators({
  required GoalNudgeEntity winner,
  required GoalNudgeEntity local,
  required GoalNudgeEntity incoming,
}) {
  final merged = mergeNudgeAccumulators(
    winner: _goalNudgeView(winner),
    local: _goalNudgeView(local),
    incoming: _goalNudgeView(incoming),
  );
  return winner.copyWith(
    vectorClock: merged.vectorClock,
    totalVisibleMs: merged.totalVisibleMs,
    impressionCount: merged.impressionCount,
    ratings: merged.ratings,
    snoozeHistory: merged.snoozeHistory,
    snoozedUntil: merged.snoozedUntil,
    lastSnoozeDuration: merged.lastSnoozeDuration,
    dismissalHistory: merged.dismissalHistory,
    staleAt: merged.staleAt,
    dismissedForDayAt: merged.dismissedForDayAt,
    activationCount: merged.activationCount,
    firstShownAt: merged.firstShownAt,
    lastShownAt: merged.lastShownAt,
  );
}

/// [mergeNudgeAccumulators] applied to the [RelationshipNudgeEntity]
/// variant.
RelationshipNudgeEntity mergeRelationshipNudgeAccumulators({
  required RelationshipNudgeEntity winner,
  required RelationshipNudgeEntity local,
  required RelationshipNudgeEntity incoming,
}) {
  final merged = mergeNudgeAccumulators(
    winner: _relationshipNudgeView(winner),
    local: _relationshipNudgeView(local),
    incoming: _relationshipNudgeView(incoming),
  );
  return winner.copyWith(
    vectorClock: merged.vectorClock,
    totalVisibleMs: merged.totalVisibleMs,
    impressionCount: merged.impressionCount,
    ratings: merged.ratings,
    snoozeHistory: merged.snoozeHistory,
    snoozedUntil: merged.snoozedUntil,
    lastSnoozeDuration: merged.lastSnoozeDuration,
    dismissalHistory: merged.dismissalHistory,
    staleAt: merged.staleAt,
    dismissedForDayAt: merged.dismissedForDayAt,
    activationCount: merged.activationCount,
    firstShownAt: merged.firstShownAt,
    lastShownAt: merged.lastShownAt,
  );
}

NudgeAccumulatorView _goalNudgeView(GoalNudgeEntity e) => (
  vectorClock: e.vectorClock,
  activationCount: e.activationCount,
  ratings: e.ratings,
  snoozeHistory: e.snoozeHistory,
  snoozedUntil: e.snoozedUntil,
  lastSnoozeDuration: e.lastSnoozeDuration,
  dismissalHistory: e.dismissalHistory,
  dismissedForDayAt: e.dismissedForDayAt,
  staleAt: e.staleAt,
  totalVisibleMs: e.totalVisibleMs,
  impressionCount: e.impressionCount,
  firstShownAt: e.firstShownAt,
  lastShownAt: e.lastShownAt,
);

NudgeAccumulatorView _relationshipNudgeView(RelationshipNudgeEntity e) => (
  vectorClock: e.vectorClock,
  activationCount: e.activationCount,
  ratings: e.ratings,
  snoozeHistory: e.snoozeHistory,
  snoozedUntil: e.snoozedUntil,
  lastSnoozeDuration: e.lastSnoozeDuration,
  dismissalHistory: e.dismissalHistory,
  dismissedForDayAt: e.dismissedForDayAt,
  staleAt: e.staleAt,
  totalVisibleMs: e.totalVisibleMs,
  impressionCount: e.impressionCount,
  firstShownAt: e.firstShownAt,
  lastShownAt: e.lastShownAt,
);

String _dayDismissalOrderKey(NudgeDayDismissal event) =>
    '${event.id}\u0000'
    '${event.dismissedAt.toUtc().toIso8601String()}\u0000'
    '${event.dismissedUntil.toUtc().toIso8601String()}\u0000'
    '${event.activation.toString().padLeft(10, '0')}\u0000'
    '${event.utcOffsetMinutes.toString().padLeft(5, '0')}';

int _compareNudgeSnoozes(NudgeSnooze a, NudgeSnooze b) {
  final byId = a.id.compareTo(b.id);
  if (byId != 0) return byId;
  final byStart = a.snoozedAt.compareTo(b.snoozedAt);
  if (byStart != 0) return byStart;
  final byUntil = a.snoozedUntil.compareTo(b.snoozedUntil);
  if (byUntil != 0) return byUntil;
  final byActivation = a.activation.compareTo(b.activation);
  if (byActivation != 0) return byActivation;
  final byDuration = a.duration.index.compareTo(b.duration.index);
  if (byDuration != 0) return byDuration;
  final byMinutes = a.durationMinutes.compareTo(b.durationMinutes);
  if (byMinutes != 0) return byMinutes;
  final byOffset = a.utcOffsetMinutes.compareTo(b.utcOffsetMinutes);
  if (byOffset != 0) return byOffset;
  final byReturnOffsetPresence = (a.returnUtcOffsetMinutes == null ? 1 : 0)
      .compareTo(b.returnUtcOffsetMinutes == null ? 1 : 0);
  if (byReturnOffsetPresence != 0) return byReturnOffsetPresence;
  final byReturnOffset = (a.returnUtcOffsetMinutes ?? a.utcOffsetMinutes)
      .compareTo(b.returnUtcOffsetMinutes ?? b.utcOffsetMinutes);
  if (byReturnOffset != 0) return byReturnOffset;
  // An older client re-serializes an event without the reason it does not
  // know: the copy that still carries one sorts first, so every replica
  // keeps it (ADR 0063).
  final byReasonPresence = (a.reason == null ? 1 : 0).compareTo(
    b.reason == null ? 1 : 0,
  );
  if (byReasonPresence != 0) return byReasonPresence;
  return (a.reason?.index ?? 0).compareTo(b.reason?.index ?? 0);
}

DateTime? _earliestInstant(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isBefore(b) ? a : b;
}

DateTime? _latestInstant(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}
