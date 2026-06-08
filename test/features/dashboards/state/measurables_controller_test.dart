import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/state/measurables_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';

void main() {
  late MockJournalDb mockJournalDb;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockUpdateNotifications mockUpdateNotifications;

  setUp(() async {
    mockJournalDb = MockJournalDb();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockUpdateNotifications = MockUpdateNotifications();

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(mockJournalDb)
          ..unregister<UpdateNotifications>()
          ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
          ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);
      },
    );
  });

  tearDown(tearDownTestGetIt);

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

      when(
        () => mockEntitiesCacheService.getDataTypeById(testId),
      ).thenReturn(testDataType);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        measurableDataTypeControllerProvider(testId).future,
      );

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

      when(
        () => mockEntitiesCacheService.getDataTypeById(testId),
      ).thenReturn(null);
      when(
        () => mockJournalDb.getMeasurableDataTypeById(testId),
      ).thenAnswer((_) async => testDataType);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        measurableDataTypeControllerProvider(testId).future,
      );

      expect(result, equals(testDataType));
      expect(result?.displayName, 'DB Measurable');
      verify(() => mockEntitiesCacheService.getDataTypeById(testId)).called(1);
      verify(() => mockJournalDb.getMeasurableDataTypeById(testId)).called(1);
    });

    test('returns null when not found in cache or database', () async {
      const testId = 'non-existent-id';

      when(
        () => mockEntitiesCacheService.getDataTypeById(testId),
      ).thenReturn(null);
      when(
        () => mockJournalDb.getMeasurableDataTypeById(testId),
      ).thenAnswer((_) async => null);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        measurableDataTypeControllerProvider(testId).future,
      );

      expect(result, isNull);
    });
  });

  group('AggregationTypeController', () {
    test('returns dashboard-defined aggregation type when provided', () async {
      const params = (
        measurableDataTypeId: 'test-id',
        dashboardDefinedAggregationType: AggregationType.dailyMax,
      );

      when(
        () => mockEntitiesCacheService.getDataTypeById('test-id'),
      ).thenReturn(null);
      when(
        () => mockJournalDb.getMeasurableDataTypeById('test-id'),
      ).thenAnswer((_) async => null);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        aggregationTypeControllerProvider(params).future,
      );

      expect(result, AggregationType.dailyMax);
    });

    test(
      'returns data type aggregation type when dashboard type is null',
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

        when(
          () => mockEntitiesCacheService.getDataTypeById('test-id'),
        ).thenReturn(testDataType);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        final result = await container.read(
          aggregationTypeControllerProvider(params).future,
        );

        expect(result, AggregationType.hourlySum);
      },
    );

    test('defaults to dailySum when no aggregation type specified', () async {
      const params = (
        measurableDataTypeId: 'test-id',
        dashboardDefinedAggregationType: null,
      );

      when(
        () => mockEntitiesCacheService.getDataTypeById('test-id'),
      ).thenReturn(null);
      when(
        () => mockJournalDb.getMeasurableDataTypeById('test-id'),
      ).thenAnswer((_) async => null);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        aggregationTypeControllerProvider(params).future,
      );

      expect(result, AggregationType.dailySum);
    });
  });

  group('MeasurableChartDataController', () {
    const typeId = 'chart-type-id';
    final rangeStart = DateTime(2024, 3, 10);
    final rangeEnd = DateTime(2024, 3, 17);

    MeasurementEntry makeEntry(DateTime ts, num value) {
      return buildMeasurementEntry(
        id: 'entry-${ts.millisecondsSinceEpoch}',
        timestamp: ts,
        value: value,
      );
    }

    test('returns measurements from db for given range', () async {
      final entry = makeEntry(DateTime(2024, 3, 12, 9), 42);

      final streamController = StreamController<Set<String>>.broadcast();
      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => streamController.stream);
      when(
        () => mockJournalDb.getMeasurementsByType(
          type: typeId,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
      ).thenAnswer((_) async => [entry]);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      addTearDown(streamController.close);

      final params = (
        measurableDataTypeId: typeId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final result = await container.read(
        measurableChartDataControllerProvider(params).future,
      );

      expect(result, hasLength(1));
      expect(result.first, equals(entry));
    });

    test('updates state when affected id arrives on update stream', () async {
      final entry1 = makeEntry(DateTime(2024, 3, 12, 9), 42);
      final entry2 = makeEntry(DateTime(2024, 3, 13, 9), 84);

      final streamController = StreamController<Set<String>>.broadcast();
      var callCount = 0;
      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => streamController.stream);
      when(
        () => mockJournalDb.getMeasurementsByType(
          type: typeId,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
      ).thenAnswer((_) async {
        callCount++;
        return callCount == 1 ? [entry1] : [entry1, entry2];
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);
      addTearDown(streamController.close);

      final params = (
        measurableDataTypeId: typeId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      // Read initial state.
      final initial = await container.read(
        measurableChartDataControllerProvider(params).future,
      );
      expect(initial, hasLength(1));

      // Emit an update that contains our type id — triggers _listen().
      streamController.add({typeId});
      await pumpEventQueue();

      final updated = await container.read(
        measurableChartDataControllerProvider(params).future,
      );
      expect(updated, hasLength(2));
    });

    test('ignores update stream events for unrelated ids', () async {
      final entry = makeEntry(DateTime(2024, 3, 12, 9), 42);

      final streamController = StreamController<Set<String>>.broadcast();
      var fetchCount = 0;
      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => streamController.stream);
      when(
        () => mockJournalDb.getMeasurementsByType(
          type: typeId,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
      ).thenAnswer((_) async {
        fetchCount++;
        return [entry];
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);
      addTearDown(streamController.close);

      final params = (
        measurableDataTypeId: typeId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      await container.read(
        measurableChartDataControllerProvider(params).future,
      );
      final countAfterBuild = fetchCount;

      // Emit an event for a different id — should NOT trigger a re-fetch.
      streamController.add({'other-id'});
      await pumpEventQueue();

      expect(fetchCount, equals(countAfterBuild));
    });
  });
}
