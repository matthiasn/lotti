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
    // Next local calendar midnight, by component construction: adding a
    // 24h Duration lands at 23:00 on a DST fall-back day and would drop
    // the final hour's entries from `date_to <= rangeEnd`.
    final rangeEnd = DateTime(
      reference.year,
      reference.month,
      reference.day + 1,
    );

    final quantitative = <String, Map<DateTime, num>>{};
    for (final dataType in needs.quantitativeTypes) {
      final entities = await _journalDb.getQuantitativeByType(
        type: dataType,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
      quantitative[dataType] = _bucketQuantitative(entities, dataType);
    }

    final habits = <String, Map<DateTime, int>>{};
    final habitCompletions = <String, Map<DateTime, HabitCompletionType>>{};
    for (final habitId in needs.habitIds) {
      final entities = await _journalDb.getHabitCompletionsByHabitId(
        habitId: habitId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
      final byDay = <DateTime, int>{};
      final completionsByDay = <DateTime, HabitCompletionType>{};
      for (final entity in entities) {
        entity.maybeMap(
          habitCompletion: (completion) {
            // The query already collapsed to the latest completion per
            // day (the habits-UI rule); only success feeds a quota.
            final completionType = completion.data.completionType;
            final day = GoalWindow.dayUtc(completion.data.dateFrom);
            if (completionType != null) {
              completionsByDay[day] = completionType;
            }
            if (completionType == HabitCompletionType.success) {
              byDay[day] = 1;
            }
          },
          orElse: () {},
        );
      }
      habits[habitId] = byDay;
      habitCompletions[habitId] = completionsByDay;
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
      habitCompletionsByDay: habitCompletions,
      measurableDailySums: measurables,
    );
  }

  /// One deterministic value per day, honoring the health config's
  /// per-type aggregation:
  ///
  /// - `dailyMax` (cumulative counters like steps): the day's peak;
  /// - `dailySum` / `dailyTimeSum`: the day's total (hours for time);
  /// - `none` (point samples like weight or heart rate): the day's LATEST
  ///   sample — `aggregateNone` returns every raw sample, and folding
  ///   those into a day-keyed map would keep whichever the query order
  ///   put last (the oldest, since results are newest-first);
  /// - unknown types: a daily sum, never silence.
  Map<DateTime, num> _bucketQuantitative(
    List<JournalEntity> entities,
    String dataType,
  ) {
    final byDay = <DateTime, num>{};
    switch (healthTypes[dataType]?.aggregationType) {
      case HealthAggregationType.none:
        // Same display normalization as `aggregateNone`: percentage types
        // store fractions (body fat 0.18) but chart — and target — as 18.
        final multiplier = dataType.contains('PERCENTAGE') ? 100 : 1;
        final latestByDay = <DateTime, ({DateTime from, String id})>{};
        for (final entity in entities) {
          entity.maybeMap(
            quantitative: (quant) {
              final day = GoalWindow.dayUtc(quant.data.dateFrom);
              final current = latestByDay[day];
              // Identical timestamps are broken by entity id: the query
              // orders by date_from only, so relying on return order
              // would let replicas pick different daily values from the
              // same journal and diverge their registers.
              final wins =
                  current == null ||
                  quant.data.dateFrom.isAfter(current.from) ||
                  (quant.data.dateFrom.isAtSameMomentAs(current.from) &&
                      quant.meta.id.compareTo(current.id) > 0);
              if (wins) {
                latestByDay[day] = (
                  from: quant.data.dateFrom,
                  id: quant.meta.id,
                );
                byDay[day] = quant.data.value * multiplier;
              }
            },
            orElse: () {},
          );
        }
      case HealthAggregationType.dailyMax:
      case HealthAggregationType.dailySum:
      case HealthAggregationType.dailyTimeSum:
        for (final observation in aggregateByType(entities, dataType)) {
          byDay[GoalWindow.dayUtc(observation.dateTime)] = observation.value;
        }
      case null:
        for (final observation in aggregateDailySum(entities)) {
          byDay[GoalWindow.dayUtc(observation.dateTime)] = observation.value;
        }
    }
    return byDay;
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
