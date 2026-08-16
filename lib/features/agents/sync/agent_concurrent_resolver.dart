import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
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
    final localVersion = _specVersionNumber(local.versionId);
    final incomingVersion = _specVersionNumber(incoming.versionId);
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
    final localVersion = _specVersionNumber(local.specVersionId);
    final incomingVersion = _specVersionNumber(incoming.specVersionId);
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
/// null for foreign id shapes — those fall back to LWW.
int? _specVersionNumber(String specVersionId) {
  final match = RegExp(r'spec-v(\d+)').firstMatch(specVersionId);
  return match == null ? null : int.tryParse(match.group(1)!);
}

const Set<NudgeStatus> _terminalNudgeStatuses = {
  NudgeStatus.retired,
  NudgeStatus.expired,
  NudgeStatus.superseded,
  NudgeStatus.failed,
};

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
  return (a.returnUtcOffsetMinutes ?? a.utcOffsetMinutes).compareTo(
    b.returnUtcOffsetMinutes ?? b.utcOffsetMinutes,
  );
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
