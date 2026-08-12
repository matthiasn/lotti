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
import 'package:lotti/features/goals/state/goal_measurable_capture_state.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;

enum GoalDimensionKind { habit, health, measurable, categoryTime }

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
  });

  final String habitId;
  final String criterionId;
  final String name;
  final String? sourceCaption;
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
      successesInWindow == targetCount &&
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
    this.criterionId = '',
    this.sourceId = '',
    this.kind = GoalDimensionKind.health,
    this.unitName,
    this.dailyTimeRange,
    this.agentRecordedDays = const {},
    this.agentRecordedProvenanceByDay = const {},
    this.categoryTimeSessions = const [],
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
    this.compositeRule,
    this.requiredSuccesses,
  }) : metrics = metric == null ? metrics : [metric, ...metrics];

  final DateTime today;
  final List<GoalHabitProgressView> habits;
  final List<GoalMetricProgressView> metrics;
  final List<bool>? compositeCompactWindow;
  final GoalCompositeRuleKind? compositeRule;
  final int? requiredSuccesses;

  int get dimensionCount => habits.length + metrics.length;

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
  GoalCriterionMetric() ||
  GoalCriterionMeasurable() ||
  GoalCriterionCategoryTime() =>
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
  Map<String, MeasurableDataType> measurableDefinitions = const {},
  Map<String, String> categoryNames = const {},
  Set<String> agentRecordedMeasurementIds = const {},
  Map<String, GoalRecordedMeasurementProvenance>
      recordedMeasurementProvenanceById =
      const {},
}) {
  final today = GoalWindow.dayUtc(reference);
  final habitLeaves = <GoalCriterionHabit>[];
  final metricLeaves = <GoalCriterionMetric>[];
  final measurableLeaves = <GoalCriterionMeasurable>[];
  final categoryTimeLeaves = <GoalCriterionCategoryTime>[];

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
          definition: measurableDefinitions[measurable.dataTypeId],
          agentRecordedMeasurementIds: agentRecordedMeasurementIds,
          recordedMeasurementProvenanceById: recordedMeasurementProvenanceById,
        ),
      for (final categoryTime in categoryTimeLeaves)
        _categoryTimeProgressView(
          categoryTime: categoryTime,
          signals: signals,
          reference: reference,
          categoryName: categoryNames[categoryTime.categoryId],
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
    dailyValues: signals.quantitativeDailySums[metric.dataType],
    signals: signals,
    reference: reference,
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
    agentRecordedDays: agentRecordedDays,
    agentRecordedProvenanceByDay: provenanceByDay,
  );
}

GoalMetricProgressView _categoryTimeProgressView({
  required GoalCriterionCategoryTime categoryTime,
  required GoalSignalWindow signals,
  required DateTime reference,
  String? categoryName,
}) => _numericProgressView(
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
  zeroIsObserved: true,
);

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
}) {
  final range = window.periodRange(reference);
  final today = GoalWindow.dayUtc(reference);
  return GoalMetricProgressView(
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
    days: [
      for (
        var day = range.start;
        !day.isAfter(range.end);
        day = day.add(const Duration(days: 1))
      )
        GoalProgressDay(
          day: day,
          value: dailyValues?[day] ?? 0,
          isObserved:
              (dailyValues?.containsKey(day) ?? false) ||
              (zeroIsObserved && !day.isAfter(today)),
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
          case GoalCriterionMetric() ||
              GoalCriterionMeasurable() ||
              GoalCriterionCategoryTime():
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
      for (final habitId in habitIds) {
        final habit = await db.getHabitById(habitId);
        if (habit != null) names[habitId] = habit.name;
      }
      final measurableIds = <String>{};
      final categoryIds = <String>{};
      void collectDefinitions(GoalCriterion criterion) {
        switch (criterion) {
          case GoalCriterionMeasurable(:final dataTypeId):
            measurableIds.add(dataTypeId);
          case GoalCriterionCategoryTime(:final categoryId):
            categoryIds.add(categoryId);
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
        habitNames: names,
        measurableDefinitions: measurableDefinitions,
        categoryNames: categoryNames,
        agentRecordedMeasurementIds: agentRecordedMeasurementIds,
        recordedMeasurementProvenanceById: recordedMeasurementProvenanceById,
      );
    }, name: 'goalAgentProgressViewProvider');
