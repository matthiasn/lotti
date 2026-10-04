import 'dart:convert';

import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/agent_link.dart';
import 'package:lotti/classes/agents/change_set.dart';
import 'package:lotti/classes/g_counter.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/agents/sync/agent_lww_timestamp.dart';

part 'agent_concurrent_resolver_merge_concurrent_agent_entities_part.dart';
part 'agent_concurrent_resolver_merge_nudge_accumulators_part.dart';

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
