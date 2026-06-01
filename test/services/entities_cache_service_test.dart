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

/// A simple wrapper that exposes the same [updateStream] getter as
/// [UpdateNotifications], but without debouncing — so tests can verify
/// notification-driven re-fetches immediately.
class TestNotifications implements UpdateNotifications {
  final _controller = StreamController<Set<String>>.broadcast(sync: true);

  @override
  Stream<Set<String>> get updateStream => _controller.stream;

  @override
  Stream<Set<String>> get localUpdateStream => _controller.stream;

  @override
  Stream<Set<String>> get syncUpdateStream => _controller.stream;

  void emit(Set<String> ids) {
    _controller.add(ids);
  }

  @override
  void notify(Set<String> affectedIds, {bool fromSync = false}) {
    emit(affectedIds);
  }

  @override
  void notifyUiOnly(Set<String> affectedIds) {
    emit(affectedIds);
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

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

enum _GeneratedIncludePrivateOverride {
  useConfig,
  include,
  exclude,
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
    required this.includePrivateOverride,
    required this.categorySlot,
  });

  final List<_GeneratedLabelSpec> labelSpecs;
  final bool privateFlag;
  final _GeneratedIncludePrivateOverride includePrivateOverride;
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

  bool? get includePrivate {
    return switch (includePrivateOverride) {
      _GeneratedIncludePrivateOverride.useConfig => null,
      _GeneratedIncludePrivateOverride.include => true,
      _GeneratedIncludePrivateOverride.exclude => false,
    };
  }

  bool get effectiveIncludePrivate => includePrivate ?? privateFlag;

  List<String> expectedAvailableIds() {
    final scoped =
        labels
            .where((label) => _isVisible(label, includePrivate: true))
            .where(_appliesToCategory)
            .where(
              (label) => effectiveIncludePrivate || !(label.private ?? false),
            )
            .toList()
          ..sort(_compareLabelsByName);
    return scoped.map((label) => label.id).toList();
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
        'includePrivateOverride: $includePrivateOverride, '
        'categorySlot: $categorySlot)';
  }
}

extension _AnyGeneratedEntitiesCacheScenario on glados.Any {
  glados.Generator<_GeneratedLabelScope> get entitiesCacheLabelScope =>
      glados.AnyUtils(this).choose(_GeneratedLabelScope.values);

  glados.Generator<_GeneratedIncludePrivateOverride>
  get entitiesCacheIncludePrivateOverride =>
      glados.AnyUtils(this).choose(_GeneratedIncludePrivateOverride.values);

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
      glados.CombinableAny(this).combine4(
        glados.ListAnys(
          this,
        ).listWithLengthInRange(0, 30, entitiesCacheLabelSpec),
        glados.AnyUtils(this).choose([false, true]),
        entitiesCacheIncludePrivateOverride,
        glados.IntAnys(this).intInRange(0, 1000),
        (
          List<_GeneratedLabelSpec> labelSpecs,
          bool privateFlag,
          _GeneratedIncludePrivateOverride includePrivateOverride,
          int categorySlot,
        ) => _GeneratedEntitiesCacheScenario(
          labelSpecs: labelSpecs,
          privateFlag: privateFlag,
          includePrivateOverride: includePrivateOverride,
          categorySlot: categorySlot,
        ),
      );
}

void main() {
  late MockJournalDb journalDb;
  late TestNotifications notifications;

  setUp(() {
    journalDb = MockJournalDb();
    notifications = TestNotifications();
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
  ).test('matches generated label visibility invariants', (scenario) async {
    final cache = await createCache(
      categories: scenario.categories,
      labels: scenario.labels,
      privateFlag: scenario.privateFlag,
    );

    final available = cache.availableLabelsForCategory(
      scenario.categoryId,
      includePrivate: scenario.includePrivate,
    );
    final filtered = cache.filterLabelsForCategory(
      scenario.labels,
      scenario.categoryId,
    );

    expect(
      available.map((label) => label.id).toList(),
      scenario.expectedAvailableIds(),
      reason: scenario.toString(),
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
    expect(
      available.map((label) => label.id).toSet(),
      hasLength(available.length),
      reason: 'availableLabelsForCategory must not duplicate label IDs',
    );
  }, tags: 'glados');

  test('availableLabelsForCategory returns union of global + bucket', () async {
    final work = CategoryDefinition(
      id: 'work',
      name: 'Work',
      color: '#0000FF',
      createdAt: testEpochDateTime,
      updatedAt: testEpochDateTime,
      vectorClock: null,
      active: true,
      private: false,
    );
    final home = CategoryDefinition(
      id: 'home',
      name: 'Home',
      color: '#00FF00',
      createdAt: testEpochDateTime,
      updatedAt: testEpochDateTime,
      vectorClock: null,
      active: true,
      private: false,
    );

    final global = testLabelDefinition1.copyWith(id: 'g', name: 'Global');
    final scopedWork = testLabelDefinition1.copyWith(
      id: 'w',
      name: 'WorkOnly',
      applicableCategoryIds: const ['work'],
    );
    final scopedHome = testLabelDefinition1.copyWith(
      id: 'h',
      name: 'HomeOnly',
      applicableCategoryIds: const ['home'],
    );
    final privateLabel = testLabelDefinition1.copyWith(
      id: 'p',
      name: 'Private',
      private: true,
    );

    final cache = await createCache(
      categories: [work, home],
      labels: [global, scopedWork, scopedHome, privateLabel],
    );

    final forWork = cache.availableLabelsForCategory('work');
    final forHome = cache.availableLabelsForCategory('home');
    final forNull = cache.availableLabelsForCategory(null);

    expect(forWork.map((e) => e.id).toSet(), {'g', 'w'});
    expect(forHome.map((e) => e.id).toSet(), {'g', 'h'});
    expect(forNull.map((e) => e.id).toSet(), {'g'});
  });

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

  test('prunes orphan category keys on categories update', () {
    fakeAsync((async) {
      final work = CategoryDefinition(
        id: 'work',
        name: 'Work',
        color: '#0000FF',
        createdAt: testEpochDateTime,
        updatedAt: testEpochDateTime,
        vectorClock: null,
        active: true,
        private: false,
      );

      final global = testLabelDefinition1.copyWith(id: 'g', name: 'Global');
      final ghost = testLabelDefinition1.copyWith(
        id: 'x',
        name: 'Ghosted',
        applicableCategoryIds: const ['ghost'],
      );

      final cache = createCacheSync(
        async,
        categories: [work],
        labels: [global, ghost],
        privateFlag: true,
      );

      // Before prune, ghost bucket exists
      expect(
        cache.availableLabelsForCategory('ghost').map((e) => e.id).toSet(),
        {'g', 'x'},
      );

      // Trigger categories update (still only 'work') → prune removes 'ghost' key
      when(() => journalDb.getAllCategories()).thenAnswer((_) async => [work]);
      notifications.emit({categoriesNotification});
      async.flushMicrotasks();

      expect(
        cache.availableLabelsForCategory('ghost').map((e) => e.id).toSet(),
        {'g'},
      );
    });
  });

  test('availableLabelsForCategory respects private config flag', () {
    fakeAsync((async) {
      final cat = CategoryDefinition(
        id: 'work',
        name: 'Work',
        color: '#0000FF',
        createdAt: testEpochDateTime,
        updatedAt: testEpochDateTime,
        vectorClock: null,
        active: true,
        private: false,
      );
      final global = testLabelDefinition1.copyWith(id: 'g', name: 'Global');
      final privGlobal = testLabelDefinition1.copyWith(
        id: 'p',
        name: 'Priv',
        private: true,
      );
      final workPub = testLabelDefinition1.copyWith(
        id: 'w',
        name: 'WorkPub',
        applicableCategoryIds: const ['work'],
      );
      final workPriv = testLabelDefinition1.copyWith(
        id: 'wp',
        name: 'WorkPriv',
        private: true,
        applicableCategoryIds: const ['work'],
      );

      // Start with private=false
      final cache = createCacheSync(
        async,
        categories: [cat],
        labels: [global, privGlobal, workPub, workPriv],
      );

      expect(
        cache.availableLabelsForCategory('work').map((e) => e.id).toList(),
        containsAllInOrder(['g', 'w']),
      );
      expect(
        cache.availableLabelsForCategory('work').map((e) => e.id).toSet(),
        isNot(containsAll(['p', 'wp'])),
      );

      // Flip to private=true via notification
      when(
        () => journalDb.getConfigFlag('private'),
      ).thenAnswer((_) async => true);
      notifications.emit({privateToggleNotification});
      async.flushMicrotasks();

      expect(
        cache.availableLabelsForCategory('work').map((e) => e.id).toSet(),
        containsAll(['g', 'p', 'w', 'wp']),
      );
    });
  });

  test(
    'availableLabelsForCategory returns labels sorted case-insensitively',
    () async {
      final work = CategoryDefinition(
        id: 'work',
        name: 'Work',
        color: '#0000FF',
        createdAt: testEpochDateTime,
        updatedAt: testEpochDateTime,
        vectorClock: null,
        active: true,
        private: false,
      );
      final cache = await createCache(
        categories: [work],
        labels: [
          testLabelDefinition1.copyWith(id: 'a', name: 'apple'),
          testLabelDefinition1.copyWith(
            id: 'b',
            name: 'Banana',
            applicableCategoryIds: const ['work'],
          ),
          testLabelDefinition1.copyWith(id: 'c', name: 'cherry'),
        ],
        privateFlag: true,
      );

      final res = cache.availableLabelsForCategory('work');
      expect(res.map((l) => l.name).toList(), ['apple', 'Banana', 'cherry']);
    },
  );

  test('availableLabelsForCategory handles deleted categories gracefully', () {
    fakeAsync((async) {
      final work = CategoryDefinition(
        id: 'work',
        name: 'Work',
        color: '#0000FF',
        createdAt: testEpochDateTime,
        updatedAt: testEpochDateTime,
        vectorClock: null,
        active: true,
        private: false,
      );
      final personal = CategoryDefinition(
        id: 'personal',
        name: 'Personal',
        color: '#00FF00',
        createdAt: testEpochDateTime,
        updatedAt: testEpochDateTime,
        vectorClock: null,
        active: true,
        private: false,
      );
      final global = testLabelDefinition1.copyWith(id: 'g', name: 'Global');
      final scopedWork = testLabelDefinition1.copyWith(
        id: 'w',
        name: 'WorkOnly',
        applicableCategoryIds: const ['work'],
      );

      final cache = createCacheSync(
        async,
        categories: [work, personal],
        labels: [global, scopedWork],
        privateFlag: true,
      );

      expect(
        cache.availableLabelsForCategory('work').map((e) => e.id).toSet(),
        {'g', 'w'},
      );

      // Simulate deleting the 'work' category
      when(
        () => journalDb.getAllCategories(),
      ).thenAnswer((_) async => [personal]);
      notifications.emit({categoriesNotification});
      async.flushMicrotasks();

      expect(
        cache.availableLabelsForCategory('work').map((e) => e.id).toSet(),
        {'g'},
      );
    });
  });

  test('filterLabelsForCategory handles empty input list', () async {
    final cache = await createCache();
    final res = cache.filterLabelsForCategory(const [], 'any');
    expect(res, isEmpty);
  });

  test('pruning cleans up multiple orphaned categories at once', () {
    fakeAsync((async) {
      CategoryDefinition makeCat(String id) => CategoryDefinition(
        id: id,
        name: id.toUpperCase(),
        color: '#000000',
        createdAt: testEpochDateTime,
        updatedAt: testEpochDateTime,
        vectorClock: null,
        active: true,
        private: false,
      );

      final a = makeCat('a');
      final b = makeCat('b');
      final c = makeCat('c');
      final global = testLabelDefinition1.copyWith(id: 'g', name: 'Global');
      final la = testLabelDefinition1.copyWith(
        id: 'la',
        name: 'A',
        applicableCategoryIds: const ['a'],
      );
      final lb = testLabelDefinition1.copyWith(
        id: 'lb',
        name: 'B',
        applicableCategoryIds: const ['b'],
      );

      final cache = createCacheSync(
        async,
        categories: [a, b, c],
        labels: [global, la, lb],
        privateFlag: true,
      );

      expect(
        cache.availableLabelsForCategory('a').map((e) => e.id).toSet(),
        {'g', 'la'},
      );
      expect(
        cache.availableLabelsForCategory('b').map((e) => e.id).toSet(),
        {'g', 'lb'},
      );

      // Drop both a and b at once
      when(() => journalDb.getAllCategories()).thenAnswer((_) async => [c]);
      notifications.emit({categoriesNotification});
      async.flushMicrotasks();

      expect(
        cache.availableLabelsForCategory('a').map((e) => e.id).toSet(),
        {'g'},
      );
      expect(
        cache.availableLabelsForCategory('b').map((e) => e.id).toSet(),
        {'g'},
      );
    });
  });

  test(
    'availableLabelsForCategory de-duplicates labels present in multiple categories',
    () async {
      final cache = await createCache(
        categories: [
          CategoryDefinition(
            id: 'a',
            name: 'A',
            color: '#000000',
            createdAt: testEpochDateTime,
            updatedAt: testEpochDateTime,
            vectorClock: null,
            active: true,
            private: false,
          ),
          CategoryDefinition(
            id: 'b',
            name: 'B',
            color: '#000000',
            createdAt: testEpochDateTime,
            updatedAt: testEpochDateTime,
            vectorClock: null,
            active: true,
            private: false,
          ),
        ],
        labels: [
          testLabelDefinition1.copyWith(
            id: 'multi',
            name: 'Multi',
            applicableCategoryIds: const ['a', 'b'],
          ),
          testLabelDefinition1.copyWith(id: 'g', name: 'Global'),
        ],
        privateFlag: true,
      );

      final ids = cache
          .availableLabelsForCategory('a')
          .map((e) => e.id)
          .toList();
      expect(
        ids.where((id) => id == 'multi').length,
        1,
        reason: 'Label should not be duplicated in union',
      );
    },
  );

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

  test('globalLabels returns only global labels sorted by name', () async {
    final global1 = testLabelDefinition1.copyWith(id: 'g1', name: 'Zebra');
    final global2 = testLabelDefinition1.copyWith(id: 'g2', name: 'Apple');
    final scoped = testLabelDefinition1.copyWith(
      id: 's',
      name: 'Scoped',
      applicableCategoryIds: const ['work'],
    );
    final deleted = testLabelDefinition1.copyWith(
      id: 'd',
      name: 'Deleted',
      deletedAt: testEpochDateTime,
    );

    final cache = await createCache(
      labels: [global1, global2, scoped, deleted],
      privateFlag: true,
    );

    final globals = cache.globalLabels;
    expect(globals.length, 2);
    expect(globals.map((l) => l.name).toList(), ['Apple', 'Zebra']);
  });

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

  test(
    'availableLabelsForCategory with includePrivate override ignores config flag',
    () async {
      final global = testLabelDefinition1.copyWith(id: 'g', name: 'Global');
      final privateLabel = testLabelDefinition1.copyWith(
        id: 'p',
        name: 'Private',
        private: true,
      );

      final cache = await createCache(labels: [global, privateLabel]);

      // Config is false, but override to include private
      final withPrivate = cache.availableLabelsForCategory(
        null,
        includePrivate: true,
      );
      expect(withPrivate.map((l) => l.id).toSet(), {'g', 'p'});

      // Config is false, explicit override to exclude private
      final withoutPrivate = cache.availableLabelsForCategory(
        null,
        includePrivate: false,
      );
      expect(withoutPrivate.map((l) => l.id).toSet(), {'g'});
    },
  );

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
}
