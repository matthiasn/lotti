// ignore_for_file: avoid_redundant_argument_values

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/state/journal_query_runner.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'journal_query_runner_test_helpers.dart';

void main() {
  late MockJournalDb mockJournalDb;
  late MockFts5Db mockFts5Db;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late JournalQueryRunner runner;

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockFts5Db = MockFts5Db();
    mockEntitiesCacheService = MockEntitiesCacheService();

    when(() => mockEntitiesCacheService.sortedCategories).thenReturn([]);

    when(
      () => mockJournalDb.getJournalEntities(
        types: any(named: 'types'),
        starredStatuses: any(named: 'starredStatuses'),
        privateStatuses: any(named: 'privateStatuses'),
        flaggedStatuses: any(named: 'flaggedStatuses'),
        ids: any(named: 'ids'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        categoryIds: any(named: 'categoryIds'),
      ),
    ).thenAnswer((_) async => <JournalEntity>[]);

    when(
      () => mockJournalDb.getTasks(
        ids: any(named: 'ids'),
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
        sortByDate: any(named: 'sortByDate'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => <JournalEntity>[]);

    when(
      () => mockJournalDb.getTasksSortedByDueDate(
        ids: any(named: 'ids'),
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => <JournalEntity>[]);

    when(
      () => mockJournalDb.getTaskIdsForProjects(any()),
    ).thenAnswer((_) async => <String>{});

    runner = JournalQueryRunner(
      db: mockJournalDb,
      fts5Db: mockFts5Db,
      entitiesCacheService: mockEntitiesCacheService,
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('fts5Search', () {
    test('returns empty set for empty query', () {
      fakeAsync((async) {
        late Set<String> result;
        runner.fts5Search('').then((r) => result = r);
        async.flushMicrotasks();

        expect(result, isEmpty);
        verifyNever(() => mockFts5Db.watchFullTextMatches(any()));
      });
    });

    test('returns matching IDs for non-empty query', () {
      fakeAsync((async) {
        when(
          () => mockFts5Db.watchFullTextMatches('flutter'),
        ).thenAnswer((_) => Stream.value(['id-1', 'id-2', 'id-1']));

        late Set<String> result;
        runner.fts5Search('flutter').then((r) => result = r);
        async.flushMicrotasks();

        expect(result, equals({'id-1', 'id-2'}));
        verify(() => mockFts5Db.watchFullTextMatches('flutter')).called(1);
      });
    });
  });

  group('runQuery - journal entries', () {
    test('calls getJournalEntities for showTasks=false', () {
      fakeAsync((async) {
        final entry = hMakeEntry(id: 'e-1', createdAt: hTestDate);

        when(
          () => mockJournalDb.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            categoryIds: any(named: 'categoryIds'),
          ),
        ).thenAnswer((_) async => [entry]);

        final params = hDefaultParams();

        late List<JournalEntity> result;
        runner.runQuery(params, 0, fullTextMatches: {}).then((r) => result = r);
        async.flushMicrotasks();

        expect(result, hasLength(1));
        expect(result.first.meta.id, equals('e-1'));
        verify(
          () => mockJournalDb.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            limit: 50,
            offset: 0,
            categoryIds: any(named: 'categoryIds'),
          ),
        ).called(1);
      });
    });

    test('passes categoryIds when selectedCategoryIds is non-empty', () {
      fakeAsync((async) {
        final params = hDefaultParams(
          selectedCategoryIds: {'cat-1', 'cat-2'},
        );

        late List<JournalEntity> result;
        runner.runQuery(params, 0, fullTextMatches: {}).then((r) => result = r);
        async.flushMicrotasks();

        final captured = verify(
          () => mockJournalDb.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            categoryIds: captureAny(named: 'categoryIds'),
          ),
        ).captured;

        final categoryIds = captured.first as Set<String>?;
        expect(categoryIds, isNotNull);
        expect(categoryIds, equals({'cat-1', 'cat-2'}));
        expect(result, isEmpty);
      });
    });

    test('passes correct types filtered by feature flags', () {
      fakeAsync((async) {
        final params = hDefaultParams(
          selectedEntryTypes: {'JournalEntry', 'JournalEvent', 'Task'},
          enableEvents: false,
        );

        late List<JournalEntity> result;
        runner.runQuery(params, 0, fullTextMatches: {}).then((r) => result = r);
        async.flushMicrotasks();

        final captured = verify(
          () => mockJournalDb.getJournalEntities(
            types: captureAny(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            categoryIds: any(named: 'categoryIds'),
          ),
        ).captured;

        final types = captured.first as List<String>;
        expect(types, contains('JournalEntry'));
        expect(types, isNot(contains('JournalEvent')));
        expect(result, isEmpty);
      });
    });
  });

  group('runQuery - tasks without post-filter', () {
    test('calls getTasks with correct params', () {
      fakeAsync((async) {
        final task = hMakeTask(id: 'task-1', createdAt: hTestDate);

        when(
          () => mockJournalDb.getTasks(
            ids: any(named: 'ids'),
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            labelIds: any(named: 'labelIds'),
            priorities: any(named: 'priorities'),
            sortByDate: any(named: 'sortByDate'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => [task]);

        final params = hDefaultParams(
          showTasks: true,
          selectedTaskStatuses: {'OPEN'},
        );

        late List<JournalEntity> result;
        runner.runQuery(params, 0, fullTextMatches: {}).then((r) => result = r);
        async.flushMicrotasks();

        expect(result, hasLength(1));
        expect(result.first.meta.id, equals('task-1'));
        verify(
          () => mockJournalDb.getTasks(
            ids: any(named: 'ids'),
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            labelIds: any(named: 'labelIds'),
            priorities: any(named: 'priorities'),
            sortByDate: any(named: 'sortByDate'),
            limit: 50,
            offset: 0,
          ),
        ).called(1);
      });
    });

    test('uses getTasksSortedByDueDate when sortOption is byDueDate', () {
      fakeAsync((async) {
        final taskWithDue = hMakeTask(
          id: 'with-due',
          createdAt: DateTime(2024, 1, 2),
          due: DateTime(2024, 6, 1),
        );
        final taskNoDue = hMakeTask(
          id: 'no-due',
          createdAt: DateTime(2024, 1, 1),
        );

        // DB returns already-sorted results
        when(
          () => mockJournalDb.getTasksSortedByDueDate(
            ids: any(named: 'ids'),
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            labelIds: any(named: 'labelIds'),
            priorities: any(named: 'priorities'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => [taskWithDue, taskNoDue]);

        final params = hDefaultParams(
          showTasks: true,
          sortOption: TaskSortOption.byDueDate,
        );

        late List<JournalEntity> result;
        runner.runQuery(params, 0, fullTextMatches: {}).then((r) => result = r);
        async.flushMicrotasks();

        expect(result.first.meta.id, equals('with-due'));
        expect(result.last.meta.id, equals('no-due'));

        verify(
          () => mockJournalDb.getTasksSortedByDueDate(
            ids: any(named: 'ids'),
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            labelIds: any(named: 'labelIds'),
            priorities: any(named: 'priorities'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).called(1);
      });
    });
  });
}
