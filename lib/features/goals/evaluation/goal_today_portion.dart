import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/evaluation/goal_evaluation.dart';
import 'package:lotti/features/goals/evaluation/goal_progress_evaluator.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';

/// The `retireReason` provenance of a banner that stood down because today's
/// part of its goal was done — by Phase A's sweep or Phase B's persistence.
const goalTodayPortionMetRetireReason = "today's part done";

/// Whether the user has done **today's part** of [criterion] — the day's
/// share of the goal — even while the window as a whole is still behind.
///
/// The goal's status stays window-driven: three good days do not undo a bad
/// week. But a banner asking the user to act on the goal has nothing left
/// to ask once today's share is in, and must not keep chiding until the
/// rolling average recovers. That is the relationship banner's behaviour —
/// a check-in satisfies the cadence and its banner retires — carried over
/// to every goal.
///
/// A leaf's part is done when its window is already satisfied (nothing is
/// left to do in it), or when today's slice of it is:
///
/// * a per-day target (`dailySumThenAverage`, `max`) — today's own value
///   reaches the target;
/// * a period total (`sum`) — today's value reaches the even per-day share
///   of the total, `target / period length`;
/// * a count of days with data (`count`) — today has data;
/// * a habit quota — today is credited: at least one success, or the whole
///   quota on a one-day window, which is the day itself.
///
/// An `atMost` leaf is never done before the day is: zero coffees at noon
/// says nothing about the evening, so a ceiling cannot vouch for today.
/// Composites fold their children's answers — every child for `allOf`, one
/// for `anyOf`, `successes` of them for `atLeastCount` — and a criterion of
/// an unknown kind is never done (ADR 0145).
///
/// [evaluation] is the window evaluation of the same [criterion], [signals]
/// and [reference]; the evaluator only re-runs over the day slice.
bool goalTodayPortionMet({
  required GoalCriterion criterion,
  required GoalSignalWindow signals,
  required GoalEvaluation evaluation,
  required DateTime reference,
  GoalProgressEvaluator evaluator = const GoalProgressEvaluator(),
}) {
  // The evaluator scores an unknown leaf as never met, so the slice is safe
  // to evaluate; the veto below keeps an `anyOf` sibling from vouching for a
  // goal this build cannot read at all.
  final today = evaluator.evaluate(
    _todaySlice(criterion, reference),
    signals,
    reference,
  );

  bool satisfied(GoalEvaluation of, String criterionId) =>
      of.results[criterionId]?.satisfied ?? false;

  bool done(GoalCriterion node) => switch (node) {
    GoalCriterionUnsupported() => false,
    GoalCriterionAllOf(:final criteria) => criteria.every(done),
    GoalCriterionAnyOf(:final criteria) => criteria.any(done),
    GoalCriterionAtLeastCount(:final criteria, :final successes) =>
      criteria.where(done).length >= successes,
    _ when _direction(node) == GoalDirection.atMost => false,
    _ =>
      satisfied(evaluation, node.criterionId) ||
          satisfied(today, node.criterionId),
  };

  return !goalCriterionHasUnsupported(criterion) && done(criterion);
}

/// [node] re-windowed to the reference day, every leaf keeping its id so its
/// result is addressable next to the window evaluation's.
GoalCriterion _todaySlice(GoalCriterion node, DateTime reference) {
  const day = GoalWindow.day();
  num share(num target, GoalAggregation aggregation, GoalWindow window) =>
      switch (aggregation) {
        GoalAggregation.sum => target / window.lengthInDays(reference),
        GoalAggregation.count => target > 0 ? 1 : 0,
        GoalAggregation.dailySumThenAverage || GoalAggregation.max => target,
      };
  return switch (node) {
    final GoalCriterionMetric leaf => leaf.copyWith(
      window: day,
      target: share(leaf.target, leaf.aggregation, leaf.window),
    ),
    final GoalCriterionMeasurable leaf => leaf.copyWith(
      window: day,
      target: share(leaf.target, leaf.aggregation, leaf.window),
    ),
    final GoalCriterionCategoryTime leaf => leaf.copyWith(
      window: day,
      targetHours: share(leaf.targetHours, leaf.aggregation, leaf.window),
    ),
    final GoalCriterionLabelTime leaf => leaf.copyWith(
      window: day,
      targetHours: share(leaf.targetHours, leaf.aggregation, leaf.window),
    ),
    final GoalCriterionCheckInTime leaf => leaf.copyWith(
      window: day,
      targetMinutes: share(leaf.targetMinutes, leaf.aggregation, leaf.window),
    ),
    final GoalCriterionHabit leaf => leaf.copyWith(
      window: day,
      targetCount: leaf.window is GoalWindowDay
          ? leaf.targetCount
          : (leaf.targetCount > 0 ? 1 : 0),
    ),
    final GoalCriterionAllOf composite => composite.copyWith(
      criteria: [for (final c in composite.criteria) _todaySlice(c, reference)],
    ),
    final GoalCriterionAnyOf composite => composite.copyWith(
      criteria: [for (final c in composite.criteria) _todaySlice(c, reference)],
    ),
    final GoalCriterionAtLeastCount composite => composite.copyWith(
      criteria: [for (final c in composite.criteria) _todaySlice(c, reference)],
    ),
    GoalCriterionUnsupported() => node,
  };
}

GoalDirection _direction(GoalCriterion leaf) => switch (leaf) {
  GoalCriterionMetric(:final direction) ||
  GoalCriterionMeasurable(:final direction) ||
  GoalCriterionCategoryTime(:final direction) ||
  GoalCriterionLabelTime(:final direction) ||
  GoalCriterionCheckInTime(:final direction) => direction,
  // A habit quota is a floor: done at least so many times.
  _ => GoalDirection.atLeast,
};
