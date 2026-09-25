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

/// Significant digits kept by [canonicalSignalValue].
const signalValueSignificantDigits = 12;

/// [value] rounded to [signalValueSignificantDigits] significant digits, the
/// form every aggregate takes before a success threshold is applied to it.
///
/// Binary doubles cannot hold the decimals people log: ten 0.1 l entries sum
/// to 0.9999999999999999, which misses "at least 1 l" by one bit, and the
/// same values summed in another order can land on a different last bit.
/// Rounding far below any precision a person enters, but far above the error
/// a few thousand additions accumulate, makes every decision agree with the
/// exact decimal arithmetic the user did in their head — and with every other
/// replica, whatever order it read the journal in. Integers and non-finite
/// values pass through unchanged.
num canonicalSignalValue(num value) {
  if (value is int || !value.isFinite || value == 0) return value;
  return double.parse(value.toStringAsPrecision(signalValueSignificantDigits));
}

/// Integer steps [canonicalSignalSum] adds in: billionths of a unit.
const _signalSumScale = 1000000000;

/// The canonical sum of [values], independent of their order.
///
/// Rounding a binary sum afterwards cannot undo cancellation: `0.1 + 0.2 -
/// 0.3` leaves `5.55e-17` in one order and `-2.78e-17` in another, and
/// `1e20 - 1e20 + 0.001` loses the thousandth in one order only — flipping an
/// "at most 0" or a balance verdict with the order rows came back in. So each
/// value is taken to whole billionths and added exactly as an integer; the
/// total depends only on which values there are, never on their order, and
/// becomes one double at the end. Amounts finer than a billionth of a unit are
/// below anything a person logs and are dropped. An all-integer sum stays an
/// integer; a non-finite value, or one too large to scale, makes the sum its
/// binary total.
num canonicalSignalSum(Iterable<num> values) {
  var exact = BigInt.zero;
  var integral = true;
  for (final value in values) {
    if (value is int) {
      exact += BigInt.from(value) * BigInt.from(_signalSumScale);
    } else {
      final scaled = value * _signalSumScale;
      if (!scaled.isFinite) return values.fold<num>(0, (sum, v) => sum + v);
      integral = false;
      exact += BigInt.from(scaled.roundToDouble());
    }
  }
  if (integral) return (exact ~/ BigInt.from(_signalSumScale)).toInt();
  return canonicalSignalValue(exact.toDouble() / _signalSumScale);
}

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
  final inWindow = [
    for (final entry in valuesByDay.entries)
      if (!signalDayKey(entry.key).isBefore(start) &&
          !signalDayKey(entry.key).isAfter(target))
        entry.value,
  ];
  if (inWindow.isEmpty) return null;
  return canonicalSignalValue(
    canonicalSignalSum(inWindow) / inWindow.length,
  );
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
/// recorded zero apart from nothing recorded. Totals are canonical sums
/// ([canonicalSignalSum]), so they do not depend on entry order.
Map<DateTime, num> bucketMeasurableTotalsByDay(List<JournalEntity> entities) {
  final byDay = <DateTime, List<num>>{};
  for (final entity in entities) {
    entity.maybeMap(
      measurement: (measurement) {
        byDay
            .putIfAbsent(signalDayKey(measurement.data.dateFrom), () => [])
            .add(measurement.data.value);
      },
      orElse: () {},
    );
  }
  return byDay.map((day, values) => MapEntry(day, canonicalSignalSum(values)));
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
