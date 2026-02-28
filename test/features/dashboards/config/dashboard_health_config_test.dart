import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/dashboards/config/dashboard_health_config.dart';

void main() {
  group('healthTypes', () {
    test('contains expected health type keys', () {
      expect(healthTypes, contains('HealthDataType.WEIGHT'));
      expect(healthTypes, contains('HealthDataType.RESTING_HEART_RATE'));
      expect(healthTypes, contains('cumulative_step_count'));
      expect(healthTypes, contains('HealthDataType.SLEEP_ASLEEP'));
      expect(healthTypes, contains('BLOOD_PRESSURE'));
      expect(healthTypes, contains('BODY_MASS_INDEX'));
    });

    test('WEIGHT has correct configuration', () {
      final weight = healthTypes['HealthDataType.WEIGHT']!;
      expect(weight.displayName, 'Weight');
      expect(weight.chartType, HealthChartType.lineChart);
      expect(weight.aggregationType, HealthAggregationType.none);
      expect(weight.unit, 'kg');
      expect(weight.colorByValue, isNull);
    });

    test('cumulative_step_count uses dailyMax with color thresholds', () {
      final steps = healthTypes['cumulative_step_count']!;
      expect(steps.displayName, 'Steps');
      expect(steps.chartType, HealthChartType.barChart);
      expect(steps.aggregationType, HealthAggregationType.dailyMax);
      expect(steps.unit, 'steps');
      expect(steps.colorByValue, isNotNull);
      expect(steps.colorByValue!.keys, containsAll([0, 6000, 10000]));
    });

    test('BLOOD_PRESSURE uses bpChart type', () {
      final bp = healthTypes['BLOOD_PRESSURE']!;
      expect(bp.chartType, HealthChartType.bpChart);
      expect(bp.aggregationType, HealthAggregationType.none);
    });

    test('BODY_MASS_INDEX uses bmiChart type', () {
      final bmi = healthTypes['BODY_MASS_INDEX']!;
      expect(bmi.chartType, HealthChartType.bmiChart);
    });

    test('sleep types use dailyTimeSum aggregation', () {
      final sleepTypes = [
        'HealthDataType.SLEEP_ASLEEP',
        'HealthDataType.SLEEP_LIGHT',
        'HealthDataType.SLEEP_DEEP',
        'HealthDataType.SLEEP_REM',
        'HealthDataType.SLEEP_IN_BED',
        'HealthDataType.SLEEP_AWAKE',
      ];

      for (final type in sleepTypes) {
        final config = healthTypes[type]!;
        expect(
          config.aggregationType,
          HealthAggregationType.dailyTimeSum,
          reason: '$type should use dailyTimeSum',
        );
        expect(
          config.chartType,
          HealthChartType.barChart,
          reason: '$type should use barChart',
        );
        expect(config.unit, 'h', reason: '$type should use hours');
      }
    });

    test('heart rate types use lineChart with none aggregation', () {
      final hrTypes = [
        'HealthDataType.RESTING_HEART_RATE',
        'HealthDataType.WALKING_HEART_RATE',
        'HealthDataType.HEART_RATE_VARIABILITY_SDNN',
      ];

      for (final type in hrTypes) {
        final config = healthTypes[type]!;
        expect(
          config.chartType,
          HealthChartType.lineChart,
          reason: '$type should use lineChart',
        );
        expect(
          config.aggregationType,
          HealthAggregationType.none,
          reason: '$type should use none aggregation',
        );
      }
    });
  });
}
