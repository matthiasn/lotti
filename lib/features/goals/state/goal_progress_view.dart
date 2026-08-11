import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/evaluation/goal_progress_evaluator.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;

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
    this.window = const GoalWindow.rollingDays(count: 7),
    this.slippedDay,
  });

  final String habitId;
  final String name;
  final int targetCount;
  final List<GoalProgressDay> days;

  /// Successful trailing seven-day periods, available only when the authored
  /// criterion itself is a rolling seven-day habit.
  final int? successfulWeeks;
  final GoalWindow window;
  final GoalProgressDay? slippedDay;

  int get successesInWindow => switch (window) {
    GoalWindowRollingDays() => days.where((day) => day.value > 0).length,
    _ => days.fold(0, (total, day) => total + day.value.toInt()),
  };

  int get deficit => (targetCount - successesInWindow).clamp(0, targetCount);

  bool get oldestSuccessAgesOutTonight =>
      window is GoalWindowRollingDays &&
      successesInWindow >= targetCount &&
      days.isNotEmpty &&
      days.first.value > 0;
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
  });

  final String name;
  final num target;
  final List<GoalProgressDay> days;
  final GoalAggregation aggregation;
  final GoalWindow window;
  final GoalDirection direction;

  bool meetsTarget(GoalProgressDay day) =>
      day.isObserved &&
      (day.targetSatisfied ?? _meetsTarget(day.value, target, direction));
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
  }) : metrics = metric == null ? metrics : [metric, ...metrics];

  final DateTime today;
  final List<GoalHabitProgressView> habits;
  final List<GoalMetricProgressView> metrics;
  final List<bool>? compositeCompactWindow;

  GoalMetricProgressView? get metric => metrics.firstOrNull;

  /// The compact list-row picture. Composite routines preserve their `all`,
  /// `any`, or `at least N` semantics; a single habit uses its own series.
  /// Metric goals respect their at-least/at-most direction.
  List<bool> get compactWindow {
    if (compositeCompactWindow case final compact?) return compact;
    final activeDays = [
      for (var offset = 6; offset >= 0; offset--)
        GoalWindow.dayUtc(today.subtract(Duration(days: offset))),
    ];
    if (habits.isNotEmpty) {
      return [
        for (final day in activeDays)
          habits.every(
            (habit) => habit.days.any(
              (entry) => entry.day == day && entry.hasValue,
            ),
          ),
      ];
    }
    final series = metric;
    if (series == null) return const [];
    final periodDays = series.days
        .where((entry) => !entry.day.isAfter(today))
        .toList(growable: false);
    final compactDays = periodDays.length <= 7
        ? periodDays
        : periodDays.sublist(periodDays.length - 7);
    return [
      for (final day in compactDays) series.meetsTarget(day),
    ];
  }
}

bool _meetsTarget(num value, num target, GoalDirection direction) =>
    switch (direction) {
      GoalDirection.atLeast => value >= target,
      GoalDirection.atMost => value <= target,
    };

bool _criterionMetOnDay(
  GoalCriterion criterion,
  GoalSignalWindow signals,
  DateTime day,
) =>
    _criterionCompletedOnDay(criterion, signals, day) ||
    const GoalProgressEvaluator().evaluate(criterion, signals, day).satisfied;

bool _criterionCompletedOnDay(
  GoalCriterion criterion,
  GoalSignalWindow signals,
  DateTime day,
) => switch (criterion) {
  // The compact strip is an accomplishment history, not a second health
  // verdict: a rolling habit contributes when it was completed on this day.
  GoalCriterionHabit(:final habitId) =>
    (signals.habitSuccessesByDay[habitId]?[day] ?? 0) > 0,
  GoalCriterionMetric() || GoalCriterionMeasurable() =>
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
  Map<String, String> habitNames = const {},
}) {
  final today = GoalWindow.dayUtc(reference);
  final habitLeaves = <GoalCriterionHabit>[];
  final metricLeaves = <GoalCriterionMetric>[];
  final measurableLeaves = <GoalCriterionMeasurable>[];

  void visit(GoalCriterion criterion) {
    switch (criterion) {
      case final GoalCriterionHabit habit:
        habitLeaves.add(habit);
      case final GoalCriterionMetric metric:
        metricLeaves.add(metric);
      case final GoalCriterionMeasurable measurable:
        measurableLeaves.add(measurable);
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
      ),
  ];

  final compositeCompactWindow = switch (criteria) {
    GoalCriterionAllOf() ||
    GoalCriterionAnyOf() ||
    GoalCriterionAtLeastCount() => [
      for (var offset = 6; offset >= 0; offset--)
        _criterionMetOnDay(
          criteria,
          signals,
          GoalWindow.dayUtc(today.subtract(Duration(days: offset))),
        ),
    ],
    _ => null,
  };
  return GoalProgressView(
    today: today,
    habits: habits,
    compositeCompactWindow: compositeCompactWindow,
    metrics: [
      for (final metric in metricLeaves)
        _metricProgressView(
          metric: metric,
          signals: signals,
          reference: reference,
        ),
      for (final measurable in measurableLeaves)
        _measurableProgressView(
          measurable: measurable,
          signals: signals,
          reference: reference,
        ),
    ],
  );
}

GoalMetricProgressView _metricProgressView({
  required GoalCriterionMetric metric,
  required GoalSignalWindow signals,
  required DateTime reference,
}) {
  return _numericProgressView(
    criterion: metric,
    name: metric.title?.trim().isNotEmpty == true
        ? metric.title!.trim()
        : metric.dataType,
    target: metric.target,
    window: metric.window,
    direction: metric.direction,
    aggregation: metric.aggregation,
    dailyValues: signals.quantitativeDailySums[metric.dataType],
    signals: signals,
    reference: reference,
  );
}

GoalMetricProgressView _measurableProgressView({
  required GoalCriterionMeasurable measurable,
  required GoalSignalWindow signals,
  required DateTime reference,
}) => _numericProgressView(
  criterion: measurable,
  name: measurable.title?.trim().isNotEmpty == true
      ? measurable.title!.trim()
      : measurable.dataTypeId,
  target: measurable.target,
  window: measurable.window,
  direction: measurable.direction,
  aggregation: measurable.aggregation,
  dailyValues: signals.measurableDailySums[measurable.dataTypeId],
  signals: signals,
  reference: reference,
);

GoalMetricProgressView _numericProgressView({
  required GoalCriterion criterion,
  required String name,
  required num target,
  required GoalWindow window,
  required GoalDirection direction,
  required GoalAggregation aggregation,
  required Map<DateTime, num>? dailyValues,
  required GoalSignalWindow signals,
  required DateTime reference,
}) {
  final range = window.periodRange(reference);
  return GoalMetricProgressView(
    name: name,
    target: target,
    window: window,
    direction: direction,
    aggregation: aggregation,
    days: [
      for (
        var day = range.start;
        !day.isAfter(range.end);
        day = day.add(const Duration(days: 1))
      )
        GoalProgressDay(
          day: day,
          value: dailyValues?[day] ?? 0,
          isObserved: dailyValues?.containsKey(day) ?? false,
          targetSatisfied: const GoalProgressEvaluator()
              .evaluate(criterion, signals, day)
              .satisfied,
        ),
    ],
  );
}

GoalHabitProgressView _habitProgressView({
  required GoalCriterionHabit habit,
  required GoalSignalWindow signals,
  required DateTime reference,
  required DateTime today,
  required Map<String, String> habitNames,
}) {
  final range = habit.window.periodRange(reference);
  GoalProgressDay projection(DateTime day) => GoalProgressDay(
    day: day,
    value: signals.habitSuccessesByDay[habit.habitId]?[day] ?? 0,
    habitCompletionType: signals.habitCompletionsByDay[habit.habitId]?[day],
  );
  return GoalHabitProgressView(
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
        var day = range.start;
        !day.isAfter(range.end);
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
    .family<GoalProgressView?, String>((ref, agentId) async {
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
            shortTermDays: 43,
          );

      final habitIds = <String>{};
      void collect(GoalCriterion criterion) {
        switch (criterion) {
          case GoalCriterionHabit(:final habitId):
            habitIds.add(habitId);
          case GoalCriterionMetric() || GoalCriterionMeasurable():
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
      for (final habitId in habitIds) {
        final habit = await db.getHabitById(habitId);
        if (habit != null) names[habitId] = habit.name;
      }
      return buildGoalProgressView(
        criteria: spec.criteria,
        signals: signals,
        reference: reference,
        habitNames: names,
      );
    }, name: 'goalAgentProgressViewProvider');
