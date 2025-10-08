import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import '../test_data/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EntitiesCacheService Tests', () {
    late MockJournalDb mockJournalDb;
    late StreamController<List<MeasurableDataType>> dataTypesController;
    late StreamController<List<CategoryDefinition>> categoriesController;
    late StreamController<List<HabitDefinition>> habitsController;
    late StreamController<List<DashboardDefinition>> dashboardsController;

    setUp(() {
      if (getIt.isRegistered<JournalDb>()) {
        getIt.unregister<JournalDb>();
      }
      if (getIt.isRegistered<EntitiesCacheService>()) {
        getIt.unregister<EntitiesCacheService>();
      }

      mockJournalDb = MockJournalDb();
      dataTypesController = StreamController<List<MeasurableDataType>>();
      categoriesController = StreamController<List<CategoryDefinition>>();
      habitsController = StreamController<List<HabitDefinition>>();
      dashboardsController = StreamController<List<DashboardDefinition>>();

      when(mockJournalDb.watchMeasurableDataTypes)
          .thenAnswer((_) => dataTypesController.stream);
      when(mockJournalDb.watchCategories)
          .thenAnswer((_) => categoriesController.stream);
      when(mockJournalDb.watchHabitDefinitions)
          .thenAnswer((_) => habitsController.stream);
      when(mockJournalDb.watchDashboards)
          .thenAnswer((_) => dashboardsController.stream);

      getIt.registerSingleton<JournalDb>(mockJournalDb);
    });

    tearDown(() async {
      await dataTypesController.close();
      await categoriesController.close();
      await habitsController.close();
      await dashboardsController.close();
    });

    test('constructor initializes and populates caches from DB streams',
        () async {
      final service = EntitiesCacheService();

      // Verify caches are initially empty
      expect(service.dataTypesById, isEmpty);
      expect(service.categoriesById, isEmpty);
      expect(service.habitsById, isEmpty);
      expect(service.dashboardsById, isEmpty);

      // Emit data to streams
      dataTypesController.add([measurableWater, measurablePullUps]);
      categoriesController.add([categoryMindfulness]);
      habitsController.add([habitFlossing]);
      dashboardsController.add([testDashboardConfig]);

      // Wait for streams to process
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Verify caches are populated
      expect(service.dataTypesById.length, 2);
      expect(service.dataTypesById[measurableWater.id], measurableWater);
      expect(service.dataTypesById[measurablePullUps.id], measurablePullUps);

      expect(service.categoriesById.length, 1);
      expect(
          service.categoriesById[categoryMindfulness.id], categoryMindfulness);

      expect(service.habitsById.length, 1);
      expect(service.habitsById[habitFlossing.id], habitFlossing);

      expect(service.dashboardsById.length, 1);
      expect(
          service.dashboardsById[testDashboardConfig.id], testDashboardConfig);
    });

    test('getDataTypeById returns correct data type', () async {
      final service = EntitiesCacheService();

      dataTypesController.add([measurableWater]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final result = service.getDataTypeById(measurableWater.id);
      expect(result, measurableWater);
    });

    test('getDataTypeById returns null for non-existing id', () async {
      final service = EntitiesCacheService();

      dataTypesController.add([measurableWater]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final result = service.getDataTypeById('non-existing-id');
      expect(result, isNull);
    });

    test('getCategoryById returns correct category', () async {
      final service = EntitiesCacheService();

      categoriesController.add([categoryMindfulness]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final result = service.getCategoryById(categoryMindfulness.id);
      expect(result, categoryMindfulness);
    });

    test('getCategoryById returns null for non-existing id', () async {
      final service = EntitiesCacheService();

      categoriesController.add([categoryMindfulness]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final result = service.getCategoryById('non-existing-id');
      expect(result, isNull);
    });

    test('getHabitById returns correct habit', () async {
      final service = EntitiesCacheService();

      habitsController.add([habitFlossing]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final result = service.getHabitById(habitFlossing.id);
      expect(result, habitFlossing);
    });

    test('getHabitById returns null for non-existing id', () async {
      final service = EntitiesCacheService();

      habitsController.add([habitFlossing]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final result = service.getHabitById('non-existing-id');
      expect(result, isNull);
    });

    test('getDashboardById returns correct dashboard', () async {
      final service = EntitiesCacheService();

      dashboardsController.add([testDashboardConfig]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final result = service.getDashboardById(testDashboardConfig.id);
      expect(result, testDashboardConfig);
    });

    test('getDashboardById returns null for non-existing id', () async {
      final service = EntitiesCacheService();

      dashboardsController.add([testDashboardConfig]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final result = service.getDashboardById('non-existing-id');
      expect(result, isNull);
    });

    test('sortedCategories returns only active categories sorted by name',
        () async {
      final inactiveCategory = CategoryDefinition(
        id: 'inactive-category-id',
        name: 'Inactive Category',
        color: '#FF0000',
        createdAt: testEpochDateTime,
        updatedAt: testEpochDateTime,
        vectorClock: null,
        active: false,
        private: false,
      );

      final categoryZ = CategoryDefinition(
        id: 'category-z-id',
        name: 'Zebra Category',
        color: '#00FF00',
        createdAt: testEpochDateTime,
        updatedAt: testEpochDateTime,
        vectorClock: null,
        active: true,
        private: false,
      );

      final categoryA = CategoryDefinition(
        id: 'category-a-id',
        name: 'Apple Category',
        color: '#0000FF',
        createdAt: testEpochDateTime,
        updatedAt: testEpochDateTime,
        vectorClock: null,
        active: true,
        private: false,
      );

      final service = EntitiesCacheService();

      categoriesController.add([
        categoryMindfulness,
        inactiveCategory,
        categoryZ,
        categoryA,
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final result = service.sortedCategories;

      // Should only include active categories
      expect(result.length, 3);
      expect(result.contains(inactiveCategory), false);

      // Should be sorted by name (case-insensitive)
      expect(result[0].name, 'Apple Category');
      expect(result[1].name, 'Mindfulness');
      expect(result[2].name, 'Zebra Category');
    });

    test('cache updates when DB streams emit new data', () async {
      final service = EntitiesCacheService();

      // Initial data
      dataTypesController.add([measurableWater]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(service.dataTypesById.length, 1);
      expect(service.dataTypesById[measurableWater.id], measurableWater);

      // Update with new data
      dataTypesController.add([measurablePullUps, measurableChocolate]);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Cache should be replaced with new data
      expect(service.dataTypesById.length, 2);
      expect(service.dataTypesById[measurableWater.id], isNull);
      expect(service.dataTypesById[measurablePullUps.id], measurablePullUps);
      expect(
          service.dataTypesById[measurableChocolate.id], measurableChocolate);
    });
  });
}
