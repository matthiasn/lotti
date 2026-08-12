import 'package:lotti/classes/goal_enums.dart';

/// Result of evaluating one criterion node for one period.
class GoalCriterionResult {
  const GoalCriterionResult({
    required this.criterionId,
    required this.actual,
    required this.target,
    required this.ratio,
    required this.satisfied,
    required this.sampleCount,
    this.paceFeasible,
    this.deficit,
    this.buffer,
    this.projectedDaysToTarget,
  });

  /// The node this result belongs to (`GoalCriterion.criterionId`).
  final String criterionId;

  /// The aggregated value (for composites: the number of satisfied
  /// children).
  final num actual;

  /// The target compared against (for composites: children required).
  final num target;

  /// Progress toward the target, clamped to 0..1. For `atMost` criteria this
  /// is 1.0 while under the cap and decays as the cap is exceeded.
  final double ratio;

  /// Whether the criterion is met for this period.
  final bool satisfied;

  /// Number of in-range days that carried data for this node (min across
  /// children for composites).
  final int sampleCount;

  /// For calendar-window habit quotas: whether the remaining days of the
  /// period can still complete the quota (assuming at most one creditable
  /// success per day). Null when pace is not applicable (rolling windows,
  /// metric leaves, already satisfied).
  final bool? paceFeasible;

  /// Rolling-window habit leaves (and `allOf` routines of them): the
  /// days-to-recovery — the fewest days of perfect adherence to bring the
  /// rolling count back to target, SIMULATING the window sliding forward
  /// (each future success day also ages the oldest in-window success out, so
  /// this can exceed `target - successesInWindow`). `0` means at or above
  /// rate; `target` means the window is empty (a restart, the warmest
  /// register). Null for metric/measurable leaves and calendar windows.
  final int? deficit;

  /// Rolling-window habit leaves at or above rate (deficit 0): the number of
  /// days until the count would drop below target if no new success arrives —
  /// the aging day of the critical `(creditable - target)`-th oldest success.
  /// `0` means a success expires at the next midnight. Null when below rate,
  /// or not a rolling habit leaf.
  final int? buffer;

  /// Days until a favorable observed health trend reaches this leaf's target.
  /// Null means the leaf is already satisfied, lacks enough samples, is not a
  /// supported health level, is moving the wrong way, or would need longer
  /// than the policy's bounded projection horizon.
  final int? projectedDaysToTarget;
}

/// Result of evaluating a whole criteria tree for one period.
class GoalEvaluation {
  const GoalEvaluation({
    required this.attainment,
    required this.satisfied,
    required this.dataCoverage,
    required this.results,
    this.paceFeasible,
    this.deficit,
    this.buffer,
    this.onTrackByTrend = false,
  });

  /// Overall progress 0..1 (composite fold of leaf ratios).
  final double attainment;

  /// Whether the root criterion is satisfied.
  final bool satisfied;

  /// The most pessimistic leaf data coverage: sampled days divided by
  /// elapsed days of that leaf's period. Habit leaves always report full
  /// coverage — the absence of a completion *is* signal, unlike a silent
  /// sensor. Drives [GoalTrackStatus.insufficientData].
  final double dataCoverage;

  /// Per-node results keyed by criterion id (leaves and composites).
  final Map<String, GoalCriterionResult> results;

  /// Combined pace feasibility (see [GoalCriterionResult.paceFeasible]).
  final bool? paceFeasible;

  /// The root criterion's days-to-recovery, when the root is a rolling-window
  /// habit leaf (see [GoalCriterionResult.deficit]). Null for composites,
  /// metric leaves and calendar windows — the goal-level surfaces only lift a
  /// single-leaf goal's deficit; a composite's per-leaf deficits stay in
  /// [results].
  final int? deficit;

  /// The root criterion's buffer when at rate (see
  /// [GoalCriterionResult.buffer]). Null under the same conditions as
  /// [deficit].
  final int? buffer;

  /// Whether every required unsatisfied health leaf is moving toward its
  /// target fast enough to reach it inside the bounded projection horizon.
  /// This can make a goal on-track, but never marks its threshold satisfied.
  final bool onTrackByTrend;
}
