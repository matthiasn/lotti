import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/evaluation/goal_progress_evaluator.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_measurable_capture_state.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/widgets/day_indicators/day_mark.dart';

enum GoalDimensionKind { habit, health, measurable, categoryTime, labelTime }

enum GoalCompositeRuleKind { all, any, atLeast }

class GoalRecordedMeasurementProvenance {
  const GoalRecordedMeasurementProvenance({
    required this.agentName,
    required this.recordedAt,
  });

  final String agentName;
  final DateTime recordedAt;
}

/// One habit row in the period visual used by the Agents list and goal detail.
///
/// [days] is exactly the criterion's active period. Rolling windows also keep
/// the immediately preceding [slippedDay] so callers can explain what just
/// left the window without corrupting the active-period progress math.
class GoalHabitProgressView {
  const GoalHabitProgressView({
    required this.habitId,
    required this.name,
    required this.targetCount,
    required this.days,
    required this.successfulWeeks,
    this.criterionId = '',
    this.sourceCaption,
    this.window = const GoalWindow.rollingDays(count: 7),
    this.slippedDay,
    this.suggestedFromDimensionName,
    this.evaluatedSuccesses,
  });

  final String habitId;
  final String criterionId;
  final String name;
  final String? sourceCaption;
  final int targetCount;
  final List<GoalProgressDay> days;

  /// Set when a sibling data dimension of the same goal recorded an
  /// observation today, this habit's name shares a distinctive word with that
  /// dimension, and today has no recorded outcome yet — evidence exists, so
  /// the card offers a one-tap check-off instead of leaving the day blank.
  final String? suggestedFromDimensionName;

  /// Successful trailing seven-day periods, available only when the authored
  /// criterion itself is a rolling seven-day habit.
  final int? successfulWeeks;
  final GoalWindow window;
  final GoalProgressDay? slippedDay;

  /// The EVALUATOR's creditable-success count for this criterion — the same
  /// number the agent is handed in FACTS. The view-side fold below mirrors
  /// the evaluator's rule only coincidentally; where the evaluator's figure
  /// is available it wins, so the card and the report cannot drift apart the
  /// way the metric headline once did.
  final int? evaluatedSuccesses;

  /// The evaluator's creditable-success count where available; the local
  /// fold otherwise. The fold is WINDOW-aware: [days] may render extra
  /// history for the page's shared span, and counting the whole list read
  /// "4 of 2 this window" the moment a track showed more than the window.
  int get successesInWindow {
    if (evaluatedSuccesses case final evaluated?) return evaluated;
    if (days.isEmpty) return 0;
    final range = window.periodRange(days.last.day);
    final inWindow = days.where(
      (day) => !day.day.isBefore(range.start) && !day.day.isAfter(range.end),
    );
    return switch (window) {
      GoalWindowRollingDays() => inWindow.where((day) => day.value > 0).length,
      _ => inWindow.fold(0, (total, day) => total + day.value.toInt()),
    };
  }

  int get deficit => (targetCount - successesInWindow).clamp(0, targetCount);

  /// Whether tonight's midnight slide drops the OLDEST in-window success.
  /// Window-aware: [days] may render extra history ahead of the window, so
  /// the check anchors at the window's own first day, not the list head.
  bool get oldestSuccessAgesOutTonight {
    final window = this.window;
    if (window is! GoalWindowRollingDays) return false;
    if (successesInWindow != targetCount) return false;
    if (days.isEmpty) return false;
    if (days.length < window.count) return days.first.value > 0;
    return days[days.length - window.count].value > 0;
  }
}

/// Metric contributions for the criterion's actual evaluation period.
/// [GoalProgressDay.targetSatisfied] carries the evaluator's aggregate verdict
/// for the period anchored at that day; bars must not compare a raw daily
/// contribution with a multi-day target.
class GoalMetricProgressView {
  const GoalMetricProgressView({
    required this.name,
    required this.target,
    required this.days,
    this.aggregation = GoalAggregation.dailySumThenAverage,
    this.window = const GoalWindow.rollingDays(count: 7),
    this.direction = GoalDirection.atLeast,
    this.criterionId = '',
    this.sourceId = '',
    this.kind = GoalDimensionKind.health,
    this.unitName,
    this.dailyTimeRange,
    this.agentRecordedDays = const {},
    this.agentRecordedProvenanceByDay = const {},
    this.categoryTimeSessions = const [],
    this.projectedOnTrack = false,
    this.evaluatedActual,
    this.warmupValues = const {},
  });

  final String name;
  final String criterionId;
  final String sourceId;
  final GoalDimensionKind kind;
  final String? unitName;
  final GoalDailyTimeRange? dailyTimeRange;
  final Set<DateTime> agentRecordedDays;
  final Map<DateTime, GoalRecordedMeasurementProvenance>
  agentRecordedProvenanceByDay;
  final List<GoalCategoryTimeSession> categoryTimeSessions;
  final bool projectedOnTrack;
  final num target;
  final List<GoalProgressDay> days;
  final GoalAggregation aggregation;

  /// The aggregate the EVALUATOR computed for this criterion — the same
  /// number the agent is handed in FACTS and quotes in its report.
  ///
  /// The card used to recompute its own from the visible days, which is a
  /// different calculation over a different set (observed days only, versus
  /// the evaluator's series), so the headline figure on the card and the one
  /// in the report beside it could disagree about the same week.
  final num? evaluatedActual;
  final GoalWindow window;
  final GoalDirection direction;

  /// Observed values for the days immediately BEFORE [days] — the run-up a
  /// trailing average needs to have a full window on the first visible day.
  ///
  /// [days] is the visible span, so a rolling mean computed from it alone
  /// cannot produce a point until six days into the chart: the line began
  /// a week late and the earliest part of the range looked like it had no
  /// trend rather than one nobody had drawn. The signal reader already
  /// fetches `historyDays + 7`, so this run-up costs no extra query — it was
  /// simply being thrown away between the reader and the series.
  ///
  /// Keyed by UTC day, observed days only; absent days are gaps, not zeroes.
  final Map<DateTime, num> warmupValues;

  /// Whether the goal's requirement held AS OF [day] — the evaluator's own
  /// verdict where it has one, which for a rolling criterion is a statement
  /// about the window ending that day, not about the day's own value.
  bool meetsTarget(GoalProgressDay day) =>
      day.isObserved &&
      (day.targetSatisfied ?? _meetsTarget(day.value, target, direction));

  /// Whether [day]'s OWN value clears the target.
  ///
  /// Distinct from [meetsTarget] on purpose. Anywhere a single day's number
  /// is shown beside a met/missed mark, the mark has to be about that number:
  /// the reflection sheet printed "122" against a 125 ceiling and crossed it
  /// out, because the rolling average behind it was still over — contradicting
  /// the report one card above, which read "today's 122 helps".
  bool valueMeetsTarget(GoalProgressDay day) =>
      day.isObserved && _meetsTarget(day.value, target, direction);

  /// Whether [target] describes one day's quantity — `dailySumThenAverage`
  /// and the point-sample aggregations — rather than a total the whole
  /// period accumulates (`sum`, `count`).
  bool get targetIsPerDay => switch (aggregation) {
    GoalAggregation.sum || GoalAggregation.count => false,
    _ => true,
  };

  /// THE per-day met/missed policy, shared by every surface that marks a
  /// single day (bars, strip cells, the reflection sheet, the composite
  /// tally).
  ///
  /// Where the target is a per-day quantity, the day is met when EITHER its
  /// own value clears the target OR the goal's requirement held as of that
  /// day — the rolling average at or above target. Each day thus has a
  /// winnable condition even while the average is still recovering (a
  /// 12,400-step day inside a weak week is a met day), and a short day inside
  /// a week that is comfortably on target is not painted as a failure. The
  /// GOAL's status stays average-driven: day-state and goal-state are
  /// deliberately different layers. Where the target belongs to the whole
  /// period, only the evaluator's window verdict can judge a day, because a
  /// single day's contribution cannot be read against a period total.
  ///
  /// One policy, or the surfaces contradict each other — a 12,400-step day
  /// inside a weak week rendered muted while the reflection sheet it opens
  /// suggested "met" for the same day.
  bool dayMark(GoalProgressDay day) => targetIsPerDay
      ? valueMeetsTarget(day) || meetsTarget(day)
      : meetsTarget(day);
}

class GoalProgressDay {
  const GoalProgressDay({
    required this.day,
    required this.value,
    this.habitCompletionType,
    this.isObserved = true,
    this.targetSatisfied,
  });

  final DateTime day;
  final num value;
  final HabitCompletionType? habitCompletionType;
  final bool isObserved;
  final bool? targetSatisfied;

  bool get hasValue => value > 0;
}

class GoalProgressView {
  GoalProgressView({
    required this.today,
    this.habits = const [],
    GoalMetricProgressView? metric,
    List<GoalMetricProgressView> metrics = const [],
    this.compositeCompactWindow,
    this.compositeRule,
    this.requiredSuccesses,
    this.rootOnTrack = false,
    int? compactWindowDays,
  }) : metrics = metric == null ? metrics : [metric, ...metrics],
       compactWindowDays = compactWindowDays ?? 7;

  /// How many days [compactWindow] covers — seven on list surfaces, the
  /// page's shared history span on the detail page, so the whole-goal strip
  /// renders the same days as every other track.
  final int compactWindowDays;

  final DateTime today;
  final List<GoalHabitProgressView> habits;
  final List<GoalMetricProgressView> metrics;
  final List<DayMarkState>? compositeCompactWindow;
  final GoalCompositeRuleKind? compositeRule;
  final int? requiredSuccesses;
  final bool rootOnTrack;

  int get dimensionCount => habits.length + metrics.length;

  GoalMetricProgressView? get metric => metrics.firstOrNull;

  /// The compact list-row picture. Composite routines preserve their `all`,
  /// `any`, or `at least N` semantics; a single habit uses its own series.
  /// Metric goals respect their at-least/at-most direction. A day is `full`
  /// when the goal requirement held as of that day, `partial` when the
  /// routine was completed while the requirement was still building up.
  List<DayMarkState> get compactWindow {
    if (compositeCompactWindow case final compact?) return compact;
    final activeDays = [
      for (var offset = compactWindowDays - 1; offset >= 0; offset--)
        GoalWindow.dayUtc(today.subtract(Duration(days: offset))),
    ];
    if (habits.isNotEmpty) {
      return [
        for (final day in activeDays)
          _combinedDayState([
            for (final habit in habits) _habitDayState(habit: habit, day: day),
          ]),
      ];
    }
    final series = metric;
    if (series == null) return const [];
    final periodDays = series.days
        .where((entry) => !entry.day.isAfter(today))
        .toList(growable: false);
    final compactDays = periodDays.length <= compactWindowDays
        ? periodDays
        : periodDays.sublist(periodDays.length - compactWindowDays);
    return [
      for (final day in compactDays)
        // The same per-day policy as the bars and the reflection sheet this
        // cell opens — a strip cell must not call a day missed while the
        // sheet suggests "met" for it.
        if (series.dayMark(day)) DayMarkState.full else DayMarkState.none,
    ];
  }

  static DayMarkState _habitDayState({
    required GoalHabitProgressView habit,
    required DateTime day,
  }) {
    final entry = habit.days
        .where((candidate) => candidate.day == day && candidate.hasValue)
        .firstOrNull;
    if (entry == null) return DayMarkState.none;
    return (entry.targetSatisfied ?? true)
        ? DayMarkState.full
        : DayMarkState.partial;
  }

  /// A multi-habit day is only as strong as its weakest completed habit, and
  /// only counts at all when every habit was completed.
  static DayMarkState _combinedDayState(
    List<DayMarkState> states,
  ) {
    if (states.any((state) => state == DayMarkState.none)) {
      return DayMarkState.none;
    }
    return states.any((state) => state == DayMarkState.partial)
        ? DayMarkState.partial
        : DayMarkState.full;
  }
}

bool _meetsTarget(num value, num target, GoalDirection direction) =>
    switch (direction) {
      GoalDirection.atLeast => value >= target,
      GoalDirection.atMost => value <= target,
    };

/// Words too generic to link a habit to a data dimension by name. The match
/// is a whole-word overlap on the remaining tokens, so "Measure Blood
/// Pressure" pairs with "Systolic blood pressure" while "BP meds" does not.
/// Deliberately small and English-only: names authored in other languages
/// still match each other verbatim, and a missed suggestion is harmless.
const Set<String> _genericNameTokens = {
  'a',
  'an',
  'and',
  'check',
  'daily',
  'day',
  'days',
  'every',
  'for',
  'habit',
  'log',
  'measure',
  'my',
  'of',
  'per',
  'record',
  'take',
  'the',
  'track',
  'week',
  'weekly',
  'with',
};

Set<String> _nameTokens(String name) => {
  for (final token in name.toLowerCase().split(
    RegExp(r'[^\p{L}\p{N}]+', unicode: true),
  ))
    if (token.length > 1 && !_genericNameTokens.contains(token)) token,
};

/// Offers a one-tap check-off when evidence for a matching data dimension
/// was recorded today while the habit day is still blank.
GoalHabitProgressView _withCheckOffSuggestion({
  required GoalHabitProgressView habit,
  required List<GoalMetricProgressView> metrics,
  required DateTime today,
}) {
  final todayEntry = habit.days
      .where((entry) => entry.day == today)
      .firstOrNull;
  if (todayEntry == null ||
      todayEntry.hasValue ||
      todayEntry.habitCompletionType != null) {
    return habit;
  }
  final habitTokens = _nameTokens(habit.name);
  if (habitTokens.isEmpty) return habit;
  for (final metric in metrics) {
    // Category time is excluded: its days are observed by definition, so it
    // would suggest on every blank day without carrying new evidence.
    final observableKind =
        metric.kind == GoalDimensionKind.health ||
        metric.kind == GoalDimensionKind.measurable;
    if (!observableKind) continue;
    final observedToday = metric.days.any(
      (entry) => entry.day == today && entry.isObserved && entry.value > 0,
    );
    if (!observedToday) continue;
    if (_nameTokens(metric.name).intersection(habitTokens).isEmpty) continue;
    return GoalHabitProgressView(
      habitId: habit.habitId,
      criterionId: habit.criterionId,
      name: habit.name,
      sourceCaption: habit.sourceCaption,
      targetCount: habit.targetCount,
      days: habit.days,
      successfulWeeks: habit.successfulWeeks,
      window: habit.window,
      slippedDay: habit.slippedDay,
      suggestedFromDimensionName: metric.name,
    );
  }
  return habit;
}

DayMarkState _criterionDayState(
  GoalCriterion criterion,
  GoalSignalWindow signals,
  DateTime day,
) {
  if (const GoalProgressEvaluator()
      .evaluate(criterion, signals, day)
      .satisfied) {
    return DayMarkState.full;
  }
  return _criterionCompletedOnDay(criterion, signals, day)
      ? DayMarkState.partial
      : DayMarkState.none;
}

bool _criterionCompletedOnDay(
  GoalCriterion criterion,
  GoalSignalWindow signals,
  DateTime day,
) => switch (criterion) {
  // The compact strip is an accomplishment history, not a second health
  // verdict: a rolling habit contributes when it was completed on this day.
  GoalCriterionHabit(:final habitId) =>
    (signals.habitSuccessesByDay[habitId]?[day] ?? 0) > 0,
  GoalCriterionMetric() ||
  GoalCriterionMeasurable() ||
  GoalCriterionCategoryTime() ||
  GoalCriterionLabelTime() =>
    const GoalProgressEvaluator().evaluate(criterion, signals, day).satisfied,
  GoalCriterionAllOf(criteria: final children) => children.every(
    (child) => _criterionCompletedOnDay(child, signals, day),
  ),
  GoalCriterionAnyOf(criteria: final children) => children.any(
    (child) => _criterionCompletedOnDay(child, signals, day),
  ),
  GoalCriterionAtLeastCount(
    criteria: final children,
    successes: final requiredSuccesses,
  ) =>
    children
            .where((child) => _criterionCompletedOnDay(child, signals, day))
            .length >=
        requiredSuccesses,
};

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

GoalMetricProgressView _metricProgressView({
  required GoalCriterionMetric metric,
  required GoalSignalWindow signals,
  required DateTime reference,
  bool projectedOnTrack = false,
  int? historyDays,
}) {
  return _numericProgressView(
    historyDays: historyDays,
    criterion: metric,
    criterionId: metric.criterionId,
    sourceId: metric.dataType,
    kind: GoalDimensionKind.health,
    name: metric.title?.trim().isNotEmpty == true
        ? metric.title!.trim()
        : metric.dataType,
    target: metric.target,
    window: metric.window,
    direction: metric.direction,
    aggregation: metric.aggregation,
    unitName: switch (metric.dataType) {
      GoalHealthDataTypes.weight => 'kg',
      GoalHealthDataTypes.bloodPressureSystolic ||
      GoalHealthDataTypes.bloodPressureDiastolic => 'mmHg',
      _ => null,
    },
    dailyValues: signals.quantitativeDailySums[metric.dataType],
    signals: signals,
    reference: reference,
    projectedOnTrack: projectedOnTrack,
  );
}

GoalMetricProgressView _measurableProgressView({
  required GoalCriterionMeasurable measurable,
  required GoalSignalWindow signals,
  required DateTime reference,
  MeasurableDataType? definition,
  Set<String> agentRecordedMeasurementIds = const {},
  Map<String, GoalRecordedMeasurementProvenance>
      recordedMeasurementProvenanceById =
      const {},
  bool projectedOnTrack = false,
  int? historyDays,
}) {
  final agentRecordedDays = agentRecordedMeasurementIds
      .map((entryId) => signals.measurableEntryDaysById[entryId])
      .whereType<DateTime>()
      .toSet();
  final provenanceByDay = <DateTime, GoalRecordedMeasurementProvenance>{};
  for (final entry in recordedMeasurementProvenanceById.entries) {
    final day = signals.measurableEntryDaysById[entry.key];
    if (day != null) provenanceByDay[day] = entry.value;
  }
  return _numericProgressView(
    historyDays: historyDays,
    criterion: measurable,
    criterionId: measurable.criterionId,
    sourceId: measurable.dataTypeId,
    kind: GoalDimensionKind.measurable,
    name: measurable.title?.trim().isNotEmpty == true
        ? measurable.title!.trim()
        : definition?.displayName ?? measurable.dataTypeId,
    unitName: definition?.unitName,
    target: measurable.target,
    window: measurable.window,
    direction: measurable.direction,
    aggregation: measurable.aggregation,
    dailyValues: signals.measurableDailySums[measurable.dataTypeId],
    signals: signals,
    reference: reference,
    projectedOnTrack: projectedOnTrack,
    agentRecordedDays: agentRecordedDays,
    agentRecordedProvenanceByDay: provenanceByDay,
  );
}

GoalMetricProgressView _categoryTimeProgressView({
  required GoalCriterionCategoryTime categoryTime,
  required GoalSignalWindow signals,
  required DateTime reference,
  String? categoryName,
  bool projectedOnTrack = false,
  int? historyDays,
}) => _numericProgressView(
  historyDays: historyDays,
  criterion: categoryTime,
  criterionId: categoryTime.criterionId,
  sourceId: categoryTime.categoryId,
  kind: GoalDimensionKind.categoryTime,
  name: categoryTime.title?.trim().isNotEmpty == true
      ? categoryTime.title!.trim()
      : categoryName ?? categoryTime.categoryId,
  dailyTimeRange: categoryTime.dailyTimeRange,
  categoryTimeSessions:
      signals.categoryTimeSessionsByCategory[categoryTime.categoryId] ??
      const [],
  target: categoryTime.targetHours,
  window: categoryTime.window,
  direction: categoryTime.direction,
  aggregation: categoryTime.aggregation,
  dailyValues: signals.categoryTimeDailyHours[categoryTime.criterionId],
  signals: signals,
  reference: reference,
  projectedOnTrack: projectedOnTrack,
  zeroIsObserved: true,
);

GoalMetricProgressView _labelTimeProgressView({
  required GoalCriterionLabelTime labelTime,
  required GoalSignalWindow signals,
  required DateTime reference,
  String? labelName,
  String? categoryName,
  int? historyDays,
}) => _numericProgressView(
  historyDays: historyDays,
  criterion: labelTime,
  criterionId: labelTime.criterionId,
  sourceId: labelTime.labelId,
  kind: GoalDimensionKind.labelTime,
  name: labelTime.title?.trim().isNotEmpty == true
      ? labelTime.title!.trim()
      : [labelName ?? labelTime.labelId, ?categoryName].join(' · '),
  dailyTimeRange: labelTime.dailyTimeRange,
  target: labelTime.targetHours,
  window: labelTime.window,
  direction: labelTime.direction,
  aggregation: labelTime.aggregation,
  dailyValues: signals.labelTimeDailyHours[labelTime.criterionId],
  signals: signals,
  reference: reference,
  zeroIsObserved: true,
);

/// The first rendered day: the authored range start, or further back when
/// the page's shared [historyDays] span (ending today) reaches earlier.
DateTime _historyStart({
  required DateTime rangeStart,
  required DateTime today,
  required int? historyDays,
}) {
  if (historyDays == null) return rangeStart;
  final spanStart = today.subtract(Duration(days: historyDays - 1));
  return spanStart.isBefore(rangeStart) ? spanStart : rangeStart;
}

/// The last rendered day: the authored range end, clamped to [today].
///
/// A calendar window's [GoalWindow.periodRange] covers its WHOLE week or
/// month, so rendering it unclipped drew cells for dates that have not
/// happened yet — a Friday habit track ran two grey "No entry" days past
/// today and labelled itself "Jul 31 – Aug 23". The goal-days strip above it
/// counts back from today and stops there, so the two tracks disagreed on
/// both the period line and, because the column pitch is the available width
/// divided by the day count, on the size of the squares themselves.
DateTime _historyEnd({required DateTime rangeEnd, required DateTime today}) =>
    rangeEnd.isAfter(today) ? today : rangeEnd;

GoalMetricProgressView _numericProgressView({
  required GoalCriterion criterion,
  required String criterionId,
  required String sourceId,
  required GoalDimensionKind kind,
  required String name,
  required num target,
  required GoalWindow window,
  required GoalDirection direction,
  required GoalAggregation aggregation,
  required Map<DateTime, num>? dailyValues,
  required GoalSignalWindow signals,
  required DateTime reference,
  bool zeroIsObserved = false,
  String? unitName,
  GoalDailyTimeRange? dailyTimeRange,
  Set<DateTime> agentRecordedDays = const {},
  Map<DateTime, GoalRecordedMeasurementProvenance>
      agentRecordedProvenanceByDay =
      const {},
  List<GoalCategoryTimeSession> categoryTimeSessions = const [],
  bool projectedOnTrack = false,
  int? historyDays,
}) {
  final range = window.periodRange(reference);
  final today = GoalWindow.dayUtc(reference);
  final start = _historyStart(
    rangeStart: range.start,
    today: today,
    historyDays: historyDays,
  );
  final end = _historyEnd(rangeEnd: range.end, today: today);
  return GoalMetricProgressView(
    evaluatedActual: const GoalProgressEvaluator()
        .evaluate(criterion, signals, reference)
        .results[criterionId]
        ?.actual,
    criterionId: criterionId,
    sourceId: sourceId,
    kind: kind,
    name: name,
    target: target,
    window: window,
    direction: direction,
    aggregation: aggregation,
    unitName: unitName,
    dailyTimeRange: dailyTimeRange,
    agentRecordedDays: agentRecordedDays,
    agentRecordedProvenanceByDay: agentRecordedProvenanceByDay,
    categoryTimeSessions: categoryTimeSessions,
    projectedOnTrack: projectedOnTrack,
    // The six days before the first visible one, so a trailing seven-day
    // mean has a full window on day one of the chart instead of starting a
    // week in. The reader's range already covers them.
    warmupValues: {
      if (dailyValues != null)
        for (
          var day = start.subtract(const Duration(days: 6));
          day.isBefore(start);
          day = day.add(const Duration(days: 1))
        )
          day: ?dailyValues[day],
    },
    days: [
      for (
        var day = start;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))
      )
        GoalProgressDay(
          day: day,
          value: dailyValues?[day] ?? 0,
          isObserved:
              (dailyValues?.containsKey(day) ?? false) ||
              (zeroIsObserved && !day.isAfter(today)),
          // A rolling window ends at the reference day; a calendar window's
          // period range covers its WHOLE week or month, so evaluating it
          // unclipped would let Friday's total repaint Monday's verdict
          // retroactively. Clipping the aggregates makes this the verdict
          // as of that day — the window ending there — for both shapes.
          targetSatisfied: const GoalProgressEvaluator()
              .evaluate(
                criterion,
                window is GoalWindowRollingDays
                    ? signals
                    : _signalsThroughDay(signals, day),
                day,
              )
              .satisfied,
        ),
    ],
  );
}

/// [signals] with every daily aggregate after [day] removed, so a calendar
/// criterion's per-day verdict cannot see data logged later in the same
/// period. Identity-preserving for everything evaluation does not date-fold.
GoalSignalWindow _signalsThroughDay(GoalSignalWindow signals, DateTime day) {
  Map<String, Map<DateTime, V>> clip<V>(Map<String, Map<DateTime, V>> source) =>
      {
        for (final entry in source.entries)
          entry.key: {
            for (final dayEntry in entry.value.entries)
              if (!dayEntry.key.isAfter(day)) dayEntry.key: dayEntry.value,
          },
      };
  return GoalSignalWindow(
    quantitativeDailySums: clip(signals.quantitativeDailySums),
    quantitativeObservationsByType: signals.quantitativeObservationsByType,
    habitSuccessesByDay: signals.habitSuccessesByDay,
    habitCompletionsByDay: signals.habitCompletionsByDay,
    measurableDailySums: clip(signals.measurableDailySums),
    measurableEntryDaysById: signals.measurableEntryDaysById,
    categoryTimeDailyHours: clip(signals.categoryTimeDailyHours),
    categoryTimeSessionsByCategory: signals.categoryTimeSessionsByCategory,
    labelTimeDailyHours: clip(signals.labelTimeDailyHours),
    labelTimeEntriesByCriterion: signals.labelTimeEntriesByCriterion,
    labelTimeEvidenceStart: signals.labelTimeEvidenceStart,
    labelTimeEvidenceEnd: signals.labelTimeEvidenceEnd,
    categoryTimeEvidenceStart: signals.categoryTimeEvidenceStart,
    categoryTimeEvidenceEnd: signals.categoryTimeEvidenceEnd,
    hasActiveCategoryTimer: signals.hasActiveCategoryTimer,
    hasActiveLabelTimer: signals.hasActiveLabelTimer,
  );
}

GoalHabitProgressView _habitProgressView({
  required GoalCriterionHabit habit,
  required GoalSignalWindow signals,
  required DateTime reference,
  required DateTime today,
  required Map<String, String> habitNames,
  int? historyDays,
}) {
  final range = habit.window.periodRange(reference);
  // The rendered day span: the authored window, extended backwards to the
  // page's shared history span when one is selected. Aggregates never fold
  // this list — the evaluator's numbers win — so a longer rendering cannot
  // change a verdict.
  final start = _historyStart(
    rangeStart: range.start,
    today: today,
    historyDays: historyDays,
  );
  final end = _historyEnd(rangeEnd: range.end, today: today);
  // Per-day verdict of the habit's own window ending that day: a completed
  // day whose window quota was not yet met renders as a partial success.
  GoalProgressDay projection(DateTime day) => GoalProgressDay(
    day: day,
    value: signals.habitSuccessesByDay[habit.habitId]?[day] ?? 0,
    habitCompletionType: signals.habitCompletionsByDay[habit.habitId]?[day],
    targetSatisfied: const GoalProgressEvaluator()
        .evaluate(habit, signals, day)
        .satisfied,
  );
  return GoalHabitProgressView(
    evaluatedSuccesses: const GoalProgressEvaluator()
        .evaluate(habit, signals, reference)
        .results[habit.criterionId]
        ?.actual
        .toInt(),
    criterionId: habit.criterionId,
    habitId: habit.habitId,
    name: habit.title?.trim().isNotEmpty == true
        ? habit.title!.trim()
        : habitNames[habit.habitId] ?? habit.habitId,
    targetCount: habit.targetCount,
    window: habit.window,
    slippedDay: habit.window is GoalWindowRollingDays
        ? projection(range.start.subtract(const Duration(days: 1)))
        : null,
    days: [
      for (
        var day = start;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))
      )
        projection(day),
    ],
    successfulWeeks: habit.window == const GoalWindow.rollingDays(count: 7)
        ? _successfulWeeks(
            successes: signals.habitSuccessesByDay[habit.habitId] ?? const {},
            today: today,
            target: habit.targetCount,
          )
        : null,
  );
}

int _successfulWeeks({
  required Map<DateTime, int> successes,
  required DateTime today,
  required int target,
}) {
  var successful = 0;
  for (var week = 0; week < 6; week++) {
    final end = today.subtract(Duration(days: week * 7));
    final start = end.subtract(const Duration(days: 6));
    final count = successes.entries
        .where(
          (entry) =>
              !entry.key.isBefore(start) &&
              !entry.key.isAfter(end) &&
              entry.value > 0,
        )
        .length;
    if (count >= target) successful++;
  }
  return successful;
}

/// Live progress projection for the active goal spec. The reader is asked for
/// six weeks because the detail card includes the reliability tail alongside
/// the active seven-day window.
final FutureProviderFamily<GoalProgressView?, String>
goalAgentProgressViewProvider = FutureProvider.autoDispose
    .family<GoalProgressView?, String>(
      (ref, agentId) => _progressView(ref, agentId, null),
      name: 'goalAgentProgressViewProvider',
    );

/// One goal's progress-view request: the agent plus an optional shared
/// history span. Null renders each dimension's authored window only.
typedef GoalProgressViewRequest = ({String agentId, int? historyDays});

/// The span-aware sibling of [goalAgentProgressViewProvider]: the detail
/// page keys it with its shared range so every day track renders the same
/// days. Both providers run the same computation independently — writers
/// that invalidate one must invalidate the other (the span side as the
/// whole family), or a recording refreshes the list but not the open
/// detail page.
final FutureProviderFamily<GoalProgressView?, GoalProgressViewRequest>
goalAgentProgressViewForSpanProvider = FutureProvider.autoDispose
    .family<GoalProgressView?, GoalProgressViewRequest>(
      (ref, request) =>
          _progressView(ref, request.agentId, request.historyDays),
      name: 'goalAgentProgressViewForSpanProvider',
    );

Future<GoalProgressView?> _progressView(
  Ref ref,
  String agentId,
  int? historyDays,
) async {
  final health = await ref.watch(goalAgentHealthProvider(agentId).future);
  final spec = health.spec;
  if (spec == null) return null;
  final reference = clock.now();
  final nextMidnight = DateTime(
    reference.year,
    reference.month,
    reference.day + 1,
  );
  final midnightTimer = Timer(
    nextMidnight.difference(reference),
    ref.invalidateSelf,
  );
  ref.onDispose(midnightTimer.cancel);
  final signals = await ref
      .watch(goalSignalReaderProvider)
      .read(
        criteria: spec.criteria,
        reference: reference,
        // Six weeks for the reliability tail; wider when the page's
        // shared range reaches further back (plus a week so rolling
        // verdicts at the span's oldest day still see their window).
        shortTermDays: math.max(43, (historyDays ?? 0) + 7),
      );

  final habitIds = <String>{};
  void collect(GoalCriterion criterion) {
    switch (criterion) {
      case GoalCriterionHabit(:final habitId):
        habitIds.add(habitId);
      case GoalCriterionMetric() ||
          GoalCriterionMeasurable() ||
          GoalCriterionCategoryTime() ||
          GoalCriterionLabelTime():
        return;
      case GoalCriterionAllOf(criteria: final children):
        children.forEach(collect);
      case GoalCriterionAnyOf(criteria: final children):
        children.forEach(collect);
      case GoalCriterionAtLeastCount(criteria: final children):
        children.forEach(collect);
    }
  }

  collect(spec.criteria);
  final db = ref.watch(journalDbProvider);
  final names = <String, String>{};
  final measurableDefinitions = <String, MeasurableDataType>{};
  final categoryNames = <String, String>{};
  final labelNames = <String, String>{};
  for (final habitId in habitIds) {
    final habit = await db.getHabitById(habitId);
    if (habit != null) names[habitId] = habit.name;
  }
  final measurableIds = <String>{};
  final categoryIds = <String>{};
  final labelIds = <String>{};
  void collectDefinitions(GoalCriterion criterion) {
    switch (criterion) {
      case GoalCriterionMeasurable(:final dataTypeId):
        measurableIds.add(dataTypeId);
      case GoalCriterionCategoryTime(:final categoryId):
        categoryIds.add(categoryId);
      case GoalCriterionLabelTime(:final labelId, :final categoryId):
        labelIds.add(labelId);
        if (categoryId != null) categoryIds.add(categoryId);
      case GoalCriterionMetric() || GoalCriterionHabit():
        return;
      case GoalCriterionAllOf(criteria: final children):
        children.forEach(collectDefinitions);
      case GoalCriterionAnyOf(criteria: final children):
        children.forEach(collectDefinitions);
      case GoalCriterionAtLeastCount(criteria: final children):
        children.forEach(collectDefinitions);
    }
  }

  collectDefinitions(spec.criteria);
  for (final measurableId in measurableIds) {
    final definition = await db.getMeasurableDataTypeById(measurableId);
    if (definition != null) {
      measurableDefinitions[measurableId] = definition;
    }
  }
  for (final categoryId in categoryIds) {
    final definition = await db.getCategoryById(categoryId);
    if (definition != null) categoryNames[categoryId] = definition.name;
  }
  for (final labelId in labelIds) {
    final definition = await db.getLabelDefinitionById(labelId);
    if (definition != null) labelNames[labelId] = definition.name;
  }
  final captureDecisions = measurableIds.isEmpty
      ? const <String, GoalMeasurableCaptureDecision>{}
      : await ref.watch(
          goalMeasurableCaptureDecisionsProvider(agentId).future,
        );
  final agentRecordedMeasurementIds = {
    for (final decision in captureDecisions.values)
      if (decision.recorded) ...decision.entryIds,
  };
  final recordedMeasurementProvenanceById = {
    for (final decision in captureDecisions.values)
      if (decision.recorded &&
          decision.recordedAt != null &&
          decision.agentName != null)
        for (final entryId in decision.entryIds)
          entryId: GoalRecordedMeasurementProvenance(
            agentName: decision.agentName!,
            recordedAt: decision.recordedAt!,
          ),
  };
  return buildGoalProgressView(
    criteria: spec.criteria,
    signals: signals,
    reference: reference,
    historyDays: historyDays,
    habitNames: names,
    measurableDefinitions: measurableDefinitions,
    categoryNames: categoryNames,
    labelNames: labelNames,
    agentRecordedMeasurementIds: agentRecordedMeasurementIds,
    recordedMeasurementProvenanceById: recordedMeasurementProvenanceById,
  );
}
