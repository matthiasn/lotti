import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;

/// One habit row in the rolling-window visual used by the Agents list and
/// goal detail page. [days] contains the slipped day first, followed by the
/// active trailing seven-day window ending at [GoalProgressView.today].
class GoalHabitProgressView {
  const GoalHabitProgressView({
    required this.habitId,
    required this.name,
    required this.targetCount,
    required this.days,
    required this.successfulWeeks,
  });

  final String habitId;
  final String name;
  final int targetCount;
  final List<GoalProgressDay> days;
  final int successfulWeeks;

  int get successesInWindow =>
      days.skip(1).where((day) => day.value > 0).length;

  int get deficit => (targetCount - successesInWindow).clamp(0, targetCount);

  bool get oldestSuccessAgesOutTonight =>
      successesInWindow >= targetCount && days[1].value > 0;
}

/// The metric-series variant of the same trailing-seven-day frame.
class GoalMetricProgressView {
  const GoalMetricProgressView({
    required this.name,
    required this.target,
    required this.days,
    this.window = const GoalWindow.rollingDays(count: 7),
    this.direction = GoalDirection.atLeast,
  });

  final String name;
  final num target;
  final List<GoalProgressDay> days;
  final GoalWindow window;
  final GoalDirection direction;

  bool meetsTarget(GoalProgressDay day) =>
      day.isObserved && _meetsTarget(day.value, target, direction);
}

class GoalProgressDay {
  const GoalProgressDay({
    required this.day,
    required this.value,
    this.habitCompletionType,
    this.isObserved = true,
  });

  final DateTime day;
  final num value;
  final HabitCompletionType? habitCompletionType;
  final bool isObserved;

  bool get hasValue => value > 0;
}

class GoalProgressView {
  const GoalProgressView({
    required this.today,
    this.habits = const [],
    this.metric,
    this.compositeCompactWindow,
  });

  final DateTime today;
  final List<GoalHabitProgressView> habits;
  final GoalMetricProgressView? metric;
  final List<bool>? compositeCompactWindow;

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
) => switch (criterion) {
  GoalCriterionHabit(:final habitId) =>
    (signals.habitSuccessesByDay[habitId]?[day] ?? 0) > 0,
  GoalCriterionMetric(:final dataType, :final target, :final direction) =>
    signals.quantitativeDailySums[dataType]?.containsKey(day) == true &&
        _meetsTarget(
          signals.quantitativeDailySums[dataType]![day]!,
          target,
          direction,
        ),
  GoalCriterionMeasurable(:final dataTypeId, :final target, :final direction) =>
    signals.measurableDailySums[dataTypeId]?.containsKey(day) == true &&
        _meetsTarget(
          signals.measurableDailySums[dataTypeId]![day]!,
          target,
          direction,
        ),
  GoalCriterionAllOf(criteria: final children) => children.every(
    (child) => _criterionMetOnDay(child, signals, day),
  ),
  GoalCriterionAnyOf(criteria: final children) => children.any(
    (child) => _criterionMetOnDay(child, signals, day),
  ),
  GoalCriterionAtLeastCount(
    criteria: final children,
    successes: final requiredSuccesses,
  ) =>
    children.where((child) => _criterionMetOnDay(child, signals, day)).length >=
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
  final displayDays = [
    for (var offset = 7; offset >= 0; offset--)
      today.subtract(Duration(days: offset)),
  ];
  final habitLeaves = <GoalCriterionHabit>[];
  GoalCriterionMetric? metricLeaf;

  void visit(GoalCriterion criterion) {
    switch (criterion) {
      case final GoalCriterionHabit habit:
        habitLeaves.add(habit);
      case final GoalCriterionMetric metric:
        metricLeaf ??= metric;
      case GoalCriterionMeasurable():
        // The detail visual for measured values follows once their unit/name
        // presentation is available; the evaluator still renders health.
        return;
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
      GoalHabitProgressView(
        habitId: habit.habitId,
        name: habit.title?.trim().isNotEmpty == true
            ? habit.title!.trim()
            : habitNames[habit.habitId] ?? habit.habitId,
        targetCount: habit.targetCount,
        days: [
          for (final day in displayDays)
            GoalProgressDay(
              day: day,
              value: signals.habitSuccessesByDay[habit.habitId]?[day] ?? 0,
              habitCompletionType:
                  signals.habitCompletionsByDay[habit.habitId]?[day],
            ),
        ],
        successfulWeeks: _successfulWeeks(
          successes: signals.habitSuccessesByDay[habit.habitId] ?? const {},
          today: today,
          target: habit.targetCount,
        ),
      ),
  ];

  final metric = metricLeaf;
  final metricRange = metric?.window.periodRange(reference);
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
    metric: metric == null
        ? null
        : GoalMetricProgressView(
            name: metric.title?.trim().isNotEmpty == true
                ? metric.title!.trim()
                : metric.dataType,
            target: metric.target,
            window: metric.window,
            direction: metric.direction,
            days: [
              for (
                var day = metricRange!.start;
                !day.isAfter(metricRange.end);
                day = day.add(const Duration(days: 1))
              )
                GoalProgressDay(
                  day: day,
                  value:
                      signals.quantitativeDailySums[metric.dataType]?[day] ?? 0,
                  isObserved:
                      signals.quantitativeDailySums[metric.dataType]
                          ?.containsKey(day) ??
                      false,
                ),
            ],
          ),
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
