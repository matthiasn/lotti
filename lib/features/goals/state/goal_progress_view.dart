import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_health_data_types.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/evaluation/goal_progress_evaluator.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_measurable_capture_state.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/widgets/day_indicators/day_mark.dart';

part 'goal_progress_view_goal_metric_progress_view_part.dart';
part 'goal_progress_view_progress_view_part.dart';

/// Builds the presentation projection from the same daily aggregates the
/// deterministic evaluator uses. This keeps the grid and the runtime verdict
/// on one source of truth instead of re-querying habit semantics in the UI.
GoalProgressView buildGoalProgressView({
  required GoalCriterion criteria,
  required GoalSignalWindow signals,
  required DateTime reference,
  int? historyDays,
  Map<String, String> habitNames = const {},
  Map<String, MeasurableDataType> measurableDefinitions = const {},
  Map<String, String> categoryNames = const {},
  Map<String, String> labelNames = const {},
  Set<String> agentRecordedMeasurementIds = const {},
  Map<String, GoalRecordedMeasurementProvenance>
      recordedMeasurementProvenanceById =
      const {},
}) {
  final today = GoalWindow.dayUtc(reference);
  final evaluation = const GoalProgressEvaluator().evaluate(
    criteria,
    signals,
    reference,
  );
  final habitLeaves = <GoalCriterionHabit>[];
  final metricLeaves = <GoalCriterionMetric>[];
  final measurableLeaves = <GoalCriterionMeasurable>[];
  final categoryTimeLeaves = <GoalCriterionCategoryTime>[];
  final labelTimeLeaves = <GoalCriterionLabelTime>[];

  void visit(GoalCriterion criterion) {
    switch (criterion) {
      case final GoalCriterionHabit habit:
        habitLeaves.add(habit);
      case final GoalCriterionMetric metric:
        metricLeaves.add(metric);
      case final GoalCriterionMeasurable measurable:
        measurableLeaves.add(measurable);
      case final GoalCriterionCategoryTime categoryTime:
        categoryTimeLeaves.add(categoryTime);
      case final GoalCriterionLabelTime labelTime:
        labelTimeLeaves.add(labelTime);
      case GoalCriterionAllOf(criteria: final children):
        children.forEach(visit);
      case GoalCriterionAnyOf(criteria: final children):
        children.forEach(visit);
      case GoalCriterionAtLeastCount(criteria: final children):
        children.forEach(visit);
    }
  }

  visit(criteria);
  final habits = [
    for (final habit in habitLeaves)
      _habitProgressView(
        habit: habit,
        signals: signals,
        reference: reference,
        today: today,
        habitNames: habitNames,
        historyDays: historyDays,
      ),
  ];

  final compositeCompactWindow = switch (criteria) {
    GoalCriterionAllOf() ||
    GoalCriterionAnyOf() ||
    GoalCriterionAtLeastCount() => [
      for (var offset = (historyDays ?? 7) - 1; offset >= 0; offset--)
        _criterionDayState(
          criteria,
          signals,
          GoalWindow.dayUtc(today.subtract(Duration(days: offset))),
        ),
    ],
    _ => null,
  };
  final metrics = [
    for (final metric in metricLeaves)
      _metricProgressView(
        metric: metric,
        signals: signals,
        reference: reference,
        historyDays: historyDays,
        projectedOnTrack:
            evaluation.results[metric.criterionId]?.projectedDaysToTarget !=
            null,
      ),
    for (final measurable in measurableLeaves)
      _measurableProgressView(
        measurable: measurable,
        signals: signals,
        reference: reference,
        historyDays: historyDays,
        definition: measurableDefinitions[measurable.dataTypeId],
        agentRecordedMeasurementIds: agentRecordedMeasurementIds,
        recordedMeasurementProvenanceById: recordedMeasurementProvenanceById,
        projectedOnTrack:
            evaluation.results[measurable.criterionId]?.projectedDaysToTarget !=
            null,
      ),
    for (final categoryTime in categoryTimeLeaves)
      _categoryTimeProgressView(
        categoryTime: categoryTime,
        signals: signals,
        reference: reference,
        historyDays: historyDays,
        categoryName: categoryNames[categoryTime.categoryId],
        projectedOnTrack:
            evaluation
                .results[categoryTime.criterionId]
                ?.projectedDaysToTarget !=
            null,
      ),
    for (final labelTime in labelTimeLeaves)
      _labelTimeProgressView(
        labelTime: labelTime,
        signals: signals,
        reference: reference,
        historyDays: historyDays,
        labelName: labelNames[labelTime.labelId],
        categoryName: labelTime.categoryId == null
            ? null
            : categoryNames[labelTime.categoryId],
      ),
  ];
  return GoalProgressView(
    today: today,
    compactWindowDays: historyDays,
    rootOnTrack: evaluation.satisfied || evaluation.onTrackByTrend,
    habits: [
      for (final habit in habits)
        _withCheckOffSuggestion(
          habit: habit,
          metrics: metrics,
          today: today,
        ),
    ],
    compositeCompactWindow: compositeCompactWindow,
    compositeRule: switch (criteria) {
      GoalCriterionAllOf() => GoalCompositeRuleKind.all,
      GoalCriterionAnyOf() => GoalCompositeRuleKind.any,
      GoalCriterionAtLeastCount() => GoalCompositeRuleKind.atLeast,
      _ => null,
    },
    requiredSuccesses: switch (criteria) {
      GoalCriterionAtLeastCount(:final successes) => successes,
      GoalCriterionAllOf(criteria: final children) => children.length,
      GoalCriterionAnyOf() => 1,
      _ => null,
    },
    metrics: metrics,
  );
}
