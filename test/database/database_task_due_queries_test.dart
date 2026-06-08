// ignore_for_file: avoid_redundant_argument_values
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import 'test_utils.dart';

void main() {
  setUpAll(registerJournalDbTestFallbacks);

  JournalDb? db;
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockLoggingService = MockDomainLogger();
  late Directory testDirectory;

  group('JournalDb task due-date queries - ', () {
    // The expensive ~40-step migration ladder runs once for the whole file;
    // each test re-uses the instance and starts clean via clearAllTables.
    setUpAll(() async {
      db = JournalDb(inMemoryDatabase: true);
    });

    setUp(() async {
      testDirectory = setupTestDirectory();
      reset(mockLoggingService);
      registerJournalDbTestServices(
        updateNotifications: mockUpdateNotifications,
        loggingService: mockLoggingService,
        documentsDirectory: testDirectory,
      );
      await clearAllTables(db!);
      await initConfigFlags(db!, inMemoryDatabase: true);
    });

    tearDown(() async {
      unregisterJournalDbTestServices();
      if (testDirectory.existsSync()) {
        testDirectory.deleteSync(recursive: true);
      }
    });

    tearDownAll(() async {
      await db?.close();
      await getIt.reset();
    });

    group('Day-agent task queries -', () {
      test(
        'getOpenTasksForDayAgentCorpus returns scoped active tasks',
        () async {
          final base = DateTime(2024, 7, 3, 9);
          final dueOpenTask = buildTaskEntry(
            id: 'day-agent-open-due',
            timestamp: base,
            status: TaskStatus.open(
              id: 'status-open-due',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            categoryId: 'cat-day-agent',
            due: DateTime(2024, 7, 4, 12),
          );
          final inProgressTask = buildTaskEntry(
            id: 'day-agent-in-progress',
            timestamp: base.add(const Duration(minutes: 5)),
            status: TaskStatus.inProgress(
              id: 'status-in-progress-corpus',
              createdAt: base.add(const Duration(minutes: 5)),
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            categoryId: 'cat-day-agent',
          );
          final doneTask = buildTaskEntry(
            id: 'day-agent-done',
            timestamp: base.add(const Duration(minutes: 10)),
            status: TaskStatus.done(
              id: 'status-done-corpus',
              createdAt: base.add(const Duration(minutes: 10)),
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            categoryId: 'cat-day-agent',
          );
          final otherCategoryTask = buildTaskEntry(
            id: 'day-agent-other-cat',
            timestamp: base.add(const Duration(minutes: 15)),
            status: TaskStatus.open(
              id: 'status-other-corpus',
              createdAt: base.add(const Duration(minutes: 15)),
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            categoryId: 'cat-other',
            due: DateTime(2024, 7, 3, 10),
          );

          await db!.upsertJournalDbEntity(toDbEntity(dueOpenTask));
          await db!.upsertJournalDbEntity(toDbEntity(inProgressTask));
          await db!.upsertJournalDbEntity(toDbEntity(doneTask));
          await db!.upsertJournalDbEntity(toDbEntity(otherCategoryTask));

          final results = await db!.getOpenTasksForDayAgentCorpus(
            categoryIds: {'cat-day-agent'},
          );

          expect(results.map((task) => task.meta.id), [
            'day-agent-open-due',
            'day-agent-in-progress',
          ]);
        },
      );

      test('getInProgressTasks filters category and honors limit', () async {
        final base = DateTime(2024, 7, 4, 9);
        final older = buildTaskEntry(
          id: 'day-agent-progress-old',
          timestamp: base,
          status: TaskStatus.inProgress(
            id: 'status-progress-old',
            createdAt: base,
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-day-agent',
        );
        final newer = buildTaskEntry(
          id: 'day-agent-progress-new',
          timestamp: base.add(const Duration(minutes: 5)),
          status: TaskStatus.inProgress(
            id: 'status-progress-new',
            createdAt: base.add(const Duration(minutes: 5)),
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-day-agent',
        );
        final otherCategory = buildTaskEntry(
          id: 'day-agent-progress-other',
          timestamp: base.add(const Duration(minutes: 10)),
          status: TaskStatus.inProgress(
            id: 'status-progress-other',
            createdAt: base.add(const Duration(minutes: 10)),
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-other',
        );

        await db!.upsertJournalDbEntity(toDbEntity(older));
        await db!.upsertJournalDbEntity(toDbEntity(newer));
        await db!.upsertJournalDbEntity(toDbEntity(otherCategory));

        final results = await db!.getInProgressTasks(
          categoryIds: {'cat-day-agent'},
          limit: 1,
        );

        expect(results.map((task) => task.meta.id), [
          'day-agent-progress-new',
        ]);
      });

      test(
        'getMissedRecurringTasks is explicit no-op until recurrence exists',
        () async {
          final results = await db!.getMissedRecurringTasks(
            asOf: DateTime(2024, 7, 4),
          );

          expect(results, isEmpty);
        },
      );
    });

    group('getTasksDueOn -', () {
      test(
        'getTasksDueOn returns only tasks due on the specified date',
        () async {
          final targetDate = DateTime(2024, 8, 15);
          final base = DateTime(2024, 8, 10);

          // Task due on target date (should be included)
          final taskDueOnDate = buildTaskEntry(
            id: 'task-due-on-date',
            timestamp: base,
            status: TaskStatus.inProgress(
              id: 'status-1',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            due: DateTime(2024, 8, 15, 14, 30), // Due on target date
          );

          // Task due the day before (should NOT be included)
          final taskDueBefore = buildTaskEntry(
            id: 'task-due-before',
            timestamp: base,
            status: TaskStatus.inProgress(
              id: 'status-2',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            due: DateTime(2024, 8, 14, 12), // Due day before
          );

          // Task due the day after (should NOT be included)
          final taskDueAfter = buildTaskEntry(
            id: 'task-due-after',
            timestamp: base,
            status: TaskStatus.inProgress(
              id: 'status-3',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            due: DateTime(2024, 8, 16, 9), // Due day after
          );

          // Task with no due date (should NOT be included)
          final taskNoDue = buildTaskEntry(
            id: 'task-no-due',
            timestamp: base,
            status: TaskStatus.inProgress(
              id: 'status-4',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            // No due date
          );

          // Completed task due on target date (should NOT be included)
          final taskDoneOnDate = buildTaskEntry(
            id: 'task-done-on-date',
            timestamp: base,
            status: TaskStatus.done(
              id: 'status-5',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            due: DateTime(2024, 8, 15, 10),
          );

          await db!.upsertJournalDbEntity(toDbEntity(taskDueOnDate));
          await db!.upsertJournalDbEntity(toDbEntity(taskDueBefore));
          await db!.upsertJournalDbEntity(toDbEntity(taskDueAfter));
          await db!.upsertJournalDbEntity(toDbEntity(taskNoDue));
          await db!.upsertJournalDbEntity(toDbEntity(taskDoneOnDate));

          final results = await db!.getTasksDueOn(targetDate);

          // Only the non-completed task due on the target date should be returned
          expect(results.map((e) => e.meta.id).toList(), ['task-due-on-date']);
        },
      );

      test('getTasksDueOn returns multiple tasks due on same date', () async {
        final targetDate = DateTime(2024, 9, 20);
        final base = DateTime(2024, 9, 15);

        final task1 = buildTaskEntry(
          id: 'task-morning',
          timestamp: base,
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: base,
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          due: DateTime(2024, 9, 20, 9), // 9 AM
          title: 'Morning task',
        );

        final task2 = buildTaskEntry(
          id: 'task-evening',
          timestamp: base,
          status: TaskStatus.inProgress(
            id: 'status-2',
            createdAt: base,
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          due: DateTime(2024, 9, 20, 18), // 6 PM
          title: 'Evening task',
        );

        await db!.upsertJournalDbEntity(toDbEntity(task1));
        await db!.upsertJournalDbEntity(toDbEntity(task2));

        final results = await db!.getTasksDueOn(targetDate);

        // Both tasks due on target date should be returned, ordered by due time
        expect(results.length, 2);
        expect(
          results.map((e) => e.meta.id).toList(),
          ['task-morning', 'task-evening'],
        );
      });

      test(
        'getTasksDueOn returns empty list when no tasks due on date',
        () async {
          final targetDate = DateTime(2024, 10, 5);
          final base = DateTime(2024, 10, 1);

          final taskDueDifferentDay = buildTaskEntry(
            id: 'task-different-day',
            timestamp: base,
            status: TaskStatus.inProgress(
              id: 'status-1',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            due: DateTime(2024, 10, 10), // Due on different date
          );

          await db!.upsertJournalDbEntity(toDbEntity(taskDueDifferentDay));

          final results = await db!.getTasksDueOn(targetDate);

          expect(results, isEmpty);
        },
      );

      test(
        'open-task due-date queries use idx_journal_tasks_due_open',
        () async {
          // After v41 the hot path reads the denormalized `due_at` column
          // and pins the partial `idx_journal_tasks_due_open`. The composite
          // `idx_journal_tasks_due_active` was dropped in v41.
          //
          // The shape mirrors `_buildSelectTasksDue` in `database.dart`:
          // `private` is bound as IN (?, ?) — one parameter per status —
          // not as a config-flag subquery, so the planner sees the real
          // query shape the production builder emits.
          final endOfDay = DateTime(2024, 10, 5, 23, 59, 59, 999);

          final plan = await db!
              .customSelect(
                '''
          EXPLAIN QUERY PLAN
          SELECT * FROM journal INDEXED BY idx_journal_tasks_due_open
          WHERE type = 'Task'
          AND task = 1
          AND deleted = FALSE
          AND task_status NOT IN ('DONE', 'REJECTED')
          AND due_at IS NOT NULL
          AND due_at <= ?1
          AND private IN (?2, ?3)
          ORDER BY due_at ASC
          ''',
                variables: [
                  drift.Variable<DateTime>(endOfDay),
                  const drift.Variable<bool>(false),
                  const drift.Variable<bool>(true),
                ],
              )
              .get();

          final details = plan
              .map((row) => row.read<String>('detail'))
              .join(' ');
          expect(details, contains('idx_journal_tasks_due_open'));
        },
      );
    });
  });
}
