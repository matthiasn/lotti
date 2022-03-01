import 'dart:core';
import 'dart:math';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:charts_flutter/flutter.dart';
import 'package:equatable/equatable.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/widgets/charts/dashboard_health_config.dart';
import 'package:lotti/widgets/charts/utils.dart';

Color colorByValue(
  Observation observation,
  HealthTypeConfig? healthTypeConfig,
) {
  Color color = charts.MaterialPalette.blue.shadeDefault;

  if (healthTypeConfig == null) {
    return color;
  }

  if (healthTypeConfig.colorByValue != null) {
    Map<num, String>? colorByValue = healthTypeConfig.colorByValue;
    List<num> sortedThresholds = colorByValue!.keys.toList();
    sortedThresholds.sort();

    num aboveThreshold = sortedThresholds.reversed.firstWhere(
        (threshold) => observation.value >= threshold,
        orElse: () => 0);

    HexColor color = HexColor(colorByValue[aboveThreshold] ?? '#000000');
    return charts.Color(r: color.red, g: color.green, b: color.blue);
  }

  return color;
}

class Observation extends Equatable {
  final DateTime dateTime;
  final num value;

  const Observation(this.dateTime, this.value);

  @override
  String toString() {
    return '$dateTime $value';
  }

  @override
  List<Object?> get props => [dateTime, value];
}

List<Observation> aggregateNone(List<JournalEntity?> entities) {
  List<Observation> aggregated = [];

  for (JournalEntity? entity in entities) {
    entity?.maybeMap(
      quantitative: (QuantitativeEntry quant) {
        aggregated.add(Observation(
          quant.data.dateFrom,
          quant.data.value,
        ));
      },
      orElse: () {},
    );
  }

  return aggregated;
}

List<Observation> aggregateDailyMax(List<JournalEntity?> entities) {
  Map<String, num> maxByDay = {};
  for (final entity in entities) {
    String dayString = ymd(entity!.meta.dateFrom);
    num n = maxByDay[dayString] ?? 0;
    if (entity is QuantitativeEntry) {
      maxByDay[dayString] = max(n, entity.data.value);
    }
  }

  List<Observation> aggregated = [];
  for (final dayString in maxByDay.keys) {
    DateTime day = DateTime.parse(dayString);
    aggregated.add(Observation(day, maxByDay[dayString] ?? 0));
  }

  return aggregated;
}

List<Observation> aggregateDailySum(List<JournalEntity?> entities) {
  Map<String, num> sumsByDay = {};

  for (final entity in entities) {
    String dayString = ymd(entity!.meta.dateFrom);
    num n = sumsByDay[dayString] ?? 0;
    if (entity is QuantitativeEntry) {
      sumsByDay[dayString] = n + entity.data.value;
    }
  }

  List<Observation> aggregated = [];
  for (final dayString in sumsByDay.keys) {
    DateTime day = DateTime.parse(dayString);
    aggregated.add(Observation(day, sumsByDay[dayString] ?? 0));
  }

  return aggregated;
}

List<Observation> transformToHours(List<Observation> observations) {
  List<Observation> observationsInHours = [];
  for (final obs in observations) {
    observationsInHours.add(Observation(obs.dateTime, obs.value / 60));
  }

  return observationsInHours;
}

List<Observation> aggregateByType(
  List<JournalEntity?> entities,
  String dataType,
) {
  HealthTypeConfig? config = healthTypes[dataType];

  switch (config?.aggregationType) {
    case HealthAggregationType.none:
      return aggregateNone(entities);
    case HealthAggregationType.dailyMax:
      return aggregateDailyMax(entities);
    case HealthAggregationType.dailySum:
      return aggregateDailySum(entities);
    case HealthAggregationType.dailyTimeSum:
      return transformToHours(aggregateDailySum(entities));
    default:
      return [];
  }
}

List<Observation> aggregateNoneFilteredBy(
  List<JournalEntity?> entities,
  String healthType,
) {
  return aggregateNone(entities.where((entity) {
    if (entity is QuantitativeEntry) {
      return entity.data.dataType == healthType;
    } else {
      return false;
    }
  }).toList());
}

num findExtreme(
  List<Observation> observations,
  num Function(num, num) extremeFn,
) {
  num val = observations.first.value;

  for (Observation observation in observations) {
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
