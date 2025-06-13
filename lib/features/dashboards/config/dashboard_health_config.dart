import 'dart:core';

enum HealthChartType {
  lineChart,
  barChart,
  bpChart,
  bmiChart,
}

enum HealthAggregationType {
  none,
  dailySum,
  dailyMax,
  dailyTimeSum,
}

class HealthTypeConfig {
  HealthTypeConfig({
    required this.displayName,
    required this.healthType,
    required this.chartType,
    required this.aggregationType,
    required this.unit,
    this.colorByValue,
    this.hoursMinutes = false,
  });

  final HealthChartType chartType;
  final HealthAggregationType aggregationType;
  final String displayName;
  final String healthType;
  final String unit;
  final Map<num, String>? colorByValue;
  final bool hoursMinutes;
}

Map<String, HealthTypeConfig> healthTypes = {
  'HealthDataType.WEIGHT': HealthTypeConfig(
    displayName: 'Weight',
    healthType: 'HealthDataType.WEIGHT',
    chartType: HealthChartType.lineChart,
    aggregationType: HealthAggregationType.none,
    unit: 'kg',
  ),
  'HealthDataType.BODY_FAT_PERCENTAGE': HealthTypeConfig(
    displayName: 'Body Fat Percentage',
    healthType: 'HealthDataType.BODY_FAT_PERCENTAGE',
    chartType: HealthChartType.lineChart,
    aggregationType: HealthAggregationType.none,
    unit: '%',
  ),
  'HealthDataType.BODY_MASS_INDEX': HealthTypeConfig(
    displayName: 'Body Mass Index',
    healthType: 'HealthDataType.BODY_MASS_INDEX',
    chartType: HealthChartType.lineChart,
    aggregationType: HealthAggregationType.none,
    unit: '',
  ),
  'BODY_MASS_INDEX': HealthTypeConfig(
    displayName: 'Weight vs. Body Mass Index',
    healthType: 'BODY_MASS_INDEX',
    chartType: HealthChartType.bmiChart,
    aggregationType: HealthAggregationType.none,
    unit: '',
  ),
  'HealthDataType.RESTING_HEART_RATE': HealthTypeConfig(
    displayName: 'Resting Heart Rate',
    healthType: 'HealthDataType.RESTING_HEART_RATE',
    chartType: HealthChartType.lineChart,
    aggregationType: HealthAggregationType.none,
    unit: 'bpm',
  ),
  'HealthDataType.WALKING_HEART_RATE': HealthTypeConfig(
    displayName: 'Walking Heart Rate',
    healthType: 'HealthDataType.WALKING_HEART_RATE',
    chartType: HealthChartType.lineChart,
    aggregationType: HealthAggregationType.none,
    unit: 'bpm',
  ),
  'HealthDataType.HEART_RATE_VARIABILITY_SDNN': HealthTypeConfig(
    displayName: 'Heart Rate Variability',
    healthType: 'HealthDataType.HEART_RATE_VARIABILITY_SDNN',
    chartType: HealthChartType.lineChart,
    aggregationType: HealthAggregationType.none,
    unit: 'ms',
  ),
  'HealthDataType.BLOOD_PRESSURE_SYSTOLIC': HealthTypeConfig(
    displayName: 'Systolic Blood Pressure',
    healthType: 'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
    chartType: HealthChartType.lineChart,
    aggregationType: HealthAggregationType.none,
    unit: 'mmHg',
  ),
  'HealthDataType.BLOOD_PRESSURE_DIASTOLIC': HealthTypeConfig(
    displayName: 'Diastolic Blood Pressure',
    healthType: 'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
    chartType: HealthChartType.lineChart,
    aggregationType: HealthAggregationType.none,
    unit: 'mmHg',
  ),
  'BLOOD_PRESSURE': HealthTypeConfig(
    displayName: 'Blood Pressure',
    healthType: 'BLOOD_PRESSURE',
    chartType: HealthChartType.bpChart,
    aggregationType: HealthAggregationType.none,
    unit: 'mmHg',
  ),
  'cumulative_step_count': HealthTypeConfig(
    displayName: 'Steps',
    healthType: 'cumulative_step_count',
    chartType: HealthChartType.barChart,
    aggregationType: HealthAggregationType.dailyMax,
    unit: 'steps',
    colorByValue: {
      10000: '#82E6CE',
      6000: '#C4ECE2',
      0: '#FF9595',
    },
  ),
  'cumulative_distance': HealthTypeConfig(
    displayName: 'Distance/m',
    healthType: 'cumulative_distance',
    chartType: HealthChartType.barChart,
    aggregationType: HealthAggregationType.dailyMax,
    unit: 'm',
  ),
  'cumulative_flights_climbed': HealthTypeConfig(
    displayName: 'Flights of stairs',
    healthType: 'cumulative_flights_climbed',
    chartType: HealthChartType.barChart,
    aggregationType: HealthAggregationType.dailyMax,
    unit: '',
  ),
  'HealthDataType.SLEEP_ASLEEP': HealthTypeConfig(
    displayName: 'Asleep',
    healthType: 'HealthDataType.SLEEP_ASLEEP',
    chartType: HealthChartType.barChart,
    aggregationType: HealthAggregationType.dailyTimeSum,
    hoursMinutes: true,
    unit: 'h',
  ),
  'HealthDataType.SLEEP_LIGHT': HealthTypeConfig(
    displayName: 'Asleep - light',
    healthType: 'HealthDataType.SLEEP_LIGHT',
    chartType: HealthChartType.barChart,
    aggregationType: HealthAggregationType.dailyTimeSum,
    hoursMinutes: true,
    unit: 'h',
  ),
  'HealthDataType.SLEEP_DEEP': HealthTypeConfig(
    displayName: 'Asleep - deep',
    healthType: 'HealthDataType.SLEEP_DEEP',
    chartType: HealthChartType.barChart,
    aggregationType: HealthAggregationType.dailyTimeSum,
    hoursMinutes: true,
    unit: 'h',
  ),
  'HealthDataType.SLEEP_REM': HealthTypeConfig(
    displayName: 'Asleep - REM',
    healthType: 'HealthDataType.SLEEP_REM',
    chartType: HealthChartType.barChart,
    aggregationType: HealthAggregationType.dailyTimeSum,
    hoursMinutes: true,
    unit: 'h',
  ),
  'HealthDataType.SLEEP_IN_BED': HealthTypeConfig(
    displayName: 'In bed',
    healthType: 'HealthDataType.SLEEP_IN_BED',
    chartType: HealthChartType.barChart,
    aggregationType: HealthAggregationType.dailyTimeSum,
    hoursMinutes: true,
    unit: 'h',
  ),
  'HealthDataType.SLEEP_AWAKE': HealthTypeConfig(
    displayName: 'Awake in bed',
    healthType: 'HealthDataType.SLEEP_AWAKE',
    chartType: HealthChartType.barChart,
    aggregationType: HealthAggregationType.dailyTimeSum,
    hoursMinutes: true,
    unit: 'h',
  ),
};
