import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:lotti/services/health_service.dart';
import 'package:mocktail/mocktail.dart';

class MockHealth extends Mock implements Health {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HealthService Tests', () {
    late MockHealth mockHealth;
    late HealthService healthService;

    setUp(() {
      mockHealth = MockHealth();
      healthService = HealthService(mockHealth);
    });

    test('requestAuthorization delegates to Health package', () async {
      final types = [HealthDataType.STEPS, HealthDataType.HEART_RATE];
      final permissions = [HealthDataAccess.READ, HealthDataAccess.READ];

      when(() =>
              mockHealth.requestAuthorization(types, permissions: permissions))
          .thenAnswer((_) async => true);

      final result = await healthService.requestAuthorization(
        types,
        permissions: permissions,
      );

      expect(result, true);
      verify(() =>
              mockHealth.requestAuthorization(types, permissions: permissions))
          .called(1);
    });

    test('requestAuthorization without permissions', () async {
      final types = [HealthDataType.STEPS];

      when(() => mockHealth.requestAuthorization(types))
          .thenAnswer((_) async => false);

      final result = await healthService.requestAuthorization(types);

      expect(result, false);
      verify(() => mockHealth.requestAuthorization(types))
          .called(1);
    });

    test('getTotalStepsInInterval returns step count', () async {
      final startTime = DateTime(2025);
      final endTime = DateTime(2025, 1, 1, 23, 59);
      const expectedSteps = 10000;

      when(() => mockHealth.getTotalStepsInInterval(startTime, endTime))
          .thenAnswer((_) async => expectedSteps);

      final result =
          await healthService.getTotalStepsInInterval(startTime, endTime);

      expect(result, expectedSteps);
      verify(() => mockHealth.getTotalStepsInInterval(startTime, endTime))
          .called(1);
    });

    test('getTotalStepsInInterval returns null when no data', () async {
      final startTime = DateTime(2025);
      final endTime = DateTime(2025, 1, 1, 23, 59);

      when(() => mockHealth.getTotalStepsInInterval(startTime, endTime))
          .thenAnswer((_) async => null);

      final result =
          await healthService.getTotalStepsInInterval(startTime, endTime);

      expect(result, isNull);
    });

    test('getHealthDataFromTypes returns health data points', () async {
      final startTime = DateTime(2025);
      final endTime = DateTime(2025, 1, 1, 23, 59);
      final types = [HealthDataType.STEPS, HealthDataType.HEART_RATE];

      final mockDataPoints = <HealthDataPoint>[
        HealthDataPoint(
          uuid: 'test-uuid',
          value: NumericHealthValue(numericValue: 100),
          type: HealthDataType.STEPS,
          unit: HealthDataUnit.COUNT,
          dateFrom: startTime,
          dateTo: endTime,
          sourcePlatform: HealthPlatformType.googleHealthConnect,
          sourceDeviceId: 'test-device',
          sourceId: 'test-source',
          sourceName: 'test-app',
          recordingMethod: RecordingMethod.automatic,
        ),
      ];

      when(
        () => mockHealth.getHealthDataFromTypes(
          startTime: startTime,
          endTime: endTime,
          types: types,
        ),
      ).thenAnswer((_) async => mockDataPoints);

      final result = await healthService.getHealthDataFromTypes(
        startTime: startTime,
        endTime: endTime,
        types: types,
      );

      expect(result, mockDataPoints);
      expect(result.length, 1);
      expect(result.first.type, HealthDataType.STEPS);
      verify(
        () => mockHealth.getHealthDataFromTypes(
          startTime: startTime,
          endTime: endTime,
          types: types,
        ),
      ).called(1);
    });

    test('getHealthDataFromTypes returns empty list when no data', () async {
      final startTime = DateTime(2025);
      final endTime = DateTime(2025, 1, 1, 23, 59);
      final types = [HealthDataType.STEPS];

      when(
        () => mockHealth.getHealthDataFromTypes(
          startTime: startTime,
          endTime: endTime,
          types: types,
        ),
      ).thenAnswer((_) async => []);

      final result = await healthService.getHealthDataFromTypes(
        startTime: startTime,
        endTime: endTime,
        types: types,
      );

      expect(result, isEmpty);
    });
  });
}
