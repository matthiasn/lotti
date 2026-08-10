/// Shared vocabulary of the goal domain.
///
/// These enums are spoken by three parties that must agree exactly: the
/// deterministic evaluator (`GoalProgressEvaluator` + `GoalTrackPolicy`)
/// computes them, the goal agent's report tool restates them, and the
/// evaluation harness asserts on them. Do not fork a near-identical enum for
/// one of those sides.
library;

/// How a metric criterion folds the daily values inside its window into one
/// number that is compared against the target.
enum GoalAggregation {
  /// Mean of the per-day sums over the days that have data.
  ///
  /// "Average 10,000 steps a day" over a rolling week. Days without any
  /// sample are excluded from the mean rather than counted as zero — a dead
  /// step tracker is missing data, not a sedentary day.
  dailySumThenAverage,

  /// Sum of the per-day sums over the window.
  sum,

  /// Number of days in the window that have any recorded value.
  count,

  /// Maximum per-day sum in the window.
  max,
}

/// Which side of the target counts as success for a metric criterion.
enum GoalDirection {
  /// The aggregate must reach or exceed the target ("at least 10,000").
  atLeast,

  /// The aggregate must stay at or below the target ("at most 2 espressos").
  atMost,
}

/// Lifecycle of one immutable `goalSpecVersion` (ADR 0053 Decision 2).
///
/// Versions are never edited: a revision writes a new version and moves the
/// head, and the previous one becomes [superseded]. The version history IS
/// the ten-year story of the goal.
enum GoalSpecVersionStatus { active, superseded }

/// Deterministic on/off-track classification of a goal for one period.
///
/// Derived exclusively by `GoalTrackPolicy` from evaluator output — never by
/// a model. The goal agent's report status enum is this enum.
enum GoalTrackStatus {
  /// The current period's criteria are met (or attainment is at 100%).
  onTrack,

  /// Behind, but not decisively: attainment is close to target, the shortfall
  /// is within the grace allowance, or a calendar quota is still feasibly
  /// completable this period.
  atRisk,

  /// Decisively behind: sustained low attainment, or a calendar quota that
  /// can no longer be met this period.
  offTrack,

  /// The trailing window still misses the target, but the most recent days
  /// are at or above pace — the turnaround case that retires "you're behind"
  /// nudges.
  recovering,

  /// The goal had a target date, it has passed, and the criteria were met.
  /// Open-ended goals (no target date) never reach this status.
  achieved,

  /// Too little signal to judge: data coverage over the elapsed part of the
  /// period is below the policy minimum. Never guilt-trip over a data gap.
  insufficientData,
}

/// Which way a goal is trending across its two most recent progress
/// registers — the direction arrow on the agents list. Computed in the
/// health projection (`goalAgentHealthProvider`); purely a picture, it
/// never becomes a number or a label.
enum GoalHealthDirection { up, flat, down }
