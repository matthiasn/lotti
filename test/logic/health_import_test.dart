import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
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

void main() {
  late HealthImport healthImport;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockJournalDb mockJournalDb;
  late MockHealthService mockHealthService;
  late MockDeviceInfoPlugin mockDeviceInfoPlugin;

  setUpAll(() {
    registerFallbackValue(FakeQuantitativeData());
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
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
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
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
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
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
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
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
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
}
