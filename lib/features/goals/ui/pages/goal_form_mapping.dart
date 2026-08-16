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
  String? categoryId,
  String? labelId,
  bool isSteps,
});

/// Lossless bridge between the goal criterion tree and WP5's observable
/// mapping controls.
///
/// The flow deliberately edits only the criterion shapes it can explain:
/// rolling-seven-day habit, measurable, supported health, category-time, and
/// steps leaves, optionally grouped by one supported composite. Anything
/// richer remains intact and is presented read-only instead of being silently
/// flattened.
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
    required this.categoryTimeTargets,
    required this.categoryTimeDirections,
    required this.categoryTimeCriterionIds,
    required this.categoryTimeCriterionTitles,
    required this.labelTimeTargets,
    required this.labelTimeDirections,
    required this.labelTimeCategoryIds,
    required this.labelTimeCriterionIds,
    required this.labelTimeCriterionTitles,
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
      categoryTimeTargets = const {},
      categoryTimeDirections = const {},
      categoryTimeCriterionIds = const {},
      categoryTimeCriterionTitles = const {},
      labelTimeTargets = const {},
      labelTimeDirections = const {},
      labelTimeCategoryIds = const {},
      labelTimeCriterionIds = const {},
      labelTimeCriterionTitles = const {},
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
    final categoryTimeTargets = <String, num>{};
    final categoryTimeDirections = <String, GoalDirection>{};
    final categoryTimeCriterionIds = <String, String>{};
    final categoryTimeCriterionTitles = <String, String?>{};
    final labelTimeTargets = <String, num>{};
    final labelTimeDirections = <String, GoalDirection>{};
    final labelTimeCategoryIds = <String, String?>{};
    final labelTimeCriterionIds = <String, String>{};
    final labelTimeCriterionTitles = <String, String?>{};
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
            categoryId: null,
            labelId: null,
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
            categoryId: null,
            labelId: null,
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
            categoryId: null,
            labelId: null,
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
            categoryId: null,
            labelId: null,
            isSteps: false,
          ));
        case GoalCriterionCategoryTime(
              :final criterionId,
              :final categoryId,
              :final window,
              :final aggregation,
              :final targetHours,
              :final direction,
              :final dailyTimeRange,
              :final title,
            )
            when window == const GoalWindow.rollingDays(count: 7) &&
                aggregation == GoalAggregation.sum &&
                dailyTimeRange == null &&
                targetHours > 0 &&
                !categoryTimeTargets.containsKey(categoryId):
          categoryTimeTargets[categoryId] = targetHours;
          categoryTimeDirections[categoryId] = direction;
          categoryTimeCriterionIds[categoryId] = criterionId;
          categoryTimeCriterionTitles[categoryId] = title;
          leafOrder.add((
            habitId: null,
            healthDataType: null,
            measurableId: null,
            categoryId: categoryId,
            labelId: null,
            isSteps: false,
          ));
        case GoalCriterionLabelTime(
              :final criterionId,
              :final labelId,
              :final categoryId,
              :final window,
              :final aggregation,
              :final targetHours,
              :final direction,
              :final dailyTimeRange,
              :final title,
            )
            when window == const GoalWindow.day() &&
                aggregation == GoalAggregation.sum &&
                dailyTimeRange == null &&
                targetHours > 0 &&
                !labelTimeTargets.containsKey(labelId):
          labelTimeTargets[labelId] = targetHours;
          labelTimeDirections[labelId] = direction;
          labelTimeCategoryIds[labelId] = categoryId;
          labelTimeCriterionIds[labelId] = criterionId;
          labelTimeCriterionTitles[labelId] = title;
          leafOrder.add((
            habitId: null,
            healthDataType: null,
            measurableId: null,
            categoryId: null,
            labelId: labelId,
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
            categoryTimeTargets: const {},
            categoryTimeDirections: const {},
            categoryTimeCriterionIds: const {},
            categoryTimeCriterionTitles: const {},
            labelTimeTargets: const {},
            labelTimeDirections: const {},
            labelTimeCategoryIds: const {},
            labelTimeCriterionIds: const {},
            labelTimeCriterionTitles: const {},
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
      categoryTimeTargets: Map.unmodifiable(categoryTimeTargets),
      categoryTimeDirections: Map.unmodifiable(categoryTimeDirections),
      categoryTimeCriterionIds: Map.unmodifiable(categoryTimeCriterionIds),
      categoryTimeCriterionTitles: Map.unmodifiable(
        categoryTimeCriterionTitles,
      ),
      labelTimeTargets: Map.unmodifiable(labelTimeTargets),
      labelTimeDirections: Map.unmodifiable(labelTimeDirections),
      labelTimeCategoryIds: Map.unmodifiable(labelTimeCategoryIds),
      labelTimeCriterionIds: Map.unmodifiable(labelTimeCriterionIds),
      labelTimeCriterionTitles: Map.unmodifiable(labelTimeCriterionTitles),
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
  final Map<String, num> categoryTimeTargets;
  final Map<String, GoalDirection> categoryTimeDirections;
  final Map<String, String> categoryTimeCriterionIds;
  final Map<String, String?> categoryTimeCriterionTitles;
  final Map<String, num> labelTimeTargets;
  final Map<String, GoalDirection> labelTimeDirections;
  final Map<String, String?> labelTimeCategoryIds;
  final Map<String, String> labelTimeCriterionIds;
  final Map<String, String?> labelTimeCriterionTitles;
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
    Map<String, num> categoryTimeTargets = const {},
    Map<String, GoalDirection> categoryTimeDirections = const {},
    Map<String, String> categoryTimeTitles = const {},
    Map<String, num> labelTimeTargets = const {},
    Map<String, GoalDirection> labelTimeDirections = const {},
    Map<String, String> labelTimeTitles = const {},
    Map<String, String?> labelTimeCategoryIds = const {},
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
    if (categoryTimeTargets.values.any((target) => target <= 0)) return null;
    if (labelTimeTargets.values.any((target) => target <= 0)) return null;
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
      ...categoryTimeCriterionIds.values,
      ...labelTimeCriterionIds.values,
      if (this.watchesSteps) stepsCriterionId,
      if (wasComposite ||
          habitTargets.length +
                  measurableTargets.length +
                  healthTargets.length +
                  categoryTimeTargets.length +
                  labelTimeTargets.length +
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
          title: measurableCriterionIds.containsKey(entry.key)
              ? measurableCriterionTitles[entry.key]
              : measurableTitles[entry.key],
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
          title: healthCriterionIds.containsKey(entry.key)
              ? healthCriterionTitles[entry.key]
              : healthTitles[entry.key],
          window: const GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: entry.value,
          direction:
              healthDirections[entry.key] ??
              this.healthDirections[entry.key] ??
              GoalDirection.atMost,
        ),
    };
    final categoryTimeLeaves = {
      for (final entry in categoryTimeTargets.entries)
        entry.key: GoalCriterion.categoryTime(
          criterionId:
              categoryTimeCriterionIds[entry.key] ??
              allocateId('category-time-${entry.key}'),
          categoryId: entry.key,
          title: categoryTimeCriterionIds.containsKey(entry.key)
              ? categoryTimeCriterionTitles[entry.key]
              : categoryTimeTitles[entry.key],
          window: const GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.sum,
          targetHours: entry.value,
          direction:
              categoryTimeDirections[entry.key] ??
              this.categoryTimeDirections[entry.key] ??
              GoalDirection.atMost,
        ),
    };
    final labelTimeLeaves = {
      for (final entry in labelTimeTargets.entries)
        entry.key: GoalCriterion.labelTime(
          criterionId:
              labelTimeCriterionIds[entry.key] ??
              allocateId('label-time-${entry.key}'),
          labelId: entry.key,
          categoryId: labelTimeCategoryIds.containsKey(entry.key)
              ? labelTimeCategoryIds[entry.key]
              : this.labelTimeCategoryIds[entry.key],
          title: labelTimeCriterionIds.containsKey(entry.key)
              ? labelTimeCriterionTitles[entry.key]
              : labelTimeTitles[entry.key],
          window: const GoalWindow.day(),
          aggregation: GoalAggregation.sum,
          targetHours: entry.value,
          direction:
              labelTimeDirections[entry.key] ??
              this.labelTimeDirections[entry.key] ??
              GoalDirection.atLeast,
        ),
    };
    final orderedHabitIds = <String>{};
    final orderedMeasurableIds = <String>{};
    final orderedHealthDataTypes = <String>{};
    final orderedCategoryIds = <String>{};
    final orderedLabelIds = <String>{};
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
      } else if (entry.categoryId case final categoryId?) {
        final categoryTime = categoryTimeLeaves[categoryId];
        if (categoryTime != null && orderedCategoryIds.add(categoryId)) {
          leaves.add(categoryTime);
        }
      } else if (entry.labelId case final labelId?) {
        final labelTime = labelTimeLeaves[labelId];
        if (labelTime != null && orderedLabelIds.add(labelId)) {
          leaves.add(labelTime);
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
    for (final entry in categoryTimeLeaves.entries) {
      if (!orderedCategoryIds.contains(entry.key)) leaves.add(entry.value);
    }
    for (final entry in labelTimeLeaves.entries) {
      if (!orderedLabelIds.contains(entry.key)) leaves.add(entry.value);
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
