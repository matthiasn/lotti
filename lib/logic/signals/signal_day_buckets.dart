/// Pure day-bucketing of journal signal entities, shared by goals and habits.
///
/// Day keys are the entity's LOCAL calendar date re-stamped as midnight UTC
/// ([GoalWindow.dayUtc]) — a calendar-date key, not a timezone conversion —
/// which is what keeps window arithmetic immune to DST by construction.
///
/// These functions carry no feature knowledge: they neither import goals nor
/// habits, so both can depend on them without depending on each other.
library;

import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/dashboards/config/dashboard_health_config.dart';
import 'package:lotti/features/dashboards/state/health_data.dart';

/// Calendar-date key of [instant]: its local date as midnight UTC.
DateTime signalDayKey(DateTime instant) => GoalWindow.dayUtc(instant);

/// The mean of the recorded daily values in the trailing [days]-day window
/// ending on [day]. Missing days are gaps, not zeroes; an entirely empty
/// window has no average.
///
/// This is the shared primitive behind the goal detail's seven-day reading and
/// habit signal evaluation, so the chart-adjacent value and auto-completion do
/// not disagree about sparse data.
num? trailingAverageOn(
  Map<DateTime, num> valuesByDay, {
  required DateTime day,
  int days = DateTime.daysPerWeek,
}) {
  assert(days > 0, 'a trailing average covers at least one day');
  final target = signalDayKey(day);
  final start = target.subtract(Duration(days: days - 1));
  num sum = 0;
  var count = 0;
  for (final entry in valuesByDay.entries) {
    final key = signalDayKey(entry.key);
    if (key.isBefore(start) || key.isAfter(target)) continue;
    sum += entry.value;
    count++;
  }
  return count == 0 ? null : sum / count;
}

/// One deterministic value per day for a quantitative (health) data type,
/// honouring the health config's per-type aggregation so a signal never
/// disagrees with the chart the user is looking at:
///
/// - `dailyMax` (cumulative counters like steps): the day's peak;
/// - `dailySum` / `dailyTimeSum`: the day's total (hours for time);
/// - `none` (point samples like weight or heart rate): the day's LATEST
///   sample — `aggregateNone` returns every raw sample, and folding those
///   into a day-keyed map would keep whichever the query order put last;
/// - unknown types: a daily sum, never silence.
Map<DateTime, num> bucketQuantitativeByDay(
  List<JournalEntity> entities,
  String dataType,
) {
  final byDay = <DateTime, num>{};
  switch (healthTypes[dataType]?.aggregationType) {
    case HealthAggregationType.none:
      final multiplier = quantitativeDisplayMultiplier(dataType);
      final latestByDay = <DateTime, ({DateTime from, String id})>{};
      for (final entity in entities) {
        entity.maybeMap(
          quantitative: (quant) {
            final day = signalDayKey(quant.data.dateFrom);
            final current = latestByDay[day];
            // Identical timestamps are broken by entity id: the query orders
            // by date_from only, so relying on return order would let
            // replicas pick different daily values from the same journal.
            final wins =
                current == null ||
                quant.data.dateFrom.isAfter(current.from) ||
                (quant.data.dateFrom.isAtSameMomentAs(current.from) &&
                    quant.meta.id.compareTo(current.id) > 0);
            if (wins) {
              latestByDay[day] = (from: quant.data.dateFrom, id: quant.meta.id);
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
        byDay[signalDayKey(observation.dateTime)] = observation.value;
      }
    case null:
      for (final observation in aggregateDailySum(entities)) {
        byDay[signalDayKey(observation.dateTime)] = observation.value;
      }
  }
  return byDay;
}

/// Matches health aggregation display units: stored percentage fractions
/// become whole percentages, every other type keeps its native unit.
num quantitativeDisplayMultiplier(String dataType) =>
    dataType.contains('PERCENTAGE') ? 100 : 1;

/// Sum of measurement values per day. A day with an entry is present in the
/// result even when its total is zero, which is how "any entry" rules tell a
/// recorded zero apart from nothing recorded.
Map<DateTime, num> bucketMeasurableTotalsByDay(List<JournalEntity> entities) {
  final byDay = <DateTime, num>{};
  for (final entity in entities) {
    entity.maybeMap(
      measurement: (measurement) {
        final day = signalDayKey(measurement.data.dateFrom);
        byDay[day] = (byDay[day] ?? 0) + measurement.data.value;
      },
      orElse: () {},
    );
  }
  return byDay;
}

/// Workouts grouped by the calendar day they started, keeping the entities
/// so duration, distance and energy thresholds can be applied later.
Map<DateTime, List<WorkoutData>> bucketWorkoutsByDay(
  List<JournalEntity> entities,
) {
  final byDay = <DateTime, List<WorkoutData>>{};
  for (final entity in entities) {
    entity.maybeMap(
      workout: (workout) {
        byDay
            .putIfAbsent(signalDayKey(workout.data.dateFrom), () => [])
            .add(
              workout.data,
            );
      },
      orElse: () {},
    );
  }
  return byDay;
}

/// The value a workout contributes for [valueType], in the units the UI
/// shows: minutes, kilometres (stored metres ÷ 1000) or kcal. Missing
/// distance or energy contributes nothing rather than failing the day.
num workoutSignalValue(WorkoutData workout, WorkoutValueType valueType) =>
    switch (valueType) {
      WorkoutValueType.duration =>
        workout.dateTo.difference(workout.dateFrom).inSeconds / 60,
      WorkoutValueType.distance => (workout.distance ?? 0) / 1000,
      WorkoutValueType.energy => workout.energy ?? 0,
    };

/// Days on which the latest completion per day was a success. [entities]
/// must already be collapsed to one completion per day (the habits-UI rule
/// implemented by the `getHabitCompletionsByHabitId` query).
Set<DateTime> habitSuccessDays(List<JournalEntity> entities) {
  final days = <DateTime>{};
  for (final entity in entities) {
    entity.maybeMap(
      habitCompletion: (completion) {
        if (completion.data.completionType == HabitCompletionType.success) {
          days.add(signalDayKey(completion.data.dateFrom));
        }
      },
      orElse: () {},
    );
  }
  return days;
}
