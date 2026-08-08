import 'package:lotti/features/goals/model/goal_enums.dart';

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

  @override
  String toString() =>
      'GoalCriterionResult($criterionId: actual=$actual/$target '
      'ratio=${ratio.toStringAsFixed(3)} satisfied=$satisfied '
      'samples=$sampleCount pace=$paceFeasible)';
}

/// Result of evaluating a whole criteria tree for one period.
class GoalEvaluation {
  const GoalEvaluation({
    required this.attainment,
    required this.satisfied,
    required this.dataCoverage,
    required this.results,
    this.paceFeasible,
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

  @override
  String toString() =>
      'GoalEvaluation(attainment=${attainment.toStringAsFixed(3)} '
      'satisfied=$satisfied coverage=${dataCoverage.toStringAsFixed(2)} '
      'pace=$paceFeasible nodes=${results.length})';
}
