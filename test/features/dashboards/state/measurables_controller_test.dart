import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/state/measurables_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

void main() {
  late MockJournalDb mockJournalDb;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockUpdateNotifications mockUpdateNotifications;

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockUpdateNotifications = MockUpdateNotifications();

    // Reset GetIt for each test
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    if (getIt.isRegistered<EntitiesCacheService>()) {
      getIt.unregister<EntitiesCacheService>();
    }
    if (getIt.isRegistered<UpdateNotifications>()) {
      getIt.unregister<UpdateNotifications>();
    }

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);
  });

  tearDown(() {
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
    if (getIt.isRegistered<EntitiesCacheService>()) {
      getIt.unregister<EntitiesCacheService>();
    }
    if (getIt.isRegistered<UpdateNotifications>()) {
      getIt.unregister<UpdateNotifications>();
    }
  });

  group('MeasurableDataTypeController', () {
    test('returns cached data type when available', () async {
      const testId = 'test-measurable-id';
      final testDataType = MeasurableDataType(
        id: testId,
        displayName: 'Test Measurable',
        description: 'A test measurable',
        unitName: 'units',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
        version: 1,
        aggregationType: AggregationType.dailySum,
      );

      when(() => mockEntitiesCacheService.getDataTypeById(testId))
          .thenReturn(testDataType);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container
          .read(measurableDataTypeControllerProvider(testId).future);

      expect(result, equals(testDataType));
      expect(result?.id, testId);
      expect(result?.displayName, 'Test Measurable');
      verify(() => mockEntitiesCacheService.getDataTypeById(testId)).called(1);
    });

    test('falls back to database when cache returns null', () async {
      const testId = 'test-measurable-id';
      final testDataType = MeasurableDataType(
        id: testId,
        displayName: 'DB Measurable',
        description: 'From database',
        unitName: 'units',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
        version: 1,
        aggregationType: AggregationType.dailyMax,
      );

      when(() => mockEntitiesCacheService.getDataTypeById(testId))
          .thenReturn(null);
      when(() => mockJournalDb.getMeasurableDataTypeById(testId))
          .thenAnswer((_) async => testDataType);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container
          .read(measurableDataTypeControllerProvider(testId).future);

      expect(result, equals(testDataType));
      expect(result?.displayName, 'DB Measurable');
      verify(() => mockEntitiesCacheService.getDataTypeById(testId)).called(1);
      verify(() => mockJournalDb.getMeasurableDataTypeById(testId)).called(1);
    });

    test('returns null when not found in cache or database', () async {
      const testId = 'non-existent-id';

      when(() => mockEntitiesCacheService.getDataTypeById(testId))
          .thenReturn(null);
      when(() => mockJournalDb.getMeasurableDataTypeById(testId))
          .thenAnswer((_) async => null);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container
          .read(measurableDataTypeControllerProvider(testId).future);

      expect(result, isNull);
    });
  });

  group('AggregationTypeController', () {
    test('returns dashboard-defined aggregation type when provided', () async {
      const params = (
        measurableDataTypeId: 'test-id',
        dashboardDefinedAggregationType: AggregationType.dailyMax,
      );

      when(() => mockEntitiesCacheService.getDataTypeById('test-id'))
          .thenReturn(null);
      when(() => mockJournalDb.getMeasurableDataTypeById('test-id'))
          .thenAnswer((_) async => null);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container
          .read(aggregationTypeControllerProvider(params).future);

      expect(result, AggregationType.dailyMax);
    });

    test('returns data type aggregation type when dashboard type is null',
        () async {
      const params = (
        measurableDataTypeId: 'test-id',
        dashboardDefinedAggregationType: null,
      );

      final testDataType = MeasurableDataType(
        id: 'test-id',
        displayName: 'Test',
        description: 'Test',
        unitName: 'units',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        vectorClock: null,
        version: 1,
        aggregationType: AggregationType.hourlySum,
      );

      when(() => mockEntitiesCacheService.getDataTypeById('test-id'))
          .thenReturn(testDataType);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container
          .read(aggregationTypeControllerProvider(params).future);

      expect(result, AggregationType.hourlySum);
    });

    test('defaults to dailySum when no aggregation type specified', () async {
      const params = (
        measurableDataTypeId: 'test-id',
        dashboardDefinedAggregationType: null,
      );

      when(() => mockEntitiesCacheService.getDataTypeById('test-id'))
          .thenReturn(null);
      when(() => mockJournalDb.getMeasurableDataTypeById('test-id'))
          .thenAnswer((_) async => null);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container
          .read(aggregationTypeControllerProvider(params).future);

      expect(result, AggregationType.dailySum);
    });
  });
}
