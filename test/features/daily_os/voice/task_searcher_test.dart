import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/daily_os/voice/day_plan_voice_strategy.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockFts5Db extends Mock implements Fts5Db {}

class FakeSelectable<T> extends Fake implements Selectable<T> {
  FakeSelectable(this._value);
  final List<T> _value;

  @override
  Future<List<T>> get() async => _value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockJournalDb mockDb;
  late MockFts5Db mockFts5Db;
  late TaskSearcher taskSearcher;

  final testDate = DateTime(2026, 1, 15);

  Task createTestTask({
    required String id,
    required String title,
    String? categoryId,
    TaskStatus? status,
  }) {
    return Task(
      meta: Metadata(
        id: id,
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
        categoryId: categoryId,
      ),
      data: TaskData(
        title: title,
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: [],
        status: status ??
            TaskStatus.open(
              id: 'status-1',
              createdAt: testDate,
              utcOffset: 0,
            ),
      ),
    );
  }

  setUp(() {
    mockDb = MockJournalDb();
    mockFts5Db = MockFts5Db();
    taskSearcher = TaskSearcher(mockDb, mockFts5Db);
  });

  group('TaskSearcher', () {
    group('findByTitle', () {
      test('returns task when FTS5 finds matching ID', () async {
        final task = createTestTask(
          id: 'task-1',
          title: 'Fix the API bug',
          categoryId: 'cat-work',
        );

        when(() => mockFts5Db.findMatching('title:"API"*'))
            .thenReturn(FakeSelectable(['task-1']));

        when(
          () => mockDb.getTasks(
            starredStatuses: [false, true],
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: [],
            ids: ['task-1'],
          ),
        ).thenAnswer((_) async => [task]);

        final result = await taskSearcher.findByTitle('API');

        expect(result, isNotNull);
        expect(result!.id, 'task-1');
        expect(result.data.title, 'Fix the API bug');
      });

      test('returns null when no FTS5 matches', () async {
        when(() => mockFts5Db.findMatching('title:"nonexistent"*'))
            .thenReturn(FakeSelectable([]));

        final result = await taskSearcher.findByTitle('nonexistent');

        expect(result, isNull);
        verifyNever(
          () => mockDb.getTasks(
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            ids: any(named: 'ids'),
          ),
        );
      });

      test('returns null when FTS5 matches but tasks are not open', () async {
        when(() => mockFts5Db.findMatching('title:"closed"*'))
            .thenReturn(FakeSelectable(['task-1']));

        // Return empty list (no open tasks with that ID)
        when(
          () => mockDb.getTasks(
            starredStatuses: [false, true],
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: [],
            ids: ['task-1'],
          ),
        ).thenAnswer((_) async => []);

        final result = await taskSearcher.findByTitle('closed');

        expect(result, isNull);
      });

      test('returns exact title match when multiple tasks found', () async {
        final task1 = createTestTask(
          id: 'task-1',
          title: 'Fix API endpoints',
          categoryId: 'cat-work',
        );
        final task2 = createTestTask(
          id: 'task-2',
          title: 'API', // Exact match
          categoryId: 'cat-work',
        );
        final task3 = createTestTask(
          id: 'task-3',
          title: 'API documentation',
          categoryId: 'cat-work',
        );

        when(() => mockFts5Db.findMatching('title:"API"*'))
            .thenReturn(FakeSelectable(['task-1', 'task-2', 'task-3']));

        when(
          () => mockDb.getTasks(
            starredStatuses: [false, true],
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: [],
            ids: ['task-1', 'task-2', 'task-3'],
          ),
        ).thenAnswer((_) async => [task1, task2, task3]);

        final result = await taskSearcher.findByTitle('API');

        expect(result, isNotNull);
        expect(result!.id, 'task-2'); // Exact match preferred
        expect(result.data.title, 'API');
      });

      test('returns first task when no exact match', () async {
        final task1 = createTestTask(
          id: 'task-1',
          title: 'Fix API endpoints',
          categoryId: 'cat-work',
        );
        final task2 = createTestTask(
          id: 'task-2',
          title: 'API documentation',
          categoryId: 'cat-work',
        );

        when(() => mockFts5Db.findMatching('title:"API"*'))
            .thenReturn(FakeSelectable(['task-1', 'task-2']));

        when(
          () => mockDb.getTasks(
            starredStatuses: [false, true],
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: [],
            ids: ['task-1', 'task-2'],
          ),
        ).thenAnswer((_) async => [task1, task2]);

        final result = await taskSearcher.findByTitle('API');

        expect(result, isNotNull);
        expect(result!.id, 'task-1'); // First result when no exact match
      });

      test('exact match is case-insensitive', () async {
        final task = createTestTask(
          id: 'task-1',
          title: 'Fix the Bug',
          categoryId: 'cat-work',
        );

        when(() => mockFts5Db.findMatching('title:"fix the bug"*'))
            .thenReturn(FakeSelectable(['task-1']));

        when(
          () => mockDb.getTasks(
            starredStatuses: [false, true],
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: [],
            ids: ['task-1'],
          ),
        ).thenAnswer((_) async => [task]);

        final result = await taskSearcher.findByTitle('fix the bug');

        expect(result, isNotNull);
        expect(result!.id, 'task-1');
      });

      test('filters non-Task entities from results', () async {
        final task = createTestTask(
          id: 'task-1',
          title: 'Real task',
          categoryId: 'cat-work',
        );

        // JournalEntry (not a Task)
        final journalEntry = JournalEntity.journalEntry(
          meta: Metadata(
            id: 'entry-1',
            createdAt: testDate,
            updatedAt: testDate,
            dateFrom: testDate,
            dateTo: testDate,
          ),
        );

        when(() => mockFts5Db.findMatching('title:"task"*'))
            .thenReturn(FakeSelectable(['task-1', 'entry-1']));

        when(
          () => mockDb.getTasks(
            starredStatuses: [false, true],
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: [],
            ids: ['task-1', 'entry-1'],
          ),
        ).thenAnswer((_) async => [task, journalEntry]);

        final result = await taskSearcher.findByTitle('task');

        expect(result, isNotNull);
        expect(result!.id, 'task-1');
      });

      test('handles task with category', () async {
        final task = createTestTask(
          id: 'task-1',
          title: 'Task with category',
          categoryId: 'cat-work',
        );

        when(() => mockFts5Db.findMatching('title:"category"*'))
            .thenReturn(FakeSelectable(['task-1']));

        when(
          () => mockDb.getTasks(
            starredStatuses: [false, true],
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: [],
            ids: ['task-1'],
          ),
        ).thenAnswer((_) async => [task]);

        final result = await taskSearcher.findByTitle('category');

        expect(result, isNotNull);
        expect(result!.meta.categoryId, 'cat-work');
      });

      test('handles task without category', () async {
        final task = createTestTask(
          id: 'task-1',
          title: 'Task without category',
        );

        when(() => mockFts5Db.findMatching('title:"without"*'))
            .thenReturn(FakeSelectable(['task-1']));

        when(
          () => mockDb.getTasks(
            starredStatuses: [false, true],
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: [],
            ids: ['task-1'],
          ),
        ).thenAnswer((_) async => [task]);

        final result = await taskSearcher.findByTitle('without');

        expect(result, isNotNull);
        expect(result!.meta.categoryId, isNull);
      });
    });
  });
}
