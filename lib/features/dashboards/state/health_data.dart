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
List<Observation> aggregateDailySum(List<JournalEntity> entities) {
  final sumsByDay = <String, num>{};

  for (final entity in entities) {
    final dayString = entity.meta.dateFrom.ymd;
    final n = sumsByDay[dayString] ?? 0;
    if (entity is QuantitativeEntry) {
      sumsByDay[dayString] = n + entity.data.value;
    }
  }

  final aggregated = <Observation>[];
  for (final dayString in sumsByDay.keys) {
    final day = DateTime.parse(dayString);
    // final midDay = day.add(const Duration(hours: 12));
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
      return transformToHours(aggregateDailySum(entities));
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
