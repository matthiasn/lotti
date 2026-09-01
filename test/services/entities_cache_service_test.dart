import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import '../test_data/test_data.dart';
import '../test_utils/test_notifications.dart';

enum _GeneratedLabelScope {
  globalNull,
  globalEmpty,
  cat0,
  cat1,
  cat2,
  cat3,
  cats01,
  cats13,
  orphan,
  cat2AndOrphan,
}

class _GeneratedLabelSpec {
  const _GeneratedLabelSpec({
    required this.seed,
    required this.scope,
    required this.isPrivate,
    required this.isDeleted,
  });

  final int seed;
  final _GeneratedLabelScope scope;
  final bool isPrivate;
  final bool isDeleted;

  LabelDefinition build(int index) {
    final namePrefix = switch (seed % 5) {
      0 => 'Alpha',
      1 => 'bravo',
      2 => 'Charlie',
      3 => 'delta',
      _ => 'Echo',
    };

    return testLabelDefinition1.copyWith(
      id: 'generated-label-$index',
      name: '$namePrefix ${seed.toString().padLeft(5, '0')} $index',
      private: isPrivate,
      deletedAt: isDeleted ? testEpochDateTime : null,
      applicableCategoryIds: categoryIds,
    );
  }

  List<String>? get categoryIds {
    return switch (scope) {
      _GeneratedLabelScope.globalNull => null,
      _GeneratedLabelScope.globalEmpty => const <String>[],
      _GeneratedLabelScope.cat0 => const ['cat-0'],
      _GeneratedLabelScope.cat1 => const ['cat-1'],
      _GeneratedLabelScope.cat2 => const ['cat-2'],
      _GeneratedLabelScope.cat3 => const ['cat-3'],
      _GeneratedLabelScope.cats01 => const ['cat-0', 'cat-1'],
      _GeneratedLabelScope.cats13 => const ['cat-1', 'cat-3'],
      _GeneratedLabelScope.orphan => const ['orphan'],
      _GeneratedLabelScope.cat2AndOrphan => const ['cat-2', 'orphan'],
    };
  }

  @override
  String toString() {
    return '_GeneratedLabelSpec(seed: $seed, scope: $scope, '
        'isPrivate: $isPrivate, isDeleted: $isDeleted)';
  }
}

class _GeneratedEntitiesCacheScenario {
  const _GeneratedEntitiesCacheScenario({
    required this.labelSpecs,
    required this.privateFlag,
    required this.categorySlot,
  });

  final List<_GeneratedLabelSpec> labelSpecs;
  final bool privateFlag;
  final int categorySlot;

  List<CategoryDefinition> get categories {
    return List<CategoryDefinition>.generate(
      4,
      (index) => CategoryDefinition(
        id: 'cat-$index',
        name: 'Category ${3 - index}',
        color: '#000000',
        createdAt: testEpochDateTime,
        updatedAt: testEpochDateTime,
        vectorClock: null,
        active: true,
        private: false,
      ),
    );
  }

  List<LabelDefinition> get labels {
    return [
      for (final indexed in labelSpecs.indexed) indexed.$2.build(indexed.$1),
    ];
  }

  String? get categoryId {
    return switch (categorySlot % 6) {
      0 => null,
      1 => 'orphan',
      2 => 'cat-0',
      3 => 'cat-1',
      4 => 'cat-2',
      _ => 'cat-3',
    };
  }

  List<String> expectedFilteredIds() {
    final scoped =
        labels
            .where((label) => _isVisible(label, includePrivate: true))
            .where(_appliesToCategory)
            .toList()
          ..sort(_compareLabelsByName);
    return scoped.map((label) => label.id).toList();
  }

  List<String> expectedSortedLabelIds() {
    final sorted =
        labels
            .where((label) => _isVisible(label, includePrivate: privateFlag))
            .toList()
          ..sort(_compareLabelsByName);
    return sorted.map((label) => label.id).toList();
  }

  bool _isVisible(LabelDefinition label, {required bool includePrivate}) {
    return label.deletedAt == null &&
        (includePrivate || !(label.private ?? false));
  }

  bool _appliesToCategory(LabelDefinition label) {
    final applicableCategoryIds = label.applicableCategoryIds;
    if (applicableCategoryIds == null || applicableCategoryIds.isEmpty) {
      return true;
    }
    final selectedCategoryId = categoryId;
    return selectedCategoryId != null &&
        applicableCategoryIds.contains(selectedCategoryId);
  }

  static int _compareLabelsByName(LabelDefinition a, LabelDefinition b) {
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  @override
  String toString() {
    return '_GeneratedEntitiesCacheScenario('
        'labelSpecs: $labelSpecs, privateFlag: $privateFlag, '
        'categorySlot: $categorySlot)';
  }
}

extension _AnyGeneratedEntitiesCacheScenario on glados.Any {
  glados.Generator<_GeneratedLabelScope> get entitiesCacheLabelScope =>
      glados.AnyUtils(this).choose(_GeneratedLabelScope.values);

  glados.Generator<_GeneratedLabelSpec> get entitiesCacheLabelSpec =>
      glados.CombinableAny(this).combine4(
        glados.IntAnys(this).intInRange(0, 100000),
        entitiesCacheLabelScope,
        glados.AnyUtils(this).choose([false, true]),
        glados.AnyUtils(this).choose([false, true]),
        (
          int seed,
          _GeneratedLabelScope scope,
          bool isPrivate,
          bool isDeleted,
        ) => _GeneratedLabelSpec(
          seed: seed,
          scope: scope,
          isPrivate: isPrivate,
          isDeleted: isDeleted,
        ),
      );

  glados.Generator<_GeneratedEntitiesCacheScenario> get entitiesCacheScenario =>
      glados.CombinableAny(this).combine3(
        glados.ListAnys(
          this,
        ).listWithLengthInRange(0, 30, entitiesCacheLabelSpec),
        glados.AnyUtils(this).choose([false, true]),
        glados.IntAnys(this).intInRange(0, 1000),
        (
          List<_GeneratedLabelSpec> labelSpecs,
          bool privateFlag,
          int categorySlot,
        ) => _GeneratedEntitiesCacheScenario(
          labelSpecs: labelSpecs,
          privateFlag: privateFlag,
          categorySlot: categorySlot,
        ),
      );
}

void main() {
  late MockJournalDb journalDb;
  late TestNotifications notifications;

  setUp(() {
    journalDb = MockJournalDb();
    notifications = TestNotifications(sync: true);
  });

  tearDown(() async {
    await notifications.dispose();
  });

  /// Helper: stubs all getAll* methods + getConfigFlag with defaults,
  /// then creates and inits the cache.
  Future<EntitiesCacheService> createCache({
    List<MeasurableDataType> measurables = const [],
    List<CategoryDefinition> categories = const [],
    List<HabitDefinition> habits = const [],
    List<DashboardDefinition> dashboards = const [],
    List<LabelDefinition> labels = const [],
    bool privateFlag = false,
  }) async {
    when(
      () => journalDb.getAllMeasurableDataTypes(),
    ).thenAnswer((_) async => measurables);
    when(
      () => journalDb.getAllCategories(),
    ).thenAnswer((_) async => categories);
    when(
      () => journalDb.getAllHabitDefinitions(),
    ).thenAnswer((_) async => habits);
    when(
      () => journalDb.getAllDashboards(),
    ).thenAnswer((_) async => dashboards);
    when(
      () => journalDb.getAllLabelDefinitions(),
    ).thenAnswer((_) async => labels);
    when(
      () => journalDb.getConfigFlag('private'),
    ).thenAnswer((_) async => privateFlag);

    final cache = EntitiesCacheService(
      journalDb: journalDb,
      updateNotifications: notifications,
    );
    await cache.init();
    return cache;
  }

  /// Synchronous version of [createCache] for use inside [fakeAsync].
  /// Call this, then [FakeAsync.flushMicrotasks] to resolve the init future.
  EntitiesCacheService createCacheSync(
    FakeAsync async, {
    List<MeasurableDataType> measurables = const [],
    List<CategoryDefinition> categories = const [],
    List<HabitDefinition> habits = const [],
    List<DashboardDefinition> dashboards = const [],
    List<LabelDefinition> labels = const [],
    bool privateFlag = false,
  }) {
    when(
      () => journalDb.getAllMeasurableDataTypes(),
    ).thenAnswer((_) async => measurables);
    when(
      () => journalDb.getAllCategories(),
    ).thenAnswer((_) async => categories);
    when(
      () => journalDb.getAllHabitDefinitions(),
    ).thenAnswer((_) async => habits);
    when(
      () => journalDb.getAllDashboards(),
    ).thenAnswer((_) async => dashboards);
    when(
      () => journalDb.getAllLabelDefinitions(),
    ).thenAnswer((_) async => labels);
    when(
      () => journalDb.getConfigFlag('private'),
    ).thenAnswer((_) async => privateFlag);

    final cache = EntitiesCacheService(
      journalDb: journalDb,
      updateNotifications: notifications,
    )..init();
    async.flushMicrotasks();
    return cache;
  }

  glados.Glados(
    glados.any.entitiesCacheScenario,
    glados.ExploreConfig(numRuns: 160),
  ).test('matches generated label visibility invariants', (scenario) {
    // Drive init through fakeAsync via the synchronous factory so each of
    // the 160 iterations avoids real async scheduling overhead.
    fakeAsync((async) {
      final cache = createCacheSync(
        async,
        categories: scenario.categories,
        labels: scenario.labels,
        privateFlag: scenario.privateFlag,
      );

      final filtered = cache.filterLabelsForCategory(
        scenario.labels,
        scenario.categoryId,
      );

      expect(
        filtered.map((label) => label.id).toList(),
        scenario.expectedFilteredIds(),
        reason: scenario.toString(),
      );
      expect(
        cache.sortedLabels.map((label) => label.id).toList(),
        scenario.expectedSortedLabelIds(),
        reason: scenario.toString(),
      );
    });
  }, tags: 'glados');

  test('filterLabelsForCategory filters by category scope', () async {
    final cache = await createCache();

    final global = testLabelDefinition1.copyWith(id: 'g', name: 'Global');
    final privateGlobal = testLabelDefinition1.copyWith(
      id: 'p',
      name: 'Private',
      private: true,
    );
    final inWork = testLabelDefinition1.copyWith(
      id: 'w',
      name: 'Work',
      applicableCategoryIds: const ['work'],
    );

    final all = [global, privateGlobal, inWork];
    final result = cache.filterLabelsForCategory(all, 'work');

    expect(result.map((e) => e.id).toSet(), {'g', 'w', 'p'});
  });

  test('filterLabelsForCategory handles empty input list', () async {
    final cache = await createCache();
    final res = cache.filterLabelsForCategory(const [], 'any');
    expect(res, isEmpty);
  });

  test('getDataTypeById returns data type when found', () async {
    final cache = await createCache(
      measurables: [measurableWater, measurablePullUps],
    );

    expect(cache.getDataTypeById(measurableWater.id), measurableWater);
    expect(cache.getDataTypeById(measurablePullUps.id), measurablePullUps);
    expect(cache.getDataTypeById('nonexistent'), isNull);
  });

  test('getCategoryById returns category when found', () async {
    final cache = await createCache(
      categories: [categoryMindfulness],
    );

    expect(cache.getCategoryById(categoryMindfulness.id), categoryMindfulness);
    expect(cache.getCategoryById('nonexistent'), isNull);
    expect(cache.getCategoryById(null), isNull);
  });

  test('getHabitById returns habit when found', () async {
    final cache = await createCache(
      habits: [habitFlossing],
    );

    expect(cache.getHabitById(habitFlossing.id), habitFlossing);
    expect(cache.getHabitById('nonexistent'), isNull);
    expect(cache.getHabitById(null), isNull);
  });

  test('getDashboardById returns dashboard when found', () async {
    final cache = await createCache(
      dashboards: [testDashboardConfig],
    );

    expect(cache.getDashboardById(testDashboardConfig.id), testDashboardConfig);
    expect(cache.getDashboardById('nonexistent'), isNull);
    expect(cache.getDashboardById(null), isNull);
  });

  test('getLabelById returns label when found', () async {
    final cache = await createCache(
      labels: [testLabelDefinition1, testLabelDefinition2],
    );

    expect(cache.getLabelById(testLabelDefinition1.id), testLabelDefinition1);
    expect(cache.getLabelById(testLabelDefinition2.id), testLabelDefinition2);
    expect(cache.getLabelById('nonexistent'), isNull);
    expect(cache.getLabelById(null), isNull);
  });

  test('sortedCategories returns active categories sorted by name', () async {
    final catA = CategoryDefinition(
      id: 'a',
      name: 'Zebra',
      color: '#000000',
      createdAt: testEpochDateTime,
      updatedAt: testEpochDateTime,
      vectorClock: null,
      active: true,
      private: false,
    );
    final catB = CategoryDefinition(
      id: 'b',
      name: 'Apple',
      color: '#000000',
      createdAt: testEpochDateTime,
      updatedAt: testEpochDateTime,
      vectorClock: null,
      active: true,
      private: false,
    );
    final catC = CategoryDefinition(
      id: 'c',
      name: 'Mango',
      color: '#000000',
      createdAt: testEpochDateTime,
      updatedAt: testEpochDateTime,
      vectorClock: null,
      active: false,
      private: false,
    );

    final cache = await createCache(categories: [catA, catB, catC]);

    final sorted = cache.sortedCategories;
    expect(sorted.length, 2);
    expect(sorted.map((c) => c.name).toList(), ['Apple', 'Zebra']);
  });

  test('sortedLabels returns non-deleted labels sorted by name', () async {
    final labelA = testLabelDefinition1.copyWith(id: 'a', name: 'Zebra');
    final labelB = testLabelDefinition1.copyWith(id: 'b', name: 'Apple');
    final labelC = testLabelDefinition1.copyWith(
      id: 'c',
      name: 'Deleted',
      deletedAt: testEpochDateTime,
    );
    final labelD = testLabelDefinition1.copyWith(
      id: 'd',
      name: 'Private',
      private: true,
    );

    final cache = await createCache(
      labels: [labelA, labelB, labelC, labelD],
    );

    final sorted = cache.sortedLabels;
    expect(sorted.length, 2);
    expect(sorted.map((l) => l.name).toList(), ['Apple', 'Zebra']);
  });

  test(
    'sortedLabels includes private labels when showPrivateEntries is true',
    () async {
      final labelA = testLabelDefinition1.copyWith(id: 'a', name: 'Public');
      final labelB = testLabelDefinition1.copyWith(
        id: 'b',
        name: 'Private',
        private: true,
      );

      final cache = await createCache(
        labels: [labelA, labelB],
        privateFlag: true,
      );

      final sorted = cache.sortedLabels;
      expect(sorted.length, 2);
      expect(sorted.map((l) => l.name).toList(), ['Private', 'Public']);
    },
  );

  test('showPrivateEntries reflects config flag', () {
    fakeAsync((async) {
      final cache = createCacheSync(async);
      expect(cache.showPrivateEntries, false);

      // Toggle to true
      when(
        () => journalDb.getConfigFlag('private'),
      ).thenAnswer((_) async => true);
      notifications.emit({privateToggleNotification});
      async.flushMicrotasks();
      expect(cache.showPrivateEntries, true);

      // Toggle back to false
      when(
        () => journalDb.getConfigFlag('private'),
      ).thenAnswer((_) async => false);
      notifications.emit({privateToggleNotification});
      async.flushMicrotasks();
      expect(cache.showPrivateEntries, false);
    });
  });

  test('filterLabelsForCategory excludes deleted labels', () async {
    final cache = await createCache();

    final global = testLabelDefinition1.copyWith(id: 'g', name: 'Global');
    final deleted = testLabelDefinition1.copyWith(
      id: 'd',
      name: 'Deleted',
      deletedAt: testEpochDateTime,
    );
    final scopedDeleted = testLabelDefinition1.copyWith(
      id: 'sd',
      name: 'ScopedDeleted',
      applicableCategoryIds: const ['work'],
      deletedAt: testEpochDateTime,
    );
    final scoped = testLabelDefinition1.copyWith(
      id: 's',
      name: 'Scoped',
      applicableCategoryIds: const ['work'],
    );

    final result = cache.filterLabelsForCategory(
      [global, deleted, scopedDeleted, scoped],
      'work',
    );
    expect(result.map((l) => l.id).toSet(), {'g', 's'});
  });

  test(
    'filterLabelsForCategory with null categoryId returns only global labels',
    () async {
      final cache = await createCache();

      final global = testLabelDefinition1.copyWith(id: 'g', name: 'Global');
      final scoped = testLabelDefinition1.copyWith(
        id: 's',
        name: 'Scoped',
        applicableCategoryIds: const ['work'],
      );

      final result = cache.filterLabelsForCategory([global, scoped], null);
      expect(result.map((l) => l.id).toSet(), {'g'});
    },
  );

  test('data types cache updates on notification', () {
    fakeAsync((async) {
      final cache = createCacheSync(async);
      expect(cache.getDataTypeById(measurableWater.id), isNull);

      // First update
      when(
        () => journalDb.getAllMeasurableDataTypes(),
      ).thenAnswer((_) async => [measurableWater]);
      notifications.emit({measurablesNotification});
      async.flushMicrotasks();
      expect(cache.getDataTypeById(measurableWater.id), measurableWater);

      // Second update with different set — old ones should be cleared
      when(
        () => journalDb.getAllMeasurableDataTypes(),
      ).thenAnswer((_) async => [measurablePullUps]);
      notifications.emit({measurablesNotification});
      async.flushMicrotasks();
      expect(cache.getDataTypeById(measurableWater.id), isNull);
      expect(cache.getDataTypeById(measurablePullUps.id), measurablePullUps);
    });
  });

  test('habits cache updates on notification', () {
    fakeAsync((async) {
      final cache = createCacheSync(async);
      expect(cache.getHabitById(habitFlossing.id), isNull);

      when(
        () => journalDb.getAllHabitDefinitions(),
      ).thenAnswer((_) async => [habitFlossing]);
      notifications.emit({habitsNotification});
      async.flushMicrotasks();
      expect(cache.getHabitById(habitFlossing.id), habitFlossing);
    });
  });

  test('dashboards cache updates on notification', () {
    fakeAsync((async) {
      final cache = createCacheSync(async);
      expect(cache.getDashboardById(testDashboardConfig.id), isNull);

      when(
        () => journalDb.getAllDashboards(),
      ).thenAnswer((_) async => [testDashboardConfig]);
      notifications.emit({dashboardsNotification});
      async.flushMicrotasks();
      expect(
        cache.getDashboardById(testDashboardConfig.id),
        testDashboardConfig,
      );
    });
  });

  test('privateToggleNotification triggers all cache reloads', () {
    fakeAsync((async) {
      final cache = createCacheSync(async);

      // Set up return values for all entity types
      when(
        () => journalDb.getAllMeasurableDataTypes(),
      ).thenAnswer((_) async => [measurableWater]);
      when(
        () => journalDb.getAllCategories(),
      ).thenAnswer((_) async => [categoryMindfulness]);
      when(
        () => journalDb.getAllHabitDefinitions(),
      ).thenAnswer((_) async => [habitFlossing]);
      when(
        () => journalDb.getAllDashboards(),
      ).thenAnswer((_) async => [testDashboardConfig]);
      when(
        () => journalDb.getAllLabelDefinitions(),
      ).thenAnswer((_) async => [testLabelDefinition1]);
      when(
        () => journalDb.getConfigFlag('private'),
      ).thenAnswer((_) async => true);

      notifications.emit({privateToggleNotification});
      async.flushMicrotasks();

      expect(cache.getDataTypeById(measurableWater.id), measurableWater);
      expect(
        cache.getCategoryById(categoryMindfulness.id),
        categoryMindfulness,
      );
      expect(cache.getHabitById(habitFlossing.id), habitFlossing);
      expect(
        cache.getDashboardById(testDashboardConfig.id),
        testDashboardConfig,
      );
      expect(
        cache.getLabelById(testLabelDefinition1.id),
        testLabelDefinition1,
      );
      expect(cache.showPrivateEntries, true);
    });
  });

  test('serialized fetch coalesces rapid notifications', () {
    fakeAsync((async) {
      var measurableFetchCount = 0;
      final completer = Completer<List<MeasurableDataType>>();

      when(() => journalDb.getAllMeasurableDataTypes()).thenAnswer((_) async {
        measurableFetchCount++;
        if (measurableFetchCount == 1) {
          // Initial fetch: return immediately
          return [];
        }
        if (measurableFetchCount == 2) {
          // Second fetch: block on completer
          return completer.future;
        }
        // Third fetch (coalesced retry): return data
        return [measurableWater];
      });
      when(
        () => journalDb.getAllCategories(),
      ).thenAnswer((_) async => <CategoryDefinition>[]);
      when(
        () => journalDb.getAllHabitDefinitions(),
      ).thenAnswer((_) async => <HabitDefinition>[]);
      when(
        () => journalDb.getAllDashboards(),
      ).thenAnswer((_) async => <DashboardDefinition>[]);
      when(
        () => journalDb.getAllLabelDefinitions(),
      ).thenAnswer((_) async => <LabelDefinition>[]);
      when(
        () => journalDb.getConfigFlag('private'),
      ).thenAnswer((_) async => false);

      final cache = EntitiesCacheService(
        journalDb: journalDb,
        updateNotifications: notifications,
      )..init();
      async.flushMicrotasks();
      expect(measurableFetchCount, 1);

      // First notification triggers a fetch that blocks
      notifications.emit({measurablesNotification});
      async.flushMicrotasks();
      expect(measurableFetchCount, 2);

      // Rapid notifications while fetch is in progress — should coalesce
      notifications
        ..emit({measurablesNotification})
        ..emit({measurablesNotification})
        ..emit({measurablesNotification});
      async.flushMicrotasks();

      // Complete the blocking fetch
      completer.complete([measurablePullUps]);
      async.flushMicrotasks();

      // Should have done exactly 3 fetches: init + blocked + one coalesced retry
      expect(measurableFetchCount, 3);
      expect(cache.getDataTypeById(measurableWater.id), measurableWater);
    });
  });

  test('init loads all entity types in parallel', () async {
    when(
      () => journalDb.getAllMeasurableDataTypes(),
    ).thenAnswer((_) async => [measurableWater]);
    when(
      () => journalDb.getAllCategories(),
    ).thenAnswer((_) async => [categoryMindfulness]);
    when(
      () => journalDb.getAllHabitDefinitions(),
    ).thenAnswer((_) async => [habitFlossing]);
    when(
      () => journalDb.getAllDashboards(),
    ).thenAnswer((_) async => [testDashboardConfig]);
    when(
      () => journalDb.getAllLabelDefinitions(),
    ).thenAnswer((_) async => [testLabelDefinition1]);
    when(
      () => journalDb.getConfigFlag('private'),
    ).thenAnswer((_) async => true);

    final cache = EntitiesCacheService(
      journalDb: journalDb,
      updateNotifications: notifications,
    );
    await cache.init();

    // Verify all entity types were loaded during init
    expect(cache.getDataTypeById(measurableWater.id), measurableWater);
    expect(
      cache.getCategoryById(categoryMindfulness.id),
      categoryMindfulness,
    );
    expect(cache.getHabitById(habitFlossing.id), habitFlossing);
    expect(
      cache.getDashboardById(testDashboardConfig.id),
      testDashboardConfig,
    );
    expect(
      cache.getLabelById(testLabelDefinition1.id),
      testLabelDefinition1,
    );
    expect(cache.showPrivateEntries, true);
  });

  test('dispose cancels notification subscription', () {
    fakeAsync((async) {
      final cache = createCacheSync(async)..dispose();

      // After dispose, notifications should not trigger reloads
      when(
        () => journalDb.getAllMeasurableDataTypes(),
      ).thenAnswer((_) async => [measurableWater]);
      notifications.emit({measurablesNotification});
      async.flushMicrotasks();
      expect(cache.getDataTypeById(measurableWater.id), isNull);
    });
  });

  test('categories fetch coalesces rapid notifications', () {
    fakeAsync((async) {
      var categoryFetchCount = 0;
      final completer = Completer<List<CategoryDefinition>>();

      when(() => journalDb.getAllCategories()).thenAnswer((_) async {
        categoryFetchCount++;
        if (categoryFetchCount == 1) {
          return const [];
        }
        if (categoryFetchCount == 2) {
          return completer.future;
        }
        return [categoryMindfulness];
      });
      when(
        () => journalDb.getAllMeasurableDataTypes(),
      ).thenAnswer((_) async => <MeasurableDataType>[]);
      when(
        () => journalDb.getAllHabitDefinitions(),
      ).thenAnswer((_) async => <HabitDefinition>[]);
      when(
        () => journalDb.getAllDashboards(),
      ).thenAnswer((_) async => <DashboardDefinition>[]);
      when(
        () => journalDb.getAllLabelDefinitions(),
      ).thenAnswer((_) async => <LabelDefinition>[]);
      when(
        () => journalDb.getConfigFlag('private'),
      ).thenAnswer((_) async => false);

      final cache = EntitiesCacheService(
        journalDb: journalDb,
        updateNotifications: notifications,
      )..init();
      async.flushMicrotasks();
      expect(categoryFetchCount, 1);

      // First notification triggers a blocked fetch
      notifications.emit({categoriesNotification});
      async.flushMicrotasks();
      expect(categoryFetchCount, 2);

      // Rapid notifications while the fetch is in progress — should coalesce
      notifications
        ..emit({categoriesNotification})
        ..emit({categoriesNotification});
      async.flushMicrotasks();

      // Complete the blocking fetch
      completer.complete([]);
      async.flushMicrotasks();

      // Exactly 3 fetches: init + blocked + one coalesced retry
      expect(categoryFetchCount, 3);
      expect(
        cache.getCategoryById(categoryMindfulness.id),
        categoryMindfulness,
      );
    });
  });

  test('habits fetch coalesces rapid notifications', () {
    fakeAsync((async) {
      var habitFetchCount = 0;
      final completer = Completer<List<HabitDefinition>>();

      when(() => journalDb.getAllHabitDefinitions()).thenAnswer((_) async {
        habitFetchCount++;
        if (habitFetchCount == 1) {
          return const [];
        }
        if (habitFetchCount == 2) {
          return completer.future;
        }
        return [habitFlossing];
      });
      when(
        () => journalDb.getAllMeasurableDataTypes(),
      ).thenAnswer((_) async => <MeasurableDataType>[]);
      when(
        () => journalDb.getAllCategories(),
      ).thenAnswer((_) async => <CategoryDefinition>[]);
      when(
        () => journalDb.getAllDashboards(),
      ).thenAnswer((_) async => <DashboardDefinition>[]);
      when(
        () => journalDb.getAllLabelDefinitions(),
      ).thenAnswer((_) async => <LabelDefinition>[]);
      when(
        () => journalDb.getConfigFlag('private'),
      ).thenAnswer((_) async => false);

      final cache = EntitiesCacheService(
        journalDb: journalDb,
        updateNotifications: notifications,
      )..init();
      async.flushMicrotasks();
      expect(habitFetchCount, 1);

      notifications.emit({habitsNotification});
      async.flushMicrotasks();
      expect(habitFetchCount, 2);

      notifications
        ..emit({habitsNotification})
        ..emit({habitsNotification});
      async.flushMicrotasks();

      completer.complete([]);
      async.flushMicrotasks();

      expect(habitFetchCount, 3);
      expect(cache.getHabitById(habitFlossing.id), habitFlossing);
    });
  });

  test('dashboards fetch coalesces rapid notifications', () {
    fakeAsync((async) {
      var dashboardFetchCount = 0;
      final completer = Completer<List<DashboardDefinition>>();

      when(() => journalDb.getAllDashboards()).thenAnswer((_) async {
        dashboardFetchCount++;
        if (dashboardFetchCount == 1) {
          return const [];
        }
        if (dashboardFetchCount == 2) {
          return completer.future;
        }
        return [testDashboardConfig];
      });
      when(
        () => journalDb.getAllMeasurableDataTypes(),
      ).thenAnswer((_) async => <MeasurableDataType>[]);
      when(
        () => journalDb.getAllCategories(),
      ).thenAnswer((_) async => <CategoryDefinition>[]);
      when(
        () => journalDb.getAllHabitDefinitions(),
      ).thenAnswer((_) async => <HabitDefinition>[]);
      when(
        () => journalDb.getAllLabelDefinitions(),
      ).thenAnswer((_) async => <LabelDefinition>[]);
      when(
        () => journalDb.getConfigFlag('private'),
      ).thenAnswer((_) async => false);

      final cache = EntitiesCacheService(
        journalDb: journalDb,
        updateNotifications: notifications,
      )..init();
      async.flushMicrotasks();
      expect(dashboardFetchCount, 1);

      notifications.emit({dashboardsNotification});
      async.flushMicrotasks();
      expect(dashboardFetchCount, 2);

      notifications
        ..emit({dashboardsNotification})
        ..emit({dashboardsNotification});
      async.flushMicrotasks();

      completer.complete([]);
      async.flushMicrotasks();

      expect(dashboardFetchCount, 3);
      expect(
        cache.getDashboardById(testDashboardConfig.id),
        testDashboardConfig,
      );
    });
  });

  test(
    'loadDashboards logs error and continues when getAllDashboards throws',
    () async {
      when(
        () => journalDb.getAllMeasurableDataTypes(),
      ).thenAnswer((_) async => <MeasurableDataType>[]);
      when(
        () => journalDb.getAllCategories(),
      ).thenAnswer((_) async => <CategoryDefinition>[]);
      when(
        () => journalDb.getAllHabitDefinitions(),
      ).thenAnswer((_) async => <HabitDefinition>[]);
      when(
        () => journalDb.getAllDashboards(),
      ).thenThrow(Exception('db error'));
      when(
        () => journalDb.getAllLabelDefinitions(),
      ).thenAnswer((_) async => <LabelDefinition>[]);
      when(
        () => journalDb.getConfigFlag('private'),
      ).thenAnswer((_) async => false);

      final cache = EntitiesCacheService(
        journalDb: journalDb,
        updateNotifications: notifications,
      );
      // Should not throw even though getAllDashboards throws
      await expectLater(cache.init(), completes);
      // dashboardsById stays empty — no crash
      expect(cache.getDashboardById('any'), isNull);
    },
  );

  test('labels fetch coalesces rapid notifications', () {
    fakeAsync((async) {
      var labelFetchCount = 0;
      final completer = Completer<List<LabelDefinition>>();

      when(() => journalDb.getAllLabelDefinitions()).thenAnswer((_) async {
        labelFetchCount++;
        if (labelFetchCount == 1) {
          return const [];
        }
        if (labelFetchCount == 2) {
          return completer.future;
        }
        return [testLabelDefinition1];
      });
      when(
        () => journalDb.getAllMeasurableDataTypes(),
      ).thenAnswer((_) async => <MeasurableDataType>[]);
      when(
        () => journalDb.getAllCategories(),
      ).thenAnswer((_) async => <CategoryDefinition>[]);
      when(
        () => journalDb.getAllHabitDefinitions(),
      ).thenAnswer((_) async => <HabitDefinition>[]);
      when(
        () => journalDb.getAllDashboards(),
      ).thenAnswer((_) async => <DashboardDefinition>[]);
      when(
        () => journalDb.getConfigFlag('private'),
      ).thenAnswer((_) async => false);

      final cache = EntitiesCacheService(
        journalDb: journalDb,
        updateNotifications: notifications,
      )..init();
      async.flushMicrotasks();
      expect(labelFetchCount, 1);

      notifications.emit({labelsNotification});
      async.flushMicrotasks();
      expect(labelFetchCount, 2);

      notifications
        ..emit({labelsNotification})
        ..emit({labelsNotification});
      async.flushMicrotasks();

      completer.complete([]);
      async.flushMicrotasks();

      expect(labelFetchCount, 3);
      expect(cache.getLabelById(testLabelDefinition1.id), testLabelDefinition1);
    });
  });

  test('sortedCategories is scoped to lockedCategoryIds while set', () async {
    CategoryDefinition category(String id, String name) => CategoryDefinition(
      id: id,
      name: name,
      color: '#000000',
      createdAt: testEpochDateTime,
      updatedAt: testEpochDateTime,
      vectorClock: null,
      active: true,
      private: false,
    );
    final cache = await createCache(
      categories: [
        category('work', 'Work'),
        category('health', 'Health'),
        category('side', 'Side project'),
      ],
    );
    expect(cache.lockedCategoryIds, isEmpty);

    cache.lockedCategoryIds = {'work', 'side'};
    expect(
      cache.sortedCategories.map((c) => c.id).toList(),
      ['side', 'work'],
    );
    // Lookups by id stay unscoped: the locked category's own content still
    // has to resolve its definition.
    expect(cache.getCategoryById('health')?.name, 'Health');

    cache.lockedCategoryIds = const {};
    expect(cache.sortedCategories.length, 3);
  });
}
