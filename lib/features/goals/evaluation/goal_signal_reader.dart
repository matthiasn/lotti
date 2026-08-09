import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/config/dashboard_health_config.dart';
import 'package:lotti/features/dashboards/state/health_data.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';

/// Reads the journal into a [GoalSignalWindow] for one criteria tree —
/// the seam between the pure evaluator and the database (Phase A of
/// ADR 0054; the reader promised by the kickoff plan).
///
/// Semantics are deliberately borrowed, not reinvented:
///
/// - Quantitative day totals use the SAME per-type aggregation as the
///   health charts (`aggregateByType`): `cumulative_step_count` is a
///   running counter, so its day total is the day's max, not a sum.
///   Diverging here would make the goal agent disagree with the chart the
///   user is looking at.
/// - Habit days use the SAME latest-completion-per-day collapse as the
///   habits UI (`getHabitCompletionsByHabitId`), and only
///   [HabitCompletionType.success] counts toward a quota.
/// - Day keys re-stamp the LOCAL wall-clock date as midnight UTC
///   ([GoalWindow.dayUtc] over `meta.dateFrom`), matching the `ymd`
///   bucketing of `habits_controller` — a calendar-date key, not a
///   timezone conversion.
class GoalSignalReader {
  const GoalSignalReader({required this._journalDb});

  final JournalDb _journalDb;

  /// Loads every signal series the [criteria] tree needs to be evaluated
  /// at [reference], covering the widest leaf window plus the short-term
  /// trend lookback.
  Future<GoalSignalWindow> read({
    required GoalCriterion criteria,
    required DateTime reference,
    int shortTermDays = 3,
  }) async {
    final needs = _SignalNeeds()..collect(criteria);
    final rangeStart = _rangeStart(criteria, reference, shortTermDays);
    // End of the reference day in local time: `date_to <= rangeEnd` must
    // include entries recorded later today.
    final rangeEnd = DateTime(
      reference.year,
      reference.month,
      reference.day,
    ).add(const Duration(days: 1));

    final quantitative = <String, Map<DateTime, num>>{};
    for (final dataType in needs.quantitativeTypes) {
      final entities = await _journalDb.getQuantitativeByType(
        type: dataType,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
      final byDay = <DateTime, num>{};
      // aggregateByType returns [] for types absent from healthTypes —
      // that would silently evaluate real data as a tracker gap, so
      // unknown types fall back to a plain daily sum.
      final observations = healthTypes.containsKey(dataType)
          ? aggregateByType(entities, dataType)
          : aggregateDailySum(entities);
      for (final observation in observations) {
        byDay[GoalWindow.dayUtc(observation.dateTime)] = observation.value;
      }
      quantitative[dataType] = byDay;
    }

    final habits = <String, Map<DateTime, int>>{};
    for (final habitId in needs.habitIds) {
      final entities = await _journalDb.getHabitCompletionsByHabitId(
        habitId: habitId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
      final byDay = <DateTime, int>{};
      for (final entity in entities) {
        entity.maybeMap(
          habitCompletion: (completion) {
            // The query already collapsed to the latest completion per
            // day (the habits-UI rule); only success feeds a quota.
            if (completion.data.completionType == HabitCompletionType.success) {
              byDay[GoalWindow.dayUtc(completion.data.dateFrom)] = 1;
            }
          },
          orElse: () {},
        );
      }
      habits[habitId] = byDay;
    }

    final measurables = <String, Map<DateTime, num>>{};
    for (final dataTypeId in needs.measurableTypeIds) {
      final entities = await _journalDb.getMeasurementsByType(
        type: dataTypeId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
      final byDay = <DateTime, num>{};
      for (final entity in entities) {
        entity.maybeMap(
          measurement: (measurement) {
            final day = GoalWindow.dayUtc(measurement.data.dateFrom);
            byDay[day] = (byDay[day] ?? 0) + measurement.data.value;
          },
          orElse: () {},
        );
      }
      measurables[dataTypeId] = byDay;
    }

    return GoalSignalWindow(
      quantitativeDailySums: quantitative,
      habitSuccessesByDay: habits,
      measurableDailySums: measurables,
    );
  }

  /// Earliest day any leaf's period (or the short-term lookback, or the
  /// grace-period prior window) reaches back to, as a local date.
  DateTime _rangeStart(
    GoalCriterion criteria,
    DateTime reference,
    int shortTermDays,
  ) {
    var earliest = GoalWindow.dayUtc(
      reference,
    ).subtract(Duration(days: shortTermDays - 1));
    void visit(GoalCriterion criterion) {
      switch (criterion) {
        case GoalCriterionMetric(:final window) ||
            GoalCriterionMeasurable(:final window) ||
            GoalCriterionHabit(:final window):
          // One extra period back so the policy's prior-attainment grace
          // check can be computed from the same window.
          final start = window.periodRange(reference).start;
          final length = window.lengthInDays(reference);
          final withPrior = start.subtract(Duration(days: length));
          if (withPrior.isBefore(earliest)) earliest = withPrior;
        case GoalCriterionAllOf(:final criteria) ||
            GoalCriterionAnyOf(:final criteria) ||
            GoalCriterionAtLeastCount(:final criteria):
          criteria.forEach(visit);
      }
    }

    visit(criteria);
    // Back to local wall-clock for the DB range query.
    return DateTime(earliest.year, earliest.month, earliest.day);
  }
}

/// The notification tokens a goal's criteria tree subscribes to: leaf
/// `dataType` strings (quantitative entries notify with their dataType),
/// `habitId`s (habit completions notify with their habitId) and
/// measurable `dataTypeId`s (measurements notify with theirs).
Set<String> goalSignalTriggerTokens(GoalCriterion criteria) {
  final needs = _SignalNeeds()..collect(criteria);
  return {
    ...needs.quantitativeTypes,
    ...needs.habitIds,
    ...needs.measurableTypeIds,
  };
}

class _SignalNeeds {
  final quantitativeTypes = <String>{};
  final habitIds = <String>{};
  final measurableTypeIds = <String>{};

  void collect(GoalCriterion criterion) {
    switch (criterion) {
      case GoalCriterionMetric(:final dataType):
        quantitativeTypes.add(dataType);
      case GoalCriterionHabit(:final habitId):
        habitIds.add(habitId);
      case GoalCriterionMeasurable(:final dataTypeId):
        measurableTypeIds.add(dataTypeId);
      case GoalCriterionAllOf(:final criteria) ||
          GoalCriterionAnyOf(:final criteria) ||
          GoalCriterionAtLeastCount(:final criteria):
        criteria.forEach(collect);
    }
  }
}
