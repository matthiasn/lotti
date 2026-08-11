import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';

typedef _LeafOrderEntry = ({String? habitId, bool isSteps});

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
    required this.habitCriterionTitles,
    required this.stepsCriterionId,
    required this.stepsCriterionTitle,
    required this.compositeCriterionId,
    required this.compositeTitle,
    required this.wasComposite,
    required this._leafOrder,
    required this.unsupportedCriteria,
  });

  const GoalFormMapping.empty()
    : watchesSteps = false,
      stepsTarget = 10000,
      habitTargets = const {},
      habitCriterionIds = const {},
      habitCriterionTitles = const {},
      stepsCriterionId = 'steps',
      stepsCriterionTitle = null,
      compositeCriterionId = 'routine',
      compositeTitle = null,
      wasComposite = false,
      _leafOrder = const [],
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
    final habitCriterionTitles = <String, String?>{};
    final leafOrder = <_LeafOrderEntry>[];

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
                target > 0 &&
                !watchesSteps:
          watchesSteps = true;
          stepsTarget = target;
          stepsCriterionId = criterionId;
          stepsCriterionTitle = title;
          leafOrder.add((habitId: null, isSteps: true));
        case GoalCriterionHabit(
              :final criterionId,
              :final habitId,
              :final window,
              :final targetCount,
              :final title,
            )
            when window == const GoalWindow.rollingDays(count: 7) &&
                targetCount >= 1 &&
                targetCount <= 7 &&
                !habitTargets.containsKey(habitId):
          habitTargets[habitId] = targetCount;
          habitCriterionIds[habitId] = criterionId;
          habitCriterionTitles[habitId] = title;
          leafOrder.add((habitId: habitId, isSteps: false));
        default:
          return GoalFormMapping._(
            watchesSteps: false,
            stepsTarget: 10000,
            habitTargets: const {},
            habitCriterionIds: const {},
            habitCriterionTitles: const {},
            stepsCriterionId: 'steps',
            stepsCriterionTitle: null,
            compositeCriterionId: 'routine',
            compositeTitle: null,
            wasComposite: false,
            leafOrder: const [],
            unsupportedCriteria: criteria,
          );
      }
    }

    return GoalFormMapping._(
      watchesSteps: watchesSteps,
      stepsTarget: stepsTarget,
      habitTargets: Map.unmodifiable(habitTargets),
      habitCriterionIds: Map.unmodifiable(habitCriterionIds),
      habitCriterionTitles: Map.unmodifiable(habitCriterionTitles),
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
      leafOrder: List.unmodifiable(leafOrder),
      unsupportedCriteria: null,
    );
  }

  final bool watchesSteps;
  final num stepsTarget;
  final Map<String, int> habitTargets;
  final Map<String, String> habitCriterionIds;
  final Map<String, String?> habitCriterionTitles;
  final String stepsCriterionId;
  final String? stepsCriterionTitle;
  final String compositeCriterionId;
  final String? compositeTitle;
  final bool wasComposite;
  final List<_LeafOrderEntry> _leafOrder;
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

    final stepsLeaf = includeSteps
        ? GoalCriterion.metric(
            criterionId: this.watchesSteps
                ? stepsCriterionId
                : allocateId('steps'),
            dataType: 'cumulative_step_count',
            title: this.watchesSteps ? stepsCriterionTitle : stepsTitle,
            window: const GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.dailySumThenAverage,
            target: resolvedStepsTarget,
          )
        : null;
    final habitLeaves = {
      for (final entry in habitTargets.entries)
        entry.key: GoalCriterion.habit(
          criterionId:
              habitCriterionIds[entry.key] ?? allocateId('habit-${entry.key}'),
          habitId: entry.key,
          title: habitCriterionTitles[entry.key],
          window: const GoalWindow.rollingDays(count: 7),
          targetCount: entry.value,
        ),
    };
    final orderedHabitIds = <String>{};
    var stepsAdded = false;
    final leaves = <GoalCriterion>[];
    for (final entry in _leafOrder) {
      if (entry.isSteps && stepsLeaf != null && !stepsAdded) {
        leaves.add(stepsLeaf);
        stepsAdded = true;
      } else if (entry.habitId case final habitId?) {
        final habit = habitLeaves[habitId];
        if (habit != null && orderedHabitIds.add(habitId)) {
          leaves.add(habit);
        }
      }
    }
    if (stepsLeaf != null && !stepsAdded) leaves.add(stepsLeaf);
    for (final entry in habitLeaves.entries) {
      if (!orderedHabitIds.contains(entry.key)) leaves.add(entry.value);
    }
    if (leaves.isEmpty) return null;
    if (leaves.length == 1 && !wasComposite) return leaves.single;
    return GoalCriterion.allOf(
      criterionId: compositeCriterionId,
      criteria: leaves,
      title: compositeTitle,
    );
  }
}
