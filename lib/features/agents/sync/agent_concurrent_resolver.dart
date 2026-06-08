import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
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
  return compareClocksCanonically(incomingVc, localVc) > 0
      ? ConcurrentWinner.incoming
      : ConcurrentWinner.local;
}

/// Type-specific **monotonic** resolution for two *concurrent* versions of one
/// agent entity, applied BEFORE the generic [resolveConcurrent] LWW. Returns
/// `null` to defer to LWW. Pure and symmetric — both replicas pass the same
/// `(local, incoming)` pair and compute the same winner — so the result stays
/// convergent regardless of arrival order.
///
/// The two rules close ADR 0022 conflict holes that raw wall-clock LWW on a
/// shared id mishandles:
///
/// - **Durable knowledge — retraction is terminal.** A concurrent retract must
///   not be revived by a concurrent edit/confirm of the same knowledge entry
///   (a later wall-clock edit would otherwise resurrect knowledge the user
///   deliberately removed). When exactly one side is retracted, it wins.
/// - **Scheduled wakes — a future reschedule beats a past consume.** A pending
///   pre-warm targeting a strictly-later instant wins over a concurrent consume
///   of an earlier instant, so a re-armed wake is not silently dropped.
///   Same-instant conflicts defer to LWW (the consume wins), so a stale pending
///   can never resurrect a wake that already fired — no double-fire.
ConcurrentWinner? resolveConcurrentAgentEntityOverride({
  required AgentDomainEntity local,
  required AgentDomainEntity incoming,
}) {
  if (local is PlannerKnowledgeEntity && incoming is PlannerKnowledgeEntity) {
    final localRetracted = local.status == KnowledgeStatus.retracted;
    final incomingRetracted = incoming.status == KnowledgeStatus.retracted;
    if (localRetracted == incomingRetracted) return null;
    return localRetracted ? ConcurrentWinner.local : ConcurrentWinner.incoming;
  }
  if (local is ScheduledWakeEntity && incoming is ScheduledWakeEntity) {
    final byTarget = local.scheduledAt.compareTo(incoming.scheduledAt);
    if (byTarget == 0) return null;
    return byTarget > 0 ? ConcurrentWinner.local : ConcurrentWinner.incoming;
  }
  return null;
}

/// A total, replica-independent ordering of two vector clocks. Compares each
/// host's counter (0 when a host is absent) in sorted host order and returns
/// the sign of the first difference: `1` if [a] is greater, `-1` if [b] is
/// greater, `0` if the clocks are identical. Independent of map iteration
/// order, so two devices comparing the same pair agree.
int compareClocksCanonically(VectorClock a, VectorClock b) {
  final hosts = <String>{...a.vclock.keys, ...b.vclock.keys}.toList()..sort();
  for (final host in hosts) {
    final counterA = a.get(host);
    final counterB = b.get(host);
    if (counterA != counterB) return counterA > counterB ? 1 : -1;
  }
  return 0;
}

/// Merges the convergent (per-host G-counter) fields of two **concurrent**
/// [AgentStateEntity] versions into [winner]: each counter becomes the
/// element-wise max (CRDT join) of [local] and [incoming], so no increment from
/// either device is lost, while every *non-counter* field stays as the
/// deterministic LWW winner ([winner], chosen by [resolveConcurrent]).
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
