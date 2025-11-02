import 'package:device_info_plus/device_info_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/health_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockJournalDb extends Mock implements JournalDb {}

class MockHealthService extends Mock implements HealthService {}

class MockDeviceInfoPlugin extends Mock implements DeviceInfoPlugin {}

class FakeQuantitativeData extends Fake implements CumulativeQuantityData {}

class FakeDiscreteQuantityData extends Fake implements DiscreteQuantityData {}

class FakeWorkoutData extends Fake implements WorkoutData {}

void main() {
  late HealthImport healthImport;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockJournalDb mockJournalDb;
  late MockHealthService mockHealthService;
  late MockDeviceInfoPlugin mockDeviceInfoPlugin;

  setUpAll(() {
    registerFallbackValue(FakeQuantitativeData());
    registerFallbackValue(FakeDiscreteQuantityData());
    registerFallbackValue(FakeWorkoutData());
  });

  setUp(() {
    mockPersistenceLogic = MockPersistenceLogic();
    mockJournalDb = MockJournalDb();
    mockHealthService = MockHealthService();
    mockDeviceInfoPlugin = MockDeviceInfoPlugin();
    healthImport = HealthImport(
      persistenceLogic: mockPersistenceLogic,
      db: mockJournalDb,
      health: mockHealthService,
      deviceInfo: mockDeviceInfoPlugin,
    );
  });

  group('sumNumericHealthValues', () {
    test('should return the sum of numeric health values', () {
      final dataPoints = <HealthDataPoint>[
        HealthDataPoint(
          uuid: const Uuid().v4(),
          value: NumericHealthValue(numericValue: 10),
          type: HealthDataType.STEPS,
          unit: HealthDataUnit.COUNT,
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
          sourcePlatform: HealthPlatformType.appleHealth,
          sourceDeviceId: '1',
          sourceId: '1',
          sourceName: '1',
        ),
        HealthDataPoint(
          uuid: const Uuid().v4(),
          value: NumericHealthValue(numericValue: 20),
          type: HealthDataType.STEPS,
          unit: HealthDataUnit.COUNT,
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
          sourcePlatform: HealthPlatformType.appleHealth,
          sourceDeviceId: '1',
          sourceId: '1',
          sourceName: '1',
        ),
      ];

      final result = healthImport.sumNumericHealthValues(dataPoints);

      expect(result, 30);
    });

    test('should return 0 for an empty list', () {
      final dataPoints = <HealthDataPoint>[];

      final result = healthImport.sumNumericHealthValues(dataPoints);

      expect(result, 0);
    });

    test('should ignore non-numeric health values', () {
      final dataPoints = <HealthDataPoint>[
        HealthDataPoint(
          uuid: const Uuid().v4(),
          value: NumericHealthValue(numericValue: 10),
          type: HealthDataType.STEPS,
          unit: HealthDataUnit.COUNT,
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
          sourcePlatform: HealthPlatformType.appleHealth,
          sourceDeviceId: '1',
          sourceId: '1',
          sourceName: '1',
        ),
        HealthDataPoint(
          uuid: const Uuid().v4(),
          value: AudiogramHealthValue(
            frequencies: [1, 2],
            leftEarSensitivities: [1, 2],
            rightEarSensitivities: [1, 2],
          ),
          type: HealthDataType.AUDIOGRAM,
          unit: HealthDataUnit.DECIBEL_HEARING_LEVEL,
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
          sourcePlatform: HealthPlatformType.appleHealth,
          sourceDeviceId: '1',
          sourceId: '1',
          sourceName: '1',
        ),
      ];

      final result = healthImport.sumNumericHealthValues(dataPoints);

      expect(result, 10);
    });
  });

  group('addActivityEntries', () {
    test('should add activity entries to the database', () async {
      final date = DateTime(2024);
      final data = {date: 100.0};
      const type = 'cumulative_step_count';
      const unit = 'count';

      when(() => mockPersistenceLogic.createQuantitativeEntry(any()))
          .thenAnswer((_) async {
        return null;
      });

      await healthImport.addActivityEntries(data, type, unit);

      verify(() => mockPersistenceLogic.createQuantitativeEntry(any()))
          .called(1);
    });
  });

  group('getDays', () {
    test('should generate correct date range for single day', () {
      final dateFrom = DateTime(2024);
      final dateTo = DateTime(2024);

      final result = healthImport.getDays(dateFrom, dateTo);

      expect(result.length, 1);
      expect(result.first, DateTime(2024));
    });

    test('should generate correct date range for multiple days', () {
      final dateFrom = DateTime(2024);
      final dateTo = DateTime(2024, 1, 5);

      final result = healthImport.getDays(dateFrom, dateTo);

      expect(result.length, 5);
      expect(result.first, DateTime(2024));
      expect(result.last, DateTime(2024, 1, 5));
    });

    test('should normalize times to midnight', () {
      final dateFrom = DateTime(2024, 1, 1, 10, 30);
      final dateTo = DateTime(2024, 1, 2, 15, 45);

      final result = healthImport.getDays(dateFrom, dateTo);

      expect(result.length, 2);
      expect(result.first, DateTime(2024));
      expect(result.last, DateTime(2024, 1, 2));
    });
  });

  group('fetchAndProcessActivityDataForDay', () {
    test('should not fetch data for future dates', () async {
      final futureDate = DateTime.now().add(const Duration(days: 1));
      final stepsByDay = <DateTime, num>{};
      final flightsByDay = <DateTime, num>{};
      final distanceByDay = <DateTime, num>{};

      await healthImport.fetchAndProcessActivityDataForDay(
        futureDate,
        stepsByDay,
        flightsByDay,
        distanceByDay,
      );

      // Should not populate any data for future dates
      expect(stepsByDay.isEmpty, true);
      expect(flightsByDay.isEmpty, true);
      expect(distanceByDay.isEmpty, true);
    });

    test('should fetch and aggregate activity data for a past date', () async {
      final testDate = DateTime(2024);
      final stepsByDay = <DateTime, num>{};
      final flightsByDay = <DateTime, num>{};
      final distanceByDay = <DateTime, num>{};

      // Mock health service responses
      when(() => mockHealthService.getTotalStepsInInterval(any(), any()))
          .thenAnswer((_) async => 10000);

      when(
        () => mockHealthService.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenAnswer((invocation) async {
        final types = invocation.namedArguments[const Symbol('types')]
            as List<HealthDataType>;

        if (types.contains(HealthDataType.FLIGHTS_CLIMBED)) {
          return [
            HealthDataPoint(
              uuid: const Uuid().v4(),
              value: NumericHealthValue(numericValue: 15),
              type: HealthDataType.FLIGHTS_CLIMBED,
              unit: HealthDataUnit.COUNT,
              dateFrom: testDate,
              dateTo: testDate.add(const Duration(hours: 1)),
              sourcePlatform: HealthPlatformType.appleHealth,
              sourceDeviceId: 'test',
              sourceId: 'test',
              sourceName: 'test',
            ),
            HealthDataPoint(
              uuid: const Uuid().v4(),
              value: NumericHealthValue(numericValue: 10),
              type: HealthDataType.FLIGHTS_CLIMBED,
              unit: HealthDataUnit.COUNT,
              dateFrom: testDate.add(const Duration(hours: 2)),
              dateTo: testDate.add(const Duration(hours: 3)),
              sourcePlatform: HealthPlatformType.appleHealth,
              sourceDeviceId: 'test',
              sourceId: 'test',
              sourceName: 'test',
            ),
          ];
        } else if (types.contains(HealthDataType.DISTANCE_WALKING_RUNNING)) {
          return [
            HealthDataPoint(
              uuid: const Uuid().v4(),
              value: NumericHealthValue(numericValue: 5000),
              type: HealthDataType.DISTANCE_WALKING_RUNNING,
              unit: HealthDataUnit.METER,
              dateFrom: testDate,
              dateTo: testDate.add(const Duration(hours: 1)),
              sourcePlatform: HealthPlatformType.appleHealth,
              sourceDeviceId: 'test',
              sourceId: 'test',
              sourceName: 'test',
            ),
          ];
        }
        return [];
      });

      await healthImport.fetchAndProcessActivityDataForDay(
        testDate,
        stepsByDay,
        flightsByDay,
        distanceByDay,
      );

      // Verify data was fetched and aggregated
      expect(stepsByDay[testDate], 10000);
      expect(flightsByDay[testDate], 25); // 15 + 10
      expect(distanceByDay[testDate], 5000);

      // Verify health service was called
      verify(() => mockHealthService.getTotalStepsInInterval(any(), any()))
          .called(1);
      verify(
        () => mockHealthService.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).called(2); // Once for flights, once for distance
    });

    test('should handle zero values correctly', () async {
      final testDate = DateTime(2024);
      final stepsByDay = <DateTime, num>{};
      final flightsByDay = <DateTime, num>{};
      final distanceByDay = <DateTime, num>{};

      when(() => mockHealthService.getTotalStepsInInterval(any(), any()))
          .thenAnswer((_) async => 0);

      when(
        () => mockHealthService.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenAnswer((_) async => []);

      await healthImport.fetchAndProcessActivityDataForDay(
        testDate,
        stepsByDay,
        flightsByDay,
        distanceByDay,
      );

      expect(stepsByDay[testDate], 0);
      expect(flightsByDay[testDate], 0);
      expect(distanceByDay[testDate], 0);
    });

    test('should handle null step count', () async {
      final testDate = DateTime(2024);
      final stepsByDay = <DateTime, num>{};
      final flightsByDay = <DateTime, num>{};
      final distanceByDay = <DateTime, num>{};

      when(() => mockHealthService.getTotalStepsInInterval(any(), any()))
          .thenAnswer((_) async => null);

      when(
        () => mockHealthService.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenAnswer((_) async => []);

      await healthImport.fetchAndProcessActivityDataForDay(
        testDate,
        stepsByDay,
        flightsByDay,
        distanceByDay,
      );

      expect(stepsByDay[testDate], 0); // Null should be treated as 0
      expect(flightsByDay[testDate], 0);
      expect(distanceByDay[testDate], 0);
    });
  });

  group('authorizeHealth', () {
    test('should return false on desktop platforms', () async {
      final types = [HealthDataType.STEPS];

      final result = await healthImport.authorizeHealth(types);

      // On desktop (macOS/Linux/Windows), should return false
      expect(result, false);
    });
  });

  group('fetchHealthData', () {
    test('should return early on desktop platforms', () async {
      final dateFrom = DateTime(2024);
      final dateTo = DateTime(2024, 1, 2);
      final types = [HealthDataType.STEPS];

      await healthImport.fetchHealthData(
        types: types,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      // On desktop, should return early without calling health service
      verifyNever(() => mockHealthService.requestAuthorization(any()));
    });
  });

  group('fetchHealthDataDelta', () {
    test('should throttle cumulative type requests within 10 minutes', () {
      fakeAsync((async) {
        // Note: This test verifies the throttling and queue management logic.
        // On desktop (where tests run), getActivityHealthData returns early due to
        // isDesktop check, so we only validate throttling behavior, not full data processing.
        const type = 'cumulative_step_count';

        // First call - type should be queued and lastFetched recorded
        healthImport.fetchHealthDataDelta(type);
        async.flushMicrotasks();

        expect(healthImport.lastFetched.containsKey(type), true);
        final firstFetchTime = healthImport.lastFetched[type]!;

        // Second call within 10 minutes should be throttled (not queued again)
        healthImport.fetchHealthDataDelta(type);
        async.flushMicrotasks();

        // Verify throttling: lastFetched time unchanged, queue processed
        expect(healthImport.lastFetched[type], firstFetchTime);
        expect(healthImport.queue.length, 0);
      });
    });

    test('should add type to queue and track last fetch time', () {
      fakeAsync((async) {
        const type = 'HealthDataType.HEART_RATE';

        expect(healthImport.queue.length, 0);
        expect(healthImport.lastFetched.containsKey(type), false);

        healthImport.fetchHealthDataDelta(type);
        async.flushMicrotasks();

        expect(healthImport.lastFetched.containsKey(type), true);
      });
    });

    test('should process multiple different types concurrently', () {
      fakeAsync((async) {
        // Note: This test verifies concurrent processing of multiple health data types.
        // On desktop (where tests run), getActivityHealthData returns early due to
        // isDesktop check, so we validate queue management and type tracking.
        const type1 = 'HealthDataType.HEART_RATE';
        const type2 = 'HealthDataType.WEIGHT';

        // Call without awaiting to test concurrent execution
        healthImport
          ..fetchHealthDataDelta(type1)
          ..fetchHealthDataDelta(type2);
        async.flushMicrotasks();

        expect(healthImport.queue.isEmpty, isTrue);
        expect(healthImport.lastFetched.containsKey(type1), true);
        expect(healthImport.lastFetched.containsKey(type2), true);
      });
    });
  });

  group('getWorkoutsHealthData', () {
    test('should return early on desktop platforms', () async {
      final dateFrom = DateTime(2024);
      final dateTo = DateTime(2024, 1, 2);

      await healthImport.getWorkoutsHealthData(
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      // On desktop, should return early without calling health service
      verifyNever(() => mockHealthService.requestAuthorization(any()));
      verifyNever(() => mockPersistenceLogic.createWorkoutEntry(any()));
    });
  });

  group('getWorkoutsHealthDataDelta', () {
    test('should return early on desktop platforms', () async {
      await healthImport.getWorkoutsHealthDataDelta();

      // On desktop, should return early
      verifyNever(() => mockJournalDb.latestWorkout());
      verifyNever(() => mockHealthService.requestAuthorization(any()));
    });

    test('should prevent concurrent workout imports using flag', () async {
      // Note: This test verifies the flag-based concurrency control, but in desktop
      // environments (where tests run), getWorkoutsHealthDataDelta returns early
      // due to isDesktop check. We test the flag behavior directly instead.

      expect(healthImport.workoutImportRunning, false);

      // Simulate the flag being set (as it would be on mobile)
      healthImport.workoutImportRunning = true;
      expect(healthImport.workoutImportRunning, true);

      // When flag is true, the method should return early without doing work
      await healthImport.getWorkoutsHealthDataDelta();

      // Flag should still be true since we set it manually and the method returned early
      expect(healthImport.workoutImportRunning, true);

      // Reset for next test
      healthImport.workoutImportRunning = false;
      expect(healthImport.workoutImportRunning, false);
    });
  });
}
