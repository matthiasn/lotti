import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';

part 'goal_criterion.freezed.dart';
part 'goal_criterion.g.dart';

/// A recurring local-time slice applied independently to every calendar day.
///
/// Minutes are counted from local midnight. A range whose start is later than
/// its end crosses midnight: `21:30 → 07:00` includes late evening and the
/// following early-morning band. All-day category time uses no range rather
/// than encoding `00:00 → 00:00`, keeping equal endpoints invalid and
/// unambiguous.
@freezed
abstract class GoalDailyTimeRange with _$GoalDailyTimeRange {
  const factory GoalDailyTimeRange({
    required int startMinute,
    required int endMinute,
  }) = _GoalDailyTimeRange;

  factory GoalDailyTimeRange.fromJson(Map<String, dynamic> json) =>
      _$GoalDailyTimeRangeFromJson(json);
}

/// The criteria tree a goal's success is defined in.
///
/// Leaves bind a measurable signal to a windowed target; composites combine
/// children. Every node carries a stable [criterionId] so per-criterion
/// results in `goalProgress` register rows stay addressable across goal
/// revisions that keep a criterion and change its siblings.
///
/// This is deliberately **not** a reuse of `AutoCompleteRule`: that tree
/// models point-in-time, same-day thresholds owned by habit autocompletion,
/// with no windows, aggregation, direction, or per-window quotas (ADR 0053).
@freezed
sealed class GoalCriterion with _$GoalCriterion {
  /// A health/quantitative dimension: "daily step totals, averaged over a
  /// rolling 7 days, at least 10,000". [dataType] is the journal quantitative
  /// data type string (for example `cumulative_step_count`, sleep duration, or
  /// weight). The health data type's configured daily aggregation is applied
  /// first; [aggregation] then combines those daily values across [window].
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

  /// A user-defined measurable-data dimension, same shape as
  /// [GoalCriterion.metric] but keyed by the `MeasurableDataType` id.
  const factory GoalCriterion.measurable({
    required String criterionId,
    required String dataTypeId,
    required GoalWindow window,
    required GoalAggregation aggregation,
    required num target,
    @Default(GoalDirection.atLeast) GoalDirection direction,
    String? title,
  }) = GoalCriterionMeasurable;

  /// A tracked-time dimension attributed to [categoryId], measured in hours.
  ///
  /// [dailyTimeRange] optionally restricts the evidence to a recurring local
  /// time band. This makes both amount goals ("at most 8 hours of coding in a
  /// rolling week") and timing goals ("no coding from 21:30 to 07:00") honest
  /// first-class criteria over the same journal time entries used by Insights.
  /// Model-facing wake facts may also include the underlying sessions for
  /// coaching-pattern analysis, but their deterministic result remains the
  /// authoritative measured outcome.
  ///
  /// [aggregation] remains hour-valued: `sum`, `dailySumThenAverage`, and `max`
  /// are valid. `count` is rejected because it counts active days and cannot be
  /// compared honestly with [targetHours].
  const factory GoalCriterion.categoryTime({
    required String criterionId,
    required String categoryId,
    required GoalWindow window,
    required GoalAggregation aggregation,
    required num targetHours,
    @Default(GoalDirection.atMost) GoalDirection direction,
    GoalDailyTimeRange? dailyTimeRange,
    String? title,
  }) = GoalCriterionCategoryTime;

  /// A tracked-time dimension selected by [labelId], measured in hours.
  ///
  /// Labels are matched by their stable definition id. When [categoryId] is
  /// null, matching entries are counted across every category; otherwise the
  /// same linked-task category precedence as Insights scopes the evidence.
  /// [dailyTimeRange] has the same local-time clipping semantics as
  /// [GoalCriterion.categoryTime].
  const factory GoalCriterion.labelTime({
    required String criterionId,
    required String labelId,
    required GoalWindow window,
    required GoalAggregation aggregation,
    required num targetHours,
    @Default(GoalDirection.atLeast) GoalDirection direction,
    String? categoryId,
    GoalDailyTimeRange? dailyTimeRange,
    String? title,
  }) = GoalCriterionLabelTime;

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
}

/// Every habit id referenced anywhere in [criterion]'s tree — the join used
/// to decide which habits a goal claims (and, by complement, which habits are
/// "not in a goal" on the unified list, and which goals share a habit for the
/// detail page's "also in {goal}" suffix).
Set<String> goalCriterionHabitIds(GoalCriterion criterion) =>
    switch (criterion) {
      GoalCriterionHabit(:final habitId) => {habitId},
      GoalCriterionAllOf(:final criteria) ||
      GoalCriterionAnyOf(:final criteria) ||
      GoalCriterionAtLeastCount(:final criteria) => {
        for (final child in criteria) ...goalCriterionHabitIds(child),
      },
      GoalCriterionMetric() ||
      GoalCriterionMeasurable() ||
      GoalCriterionCategoryTime() ||
      GoalCriterionLabelTime() => const {},
    };

/// Every quantitative data type referenced anywhere in [criterion]'s tree.
///
/// The join used to decide which health imports a goal surface should refresh
/// on entry: a goal reading its own journal entries is current by
/// construction, while one reading health samples is only as fresh as the last
/// import.
Set<String> goalCriterionMetricDataTypes(GoalCriterion criterion) =>
    switch (criterion) {
      GoalCriterionMetric(:final dataType) => {dataType},
      GoalCriterionAllOf(:final criteria) ||
      GoalCriterionAnyOf(:final criteria) ||
      GoalCriterionAtLeastCount(:final criteria) => {
        for (final child in criteria) ...goalCriterionMetricDataTypes(child),
      },
      GoalCriterionHabit() ||
      GoalCriterionMeasurable() ||
      GoalCriterionCategoryTime() ||
      GoalCriterionLabelTime() => const {},
    };
