import 'dart:core';
import 'dart:math';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:charts_flutter/flutter.dart';
import 'package:equatable/equatable.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/widgets/charts/utils.dart';

enum HealthChartType {
  lineChart,
  barChart,
  bpChart,
}

enum HealthAggregationType {
  none,
  dailySum,
  dailyMax,
}

class HealthTypeConfig {
  final HealthChartType chartType;
  final HealthAggregationType aggregationType;
  final String displayName;
  final String healthType;
  final Map<num, String>? colorByValue;

  HealthTypeConfig({
    required this.displayName,
    required this.healthType,
    required this.chartType,
    required this.aggregationType,
    this.colorByValue,
  });
}

Map<String, HealthTypeConfig> healthTypes = {
  'HealthDataType.WEIGHT': HealthTypeConfig(
    displayName: 'Weight',
    healthType: 'HealthDataType.WEIGHT',
    chartType: HealthChartType.lineChart,
    aggregationType: HealthAggregationType.none,
  ),
  'HealthDataType.RESTING_HEART_RATE': HealthTypeConfig(
    displayName: 'Resting Heart Rate',
    healthType: 'HealthDataType.RESTING_HEART_RATE',
    chartType: HealthChartType.lineChart,
    aggregationType: HealthAggregationType.none,
  ),
  'HealthDataType.HEART_RATE_VARIABILITY_SDNN': HealthTypeConfig(
    displayName: 'Heart Rate Variability',
    healthType: 'HealthDataType.HEART_RATE_VARIABILITY_SDNN',
    chartType: HealthChartType.lineChart,
    aggregationType: HealthAggregationType.none,
  ),
  'HealthDataType.BLOOD_PRESSURE_SYSTOLIC': HealthTypeConfig(
    displayName: 'Systolic Blood Pressure',
    healthType: 'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
    chartType: HealthChartType.lineChart,
    aggregationType: HealthAggregationType.none,
  ),
  'HealthDataType.BLOOD_PRESSURE_DIASTOLIC': HealthTypeConfig(
    displayName: 'Diastolic Blood Pressure',
    healthType: 'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
    chartType: HealthChartType.lineChart,
    aggregationType: HealthAggregationType.none,
  ),
  'BLOOD_PRESSURE': HealthTypeConfig(
    displayName: 'Blood Pressure',
    healthType: 'BLOOD_PRESSURE',
    chartType: HealthChartType.bpChart,
    aggregationType: HealthAggregationType.none,
  ),
  'cumulative_step_count': HealthTypeConfig(
      displayName: 'Steps',
      healthType: 'cumulative_step_count',
      chartType: HealthChartType.barChart,
      aggregationType: HealthAggregationType.dailyMax,
      colorByValue: {
        10000: '#4BB543',
        6000: '#FF5F1F',
        0: '#FC100D',
      }),
  'cumulative_flights_climbed': HealthTypeConfig(
    displayName: 'Flights of stairs',
    healthType: 'cumulative_flights_climbed',
    chartType: HealthChartType.barChart,
    aggregationType: HealthAggregationType.dailyMax,
  ),
  'HealthDataType.WORKOUT': HealthTypeConfig(
    displayName: 'Workout time',
    healthType: 'HealthDataType.WORKOUT',
    chartType: HealthChartType.barChart,
    aggregationType: HealthAggregationType.dailySum,
  ),
};

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
