import 'dart:math' as math;

import 'package:lotti/features/goals/evaluation/goal_evaluation.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/model/goal_criterion.dart';
import 'package:lotti/features/goals/model/goal_enums.dart';
import 'package:lotti/features/goals/model/goal_window.dart';

/// Pure fold of a [GoalCriterion] tree over a [GoalSignalWindow].
///
/// This is the deterministic tier of the goal-agent wake architecture
/// (ADR 0054): it runs on every tick, on every device, and costs nothing.
/// The LLM only ever *restates* what this evaluator computed — it never
/// derives progress itself.
class GoalProgressEvaluator {
  const GoalProgressEvaluator();

  /// Evaluates [criterion] for the period containing [reference].
  GoalEvaluation evaluate(
    GoalCriterion criterion,
    GoalSignalWindow signals,
    DateTime reference,
  ) {
    final results = <String, GoalCriterionResult>{};
    final root = _node(criterion, signals, reference, results);
    return GoalEvaluation(
      attainment: root.result.ratio,
      satisfied: root.result.satisfied,
      dataCoverage: root.coverage,
      results: results,
      paceFeasible: root.result.paceFeasible,
    );
  }

  /// Attainment over just the trailing [days] days — the "recovering"
  /// signal: a bad trailing week with on-pace recent days is a turnaround,
  /// not a failure.
  ///
  /// Metric and measurable leaves are re-windowed to `rollingDays(days)`;
  /// habit leaves are excluded (a weekly quota has no meaningful 3-day
  /// slice). Composites fold the included children — mean for allOf and
  /// atLeastCount, max for anyOf. Returns null when the tree contains no
  /// re-windowable leaf.
  double? shortTermAttainment(
    GoalCriterion criterion,
    GoalSignalWindow signals,
    DateTime reference, {
    int days = 3,
  }) {
    final window = GoalWindow.rollingDays(count: days);
    switch (criterion) {
      case GoalCriterionMetric(
        :final dataType,
        :final aggregation,
        :final target,
        :final direction,
      ):
        final range = window.periodRange(reference);
        final series = signals.quantitativeInRange(
          dataType,
          range.start,
          range.end,
        );
        return _leafRatio(series, aggregation, target, direction);
      case GoalCriterionMeasurable(
        :final dataTypeId,
        :final aggregation,
        :final target,
        :final direction,
      ):
        final range = window.periodRange(reference);
        final series = signals.measurableInRange(
          dataTypeId,
          range.start,
          range.end,
        );
        return _leafRatio(series, aggregation, target, direction);
      case GoalCriterionHabit():
        return null;
      case GoalCriterionAllOf(:final criteria):
      case GoalCriterionAtLeastCount(:final criteria):
        final values = _shortTermChildren(criteria, signals, reference, days);
        if (values.isEmpty) return null;
        return values.reduce((a, b) => a + b) / values.length;
      case GoalCriterionAnyOf(:final criteria):
        final values = _shortTermChildren(criteria, signals, reference, days);
        if (values.isEmpty) return null;
        return values.reduce(math.max);
    }
  }

  List<double> _shortTermChildren(
    List<GoalCriterion> criteria,
    GoalSignalWindow signals,
    DateTime reference,
    int days,
  ) => [
    for (final child in criteria)
      if (shortTermAttainment(child, signals, reference, days: days)
          case final double value)
        value,
  ];

  _NodeOutcome _node(
    GoalCriterion criterion,
    GoalSignalWindow signals,
    DateTime reference,
    Map<String, GoalCriterionResult> results,
  ) {
    final outcome = switch (criterion) {
      GoalCriterionMetric(
        :final criterionId,
        :final dataType,
        :final window,
        :final aggregation,
        :final target,
        :final direction,
      ) =>
        _metricLeaf(
          criterionId: criterionId,
          series: () {
            final range = window.periodRange(reference);
            return signals.quantitativeInRange(
              dataType,
              range.start,
              range.end,
            );
          }(),
          window: window,
          reference: reference,
          aggregation: aggregation,
          target: target,
          direction: direction,
        ),
      GoalCriterionMeasurable(
        :final criterionId,
        :final dataTypeId,
        :final window,
        :final aggregation,
        :final target,
        :final direction,
      ) =>
        _metricLeaf(
          criterionId: criterionId,
          series: () {
            final range = window.periodRange(reference);
            return signals.measurableInRange(
              dataTypeId,
              range.start,
              range.end,
            );
          }(),
          window: window,
          reference: reference,
          aggregation: aggregation,
          target: target,
          direction: direction,
        ),
      GoalCriterionHabit(
        :final criterionId,
        :final habitId,
        :final window,
        :final targetCount,
      ) =>
        _habitLeaf(
          criterionId: criterionId,
          habitId: habitId,
          window: window,
          targetCount: targetCount,
          signals: signals,
          reference: reference,
        ),
      GoalCriterionAllOf(:final criterionId, :final criteria) => _composite(
        criterionId: criterionId,
        criteria: criteria,
        signals: signals,
        reference: reference,
        results: results,
        kind: _CompositeKind.allOf,
      ),
      GoalCriterionAnyOf(:final criterionId, :final criteria) => _composite(
        criterionId: criterionId,
        criteria: criteria,
        signals: signals,
        reference: reference,
        results: results,
        kind: _CompositeKind.anyOf,
      ),
      GoalCriterionAtLeastCount(
        :final criterionId,
        :final criteria,
        :final successes,
      ) =>
        _composite(
          criterionId: criterionId,
          criteria: criteria,
          signals: signals,
          reference: reference,
          results: results,
          kind: _CompositeKind.atLeastCount,
          successes: successes,
        ),
    };
    results[outcome.result.criterionId] = outcome.result;
    return outcome;
  }

  _NodeOutcome _metricLeaf({
    required String criterionId,
    required Map<DateTime, num> series,
    required GoalWindow window,
    required DateTime reference,
    required GoalAggregation aggregation,
    required num target,
    required GoalDirection direction,
  }) {
    final sampleCount = series.length;
    final actual = _aggregate(series, aggregation);
    final double ratio;
    final bool satisfied;
    if (sampleCount == 0) {
      // No signal at all: never conclude anything (not even "under the cap"
      // for atMost) — coverage below routes this to insufficientData.
      ratio = 0;
      satisfied = false;
    } else {
      (ratio, satisfied) = _compare(actual, target, direction);
    }
    final elapsed = window.elapsedDays(reference);
    final coverage = elapsed == 0
        ? 1.0
        : math.min(1, sampleCount / elapsed).toDouble();
    return _NodeOutcome(
      result: GoalCriterionResult(
        criterionId: criterionId,
        actual: actual,
        target: target,
        ratio: ratio,
        satisfied: satisfied,
        sampleCount: sampleCount,
      ),
      coverage: coverage,
    );
  }

  _NodeOutcome _habitLeaf({
    required String criterionId,
    required String habitId,
    required GoalWindow window,
    required int targetCount,
    required GoalSignalWindow signals,
    required DateTime reference,
  }) {
    final range = window.periodRange(reference);
    final byDay = signals.habitSuccessesInRange(
      habitId,
      range.start,
      range.end,
    );
    final actual = byDay.values.fold<int>(0, (sum, count) => sum + count);
    final satisfied = actual >= targetCount;
    final ratio = targetCount <= 0
        ? 1.0
        : math.min(1, actual / targetCount).toDouble();

    // Pace: only calendar periods have a fixed end to run out of road
    // against; each remaining day is worth at most one creditable success,
    // and today only counts if it has not already been credited.
    bool? paceFeasible;
    if (!satisfied &&
        (window is GoalWindowCalendarWeek ||
            window is GoalWindowCalendarMonth)) {
      final day = GoalWindow.dayUtc(reference);
      final todayCredited = (byDay[day] ?? 0) > 0;
      final creditableRemaining =
          range.end.difference(day).inDays + (todayCredited ? 0 : 1);
      paceFeasible = targetCount - actual <= creditableRemaining;
    }
    return _NodeOutcome(
      result: GoalCriterionResult(
        criterionId: criterionId,
        actual: actual,
        target: targetCount,
        ratio: ratio,
        satisfied: satisfied,
        sampleCount: byDay.length,
        paceFeasible: paceFeasible,
      ),
      // A habit with no completion is genuinely uncompleted — absence IS
      // signal here, unlike a silent step tracker.
      coverage: 1,
    );
  }

  _NodeOutcome _composite({
    required String criterionId,
    required List<GoalCriterion> criteria,
    required GoalSignalWindow signals,
    required DateTime reference,
    required Map<String, GoalCriterionResult> results,
    required _CompositeKind kind,
    int successes = 0,
  }) {
    if (criteria.isEmpty) {
      throw ArgumentError(
        'Composite criterion $criterionId has no children.',
      );
    }
    final children = [
      for (final child in criteria) _node(child, signals, reference, results),
    ];
    final ratios = children.map((c) => c.result.ratio).toList();
    final satisfiedCount = children.where((c) => c.result.satisfied).length;

    final double ratio;
    final bool satisfied;
    final num target;
    final bool? pace;
    switch (kind) {
      case _CompositeKind.allOf:
        ratio = ratios.reduce((a, b) => a + b) / ratios.length;
        satisfied = satisfiedCount == children.length;
        target = children.length;
        pace = _paceAll(children);
      case _CompositeKind.anyOf:
        ratio = ratios.reduce(math.max);
        satisfied = satisfiedCount > 0;
        target = 1;
        pace = _paceAny(children);
      case _CompositeKind.atLeastCount:
        final sorted = [...ratios]..sort((a, b) => b.compareTo(a));
        final top = sorted.take(math.max(1, successes)).toList();
        ratio = top.reduce((a, b) => a + b) / top.length;
        satisfied = satisfiedCount >= successes;
        target = successes;
        pace = _paceAll(children);
    }
    return _NodeOutcome(
      result: GoalCriterionResult(
        criterionId: criterionId,
        actual: satisfiedCount,
        target: target,
        ratio: ratio,
        satisfied: satisfied,
        sampleCount: children.map((c) => c.result.sampleCount).reduce(math.min),
        paceFeasible: pace,
      ),
      coverage: children.map((c) => c.coverage).reduce(math.min),
    );
  }

  /// allOf/atLeastCount pace: one infeasible child sinks the composite; a
  /// composite is only affirmatively on pace when some child said so and
  /// none said otherwise.
  bool? _paceAll(List<_NodeOutcome> children) {
    var sawTrue = false;
    for (final child in children) {
      switch (child.result.paceFeasible) {
        case false:
          return false;
        case true:
          sawTrue = true;
        case null:
          break;
      }
    }
    return sawTrue ? true : null;
  }

  /// anyOf pace: one feasible child keeps the composite alive; it is only
  /// infeasible when every child that has an opinion says infeasible.
  bool? _paceAny(List<_NodeOutcome> children) {
    var sawFalse = false;
    for (final child in children) {
      switch (child.result.paceFeasible) {
        case true:
          return true;
        case false:
          sawFalse = true;
        case null:
          break;
      }
    }
    return sawFalse ? false : null;
  }

  num _aggregate(Map<DateTime, num> series, GoalAggregation aggregation) {
    if (series.isEmpty) return 0;
    switch (aggregation) {
      case GoalAggregation.dailySumThenAverage:
        return series.values.reduce((a, b) => a + b) / series.length;
      case GoalAggregation.sum:
        return series.values.reduce((a, b) => a + b);
      case GoalAggregation.count:
        return series.length;
      case GoalAggregation.max:
        return series.values.reduce(math.max);
    }
  }

  (double, bool) _compare(num actual, num target, GoalDirection direction) {
    switch (direction) {
      case GoalDirection.atLeast:
        final satisfied = actual >= target;
        final ratio = target <= 0
            ? 1.0
            : math.min(1, actual / target).toDouble();
        return (math.max(0, ratio).toDouble(), satisfied);
      case GoalDirection.atMost:
        if (actual <= target) return (1.0, true);
        final ratio = target <= 0
            ? 0.0
            : math.min(1, target / actual).toDouble();
        return (math.max(0, ratio).toDouble(), false);
    }
  }
}

enum _CompositeKind { allOf, anyOf, atLeastCount }

class _NodeOutcome {
  const _NodeOutcome({required this.result, required this.coverage});

  final GoalCriterionResult result;
  final double coverage;
}

/// Leaf ratio for [GoalProgressEvaluator.shortTermAttainment] — same compare
/// semantics as the full evaluation, without result bookkeeping.
double _leafRatio(
  Map<DateTime, num> series,
  GoalAggregation aggregation,
  num target,
  GoalDirection direction,
) {
  if (series.isEmpty) return 0;
  const evaluator = GoalProgressEvaluator();
  final actual = evaluator._aggregate(series, aggregation);
  final (ratio, _) = evaluator._compare(actual, target, direction);
  return ratio;
}
