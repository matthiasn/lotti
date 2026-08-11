import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';

/// Lossless bridge between the goal criterion tree and WP5's observable
/// mapping controls.
///
/// The flow deliberately edits only the criterion shapes it can explain:
/// rolling-seven-day habit leaves and the existing at-least rolling
/// daily-average steps metric, optionally grouped by one `allOf`. Anything
/// richer remains intact and is presented read-only instead of being silently
/// flattened.
class GoalFormMapping {
  const GoalFormMapping._({
    required this.watchesSteps,
    required this.stepsTarget,
    required this.habitTargets,
    required this.habitCriterionIds,
    required this.stepsCriterionId,
    required this.stepsCriterionTitle,
    required this.compositeCriterionId,
    required this.compositeTitle,
    required this.wasComposite,
    required this.unsupportedCriteria,
  });

  const GoalFormMapping.empty()
    : watchesSteps = false,
      stepsTarget = 10000,
      habitTargets = const {},
      habitCriterionIds = const {},
      stepsCriterionId = 'steps',
      stepsCriterionTitle = null,
      compositeCriterionId = 'routine',
      compositeTitle = null,
      wasComposite = false,
      unsupportedCriteria = null;

  factory GoalFormMapping.fromCriteria(GoalCriterion criteria) {
    final leaves = switch (criteria) {
      GoalCriterionAllOf(:final criteria) => criteria,
      _ => [criteria],
    };
    var watchesSteps = false;
    num stepsTarget = 10000;
    var stepsCriterionId = 'steps';
    String? stepsCriterionTitle;
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
              :final direction,
              :final title,
            )
            when dataType == 'cumulative_step_count' &&
                window == const GoalWindow.rollingDays(count: 7) &&
                aggregation == GoalAggregation.dailySumThenAverage &&
                direction == GoalDirection.atLeast &&
                !watchesSteps:
          watchesSteps = true;
          stepsTarget = target;
          stepsCriterionId = criterionId;
          stepsCriterionTitle = title;
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
            stepsCriterionTitle: null,
            compositeCriterionId: 'routine',
            compositeTitle: null,
            wasComposite: false,
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
      stepsCriterionTitle: stepsCriterionTitle,
      compositeCriterionId: switch (criteria) {
        GoalCriterionAllOf(:final criterionId) => criterionId,
        _ => _availableCompositeCriterionId(leaves),
      },
      compositeTitle: switch (criteria) {
        GoalCriterionAllOf(:final title) => title,
        _ => null,
      },
      wasComposite: criteria is GoalCriterionAllOf,
      unsupportedCriteria: null,
    );
  }

  final bool watchesSteps;
  final num stepsTarget;
  final Map<String, int> habitTargets;
  final Map<String, String> habitCriterionIds;
  final String stepsCriterionId;
  final String? stepsCriterionTitle;
  final String compositeCriterionId;
  final String? compositeTitle;
  final bool wasComposite;
  final GoalCriterion? unsupportedCriteria;

  bool get isEditable => unsupportedCriteria == null;

  static String _availableCompositeCriterionId(List<GoalCriterion> leaves) {
    final usedIds = {for (final leaf in leaves) leaf.criterionId};
    return usedIds.contains('routine') ? 'routine-group' : 'routine';
  }

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

    final usedIds = <String>{
      ...habitCriterionIds.values,
      if (this.watchesSteps) stepsCriterionId,
      if (wasComposite || habitTargets.length + (includeSteps ? 1 : 0) > 1)
        compositeCriterionId,
    };
    String allocateId(String preferred) {
      if (usedIds.add(preferred)) return preferred;
      var suffix = 2;
      while (!usedIds.add('$preferred-$suffix')) {
        suffix++;
      }
      return '$preferred-$suffix';
    }

    final leaves = <GoalCriterion>[
      if (includeSteps)
        GoalCriterion.metric(
          criterionId: this.watchesSteps
              ? stepsCriterionId
              : allocateId('steps'),
          dataType: 'cumulative_step_count',
          title: this.watchesSteps ? stepsCriterionTitle : stepsTitle,
          window: const GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: resolvedStepsTarget,
        ),
      for (final entry in habitTargets.entries)
        GoalCriterion.habit(
          criterionId:
              habitCriterionIds[entry.key] ?? allocateId('habit-${entry.key}'),
          habitId: entry.key,
          window: const GoalWindow.rollingDays(count: 7),
          targetCount: entry.value,
        ),
    ];
    if (leaves.isEmpty) return null;
    if (leaves.length == 1 && !wasComposite) return leaves.single;
    return GoalCriterion.allOf(
      criterionId: compositeCriterionId,
      criteria: leaves,
      title: compositeTitle,
    );
  }
}
