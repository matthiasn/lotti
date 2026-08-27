import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:health/health.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler/permission_handler.dart';
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
  late MockDomainLogger mockDomainLogger;

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
    mockDomainLogger = MockDomainLogger();

    // Every import path now logs its outcome, so the logger has to resolve.
    getIt.registerSingleton<DomainLogger>(mockDomainLogger);

    // HealthKit's answer to "do I have read access?" — Apple will not disclose
    // it, so every path through the permission gate has to cope with `null`.
    // Individual tests override it to exercise Health Connect's definitive
    // `true`/`false`.
    when(
      () => mockHealthService.hasPermissions(any()),
    ).thenAnswer((_) async => null);

    healthImport = HealthImport(
      persistenceLogic: mockPersistenceLogic,
      db: mockJournalDb,
      health: mockHealthService,
      deviceInfo: mockDeviceInfoPlugin,
    );
  });

  tearDown(getIt.reset);

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

  /// Makes every type look like one Lotti has imported before.
  ///
  /// An empty read is only reported as [HealthImportStatus.noDataOrAccess] when
  /// the category has *never* yielded a sample, so a test about anything else
  /// has to say which side of that it is on.
  void stubStoredHistory() {
    when(() => mockJournalDb.latestQuantitativeByType(any())).thenAnswer((
      invocation,
    ) async {
      final dataType = invocation.positionalArguments.first as String;
      final at = DateTime(2024);
      return QuantitativeEntry(
        data: DiscreteQuantityData(
          dateFrom: at,
          dateTo: at,
          value: 1,
          dataType: dataType,
          unit: 'unit',
        ),
        meta: Metadata(
          id: 'history',
          createdAt: at,
          updatedAt: at,
          dateFrom: at,
          dateTo: at,
        ),
      );
    });
  }

  /// Grants authorization and returns [dataPoints] from every read.
  ///
  /// `hasPermissions` answers `null` — HealthKit's answer, since Apple will not
  /// disclose read authorization — so the permission gate still raises the
  /// authorization request, which is the behaviour most of these tests assert
  /// on. Health Connect's definitive `true`/`false` is exercised in
  /// `health_permission_gate_test.dart`.
  void stubHealthStore({List<HealthDataPoint> dataPoints = const []}) {
    when(
      () => mockHealthService.hasPermissions(any()),
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
    ).thenAnswer((_) async => dataPoints);
    when(
      () => mockHealthService.getTotalStepsInInterval(any(), any()),
    ).thenAnswer((_) async => 0);
    // Returning a real entity, not null: `createQuantitativeEntry` signals
    // "not stored" with null, and the reported sample count now honours that.
    when(
      () => mockPersistenceLogic.createQuantitativeEntry(any()),
    ).thenAnswer((invocation) async {
      final data = invocation.positionalArguments.first as QuantitativeData;
      return QuantitativeEntry(
        data: data,
        meta: Metadata(
          id: 'stored',
          createdAt: data.dateFrom,
          updatedAt: data.dateFrom,
          dateFrom: data.dateFrom,
          dateTo: data.dateTo,
        ),
      );
    });
    when(() => mockPersistenceLogic.createWorkoutEntry(any())).thenAnswer((
      invocation,
    ) async {
      final data = invocation.positionalArguments.first as WorkoutData;
      return WorkoutEntry(
        data: data,
        meta: Metadata(
          id: 'stored',
          createdAt: data.dateFrom,
          updatedAt: data.dateFrom,
          dateFrom: data.dateFrom,
          dateTo: data.dateTo,
        ),
      );
    });
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

      expect(healthImport.sumNumericHealthValues(dataPoints), 30);
    });

    test('should return 0 for an empty list', () {
      expect(healthImport.sumNumericHealthValues([]), 0);
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

      expect(healthImport.sumNumericHealthValues(dataPoints), 10);
    });
  });

  group('addActivityEntries', () {
    test('persists one entry per day and counts what was stored', () async {
      stubHealthStore();

      final written = await healthImport.addActivityEntries(
        {DateTime(2024): 100.0, DateTime(2024, 1, 2): 200.0},
        'cumulative_step_count',
        'count',
      );

      expect(written, 2);
      verify(
        () => mockPersistenceLogic.createQuantitativeEntry(any()),
      ).called(2);
    });

    // `createQuantitativeEntry` logs and returns null rather than throwing, so
    // a count of attempts would tell the user "2 samples imported" about rows
    // the database rejected.
    test('does not count entries the database rejected', () async {
      when(
        () => mockPersistenceLogic.createQuantitativeEntry(any()),
      ).thenAnswer((_) async => null);

      final written = await healthImport.addActivityEntries(
        {DateTime(2024): 100.0, DateTime(2024, 1, 2): 200.0},
        'cumulative_step_count',
        'count',
      );

      expect(written, 0);
      verify(
        () => mockPersistenceLogic.createQuantitativeEntry(any()),
      ).called(2);
    });

    test('writes nothing and reports zero for an empty day map', () async {
      expect(
        await healthImport.addActivityEntries({}, 'cumulative_step_count', 'x'),
        0,
      );
      verifyNever(() => mockPersistenceLogic.createQuantitativeEntry(any()));
    });
  });

  group('getDays', () {
    test('should generate correct date range for single day', () {
      final result = healthImport.getDays(DateTime(2024), DateTime(2024));

      expect(result.length, 1);
      expect(result.first, DateTime(2024));
    });

    test('should generate correct date range for multiple days', () {
      final result = healthImport.getDays(DateTime(2024), DateTime(2024, 1, 5));

      expect(result.length, 5);
      expect(result.first, DateTime(2024));
      expect(result.last, DateTime(2024, 1, 5));
    });

    test('should normalize times to midnight', () {
      final result = healthImport.getDays(
        DateTime(2024, 1, 1, 10, 30),
        DateTime(2024, 1, 2, 15, 45),
      );

      expect(result.length, 2);
      expect(result.first, DateTime(2024));
      expect(result.last, DateTime(2024, 1, 2));
    });
  });

  group('resolveHealthDataTypes', () {
    test('resolves fully qualified storage type strings', () {
      expect(
        healthImport.resolveHealthDataTypes([
          'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
          'HealthDataType.HEART_RATE_VARIABILITY_SDNN',
        ]),
        [
          HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
          HealthDataType.HEART_RATE_VARIABILITY_SDNN,
        ],
      );
    });

    test('resolves bare enum names', () {
      expect(
        healthImport.resolveHealthDataTypes(['STEPS']),
        [HealthDataType.STEPS],
      );
    });

    test('drops names the plugin no longer defines', () {
      // `SLEEP_ASLEEP_CORE` is exactly the kind of stale name that used to be
      // dropped silently, leaving the caller with an empty fetch and no clue.
      expect(
        healthImport.resolveHealthDataTypes([
          'HealthDataType.SLEEP_ASLEEP_CORE',
          'HealthDataType.WEIGHT',
        ]),
        [HealthDataType.WEIGHT],
      );
    });

    test('returns empty when nothing resolves', () {
      expect(
        healthImport.resolveHealthDataTypes(['HealthDataType.NOT_A_TYPE']),
        isEmpty,
      );
    });
  });

  group('fetchAndProcessActivityDataForDay', () {
    test('should not fetch data for future dates', () async {
      final stepsByDay = <DateTime, num>{};
      final flightsByDay = <DateTime, num>{};
      final distanceByDay = <DateTime, num>{};

      await healthImport.fetchAndProcessActivityDataForDay(
        DateTime(2099),
        stepsByDay,
        flightsByDay,
        distanceByDay,
      );

      expect(stepsByDay.isEmpty, true);
      expect(flightsByDay.isEmpty, true);
      expect(distanceByDay.isEmpty, true);
    });

    test('should fetch and aggregate activity data for a past date', () async {
      final testDate = DateTime(2024);
      final stepsByDay = <DateTime, num>{};
      final flightsByDay = <DateTime, num>{};
      final distanceByDay = <DateTime, num>{};

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

      expect(stepsByDay[testDate], 10000);
      expect(flightsByDay[testDate], 25); // 15 + 10
      expect(distanceByDay[testDate], 5000);

      verify(
        () => mockHealthService.getTotalStepsInInterval(any(), any()),
      ).called(1);
      verify(
        () => mockHealthService.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).called(3); // Steps samples, flights, distance
    });

    test('reads the raw step samples over the same whole day', () async {
      final testDate = DateTime(2024);
      stubHealthStore();

      await healthImport.fetchAndProcessActivityDataForDay(
        testDate,
        <DateTime, num>{},
        <DateTime, num>{},
        <DateTime, num>{},
      );

      verify(
        () => mockHealthService.getHealthDataFromTypes(
          types: [HealthDataType.STEPS],
          startTime: testDate,
          endTime: DateTime(2024, 1, 1, 23, 59, 59, 999),
        ),
      ).called(1);
    });

    // The reported bug: a band that syncs its whole day once overnight is
    // ranked below the phone in Health's source priority, so HealthKit's merged
    // total kept the phone's under-count. The per-source samples still carry
    // the band's figure, and the best single source wins.
    test(
      'prefers the best single source over a merged total that dropped it',
      () async {
        final testDate = DateTime(2024);
        final stepsByDay = <DateTime, num>{};

        when(
          () => mockHealthService.getTotalStepsInInterval(any(), any()),
        ).thenAnswer((_) async => 9800);
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
          if (!types.contains(HealthDataType.STEPS)) {
            return [];
          }
          return [
            makeNumericDataPoint(
              type: HealthDataType.STEPS,
              value: 9800,
              dateFrom: testDate,
              dateTo: testDate.add(const Duration(hours: 23)),
              sourceId: 'com.apple.health.iphone',
              sourceName: 'iPhone',
            ),
            makeNumericDataPoint(
              type: HealthDataType.STEPS,
              value: 11600,
              dateFrom: testDate,
              dateTo: testDate.add(const Duration(hours: 24)),
              sourceId: 'com.whoop.app',
              sourceName: 'WHOOP',
            ),
          ];
        });

        await healthImport.fetchAndProcessActivityDataForDay(
          testDate,
          stepsByDay,
          <DateTime, num>{},
          <DateTime, num>{},
        );

        expect(stepsByDay[testDate], 11600);
      },
    );

    test('should handle zero values correctly', () async {
      final testDate = DateTime(2024);
      final stepsByDay = <DateTime, num>{};
      final flightsByDay = <DateTime, num>{};
      final distanceByDay = <DateTime, num>{};

      stubHealthStore();

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

      stubHealthStore();
      when(
        () => mockHealthService.getTotalStepsInInterval(any(), any()),
      ).thenAnswer((_) async => null);

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
    test('denies on desktop without reaching the health store', () async {
      expect(
        await healthImport.authorizeHealth(
          [HealthDataType.STEPS],
          userInitiated: true,
        ),
        HealthAuthorization.denied,
      );
      verifyNever(() => mockHealthService.hasPermissions(any()));
      verifyNever(() => mockHealthService.requestAuthorization(any()));
    });

    test('asks for the whole permission family, not the one type', () async {
      final mobileImport = createMobileHealthImport();
      stubHealthStore();

      expect(
        await mobileImport.authorizeHealth(
          [HealthDataType.STEPS],
          userInitiated: true,
        ),
        HealthAuthorization.undisclosed,
      );
      // STEPS alone would be a second sheet the next time FLIGHTS_CLIMBED is
      // imported; the family is authorized in one request.
      verify(
        () => mockHealthService.requestAuthorization(activityTypes),
      ).called(1);
    });

    test('reports denied when the platform refuses to raise a sheet', () async {
      final mobileImport = createMobileHealthImport();
      when(
        () => mockHealthService.hasPermissions(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => false);

      expect(
        await mobileImport.authorizeHealth(
          [HealthDataType.RESTING_HEART_RATE],
          userInitiated: true,
        ),
        HealthAuthorization.denied,
      );
    });
  });

  group('fetchHealthData', () {
    test(
      'reports unsupportedPlatform on desktop without touching the store',
      () async {
        final result = await healthImport.fetchHealthData(
          types: [HealthDataType.STEPS],
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024, 1, 2),
        );

        expect(result.status, HealthImportStatus.unsupportedPlatform);
        verifyNever(() => mockHealthService.requestAuthorization(any()));
      },
    );

    test('reports permissionDenied when authorization is refused', () async {
      final mobileImport = createMobileHealthImport();

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => false);

      final result = await mobileImport.fetchHealthData(
        types: [HealthDataType.HEART_RATE],
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024, 1, 2),
      );

      expect(result.status, HealthImportStatus.permissionDenied);
      verify(() => mockHealthService.requestAuthorization(any())).called(1);
      verifyNever(
        () => mockHealthService.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      );
    });

    test('persists numeric points and reports how many', () async {
      final mobileImport = createMobileHealthImport();
      final dateFrom = DateTime(2024, 3);
      final dateTo = DateTime(2024, 3, 1, 12);

      stubHealthStore(
        dataPoints: [
          makeNumericDataPoint(
            type: HealthDataType.HEART_RATE,
            value: 72,
            dateFrom: dateFrom,
            dateTo: dateTo,
            unit: HealthDataUnit.BEATS_PER_MINUTE,
          ),
        ],
      );

      final result = await mobileImport.fetchHealthData(
        types: [HealthDataType.HEART_RATE],
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      expect(result.status, HealthImportStatus.imported);
      expect(result.sampleCount, 1);

      final captured = verify(
        () => mockPersistenceLogic.createQuantitativeEntry(captureAny()),
      ).captured;

      expect(captured.length, 1);
      final data = captured.first as DiscreteQuantityData;
      expect(data.value, 72);
      expect(data.dataType, 'HealthDataType.HEART_RATE');
    });

    test('a rejected sample is not counted as imported', () async {
      final mobileImport = createMobileHealthImport();
      stubHealthStore(
        dataPoints: [
          makeNumericDataPoint(
            type: HealthDataType.HEART_RATE,
            value: 72,
            dateFrom: DateTime(2024, 3),
            dateTo: DateTime(2024, 3),
          ),
        ],
      );
      when(
        () => mockPersistenceLogic.createQuantitativeEntry(any()),
      ).thenAnswer((_) async => null);

      final result = await mobileImport.fetchHealthData(
        types: [HealthDataType.HEART_RATE],
        dateFrom: DateTime(2024, 3),
        dateTo: DateTime(2024, 3, 2),
      );

      expect(result.isSuccess, isTrue);
      expect(
        result.sampleCount,
        0,
        reason: 'the store refused the row; reporting 1 would be a lie',
      );
    });

    test('an empty range is a success importing zero samples', () async {
      final mobileImport = createMobileHealthImport();
      stubHealthStore();
      stubStoredHistory();

      final result = await mobileImport.fetchHealthData(
        types: [HealthDataType.HEART_RATE],
        dateFrom: DateTime(2024, 3),
        dateTo: DateTime(2024, 3, 2),
      );

      expect(result.isSuccess, isTrue);
      expect(result.sampleCount, 0);
    });

    group('an empty read that may be a permission problem', () {
      test(
        'is reported as noDataOrAccess when nothing was ever stored',
        () async {
          final mobileImport = createMobileHealthImport();
          stubHealthStore();
          when(
            () => mockJournalDb.latestQuantitativeByType(any()),
          ).thenAnswer((_) async => null);

          final result = await mobileImport.fetchHealthData(
            types: bpTypes,
            dateFrom: DateTime(2024, 3),
            dateTo: DateTime(2024, 3, 2),
          );

          // The reported symptom: blood pressure switched off in Settings →
          // Privacy & Security → Health imports nothing, HealthKit reports the
          // authorization as fine, and the row used to show a green tick reading
          // "No new samples".
          expect(result.status, HealthImportStatus.noDataOrAccess);
          expect(result.isSuccess, isFalse);
        },
      );

      test('is an ordinary empty import once history exists', () async {
        final mobileImport = createMobileHealthImport();
        stubHealthStore();
        stubStoredHistory();

        final result = await mobileImport.fetchHealthData(
          types: bpTypes,
          dateFrom: DateTime(2024, 3),
          dateTo: DateTime(2024, 3, 2),
        );

        expect(result.status, HealthImportStatus.imported);
        expect(result.sampleCount, 0);
      });

      test('checks every requested type before concluding', () async {
        final mobileImport = createMobileHealthImport();
        stubHealthStore();
        when(
          () => mockJournalDb.latestQuantitativeByType(any()),
        ).thenAnswer((_) async => null);

        await mobileImport.fetchHealthData(
          types: bpTypes,
          dateFrom: DateTime(2024, 3),
          dateTo: DateTime(2024, 3, 2),
        );

        for (final type in bpTypes) {
          verify(
            () => mockJournalDb.latestQuantitativeByType(type.toString()),
          ).called(1);
        }
      });

      test('stops at the first type with history', () async {
        final mobileImport = createMobileHealthImport();
        stubHealthStore();
        when(
          () => mockJournalDb.latestQuantitativeByType(any()),
        ).thenAnswer((_) async => null);
        stubStoredHistory();

        await mobileImport.fetchHealthData(
          types: bpTypes,
          dateFrom: DateTime(2024, 3),
          dateTo: DateTime(2024, 3, 2),
        );

        verifyNever(
          () => mockJournalDb.latestQuantitativeByType(
            'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
          ),
        );
      });

      test(
        'is never claimed when the platform confirmed read access',
        () async {
          final mobileImport = createMobileHealthImport();
          stubHealthStore();
          // Health Connect said yes, so an empty read really does mean there
          // is nothing there — asserting a permission problem would be a lie,
          // and the DB need not even be consulted.
          when(
            () => mockHealthService.hasPermissions(any()),
          ).thenAnswer((_) async => true);

          final result = await mobileImport.fetchHealthData(
            types: bpTypes,
            dateFrom: DateTime(2024, 3),
            dateTo: DateTime(2024, 3, 2),
          );

          expect(result.status, HealthImportStatus.imported);
          verifyNever(() => mockJournalDb.latestQuantitativeByType(any()));
        },
      );

      test('is not claimed when samples did come back', () async {
        final mobileImport = createMobileHealthImport();
        stubHealthStore(
          dataPoints: [
            makeNumericDataPoint(
              type: HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
              value: 118,
              dateFrom: DateTime(2024, 3),
              dateTo: DateTime(2024, 3),
            ),
          ],
        );
        when(
          () => mockJournalDb.latestQuantitativeByType(any()),
        ).thenAnswer((_) async => null);

        final result = await mobileImport.fetchHealthData(
          types: bpTypes,
          dateFrom: DateTime(2024, 3),
          dateTo: DateTime(2024, 3, 2),
        );

        expect(result.status, HealthImportStatus.imported);
        expect(result.sampleCount, 1);
      });

      test('logs a warning naming access as the suspect', () async {
        final mobileImport = createMobileHealthImport();
        stubHealthStore();
        when(
          () => mockJournalDb.latestQuantitativeByType(any()),
        ).thenAnswer((_) async => null);

        await mobileImport.fetchHealthData(
          types: bpTypes,
          dateFrom: DateTime(2024, 3),
          dateTo: DateTime(2024, 3, 2),
        );

        verify(
          () => mockDomainLogger.log(
            LogDomain.health,
            any(that: contains('read access may be off')),
            subDomain: 'fetchHealthData',
            level: InsightLevel.warn,
          ),
        ).called(1);
      });
    });

    // Sleep-duplication invariant, parameterized over the full contract.
    //
    // Apple's staged sleep (`SLEEP_LIGHT` = core, `SLEEP_DEEP`, `SLEEP_REM`) is
    // additionally stored under the generic `SLEEP_ASLEEP` type, which is what
    // the "Asleep" dashboard charts. `SLEEP_LIGHT` is the regression: the old
    // duplication set named `SLEEP_ASLEEP_CORE`, which is not a value of the
    // plugin's enum, so the largest stage of a night was never counted.
    const sleepDuplicationExpectations = <HealthDataType, bool>{
      HealthDataType.SLEEP_LIGHT: true,
      HealthDataType.SLEEP_DEEP: true,
      HealthDataType.SLEEP_REM: true,
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

          stubHealthStore(
            dataPoints: [
              makeNumericDataPoint(
                type: type,
                value: 90,
                dateFrom: dateFrom,
                dateTo: dateTo,
                unit: HealthDataUnit.MINUTE,
              ),
            ],
          );

          final result = await mobileImport.fetchHealthData(
            types: [type],
            dateFrom: dateFrom,
            dateTo: dateTo,
          );

          final captured = verify(
            () => mockPersistenceLogic.createQuantitativeEntry(captureAny()),
          ).captured.cast<DiscreteQuantityData>();

          expect(captured.first.dataType, type.toString());
          // The reported count is samples read, not rows written: the generic
          // copy is the same reading stored twice, not a second measurement.
          expect(result.sampleCount, 1);

          if (duplicates) {
            expect(captured.length, 2);
            expect(captured.last.dataType, 'HealthDataType.SLEEP_ASLEEP');
            expect(captured.last.value, captured.first.value);
            // Everything but the type is carried over verbatim.
            expect(captured.last.dateFrom, captured.first.dateFrom);
            expect(captured.last.dateTo, captured.first.dateTo);
            expect(captured.last.unit, captured.first.unit);
          } else {
            expect(captured.length, 1);
          }
        },
      );
    }

    test('the duplication set contains exactly the staged sleep types', () {
      expect(sleepStagesDuplicatedAsAsleep, {
        'HealthDataType.SLEEP_LIGHT',
        'HealthDataType.SLEEP_DEEP',
        'HealthDataType.SLEEP_REM',
      });
      // Every member must be a real enum value — the previous set's members
      // were not, which is how the defect went unnoticed.
      for (final name in sleepStagesDuplicatedAsAsleep) {
        expect(
          HealthDataType.values.map((type) => type.toString()),
          contains(name),
          reason: '$name is not a HealthDataType',
        );
      }
    });

    test('should skip non-numeric health values', () async {
      final mobileImport = createMobileHealthImport();
      final dateFrom = DateTime(2024, 3);
      final dateTo = DateTime(2024, 3, 1, 12);

      stubHealthStore(
        dataPoints: [
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

      final result = await mobileImport.fetchHealthData(
        types: [HealthDataType.AUDIOGRAM],
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      expect(result.sampleCount, 0);
      verifyNever(() => mockPersistenceLogic.createQuantitativeEntry(any()));
    });

    test('should process multiple data points in reverse order', () async {
      final mobileImport = createMobileHealthImport();
      final date1 = DateTime(2024, 3, 1, 8);
      final date2 = DateTime(2024, 3, 1, 12);
      final date3 = DateTime(2024, 3, 1, 18);

      stubHealthStore(
        dataPoints: [
          for (final (date, value) in [(date1, 60), (date2, 80), (date3, 70)])
            makeNumericDataPoint(
              type: HealthDataType.HEART_RATE,
              value: value,
              dateFrom: date,
              dateTo: date,
            ),
        ],
      );

      final result = await mobileImport.fetchHealthData(
        types: [HealthDataType.HEART_RATE],
        dateFrom: date1,
        dateTo: date3,
      );

      final captured = verify(
        () => mockPersistenceLogic.createQuantitativeEntry(captureAny()),
      ).captured;

      expect(result.sampleCount, 3);
      expect(captured.length, 3);
      expect((captured[0] as DiscreteQuantityData).value, 70);
      expect((captured[1] as DiscreteQuantityData).value, 80);
      expect((captured[2] as DiscreteQuantityData).value, 60);
    });

    test('caps the range end at now rather than reading into the future', () {
      fakeAsync((async) {
        final mobileImport = createMobileHealthImport();
        stubHealthStore();

        mobileImport.fetchHealthData(
          types: [HealthDataType.HEART_RATE],
          dateFrom: DateTime(2024),
          dateTo: DateTime(2099),
        );
        async.flushMicrotasks();

        final captured = verify(
          () => mockHealthService.getHealthDataFromTypes(
            types: any(named: 'types'),
            startTime: any(named: 'startTime'),
            endTime: captureAny(named: 'endTime'),
          ),
        ).captured;

        expect(captured.single, clock.now());
      });
    });

    // The authorization call lives inside the same `try` as the read. It can
    // throw on its own — `requestAuthorization` rejects a bad type/permission
    // pairing, and `HealthService` rethrows a failed configure handshake — and
    // letting that escape would break this method's contract of returning an
    // outcome. The caller that trusts it hardest is the settings page, whose
    // row would be left spinning with no way to retry.
    test('reports failed when authorization itself throws', () async {
      final mobileImport = createMobileHealthImport();
      final failure = ArgumentError('types and permissions differ in length');

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenThrow(failure);

      final result = await mobileImport.fetchHealthData(
        types: [HealthDataType.HEART_RATE],
        dateFrom: DateTime(2024, 3),
        dateTo: DateTime(2024, 3, 2),
      );

      expect(result.status, HealthImportStatus.failed);
      expect(result.error, same(failure));
      verify(
        () => mockDomainLogger.error(
          LogDomain.health,
          same(failure),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'fetchHealthData',
        ),
      ).called(1);
    });

    test('reports failed and logs when the health store throws', () async {
      final mobileImport = createMobileHealthImport();
      final failure = Exception('Health API error');

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockHealthService.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenThrow(failure);

      final result = await mobileImport.fetchHealthData(
        types: [HealthDataType.HEART_RATE],
        dateFrom: DateTime(2024, 3),
        dateTo: DateTime(2024, 3, 1, 12),
      );

      expect(result.status, HealthImportStatus.failed);
      expect(result.error, same(failure));
      verify(
        () => mockDomainLogger.error(
          LogDomain.health,
          same(failure),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'fetchHealthData',
        ),
      ).called(1);
    });
  });

  group('serialization of health-store access', () {
    // HealthKit shows one authorization sheet at a time; a second request
    // raised while the first is on screen replaces it, and the user sees a
    // sheet flash and vanish. Two entry points can fire at once with no user
    // error at all (a dashboard schedules background deltas while the settings
    // page runs an import), so the import layer must serialize them itself.
    test('two concurrent imports never overlap in the health plugin', () async {
      final mobileImport = createMobileHealthImport();
      final events = <String>[];

      when(() => mockHealthService.requestAuthorization(any())).thenAnswer((
        invocation,
      ) async {
        final types =
            invocation.positionalArguments.first as List<HealthDataType>;
        final label = types.first.name;
        events.add('open:$label');
        // Yield across several microtasks: if the two requests were allowed to
        // run concurrently, the second would open inside this gap.
        await null;
        await null;
        await null;
        events.add('close:$label');
        return true;
      });
      when(
        () => mockHealthService.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenAnswer((_) async => []);

      await Future.wait([
        mobileImport.fetchHealthData(
          types: [HealthDataType.HEART_RATE],
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024, 1, 2),
        ),
        mobileImport.fetchHealthData(
          types: [HealthDataType.WEIGHT],
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024, 1, 2),
        ),
      ]);

      expect(events, [
        'open:HEART_RATE',
        'close:HEART_RATE',
        'open:WEIGHT',
        'close:WEIGHT',
      ]);
    });

    test('a failing import does not wedge the ones queued behind it', () async {
      final mobileImport = createMobileHealthImport();

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => true);
      var call = 0;
      when(
        () => mockHealthService.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenAnswer((_) async {
        if (++call == 1) throw Exception('first one explodes');
        return [];
      });
      stubStoredHistory();

      final results = await Future.wait([
        mobileImport.fetchHealthData(
          types: [HealthDataType.HEART_RATE],
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024, 1, 2),
        ),
        mobileImport.fetchHealthData(
          types: [HealthDataType.WEIGHT],
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024, 1, 2),
        ),
      ]);

      expect(results.first.status, HealthImportStatus.failed);
      expect(results.last.isSuccess, isTrue);
    });
  });

  group('fetchHealthDataDelta', () {
    test('should throttle cumulative type requests within 10 minutes', () {
      fakeAsync((async) {
        const type = 'cumulative_step_count';

        healthImport.fetchHealthDataDelta(type);
        async.flushMicrotasks();

        expect(healthImport.lastFetched.containsKey(type), true);
        final firstFetchTime = healthImport.lastFetched[type]!;

        healthImport.fetchHealthDataDelta(type);
        async.flushMicrotasks();

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

        healthImport.fetchHealthDataDelta(type);
        async.flushMicrotasks();

        expect(
          healthImport.lastFetched[type]!.millisecondsSinceEpoch,
          greaterThanOrEqualTo(firstFetchTime.millisecondsSinceEpoch),
        );
      });
    });

    // The "Asleep chart falls behind" regression.
    //
    // HealthKit keeps every sleep stage under one category type, and the
    // plugin's iOS reader picks a stage by filtering on the category value:
    // SLEEP_ASLEEP matches only `asleepUnspecified`, which an Apple Watch on
    // iOS 16+ never writes. So the background delta for the Asleep card read
    // nothing at all, and that series only grew when a *stage* card was
    // fetched (each staged sample is copied under the generic type) or from a
    // manual import in Settings, which asks for the whole family at once.
    test('the Asleep delta fetches the staged types that feed it', () {
      fakeAsync((async) {
        final mobileImport = createMobileHealthImport();
        when(
          () => mockJournalDb.latestQuantitativeByType(any()),
        ).thenAnswer((_) async => null);
        stubHealthStore();

        mobileImport.fetchHealthDataDelta('HealthDataType.SLEEP_ASLEEP');
        async.flushMicrotasks();

        final requested =
            verify(
                  () => mockHealthService.getHealthDataFromTypes(
                    types: captureAny(named: 'types'),
                    startTime: any(named: 'startTime'),
                    endTime: any(named: 'endTime'),
                  ),
                ).captured.single
                as List<HealthDataType>;

        expect(
          requested,
          containsAll(<HealthDataType>[
            HealthDataType.SLEEP_LIGHT,
            HealthDataType.SLEEP_DEEP,
            HealthDataType.SLEEP_REM,
          ]),
          reason: 'asking for SLEEP_ASLEEP alone reads nothing on iOS 16+',
        );
        expect(requested, contains(HealthDataType.SLEEP_ASLEEP));
      });
    });

    // The delta window must come from the generic series being caught up, not
    // from whichever stage sorts first — a stage imported more recently than
    // the last duplicated row would start the window too late and skip the
    // very nights the Asleep chart is missing.
    test('the Asleep delta window comes from the Asleep series itself', () {
      fakeAsync((async) {
        final mobileImport = createMobileHealthImport();
        final asleepLatest = DateTime(2024, 6, 10);

        when(() => mockJournalDb.latestQuantitativeByType(any())).thenAnswer((
          invocation,
        ) async {
          final type = invocation.positionalArguments.first as String;
          // A stage imported far more recently than the generic series.
          final date = type == 'HealthDataType.SLEEP_ASLEEP'
              ? asleepLatest
              : DateTime(2024, 8);
          return QuantitativeEntry(
            data: DiscreteQuantityData(
              dateFrom: date,
              dateTo: date,
              value: 1,
              dataType: type,
              unit: 'MINUTE',
            ),
            meta: Metadata(
              id: 'id-$type',
              createdAt: date,
              updatedAt: date,
              dateFrom: date,
              dateTo: date,
            ),
          );
        });
        stubHealthStore();

        mobileImport.fetchHealthDataDelta('HealthDataType.SLEEP_ASLEEP');
        async.flushMicrotasks();

        verify(
          () => mockHealthService.getHealthDataFromTypes(
            types: any(named: 'types'),
            startTime: asleepLatest,
            endTime: any(named: 'endTime'),
          ),
        ).called(1);
      });
    });

    test('clears the running flag once the queue drains', () {
      fakeAsync((async) {
        final mobileImport = createMobileHealthImport();
        when(
          () => mockJournalDb.latestQuantitativeByType(any()),
        ).thenAnswer((_) async => null);
        stubHealthStore();

        mobileImport.fetchHealthDataDelta('HealthDataType.HEART_RATE');
        expect(mobileImport.running, isTrue, reason: 'set on enqueue');

        async.flushMicrotasks();

        expect(mobileImport.running, isFalse);
        expect(mobileImport.queue, isEmpty);
      });
    });

    // The queue-deadlock regression. `_start` had no try/finally and no
    // per-item guard, so the first type that threw escaped the drain loop and
    // left `running` permanently true. Every later import in the session was
    // then queued behind a drain that would never run again — the symptom
    // being health charts that simply stopped updating.
    test('a throwing type does not wedge the queue for the session', () {
      fakeAsync((async) {
        final mobileImport = createMobileHealthImport();

        when(
          () => mockJournalDb.latestQuantitativeByType(
            'HealthDataType.WEIGHT',
          ),
        ).thenThrow(Exception('db read failed'));
        when(
          () => mockJournalDb.latestQuantitativeByType(
            'HealthDataType.HEART_RATE',
          ),
        ).thenAnswer((_) async => null);
        stubHealthStore();

        mobileImport
          ..fetchHealthDataDelta('HealthDataType.WEIGHT')
          ..fetchHealthDataDelta('HealthDataType.HEART_RATE');
        async.flushMicrotasks();

        // The drain survived the failure...
        expect(mobileImport.running, isFalse);
        expect(mobileImport.queue, isEmpty);
        // ...and the type queued behind the failing one was still imported.
        verify(
          () => mockHealthService.getHealthDataFromTypes(
            types: [HealthDataType.HEART_RATE],
            startTime: any(named: 'startTime'),
            endTime: any(named: 'endTime'),
          ),
        ).called(1);
        // The failure is reported rather than swallowed.
        verify(
          () => mockDomainLogger.error(
            LogDomain.health,
            any<Object>(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'fetchHealthDataDelta',
          ),
        ).called(1);
      });
    });

    test('a later delta still runs after an earlier one failed', () {
      fakeAsync((async) {
        final mobileImport = createMobileHealthImport();

        when(
          () => mockJournalDb.latestQuantitativeByType(any()),
        ).thenThrow(Exception('db read failed'));
        stubHealthStore();

        mobileImport.fetchHealthDataDelta('HealthDataType.WEIGHT');
        async.flushMicrotasks();
        expect(mobileImport.running, isFalse);

        // A *separate* later call — this is the one that used to be swallowed
        // by the stuck `running` flag rather than merely failing itself.
        when(
          () => mockJournalDb.latestQuantitativeByType(any()),
        ).thenAnswer((_) async => null);
        mobileImport.fetchHealthDataDelta('HealthDataType.HEART_RATE');
        async.flushMicrotasks();

        verify(
          () => mockHealthService.getHealthDataFromTypes(
            types: [HealthDataType.HEART_RATE],
            startTime: any(named: 'startTime'),
            endTime: any(named: 'endTime'),
          ),
        ).called(1);
      });
    });
  });

  // Which imports may re-raise a system authorization sheet, and which may not.
  // This is the reported bug: opening a dashboard asked again every time, and
  // once a type is switched off in Settings → Privacy & Security → Health there
  // is nothing in that sheet to answer.
  group('who may re-ask for permission', () {
    test('a dashboard delta asks once and then stays quiet', () {
      fakeAsync((async) {
        final mobileImport = createMobileHealthImport();
        stubHealthStore();
        stubStoredHistory();

        mobileImport
          ..fetchHealthDataDelta('HealthDataType.BLOOD_PRESSURE_SYSTOLIC')
          ..fetchHealthDataDelta('HealthDataType.BLOOD_PRESSURE_DIASTOLIC');
        async.flushMicrotasks();

        // Two charts, one card, one sheet — and none at all on the next visit.
        verify(() => mockHealthService.requestAuthorization(any())).called(1);
      });
    });

    test('a workout delta does not re-ask either', () async {
      final mobileImport = createMobileHealthImport();
      stubHealthStore();
      when(() => mockJournalDb.latestWorkout()).thenAnswer((_) async => null);

      await mobileImport.getWorkoutsHealthDataDelta();
      await mobileImport.getWorkoutsHealthDataDelta();

      verify(() => mockHealthService.requestAuthorization(any())).called(1);
    });

    test('a cumulative delta does not re-ask either', () {
      fakeAsync((async) {
        final mobileImport = createMobileHealthImport();
        stubHealthStore();
        stubStoredHistory();

        mobileImport.fetchHealthDataDelta('cumulative_step_count');
        // Past the ten-minute throttle, so the second call really does run.
        async
          ..flushMicrotasks()
          ..elapse(const Duration(minutes: 11));
        mobileImport.fetchHealthDataDelta('cumulative_step_count');
        async.flushMicrotasks();

        verify(() => mockHealthService.requestAuthorization(any())).called(1);
      });
    });

    test('the settings page asks again on every tap', () async {
      final mobileImport = createMobileHealthImport();
      stubHealthStore();
      stubStoredHistory();

      await mobileImport.fetchHealthData(
        types: bpTypes,
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024, 1, 2),
      );
      await mobileImport.fetchHealthData(
        types: bpTypes,
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024, 1, 2),
      );

      // Tapping a row is the user saying "try again" — the one moment when
      // re-raising the sheet is what they want.
      verify(() => mockHealthService.requestAuthorization(any())).called(2);
    });

    test('the settings page asks again for activity too', () async {
      final mobileImport = createMobileHealthImport();
      stubHealthStore();
      stubStoredHistory();

      await mobileImport.getActivityHealthData(
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024, 1, 2),
      );
      await mobileImport.getActivityHealthData(
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024, 1, 2),
      );

      verify(() => mockHealthService.requestAuthorization(any())).called(2);
    });

    test('the settings page asks again for workouts too', () async {
      final mobileImport = createMobileHealthImport();
      stubHealthStore();
      final at = DateTime(2024);
      when(() => mockJournalDb.latestWorkout()).thenAnswer(
        (_) async => WorkoutEntry(
          data: WorkoutData(
            dateFrom: at,
            dateTo: at,
            workoutType: 'running',
            energy: null,
            distance: null,
            source: null,
            id: 'workout',
          ),
          meta: Metadata(
            id: 'workout',
            createdAt: at,
            updatedAt: at,
            dateFrom: at,
            dateTo: at,
          ),
        ),
      );

      await mobileImport.getWorkoutsHealthData(
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024, 1, 2),
      );
      await mobileImport.getWorkoutsHealthData(
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024, 1, 2),
      );

      verify(() => mockHealthService.requestAuthorization(any())).called(2);
    });

    test('a user-initiated ask unblocks the deltas behind it', () {
      fakeAsync((async) {
        final mobileImport = createMobileHealthImport();
        stubHealthStore();
        stubStoredHistory();

        mobileImport.fetchHealthDataDelta(
          'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
        );
        async.flushMicrotasks();
        verify(() => mockHealthService.requestAuthorization(any())).called(1);

        // The page's own import shares the gate's memory, so granting access
        // there is not asked for a third time by the next chart.
        unawaited(
          mobileImport.fetchHealthData(
            types: bpTypes,
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024, 1, 2),
          ),
        );
        async.flushMicrotasks();
        verify(() => mockHealthService.requestAuthorization(any())).called(1);

        mobileImport.fetchHealthDataDelta(
          'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
        );
        async.flushMicrotasks();
        verifyNever(() => mockHealthService.requestAuthorization(any()));
      });
    });
  });

  group('delta type mapping', () {
    test('maps BLOOD_PRESSURE to systolic and diastolic', () {
      fakeAsync((async) {
        final mobileImport = createMobileHealthImport();

        when(
          () => mockJournalDb.latestQuantitativeByType(any()),
        ).thenAnswer((_) async => null);
        stubHealthStore();

        mobileImport.fetchHealthDataDelta('BLOOD_PRESSURE');
        async.flushMicrotasks();

        // Twice: once to anchor the delta's start date, once to decide whether
        // an empty read means "nothing new" or "nothing ever".
        verify(
          () => mockJournalDb.latestQuantitativeByType(
            'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
          ),
        ).called(2);

        // Exactly one authorization request. It used to be two — the delta
        // path asked, then handed off to `fetchHealthData`, which asked again,
        // putting two HealthKit sheets back to back for one import.
        verify(
          () => mockHealthService.requestAuthorization([
            HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
            HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
          ]),
        ).called(1);
      });
    });

    test('maps BODY_MASS_INDEX to WEIGHT', () {
      fakeAsync((async) {
        final mobileImport = createMobileHealthImport();

        when(
          () => mockJournalDb.latestQuantitativeByType(any()),
        ).thenAnswer((_) async => null);
        stubHealthStore();

        mobileImport.fetchHealthDataDelta('BODY_MASS_INDEX');
        async.flushMicrotasks();

        verify(
          () => mockJournalDb.latestQuantitativeByType('HealthDataType.WEIGHT'),
        ).called(2);
        // Weight is authorized with the rest of the body-measurement family:
        // the four are one switch to the user, and asking per type is what put
        // several sheets in a row in front of one dashboard.
        verify(
          () => mockHealthService.requestAuthorization(bodyMeasurementTypes),
        ).called(1);
      });
    });

    test('the composite map documents exactly these expansions', () {
      expect(HealthImport.compositeStorageTypes, {
        'BLOOD_PRESSURE': [
          'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
          'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
        ],
        'BODY_MASS_INDEX': ['HealthDataType.WEIGHT'],
        'HealthDataType.SLEEP_ASLEEP': [
          'HealthDataType.SLEEP_ASLEEP',
          'HealthDataType.SLEEP_LIGHT',
          'HealthDataType.SLEEP_DEEP',
          'HealthDataType.SLEEP_REM',
        ],
      });
    });

    test('should use latest entry dateFrom as fetch start', () {
      fakeAsync((async) {
        final mobileImport = createMobileHealthImport();
        final latestDate = DateTime(2024, 6, 15);

        when(() => mockJournalDb.latestQuantitativeByType(any())).thenAnswer(
          (_) async => QuantitativeEntry(
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
          ),
        );
        stubHealthStore();

        mobileImport.fetchHealthDataDelta('HealthDataType.HEART_RATE');
        async.flushMicrotasks();

        verify(
          () => mockHealthService.getHealthDataFromTypes(
            types: [HealthDataType.HEART_RATE],
            startTime: latestDate,
            endTime: any(named: 'endTime'),
          ),
        ).called(1);
      });
    });

    test('uses the default fetch duration when nothing is stored yet', () {
      fakeAsync((async) {
        final mobileImport = createMobileHealthImport();

        when(
          () => mockJournalDb.latestQuantitativeByType(any()),
        ).thenAnswer((_) async => null);
        stubHealthStore();

        mobileImport.fetchHealthDataDelta('HealthDataType.WEIGHT');
        async.flushMicrotasks();

        final captured = verify(
          () => mockHealthService.getHealthDataFromTypes(
            types: any(named: 'types'),
            startTime: captureAny(named: 'startTime'),
            endTime: any(named: 'endTime'),
          ),
        ).captured;

        expect(
          captured.single,
          clock.now().subtract(const Duration(days: 90)),
        );
      });
    });

    test('skips the fetch when auth is denied for a non-cumulative type', () {
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

    test('routes cumulative types through the activity importer', () {
      fakeAsync((async) {
        final mobileImport = createMobileHealthImport();

        when(
          () => mockJournalDb.latestQuantitativeByType(any()),
        ).thenAnswer((_) async => null);
        stubHealthStore();

        mobileImport.fetchHealthDataDelta('cumulative_step_count');
        async.flushMicrotasks();

        verify(
          () => mockJournalDb.latestQuantitativeByType('cumulative_step_count'),
        ).called(2);
        verify(
          () => mockHealthService.requestAuthorization(activityTypes),
        ).called(1);
      });
    });

    // A band that syncs its day overnight lands yesterday's final total after
    // yesterday already has a row. A delta that only looked from the newest
    // stored day forward never re-read it, so the dashboards kept the phone's
    // bedtime count until a manual import.
    test(
      'a cumulative delta re-reads the day before the newest stored one',
      () {
        fakeAsync((async) {
          final mobileImport = createMobileHealthImport();
          final now = DateTime(2024, 1, 10, 9);
          final latestDay = DateTime(2024, 1, 10);

          when(
            () => mockJournalDb.latestQuantitativeByType(any()),
          ).thenAnswer(
            (_) async => QuantitativeEntry(
              data: QuantitativeData.cumulativeQuantityData(
                dateFrom: latestDay,
                dateTo: DateTime(2024, 1, 10, 8),
                value: 1200,
                dataType: 'cumulative_step_count',
                unit: 'count',
              ),
              meta: Metadata(
                id: 'latest',
                createdAt: latestDay,
                updatedAt: latestDay,
                dateFrom: latestDay,
                dateTo: DateTime(2024, 1, 10, 8),
              ),
            ),
          );
          stubHealthStore();

          withClock(Clock.fixed(now), () {
            mobileImport.fetchHealthDataDelta('cumulative_step_count');
            async.flushMicrotasks();
          });

          verify(
            () => mockHealthService.getTotalStepsInInterval(
              DateTime(2024, 1, 9),
              DateTime(2024, 1, 9, 23, 59, 59, 999),
            ),
          ).called(1);
          verify(
            () => mockHealthService.getTotalStepsInInterval(
              latestDay,
              DateTime(2024, 1, 10, 23, 59, 59, 999),
            ),
          ).called(1);
          verifyNever(
            () => mockHealthService.getTotalStepsInInterval(
              DateTime(2024, 1, 8),
              any(),
            ),
          );
        });
      },
    );

    // Silently importing nothing is what made a dashboard configured for a
    // retired type look like a broken import rather than stale configuration.
    test('an unresolvable type is reported, not silently skipped', () {
      fakeAsync((async) {
        final mobileImport = createMobileHealthImport();

        when(
          () => mockJournalDb.latestQuantitativeByType(any()),
        ).thenAnswer((_) async => null);
        stubHealthStore();

        mobileImport.fetchHealthDataDelta('HealthDataType.NO_SUCH_TYPE');
        async.flushMicrotasks();

        verifyNever(() => mockHealthService.requestAuthorization(any()));
        verify(
          () => mockDomainLogger.error(
            LogDomain.health,
            any<Object>(that: isA<StateError>()),
            subDomain: 'fetchHealthDataDelta',
          ),
        ).called(1);
      });
    });
  });

  group('getActivityHealthData', () {
    test('reports unsupportedPlatform on desktop', () async {
      final result = await healthImport.getActivityHealthData(
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024, 1, 2),
      );

      expect(result.status, HealthImportStatus.unsupportedPlatform);
      verifyNever(() => mockHealthService.requestAuthorization(any()));
    });

    test('reports permissionDenied when authorization is refused', () async {
      final mobileImport = createMobileHealthImport();

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => false);

      final result = await mobileImport.getActivityHealthData(
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024, 1, 2),
      );

      expect(result.status, HealthImportStatus.permissionDenied);
      verifyNever(
        () => mockHealthService.getTotalStepsInInterval(any(), any()),
      );
    });

    group('an all-zero range that may be a permission problem', () {
      test(
        'is reported as noDataOrAccess when nothing was ever stored',
        () async {
          final mobileImport = createMobileHealthImport();
          stubHealthStore();
          when(
            () => mockJournalDb.latestQuantitativeByType(any()),
          ).thenAnswer((_) async => null);

          final result = await mobileImport.getActivityHealthData(
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024, 1, 2),
          );

          expect(result.status, HealthImportStatus.noDataOrAccess);
        },
      );

      test('writes no fabricated zero-step days', () async {
        final mobileImport = createMobileHealthImport();
        stubHealthStore();
        when(
          () => mockJournalDb.latestQuantitativeByType(any()),
        ).thenAnswer((_) async => null);

        await mobileImport.getActivityHealthData(
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024, 1, 2),
        );

        // The check happens before the write: a range Lotti was not allowed to
        // read must not leave "0 steps" entries behind, which would then chart
        // as real days and mask the problem forever after.
        verifyNever(() => mockPersistenceLogic.createQuantitativeEntry(any()));
      });

      test('is an ordinary import once history exists', () async {
        final mobileImport = createMobileHealthImport();
        stubHealthStore();
        stubStoredHistory();

        final result = await mobileImport.getActivityHealthData(
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024, 1, 2),
        );

        expect(result.status, HealthImportStatus.imported);
      });

      test('is not claimed when a single day read above zero', () async {
        final mobileImport = createMobileHealthImport();
        stubHealthStore();
        when(
          () => mockJournalDb.latestQuantitativeByType(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockHealthService.getTotalStepsInInterval(any(), any()),
        ).thenAnswer((_) async => 1);

        final result = await mobileImport.getActivityHealthData(
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024, 1, 2),
        );

        expect(result.status, HealthImportStatus.imported);
      });

      test('is never claimed when the platform confirmed access', () async {
        final mobileImport = createMobileHealthImport();
        stubHealthStore();
        when(
          () => mockHealthService.hasPermissions(any()),
        ).thenAnswer((_) async => true);

        final result = await mobileImport.getActivityHealthData(
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024, 1, 2),
        );

        expect(result.status, HealthImportStatus.imported);
      });
    });

    test('writes one entry per day per metric and counts them', () async {
      final mobileImport = createMobileHealthImport();
      stubHealthStore();
      when(
        () => mockHealthService.getTotalStepsInInterval(any(), any()),
      ).thenAnswer((_) async => 5000);

      final result = await mobileImport.getActivityHealthData(
        dateFrom: DateTime(2024, 3),
        dateTo: DateTime(2024, 3, 2),
      );

      // 2 days × 3 metrics (steps, flights, distance)
      expect(result.sampleCount, 6);
      verify(
        () => mockPersistenceLogic.createQuantitativeEntry(any()),
      ).called(6);
    });

    test('reports failed and logs when the health store throws', () async {
      final mobileImport = createMobileHealthImport();
      final failure = Exception('steps unavailable');

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockHealthService.getTotalStepsInInterval(any(), any()),
      ).thenThrow(failure);

      final result = await mobileImport.getActivityHealthData(
        dateFrom: DateTime(2024, 3),
        dateTo: DateTime(2024, 3, 2),
      );

      expect(result.status, HealthImportStatus.failed);
      expect(result.error, same(failure));
      verify(
        () => mockDomainLogger.error(
          LogDomain.health,
          same(failure),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'getActivityHealthData',
        ),
      ).called(1);
    });
  });

  group('getWorkoutsHealthData', () {
    test('reports unsupportedPlatform on desktop', () async {
      final result = await healthImport.getWorkoutsHealthData(
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024, 1, 2),
      );

      expect(result.status, HealthImportStatus.unsupportedPlatform);
      verifyNever(() => mockHealthService.requestAuthorization(any()));
      verifyNever(() => mockPersistenceLogic.createWorkoutEntry(any()));
    });

    test('reports permissionDenied when authorization is refused', () async {
      final mobileImport = createMobileHealthImport();

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => false);

      final result = await mobileImport.getWorkoutsHealthData(
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024, 1, 2),
      );

      expect(result.status, HealthImportStatus.permissionDenied);
      verifyNever(() => mockPersistenceLogic.createWorkoutEntry(any()));
    });

    group('an empty read that may be a permission problem', () {
      test('is reported as noDataOrAccess when none was ever stored', () async {
        final mobileImport = createMobileHealthImport();
        stubHealthStore();
        when(() => mockJournalDb.latestWorkout()).thenAnswer((_) async => null);

        final result = await mobileImport.getWorkoutsHealthData(
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024, 1, 2),
        );

        expect(result.status, HealthImportStatus.noDataOrAccess);
      });

      test('is an ordinary empty import once a workout exists', () async {
        final mobileImport = createMobileHealthImport();
        stubHealthStore();
        final at = DateTime(2024);
        when(() => mockJournalDb.latestWorkout()).thenAnswer(
          (_) async => WorkoutEntry(
            data: WorkoutData(
              dateFrom: at,
              dateTo: at,
              workoutType: 'running',
              energy: null,
              distance: null,
              source: null,
              id: 'workout',
            ),
            meta: Metadata(
              id: 'workout',
              createdAt: at,
              updatedAt: at,
              dateFrom: at,
              dateTo: at,
            ),
          ),
        );

        final result = await mobileImport.getWorkoutsHealthData(
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024, 1, 2),
        );

        expect(result.status, HealthImportStatus.imported);
        expect(result.sampleCount, 0);
      });

      test('is never claimed when the platform confirmed access', () async {
        final mobileImport = createMobileHealthImport();
        stubHealthStore();
        when(
          () => mockHealthService.hasPermissions(any()),
        ).thenAnswer((_) async => true);

        final result = await mobileImport.getWorkoutsHealthData(
          dateFrom: DateTime(2024),
          dateTo: DateTime(2024, 1, 2),
        );

        expect(result.status, HealthImportStatus.imported);
        verifyNever(() => mockJournalDb.latestWorkout());
      });
    });

    test('maps a workout data point onto a workout entry', () async {
      final mobileImport = createMobileHealthImport();
      final dateFrom = DateTime(2024, 3, 1, 8);
      final dateTo = DateTime(2024, 3, 1, 9);

      stubHealthStore(
        dataPoints: [
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

      final result = await mobileImport.getWorkoutsHealthData(
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      expect(result.sampleCount, 1);

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

      stubHealthStore(
        dataPoints: [
          makeNumericDataPoint(
            type: HealthDataType.WORKOUT,
            value: 100,
            dateFrom: dateFrom,
            dateTo: dateTo,
          ),
        ],
      );

      final result = await mobileImport.getWorkoutsHealthData(
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      expect(result.sampleCount, 0);
      verifyNever(() => mockPersistenceLogic.createWorkoutEntry(any()));
    });

    test('should process multiple workouts in reverse order', () async {
      final mobileImport = createMobileHealthImport();
      final date1From = DateTime(2024, 3, 1, 8);
      final date2From = DateTime(2024, 3, 1, 16);

      stubHealthStore(
        dataPoints: [
          for (final (uuid, type, from) in [
            ('workout-1', HealthWorkoutActivityType.RUNNING, date1From),
            ('workout-2', HealthWorkoutActivityType.YOGA, date2From),
          ])
            HealthDataPoint(
              uuid: uuid,
              value: WorkoutHealthValue(
                workoutActivityType: type,
                totalEnergyBurned: 200,
                totalDistance: 3000,
              ),
              type: HealthDataType.WORKOUT,
              unit: HealthDataUnit.NO_UNIT,
              dateFrom: from,
              dateTo: from.add(const Duration(hours: 1)),
              sourcePlatform: HealthPlatformType.appleHealth,
              sourceDeviceId: 'test',
              sourceId: 'test',
              sourceName: 'test',
            ),
        ],
      );

      await mobileImport.getWorkoutsHealthData(
        dateFrom: date1From,
        dateTo: date2From.add(const Duration(hours: 1)),
      );

      final captured = verify(
        () => mockPersistenceLogic.createWorkoutEntry(captureAny()),
      ).captured;

      expect(captured.length, 2);
      expect((captured[0] as WorkoutData).workoutType, 'YOGA');
      expect((captured[1] as WorkoutData).workoutType, 'RUNNING');
    });

    test('reports failed and logs when the health store throws', () async {
      final mobileImport = createMobileHealthImport();
      final failure = Exception('workouts unavailable');

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockHealthService.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenThrow(failure);

      final result = await mobileImport.getWorkoutsHealthData(
        dateFrom: DateTime(2024, 3),
        dateTo: DateTime(2024, 3, 2),
      );

      expect(result.status, HealthImportStatus.failed);
      verify(
        () => mockDomainLogger.error(
          LogDomain.health,
          same(failure),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'getWorkoutsHealthData',
        ),
      ).called(1);
    });
  });

  group('getWorkoutsHealthDataDelta', () {
    test('reports unsupportedPlatform on desktop', () async {
      final result = await healthImport.getWorkoutsHealthDataDelta();

      expect(result.status, HealthImportStatus.unsupportedPlatform);
      verifyNever(() => mockJournalDb.latestWorkout());
      verifyNever(() => mockHealthService.requestAuthorization(any()));
    });

    test('refuses to overlap with a run already in flight', () async {
      final mobileImport = createMobileHealthImport()
        ..workoutImportRunning = true;

      final result = await mobileImport.getWorkoutsHealthDataDelta();

      expect(result.sampleCount, 0);
      verifyNever(() => mockJournalDb.latestWorkout());
      // The in-flight run owns the flag; the refused call must not clear it.
      expect(mobileImport.workoutImportRunning, isTrue);
    });

    test('should use latest workout dateFrom as fetch start', () async {
      final mobileImport = createMobileHealthImport();
      final latestDate = DateTime(2024, 6, 15, 10);

      when(() => mockJournalDb.latestWorkout()).thenAnswer(
        (_) async => WorkoutEntry(
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
        ),
      );
      stubHealthStore();

      await mobileImport.getWorkoutsHealthDataDelta();

      verify(
        () => mockHealthService.getHealthDataFromTypes(
          types: [HealthDataType.WORKOUT],
          startTime: latestDate,
          endTime: any(named: 'endTime'),
        ),
      ).called(1);
      expect(mobileImport.workoutImportRunning, false);
    });

    test('uses the default duration when no workout is stored yet', () {
      fakeAsync((async) {
        final mobileImport = createMobileHealthImport();

        when(() => mockJournalDb.latestWorkout()).thenAnswer((_) async => null);
        stubHealthStore();

        mobileImport.getWorkoutsHealthDataDelta();
        async.flushMicrotasks();

        final captured = verify(
          () => mockHealthService.getHealthDataFromTypes(
            types: any(named: 'types'),
            startTime: captureAny(named: 'startTime'),
            endTime: any(named: 'endTime'),
          ),
        ).captured;

        expect(
          captured.single,
          clock.now().subtract(const Duration(days: 90)),
        );
      });
    });

    test('clears the guard flag when authorization is refused', () async {
      final mobileImport = createMobileHealthImport();

      when(() => mockJournalDb.latestWorkout()).thenAnswer((_) async => null);
      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => false);

      await mobileImport.getWorkoutsHealthDataDelta();

      expect(mobileImport.workoutImportRunning, false);
    });

    // The workout-deadlock regression: the guard flag used to be set before an
    // unguarded fetch and cleared only on the line after it, so a throw left it
    // set forever and every later workout import returned early — silently, for
    // the rest of the session.
    test('clears the guard flag and reports when the fetch fails', () async {
      final mobileImport = createMobileHealthImport();

      when(() => mockJournalDb.latestWorkout()).thenAnswer((_) async => null);
      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockHealthService.getHealthDataFromTypes(
          types: any(named: 'types'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).thenThrow(Exception('health fetch failed'));

      final result = await mobileImport.getWorkoutsHealthDataDelta();

      expect(result.status, HealthImportStatus.failed);
      expect(mobileImport.workoutImportRunning, isFalse);
    });

    test('a later delta still runs after an earlier one failed', () async {
      final mobileImport = createMobileHealthImport();

      when(() => mockJournalDb.latestWorkout()).thenThrow(Exception('db down'));

      final first = await mobileImport.getWorkoutsHealthDataDelta();
      expect(first.status, HealthImportStatus.failed);
      expect(mobileImport.workoutImportRunning, isFalse);

      when(() => mockJournalDb.latestWorkout()).thenAnswer((_) async => null);
      stubHealthStore();

      final second = await mobileImport.getWorkoutsHealthDataDelta();
      expect(second.status, isNot(HealthImportStatus.failed));
      verify(
        () => mockHealthService.getHealthDataFromTypes(
          types: workoutTypes,
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        ),
      ).called(1);
    });

    test('a failing DB read is logged against the delta sub-domain', () async {
      final mobileImport = createMobileHealthImport();
      final failure = Exception('db down');
      when(() => mockJournalDb.latestWorkout()).thenThrow(failure);

      await mobileImport.getWorkoutsHealthDataDelta();

      verify(
        () => mockDomainLogger.error(
          LogDomain.health,
          same(failure),
          stackTrace: any(named: 'stackTrace'),
          subDomain: 'getWorkoutsHealthDataDelta',
        ),
      ).called(1);
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

    /// Pins the platform flags for the duration of one test.
    void asPlatform({bool ios = false, bool android = false}) {
      final originalIsIOS = platform.isIOS;
      final originalIsAndroid = platform.isAndroid;
      platform.isIOS = ios;
      platform.isAndroid = android;
      addTearDown(() {
        platform.isIOS = originalIsIOS;
        platform.isAndroid = originalIsAndroid;
      });
    }

    // `activityRecognition` and `location` are Health Connect's companion
    // permissions on Android. On every other platform the default handler now
    // returns without asking: iOS has no strategy for `activityRecognition` at
    // all (it resolves to permanently-denied without ever prompting), and
    // `location` would raise an unrelated location prompt in front of the
    // HealthKit sheet — two system dialogs racing for one tap.
    test('asks for nothing on a non-Android platform', () async {
      final recordingHandler = _RecordingPermissionHandler();
      final originalHandler = PermissionHandlerPlatform.instance;
      PermissionHandlerPlatform.instance = recordingHandler;
      addTearDown(() => PermissionHandlerPlatform.instance = originalHandler);

      final mobileImport = createMobileHealthImportWithDefaultPermissions();

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => false);

      await mobileImport.getActivityHealthData(
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024, 1, 2),
      );

      expect(recordingHandler.requestedPermissions, isEmpty);
      // The health authorization itself still runs — only the companion
      // Android permissions are skipped.
      verify(() => mockHealthService.requestAuthorization(any())).called(1);
    });

    test('asks for both companion permissions on Android', () async {
      asPlatform(android: true);

      final recordingHandler = _RecordingPermissionHandler();
      final originalHandler = PermissionHandlerPlatform.instance;
      PermissionHandlerPlatform.instance = recordingHandler;
      addTearDown(() => PermissionHandlerPlatform.instance = originalHandler);

      final mobileImport = createMobileHealthImportWithDefaultPermissions();

      when(
        () => mockHealthService.requestAuthorization(any()),
      ).thenAnswer((_) async => false);

      await mobileImport.getActivityHealthData(
        dateFrom: DateTime(2024),
        dateTo: DateTime(2024, 1, 2),
      );

      // Each is requested on its own, in this order.
      expect(recordingHandler.requestedPermissions, [
        [Permission.activityRecognition],
        [Permission.location],
      ]);
    });
  });

  group('platform metadata stamped onto samples', () {
    /// Builds a mobile import with the platform flags pinned, so the
    /// device-info branch under test is the one that runs.
    HealthImport importOn({bool ios = false, bool android = false}) {
      final originalIsIOS = platform.isIOS;
      final originalIsAndroid = platform.isAndroid;
      platform.isIOS = ios;
      platform.isAndroid = android;
      addTearDown(() {
        platform.isIOS = originalIsIOS;
        platform.isAndroid = originalIsAndroid;
      });
      return createMobileHealthImport();
    }

    /// Persists one sample and returns what was written.
    Future<DiscreteQuantityData> importOneSample(HealthImport import) async {
      stubHealthStore(
        dataPoints: [
          makeNumericDataPoint(
            type: HealthDataType.HEART_RATE,
            value: 60,
            dateFrom: DateTime(2024, 3),
            dateTo: DateTime(2024, 3),
          ),
        ],
      );

      await import.fetchHealthData(
        types: [HealthDataType.HEART_RATE],
        dateFrom: DateTime(2024, 3),
        dateTo: DateTime(2024, 3, 2),
      );

      return verify(
            () => mockPersistenceLogic.createQuantitativeEntry(captureAny()),
          ).captured.first
          as DiscreteQuantityData;
    }

    test('stamps IOS and the hardware identifier on iOS', () async {
      final utsname = MockIosUtsname();
      when(() => utsname.machine).thenReturn('iPhone16,2');
      final iosInfo = MockIosDeviceInfo();
      when(() => iosInfo.utsname).thenReturn(utsname);
      when(() => mockDeviceInfoPlugin.iosInfo).thenAnswer((_) async => iosInfo);

      final entry = await importOneSample(importOn(ios: true));

      expect(entry.platformType, 'IOS');
      expect(entry.deviceType, 'iPhone16,2');
    });

    test('stamps ANDROID and the model on Android', () async {
      final androidInfo = MockAndroidDeviceInfo();
      when(() => androidInfo.model).thenReturn('Pixel 8');
      when(
        () => mockDeviceInfoPlugin.androidInfo,
      ).thenAnswer((_) async => androidInfo);

      final entry = await importOneSample(importOn(android: true));

      expect(entry.platformType, 'ANDROID');
      expect(entry.deviceType, 'Pixel 8');
    });

    // Device model is descriptive metadata, not something an import depends
    // on: losing it must not take the import with it. It used to be resolved
    // in an unawaited constructor call, where a throw became an unhandled
    // async error.
    test(
      'a failing device-info lookup is logged, and the import proceeds',
      () async {
        final failure = Exception('device info channel unavailable');
        when(() => mockDeviceInfoPlugin.iosInfo).thenThrow(failure);

        final entry = await importOneSample(importOn(ios: true));

        expect(entry.platformType, 'IOS');
        expect(entry.deviceType, isNull);
        expect(entry.value, 60);
        verify(
          () => mockDomainLogger.error(
            LogDomain.health,
            same(failure),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'resolvePlatform',
          ),
        ).called(1);
      },
    );

    test('stamps an empty platform and no device on desktop', () async {
      final entry = await importOneSample(importOn());

      expect(entry.platformType, '');
      expect(entry.deviceType, isNull);
      verifyNever(() => mockDeviceInfoPlugin.iosInfo);
      verifyNever(() => mockDeviceInfoPlugin.androidInfo);
    });
  });

  group('top-level type lists', () {
    test('sleepTypes contains expected types', () {
      expect(sleepTypes, [
        HealthDataType.SLEEP_IN_BED,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_REM,
        HealthDataType.SLEEP_AWAKE,
      ]);
    });

    test('bpTypes contains systolic and diastolic', () {
      expect(bpTypes, [
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
      ]);
    });

    test('heartRateTypes contains expected types', () {
      expect(heartRateTypes, [
        HealthDataType.RESTING_HEART_RATE,
        HealthDataType.WALKING_HEART_RATE,
        HealthDataType.HEART_RATE_VARIABILITY_SDNN,
      ]);
    });

    test('bodyMeasurementTypes contains expected types', () {
      expect(bodyMeasurementTypes, [
        HealthDataType.WEIGHT,
        HealthDataType.BODY_FAT_PERCENTAGE,
        HealthDataType.BODY_MASS_INDEX,
        HealthDataType.HEIGHT,
      ]);
    });

    test('activityTypes contains expected types', () {
      expect(activityTypes, [
        HealthDataType.STEPS,
        HealthDataType.FLIGHTS_CLIMBED,
        HealthDataType.DISTANCE_WALKING_RUNNING,
      ]);
    });

    test('the five type lists are pairwise disjoint', () {
      final lists = <String, List<HealthDataType>>{
        'sleepTypes': sleepTypes,
        'bpTypes': bpTypes,
        'heartRateTypes': heartRateTypes,
        'bodyMeasurementTypes': bodyMeasurementTypes,
        'activityTypes': activityTypes,
      };

      for (final MapEntry(key: name, value: list) in lists.entries) {
        expect(list.toSet().length, list.length, reason: '$name has dupes');
      }

      final entries = lists.entries.toList();
      for (var i = 0; i < entries.length; i++) {
        for (var j = i + 1; j < entries.length; j++) {
          final overlap = entries[i].value.toSet().intersection(
            entries[j].value.toSet(),
          );
          expect(
            overlap,
            isEmpty,
            reason: '${entries[i].key} and ${entries[j].key} share $overlap',
          );
        }
      }
    });

    test('every listed type is a type the plugin can actually read', () {
      for (final list in [
        sleepTypes,
        bpTypes,
        heartRateTypes,
        bodyMeasurementTypes,
        activityTypes,
      ]) {
        for (final type in list) {
          expect(
            dataTypeKeysIOS,
            contains(type),
            reason: '$type is not readable on iOS',
          );
        }
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Additive Glados property groups for pure methods on HealthImport.
  // healthImport is already initialized by setUp() above; the pure functions
  // under test do not use any injected dependency.
  // ---------------------------------------------------------------------------

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
        expect(result, equals(expected), reason: 'values=$values');
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
        expect(
          healthImport.getDays(dateFrom, dateTo).length,
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
        for (final day in healthImport.getDays(dateFrom, dateTo)) {
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
        final day = DateTime(2024).add(Duration(days: offsetDays));
        final result = healthImport.getDays(day, day);
        expect(result.length, equals(1));
        expect(result.single, equals(DateTime(day.year, day.month, day.day)));
      },
      tags: 'glados',
    );
  });

  group('addActivityEntries — Glados day-boundary properties', () {
    // `addActivityEntries` derives each entry's [dateTo] as
    // `dayStart + 1 day - 1 ms`, then caps it to `clock.now()` when that end
    // overruns the present. These are pure time-boundary invariants over the
    // realistic input domain: `getActivityHealthData` only ever feeds days at
    // or before the present (`fetchAndProcessActivityDataForDay` skips days
    // that are not `dateFrom.isBefore(now)`), so offsets span `[-10, 0]` —
    // completed past days (no cap) plus the in-progress current day (cap to
    // now), exercising both branches of the `isAfter(now)` conditional.
    glados.Glados<int>(
      glados.IntAnys(glados.any).intInRange(-10, 1),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'persisted dateTo stays within [dayStart, dayStart + 1 day) and never '
      'exceeds now',
      (dayOffsetFromNow) async {
        // Pin "now" to a deterministic, non-midnight instant so the cap branch
        // is reachable for the current day.
        final now = DateTime(2024, 3, 15, 14, 30, 45, 123);

        await withClock(Clock.fixed(now), () async {
          final mobileImport = createMobileHealthImport();
          final dayStart = DateTime(2024, 3, 15 + dayOffsetFromNow);

          final captured = <CumulativeQuantityData>[];
          when(
            () => mockPersistenceLogic.createQuantitativeEntry(any()),
          ).thenAnswer((invocation) async {
            captured.add(
              invocation.positionalArguments.first as CumulativeQuantityData,
            );
            return null;
          });

          await mobileImport.addActivityEntries(
            {dayStart: 42.0},
            'cumulative_step_count',
            'count',
          );

          expect(captured, hasLength(1), reason: 'offset=$dayOffsetFromNow');
          final entry = captured.single;
          final nextMidnight = dayStart.add(const Duration(days: 1));

          // dateFrom is always the start of the day, untouched by the cap.
          expect(entry.dateFrom, dayStart, reason: 'offset=$dayOffsetFromNow');
          // dateTo never reaches the next midnight (strict upper bound).
          expect(
            entry.dateTo.isBefore(nextMidnight),
            isTrue,
            reason: 'dateTo=${entry.dateTo} offset=$dayOffsetFromNow',
          );
          // dateTo never precedes the day it belongs to.
          expect(
            entry.dateTo.isBefore(dayStart),
            isFalse,
            reason: 'dateTo=${entry.dateTo} offset=$dayOffsetFromNow',
          );
          // The cap is honoured: dateTo never overruns the present.
          expect(
            entry.dateTo.isAfter(now),
            isFalse,
            reason: 'dateTo=${entry.dateTo} now=$now',
          );
          // The value is passed through verbatim, regardless of the cap.
          expect(entry.value, 42.0, reason: 'offset=$dayOffsetFromNow');
        });
      },
      tags: 'glados',
    );

    test(
      'caps dateTo to now for the in-progress day, leaves past days full',
      () async {
        final now = DateTime(2024, 3, 15, 14, 30, 45, 123);

        await withClock(Clock.fixed(now), () async {
          final mobileImport = createMobileHealthImport();
          final today = DateTime(2024, 3, 15);
          final yesterday = DateTime(2024, 3, 14);

          final captured = <CumulativeQuantityData>[];
          when(
            () => mockPersistenceLogic.createQuantitativeEntry(any()),
          ).thenAnswer((invocation) async {
            captured.add(
              invocation.positionalArguments.first as CumulativeQuantityData,
            );
            return null;
          });

          await mobileImport.addActivityEntries(
            {yesterday: 10.0, today: 20.0},
            'cumulative_step_count',
            'count',
          );

          // Entries are sorted ascending by day, so yesterday comes first.
          expect(captured.map((e) => e.dateFrom).toList(), [yesterday, today]);
          // The completed day keeps its full end-of-day boundary.
          expect(
            captured[0].dateTo,
            yesterday
                .add(const Duration(days: 1))
                .subtract(const Duration(milliseconds: 1)),
          );
          // The in-progress day is capped to the current instant.
          expect(captured[1].dateTo, now);
        });
      },
    );
  });
}
