// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import '../test_data/test_data.dart';

void main() {
  late MockJournalDb journalDb;
  late MockUpdateNotifications notifications;

  setUp(() async {
    journalDb = MockJournalDb();
    notifications = MockUpdateNotifications();
    await getIt.reset();
    getIt
      ..registerSingleton<JournalDb>(journalDb)
      ..registerSingleton<UpdateNotifications>(notifications);
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('availableLabelsForCategory returns union of global + bucket', () {
    fakeAsync((async) {
      // Arrange categories
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

      // Labels: one global, one scoped to work, one scoped to home, one private
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

      when(journalDb.watchMeasurableDataTypes).thenAnswer(
        (_) => Stream<List<MeasurableDataType>>.fromIterable([
          const <MeasurableDataType>[],
        ]),
      );
      when(journalDb.watchHabitDefinitions).thenAnswer(
        (_) => Stream<List<HabitDefinition>>.fromIterable([
          const <HabitDefinition>[],
        ]),
      );
      when(journalDb.watchDashboards).thenAnswer(
        (_) => Stream<List<DashboardDefinition>>.fromIterable([
          const <DashboardDefinition>[],
        ]),
      );
      when(journalDb.watchCategories)
          .thenAnswer((_) => Stream<List<CategoryDefinition>>.fromIterable([
                [work, home],
              ]));
      when(journalDb.watchLabelDefinitions)
          .thenAnswer((_) => Stream<List<LabelDefinition>>.fromIterable([
                [global, scopedWork, scopedHome, privateLabel],
              ]));
      when(() => journalDb.watchConfigFlag('private')).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );

      final cache = EntitiesCacheService();
      // Allow streams to deliver
      async.elapse(const Duration(milliseconds: 10));
      async.flushMicrotasks();

      // Act
      final forWork = cache.availableLabelsForCategory('work');
      final forHome = cache.availableLabelsForCategory('home');
      final forNull = cache.availableLabelsForCategory(null);

      // Assert
      expect(forWork.map((e) => e.id).toSet(), {'g', 'w'});
      expect(forHome.map((e) => e.id).toSet(), {'g', 'h'});
      expect(forNull.map((e) => e.id).toSet(), {'g'});
    });
  });

  test('filterLabelsForCategory respects includePrivate', () async {
    when(journalDb.watchMeasurableDataTypes).thenAnswer(
      (_) => Stream<List<MeasurableDataType>>.fromIterable([
        const <MeasurableDataType>[],
      ]),
    );
    when(journalDb.watchHabitDefinitions).thenAnswer(
      (_) => Stream<List<HabitDefinition>>.fromIterable([
        const <HabitDefinition>[],
      ]),
    );
    when(journalDb.watchDashboards).thenAnswer(
      (_) => Stream<List<DashboardDefinition>>.fromIterable([
        const <DashboardDefinition>[],
      ]),
    );
    when(journalDb.watchCategories).thenAnswer(
      (_) => Stream<List<CategoryDefinition>>.fromIterable([
        const <CategoryDefinition>[],
      ]),
    );
    when(journalDb.watchLabelDefinitions).thenAnswer(
      (_) => Stream<List<LabelDefinition>>.fromIterable([
        const <LabelDefinition>[],
      ]),
    );
    when(() => journalDb.watchConfigFlag('private')).thenAnswer(
      (_) => Stream<bool>.fromIterable([false]),
    );
    final cache = EntitiesCacheService();
    // Do not rely on watchers for this pure helper
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

    final withoutPrivate = cache.filterLabelsForCategory(
      all,
      'work',
      includePrivate: false,
    );
    final withPrivate = cache.filterLabelsForCategory(
      all,
      'work',
      includePrivate: true,
    );

    expect(withoutPrivate.map((e) => e.id).toSet(), {'g', 'w'});
    expect(withPrivate.map((e) => e.id).toSet(), {'g', 'w', 'p'});
  });

  test('prunes orphan category keys on categories update', () {
    fakeAsync((async) {
      final categoriesCtrl =
          StreamController<List<CategoryDefinition>>.broadcast();
      final labelsCtrl = StreamController<List<LabelDefinition>>.broadcast();
      addTearDown(() async {
        await categoriesCtrl.close();
        await labelsCtrl.close();
      });

      when(journalDb.watchMeasurableDataTypes).thenAnswer(
        (_) => Stream<List<MeasurableDataType>>.fromIterable([
          const <MeasurableDataType>[],
        ]),
      );
      when(journalDb.watchHabitDefinitions).thenAnswer(
        (_) => Stream<List<HabitDefinition>>.fromIterable([
          const <HabitDefinition>[],
        ]),
      );
      when(journalDb.watchDashboards).thenAnswer(
        (_) => Stream<List<DashboardDefinition>>.fromIterable([
          const <DashboardDefinition>[],
        ]),
      );
      when(journalDb.watchCategories).thenAnswer((_) => categoriesCtrl.stream);
      when(journalDb.watchLabelDefinitions)
          .thenAnswer((_) => labelsCtrl.stream);
      when(() => journalDb.watchConfigFlag('private')).thenAnswer(
        (_) => Stream<bool>.fromIterable([true]),
      );

      final cache = EntitiesCacheService();

      // Initial categories: only 'work'
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
      categoriesCtrl.add([work]);
      async.elapse(const Duration(milliseconds: 5));
      async.flushMicrotasks();

      // Labels: one global and one scoped to unknown 'ghost'
      final global = testLabelDefinition1.copyWith(id: 'g', name: 'Global');
      final ghost = testLabelDefinition1.copyWith(
        id: 'x',
        name: 'Ghosted',
        applicableCategoryIds: const ['ghost'],
      );
      labelsCtrl.add([global, ghost]);
      async.elapse(const Duration(milliseconds: 5));
      async.flushMicrotasks();

      // Before prune, ghost bucket exists
      expect(cache.availableLabelsForCategory('ghost').map((e) => e.id).toSet(),
          {'g', 'x'});

      // Trigger categories update (still only 'work') → prune removes 'ghost' key
      categoriesCtrl.add([work]);
      async.elapse(const Duration(milliseconds: 5));
      async.flushMicrotasks();

      expect(cache.availableLabelsForCategory('ghost').map((e) => e.id).toSet(),
          {'g'});
    });
  });

  test('availableLabelsForCategory respects private config flag', () {
    fakeAsync((async) {
      final categoriesCtrl =
          StreamController<List<CategoryDefinition>>.broadcast();
      final labelsCtrl = StreamController<List<LabelDefinition>>.broadcast();
      final privateCtrl = StreamController<bool>.broadcast();
      addTearDown(() async {
        await categoriesCtrl.close();
        await labelsCtrl.close();
        await privateCtrl.close();
      });

      when(journalDb.watchMeasurableDataTypes).thenAnswer(
        (_) => Stream<List<MeasurableDataType>>.fromIterable([
          const <MeasurableDataType>[],
        ]),
      );
      when(journalDb.watchHabitDefinitions).thenAnswer(
        (_) => Stream<List<HabitDefinition>>.fromIterable([
          const <HabitDefinition>[],
        ]),
      );
      when(journalDb.watchDashboards).thenAnswer(
        (_) => Stream<List<DashboardDefinition>>.fromIterable([
          const <DashboardDefinition>[],
        ]),
      );
      when(journalDb.watchCategories).thenAnswer((_) => categoriesCtrl.stream);
      when(journalDb.watchLabelDefinitions)
          .thenAnswer((_) => labelsCtrl.stream);
      when(() => journalDb.watchConfigFlag('private'))
          .thenAnswer((_) => privateCtrl.stream);

      final cache = EntitiesCacheService();

      // Emit categories and labels
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
      categoriesCtrl.add([cat]);
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
      labelsCtrl.add([global, privGlobal, workPub, workPriv]);

      // Start with includePrivate=false
      privateCtrl.add(false);
      async.elapse(const Duration(milliseconds: 10));
      async.flushMicrotasks();
      expect(cache.availableLabelsForCategory('work').map((e) => e.id).toList(),
          containsAllInOrder(['g', 'w']));
      expect(
        cache.availableLabelsForCategory('work').map((e) => e.id).toSet(),
        isNot(containsAll(['p', 'wp'])),
      );

      // Flip includePrivate=true and validate both privates are included
      privateCtrl.add(true);
      async.elapse(const Duration(milliseconds: 10));
      async.flushMicrotasks();
      expect(
        cache.availableLabelsForCategory('work').map((e) => e.id).toSet(),
        containsAll(['g', 'p', 'w', 'wp']),
      );
    });
  });

  test('availableLabelsForCategory returns labels sorted case-insensitively',
      () {
    fakeAsync((async) {
      when(journalDb.watchMeasurableDataTypes).thenAnswer(
        (_) => Stream<List<MeasurableDataType>>.fromIterable([
          const <MeasurableDataType>[],
        ]),
      );
      when(journalDb.watchHabitDefinitions).thenAnswer(
        (_) => Stream<List<HabitDefinition>>.fromIterable([
          const <HabitDefinition>[],
        ]),
      );
      when(journalDb.watchDashboards).thenAnswer(
        (_) => Stream<List<DashboardDefinition>>.fromIterable([
          const <DashboardDefinition>[],
        ]),
      );
      when(journalDb.watchCategories).thenAnswer(
        (_) => Stream<List<CategoryDefinition>>.fromIterable([
          [
            CategoryDefinition(
              id: 'work',
              name: 'Work',
              color: '#0000FF',
              createdAt: testEpochDateTime,
              updatedAt: testEpochDateTime,
              vectorClock: null,
              active: true,
              private: false,
            ),
          ],
        ]),
      );
      when(journalDb.watchLabelDefinitions).thenAnswer(
        (_) => Stream<List<LabelDefinition>>.fromIterable([
          [
            testLabelDefinition1.copyWith(id: 'a', name: 'apple'),
            testLabelDefinition1.copyWith(
              id: 'b',
              name: 'Banana',
              applicableCategoryIds: const ['work'],
            ),
            testLabelDefinition1.copyWith(id: 'c', name: 'cherry'),
          ],
        ]),
      );
      when(() => journalDb.watchConfigFlag('private')).thenAnswer(
        (_) => Stream<bool>.fromIterable([true]),
      );

      final cache = EntitiesCacheService();
      async.elapse(const Duration(milliseconds: 10));
      async.flushMicrotasks();
      final res = cache.availableLabelsForCategory('work');
      expect(res.map((l) => l.name).toList(), ['apple', 'Banana', 'cherry']);
    });
  });

  test('availableLabelsForCategory handles deleted categories gracefully', () {
    fakeAsync((async) {
      final categoriesCtrl =
          StreamController<List<CategoryDefinition>>.broadcast();
      final labelsCtrl = StreamController<List<LabelDefinition>>.broadcast();
      addTearDown(() async {
        await categoriesCtrl.close();
        await labelsCtrl.close();
      });

      when(journalDb.watchMeasurableDataTypes).thenAnswer(
        (_) => Stream<List<MeasurableDataType>>.fromIterable([
          const <MeasurableDataType>[],
        ]),
      );
      when(journalDb.watchHabitDefinitions).thenAnswer(
        (_) => Stream<List<HabitDefinition>>.fromIterable([
          const <HabitDefinition>[],
        ]),
      );
      when(journalDb.watchDashboards).thenAnswer(
        (_) => Stream<List<DashboardDefinition>>.fromIterable([
          const <DashboardDefinition>[],
        ]),
      );
      when(journalDb.watchCategories).thenAnswer((_) => categoriesCtrl.stream);
      when(journalDb.watchLabelDefinitions)
          .thenAnswer((_) => labelsCtrl.stream);
      when(() => journalDb.watchConfigFlag('private')).thenAnswer(
        (_) => Stream<bool>.fromIterable([true]),
      );

      final cache = EntitiesCacheService();

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
      categoriesCtrl.add([work, personal]);
      final global = testLabelDefinition1.copyWith(id: 'g', name: 'Global');
      final scopedWork = testLabelDefinition1.copyWith(
        id: 'w',
        name: 'WorkOnly',
        applicableCategoryIds: const ['work'],
      );
      labelsCtrl.add([global, scopedWork]);
      async.elapse(const Duration(milliseconds: 10));
      async.flushMicrotasks();

      expect(cache.availableLabelsForCategory('work').map((e) => e.id).toSet(),
          {'g', 'w'});

      // Simulate deleting the 'work' category → cache should fall back to globals
      categoriesCtrl.add([personal]);
      async.elapse(const Duration(milliseconds: 10));
      async.flushMicrotasks();
      expect(cache.availableLabelsForCategory('work').map((e) => e.id).toSet(),
          {'g'});
    });
  });

  test('filterLabelsForCategory handles empty input list', () {
    fakeAsync((async) {
      when(journalDb.watchMeasurableDataTypes).thenAnswer(
        (_) => Stream<List<MeasurableDataType>>.fromIterable([
          const <MeasurableDataType>[],
        ]),
      );
      when(journalDb.watchHabitDefinitions).thenAnswer(
        (_) => Stream<List<HabitDefinition>>.fromIterable([
          const <HabitDefinition>[],
        ]),
      );
      when(journalDb.watchDashboards).thenAnswer(
        (_) => Stream<List<DashboardDefinition>>.fromIterable([
          const <DashboardDefinition>[],
        ]),
      );
      when(journalDb.watchCategories).thenAnswer(
        (_) => Stream<List<CategoryDefinition>>.fromIterable([
          const <CategoryDefinition>[],
        ]),
      );
      when(journalDb.watchLabelDefinitions).thenAnswer(
        (_) => Stream<List<LabelDefinition>>.fromIterable([
          const <LabelDefinition>[],
        ]),
      );
      when(() => journalDb.watchConfigFlag('private')).thenAnswer(
        (_) => Stream<bool>.fromIterable([false]),
      );

      final cache = EntitiesCacheService();
      async.elapse(const Duration(milliseconds: 5));
      async.flushMicrotasks();

      final res = cache.filterLabelsForCategory(const [], 'any');
      expect(res, isEmpty);
    });
  });

  test('pruning cleans up multiple orphaned categories at once', () {
    fakeAsync((async) {
      final categoriesCtrl =
          StreamController<List<CategoryDefinition>>.broadcast();
      final labelsCtrl = StreamController<List<LabelDefinition>>.broadcast();
      addTearDown(() async {
        await categoriesCtrl.close();
        await labelsCtrl.close();
      });

      when(journalDb.watchMeasurableDataTypes).thenAnswer(
        (_) => Stream<List<MeasurableDataType>>.fromIterable([
          const <MeasurableDataType>[],
        ]),
      );
      when(journalDb.watchHabitDefinitions).thenAnswer(
        (_) => Stream<List<HabitDefinition>>.fromIterable([
          const <HabitDefinition>[],
        ]),
      );
      when(journalDb.watchDashboards).thenAnswer(
        (_) => Stream<List<DashboardDefinition>>.fromIterable([
          const <DashboardDefinition>[],
        ]),
      );
      when(journalDb.watchCategories).thenAnswer((_) => categoriesCtrl.stream);
      when(journalDb.watchLabelDefinitions)
          .thenAnswer((_) => labelsCtrl.stream);
      when(() => journalDb.watchConfigFlag('private')).thenAnswer(
        (_) => Stream<bool>.fromIterable([true]),
      );

      final cache = EntitiesCacheService();

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
      categoriesCtrl.add([a, b, c]);

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
      labelsCtrl.add([global, la, lb]);
      async.elapse(const Duration(milliseconds: 10));
      async.flushMicrotasks();

      expect(cache.availableLabelsForCategory('a').map((e) => e.id).toSet(),
          {'g', 'la'});
      expect(cache.availableLabelsForCategory('b').map((e) => e.id).toSet(),
          {'g', 'lb'});

      // Drop both a and b at once
      categoriesCtrl.add([c]);
      async.elapse(const Duration(milliseconds: 10));
      async.flushMicrotasks();

      expect(cache.availableLabelsForCategory('a').map((e) => e.id).toSet(),
          {'g'});
      expect(cache.availableLabelsForCategory('b').map((e) => e.id).toSet(),
          {'g'});
    });
  });

  test(
      'availableLabelsForCategory de-duplicates labels present in multiple categories',
      () {
    fakeAsync((async) {
      when(journalDb.watchMeasurableDataTypes).thenAnswer(
        (_) => Stream<List<MeasurableDataType>>.fromIterable([
          const <MeasurableDataType>[],
        ]),
      );
      when(journalDb.watchHabitDefinitions).thenAnswer(
        (_) => Stream<List<HabitDefinition>>.fromIterable([
          const <HabitDefinition>[],
        ]),
      );
      when(journalDb.watchDashboards).thenAnswer(
        (_) => Stream<List<DashboardDefinition>>.fromIterable([
          const <DashboardDefinition>[],
        ]),
      );
      when(journalDb.watchCategories).thenAnswer(
        (_) => Stream<List<CategoryDefinition>>.fromIterable([
          [
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
        ]),
      );
      when(journalDb.watchLabelDefinitions).thenAnswer(
        (_) => Stream<List<LabelDefinition>>.fromIterable([
          [
            testLabelDefinition1.copyWith(
              id: 'multi',
              name: 'Multi',
              applicableCategoryIds: const ['a', 'b'],
            ),
            testLabelDefinition1.copyWith(id: 'g', name: 'Global'),
          ],
        ]),
      );
      when(() => journalDb.watchConfigFlag('private')).thenAnswer(
        (_) => Stream<bool>.fromIterable([true]),
      );

      final cache = EntitiesCacheService();
      async.elapse(const Duration(milliseconds: 10));
      async.flushMicrotasks();

      final ids =
          cache.availableLabelsForCategory('a').map((e) => e.id).toList();
      expect(ids.where((id) => id == 'multi').length, 1,
          reason: 'Label should not be duplicated in union');
    });
  });
}
