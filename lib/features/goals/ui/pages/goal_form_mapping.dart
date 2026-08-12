import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';

export 'package:lotti/features/goals/model/goal_health_data_types.dart'
    show GoalHealthDataTypes;

enum GoalFormCompositeRule { all, any, atLeast }

typedef _LeafOrderEntry = ({
  String? habitId,
  String? healthDataType,
  String? measurableId,
  bool isSteps,
});

/// Lossless bridge between the goal criterion tree and WP5's observable
/// mapping controls.
///
/// The flow deliberately edits only the criterion shapes it can explain:
/// rolling-seven-day habit, measurable, supported health, and steps leaves,
/// optionally grouped by one supported composite. Anything richer remains
/// intact and is presented read-only instead of being silently flattened.
class GoalFormMapping {
  const GoalFormMapping._({
    required this.watchesSteps,
    required this.stepsTarget,
    required this.habitTargets,
    required this.habitCriterionIds,
    required this.habitCriterionTitles,
    required this.measurableTargets,
    required this.measurableCriterionIds,
    required this.measurableCriterionTitles,
    required this.healthTargets,
    required this.healthDirections,
    required this.healthCriterionIds,
    required this.healthCriterionTitles,
    required this.stepsCriterionId,
    required this.stepsCriterionTitle,
    required this.compositeCriterionId,
    required this.compositeTitle,
    required this.wasComposite,
    required this.compositeRule,
    required this.requiredSuccesses,
    required this._leafOrder,
    required this.unsupportedCriteria,
  });

  const GoalFormMapping.empty()
    : watchesSteps = false,
      stepsTarget = 10000,
      habitTargets = const {},
      habitCriterionIds = const {},
      habitCriterionTitles = const {},
      measurableTargets = const {},
      measurableCriterionIds = const {},
      measurableCriterionTitles = const {},
      healthTargets = const {},
      healthDirections = const {},
      healthCriterionIds = const {},
      healthCriterionTitles = const {},
      stepsCriterionId = 'steps',
      stepsCriterionTitle = null,
      compositeCriterionId = 'routine',
      compositeTitle = null,
      wasComposite = false,
      compositeRule = GoalFormCompositeRule.all,
      requiredSuccesses = 1,
      _leafOrder = const [],
      unsupportedCriteria = null;

  factory GoalFormMapping.fromCriteria(GoalCriterion criteria) {
    final leaves = switch (criteria) {
      GoalCriterionAllOf(:final criteria) ||
      GoalCriterionAnyOf(:final criteria) ||
      GoalCriterionAtLeastCount(:final criteria) => criteria,
      _ => [criteria],
    };
    var watchesSteps = false;
    num stepsTarget = 10000;
    var stepsCriterionId = 'steps';
    String? stepsCriterionTitle;
    final habitTargets = <String, int>{};
    final habitCriterionIds = <String, String>{};
    final habitCriterionTitles = <String, String?>{};
    final measurableTargets = <String, num>{};
    final measurableCriterionIds = <String, String>{};
    final measurableCriterionTitles = <String, String?>{};
    final healthTargets = <String, num>{};
    final healthDirections = <String, GoalDirection>{};
    final healthCriterionIds = <String, String>{};
    final healthCriterionTitles = <String, String?>{};
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
          leafOrder.add((
            habitId: null,
            healthDataType: null,
            measurableId: null,
            isSteps: true,
          ));
        case GoalCriterionMetric(
              :final criterionId,
              :final dataType,
              :final window,
              :final aggregation,
              :final target,
              :final direction,
              :final title,
            )
            when GoalHealthDataTypes.supported.contains(dataType) &&
                window == const GoalWindow.rollingDays(count: 7) &&
                aggregation == GoalAggregation.dailySumThenAverage &&
                target > 0 &&
                !healthTargets.containsKey(dataType):
          healthTargets[dataType] = target;
          healthDirections[dataType] = direction;
          healthCriterionIds[dataType] = criterionId;
          healthCriterionTitles[dataType] = title;
          leafOrder.add((
            habitId: null,
            healthDataType: dataType,
            measurableId: null,
            isSteps: false,
          ));
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
          leafOrder.add((
            habitId: habitId,
            healthDataType: null,
            measurableId: null,
            isSteps: false,
          ));
        case GoalCriterionMeasurable(
              :final criterionId,
              :final dataTypeId,
              :final window,
              :final aggregation,
              :final target,
              :final direction,
              :final title,
            )
            when window == const GoalWindow.rollingDays(count: 7) &&
                aggregation == GoalAggregation.sum &&
                direction == GoalDirection.atLeast &&
                target > 0 &&
                !measurableTargets.containsKey(dataTypeId):
          measurableTargets[dataTypeId] = target;
          measurableCriterionIds[dataTypeId] = criterionId;
          measurableCriterionTitles[dataTypeId] = title;
          leafOrder.add((
            habitId: null,
            healthDataType: null,
            measurableId: dataTypeId,
            isSteps: false,
          ));
        default:
          return GoalFormMapping._(
            watchesSteps: false,
            stepsTarget: 10000,
            habitTargets: const {},
            habitCriterionIds: const {},
            habitCriterionTitles: const {},
            measurableTargets: const {},
            measurableCriterionIds: const {},
            measurableCriterionTitles: const {},
            healthTargets: const {},
            healthDirections: const {},
            healthCriterionIds: const {},
            healthCriterionTitles: const {},
            stepsCriterionId: 'steps',
            stepsCriterionTitle: null,
            compositeCriterionId: 'routine',
            compositeTitle: null,
            wasComposite: false,
            compositeRule: GoalFormCompositeRule.all,
            requiredSuccesses: 1,
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
      measurableTargets: Map.unmodifiable(measurableTargets),
      measurableCriterionIds: Map.unmodifiable(measurableCriterionIds),
      measurableCriterionTitles: Map.unmodifiable(measurableCriterionTitles),
      healthTargets: Map.unmodifiable(healthTargets),
      healthDirections: Map.unmodifiable(healthDirections),
      healthCriterionIds: Map.unmodifiable(healthCriterionIds),
      healthCriterionTitles: Map.unmodifiable(healthCriterionTitles),
      stepsCriterionId: stepsCriterionId,
      stepsCriterionTitle: stepsCriterionTitle,
      compositeCriterionId: switch (criteria) {
        GoalCriterionAllOf(:final criterionId) ||
        GoalCriterionAnyOf(:final criterionId) ||
        GoalCriterionAtLeastCount(:final criterionId) => criterionId,
        _ => _availableCompositeCriterionId(leaves),
      },
      compositeTitle: switch (criteria) {
        GoalCriterionAllOf(:final title) ||
        GoalCriterionAnyOf(:final title) ||
        GoalCriterionAtLeastCount(:final title) => title,
        _ => null,
      },
      wasComposite:
          criteria is GoalCriterionAllOf ||
          criteria is GoalCriterionAnyOf ||
          criteria is GoalCriterionAtLeastCount,
      compositeRule: switch (criteria) {
        GoalCriterionAnyOf() => GoalFormCompositeRule.any,
        GoalCriterionAtLeastCount() => GoalFormCompositeRule.atLeast,
        _ => GoalFormCompositeRule.all,
      },
      requiredSuccesses: switch (criteria) {
        GoalCriterionAtLeastCount(:final successes) => successes,
        _ => 1,
      },
      leafOrder: List.unmodifiable(leafOrder),
      unsupportedCriteria: null,
    );
  }

  final bool watchesSteps;
  final num stepsTarget;
  final Map<String, int> habitTargets;
  final Map<String, String> habitCriterionIds;
  final Map<String, String?> habitCriterionTitles;
  final Map<String, num> measurableTargets;
  final Map<String, String> measurableCriterionIds;
  final Map<String, String?> measurableCriterionTitles;
  final Map<String, num> healthTargets;
  final Map<String, GoalDirection> healthDirections;
  final Map<String, String> healthCriterionIds;
  final Map<String, String?> healthCriterionTitles;
  final String stepsCriterionId;
  final String? stepsCriterionTitle;
  final String compositeCriterionId;
  final String? compositeTitle;
  final bool wasComposite;
  final GoalFormCompositeRule compositeRule;
  final int requiredSuccesses;
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
    Map<String, num> measurableTargets = const {},
    Map<String, String> measurableTitles = const {},
    Map<String, num> healthTargets = const {},
    Map<String, GoalDirection> healthDirections = const {},
    Map<String, String> healthTitles = const {},
    bool? watchesSteps,
    num? stepsTarget,
    GoalFormCompositeRule? compositeRule,
    int? requiredSuccesses,
  }) {
    final preserved = unsupportedCriteria;
    if (preserved != null) return preserved;

    final includeSteps = watchesSteps ?? this.watchesSteps;
    final resolvedStepsTarget = stepsTarget ?? this.stepsTarget;
    if (includeSteps && resolvedStepsTarget <= 0) return null;
    if (habitTargets.values.any((count) => count < 1 || count > 7)) {
      return null;
    }
    if (measurableTargets.values.any((target) => target <= 0)) return null;
    if (healthTargets.entries.any(
      (entry) =>
          !GoalHealthDataTypes.supported.contains(entry.key) ||
          entry.value <= 0,
    )) {
      return null;
    }

    final usedIds = <String>{
      ...habitCriterionIds.values,
      ...measurableCriterionIds.values,
      ...healthCriterionIds.values,
      if (this.watchesSteps) stepsCriterionId,
      if (wasComposite ||
          habitTargets.length +
                  measurableTargets.length +
                  healthTargets.length +
                  (includeSteps ? 1 : 0) >
              1)
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
    final measurableLeaves = {
      for (final entry in measurableTargets.entries)
        entry.key: GoalCriterion.measurable(
          criterionId:
              measurableCriterionIds[entry.key] ??
              allocateId('measurable-${entry.key}'),
          dataTypeId: entry.key,
          title:
              measurableCriterionTitles[entry.key] ??
              measurableTitles[entry.key],
          window: const GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.sum,
          target: entry.value,
        ),
    };
    final healthLeaves = {
      for (final entry in healthTargets.entries)
        entry.key: GoalCriterion.metric(
          criterionId:
              healthCriterionIds[entry.key] ??
              allocateId(GoalHealthDataTypes.criterionId(entry.key)),
          dataType: entry.key,
          title: healthCriterionTitles[entry.key] ?? healthTitles[entry.key],
          window: const GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: entry.value,
          direction:
              healthDirections[entry.key] ??
              this.healthDirections[entry.key] ??
              GoalDirection.atMost,
        ),
    };
    final orderedHabitIds = <String>{};
    final orderedMeasurableIds = <String>{};
    final orderedHealthDataTypes = <String>{};
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
      } else if (entry.healthDataType case final healthDataType?) {
        final health = healthLeaves[healthDataType];
        if (health != null && orderedHealthDataTypes.add(healthDataType)) {
          leaves.add(health);
        }
      } else if (entry.measurableId case final measurableId?) {
        final measurable = measurableLeaves[measurableId];
        if (measurable != null && orderedMeasurableIds.add(measurableId)) {
          leaves.add(measurable);
        }
      }
    }
    if (stepsLeaf != null && !stepsAdded) leaves.add(stepsLeaf);
    for (final entry in habitLeaves.entries) {
      if (!orderedHabitIds.contains(entry.key)) leaves.add(entry.value);
    }
    for (final entry in measurableLeaves.entries) {
      if (!orderedMeasurableIds.contains(entry.key)) leaves.add(entry.value);
    }
    for (final entry in healthLeaves.entries) {
      if (!orderedHealthDataTypes.contains(entry.key)) leaves.add(entry.value);
    }
    if (leaves.isEmpty) return null;
    if (leaves.length == 1 && !wasComposite) return leaves.single;
    final rule = compositeRule ?? this.compositeRule;
    return switch (rule) {
      GoalFormCompositeRule.all => GoalCriterion.allOf(
        criterionId: compositeCriterionId,
        criteria: leaves,
        title: compositeTitle,
      ),
      GoalFormCompositeRule.any => GoalCriterion.anyOf(
        criterionId: compositeCriterionId,
        criteria: leaves,
        title: compositeTitle,
      ),
      GoalFormCompositeRule.atLeast => GoalCriterion.atLeastCount(
        criterionId: compositeCriterionId,
        criteria: leaves,
        successes: (requiredSuccesses ?? this.requiredSuccesses).clamp(
          1,
          leaves.length,
        ),
        title: compositeTitle,
      ),
    };
  }
}
