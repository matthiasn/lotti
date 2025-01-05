import 'dart:core';
import 'dart:math';
import 'dart:ui';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_config.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/charts/utils.dart';

Color colorByValueAndType(
  Observation observation,
  HealthTypeConfig? healthTypeConfig,
) {
  final color = colorFromCssHex('#82E6CE');

  if (healthTypeConfig == null) {
    return color;
  }

  if (healthTypeConfig.colorByValue != null) {
    final colorByValue = healthTypeConfig.colorByValue;
    final sortedThresholds = colorByValue!.keys.toList()..sort();

    final aboveThreshold = sortedThresholds.reversed.firstWhere(
      (threshold) => observation.value >= threshold,
      orElse: () => 0,
    );

    return colorFromCssHex(colorByValue[aboveThreshold] ?? '#000000');
  }

  return color;
}

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

List<Observation> transformToHours(List<Observation> observations) {
  final observationsInHours = <Observation>[];
  for (final obs in observations) {
    observationsInHours.add(Observation(obs.dateTime, obs.value / 60));
  }

  return observationsInHours;
}

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

List<Observation> aggregateNoneFilteredBy(
  List<JournalEntity> entities,
  String healthType,
) {
  return aggregateNone(
    entities.where((entity) {
      if (entity is QuantitativeEntry) {
        return entity.data.dataType == healthType;
      } else {
        return false;
      }
    }).toList(),
    healthType,
  );
}

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

num findMin(List<Observation> observations) {
  return findExtreme(observations, min);
}

num findMax(List<Observation> observations) {
  return findExtreme(observations, max);
}

bool nearRange({
  required num min,
  required num max,
  required num lowerBound,
  required num upperBound,
}) {
  const threshold = 2;
  final minNearLower = (lowerBound - min).abs() < threshold;
  final minNearUpper = (upperBound - min).abs() < threshold;
  final maxNearLower = (lowerBound - max).abs() < threshold;
  final maxNearUpper = (upperBound - max).abs() < threshold;
  return minNearLower || minNearUpper || maxNearLower || maxNearUpper;
}
