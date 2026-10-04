part of 'agent_concurrent_resolver.dart';

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
