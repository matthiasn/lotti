import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
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
  });

  final String name;
  final num target;
  final List<GoalProgressDay> days;
}

class GoalProgressDay {
  const GoalProgressDay({
    required this.day,
    required this.value,
    this.habitCompletionType,
  });

  final DateTime day;
  final num value;
  final HabitCompletionType? habitCompletionType;

  bool get hasValue => value > 0;
}

class GoalProgressView {
  const GoalProgressView({
    required this.today,
    this.habits = const [],
    this.metric,
  });

  final DateTime today;
  final List<GoalHabitProgressView> habits;
  final GoalMetricProgressView? metric;

  /// The compact list-row picture. A composite routine is healthy on a day
  /// only when every watched habit succeeded; a single habit uses its own
  /// series. Metric goals report whether that day's value cleared the target.
  List<bool> get compactWindow {
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
    return [
      for (final day in activeDays)
        series.days.any(
          (entry) => entry.day == day && entry.value >= series.target,
        ),
    ];
  }
}

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
  return GoalProgressView(
    today: today,
    habits: habits,
    metric: metric == null
        ? null
        : GoalMetricProgressView(
            name: metric.title?.trim().isNotEmpty == true
                ? metric.title!.trim()
                : metric.dataType,
            target: metric.target,
            days: [
              for (final day in displayDays.skip(1))
                GoalProgressDay(
                  day: day,
                  value:
                      signals.quantitativeDailySums[metric.dataType]?[day] ?? 0,
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
