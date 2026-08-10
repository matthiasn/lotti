import 'package:lotti/classes/goal_enums.dart';

/// One day in a habit leaf's rolling window (or the edge cell that just left
/// it) — the atoms the detail-page grid and the list window-strip render.
///
/// The window is bookkeeping, never vocabulary: these cells drive the
/// *picture*, while copy stays in events-and-time language. A cell is
/// `done` when the habit succeeded that local day; `isToday` marks the
/// window's trailing edge (rendered dashed); `agingOut` marks the oldest
/// success that will slide out of the window at the next midnight while the
/// leaf is exactly at target (its pulsing ring is the buffer made visible);
/// `slipped` marks the day that has already left the window (the greyed
/// left-edge cell).
class GoalDayCell {
  const GoalDayCell({
    required this.day,
    required this.done,
    this.isToday = false,
    this.agingOut = false,
    this.slipped = false,
  });

  final DateTime day;
  final bool done;
  final bool isToday;
  final bool agingOut;
  final bool slipped;
}

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
    this.dayCells,
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

  /// Rolling-window habit leaves only: `target - successesInWindow`, floored
  /// at 0 — the number of days-to-recovery (at most one creditable success
  /// per day, so the deficit *is* the days needed). `0` means at rate;
  /// `target` means the window is empty (a restart, the warmest register).
  /// Null for metric/measurable leaves, composites, and calendar windows.
  final int? deficit;

  /// Rolling-window habit leaves at rate (deficit 0): the number of days
  /// until the OLDEST in-window success ages out — the slack before the
  /// count drops. `0` means a success expires at the next midnight (aging
  /// out). Null when not at rate, or not a rolling habit leaf.
  final int? buffer;

  /// Rolling-window habit leaves: the per-day cells for the grid/strip
  /// (window days plus the slipped left-edge). Null for other leaves.
  final List<GoalDayCell>? dayCells;
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
}
