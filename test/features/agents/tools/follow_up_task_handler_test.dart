import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/tools/follow_up_task_handler.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockPersistenceLogic mockPersistenceLogic;
  late MockJournalDb mockJournalDb;
  late FollowUpTaskHandler handler;

  const sourceTaskId = 'source-task-001';
  const categoryId = 'cat-001';
  final testDate = DateTime(2024, 6, 15, 12);

  Task makeSourceTask({String? taskCategoryId = categoryId}) {
    return Task(
      meta: Metadata(
        id: sourceTaskId,
        dateFrom: DateTime(2024, 3, 15),
        dateTo: DateTime(2024, 3, 15),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        categoryId: taskCategoryId,
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: sourceTaskId,
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 0,
        ),
        dateFrom: DateTime(2024, 3, 15),
        dateTo: DateTime(2024, 3, 15),
        statusHistory: [],
        title: 'Source Task',
      ),
    );
  }

  Task makeNewTask(String id) {
    return Task(
      meta: Metadata(
        id: id,
        dateFrom: testDate,
        dateTo: testDate,
        createdAt: testDate,
        updatedAt: testDate,
        categoryId: categoryId,
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: id,
          createdAt: testDate,
          utcOffset: 0,
        ),
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: [],
        title: 'Follow-Up Task',
      ),
    );
  }

  setUp(() {
    mockPersistenceLogic = MockPersistenceLogic();
    mockJournalDb = MockJournalDb();
    handler = FollowUpTaskHandler(
      persistenceLogic: mockPersistenceLogic,
      journalDb: mockJournalDb,
    );
  });

  group('FollowUpTaskHandler', () {
    group('validation', () {
      test('returns failure when title is missing', () async {
        final result = await handler.handle(
          sourceTaskId,
          <String, dynamic>{},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"title" must be a non-empty string'));
        expect(result.errorMessage, 'Missing or empty title');
      });

      test('returns failure when title is empty', () async {
        final result = await handler.handle(
          sourceTaskId,
          {'title': '   '},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"title" must be a non-empty string'));
      });

      test('returns failure when title is non-string', () async {
        final result = await handler.handle(
          sourceTaskId,
          {'title': 42},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"title" must be a non-empty string'));
      });

      test('returns failure when source task not found', () async {
        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => null);

        final result = await handler.handle(
          sourceTaskId,
          {'title': 'Follow-Up'},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('not found or not a Task'));
        expect(result.errorMessage, 'Source task lookup failed');
      });
    });

    group('task creation', () {
      test('creates task with correct title and default priority', () async {
        final sourceTask = makeSourceTask();
        final newTask = makeNewTask('new-task-001');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        await withClock(Clock.fixed(testDate), () async {
          final result = await handler.handle(
            sourceTaskId,
            {'title': 'Follow-Up'},
          );

          expect(result.success, isTrue);
          expect(result.output, contains('Follow-Up'));
          expect(result.output, contains('new-task-001'));
          expect(result.mutatedEntityId, 'new-task-001');

          // Verify task data passed to createTaskEntry.
          final captured = verify(
            () => mockPersistenceLogic.createTaskEntry(
              data: captureAny(named: 'data'),
              entryText: any(named: 'entryText'),
              categoryId: captureAny(named: 'categoryId'),
            ),
          ).captured;

          final taskData = captured[0] as TaskData;
          expect(taskData.title, 'Follow-Up');
          expect(taskData.priority, TaskPriority.p2Medium);

          // Category inherited from source.
          expect(captured[1], categoryId);
        });
      });

      test('creates task with custom priority and due date', () async {
        final sourceTask = makeSourceTask();
        final newTask = makeNewTask('new-task-002');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        await withClock(Clock.fixed(testDate), () async {
          final result = await handler.handle(
            sourceTaskId,
            {
              'title': 'Urgent Follow-Up',
              'priority': 'P1',
              'dueDate': '2024-12-31',
              'description': 'Some details',
            },
          );

          expect(result.success, isTrue);

          final captured = verify(
            () => mockPersistenceLogic.createTaskEntry(
              data: captureAny(named: 'data'),
              entryText: captureAny(named: 'entryText'),
              categoryId: any(named: 'categoryId'),
            ),
          ).captured;

          final taskData = captured[0] as TaskData;
          expect(taskData.priority, TaskPriority.p1High);
          expect(taskData.due, DateTime(2024, 12, 31));
        });
      });

      test('returns failure when createTaskEntry returns null', () async {
        final sourceTask = makeSourceTask();

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

        await withClock(Clock.fixed(testDate), () async {
          final result = await handler.handle(
            sourceTaskId,
            {'title': 'Will Fail'},
          );

          expect(result.success, isFalse);
          expect(result.errorMessage, 'Task creation failed');
        });
      });
    });

    group('link creation', () {
      test('creates link from source to new task', () async {
        final sourceTask = makeSourceTask();
        final newTask = makeNewTask('new-task-003');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        await withClock(Clock.fixed(testDate), () async {
          await handler.handle(
            sourceTaskId,
            {'title': 'Linked Task'},
          );

          verify(
            () => mockPersistenceLogic.createLink(
              fromId: sourceTaskId,
              toId: 'new-task-003',
            ),
          ).called(1);
        });
      });

      test('creates audio link when sourceAudioId is provided', () async {
        final sourceTask = makeSourceTask();
        final newTask = makeNewTask('new-task-004');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        await withClock(Clock.fixed(testDate), () async {
          await handler.handle(
            sourceTaskId,
            {
              'title': 'Audio Follow-Up',
              'sourceAudioId': 'audio-001',
            },
          );

          // Two links: source→task and audio→task.
          verify(
            () => mockPersistenceLogic.createLink(
              fromId: sourceTaskId,
              toId: 'new-task-004',
            ),
          ).called(1);
          verify(
            () => mockPersistenceLogic.createLink(
              fromId: 'audio-001',
              toId: 'new-task-004',
            ),
          ).called(1);
        });
      });

      test('skips audio link when sourceAudioId is empty', () async {
        final sourceTask = makeSourceTask();
        final newTask = makeNewTask('new-task-005');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        await withClock(Clock.fixed(testDate), () async {
          await handler.handle(
            sourceTaskId,
            {
              'title': 'No Audio',
              'sourceAudioId': '',
            },
          );

          // Only one link: source→task.
          verify(
            () => mockPersistenceLogic.createLink(
              fromId: any(named: 'fromId'),
              toId: any(named: 'toId'),
            ),
          ).called(1);
        });
      });
    });

    group('category inheritance', () {
      test('inherits null category when source has none', () async {
        final sourceTask = makeSourceTask(taskCategoryId: null);
        final newTask = makeNewTask('new-task-006');

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => sourceTask);

        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => newTask);

        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
          ),
        ).thenAnswer((_) async => true);

        await withClock(Clock.fixed(testDate), () async {
          await handler.handle(
            sourceTaskId,
            {'title': 'No Category'},
          );

          final captured = verify(
            () => mockPersistenceLogic.createTaskEntry(
              data: any(named: 'data'),
              entryText: any(named: 'entryText'),
              categoryId: captureAny(named: 'categoryId'),
            ),
          ).captured;

          expect(captured[0], isNull);
        });
      });
    });
  });
}
