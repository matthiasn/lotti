import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';

/// Lossless bridge between the goal criterion tree and WP5's observable
/// mapping controls.
///
/// The flow deliberately edits only the criterion shapes it can explain:
/// rolling-seven-day habit leaves and the existing rolling daily-average steps
/// metric, optionally grouped by one `allOf`. Anything richer remains intact
/// and is presented read-only instead of being silently flattened.
class GoalFormMapping {
  const GoalFormMapping._({
    required this.watchesSteps,
    required this.stepsTarget,
    required this.habitTargets,
    required this.habitCriterionIds,
    required this.stepsCriterionId,
    required this.compositeCriterionId,
    required this.unsupportedCriteria,
  });

  const GoalFormMapping.empty()
    : watchesSteps = false,
      stepsTarget = 10000,
      habitTargets = const {},
      habitCriterionIds = const {},
      stepsCriterionId = 'steps',
      compositeCriterionId = 'routine',
      unsupportedCriteria = null;

  factory GoalFormMapping.fromCriteria(GoalCriterion criteria) {
    final leaves = switch (criteria) {
      GoalCriterionAllOf(:final criteria) => criteria,
      _ => [criteria],
    };
    var watchesSteps = false;
    num stepsTarget = 10000;
    var stepsCriterionId = 'steps';
    final habitTargets = <String, int>{};
    final habitCriterionIds = <String, String>{};

    for (final leaf in leaves) {
      switch (leaf) {
        case GoalCriterionMetric(
              :final criterionId,
              :final dataType,
              :final window,
              :final aggregation,
              :final target,
            )
            when dataType == 'cumulative_step_count' &&
                window == const GoalWindow.rollingDays(count: 7) &&
                aggregation == GoalAggregation.dailySumThenAverage &&
                !watchesSteps:
          watchesSteps = true;
          stepsTarget = target;
          stepsCriterionId = criterionId;
        case GoalCriterionHabit(
              :final criterionId,
              :final habitId,
              :final window,
              :final targetCount,
            )
            when window == const GoalWindow.rollingDays(count: 7) &&
                !habitTargets.containsKey(habitId):
          habitTargets[habitId] = targetCount;
          habitCriterionIds[habitId] = criterionId;
        default:
          return GoalFormMapping._(
            watchesSteps: false,
            stepsTarget: 10000,
            habitTargets: const {},
            habitCriterionIds: const {},
            stepsCriterionId: 'steps',
            compositeCriterionId: 'routine',
            unsupportedCriteria: criteria,
          );
      }
    }

    return GoalFormMapping._(
      watchesSteps: watchesSteps,
      stepsTarget: stepsTarget,
      habitTargets: Map.unmodifiable(habitTargets),
      habitCriterionIds: Map.unmodifiable(habitCriterionIds),
      stepsCriterionId: stepsCriterionId,
      compositeCriterionId: switch (criteria) {
        GoalCriterionAllOf(:final criterionId) => criterionId,
        _ => 'routine',
      },
      unsupportedCriteria: null,
    );
  }

  final bool watchesSteps;
  final num stepsTarget;
  final Map<String, int> habitTargets;
  final Map<String, String> habitCriterionIds;
  final String stepsCriterionId;
  final String compositeCriterionId;
  final GoalCriterion? unsupportedCriteria;

  bool get isEditable => unsupportedCriteria == null;

  /// Builds the exact criterion tree represented by the visible controls.
  /// Returns null when nothing is selected or a visible value is invalid.
  GoalCriterion? buildCriteria({
    required String stepsTitle,
    required Map<String, int> habitTargets,
    bool? watchesSteps,
    num? stepsTarget,
  }) {
    final preserved = unsupportedCriteria;
    if (preserved != null) return preserved;

    final includeSteps = watchesSteps ?? this.watchesSteps;
    final resolvedStepsTarget = stepsTarget ?? this.stepsTarget;
    if (includeSteps && resolvedStepsTarget <= 0) return null;
    if (habitTargets.values.any((count) => count < 1 || count > 7)) {
      return null;
    }

    final leaves = <GoalCriterion>[
      if (includeSteps)
        GoalCriterion.metric(
          criterionId: stepsCriterionId,
          dataType: 'cumulative_step_count',
          title: stepsTitle,
          window: const GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: resolvedStepsTarget,
        ),
      for (final entry in habitTargets.entries)
        GoalCriterion.habit(
          criterionId: habitCriterionIds[entry.key] ?? 'habit-${entry.key}',
          habitId: entry.key,
          window: const GoalWindow.rollingDays(count: 7),
          targetCount: entry.value,
        ),
    ];
    if (leaves.isEmpty) return null;
    if (leaves.length == 1) return leaves.single;
    return GoalCriterion.allOf(
      criterionId: compositeCriterionId,
      criteria: leaves,
    );
  }
}
