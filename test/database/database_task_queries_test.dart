// ignore_for_file: avoid_redundant_argument_values
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import '../test_data/test_data.dart';
import 'test_utils.dart';

void main() {
  setUpAll(registerJournalDbTestFallbacks);

  JournalDb? db;
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockLoggingService = MockDomainLogger();
  late Directory testDirectory;

  group('JournalDb task queries - ', () {
    setUp(() async {
      testDirectory = setupTestDirectory();
      reset(mockLoggingService);
      registerJournalDbTestServices(
        updateNotifications: mockUpdateNotifications,
        loggingService: mockLoggingService,
        documentsDirectory: testDirectory,
      );
      db = JournalDb(inMemoryDatabase: true);
      await initConfigFlags(db!, inMemoryDatabase: true);
    });

    tearDown(() async {
      unregisterJournalDbTestServices();
      await db?.close();
      if (testDirectory.existsSync()) {
        testDirectory.deleteSync(recursive: true);
      }
    });

    tearDownAll(() async {
      await getIt.reset();
    });

    group('Task queries -', () {
      test('getTasks filters by status and category', () async {
        final base = DateTime(2024, 7, 1, 8);
        final inProgressTask = buildTaskEntry(
          id: 'task-in-progress',
          timestamp: base,
          status: TaskStatus.inProgress(
            id: 'status-in-progress',
            createdAt: base,
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-1',
        );
        final doneTask = buildTaskEntry(
          id: 'task-done',
          timestamp: base.add(const Duration(minutes: 5)),
          status: TaskStatus.done(
            id: 'status-done',
            createdAt: base.add(const Duration(minutes: 5)),
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-1',
        );
        final otherCatTask = buildTaskEntry(
          id: 'task-other-cat',
          timestamp: base.add(const Duration(minutes: 10)),
          status: TaskStatus.inProgress(
            id: 'status-in-progress-2',
            createdAt: base.add(const Duration(minutes: 10)),
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-2',
        );

        await db!.upsertJournalDbEntity(toDbEntity(inProgressTask));
        await db!.upsertJournalDbEntity(toDbEntity(doneTask));
        await db!.upsertJournalDbEntity(toDbEntity(otherCatTask));

        final results = await db!.getTasks(
          starredStatuses: const [true, false],
          taskStatuses: const ['IN PROGRESS'],
          categoryIds: const ['cat-1'],
        );

        expect(results.map((e) => e.meta.id), ['task-in-progress']);
      });

      test('getTasks filters by explicit ids', () async {
        final base = DateTime(2024, 7, 2, 9);
        final openTask = buildTaskEntry(
          id: 'task-open',
          timestamp: base,
          status: TaskStatus.open(
            id: 'status-open',
            createdAt: base,
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-3',
        );
        final blockedTask = buildTaskEntry(
          id: 'task-blocked',
          timestamp: base.add(const Duration(minutes: 5)),
          status: TaskStatus.blocked(
            id: 'status-blocked',
            createdAt: base.add(const Duration(minutes: 5)),
            utcOffset: base.timeZoneOffset.inMinutes,
            reason: 'Blocked',
          ),
          categoryId: 'cat-3',
        );

        await db!.upsertJournalDbEntity(toDbEntity(openTask));
        await db!.upsertJournalDbEntity(toDbEntity(blockedTask));

        final results = await db!.getTasks(
          starredStatuses: const [true, false],
          taskStatuses: const ['BLOCKED'],
          categoryIds: const ['cat-3'],
          ids: const ['task-blocked'],
        );

        expect(results.map((e) => e.meta.id), ['task-blocked']);
      });

      test('getTasksSortedByDueDate orders by due date globally', () async {
        final base = DateTime(2024, 7, 10, 8);
        final taskNoDue = buildTaskEntry(
          id: 'task-no-due',
          timestamp: base,
          status: TaskStatus.open(
            id: 'status-no-due',
            createdAt: base,
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-due',
        );
        final taskLateDue = buildTaskEntry(
          id: 'task-late-due',
          timestamp: base.add(const Duration(minutes: 1)),
          status: TaskStatus.open(
            id: 'status-late-due',
            createdAt: base.add(const Duration(minutes: 1)),
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-due',
          due: DateTime(2024, 12, 31),
        );
        final taskEarlyDue = buildTaskEntry(
          id: 'task-early-due',
          timestamp: base.add(const Duration(minutes: 2)),
          status: TaskStatus.open(
            id: 'status-early-due',
            createdAt: base.add(const Duration(minutes: 2)),
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-due',
          due: DateTime(2024, 6, 1),
        );

        await db!.upsertJournalDbEntity(toDbEntity(taskNoDue));
        await db!.upsertJournalDbEntity(toDbEntity(taskLateDue));
        await db!.upsertJournalDbEntity(toDbEntity(taskEarlyDue));

        final results = await db!.getTasksSortedByDueDate(
          starredStatuses: const [true, false],
          taskStatuses: const ['OPEN'],
          categoryIds: const ['cat-due'],
        );

        // early due first, late due second, no due last
        expect(
          results.map((e) => e.meta.id),
          ['task-early-due', 'task-late-due', 'task-no-due'],
        );
      });

      test('getTasksSortedByDueDate returns empty for empty ids', () async {
        final base = DateTime(2024, 7, 11, 8);
        final task = buildTaskEntry(
          id: 'task-empty-ids',
          timestamp: base,
          status: TaskStatus.open(
            id: 'status-empty-ids',
            createdAt: base,
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-empty',
        );
        await db!.upsertJournalDbEntity(toDbEntity(task));

        final results = await db!.getTasksSortedByDueDate(
          starredStatuses: const [true, false],
          taskStatuses: const ['OPEN'],
          categoryIds: const ['cat-empty'],
          ids: const [],
        );

        expect(results, isEmpty);
      });

      test('getTasksSortedByDueDate filters by starred', () async {
        final base = DateTime(2024, 7, 12, 8);
        final starredTask = buildTaskEntry(
          id: 'task-starred',
          timestamp: base,
          starred: true,
          status: TaskStatus.open(
            id: 'status-starred',
            createdAt: base,
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-star',
          due: DateTime(2024, 8, 1),
        );
        final unstarredTask = buildTaskEntry(
          id: 'task-unstarred',
          timestamp: base.add(const Duration(minutes: 1)),
          status: TaskStatus.open(
            id: 'status-unstarred',
            createdAt: base.add(const Duration(minutes: 1)),
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-star',
          due: DateTime(2024, 7, 1),
        );

        await db!.upsertJournalDbEntity(toDbEntity(starredTask));
        await db!.upsertJournalDbEntity(toDbEntity(unstarredTask));

        final results = await db!.getTasksSortedByDueDate(
          starredStatuses: const [true],
          taskStatuses: const ['OPEN'],
          categoryIds: const ['cat-star'],
        );

        expect(results.map((e) => e.meta.id), ['task-starred']);
      });

      test('getTasksSortedByDueDate filters by FTS ids', () async {
        final base = DateTime(2024, 7, 13, 8);
        final taskA = buildTaskEntry(
          id: 'task-fts-a',
          timestamp: base,
          status: TaskStatus.open(
            id: 'status-fts-a',
            createdAt: base,
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-fts',
          due: DateTime(2024, 8, 1),
        );
        final taskB = buildTaskEntry(
          id: 'task-fts-b',
          timestamp: base.add(const Duration(minutes: 1)),
          status: TaskStatus.open(
            id: 'status-fts-b',
            createdAt: base.add(const Duration(minutes: 1)),
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-fts',
          due: DateTime(2024, 7, 1),
        );

        await db!.upsertJournalDbEntity(toDbEntity(taskA));
        await db!.upsertJournalDbEntity(toDbEntity(taskB));

        final results = await db!.getTasksSortedByDueDate(
          starredStatuses: const [true, false],
          taskStatuses: const ['OPEN'],
          categoryIds: const ['cat-fts'],
          ids: const ['task-fts-b'],
        );

        expect(results.map((e) => e.meta.id), ['task-fts-b']);
      });

      test('getTasksSortedByDueDate filters by priority', () async {
        final base = DateTime(2024, 7, 14, 8);
        final taskP0 = buildTaskEntry(
          id: 'task-p0',
          timestamp: base,
          status: TaskStatus.open(
            id: 'status-p0',
            createdAt: base,
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-prio',
          due: DateTime(2024, 9, 1),
        );
        final taskP2 = buildTaskEntry(
          id: 'task-p2',
          timestamp: base.add(const Duration(minutes: 1)),
          status: TaskStatus.open(
            id: 'status-p2',
            createdAt: base.add(const Duration(minutes: 1)),
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-prio',
          due: DateTime(2024, 8, 1),
        );

        // Set priorities via raw update (buildTaskEntry doesn't set
        // task_priority column directly — the column is set by
        // upsertJournalDbEntity from the serialized data, but the priority
        // field maps to task_priority_rank not task_priority. Use customUpdate
        // to set the column for this test.)
        await db!.upsertJournalDbEntity(toDbEntity(taskP0));
        await db!.upsertJournalDbEntity(toDbEntity(taskP2));
        await db!.customUpdate(
          "UPDATE journal SET task_priority = 'P0' WHERE id = 'task-p0'",
          updates: {db!.journal},
        );
        await db!.customUpdate(
          "UPDATE journal SET task_priority = 'P2' WHERE id = 'task-p2'",
          updates: {db!.journal},
        );

        final results = await db!.getTasksSortedByDueDate(
          starredStatuses: const [true, false],
          taskStatuses: const ['OPEN'],
          categoryIds: const ['cat-prio'],
          priorities: const ['P0'],
        );

        expect(results.map((e) => e.meta.id), ['task-p0']);
      });

      test('getTasksSortedByDueDate filters by labels', () async {
        final base = DateTime(2024, 7, 15, 8);
        final labeledTask = buildTaskEntry(
          id: 'task-labeled',
          timestamp: base,
          status: TaskStatus.open(
            id: 'status-labeled',
            createdAt: base,
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-label',
          due: DateTime(2024, 10, 1),
        );
        final unlabeledTask = buildTaskEntry(
          id: 'task-unlabeled',
          timestamp: base.add(const Duration(minutes: 1)),
          status: TaskStatus.open(
            id: 'status-unlabeled',
            createdAt: base.add(const Duration(minutes: 1)),
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
          categoryId: 'cat-label',
          due: DateTime(2024, 9, 1),
        );

        await db!.upsertJournalDbEntity(toDbEntity(labeledTask));
        await db!.upsertJournalDbEntity(toDbEntity(unlabeledTask));

        // Temporarily disable FK checks so we can insert into labeled
        await db!.customStatement('PRAGMA foreign_keys = OFF');
        await db!.customStatement(
          'INSERT INTO labeled (id, journal_id, label_id) '
          "VALUES ('lbl-1', 'task-labeled', 'label-A')",
        );
        await db!.customStatement('PRAGMA foreign_keys = ON');

        // Filter by specific label
        final labelResults = await db!.getTasksSortedByDueDate(
          starredStatuses: const [true, false],
          taskStatuses: const ['OPEN'],
          categoryIds: const ['cat-label'],
          labelIds: const ['label-A'],
        );
        expect(labelResults.map((e) => e.meta.id), ['task-labeled']);

        // Filter by unlabeled (empty string sentinel)
        final unlabeledResults = await db!.getTasksSortedByDueDate(
          starredStatuses: const [true, false],
          taskStatuses: const ['OPEN'],
          categoryIds: const ['cat-label'],
          labelIds: const [''],
        );
        expect(unlabeledResults.map((e) => e.meta.id), ['task-unlabeled']);
      });

      test(
        'getTasksSortedByDueDate excludes private when restricted',
        () async {
          final base = DateTime(2024, 7, 16, 8);
          final privateTask = buildTaskEntry(
            id: 'task-priv-due',
            timestamp: base,
            privateFlag: true,
            status: TaskStatus.open(
              id: 'status-priv-due',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            categoryId: 'cat-priv-due',
            due: DateTime(2024, 7, 1),
          );
          final publicTask = buildTaskEntry(
            id: 'task-pub-due',
            timestamp: base.add(const Duration(minutes: 1)),
            status: TaskStatus.open(
              id: 'status-pub-due',
              createdAt: base.add(const Duration(minutes: 1)),
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            categoryId: 'cat-priv-due',
            due: DateTime(2024, 8, 1),
          );

          await db!.upsertJournalDbEntity(toDbEntity(privateTask));
          await db!.upsertJournalDbEntity(toDbEntity(publicTask));

          // Ensure private flag is off (only public tasks visible).
          // getConfigFlag returns false by default when the flag doesn't exist,
          // so _visiblePrivateStatuses returns [false].
          // However initConfigFlags may set 'private' to true by default.
          // Toggle explicitly to guarantee [false].
          final showPrivate = await db!.getConfigFlag('private');
          if (showPrivate) {
            await db!.toggleConfigFlag('private');
          }

          final results = await db!.getTasksSortedByDueDate(
            starredStatuses: const [true, false],
            taskStatuses: const ['OPEN'],
            categoryIds: const ['cat-priv-due'],
          );

          // Only the public task should be returned
          expect(results.map((e) => e.meta.id), ['task-pub-due']);
        },
      );

      test('getTasksSortedByDueDate paginates correctly', () async {
        final base = DateTime(2024, 7, 15, 8);
        // Create 3 tasks with different due dates
        for (var i = 0; i < 3; i++) {
          final task = buildTaskEntry(
            id: 'task-page-$i',
            timestamp: base.add(Duration(minutes: i)),
            status: TaskStatus.open(
              id: 'status-page-$i',
              createdAt: base.add(Duration(minutes: i)),
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            categoryId: 'cat-page',
            due: DateTime(2024, 6 + i, 1),
          );
          await db!.upsertJournalDbEntity(toDbEntity(task));
        }

        // Fetch first page (limit 2)
        final page1 = await db!.getTasksSortedByDueDate(
          starredStatuses: const [true, false],
          taskStatuses: const ['OPEN'],
          categoryIds: const ['cat-page'],
          limit: 2,
        );
        expect(page1.map((e) => e.meta.id), ['task-page-0', 'task-page-1']);

        // Fetch second page
        final page2 = await db!.getTasksSortedByDueDate(
          starredStatuses: const [true, false],
          taskStatuses: const ['OPEN'],
          categoryIds: const ['cat-page'],
          limit: 2,
          offset: 2,
        );
        expect(page2.map((e) => e.meta.id), ['task-page-2']);
      });

      test('getWipCount counts tasks with IN PROGRESS status', () async {
        final base = DateTime(2024, 7, 3, 10);
        final inProgressA = buildTaskEntry(
          id: 'wip-A',
          timestamp: base,
          status: TaskStatus.inProgress(
            id: 'wip-status-a',
            createdAt: base,
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
        );
        final inProgressB = buildTaskEntry(
          id: 'wip-B',
          timestamp: base.add(const Duration(minutes: 5)),
          status: TaskStatus.inProgress(
            id: 'wip-status-b',
            createdAt: base.add(const Duration(minutes: 5)),
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
        );
        final doneTask = buildTaskEntry(
          id: 'wip-done',
          timestamp: base.add(const Duration(minutes: 10)),
          status: TaskStatus.done(
            id: 'wip-status-done',
            createdAt: base.add(const Duration(minutes: 10)),
            utcOffset: base.timeZoneOffset.inMinutes,
          ),
        );

        await db!.upsertJournalDbEntity(toDbEntity(inProgressA));
        await db!.upsertJournalDbEntity(toDbEntity(inProgressB));
        await db!.upsertJournalDbEntity(toDbEntity(doneTask));

        expect(await db!.getWipCount(), 2);
      });

      test('getTasks filters by priorities', () async {
        final base = DateTime(2024, 7, 4, 11);
        final p0 = JournalEntity.task(
          meta: Metadata(
            id: 'prio-0',
            createdAt: base,
            updatedAt: base,
            dateFrom: base,
            dateTo: base,
          ),
          data: testTask.data.copyWith(
            status: TaskStatus.open(
              id: 's0',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            dateFrom: base,
            dateTo: base,
            title: 'P0',
            priority: TaskPriority.p0Urgent,
          ),
          entryText: const EntryText(plainText: 'prio 0'),
        );
        final p2 = JournalEntity.task(
          meta: Metadata(
            id: 'prio-2',
            createdAt: base,
            updatedAt: base,
            dateFrom: base,
            dateTo: base,
          ),
          data: testTask.data.copyWith(
            status: TaskStatus.open(
              id: 's2',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            dateFrom: base,
            dateTo: base,
            title: 'P2',
            priority: TaskPriority.p2Medium,
          ),
          entryText: const EntryText(plainText: 'prio 2'),
        );

        await db!.upsertJournalDbEntity(toDbEntity(p0));
        await db!.upsertJournalDbEntity(toDbEntity(p2));

        final results = await db!.getTasks(
          starredStatuses: const [true, false],
          taskStatuses: const ['OPEN'],
          categoryIds: const [''],
          priorities: const ['P0'],
        );

        expect(results.map((e) => e.meta.id), ['prio-0']);
      });

      test(
        'getTasks returns empty list when no task statuses are selected',
        () async {
          final base = DateTime(2024, 7, 4, 11);
          final task = buildTaskEntry(
            id: 'task-no-status-filter',
            timestamp: base,
            status: TaskStatus.open(
              id: 'no-status-filter-open',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            categoryId: 'cat-1',
          );

          await db!.upsertJournalDbEntity(toDbEntity(task));

          final results = await db!.getTasks(
            starredStatuses: const [true, false],
            taskStatuses: const [],
            categoryIds: const ['cat-1'],
          );

          expect(results, isEmpty);
        },
      );

      group('getFilteredTasksCount / getFilteredTaskIds', () {
        Future<void> seedTasks(DateTime base) async {
          final inProgressP0 = JournalEntity.task(
            meta: Metadata(
              id: 'count-in-progress-p0',
              createdAt: base,
              updatedAt: base,
              dateFrom: base,
              dateTo: base,
              categoryId: 'cat-1',
            ),
            data: testTask.data.copyWith(
              status: TaskStatus.inProgress(
                id: 'count-s1',
                createdAt: base,
                utcOffset: base.timeZoneOffset.inMinutes,
              ),
              dateFrom: base,
              dateTo: base,
              title: 'in-progress p0',
              priority: TaskPriority.p0Urgent,
            ),
            entryText: const EntryText(plainText: 'a'),
          );
          final inProgressP2 = JournalEntity.task(
            meta: Metadata(
              id: 'count-in-progress-p2',
              createdAt: base.add(const Duration(minutes: 1)),
              updatedAt: base.add(const Duration(minutes: 1)),
              dateFrom: base.add(const Duration(minutes: 1)),
              dateTo: base.add(const Duration(minutes: 1)),
              categoryId: 'cat-1',
            ),
            data: testTask.data.copyWith(
              status: TaskStatus.inProgress(
                id: 'count-s2',
                createdAt: base.add(const Duration(minutes: 1)),
                utcOffset: base.timeZoneOffset.inMinutes,
              ),
              dateFrom: base.add(const Duration(minutes: 1)),
              dateTo: base.add(const Duration(minutes: 1)),
              title: 'in-progress p2',
              priority: TaskPriority.p2Medium,
            ),
            entryText: const EntryText(plainText: 'b'),
          );
          final doneP0 = JournalEntity.task(
            meta: Metadata(
              id: 'count-done-p0',
              createdAt: base.add(const Duration(minutes: 2)),
              updatedAt: base.add(const Duration(minutes: 2)),
              dateFrom: base.add(const Duration(minutes: 2)),
              dateTo: base.add(const Duration(minutes: 2)),
              categoryId: 'cat-1',
            ),
            data: testTask.data.copyWith(
              status: TaskStatus.done(
                id: 'count-s3',
                createdAt: base.add(const Duration(minutes: 2)),
                utcOffset: base.timeZoneOffset.inMinutes,
              ),
              dateFrom: base.add(const Duration(minutes: 2)),
              dateTo: base.add(const Duration(minutes: 2)),
              title: 'done p0',
              priority: TaskPriority.p0Urgent,
            ),
            entryText: const EntryText(plainText: 'c'),
          );
          final inProgressOtherCat = JournalEntity.task(
            meta: Metadata(
              id: 'count-other-cat',
              createdAt: base.add(const Duration(minutes: 3)),
              updatedAt: base.add(const Duration(minutes: 3)),
              dateFrom: base.add(const Duration(minutes: 3)),
              dateTo: base.add(const Duration(minutes: 3)),
              categoryId: 'cat-2',
            ),
            data: testTask.data.copyWith(
              status: TaskStatus.inProgress(
                id: 'count-s4',
                createdAt: base.add(const Duration(minutes: 3)),
                utcOffset: base.timeZoneOffset.inMinutes,
              ),
              dateFrom: base.add(const Duration(minutes: 3)),
              dateTo: base.add(const Duration(minutes: 3)),
              title: 'cat-2 task',
              priority: TaskPriority.p1High,
            ),
            entryText: const EntryText(plainText: 'd'),
          );

          await db!.upsertJournalDbEntity(toDbEntity(inProgressP0));
          await db!.upsertJournalDbEntity(toDbEntity(inProgressP2));
          await db!.upsertJournalDbEntity(toDbEntity(doneP0));
          await db!.upsertJournalDbEntity(toDbEntity(inProgressOtherCat));
        }

        test('count by status + category', () async {
          await seedTasks(DateTime(2024, 8));

          expect(
            await db!.getFilteredTasksCount(
              taskStatuses: const ['IN PROGRESS'],
              categoryIds: const ['cat-1'],
            ),
            2,
          );
          expect(
            await db!.getFilteredTasksCount(
              taskStatuses: const ['DONE'],
              categoryIds: const ['cat-1'],
            ),
            1,
          );
        });

        test('count narrows by priority when supplied', () async {
          await seedTasks(DateTime(2024, 8));

          expect(
            await db!.getFilteredTasksCount(
              taskStatuses: const ['IN PROGRESS', 'DONE'],
              categoryIds: const ['cat-1'],
              priorities: const ['P0'],
            ),
            2,
          );
        });

        test('count of zero on empty status list (fail-fast)', () async {
          await seedTasks(DateTime(2024, 8));

          expect(
            await db!.getFilteredTasksCount(
              taskStatuses: const [],
              categoryIds: const ['cat-1'],
            ),
            0,
          );
          expect(
            await db!.getFilteredTasksCount(
              taskStatuses: const ['IN PROGRESS'],
              categoryIds: const [],
            ),
            0,
          );
        });

        test('selectFilteredTaskIds returns matching ids', () async {
          await seedTasks(DateTime(2024, 8));

          final ids = await db!.getFilteredTaskIds(
            taskStatuses: const ['IN PROGRESS'],
            categoryIds: const ['cat-1', 'cat-2'],
          );
          expect(
            ids.toSet(),
            {'count-in-progress-p0', 'count-in-progress-p2', 'count-other-cat'},
          );
        });

        test(
          'selectFilteredTaskIds returns empty list on empty filters',
          () async {
            await seedTasks(DateTime(2024, 8));
            expect(
              await db!.getFilteredTaskIds(
                taskStatuses: const [],
                categoryIds: const ['cat-1'],
              ),
              isEmpty,
            );
          },
        );
      });

      test(
        'getTasks returns consistent results and reflects writes',
        () async {
          final base = DateTime(2024, 7, 4, 11);
          final firstTask = buildTaskEntry(
            id: 'cached-task-1',
            timestamp: base,
            status: TaskStatus.open(
              id: 'cached-open-1',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            categoryId: 'cat-cache',
          );

          await db!.upsertJournalDbEntity(toDbEntity(firstTask));

          final firstResults = await db!.getTasks(
            starredStatuses: const [true, false],
            taskStatuses: const ['OPEN'],
            categoryIds: const ['cat-cache'],
            sortByDate: true,
          );
          final secondResults = await db!.getTasks(
            starredStatuses: const [true, false],
            taskStatuses: const ['OPEN'],
            categoryIds: const ['cat-cache'],
            sortByDate: true,
          );

          expect(firstResults.map((e) => e.meta.id), ['cached-task-1']);
          expect(secondResults.map((e) => e.meta.id), ['cached-task-1']);

          final secondTask = buildTaskEntry(
            id: 'cached-task-2',
            timestamp: base.add(const Duration(minutes: 1)),
            status: TaskStatus.open(
              id: 'cached-open-2',
              createdAt: base.add(const Duration(minutes: 1)),
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            categoryId: 'cat-cache',
          );

          await db!.upsertJournalDbEntity(toDbEntity(secondTask));

          final refreshedResults = await db!.getTasks(
            starredStatuses: const [true, false],
            taskStatuses: const ['OPEN'],
            categoryIds: const ['cat-cache'],
            sortByDate: true,
          );

          expect(
            refreshedResults.map((e) => e.meta.id),
            ['cached-task-2', 'cached-task-1'],
          );
        },
      );

      test('getTasks orders by priority rank then date_from desc', () async {
        final base = DateTime(2024, 7, 5, 12);
        final p3older = JournalEntity.task(
          meta: Metadata(
            id: 'older-low',
            createdAt: base,
            updatedAt: base,
            dateFrom: base,
            dateTo: base,
          ),
          data: testTask.data.copyWith(
            status: TaskStatus.open(
              id: 's3',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            dateFrom: base,
            dateTo: base,
            title: 'P3 older',
            priority: TaskPriority.p3Low,
          ),
          entryText: const EntryText(plainText: 'older low'),
        );
        final p1newer = JournalEntity.task(
          meta: Metadata(
            id: 'newer-high',
            createdAt: base.add(const Duration(minutes: 1)),
            updatedAt: base.add(const Duration(minutes: 1)),
            dateFrom: base.add(const Duration(minutes: 1)),
            dateTo: base.add(const Duration(minutes: 1)),
          ),
          data: testTask.data.copyWith(
            status: TaskStatus.open(
              id: 's1',
              createdAt: base.add(const Duration(minutes: 1)),
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            dateFrom: base.add(const Duration(minutes: 1)),
            dateTo: base.add(const Duration(minutes: 1)),
            title: 'P1 newer',
            priority: TaskPriority.p1High,
          ),
          entryText: const EntryText(plainText: 'newer high'),
        );
        final p0newest = JournalEntity.task(
          meta: Metadata(
            id: 'newest-urgent',
            createdAt: base.add(const Duration(minutes: 2)),
            updatedAt: base.add(const Duration(minutes: 2)),
            dateFrom: base.add(const Duration(minutes: 2)),
            dateTo: base.add(const Duration(minutes: 2)),
          ),
          data: testTask.data.copyWith(
            status: TaskStatus.open(
              id: 's0',
              createdAt: base.add(const Duration(minutes: 2)),
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            dateFrom: base.add(const Duration(minutes: 2)),
            dateTo: base.add(const Duration(minutes: 2)),
            title: 'P0 newest',
            priority: TaskPriority.p0Urgent,
          ),
          entryText: const EntryText(plainText: 'newest urgent'),
        );

        await db!.upsertJournalDbEntity(toDbEntity(p3older));
        await db!.upsertJournalDbEntity(toDbEntity(p1newer));
        await db!.upsertJournalDbEntity(toDbEntity(p0newest));

        final results = await db!.getTasks(
          starredStatuses: const [true, false],
          taskStatuses: const ['OPEN'],
          categoryIds: const [''],
        );

        // Order: P0 -> P1 -> P3; within same priority, date_from DESC
        expect(
          results.map((e) => e.meta.id).toList(),
          ['newest-urgent', 'newer-high', 'older-low'],
        );
      });

      test('getTasks with sortByDate orders by date_from desc only', () async {
        final base = DateTime(2024, 7, 5, 12);
        // Create tasks with different priorities and dates
        // When sorting by date, priority should be ignored
        final p3oldest = JournalEntity.task(
          meta: Metadata(
            id: 'oldest-low',
            createdAt: base,
            updatedAt: base,
            dateFrom: base,
            dateTo: base,
          ),
          data: testTask.data.copyWith(
            status: TaskStatus.open(
              id: 's3',
              createdAt: base,
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            dateFrom: base,
            dateTo: base,
            title: 'P3 oldest',
            priority: TaskPriority.p3Low,
          ),
          entryText: const EntryText(plainText: 'oldest low'),
        );
        final p0middle = JournalEntity.task(
          meta: Metadata(
            id: 'middle-urgent',
            createdAt: base.add(const Duration(minutes: 1)),
            updatedAt: base.add(const Duration(minutes: 1)),
            dateFrom: base.add(const Duration(minutes: 1)),
            dateTo: base.add(const Duration(minutes: 1)),
          ),
          data: testTask.data.copyWith(
            status: TaskStatus.open(
              id: 's0',
              createdAt: base.add(const Duration(minutes: 1)),
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            dateFrom: base.add(const Duration(minutes: 1)),
            dateTo: base.add(const Duration(minutes: 1)),
            title: 'P0 middle',
            priority: TaskPriority.p0Urgent,
          ),
          entryText: const EntryText(plainText: 'middle urgent'),
        );
        final p1newest = JournalEntity.task(
          meta: Metadata(
            id: 'newest-high',
            createdAt: base.add(const Duration(minutes: 2)),
            updatedAt: base.add(const Duration(minutes: 2)),
            dateFrom: base.add(const Duration(minutes: 2)),
            dateTo: base.add(const Duration(minutes: 2)),
          ),
          data: testTask.data.copyWith(
            status: TaskStatus.open(
              id: 's1',
              createdAt: base.add(const Duration(minutes: 2)),
              utcOffset: base.timeZoneOffset.inMinutes,
            ),
            dateFrom: base.add(const Duration(minutes: 2)),
            dateTo: base.add(const Duration(minutes: 2)),
            title: 'P1 newest',
            priority: TaskPriority.p1High,
          ),
          entryText: const EntryText(plainText: 'newest high'),
        );

        await db!.upsertJournalDbEntity(toDbEntity(p3oldest));
        await db!.upsertJournalDbEntity(toDbEntity(p0middle));
        await db!.upsertJournalDbEntity(toDbEntity(p1newest));

        final results = await db!.getTasks(
          starredStatuses: const [true, false],
          taskStatuses: const ['OPEN'],
          categoryIds: const [''],
          sortByDate: true,
        );

        // Order: newest -> middle -> oldest (date_from DESC, ignoring priority)
        // P1 newest (minute 2) > P0 middle (minute 1) > P3 oldest (minute 0)
        expect(
          results.map((e) => e.meta.id).toList(),
          ['newest-high', 'middle-urgent', 'oldest-low'],
        );
      });

      test(
        'getTasks with sortByDate and ids uses filteredTasksByDate2',
        () async {
          final base = DateTime(2024, 7, 5, 12);
          // Create tasks with different priorities and dates
          final p3oldest = JournalEntity.task(
            meta: Metadata(
              id: 'oldest-low',
              createdAt: base,
              updatedAt: base,
              dateFrom: base,
              dateTo: base,
            ),
            data: testTask.data.copyWith(
              status: TaskStatus.open(
                id: 's3',
                createdAt: base,
                utcOffset: base.timeZoneOffset.inMinutes,
              ),
              dateFrom: base,
              dateTo: base,
              title: 'P3 oldest',
              priority: TaskPriority.p3Low,
            ),
            entryText: const EntryText(plainText: 'oldest low'),
          );
          final p0middle = JournalEntity.task(
            meta: Metadata(
              id: 'middle-urgent',
              createdAt: base.add(const Duration(minutes: 1)),
              updatedAt: base.add(const Duration(minutes: 1)),
              dateFrom: base.add(const Duration(minutes: 1)),
              dateTo: base.add(const Duration(minutes: 1)),
            ),
            data: testTask.data.copyWith(
              status: TaskStatus.open(
                id: 's0',
                createdAt: base.add(const Duration(minutes: 1)),
                utcOffset: base.timeZoneOffset.inMinutes,
              ),
              dateFrom: base.add(const Duration(minutes: 1)),
              dateTo: base.add(const Duration(minutes: 1)),
              title: 'P0 middle',
              priority: TaskPriority.p0Urgent,
            ),
            entryText: const EntryText(plainText: 'middle urgent'),
          );
          final p1newest = JournalEntity.task(
            meta: Metadata(
              id: 'newest-high',
              createdAt: base.add(const Duration(minutes: 2)),
              updatedAt: base.add(const Duration(minutes: 2)),
              dateFrom: base.add(const Duration(minutes: 2)),
              dateTo: base.add(const Duration(minutes: 2)),
            ),
            data: testTask.data.copyWith(
              status: TaskStatus.open(
                id: 's1',
                createdAt: base.add(const Duration(minutes: 2)),
                utcOffset: base.timeZoneOffset.inMinutes,
              ),
              dateFrom: base.add(const Duration(minutes: 2)),
              dateTo: base.add(const Duration(minutes: 2)),
              title: 'P1 newest',
              priority: TaskPriority.p1High,
            ),
            entryText: const EntryText(plainText: 'newest high'),
          );

          await db!.upsertJournalDbEntity(toDbEntity(p3oldest));
          await db!.upsertJournalDbEntity(toDbEntity(p0middle));
          await db!.upsertJournalDbEntity(toDbEntity(p1newest));

          // Query with ids filter + sortByDate to exercise filteredTasksByDate2
          final results = await db!.getTasks(
            starredStatuses: const [true, false],
            taskStatuses: const ['OPEN'],
            categoryIds: const [''],
            ids: ['oldest-low', 'newest-high', 'middle-urgent'],
            sortByDate: true,
          );

          // Order: newest -> middle -> oldest (date_from DESC, ignoring priority)
          // With ids filter, should use filteredTasksByDate2 query
          expect(
            results.map((e) => e.meta.id).toList(),
            ['newest-high', 'middle-urgent', 'oldest-low'],
          );
        },
      );

      test(
        'date-sorted task queries use the date-oriented task index',
        () async {
          final plan = await db!.customSelect(
            '''
          EXPLAIN QUERY PLAN
          SELECT * FROM journal
          WHERE type = 'Task'
          AND deleted = FALSE
          AND task = 1
          AND task_status = 'OPEN'
          AND category = ''
          ORDER BY date_from DESC, id ASC
          LIMIT 50 OFFSET 0
          ''',
          ).get();

          final details = plan
              .map((row) => row.read<String>('detail'))
              .join(' ');
          expect(details, contains('idx_journal_tasks_date'));
        },
      );

      test(
        'priority-filtered date-sorted task queries use the priority-aware date index',
        () async {
          final plan = await db!.customSelect(
            '''
          EXPLAIN QUERY PLAN
          SELECT * FROM journal
          WHERE type = 'Task'
          AND deleted = FALSE
          AND task = 1
          AND task_status = 'OPEN'
          AND category = ''
          AND task_priority = 'P1'
          ORDER BY date_from DESC, id ASC
          LIMIT 50 OFFSET 0
          ''',
          ).get();

          final details = plan
              .map((row) => row.read<String>('detail'))
              .join(' ');
          expect(details, contains('idx_journal_tasks_date_priority'));
        },
      );
    });

    group('updateTaskPriorityColumn -', () {
      test('updates priority and rank for a task', () async {
        final base = DateTime(2024, 11, 1, 9);
        final task = buildTaskEntry(
          id: 'prio-col-task',
          timestamp: base,
          status: TaskStatus.open(
            id: 'prio-col-status',
            createdAt: base,
            utcOffset: 0,
          ),
        );
        await db!.upsertJournalDbEntity(toDbEntity(task));

        await db!.updateTaskPriorityColumn(
          id: 'prio-col-task',
          priority: 'P0',
          rank: 42,
        );

        final row = await (db!.select(
          db!.journal,
        )..where((t) => t.id.equals('prio-col-task'))).getSingle();
        expect(row.taskPriority, 'P0');
        expect(row.taskPriorityRank, 42);
      });

      test('logs and swallows when the underlying statement fails', () async {
        // Dropping the journal table makes the raw UPDATE throw; the method
        // must log the failure instead of propagating it to the caller.
        await db!.customStatement('DROP TABLE journal');
        DevLogger.clear();

        await db!.updateTaskPriorityColumn(
          id: 'prio-col-task',
          priority: 'P0',
          rank: 1,
        );

        expect(
          DevLogger.capturedLogs.any(
            (message) => message.contains('updateTaskPriorityColumn error'),
          ),
          isTrue,
        );
      });
    });

    group('getTaskCountsByCategory -', () {
      test('returns task count per category', () async {
        final base = DateTime(2024, 11, 6, 9);
        final t1 = buildTaskEntry(
          id: 'tcc-task-1',
          timestamp: base,
          status: TaskStatus.open(
            id: 'tcc-status-1',
            createdAt: base,
            utcOffset: 0,
          ),
          categoryId: 'tcc-cat-a',
        );
        final t2 = buildTaskEntry(
          id: 'tcc-task-2',
          timestamp: base.add(const Duration(minutes: 1)),
          status: TaskStatus.open(
            id: 'tcc-status-2',
            createdAt: base.add(const Duration(minutes: 1)),
            utcOffset: 0,
          ),
          categoryId: 'tcc-cat-a',
        );
        final t3 = buildTaskEntry(
          id: 'tcc-task-3',
          timestamp: base.add(const Duration(minutes: 2)),
          status: TaskStatus.open(
            id: 'tcc-status-3',
            createdAt: base.add(const Duration(minutes: 2)),
            utcOffset: 0,
          ),
          categoryId: 'tcc-cat-b',
        );
        await db!.upsertJournalDbEntity(toDbEntity(t1));
        await db!.upsertJournalDbEntity(toDbEntity(t2));
        await db!.upsertJournalDbEntity(toDbEntity(t3));

        final counts = await db!.getTaskCountsByCategory();
        expect(counts['tcc-cat-a'], greaterThanOrEqualTo(2));
        expect(counts['tcc-cat-b'], greaterThanOrEqualTo(1));
      });
    });

    group('getTasks with label/sortByDate/priority branch coverage -', () {
      test(
        'getTasks with label filter (all-private/all-starred, label included)',
        () async {
          final base = DateTime(2024, 11, 15, 9);
          await db!.upsertLabelDefinition(
            LabelDefinition(
              id: 'lbl-task-cov',
              createdAt: base,
              updatedAt: base,
              name: 'TaskLabel',
              color: '#001122',
              vectorClock: null,
            ),
          );
          final labeledTask = buildTaskEntry(
            id: 'labeled-task-cov',
            timestamp: base,
            status: TaskStatus.open(
              id: 'lts-cov',
              createdAt: base,
              utcOffset: 0,
            ),
            categoryId: 'lbl-cat-cov',
          );
          final unlabeledTask = buildTaskEntry(
            id: 'unlabeled-task-cov',
            timestamp: base.add(const Duration(minutes: 1)),
            status: TaskStatus.open(
              id: 'lts-cov-2',
              createdAt: base.add(const Duration(minutes: 1)),
              utcOffset: 0,
            ),
            categoryId: 'lbl-cat-cov',
          );
          await db!.upsertJournalDbEntity(toDbEntity(labeledTask));
          await db!.upsertJournalDbEntity(toDbEntity(unlabeledTask));
          await db!.insertLabel('labeled-task-cov', 'lbl-task-cov');

          // Exercise the label-filter branch (all-private/all-starred).
          final results = await db!.getTasks(
            starredStatuses: const [true, false],
            taskStatuses: const ['OPEN'],
            categoryIds: const ['lbl-cat-cov'],
            labelIds: const ['lbl-task-cov'],
          );
          expect(
            results.map((e) => e.meta.id),
            contains('labeled-task-cov'),
          );
          expect(
            results.map((e) => e.meta.id),
            isNot(contains('unlabeled-task-cov')),
          );
        },
      );

      test(
        'getTasks with sortByDate=true exercises date-sorted branch',
        () async {
          final base = DateTime(2024, 11, 16, 9);
          final t1 = buildTaskEntry(
            id: 'sort-date-task-1',
            timestamp: base,
            status: TaskStatus.open(
              id: 'sdt-1',
              createdAt: base,
              utcOffset: 0,
            ),
            categoryId: 'sdt-cat',
            due: DateTime(2024, 11, 18),
          );
          final t2 = buildTaskEntry(
            id: 'sort-date-task-2',
            timestamp: base.add(const Duration(minutes: 1)),
            status: TaskStatus.open(
              id: 'sdt-2',
              createdAt: base.add(const Duration(minutes: 1)),
              utcOffset: 0,
            ),
            categoryId: 'sdt-cat',
            due: DateTime(2024, 11, 17),
          );
          await db!.upsertJournalDbEntity(toDbEntity(t1));
          await db!.upsertJournalDbEntity(toDbEntity(t2));

          final results = await db!.getTasks(
            starredStatuses: const [true, false],
            taskStatuses: const ['OPEN'],
            categoryIds: const ['sdt-cat'],
            sortByDate: true,
          );
          expect(results.length, greaterThanOrEqualTo(2));
          // Due-date sorted: t2 (Nov 17) before t1 (Nov 18).
          final ids = results.map((e) => e.meta.id).toList();
          expect(
            ids.indexOf('sort-date-task-2'),
            lessThan(ids.indexOf('sort-date-task-1')),
          );
        },
      );

      test(
        'getTasks with sortByDate=true and priority filter (all-private path)',
        () async {
          final base = DateTime(2024, 11, 17, 9);
          final t1 = buildTaskEntry(
            id: 'sortdate-prio-task',
            timestamp: base,
            status: TaskStatus.open(
              id: 'sdp-1',
              createdAt: base,
              utcOffset: 0,
            ),
            categoryId: 'sdp-cat',
          );
          await db!.upsertJournalDbEntity(toDbEntity(t1));
          await db!.updateTaskPriorityColumn(
            id: 'sortdate-prio-task',
            priority: 'P0',
            rank: 1,
          );

          final results = await db!.getTasks(
            starredStatuses: const [true, false],
            taskStatuses: const ['OPEN'],
            categoryIds: const ['sdp-cat'],
            priorities: const ['P0'],
            sortByDate: true,
          );
          expect(results.map((e) => e.meta.id), contains('sortdate-prio-task'));
        },
      );

      test(
        'getTasks with label filter and sortByDate=true (all-private path)',
        () async {
          final base = DateTime(2024, 11, 18, 9);
          await db!.upsertLabelDefinition(
            LabelDefinition(
              id: 'lbl-sort-date',
              createdAt: base,
              updatedAt: base,
              name: 'SortDateLabel',
              color: '#334455',
              vectorClock: null,
            ),
          );
          final t = buildTaskEntry(
            id: 'lbl-sort-date-task',
            timestamp: base,
            status: TaskStatus.open(
              id: 'lsd-status',
              createdAt: base,
              utcOffset: 0,
            ),
            categoryId: 'lsd-cat',
            due: DateTime(2024, 11, 20),
          );
          await db!.upsertJournalDbEntity(toDbEntity(t));
          await db!.insertLabel('lbl-sort-date-task', 'lbl-sort-date');

          final results = await db!.getTasks(
            starredStatuses: const [true, false],
            taskStatuses: const ['OPEN'],
            categoryIds: const ['lsd-cat'],
            labelIds: const ['lbl-sort-date'],
            sortByDate: true,
          );
          expect(
            results.map((e) => e.meta.id),
            contains('lbl-sort-date-task'),
          );
        },
      );

      test(
        'getTasks with explicit ids, label filter, sortByDate=false',
        () async {
          final base = DateTime(2024, 11, 19, 9);
          await db!.upsertLabelDefinition(
            LabelDefinition(
              id: 'lbl-ids-filter',
              createdAt: base,
              updatedAt: base,
              name: 'IdsFilterLabel',
              color: '#556677',
              vectorClock: null,
            ),
          );
          final t = buildTaskEntry(
            id: 'ids-lbl-task',
            timestamp: base,
            status: TaskStatus.open(
              id: 'ilf-status',
              createdAt: base,
              utcOffset: 0,
            ),
            categoryId: 'ilf-cat',
          );
          await db!.upsertJournalDbEntity(toDbEntity(t));
          await db!.insertLabel('ids-lbl-task', 'lbl-ids-filter');

          final results = await db!.getTasks(
            starredStatuses: const [true, false],
            taskStatuses: const ['OPEN'],
            categoryIds: const ['ilf-cat'],
            labelIds: const ['lbl-ids-filter'],
            ids: const ['ids-lbl-task'],
          );
          expect(results.map((e) => e.meta.id), contains('ids-lbl-task'));
        },
      );

      test(
        'getTasks with explicit ids, label filter, sortByDate=true',
        () async {
          final base = DateTime(2024, 11, 20, 9);
          await db!.upsertLabelDefinition(
            LabelDefinition(
              id: 'lbl-ids-sort-date',
              createdAt: base,
              updatedAt: base,
              name: 'IdsDateLabel',
              color: '#667788',
              vectorClock: null,
            ),
          );
          final t = buildTaskEntry(
            id: 'ids-sort-date-task',
            timestamp: base,
            status: TaskStatus.open(
              id: 'isd-status',
              createdAt: base,
              utcOffset: 0,
            ),
            categoryId: 'isd-cat',
            due: DateTime(2024, 11, 25),
          );
          await db!.upsertJournalDbEntity(toDbEntity(t));
          await db!.insertLabel('ids-sort-date-task', 'lbl-ids-sort-date');

          final results = await db!.getTasks(
            starredStatuses: const [true, false],
            taskStatuses: const ['OPEN'],
            categoryIds: const ['isd-cat'],
            labelIds: const ['lbl-ids-sort-date'],
            ids: const ['ids-sort-date-task'],
            sortByDate: true,
          );
          expect(
            results.map((e) => e.meta.id),
            contains('ids-sort-date-task'),
          );
        },
      );

      test(
        'getTasks with no-label filter (unlabeled items)',
        () async {
          final base = DateTime(2024, 11, 21, 9);
          final t = buildTaskEntry(
            id: 'no-lbl-task',
            timestamp: base,
            status: TaskStatus.open(
              id: 'nlt-status',
              createdAt: base,
              utcOffset: 0,
            ),
            categoryId: 'nlt-cat',
          );
          await db!.upsertJournalDbEntity(toDbEntity(t));

          // '' sentinel means "include unlabeled".
          final results = await db!.getTasks(
            starredStatuses: const [true, false],
            taskStatuses: const ['OPEN'],
            categoryIds: const ['nlt-cat'],
            labelIds: const [''],
          );
          expect(results.map((e) => e.meta.id), contains('no-lbl-task'));
        },
      );

      test(
        'getTasks with private-filtered path (not all-private)',
        () async {
          final base = DateTime(2024, 11, 22, 9);
          final t = buildTaskEntry(
            id: 'private-filtered-task',
            timestamp: base,
            status: TaskStatus.open(
              id: 'pft-status',
              createdAt: base,
              utcOffset: 0,
            ),
            categoryId: 'pft-cat',
          );
          await db!.upsertJournalDbEntity(toDbEntity(t));

          // Restrict private statuses to [false] to exercise the
          // non-all-private path in _selectTasks.
          final privateStatuses = await db!.getConfigFlagByName(privateFlag);
          // Disable private flag so _visiblePrivateStatuses returns [false].
          await db!.upsertConfigFlag(
            const ConfigFlag(
              name: privateFlag,
              description: 'Show private entries?',
              status: false,
            ),
          );

          final results = await db!.getTasks(
            starredStatuses: const [true, false],
            taskStatuses: const ['OPEN'],
            categoryIds: const ['pft-cat'],
          );
          expect(
            results.map((e) => e.meta.id),
            contains('private-filtered-task'),
          );

          // Restore the flag.
          await db!.upsertConfigFlag(
            privateStatuses ??
                const ConfigFlag(
                  name: privateFlag,
                  description: 'Show private entries?',
                  status: true,
                ),
          );
        },
      );

      test(
        '_selectTasksByStatusForDayAgent with private filter (not all-private)',
        () async {
          final base = DateTime(2024, 11, 23, 9);
          final t = buildTaskEntry(
            id: 'day-agent-priv-filter',
            timestamp: base,
            status: TaskStatus.open(
              id: 'dapf-status',
              createdAt: base,
              utcOffset: 0,
            ),
            categoryId: 'dapf-cat',
          );
          await db!.upsertJournalDbEntity(toDbEntity(t));

          // Disable the private flag so only public entries are visible.
          await db!.upsertConfigFlag(
            const ConfigFlag(
              name: privateFlag,
              description: 'Show private entries?',
              status: false,
            ),
          );

          final results = await db!.getOpenTasksForDayAgentCorpus(
            categoryIds: {'dapf-cat'},
          );
          expect(
            results.map((t) => t.meta.id),
            contains('day-agent-priv-filter'),
          );

          // Restore flag.
          await db!.upsertConfigFlag(
            const ConfigFlag(
              name: privateFlag,
              description: 'Show private entries?',
              status: true,
            ),
          );
        },
      );
    });

    group('getTasksSortedByDueDate edge cases -', () {
      test('empty taskStatuses or categoryIds returns empty list', () async {
        final results1 = await db!.getTasksSortedByDueDate(
          starredStatuses: const [true, false],
          taskStatuses: const [],
          categoryIds: const ['cat-1'],
        );
        expect(results1, isEmpty);

        final results2 = await db!.getTasksSortedByDueDate(
          starredStatuses: const [true, false],
          taskStatuses: const ['OPEN'],
          categoryIds: const [],
        );
        expect(results2, isEmpty);

        final results3 = await db!.getTasksSortedByDueDate(
          starredStatuses: const [true, false],
          taskStatuses: const ['OPEN'],
          categoryIds: const ['cat-1'],
          ids: const [],
        );
        expect(results3, isEmpty);
      });
    });

    group('getTaskEstimatesByIds -', () {
      test('returns empty map for empty input', () async {
        final result = await db!.getTaskEstimatesByIds({});
        expect(result, isEmpty);
      });

      test('returns Duration for task with estimate', () async {
        final base = DateTime(2024, 8, 2);
        final task = buildTaskEntry(
          id: 'task-with-estimate',
          timestamp: base,
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: base,
            utcOffset: 60,
          ),
        );
        // buildTaskEntry copies testTask.data which has estimate: Duration(hours: 4)
        await db!.upsertJournalDbEntity(toDbEntity(task));

        final result = await db!.getTaskEstimatesByIds({'task-with-estimate'});
        expect(result, hasLength(1));
        expect(result['task-with-estimate'], const Duration(hours: 4));
      });

      test('returns null for task without estimate', () async {
        final base = DateTime(2024, 8, 2);
        final taskNoEstimate = JournalEntity.task(
          meta: Metadata(
            id: 'task-no-estimate',
            createdAt: base,
            updatedAt: base,
            dateFrom: base,
            dateTo: base,
            starred: false,
            private: false,
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-2',
              createdAt: base,
              utcOffset: 60,
            ),
            title: 'Task without estimate',
            statusHistory: [],
            dateFrom: base,
            dateTo: base,
          ),
          entryText: const EntryText(plainText: 'No estimate task'),
        );
        await db!.upsertJournalDbEntity(toDbEntity(taskNoEstimate));

        final result = await db!.getTaskEstimatesByIds({'task-no-estimate'});
        expect(result, hasLength(1));
        expect(result['task-no-estimate'], isNull);
      });

      test('excludes non-task entities', () async {
        final base = DateTime(2024, 8, 2);
        final journalEntry = buildJournalEntry(
          id: 'not-a-task',
          timestamp: base,
          text: 'Just a journal entry',
        );
        await db!.upsertJournalDbEntity(toDbEntity(journalEntry));

        final result = await db!.getTaskEstimatesByIds({'not-a-task'});
        expect(result, isEmpty);
      });

      test('returns mix of tasks with and without estimates', () async {
        final base = DateTime(2024, 8, 2);
        final taskWithEstimate = buildTaskEntry(
          id: 'task-est-yes',
          timestamp: base,
          status: TaskStatus.open(
            id: 'status-3',
            createdAt: base,
            utcOffset: 60,
          ),
        );
        final taskWithoutEstimate = JournalEntity.task(
          meta: Metadata(
            id: 'task-est-no',
            createdAt: base,
            updatedAt: base,
            dateFrom: base,
            dateTo: base,
            starred: false,
            private: false,
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 'status-4',
              createdAt: base,
              utcOffset: 60,
            ),
            title: 'No estimate',
            statusHistory: [],
            dateFrom: base,
            dateTo: base,
          ),
          entryText: const EntryText(plainText: 'No estimate'),
        );
        final notATask = buildJournalEntry(
          id: 'entry-not-task',
          timestamp: base,
          text: 'Not a task',
        );

        await db!.upsertJournalDbEntity(toDbEntity(taskWithEstimate));
        await db!.upsertJournalDbEntity(toDbEntity(taskWithoutEstimate));
        await db!.upsertJournalDbEntity(toDbEntity(notATask));

        final result = await db!.getTaskEstimatesByIds({
          'task-est-yes',
          'task-est-no',
          'entry-not-task',
        });
        expect(result, hasLength(2));
        expect(result['task-est-yes'], const Duration(hours: 4));
        expect(result['task-est-no'], isNull);
        expect(result.containsKey('entry-not-task'), isFalse);
      });
    });

    group('getTasks not-all-starred sortByDate branches -', () {
      // starredStatuses single-valued ([true]) forces the slower
      // `_selectTasks` branches (1779+ / 1871+) instead of the
      // all-private/all-starred fast paths.
      test(
        'sortByDate without priorities uses filteredTasksByDateFast',
        () async {
          final base = DateTime(2024, 10, 15, 8);
          final starredTask = buildTaskEntry(
            id: 'fbdf-starred',
            timestamp: base.add(const Duration(minutes: 5)),
            status: TaskStatus.open(
              id: 'fbdf-s1',
              createdAt: base.add(const Duration(minutes: 5)),
              utcOffset: 0,
            ),
            categoryId: 'fbdf-cat',
            starred: true,
            due: DateTime(2024, 10, 20),
          );
          final unstarredTask = buildTaskEntry(
            id: 'fbdf-unstarred',
            timestamp: base,
            status: TaskStatus.open(
              id: 'fbdf-s2',
              createdAt: base,
              utcOffset: 0,
            ),
            categoryId: 'fbdf-cat',
            due: DateTime(2024, 10, 18),
          );

          await db!.upsertJournalDbEntity(toDbEntity(starredTask));
          await db!.upsertJournalDbEntity(toDbEntity(unstarredTask));

          final result = await db!.getTasks(
            starredStatuses: const [true],
            taskStatuses: const ['OPEN'],
            categoryIds: const ['fbdf-cat'],
            sortByDate: true,
          );
          expect(result.map((e) => e.meta.id), ['fbdf-starred']);
        },
      );

      test(
        'sortByDate with priorities uses filteredTasksByDateFastWithPriorities',
        () async {
          final base = DateTime(2024, 10, 16, 8);
          final p1Starred = JournalEntity.task(
            meta: Metadata(
              id: 'fbdfp-p1-starred',
              createdAt: base,
              updatedAt: base,
              dateFrom: base,
              dateTo: base,
              starred: true,
              categoryId: 'fbdfp-cat',
            ),
            data: testTask.data.copyWith(
              status: TaskStatus.open(
                id: 'fbdfp-s1',
                createdAt: base,
                utcOffset: 0,
              ),
              dateFrom: base,
              dateTo: base,
              title: 'P1 starred',
              priority: TaskPriority.p1High,
            ),
            entryText: const EntryText(plainText: 'p1'),
          );
          final p3Unstarred = JournalEntity.task(
            meta: Metadata(
              id: 'fbdfp-p3-unstarred',
              createdAt: base.add(const Duration(minutes: 1)),
              updatedAt: base.add(const Duration(minutes: 1)),
              dateFrom: base.add(const Duration(minutes: 1)),
              dateTo: base.add(const Duration(minutes: 1)),
              categoryId: 'fbdfp-cat',
            ),
            data: testTask.data.copyWith(
              status: TaskStatus.open(
                id: 'fbdfp-s2',
                createdAt: base.add(const Duration(minutes: 1)),
                utcOffset: 0,
              ),
              dateFrom: base.add(const Duration(minutes: 1)),
              dateTo: base.add(const Duration(minutes: 1)),
              title: 'P3 unstarred',
              priority: TaskPriority.p3Low,
            ),
            entryText: const EntryText(plainText: 'p3'),
          );

          await db!.upsertJournalDbEntity(toDbEntity(p1Starred));
          await db!.upsertJournalDbEntity(toDbEntity(p3Unstarred));

          final result = await db!.getTasks(
            starredStatuses: const [true],
            taskStatuses: const ['OPEN'],
            categoryIds: const ['fbdfp-cat'],
            priorities: const ['P1'],
            sortByDate: true,
          );
          // Only the starred P1 task matches both the starred filter and the
          // priority filter.
          expect(result.map((e) => e.meta.id), ['fbdfp-p1-starred']);
        },
      );

      test(
        'sortByDate with labels uses filteredTasksByDate',
        () async {
          final base = DateTime(2024, 10, 17, 8);
          await db!.upsertLabelDefinition(
            LabelDefinition(
              id: 'fbd-label',
              createdAt: base,
              updatedAt: base,
              name: 'FbdLabel',
              color: '#abcdef',
              vectorClock: null,
            ),
          );
          final starredLabeled = buildTaskEntry(
            id: 'fbd-starred-labeled',
            timestamp: base,
            status: TaskStatus.open(
              id: 'fbd-s1',
              createdAt: base,
              utcOffset: 0,
            ),
            categoryId: 'fbd-cat',
            starred: true,
            due: DateTime(2024, 10, 25),
          );
          final unstarredLabeled = buildTaskEntry(
            id: 'fbd-unstarred-labeled',
            timestamp: base.add(const Duration(minutes: 1)),
            status: TaskStatus.open(
              id: 'fbd-s2',
              createdAt: base.add(const Duration(minutes: 1)),
              utcOffset: 0,
            ),
            categoryId: 'fbd-cat',
            due: DateTime(2024, 10, 24),
          );

          await db!.upsertJournalDbEntity(toDbEntity(starredLabeled));
          await db!.upsertJournalDbEntity(toDbEntity(unstarredLabeled));
          await db!.insertLabel('fbd-starred-labeled', 'fbd-label');
          await db!.insertLabel('fbd-unstarred-labeled', 'fbd-label');

          final result = await db!.getTasks(
            starredStatuses: const [true],
            taskStatuses: const ['OPEN'],
            categoryIds: const ['fbd-cat'],
            labelIds: const ['fbd-label'],
            sortByDate: true,
          );
          // Label filter keeps both, starred filter keeps only the starred one.
          expect(result.map((e) => e.meta.id), ['fbd-starred-labeled']);
        },
      );
    });
  });
}
