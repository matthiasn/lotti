import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:health/health.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler/permission_handler.dart';
// ignore: depend_on_referenced_packages
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart'
    show PermissionHandlerPlatform;
import 'package:uuid/uuid.dart';

import '../mocks/mocks.dart';

/// Fake [PermissionHandlerPlatform] that records every requested permission set
/// and grants them all, so the default [HealthImport] permission request path
/// can be exercised without the native plugin.
class _RecordingPermissionHandler extends PermissionHandlerPlatform {
  final List<List<Permission>> requestedPermissions = [];

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    requestedPermissions.add(permissions);
    return {
      for (final permission in permissions)
        permission: PermissionStatus.granted,
    };
  }
}

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

  /// Creates a [HealthImport] with [isDesktop] overridden to false and
  /// permissions bypassed. Restores platform flags via [addTearDown].
  HealthImport createMobileHealthImport() {
    final originalIsDesktop = platform.isDesktop;
    final originalIsMobile = platform.isMobile;
    platform.isDesktop = false;
    platform.isMobile = true;
    addTearDown(() {
      platform.isDesktop = originalIsDesktop;
      platform.isMobile = originalIsMobile;
    });

    return HealthImport(
      persistenceLogic: mockPersistenceLogic,
      db: mockJournalDb,
      health: mockHealthService,
      deviceInfo: mockDeviceInfoPlugin,
      requestPermissions: () async {},
    );
  }

  HealthDataPoint makeNumericDataPoint({
    required HealthDataType type,
    required num value,
    required DateTime dateFrom,
    required DateTime dateTo,
    HealthDataUnit unit = HealthDataUnit.COUNT,
    String sourceId = 'test-source',
    String sourceName = 'Test',
  }) {
    return HealthDataPoint(
      uuid: const Uuid().v4(),
      value: NumericHealthValue(numericValue: value),
      type: type,
      unit: unit,
      dateFrom: dateFrom,
      dateTo: dateTo,
      sourcePlatform: HealthPlatformType.appleHealth,
      sourceDeviceId: 'test-device',
      sourceId: sourceId,
      sourceName: sourceName,
    );
  }

  group('sumNumericHealthValues', () {
    test('should return the sum of numeric health values', () {
      final dataPoints = <HealthDataPoint>[
        makeNumericDataPoint(
          type: HealthDataType.STEPS,
          value: 10,
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
        ),
        makeNumericDataPoint(
          type: HealthDataType.STEPS,
          value: 20,
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
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
        makeNumericDataPoint(
          type: HealthDataType.STEPS,
          value: 10,
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025),
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

      when(
        () => mockPersistenceLogic.createQuantitativeEntry(any()),
      ).thenAnswer((_) async {
        return null;
      });

      await healthImport.addActivityEntries(data, type, unit);

      verify(
        () => mockPersistenceLogic.createQuantitativeEntry(any()),
      ).called(1);
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
      final futureDate = DateTime(2099);
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
      when(
        () => mockHealthService.getTotalStepsInInterval(any(), any()),
      ).thenAnswer((_) async => 10000);

      when(
        () => mockHealthService.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenAnswer((invocation) async {
        final types =
            invocation.namedArguments[const Symbol('types')]
                as List<HealthDataType>;

        if (types.contains(HealthDataType.FLIGHTS_CLIMBED)) {
          return [
            makeNumericDataPoint(
              type: HealthDataType.FLIGHTS_CLIMBED,
              value: 15,
              dateFrom: testDate,
              dateTo: testDate.add(const Duration(hours: 1)),
            ),
            makeNumericDataPoint(
              type: HealthDataType.FLIGHTS_CLIMBED,
              value: 10,
              dateFrom: testDate.add(const Duration(hours: 2)),
              dateTo: testDate.add(const Duration(hours: 3)),
            ),
          ];
        } else if (types.contains(HealthDataType.DISTANCE_WALKING_RUNNING)) {
          return [
            makeNumericDataPoint(
              type: HealthDataType.DISTANCE_WALKING_RUNNING,
              value: 5000,
              dateFrom: testDate,
              dateTo: testDate.add(const Duration(hours: 1)),
              unit: HealthDataUnit.METER,
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
      verify(
        () => mockHealthService.getTotalStepsInInterval(any(), any()),
      ).called(1);
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

      when(
        () => mockHealthService.getTotalStepsInInterval(any(), any()),
      ).thenAnswer((_) async => 0);

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

      when(
        () => mockHealthService.getTotalStepsInInterval(any(), any()),
      ).thenAnswer((_) async => null);

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

    test('should delegate to health service on mobile', () async {
      final mobileImport = createMobileHealthImport();

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => true);

      final result = await mobileImport.authorizeHealth(
        [HealthDataType.STEPS],
      );

      expect(result, true);
      verify(
        () => mockHealthService.requestAuthorization(
          [HealthDataType.STEPS],
        ),
      ).called(1);
    });

    test('should return false when health service denies auth', () async {
      final mobileImport = createMobileHealthImport();

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => false);

      final result = await mobileImport.authorizeHealth(
        [HealthDataType.HEART_RATE],
      );

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

    test('should return early when authorization is denied', () async {
      final mobileImport = createMobileHealthImport();

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => false);

      await mobileImport.fetchHealthData(
        types: [HealthDataType.HEART_RATE],
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024, 1, 2),
      );

      verify(
        () => mockHealthService.requestAuthorization(any()),
      ).called(1);
      verifyNever(
        () => mockHealthService.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      );
    });

    test('should process numeric health data points', () async {
      final mobileImport = createMobileHealthImport();
      final dateFrom = DateTime(2024, 3);
      final dateTo = DateTime(2024, 3, 1, 12);

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => true);

      when(
        () => mockHealthService.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenAnswer(
        (_) async => [
          makeNumericDataPoint(
            type: HealthDataType.HEART_RATE,
            value: 72,
            dateFrom: dateFrom,
            dateTo: dateTo,
            unit: HealthDataUnit.BEATS_PER_MINUTE,
          ),
        ],
      );

      when(
        () => mockPersistenceLogic.createQuantitativeEntry(any()),
      ).thenAnswer((_) async => null);

      await mobileImport.fetchHealthData(
        types: [HealthDataType.HEART_RATE],
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      final captured = verify(
        () => mockPersistenceLogic.createQuantitativeEntry(
          captureAny(),
        ),
      ).captured;

      expect(captured.length, 1);
      final data = captured.first as DiscreteQuantityData;
      expect(data.value, 72);
      expect(data.dataType, 'HealthDataType.HEART_RATE');
    });

    // Sleep-duplication invariant, parameterized over the full contract:
    // only SLEEP_DEEP and SLEEP_REM get an additional generic SLEEP_ASLEEP
    // copy (for comparability with pre-iOS-16 data). All other sleep stages
    // and non-sleep types must persist exactly one entry.
    //
    // Note: the impl's duplication set also lists SLEEP_ASLEEP_CORE and
    // SLEEP_ASLEEP_UNSPECIFIED, but those names do not exist in the current
    // health-package enum, so they are unreachable via dataPoint.type.
    const sleepDuplicationExpectations = <HealthDataType, bool>{
      HealthDataType.SLEEP_DEEP: true,
      HealthDataType.SLEEP_REM: true,
      HealthDataType.SLEEP_LIGHT: false,
      HealthDataType.SLEEP_IN_BED: false,
      HealthDataType.SLEEP_AWAKE: false,
      HealthDataType.SLEEP_ASLEEP: false,
      HealthDataType.WEIGHT: false,
    };

    for (final MapEntry(key: type, value: duplicates)
        in sleepDuplicationExpectations.entries) {
      test(
        duplicates
            ? 'duplicates $type as generic SLEEP_ASLEEP'
            : 'does NOT duplicate $type',
        () async {
          final mobileImport = createMobileHealthImport();
          final dateFrom = DateTime(2024, 3);
          final dateTo = DateTime(2024, 3, 1, 8);

          when(
            () => mockHealthService.requestAuthorization(any()),
          ).thenAnswer((_) async => true);
          when(
            () => mockHealthService.getHealthDataFromTypes(
              types: any(named: 'types'),
              startTime: any(named: 'startTime'),
              endTime: any(named: 'endTime'),
            ),
          ).thenAnswer(
            (_) async => [
              makeNumericDataPoint(
                type: type,
                value: 90,
                dateFrom: dateFrom,
                dateTo: dateTo,
                unit: HealthDataUnit.MINUTE,
              ),
            ],
          );
          when(
            () => mockPersistenceLogic.createQuantitativeEntry(any()),
          ).thenAnswer((_) async => null);

          await mobileImport.fetchHealthData(
            types: [type],
            dateFrom: dateFrom,
            dateTo: dateTo,
          );

          final captured = verify(
            () => mockPersistenceLogic.createQuantitativeEntry(captureAny()),
          ).captured.cast<DiscreteQuantityData>();

          expect(captured.first.dataType, type.toString());
          if (duplicates) {
            expect(captured.length, 2);
            expect(captured.last.dataType, 'HealthDataType.SLEEP_ASLEEP');
            // The duplicated entry preserves the original value.
            expect(captured.last.value, captured.first.value);
          } else {
            expect(captured.length, 1);
          }
        },
      );
    }

    test('should skip non-numeric health values', () async {
      final mobileImport = createMobileHealthImport();
      final dateFrom = DateTime(2024, 3);
      final dateTo = DateTime(2024, 3, 1, 12);

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => true);

      when(
        () => mockHealthService.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenAnswer(
        (_) async => [
          HealthDataPoint(
            uuid: const Uuid().v4(),
            value: AudiogramHealthValue(
              frequencies: [1000, 2000],
              leftEarSensitivities: [20, 30],
              rightEarSensitivities: [25, 35],
            ),
            type: HealthDataType.AUDIOGRAM,
            unit: HealthDataUnit.DECIBEL_HEARING_LEVEL,
            dateFrom: dateFrom,
            dateTo: dateTo,
            sourcePlatform: HealthPlatformType.appleHealth,
            sourceDeviceId: 'test',
            sourceId: 'test',
            sourceName: 'test',
          ),
        ],
      );

      await mobileImport.fetchHealthData(
        types: [HealthDataType.AUDIOGRAM],
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      // Should not create any entries for non-numeric values
      verifyNever(
        () => mockPersistenceLogic.createQuantitativeEntry(any()),
      );
    });

    test('should process multiple data points in reverse order', () async {
      final mobileImport = createMobileHealthImport();
      final date1 = DateTime(2024, 3, 1, 8);
      final date2 = DateTime(2024, 3, 1, 12);
      final date3 = DateTime(2024, 3, 1, 18);

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => true);

      when(
        () => mockHealthService.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenAnswer(
        (_) async => [
          makeNumericDataPoint(
            type: HealthDataType.HEART_RATE,
            value: 60,
            dateFrom: date1,
            dateTo: date1,
          ),
          makeNumericDataPoint(
            type: HealthDataType.HEART_RATE,
            value: 80,
            dateFrom: date2,
            dateTo: date2,
          ),
          makeNumericDataPoint(
            type: HealthDataType.HEART_RATE,
            value: 70,
            dateFrom: date3,
            dateTo: date3,
          ),
        ],
      );

      when(
        () => mockPersistenceLogic.createQuantitativeEntry(any()),
      ).thenAnswer((_) async => null);

      await mobileImport.fetchHealthData(
        types: [HealthDataType.HEART_RATE],
        dateFrom: date1,
        dateTo: date3,
      );

      final captured = verify(
        () => mockPersistenceLogic.createQuantitativeEntry(
          captureAny(),
        ),
      ).captured;

      // Processed in reversed order: date3, date2, date1
      expect(captured.length, 3);
      expect((captured[0] as DiscreteQuantityData).value, 70);
      expect((captured[1] as DiscreteQuantityData).value, 80);
      expect((captured[2] as DiscreteQuantityData).value, 60);
    });

    test('should catch and log exceptions', () async {
      final mobileImport = createMobileHealthImport();
      final mockDomainLogger = MockDomainLogger();

      await getIt.reset();
      getIt.registerSingleton<DomainLogger>(mockDomainLogger);
      addTearDown(getIt.reset);

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => true);

      when(
        () => mockHealthService.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenThrow(Exception('Health API error'));

      // Should not throw — error is caught and logged
      await mobileImport.fetchHealthData(
        types: [HealthDataType.HEART_RATE],
        dateFrom: DateTime(2024, 3),
        dateTo: DateTime(2024, 3, 1, 12),
      );

      verify(
        () => mockDomainLogger.error(
          LogDomain.health,
          any<Object>(),
          subDomain: 'fetchHealthData',
        ),
      ).called(1);
    });
  });

  group('fetchHealthDataDelta', () {
    test('should throttle cumulative type requests within 10 minutes', () {
      fakeAsync((async) {
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

    test('should not throttle non-cumulative types', () {
      fakeAsync((async) {
        const type = 'HealthDataType.HEART_RATE';

        healthImport.fetchHealthDataDelta(type);
        async.flushMicrotasks();

        final firstFetchTime = healthImport.lastFetched[type]!;

        // Second call - non-cumulative types are NOT throttled
        healthImport.fetchHealthDataDelta(type);
        async.flushMicrotasks();

        // lastFetched should be updated (not throttled)
        expect(
          healthImport.lastFetched[type]!.millisecondsSinceEpoch,
          greaterThanOrEqualTo(firstFetchTime.millisecondsSinceEpoch),
        );
      });
    });
  });

  group('_fetchHealthDataDelta - type mapping', () {
    test('should map BLOOD_PRESSURE to systolic and diastolic types', () {
      fakeAsync((async) {
        final mobileImport = createMobileHealthImport();

        when(
          () => mockJournalDb.latestQuantitativeByType(any()),
        ).thenAnswer((_) async => null);

        when(
          () => mockHealthService.requestAuthorization(any()),
        ).thenAnswer((_) async => true);

        when(
          () => mockHealthService.getHealthDataFromTypes(
            types: any(named: 'types'),
            startTime: any(named: 'startTime'),
            endTime: any(named: 'endTime'),
          ),
        ).thenAnswer((_) async => []);

        mobileImport.fetchHealthDataDelta('BLOOD_PRESSURE');
        async.flushMicrotasks();

        // Should look up latest by the first actual type (systolic)
        verify(
          () => mockJournalDb.latestQuantitativeByType(
            'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
          ),
        ).called(1);

        // Auth requested in _fetchHealthDataDelta AND again in fetchHealthData
        verify(
          () => mockHealthService.requestAuthorization(
            [
              HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
              HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
            ],
          ),
        ).called(2);
      });
    });

    test('should map BODY_MASS_INDEX to WEIGHT', () {
      fakeAsync((async) {
        final mobileImport = createMobileHealthImport();

        when(
          () => mockJournalDb.latestQuantitativeByType(any()),
        ).thenAnswer((_) async => null);

        when(
          () => mockHealthService.requestAuthorization(any()),
        ).thenAnswer((_) async => true);

        when(
          () => mockHealthService.getHealthDataFromTypes(
            types: any(named: 'types'),
            startTime: any(named: 'startTime'),
            endTime: any(named: 'endTime'),
          ),
        ).thenAnswer((_) async => []);

        mobileImport.fetchHealthDataDelta('BODY_MASS_INDEX');
        async.flushMicrotasks();

        verify(
          () => mockJournalDb.latestQuantitativeByType(
            'HealthDataType.WEIGHT',
          ),
        ).called(1);

        // Auth requested in _fetchHealthDataDelta AND again in fetchHealthData
        verify(
          () => mockHealthService.requestAuthorization(
            [HealthDataType.WEIGHT],
          ),
        ).called(2);
      });
    });

    test('should use latest entry dateFrom as fetch start', () {
      fakeAsync((async) {
        final mobileImport = createMobileHealthImport();
        final latestDate = DateTime(2024, 6, 15);

        final latestEntry = QuantitativeEntry(
          data: DiscreteQuantityData(
            dateFrom: latestDate,
            dateTo: latestDate,
            value: 72,
            dataType: 'HealthDataType.HEART_RATE',
            unit: 'BEATS_PER_MINUTE',
          ),
          meta: Metadata(
            id: 'test-id',
            createdAt: latestDate,
            updatedAt: latestDate,
            dateFrom: latestDate,
            dateTo: latestDate,
          ),
        );

        when(
          () => mockJournalDb.latestQuantitativeByType(any()),
        ).thenAnswer((_) async => latestEntry);

        when(
          () => mockHealthService.requestAuthorization(any()),
        ).thenAnswer((_) async => true);

        when(
          () => mockHealthService.getHealthDataFromTypes(
            types: any(named: 'types'),
            startTime: any(named: 'startTime'),
            endTime: any(named: 'endTime'),
          ),
        ).thenAnswer((_) async => []);

        mobileImport.fetchHealthDataDelta('HealthDataType.HEART_RATE');
        async.flushMicrotasks();

        // Should fetch from the latest entry's dateFrom
        verify(
          () => mockHealthService.getHealthDataFromTypes(
            types: [HealthDataType.HEART_RATE],
            startTime: latestDate,
            endTime: any(named: 'endTime'),
          ),
        ).called(1);
      });
    });

    test(
      'should use default fetch duration when no latest entry exists',
      () {
        fakeAsync((async) {
          final mobileImport = createMobileHealthImport();

          when(
            () => mockJournalDb.latestQuantitativeByType(any()),
          ).thenAnswer((_) async => null);

          when(
            () => mockHealthService.requestAuthorization(any()),
          ).thenAnswer((_) async => true);

          when(
            () => mockHealthService.getHealthDataFromTypes(
              types: any(named: 'types'),
              startTime: any(named: 'startTime'),
              endTime: any(named: 'endTime'),
            ),
          ).thenAnswer((_) async => []);

          mobileImport.fetchHealthDataDelta('HealthDataType.WEIGHT');
          async.flushMicrotasks();

          final captured = verify(
            () => mockHealthService.getHealthDataFromTypes(
              types: any(named: 'types'),
              startTime: captureAny(named: 'startTime'),
              endTime: any(named: 'endTime'),
            ),
          ).captured;

          final startTime = captured.first as DateTime;
          // fakeAsync controls clock.now() used by production code,
          // so we can assert exact equality.
          final expectedStart = clock.now().subtract(
            const Duration(days: 90),
          );
          expect(startTime, expectedStart);
        });
      },
    );

    test('should skip fetch when auth denied for non-cumulative type', () {
      fakeAsync((async) {
        final mobileImport = createMobileHealthImport();

        when(
          () => mockJournalDb.latestQuantitativeByType(any()),
        ).thenAnswer((_) async => null);

        when(
          () => mockHealthService.requestAuthorization(any()),
        ).thenAnswer((_) async => false);

        mobileImport.fetchHealthDataDelta('HealthDataType.HEART_RATE');
        async.flushMicrotasks();

        verifyNever(
          () => mockHealthService.getHealthDataFromTypes(
            types: any(named: 'types'),
            startTime: any(named: 'startTime'),
            endTime: any(named: 'endTime'),
          ),
        );
      });
    });

    test(
      'should call getActivityHealthData for cumulative types',
      () {
        fakeAsync((async) {
          final mobileImport = createMobileHealthImport();

          when(
            () => mockJournalDb.latestQuantitativeByType(any()),
          ).thenAnswer((_) async => null);

          // Auth for activity types (called by getActivityHealthData)
          when(
            () => mockHealthService.requestAuthorization(any()),
          ).thenAnswer((_) async => true);

          when(
            () => mockHealthService.getTotalStepsInInterval(any(), any()),
          ).thenAnswer((_) async => 0);

          when(
            () => mockHealthService.getHealthDataFromTypes(
              types: any(named: 'types'),
              startTime: any(named: 'startTime'),
              endTime: any(named: 'endTime'),
            ),
          ).thenAnswer((_) async => []);

          when(
            () => mockPersistenceLogic.createQuantitativeEntry(any()),
          ).thenAnswer((_) async => null);

          mobileImport.fetchHealthDataDelta('cumulative_step_count');
          async.flushMicrotasks();

          // Should have looked up latest for the cumulative type
          verify(
            () => mockJournalDb.latestQuantitativeByType(
              'cumulative_step_count',
            ),
          ).called(1);

          // Should have called getActivityHealthData which requests
          // activity auth
          verify(
            () => mockHealthService.requestAuthorization(activityTypes),
          ).called(1);
        });
      },
    );
  });

  group('getActivityHealthData', () {
    test('should return early on desktop platforms', () async {
      await healthImport.getActivityHealthData(
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024, 1, 2),
      );

      verifyNever(() => mockHealthService.requestAuthorization(any()));
    });

    test('should return early when authorization is denied', () async {
      final mobileImport = createMobileHealthImport();

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => false);

      await mobileImport.getActivityHealthData(
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024, 1, 2),
      );

      verifyNever(
        () => mockHealthService.getTotalStepsInInterval(any(), any()),
      );
    });

    test('should fetch and save activity data for date range', () async {
      final mobileImport = createMobileHealthImport();
      final dateFrom = DateTime(2024, 3);
      final dateTo = DateTime(2024, 3, 2);

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => true);

      when(
        () => mockHealthService.getTotalStepsInInterval(any(), any()),
      ).thenAnswer((_) async => 5000);

      when(
        () => mockHealthService.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenAnswer((_) async => []);

      when(
        () => mockPersistenceLogic.createQuantitativeEntry(any()),
      ).thenAnswer((_) async => null);

      await mobileImport.getActivityHealthData(
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      // 2 days × 3 types (steps, flights, distance) = 6 persistence calls
      verify(
        () => mockPersistenceLogic.createQuantitativeEntry(any()),
      ).called(6);
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

    test('should return early when authorization is denied', () async {
      final mobileImport = createMobileHealthImport();

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => false);

      await mobileImport.getWorkoutsHealthData(
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024, 1, 2),
      );

      verifyNever(() => mockPersistenceLogic.createWorkoutEntry(any()));
    });

    test('should process WorkoutHealthValue data points', () async {
      final mobileImport = createMobileHealthImport();
      final dateFrom = DateTime(2024, 3, 1, 8);
      final dateTo = DateTime(2024, 3, 1, 9);

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => true);

      when(
        () => mockHealthService.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenAnswer(
        (_) async => [
          HealthDataPoint(
            uuid: 'workout-uuid-1',
            value: WorkoutHealthValue(
              workoutActivityType: HealthWorkoutActivityType.RUNNING,
              totalEnergyBurned: 350,
              totalDistance: 5000,
            ),
            type: HealthDataType.WORKOUT,
            unit: HealthDataUnit.NO_UNIT,
            dateFrom: dateFrom,
            dateTo: dateTo,
            sourcePlatform: HealthPlatformType.appleHealth,
            sourceDeviceId: 'test-device',
            sourceId: 'apple-watch',
            sourceName: 'Apple Watch',
          ),
        ],
      );

      when(
        () => mockPersistenceLogic.createWorkoutEntry(any()),
      ).thenAnswer((_) async => null);

      await mobileImport.getWorkoutsHealthData(
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      final captured = verify(
        () => mockPersistenceLogic.createWorkoutEntry(captureAny()),
      ).captured;

      expect(captured.length, 1);
      final workoutData = captured.first as WorkoutData;
      expect(workoutData.workoutType, 'RUNNING');
      expect(workoutData.distance, 5000);
      expect(workoutData.energy, 350);
      expect(workoutData.source, 'apple-watch');
      expect(workoutData.id, 'workout-uuid-1');
      expect(workoutData.dateFrom, dateFrom);
      expect(workoutData.dateTo, dateTo);
    });

    test('should skip non-workout health values', () async {
      final mobileImport = createMobileHealthImport();
      final dateFrom = DateTime(2024, 3, 1, 8);
      final dateTo = DateTime(2024, 3, 1, 9);

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => true);

      when(
        () => mockHealthService.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenAnswer(
        (_) async => [
          makeNumericDataPoint(
            type: HealthDataType.WORKOUT,
            value: 100,
            dateFrom: dateFrom,
            dateTo: dateTo,
          ),
        ],
      );

      await mobileImport.getWorkoutsHealthData(
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      // Numeric value should be skipped (not a WorkoutHealthValue)
      verifyNever(() => mockPersistenceLogic.createWorkoutEntry(any()));
    });

    test('should process multiple workouts in reverse order', () async {
      final mobileImport = createMobileHealthImport();
      final date1From = DateTime(2024, 3, 1, 8);
      final date1To = DateTime(2024, 3, 1, 9);
      final date2From = DateTime(2024, 3, 1, 16);
      final date2To = DateTime(2024, 3, 1, 17);

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => true);

      when(
        () => mockHealthService.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenAnswer(
        (_) async => [
          HealthDataPoint(
            uuid: 'workout-1',
            value: WorkoutHealthValue(
              workoutActivityType: HealthWorkoutActivityType.RUNNING,
              totalEnergyBurned: 200,
              totalDistance: 3000,
            ),
            type: HealthDataType.WORKOUT,
            unit: HealthDataUnit.NO_UNIT,
            dateFrom: date1From,
            dateTo: date1To,
            sourcePlatform: HealthPlatformType.appleHealth,
            sourceDeviceId: 'test',
            sourceId: 'test',
            sourceName: 'test',
          ),
          HealthDataPoint(
            uuid: 'workout-2',
            value: WorkoutHealthValue(
              workoutActivityType: HealthWorkoutActivityType.YOGA,
              totalEnergyBurned: 150,
              totalDistance: 0,
            ),
            type: HealthDataType.WORKOUT,
            unit: HealthDataUnit.NO_UNIT,
            dateFrom: date2From,
            dateTo: date2To,
            sourcePlatform: HealthPlatformType.appleHealth,
            sourceDeviceId: 'test',
            sourceId: 'test',
            sourceName: 'test',
          ),
        ],
      );

      when(
        () => mockPersistenceLogic.createWorkoutEntry(any()),
      ).thenAnswer((_) async => null);

      await mobileImport.getWorkoutsHealthData(
        dateFrom: date1From,
        dateTo: date2To,
      );

      final captured = verify(
        () => mockPersistenceLogic.createWorkoutEntry(captureAny()),
      ).captured;

      // Processed in reversed order
      expect(captured.length, 2);
      expect((captured[0] as WorkoutData).workoutType, 'YOGA');
      expect((captured[1] as WorkoutData).workoutType, 'RUNNING');
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
      expect(healthImport.workoutImportRunning, false);

      // Simulate the flag being set (as it would be on mobile)
      healthImport.workoutImportRunning = true;
      expect(healthImport.workoutImportRunning, true);

      // When flag is true, the method should return early without doing work
      await healthImport.getWorkoutsHealthDataDelta();

      // Flag should still be true since we set it manually and the method
      // returned early
      expect(healthImport.workoutImportRunning, true);

      // Reset for next test
      healthImport.workoutImportRunning = false;
      expect(healthImport.workoutImportRunning, false);
    });

    test('should use latest workout dateFrom as fetch start', () async {
      final mobileImport = createMobileHealthImport();
      final latestDate = DateTime(2024, 6, 15, 10);

      final latestWorkout = WorkoutEntry(
        data: WorkoutData(
          dateFrom: latestDate,
          dateTo: latestDate.add(const Duration(hours: 1)),
          id: 'workout-123',
          workoutType: 'RUNNING',
          energy: 300,
          distance: 5000,
          source: 'test',
        ),
        meta: Metadata(
          id: 'meta-id',
          createdAt: latestDate,
          updatedAt: latestDate,
          dateFrom: latestDate,
          dateTo: latestDate.add(const Duration(hours: 1)),
        ),
      );

      when(
        () => mockJournalDb.latestWorkout(),
      ).thenAnswer((_) async => latestWorkout);

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => true);

      when(
        () => mockHealthService.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenAnswer((_) async => []);

      await mobileImport.getWorkoutsHealthDataDelta();

      verify(
        () => mockHealthService.getHealthDataFromTypes(
          types: [HealthDataType.WORKOUT],
          startTime: latestDate,
          endTime: any(named: 'endTime'),
        ),
      ).called(1);

      // Flag should be reset after completion
      expect(mobileImport.workoutImportRunning, false);
    });

    test(
      'should use default duration when no latest workout exists',
      () {
        fakeAsync((async) {
          final mobileImport = createMobileHealthImport();

          when(
            () => mockJournalDb.latestWorkout(),
          ).thenAnswer((_) async => null);

          when(
            () => mockHealthService.requestAuthorization(any()),
          ).thenAnswer((_) async => true);

          when(
            () => mockHealthService.getHealthDataFromTypes(
              types: any(named: 'types'),
              startTime: any(named: 'startTime'),
              endTime: any(named: 'endTime'),
            ),
          ).thenAnswer((_) async => []);

          mobileImport.getWorkoutsHealthDataDelta();
          async.flushMicrotasks();

          final captured = verify(
            () => mockHealthService.getHealthDataFromTypes(
              types: any(named: 'types'),
              startTime: captureAny(named: 'startTime'),
              endTime: any(named: 'endTime'),
            ),
          ).captured;

          final startTime = captured.first as DateTime;
          final expectedStart = clock.now().subtract(
            const Duration(days: 90),
          );
          expect(startTime, expectedStart);
        });
      },
    );

    test('should reset workoutImportRunning flag after completion', () async {
      final mobileImport = createMobileHealthImport();

      when(
        () => mockJournalDb.latestWorkout(),
      ).thenAnswer((_) async => null);

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => false);

      expect(mobileImport.workoutImportRunning, false);

      await mobileImport.getWorkoutsHealthDataDelta();

      // Flag should be reset even if auth fails
      expect(mobileImport.workoutImportRunning, false);
    });
  });

  group('default permission request', () {
    /// Forces mobile platform flags and restores them afterwards, without
    /// injecting a [requestPermissions] override, so the production default
    /// ([HealthImport]'s static permission request) is exercised.
    HealthImport createMobileHealthImportWithDefaultPermissions() {
      final originalIsDesktop = platform.isDesktop;
      final originalIsMobile = platform.isMobile;
      platform.isDesktop = false;
      platform.isMobile = true;
      addTearDown(() {
        platform.isDesktop = originalIsDesktop;
        platform.isMobile = originalIsMobile;
      });

      return HealthImport(
        persistenceLogic: mockPersistenceLogic,
        db: mockJournalDb,
        health: mockHealthService,
        deviceInfo: mockDeviceInfoPlugin,
      );
    }

    test(
      'requests activityRecognition and location via the default handler',
      () async {
        final recordingHandler = _RecordingPermissionHandler();
        final originalHandler = PermissionHandlerPlatform.instance;
        PermissionHandlerPlatform.instance = recordingHandler;
        addTearDown(
          () => PermissionHandlerPlatform.instance = originalHandler,
        );

        final mobileImport = createMobileHealthImportWithDefaultPermissions();

        // Deny health auth so the flow returns right after the default
        // permission request, isolating the permission request path.
        when(
          () => mockHealthService.requestAuthorization(any()),
        ).thenAnswer((_) async => false);

        await mobileImport.getActivityHealthData(
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024, 1, 2),
        );

        // The default handler must have requested exactly the two
        // permissions, each as its own single-element request.
        expect(
          recordingHandler.requestedPermissions,
          [
            [Permission.activityRecognition],
            [Permission.location],
          ],
        );
      },
    );
  });

  group('top-level type lists', () {
    test('sleepTypes contains expected types', () {
      expect(sleepTypes, contains(HealthDataType.SLEEP_IN_BED));
      expect(sleepTypes, contains(HealthDataType.SLEEP_ASLEEP));
      expect(sleepTypes, contains(HealthDataType.SLEEP_LIGHT));
      expect(sleepTypes, contains(HealthDataType.SLEEP_DEEP));
      expect(sleepTypes, contains(HealthDataType.SLEEP_REM));
      expect(sleepTypes, contains(HealthDataType.SLEEP_AWAKE));
      expect(sleepTypes.length, 6);
    });

    test('bpTypes contains systolic and diastolic', () {
      expect(bpTypes, contains(HealthDataType.BLOOD_PRESSURE_SYSTOLIC));
      expect(bpTypes, contains(HealthDataType.BLOOD_PRESSURE_DIASTOLIC));
      expect(bpTypes.length, 2);
    });

    test('heartRateTypes contains expected types', () {
      expect(heartRateTypes, contains(HealthDataType.RESTING_HEART_RATE));
      expect(heartRateTypes, contains(HealthDataType.WALKING_HEART_RATE));
      expect(
        heartRateTypes,
        contains(HealthDataType.HEART_RATE_VARIABILITY_SDNN),
      );
      expect(heartRateTypes.length, 3);
    });

    test('bodyMeasurementTypes contains expected types', () {
      expect(bodyMeasurementTypes, contains(HealthDataType.WEIGHT));
      expect(
        bodyMeasurementTypes,
        contains(HealthDataType.BODY_FAT_PERCENTAGE),
      );
      expect(bodyMeasurementTypes, contains(HealthDataType.BODY_MASS_INDEX));
      expect(bodyMeasurementTypes, contains(HealthDataType.HEIGHT));
      expect(bodyMeasurementTypes.length, 4);
    });

    test('activityTypes contains expected types', () {
      expect(activityTypes, contains(HealthDataType.STEPS));
      expect(activityTypes, contains(HealthDataType.FLIGHTS_CLIMBED));
      expect(
        activityTypes,
        contains(HealthDataType.DISTANCE_WALKING_RUNNING),
      );
      expect(activityTypes.length, 3);
    });
  });

  // -------------------------------------------------------------------------
  // Additive Glados property groups for pure methods on HealthImport.
  // healthImport is already initialized by setUp() above; the pure functions
  // under test do not use any injected dependency.
  // -------------------------------------------------------------------------

  group('sumNumericHealthValues — Glados properties', () {
    glados.Glados<List<int>>(
      glados.ListAnys(glados.any).listWithLengthInRange(
        0,
        10,
        glados.IntAnys(glados.any).intInRange(0, 1000),
      ),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'result equals the arithmetic sum of all numeric values',
      (values) {
        final baseDate = DateTime(2024);
        final dataPoints = <HealthDataPoint>[
          for (final v in values)
            HealthDataPoint(
              uuid: 'test-uuid-$v',
              value: NumericHealthValue(numericValue: v),
              type: HealthDataType.STEPS,
              unit: HealthDataUnit.COUNT,
              dateFrom: baseDate,
              dateTo: baseDate,
              sourcePlatform: HealthPlatformType.appleHealth,
              sourceDeviceId: 'dev',
              sourceId: 'src',
              sourceName: 'Test',
            ),
        ];
        final result = healthImport.sumNumericHealthValues(dataPoints);
        final expected = values.fold<num>(0, (acc, v) => acc + v);
        expect(
          result,
          equals(expected),
          reason: 'values=$values',
        );
      },
      tags: 'glados',
    );

    glados.Glados<List<int>>(
      glados.ListAnys(glados.any).listWithLengthInRange(
        1,
        8,
        glados.IntAnys(glados.any).intInRange(0, 500),
      ),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'result is ≥ the maximum individual value',
      (values) {
        final baseDate = DateTime(2024);
        final dataPoints = <HealthDataPoint>[
          for (final v in values)
            HealthDataPoint(
              uuid: 'uuid-$v',
              value: NumericHealthValue(numericValue: v),
              type: HealthDataType.STEPS,
              unit: HealthDataUnit.COUNT,
              dateFrom: baseDate,
              dateTo: baseDate,
              sourcePlatform: HealthPlatformType.appleHealth,
              sourceDeviceId: 'dev',
              sourceId: 'src',
              sourceName: 'Test',
            ),
        ];
        final result = healthImport.sumNumericHealthValues(dataPoints);
        final maxVal = values.reduce((a, b) => a > b ? a : b);
        expect(
          result,
          greaterThanOrEqualTo(maxVal),
          reason: 'values=$values',
        );
      },
      tags: 'glados',
    );
  });

  group('getDays — Glados algebraic properties', () {
    glados.Glados2<int, int>(
      glados.IntAnys(glados.any).intInRange(0, 90),
      glados.IntAnys(glados.any).intInRange(0, 90),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'result length equals inDays + 1 for any date range',
      (startOffsetDays, rangeLen) {
        final base = DateTime(2024);
        final dateFrom = base.add(Duration(days: startOffsetDays));
        final dateTo = dateFrom.add(Duration(days: rangeLen));
        final result = healthImport.getDays(dateFrom, dateTo);
        expect(
          result.length,
          equals(rangeLen + 1),
          reason: 'startOffset=$startOffsetDays rangeLen=$rangeLen',
        );
      },
      tags: 'glados',
    );

    glados.Glados2<int, int>(
      glados.IntAnys(glados.any).intInRange(0, 60),
      glados.IntAnys(glados.any).intInRange(0, 60),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'every element has time-of-day normalized to midnight',
      (startOffsetDays, rangeLen) {
        final base = DateTime(2024, 3, 15, 14, 30, 45); // non-midnight start
        final dateFrom = base.add(Duration(days: startOffsetDays));
        final dateTo = dateFrom.add(Duration(days: rangeLen));
        final result = healthImport.getDays(dateFrom, dateTo);
        for (final day in result) {
          expect(day.hour, equals(0), reason: 'day=$day is not midnight');
          expect(day.minute, equals(0), reason: 'day=$day is not midnight');
          expect(day.second, equals(0), reason: 'day=$day is not midnight');
        }
      },
      tags: 'glados',
    );

    glados.Glados2<int, int>(
      glados.IntAnys(glados.any).intInRange(0, 60),
      glados.IntAnys(glados.any).intInRange(1, 60),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'consecutive elements differ by exactly one day',
      (startOffsetDays, rangeLen) {
        final base = DateTime(2024);
        final dateFrom = base.add(Duration(days: startOffsetDays));
        final dateTo = dateFrom.add(Duration(days: rangeLen));
        final result = healthImport.getDays(dateFrom, dateTo);
        for (var i = 1; i < result.length; i++) {
          final prev = result[i - 1];
          // Compare by calendar day (DST-safe): the next element must be the
          // next calendar midnight, which `inDays` can't assert across a
          // spring-forward/fall-back boundary (23h/25h gaps).
          expect(
            result[i],
            DateTime(prev.year, prev.month, prev.day + 1),
            reason: 'gap between $prev and ${result[i]}',
          );
        }
      },
      tags: 'glados',
    );

    glados.Glados<int>(
      glados.IntAnys(glados.any).intInRange(0, 365),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'single-day range always returns exactly one element equal to that day',
      (offsetDays) {
        final base = DateTime(2024);
        final day = base.add(Duration(days: offsetDays));
        final result = healthImport.getDays(day, day);
        expect(result.length, equals(1));
        expect(
          result.single,
          equals(DateTime(day.year, day.month, day.day)),
        );
      },
      tags: 'glados',
    );
  });

  group('health type list invariants', () {
    test('the five type lists are pairwise disjoint', () {
      final lists = <String, List<HealthDataType>>{
        'sleepTypes': sleepTypes,
        'bpTypes': bpTypes,
        'heartRateTypes': heartRateTypes,
        'bodyMeasurementTypes': bodyMeasurementTypes,
        'activityTypes': activityTypes,
      };

      // No list may contain duplicates...
      for (final MapEntry(key: name, value: list) in lists.entries) {
        expect(list.toSet().length, list.length, reason: '$name has dupes');
      }

      // ...and no type may appear in two different lists (a type present in
      // two lists would be imported twice by the per-category fetchers).
      final entries = lists.entries.toList();
      for (var i = 0; i < entries.length; i++) {
        for (var j = i + 1; j < entries.length; j++) {
          final overlap = entries[i].value.toSet().intersection(
            entries[j].value.toSet(),
          );
          expect(
            overlap,
            isEmpty,
            reason:
                '${entries[i].key} and ${entries[j].key} share '
                '$overlap',
          );
        }
      }
    });
  });
}
