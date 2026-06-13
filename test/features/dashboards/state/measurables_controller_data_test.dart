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
import 'package:lotti/widgets/charts/utils.dart';
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

  group('MeasurableObservationsController', () {
    const typeId = 'obs-type-id';
    final rangeStart = DateTime(2024, 3, 10);
    final rangeEnd = DateTime(2024, 3, 17);

    MeasurementEntry makeObsEntry(DateTime ts, num value) {
      return buildMeasurementEntry(
        id: 'entry-${ts.millisecondsSinceEpoch}',
        timestamp: ts,
        value: value,
      );
    }

    void stubDataType(MeasurableDataType? dataType) {
      when(
        () => mockEntitiesCacheService.getDataTypeById(typeId),
      ).thenReturn(dataType);
      if (dataType == null) {
        when(
          () => mockJournalDb.getMeasurableDataTypeById(typeId),
        ).thenAnswer((_) async => null);
      }
    }

    void stubMeasurements(List<MeasurementEntry> entries) {
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
      ).thenAnswer((_) async => entries);
    }

    test(
      'aggregates with dailySum when aggregation type is dailySum',
      () async {
        stubDataType(null);
        final entry1 = makeObsEntry(DateTime(2024, 3, 12, 9), 30);
        final entry2 = makeObsEntry(DateTime(2024, 3, 12, 14), 20);
        stubMeasurements([entry1, entry2]);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        final params = (
          measurableDataTypeId: typeId,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          dashboardDefinedAggregationType: AggregationType.dailySum,
        );

        final result = await container.read(
          measurableObservationsControllerProvider(params).future,
        );

        // Both entries fall on 2024-03-12 → dailySum produces one bucket = 50
        final march12 = result.where(
          (o) =>
              o.dateTime.year == 2024 &&
              o.dateTime.month == 3 &&
              o.dateTime.day == 12,
        );
        expect(march12, hasLength(1));
        expect(march12.first.value, equals(50));
      },
    );

    test(
      'aggregates with dailyMax when aggregation type is dailyMax',
      () async {
        stubDataType(null);
        final entry1 = makeObsEntry(DateTime(2024, 3, 12, 9), 30);
        final entry2 = makeObsEntry(DateTime(2024, 3, 12, 14), 20);
        stubMeasurements([entry1, entry2]);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        final params = (
          measurableDataTypeId: typeId,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          dashboardDefinedAggregationType: AggregationType.dailyMax,
        );

        final result = await container.read(
          measurableObservationsControllerProvider(params).future,
        );

        final march12 = result.where(
          (o) =>
              o.dateTime.year == 2024 &&
              o.dateTime.month == 3 &&
              o.dateTime.day == 12,
        );
        expect(march12, hasLength(1));
        expect(march12.first.value, equals(30));
      },
    );

    test(
      'aggregates with dailyAvg when aggregation type is dailyAvg',
      () async {
        stubDataType(null);
        final entry1 = makeObsEntry(DateTime(2024, 3, 12, 9), 30);
        final entry2 = makeObsEntry(DateTime(2024, 3, 12, 14), 20);
        stubMeasurements([entry1, entry2]);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        final params = (
          measurableDataTypeId: typeId,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          dashboardDefinedAggregationType: AggregationType.dailyAvg,
        );

        final result = await container.read(
          measurableObservationsControllerProvider(params).future,
        );

        final march12 = result.where(
          (o) =>
              o.dateTime.year == 2024 &&
              o.dateTime.month == 3 &&
              o.dateTime.day == 12,
        );
        expect(march12, hasLength(1));
        expect(march12.first.value, equals(25));
      },
    );

    test(
      'aggregates with hourlySum when aggregation type is hourlySum',
      () async {
        stubDataType(null);
        final hourlySumRangeStart = DateTime(2024, 3, 12);
        final hourlySumRangeEnd = DateTime(2024, 3, 13);
        final entry1 = makeObsEntry(DateTime(2024, 3, 12, 9, 15), 10);
        final entry2 = makeObsEntry(DateTime(2024, 3, 12, 9, 45), 20);
        final entry3 = makeObsEntry(DateTime(2024, 3, 12, 10, 5), 5);

        final streamController = StreamController<Set<String>>.broadcast();
        when(
          () => mockUpdateNotifications.updateStream,
        ).thenAnswer((_) => streamController.stream);
        when(
          () => mockJournalDb.getMeasurementsByType(
            type: typeId,
            rangeStart: hourlySumRangeStart,
            rangeEnd: hourlySumRangeEnd,
          ),
        ).thenAnswer((_) async => [entry1, entry2, entry3]);

        final container = ProviderContainer();
        addTearDown(container.dispose);
        addTearDown(streamController.close);

        final params = (
          measurableDataTypeId: typeId,
          rangeStart: hourlySumRangeStart,
          rangeEnd: hourlySumRangeEnd,
          dashboardDefinedAggregationType: AggregationType.hourlySum,
        );

        final result = await container.read(
          measurableObservationsControllerProvider(params).future,
        );

        // Hour 9 should sum to 30, hour 10 should sum to 5.
        final hour9 = result.where(
          (o) =>
              o.dateTime.year == 2024 &&
              o.dateTime.month == 3 &&
              o.dateTime.day == 12 &&
              o.dateTime.hour == 9,
        );
        expect(hour9, hasLength(1));
        expect(hour9.first.value, equals(30));

        final hour10 = result.where(
          (o) =>
              o.dateTime.year == 2024 &&
              o.dateTime.month == 3 &&
              o.dateTime.day == 12 &&
              o.dateTime.hour == 10,
        );
        expect(hour10, hasLength(1));
        expect(hour10.first.value, equals(5));
      },
    );

    test('aggregates with none when aggregation type is none', () async {
      stubDataType(null);
      final entry1 = makeObsEntry(DateTime(2024, 3, 12, 9, 15), 10);
      final entry2 = makeObsEntry(DateTime(2024, 3, 12, 9, 45), 20);
      stubMeasurements([entry1, entry2]);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final params = (
        measurableDataTypeId: typeId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        dashboardDefinedAggregationType: AggregationType.none,
      );

      final result = await container.read(
        measurableObservationsControllerProvider(params).future,
      );

      // AggregationType.none returns one Observation per entry.
      expect(result, hasLength(2));
      final values = result.map((o) => o.value).toList()..sort();
      expect(values, equals([10, 20]));
    });

    test(
      'uses data-type aggregation type when dashboard type is null',
      () async {
        // dailyMax from the data type, no dashboard override.
        final dataType = MeasurableDataType(
          id: typeId,
          displayName: 'Obs Test',
          description: 'desc',
          unitName: 'u',
          // ignore: avoid_redundant_argument_values
          createdAt: DateTime(2024, 1, 1),
          // ignore: avoid_redundant_argument_values
          updatedAt: DateTime(2024, 1, 1),
          vectorClock: null,
          version: 1,
          aggregationType: AggregationType.dailyMax,
        );
        stubDataType(dataType);

        final entry1 = makeObsEntry(DateTime(2024, 3, 12, 9), 15);
        final entry2 = makeObsEntry(DateTime(2024, 3, 12, 14), 5);
        stubMeasurements([entry1, entry2]);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        final params = (
          measurableDataTypeId: typeId,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          dashboardDefinedAggregationType: null,
        );

        final result = await container.read(
          measurableObservationsControllerProvider(params).future,
        );

        final march12 = result.where(
          (o) =>
              o.dateTime.year == 2024 &&
              o.dateTime.month == 3 &&
              o.dateTime.day == 12,
        );
        expect(march12, hasLength(1));
        // Max of 15 and 5 is 15.
        expect(march12.first.value, equals(15));
      },
    );

    test('returns empty list when measurements are empty', () async {
      stubDataType(null);
      stubMeasurements([]);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final params = (
        measurableDataTypeId: typeId,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        dashboardDefinedAggregationType: AggregationType.dailySum,
      );

      final result = await container.read(
        measurableObservationsControllerProvider(params).future,
      );

      // dailySum initialises every day bucket to 0 — 7 days in range.
      expect(result, isA<List<Observation>>());
      for (final obs in result) {
        expect(obs.value, equals(0));
      }
    });
  });

  group('MeasurableSuggestionsController', () {
    const typeId = 'suggestions-type-id';

    test('returns ranked suggestions from measurements', () async {
      final now = DateTime(2024, 3, 15);
      // rangeStart is 90 days before midnight of today, rangeEnd is tomorrow
      // midnight. We need to stub getMeasurementsByType for any range.
      final streamController = StreamController<Set<String>>.broadcast();
      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => streamController.stream);
      when(
        () => mockJournalDb.getMeasurementsByType(
          type: typeId,
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer(
        (_) async => [
          buildMeasurementEntry(
            id: 'e1',
            timestamp: now,
            value: 100,
          ),
          buildMeasurementEntry(
            id: 'e2',
            timestamp: now.subtract(const Duration(days: 1)),
            value: 100,
          ),
          buildMeasurementEntry(
            id: 'e3',
            timestamp: now.subtract(const Duration(days: 2)),
            value: 7,
          ),
        ],
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);
      addTearDown(streamController.close);

      final result = await container.read(
        measurableSuggestionsControllerProvider(typeId).future,
      );

      // Value 100 appears twice, 7 once → ranked: [100, 7].
      expect(result, isNotNull);
      expect(result!.first, equals(100));
      expect(result, contains(7));
    });

    test('returns empty list when there are no measurements', () async {
      final streamController = StreamController<Set<String>>.broadcast();
      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => streamController.stream);
      when(
        () => mockJournalDb.getMeasurementsByType(
          type: typeId,
          rangeStart: any(named: 'rangeStart'),
          rangeEnd: any(named: 'rangeEnd'),
        ),
      ).thenAnswer((_) async => []);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      addTearDown(streamController.close);

      final result = await container.read(
        measurableSuggestionsControllerProvider(typeId).future,
      );

      expect(result, isNotNull);
      expect(result, isEmpty);
    });
  });
}
