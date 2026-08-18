import 'dart:core';
import 'dart:math';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/dashboards/config/dashboard_health_config.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// One observation per quantitative sample, unaggregated. Percentage types
/// (health type contains `PERCENTAGE`) are scaled ×100 so e.g. body-fat plots
/// as `18` rather than `0.18`. Non-quantitative entities are ignored.
List<Observation> aggregateNone(
  List<JournalEntity> entities,
  String healthType,
) {
  final aggregated = <Observation>[];
  final multiplier = healthType.contains('PERCENTAGE') ? 100 : 1;

  for (final entity in entities) {
    entity.maybeMap(
      quantitative: (QuantitativeEntry quant) {
        aggregated.add(
          Observation(
            quant.data.dateFrom,
            quant.data.value * multiplier,
          ),
        );
      },
      orElse: () {},
    );
  }

  return aggregated;
}

/// One observation per calendar day carrying that day's maximum sample value
/// (dated at local midnight). Used for cumulative metrics whose stored value
/// already grows over the day, so the day's last/peak reading is its total
/// (e.g. step and distance counters).
List<Observation> aggregateDailyMax(List<JournalEntity> entities) {
  final maxByDay = <String, num>{};
  for (final entity in entities) {
    final dayString = entity.meta.dateFrom.ymd;
    final n = maxByDay[dayString] ?? 0;
    if (entity is QuantitativeEntry) {
      maxByDay[dayString] = max(n, entity.data.value);
    }
  }

  final aggregated = <Observation>[];
  for (final dayString in maxByDay.keys) {
    final day = DateTime.parse(dayString);
    aggregated.add(Observation(day, maxByDay[dayString] ?? 0));
  }

  return aggregated;
}

/// One observation per calendar day carrying the sum of that day's sample
/// values (dated at local midnight). Days with no samples produce no
/// observation.
///
/// A sample belongs to the day it **starts**. For a metric accumulated while
/// awake that is simply the day it happened; for sleep it is the wrong
/// question, which is what [aggregateDailySumByEndDay] exists to answer.
List<Observation> aggregateDailySum(List<JournalEntity> entities) =>
    _aggregateDailySumBy(entities, (entity) => entity.meta.dateFrom);

/// As [aggregateDailySum], but a sample belongs to the day it **ends**.
///
/// This is the sleep rule, and it exists because a night crosses midnight.
/// Keyed on the start day, a bed time of 23:12 puts the first 48 minutes on one
/// date and the remaining seven hours on the next, so no bar is ever one
/// night: each is the tail of the night before plus the head of the night
/// after. Worse, while the user is awake today's bar holds only the
/// post-midnight portion, so "last night" reads short by however long they were
/// asleep before midnight — every day, all day.
///
/// Keying on the end day attributes a night to the morning it ended, which is
/// the convention Apple Health uses and the one that matches the question a
/// sleep chart is read to answer. Daytime samples are unaffected: a nap that
/// starts and ends the same afternoon lands on that afternoon either way.
List<Observation> aggregateDailySumByEndDay(List<JournalEntity> entities) =>
    _aggregateDailySumBy(entities, (entity) => entity.meta.dateTo);

List<Observation> _aggregateDailySumBy(
  List<JournalEntity> entities,
  DateTime Function(JournalEntity) dayOf,
) {
  final sumsByDay = <String, num>{};

  for (final entity in entities) {
    if (entity is! QuantitativeEntry) {
      continue;
    }
    final dayString = dayOf(entity).ymd;
    sumsByDay[dayString] = (sumsByDay[dayString] ?? 0) + entity.data.value;
  }

  final aggregated = <Observation>[];
  for (final dayString in sumsByDay.keys) {
    final day = DateTime.parse(dayString);
    aggregated.add(Observation(day, sumsByDay[dayString] ?? 0));
  }

  return aggregated;
}

/// Rescales each observation's value from minutes to hours (value / 60).
/// Applied after a daily sum for time-based metrics such as sleep stages so the
/// axis reads in hours.
List<Observation> transformToHours(List<Observation> observations) {
  final observationsInHours = <Observation>[];
  for (final obs in observations) {
    observationsInHours.add(Observation(obs.dateTime, obs.value / 60));
  }

  return observationsInHours;
}

/// Reduces raw health entities to chart observations using the
/// `HealthAggregationType` configured for `dataType` in `healthTypes`:
/// none → per-sample, dailyMax, dailySum, or dailyTimeSum (daily sum then
/// minutes→hours). An unknown `dataType` yields an empty list.
List<Observation> aggregateByType(
  List<JournalEntity> entities,
  String dataType,
) {
  final config = healthTypes[dataType];

  switch (config?.aggregationType) {
    case HealthAggregationType.none:
      return aggregateNone(entities, dataType);
    case HealthAggregationType.dailyMax:
      return aggregateDailyMax(entities);
    case HealthAggregationType.dailySum:
      return aggregateDailySum(entities);
    case HealthAggregationType.dailyTimeSum:
      // `dailyTimeSum` is configured for the six sleep types and nothing else
      // (see `healthTypes`), so this is the sleep path: attribute a night to
      // the day it ended rather than splitting it across midnight.
      return transformToHours(aggregateDailySumByEndDay(entities));
    case null:
      return [];
  }
}

/// Folds [observations] with [extremeFn] (e.g. `min`/`max`) over their values,
/// returning `0.0` for an empty list. Backs [findMin]/[findMax].
num findExtreme(
  List<Observation> observations,
  num Function(num, num) extremeFn,
) {
  if (observations.isEmpty) {
    return 0.0;
  }

  var val = observations.first.value;

  for (final observation in observations) {
    val = extremeFn(val, observation.value);
  }

  return val;
}

/// Smallest observation value, or `0.0` if empty (used for the weight range
/// readout on the BMI/weight card).
num findMin(List<Observation> observations) {
  return findExtreme(observations, min);
}

/// Largest observation value, or `0.0` if empty (used for the weight range
/// readout on the BMI/weight card).
num findMax(List<Observation> observations) {
  return findExtreme(observations, max);
}
