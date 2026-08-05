import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:lotti/services/health_service.dart';
import 'package:mocktail/mocktail.dart';

class MockHealth extends Mock implements Health {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHealth mockHealth;
  late HealthService healthService;

  setUp(() {
    mockHealth = MockHealth();
    healthService = HealthService(mockHealth);
    when(() => mockHealth.configure()).thenAnswer((_) async {});
  });

  HealthDataPoint stepsPoint(DateTime startTime, DateTime endTime) =>
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
      );

  group('delegation', () {
    test('requestAuthorization passes types and permissions through', () async {
      final types = [HealthDataType.STEPS, HealthDataType.HEART_RATE];
      final permissions = [HealthDataAccess.READ, HealthDataAccess.READ];

      when(
        () => mockHealth.requestAuthorization(types, permissions: permissions),
      ).thenAnswer((_) async => true);

      final result = await healthService.requestAuthorization(
        types,
        permissions: permissions,
      );

      expect(result, true);
      verify(
        () => mockHealth.requestAuthorization(types, permissions: permissions),
      ).called(1);
    });

    test(
      'requestAuthorization without permissions relays the refusal',
      () async {
        final types = [HealthDataType.STEPS];

        when(
          () => mockHealth.requestAuthorization(types),
        ).thenAnswer((_) async => false);

        expect(await healthService.requestAuthorization(types), false);
        verify(() => mockHealth.requestAuthorization(types)).called(1);
      },
    );

    test('hasPermissions passes types and permissions through', () async {
      final types = [HealthDataType.STEPS];
      final permissions = [HealthDataAccess.READ];

      when(
        () => mockHealth.hasPermissions(types, permissions: permissions),
      ).thenAnswer((_) async => true);

      expect(
        await healthService.hasPermissions(types, permissions: permissions),
        isTrue,
      );
      verify(
        () => mockHealth.hasPermissions(types, permissions: permissions),
      ).called(1);
    });

    test('hasPermissions relays a definitive refusal', () async {
      when(
        () => mockHealth.hasPermissions(any()),
      ).thenAnswer((_) async => false);

      expect(
        await healthService.hasPermissions([HealthDataType.STEPS]),
        isFalse,
      );
    });

    test('hasPermissions relays the undisclosed answer as null', () async {
      // HealthKit's answer for a READ query — Apple will not say. Collapsing it
      // to `false` here would make every iOS import look permanently denied.
      when(
        () => mockHealth.hasPermissions(any()),
      ).thenAnswer((_) async => null);

      expect(
        await healthService.hasPermissions([HealthDataType.STEPS]),
        isNull,
      );
    });

    test('getTotalStepsInInterval relays the count', () async {
      final startTime = DateTime(2025);
      final endTime = DateTime(2025, 1, 1, 23, 59);

      when(
        () => mockHealth.getTotalStepsInInterval(startTime, endTime),
      ).thenAnswer((_) async => 10000);

      expect(
        await healthService.getTotalStepsInInterval(startTime, endTime),
        10000,
      );
      verify(
        () => mockHealth.getTotalStepsInInterval(startTime, endTime),
      ).called(1);
    });

    test('getTotalStepsInInterval relays a null count', () async {
      final startTime = DateTime(2025);
      final endTime = DateTime(2025, 1, 1, 23, 59);

      when(
        () => mockHealth.getTotalStepsInInterval(startTime, endTime),
      ).thenAnswer((_) async => null);

      expect(
        await healthService.getTotalStepsInInterval(startTime, endTime),
        isNull,
      );
    });

    test('getHealthDataFromTypes relays the data points', () async {
      final startTime = DateTime(2025);
      final endTime = DateTime(2025, 1, 1, 23, 59);
      final types = [HealthDataType.STEPS, HealthDataType.HEART_RATE];
      final dataPoints = [stepsPoint(startTime, endTime)];

      when(
        () => mockHealth.getHealthDataFromTypes(
          startTime: startTime,
          endTime: endTime,
          types: types,
        ),
      ).thenAnswer((_) async => dataPoints);

      final result = await healthService.getHealthDataFromTypes(
        startTime: startTime,
        endTime: endTime,
        types: types,
      );

      expect(result, dataPoints);
      expect(result.single.type, HealthDataType.STEPS);
    });

    test('getHealthDataFromTypes relays an empty result', () async {
      final startTime = DateTime(2025);
      final endTime = DateTime(2025, 1, 1, 23, 59);

      when(
        () => mockHealth.getHealthDataFromTypes(
          startTime: startTime,
          endTime: endTime,
          types: [HealthDataType.STEPS],
        ),
      ).thenAnswer((_) async => []);

      expect(
        await healthService.getHealthDataFromTypes(
          startTime: startTime,
          endTime: endTime,
          types: [HealthDataType.STEPS],
        ),
        isEmpty,
      );
    });
  });

  group('configure handshake', () {
    // The health plugin documents configure() as mandatory before any other
    // call, and it is what populates the plugin's cached device id. Nothing
    // called it before this seam took ownership of it.
    test('every read method configures the plugin first', () async {
      final start = DateTime(2025);
      final end = DateTime(2025, 1, 2);

      when(
        () => mockHealth.requestAuthorization(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockHealth.getTotalStepsInInterval(any(), any()),
      ).thenAnswer((_) async => 1);
      when(
        () => mockHealth.getHealthDataFromTypes(
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
          types: any(named: 'types'),
        ),
      ).thenAnswer((_) async => []);

      // Each entry point on its own service, so each one has to do the
      // handshake itself rather than riding on a sibling's.
      when(
        () => mockHealth.hasPermissions(any()),
      ).thenAnswer((_) async => null);

      await HealthService(mockHealth).requestAuthorization([
        HealthDataType.STEPS,
      ]);
      verify(() => mockHealth.configure()).called(1);

      await HealthService(mockHealth).hasPermissions([HealthDataType.STEPS]);
      verify(() => mockHealth.configure()).called(1);

      await HealthService(mockHealth).getTotalStepsInInterval(start, end);
      verify(() => mockHealth.configure()).called(1);

      await HealthService(mockHealth).getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.STEPS],
      );
      verify(() => mockHealth.configure()).called(1);
    });

    test('configures once per service, not once per call', () async {
      when(
        () => mockHealth.requestAuthorization(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockHealth.getTotalStepsInInterval(any(), any()),
      ).thenAnswer((_) async => 0);

      await healthService.requestAuthorization([HealthDataType.STEPS]);
      await healthService.requestAuthorization([HealthDataType.WEIGHT]);
      await healthService.getTotalStepsInInterval(
        DateTime(2025),
        DateTime(2025, 1, 2),
      );

      verify(() => mockHealth.configure()).called(1);
    });

    test('concurrent first calls share a single configure', () async {
      when(
        () => mockHealth.requestAuthorization(any()),
      ).thenAnswer((_) async => true);

      await Future.wait([
        healthService.requestAuthorization([HealthDataType.STEPS]),
        healthService.requestAuthorization([HealthDataType.WEIGHT]),
        healthService.requestAuthorization([HealthDataType.HEART_RATE]),
      ]);

      verify(() => mockHealth.configure()).called(1);
    });

    test('a failed configure propagates and is not cached', () async {
      // Caching a rejected future would poison every later call with a
      // transient error — e.g. a device-info channel that was not ready yet.
      var attempts = 0;
      when(() => mockHealth.configure()).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) {
          throw StateError('device info not ready');
        }
      });
      when(
        () => mockHealth.requestAuthorization(any()),
      ).thenAnswer((_) async => true);

      await expectLater(
        healthService.requestAuthorization([HealthDataType.STEPS]),
        throwsStateError,
      );
      // The plugin call is not attempted when the handshake failed.
      verifyNever(() => mockHealth.requestAuthorization(any()));

      // The retry re-runs configure and then succeeds.
      expect(
        await healthService.requestAuthorization([HealthDataType.STEPS]),
        isTrue,
      );
      expect(attempts, 2);
      verify(() => mockHealth.requestAuthorization(any())).called(1);
    });
  });
}
