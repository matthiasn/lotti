import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/goals/model/goal_enums.dart';
import 'package:lotti/features/goals/model/goal_window.dart';

part 'goal_criterion.freezed.dart';
part 'goal_criterion.g.dart';

/// The criteria tree a goal's success is defined in.
///
/// Leaves bind a measurable signal to a windowed target; composites combine
/// children. Every node carries a stable [criterionId] so per-criterion
/// results in `goalProgress` register rows stay addressable across goal
/// revisions that keep a criterion and change its siblings.
///
/// This is deliberately **not** a reuse of [AutoCompleteRule]: that tree
/// models point-in-time, same-day thresholds owned by habit autocompletion,
/// with no windows, aggregation, direction, or per-window quotas (ADR 0053).
/// [GoalCriterion.fromAutoCompleteRule] imports one as a seed instead.
@freezed
sealed class GoalCriterion with _$GoalCriterion {
  /// A health/quantitative target: "daily step sums, averaged over a rolling
  /// 7 days, at least 10,000". [dataType] is the journal quantitative data
  /// type string (e.g. `cumulative_step_count`).
  const factory GoalCriterion.metric({
    required String criterionId,
    required String dataType,
    required GoalWindow window,
    required GoalAggregation aggregation,
    required num target,
    @Default(GoalDirection.atLeast) GoalDirection direction,
    String? title,
  }) = GoalCriterionMetric;

  /// A habit quota: "[habitId] completed successfully at least [targetCount]
  /// times per [window]". Skipped completions do not count toward the quota.
  const factory GoalCriterion.habit({
    required String criterionId,
    required String habitId,
    required GoalWindow window,
    required int targetCount,
    String? title,
  }) = GoalCriterionHabit;

  /// A measurable-data-type target, same shape as [GoalCriterion.metric] but
  /// keyed by the `MeasurableDataType` id.
  const factory GoalCriterion.measurable({
    required String criterionId,
    required String dataTypeId,
    required GoalWindow window,
    required GoalAggregation aggregation,
    required num target,
    @Default(GoalDirection.atLeast) GoalDirection direction,
    String? title,
  }) = GoalCriterionMeasurable;

  /// All children must be satisfied; attainment is their mean.
  const factory GoalCriterion.allOf({
    required String criterionId,
    required List<GoalCriterion> criteria,
    String? title,
  }) = GoalCriterionAllOf;

  /// Any child satisfies; attainment is the best child's.
  const factory GoalCriterion.anyOf({
    required String criterionId,
    required List<GoalCriterion> criteria,
    String? title,
  }) = GoalCriterionAnyOf;

  /// At least [successes] children must be satisfied — the composite-goal
  /// "2 of 3 pillars" shape. Attainment is the mean of the best [successes]
  /// child attainments.
  const factory GoalCriterion.atLeastCount({
    required String criterionId,
    required List<GoalCriterion> criteria,
    required int successes,
    String? title,
  }) = GoalCriterionAtLeastCount;

  const GoalCriterion._();

  factory GoalCriterion.fromJson(Map<String, dynamic> json) =>
      _$GoalCriterionFromJson(json);

  /// Imports an existing habit [AutoCompleteRule] as a goal criteria seed.
  ///
  /// The import is faithful by default: rule thresholds are same-day checks,
  /// so [window] defaults to a single day and [aggregation] to the day's
  /// sum. Callers upgrade to rolling windows explicitly after import.
  ///
  /// Node ids are deterministic paths under [idPrefix] (`c`, `c.0`,
  /// `c.0.min`, …) so repeated imports of the same rule produce identical
  /// trees. A threshold rule with neither `minimum` nor `maximum` throws an
  /// [ArgumentError] — it asserts nothing and cannot seed a target.
  factory GoalCriterion.fromAutoCompleteRule(
    AutoCompleteRule rule, {
    GoalWindow window = const GoalWindow.day(),
    GoalAggregation aggregation = GoalAggregation.sum,
    String idPrefix = 'c',
  }) {
    switch (rule) {
      case AutoCompleteRuleHealth(
        :final dataType,
        :final minimum,
        :final maximum,
        :final title,
      ):
      case AutoCompleteRuleWorkout(
        :final dataType,
        :final minimum,
        :final maximum,
        :final title,
      ):
        return _threshold(
          idPrefix: idPrefix,
          title: title,
          minimum: minimum,
          maximum: maximum,
          build: (id, target, direction) => GoalCriterion.metric(
            criterionId: id,
            dataType: dataType,
            window: window,
            aggregation: aggregation,
            target: target,
            direction: direction,
            title: title,
          ),
        );
      case AutoCompleteRuleMeasurable(
        :final dataTypeId,
        :final minimum,
        :final maximum,
        :final title,
      ):
        return _threshold(
          idPrefix: idPrefix,
          title: title,
          minimum: minimum,
          maximum: maximum,
          build: (id, target, direction) => GoalCriterion.measurable(
            criterionId: id,
            dataTypeId: dataTypeId,
            window: window,
            aggregation: aggregation,
            target: target,
            direction: direction,
            title: title,
          ),
        );
      case AutoCompleteRuleHabit(:final habitId, :final title):
        return GoalCriterion.habit(
          criterionId: idPrefix,
          habitId: habitId,
          window: window,
          targetCount: 1,
          title: title,
        );
      case AutoCompleteRuleAnd(:final rules, :final title):
        return GoalCriterion.allOf(
          criterionId: idPrefix,
          criteria: _children(rules, window, aggregation, idPrefix),
          title: title,
        );
      case AutoCompleteRuleOr(:final rules, :final title):
        return GoalCriterion.anyOf(
          criterionId: idPrefix,
          criteria: _children(rules, window, aggregation, idPrefix),
          title: title,
        );
      case AutoCompleteRuleMultiple(
        :final rules,
        :final successes,
        :final title,
      ):
        return GoalCriterion.atLeastCount(
          criterionId: idPrefix,
          criteria: _children(rules, window, aggregation, idPrefix),
          successes: successes,
          title: title,
        );
    }
  }

  static List<GoalCriterion> _children(
    List<AutoCompleteRule> rules,
    GoalWindow window,
    GoalAggregation aggregation,
    String idPrefix,
  ) => [
    for (var i = 0; i < rules.length; i++)
      GoalCriterion.fromAutoCompleteRule(
        rules[i],
        window: window,
        aggregation: aggregation,
        idPrefix: '$idPrefix.$i',
      ),
  ];

  static GoalCriterion _threshold({
    required String idPrefix,
    required String? title,
    required num? minimum,
    required num? maximum,
    required GoalCriterion Function(
      String criterionId,
      num target,
      GoalDirection direction,
    )
    build,
  }) {
    if (minimum != null && maximum != null) {
      return GoalCriterion.allOf(
        criterionId: idPrefix,
        criteria: [
          build('$idPrefix.min', minimum, GoalDirection.atLeast),
          build('$idPrefix.max', maximum, GoalDirection.atMost),
        ],
        title: title,
      );
    }
    if (minimum != null) {
      return build(idPrefix, minimum, GoalDirection.atLeast);
    }
    if (maximum != null) {
      return build(idPrefix, maximum, GoalDirection.atMost);
    }
    throw ArgumentError(
      'AutoCompleteRule threshold with neither minimum nor maximum '
      'cannot seed a goal criterion.',
    );
  }
}
