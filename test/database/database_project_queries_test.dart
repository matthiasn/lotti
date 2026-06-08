// ignore_for_file: avoid_redundant_argument_values
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../mocks/mocks.dart';
import 'test_utils.dart';

void main() {
  setUpAll(registerJournalDbTestFallbacks);

  JournalDb? db;
  final mockUpdateNotifications = MockUpdateNotifications();
  final mockLoggingService = MockDomainLogger();
  late Directory testDirectory;

  group('JournalDb project queries - ', () {
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

    group('updateProjectIdColumn -', () {
      test('sets and clears projectId column for a task', () async {
        final base = DateTime(2024, 11, 2, 9);
        final task = buildTaskEntry(
          id: 'proj-id-col-task',
          timestamp: base,
          status: TaskStatus.open(
            id: 'proj-id-col-status',
            createdAt: base,
            utcOffset: 0,
          ),
        );
        await db!.upsertJournalDbEntity(toDbEntity(task));

        await db!.updateProjectIdColumn('proj-id-col-task', 'some-project');
        var row = await (db!.select(
          db!.journal,
        )..where((t) => t.id.equals('proj-id-col-task'))).getSingle();
        expect(row.projectId, 'some-project');

        await db!.updateProjectIdColumn('proj-id-col-task', null);
        row = await (db!.select(
          db!.journal,
        )..where((t) => t.id.equals('proj-id-col-task'))).getSingle();
        expect(row.projectId, isNull);
      });

      test('logs and swallows when the underlying statement fails', () async {
        // Dropping the journal table makes the raw UPDATE throw; the method
        // must log the failure instead of propagating it to the caller.
        // Use a throwaway DB so the destructive DROP never corrupts the
        // file-shared instance the other tests reuse.
        final throwawayDb = JournalDb(inMemoryDatabase: true);
        addTearDown(throwawayDb.close);
        await initConfigFlags(throwawayDb, inMemoryDatabase: true);

        await throwawayDb.customStatement('DROP TABLE journal');
        DevLogger.clear();

        await throwawayDb.updateProjectIdColumn('proj-id-col-task', 'proj-x');

        expect(
          DevLogger.capturedLogs.any(
            (message) => message.contains('updateProjectIdColumn error'),
          ),
          isTrue,
        );
      });
    });

    group('getTaskIdsForProjects -', () {
      test('returns empty set for empty input', () async {
        expect(await db!.getTaskIdsForProjects({}), isEmpty);
      });

      test('returns task ids that belong to the given projects', () async {
        final base = DateTime(2024, 11, 3, 9);
        final taskA = buildTaskEntry(
          id: 'task-proj-a',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-proj-a',
            createdAt: base,
            utcOffset: 0,
          ),
          categoryId: 'cat-proj',
        );
        final taskB = buildTaskEntry(
          id: 'task-proj-b',
          timestamp: base.add(const Duration(minutes: 1)),
          status: TaskStatus.open(
            id: 'ts-proj-b',
            createdAt: base.add(const Duration(minutes: 1)),
            utcOffset: 0,
          ),
          categoryId: 'cat-proj',
        );
        await db!.upsertJournalDbEntity(toDbEntity(taskA));
        await db!.upsertJournalDbEntity(toDbEntity(taskB));
        // Associate taskA with a project via direct column update.
        await db!.updateProjectIdColumn('task-proj-a', 'proj-x');

        final ids = await db!.getTaskIdsForProjects({'proj-x', 'proj-y'});
        expect(ids, contains('task-proj-a'));
        expect(ids, isNot(contains('task-proj-b')));
      });
    });

    group('getProjectIdsForTaskIds chunking -', () {
      test(
        'resolves project ids across the 500-id chunk boundary',
        () async {
          final base = DateTime(2024, 11, 3, 10);
          for (final (taskId, projectId) in [
            ('task-chunk-first', 'proj-chunk-1'),
            ('task-chunk-last', 'proj-chunk-2'),
          ]) {
            await db!.upsertJournalDbEntity(
              toDbEntity(
                buildTaskEntry(
                  id: taskId,
                  timestamp: base,
                  status: TaskStatus.open(
                    id: 'ts-$taskId',
                    createdAt: base,
                    utcOffset: 0,
                  ),
                ),
              ),
            );
            await db!.updateProjectIdColumn(taskId, projectId);
          }

          // Real ids sit at positions 0 and 500 so they land in different
          // chunks; everything in between is unknown to the database.
          final queryIds = <String>{
            'task-chunk-first',
            for (var i = 0; i < 499; i++) 'task-chunk-missing-$i',
            'task-chunk-last',
          };
          expect(queryIds, hasLength(501));

          final projectIds = await db!.getProjectIdsForTaskIds(queryIds);
          expect(projectIds, {'proj-chunk-1', 'proj-chunk-2'});
        },
      );
    });

    group('Project queries -', () {
      JournalEntity buildProjectEntry({
        required String id,
        required DateTime timestamp,
        bool privateFlag = false,
        String? categoryId,
      }) {
        return JournalEntity.project(
          meta: Metadata(
            id: id,
            createdAt: timestamp,
            updatedAt: timestamp,
            dateFrom: timestamp,
            dateTo: timestamp,
            private: privateFlag,
            categoryId: categoryId,
          ),
          data: ProjectData(
            title: 'Project $id',
            status: ProjectStatus.active(
              id: 'ps-$id',
              createdAt: timestamp,
              utcOffset: 0,
            ),
            dateFrom: timestamp,
            dateTo: timestamp,
          ),
        );
      }

      EntryLink buildProjectLink({
        required String id,
        required String fromId,
        required String toId,
        required DateTime timestamp,
        bool hidden = false,
      }) {
        return EntryLink.project(
          id: id,
          fromId: fromId,
          toId: toId,
          createdAt: timestamp,
          updatedAt: timestamp,
          vectorClock: const VectorClock({'db': 1}),
          hidden: hidden ? true : null,
          deletedAt: hidden ? timestamp : null,
        );
      }

      test('getProjectsForCategory returns projects in category', () async {
        final base = DateTime(2024, 7, 1);
        final p1 = buildProjectEntry(
          id: 'proj-cat-1',
          timestamp: base,
          categoryId: 'cat-a',
        );
        final p2 = buildProjectEntry(
          id: 'proj-cat-2',
          timestamp: base.add(const Duration(hours: 1)),
          categoryId: 'cat-a',
        );
        final p3 = buildProjectEntry(
          id: 'proj-other',
          timestamp: base,
          categoryId: 'cat-b',
        );

        await db!.upsertJournalDbEntity(toDbEntity(p1));
        await db!.upsertJournalDbEntity(toDbEntity(p2));
        await db!.upsertJournalDbEntity(toDbEntity(p3));

        final result = await db!.getProjectsForCategory('cat-a');

        expect(result, hasLength(2));
        expect(
          result.map((p) => p.meta.id).toSet(),
          {'proj-cat-1', 'proj-cat-2'},
        );
      });

      test('getProjectsForCategory excludes deleted projects', () async {
        final base = DateTime(2024, 7, 2);
        final active = buildProjectEntry(
          id: 'proj-active',
          timestamp: base,
          categoryId: 'cat-del',
        );
        final deleted = buildProjectEntry(
          id: 'proj-deleted',
          timestamp: base,
          categoryId: 'cat-del',
        );
        final deletedEntity = (deleted as ProjectEntry).copyWith(
          meta: deleted.meta.copyWith(deletedAt: base),
        );

        await db!.upsertJournalDbEntity(toDbEntity(active));
        await db!.upsertJournalDbEntity(toDbEntity(deletedEntity));

        final result = await db!.getProjectsForCategory('cat-del');

        expect(result, hasLength(1));
        expect(result.first.meta.id, 'proj-active');
      });

      test('getProjectsForCategory respects private flag', () async {
        final base = DateTime(2024, 7, 3);
        final publicProj = buildProjectEntry(
          id: 'proj-public',
          timestamp: base,
          categoryId: 'cat-priv',
        );
        final privateProj = buildProjectEntry(
          id: 'proj-private',
          timestamp: base,
          categoryId: 'cat-priv',
          privateFlag: true,
        );

        await db!.upsertJournalDbEntity(toDbEntity(publicProj));
        await db!.upsertJournalDbEntity(toDbEntity(privateProj));

        // Disable private entries
        await db!.upsertConfigFlag(
          const ConfigFlag(
            name: 'private',
            description: 'Show private entries?',
            status: false,
          ),
        );

        final result = await db!.getProjectsForCategory('cat-priv');
        expect(result, hasLength(1));
        expect(result.first.meta.id, 'proj-public');

        // Re-enable private entries
        await db!.upsertConfigFlag(
          const ConfigFlag(
            name: 'private',
            description: 'Show private entries?',
            status: true,
          ),
        );

        final resultWithPrivate = await db!.getProjectsForCategory('cat-priv');
        expect(resultWithPrivate, hasLength(2));
      });

      test('getTasksForProject returns linked tasks', () async {
        final base = DateTime(2024, 7, 4);
        final project = buildProjectEntry(
          id: 'proj-tasks',
          timestamp: base,
          categoryId: 'cat-t',
        );
        final task1 = buildTaskEntry(
          id: 'task-linked-1',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-l1',
            createdAt: base,
            utcOffset: 0,
          ),
          categoryId: 'cat-t',
        );
        final task2 = buildTaskEntry(
          id: 'task-linked-2',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-l2',
            createdAt: base,
            utcOffset: 0,
          ),
          categoryId: 'cat-t',
        );
        final unlinkedTask = buildTaskEntry(
          id: 'task-unlinked',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-u',
            createdAt: base,
            utcOffset: 0,
          ),
          categoryId: 'cat-t',
        );

        await db!.upsertJournalDbEntity(toDbEntity(project));
        await db!.upsertJournalDbEntity(toDbEntity(task1));
        await db!.upsertJournalDbEntity(toDbEntity(task2));
        await db!.upsertJournalDbEntity(toDbEntity(unlinkedTask));

        // Link task1 and task2 to project
        await db!.upsertEntryLink(
          buildProjectLink(
            id: 'pl-1',
            fromId: 'proj-tasks',
            toId: 'task-linked-1',
            timestamp: base,
          ),
        );
        await db!.upsertEntryLink(
          buildProjectLink(
            id: 'pl-2',
            fromId: 'proj-tasks',
            toId: 'task-linked-2',
            timestamp: base,
          ),
        );

        final result = await db!.getTasksForProject('proj-tasks');

        expect(result, hasLength(2));
        expect(
          result.map((t) => t.meta.id).toSet(),
          {'task-linked-1', 'task-linked-2'},
        );
      });

      test('getTasksForProject excludes hidden links', () async {
        final base = DateTime(2024, 7, 5);
        final project = buildProjectEntry(
          id: 'proj-hidden',
          timestamp: base,
          categoryId: 'cat-h',
        );
        final task = buildTaskEntry(
          id: 'task-hidden-link',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-h',
            createdAt: base,
            utcOffset: 0,
          ),
          categoryId: 'cat-h',
        );

        await db!.upsertJournalDbEntity(toDbEntity(project));
        await db!.upsertJournalDbEntity(toDbEntity(task));

        // Create a hidden (soft-deleted) link
        await db!.upsertEntryLink(
          buildProjectLink(
            id: 'pl-hidden',
            fromId: 'proj-hidden',
            toId: 'task-hidden-link',
            timestamp: base,
            hidden: true,
          ),
        );

        final result = await db!.getTasksForProject('proj-hidden');

        expect(result, isEmpty);
      });

      test('getTasksForProject only returns Task type entities', () async {
        final base = DateTime(2024, 7, 6);
        final project = buildProjectEntry(
          id: 'proj-type-guard',
          timestamp: base,
          categoryId: 'cat-tg',
        );
        final task = buildTaskEntry(
          id: 'task-type-guard',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-tg',
            createdAt: base,
            utcOffset: 0,
          ),
          categoryId: 'cat-tg',
        );
        // A non-task entity linked with a ProjectLink
        final note = createJournalEntry('note body', id: 'note-type-guard');

        await db!.upsertJournalDbEntity(toDbEntity(project));
        await db!.upsertJournalDbEntity(toDbEntity(task));
        await db!.upsertJournalDbEntity(toDbEntity(note));

        await db!.upsertEntryLink(
          buildProjectLink(
            id: 'pl-task',
            fromId: 'proj-type-guard',
            toId: 'task-type-guard',
            timestamp: base,
          ),
        );
        await db!.upsertEntryLink(
          buildProjectLink(
            id: 'pl-note',
            fromId: 'proj-type-guard',
            toId: 'note-type-guard',
            timestamp: base,
          ),
        );

        final result = await db!.getTasksForProject('proj-type-guard');

        // Only the Task should be returned, not the note
        expect(result, hasLength(1));
        expect(result.first.meta.id, 'task-type-guard');
      });

      test('getTasksForProject respects private flag', () async {
        final base = DateTime(2024, 7, 13);
        final project = buildProjectEntry(
          id: 'proj-task-priv',
          timestamp: base,
          categoryId: 'cat-tp',
        );
        final publicTask = buildTaskEntry(
          id: 'task-public-tp',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-pub-tp',
            createdAt: base,
            utcOffset: 0,
          ),
          categoryId: 'cat-tp',
        );
        final privateTask = buildTaskEntry(
          id: 'task-private-tp',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-priv-tp',
            createdAt: base,
            utcOffset: 0,
          ),
          categoryId: 'cat-tp',
          privateFlag: true,
        );

        await db!.upsertJournalDbEntity(toDbEntity(project));
        await db!.upsertJournalDbEntity(toDbEntity(publicTask));
        await db!.upsertJournalDbEntity(toDbEntity(privateTask));

        await db!.upsertEntryLink(
          buildProjectLink(
            id: 'pl-pub-tp',
            fromId: 'proj-task-priv',
            toId: 'task-public-tp',
            timestamp: base,
          ),
        );
        await db!.upsertEntryLink(
          buildProjectLink(
            id: 'pl-priv-tp',
            fromId: 'proj-task-priv',
            toId: 'task-private-tp',
            timestamp: base,
          ),
        );

        // Disable private entries
        await db!.upsertConfigFlag(
          const ConfigFlag(
            name: 'private',
            description: 'Show private entries?',
            status: false,
          ),
        );

        final result = await db!.getTasksForProject('proj-task-priv');
        expect(result, hasLength(1));
        expect(result.first.meta.id, 'task-public-tp');

        // Re-enable private entries
        await db!.upsertConfigFlag(
          const ConfigFlag(
            name: 'private',
            description: 'Show private entries?',
            status: true,
          ),
        );

        final resultWithPrivate = await db!.getTasksForProject(
          'proj-task-priv',
        );
        expect(resultWithPrivate, hasLength(2));
      });

      test('getProjectForTask returns linked project', () async {
        final base = DateTime(2024, 7, 7);
        final project = buildProjectEntry(
          id: 'proj-for-task',
          timestamp: base,
          categoryId: 'cat-ft',
        );
        final task = buildTaskEntry(
          id: 'task-has-project',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-ft',
            createdAt: base,
            utcOffset: 0,
          ),
          categoryId: 'cat-ft',
        );

        await db!.upsertJournalDbEntity(toDbEntity(project));
        await db!.upsertJournalDbEntity(toDbEntity(task));
        await db!.upsertEntryLink(
          buildProjectLink(
            id: 'pl-ft',
            fromId: 'proj-for-task',
            toId: 'task-has-project',
            timestamp: base,
          ),
        );

        final result = await db!.getProjectForTask('task-has-project');

        expect(result, isNotNull);
        expect(result!.meta.id, 'proj-for-task');
        expect(result.data.title, 'Project proj-for-task');
      });

      test('getProjectForTask returns null for unlinked task', () async {
        final result = await db!.getProjectForTask('nonexistent-task');
        expect(result, isNull);
      });

      test('getProjectForTask excludes hidden links', () async {
        final base = DateTime(2024, 7, 8);
        final project = buildProjectEntry(
          id: 'proj-hidden-ft',
          timestamp: base,
          categoryId: 'cat-hft',
        );
        final task = buildTaskEntry(
          id: 'task-hidden-ft',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-hft',
            createdAt: base,
            utcOffset: 0,
          ),
          categoryId: 'cat-hft',
        );

        await db!.upsertJournalDbEntity(toDbEntity(project));
        await db!.upsertJournalDbEntity(toDbEntity(task));
        await db!.upsertEntryLink(
          buildProjectLink(
            id: 'pl-hft',
            fromId: 'proj-hidden-ft',
            toId: 'task-hidden-ft',
            timestamp: base,
            hidden: true,
          ),
        );

        final result = await db!.getProjectForTask('task-hidden-ft');
        expect(result, isNull);
      });

      test('getProjectForTask respects private flag', () async {
        final base = DateTime(2024, 7, 9);
        final privateProject = buildProjectEntry(
          id: 'proj-priv-ft',
          timestamp: base,
          categoryId: 'cat-pft',
          privateFlag: true,
        );
        final task = buildTaskEntry(
          id: 'task-priv-ft',
          timestamp: base,
          status: TaskStatus.open(
            id: 'ts-pft',
            createdAt: base,
            utcOffset: 0,
          ),
          categoryId: 'cat-pft',
        );

        await db!.upsertJournalDbEntity(toDbEntity(privateProject));
        await db!.upsertJournalDbEntity(toDbEntity(task));
        await db!.upsertEntryLink(
          buildProjectLink(
            id: 'pl-pft',
            fromId: 'proj-priv-ft',
            toId: 'task-priv-ft',
            timestamp: base,
          ),
        );

        // Disable private entries
        await db!.upsertConfigFlag(
          const ConfigFlag(
            name: 'private',
            description: 'Show private entries?',
            status: false,
          ),
        );

        final result = await db!.getProjectForTask('task-priv-ft');
        expect(result, isNull);

        // Re-enable private entries
        await db!.upsertConfigFlag(
          const ConfigFlag(
            name: 'private',
            description: 'Show private entries?',
            status: true,
          ),
        );

        final resultWithPrivate = await db!.getProjectForTask('task-priv-ft');
        expect(resultWithPrivate, isNotNull);
        expect(resultWithPrivate!.meta.id, 'proj-priv-ft');
      });

      test(
        'getExistingProjectIds returns only live project ids and handles empty input',
        () async {
          expect(await db!.getExistingProjectIds({}), isEmpty);

          final base = DateTime(2024, 7, 10);
          final activeProject = buildProjectEntry(
            id: 'proj-existing-live',
            timestamp: base,
            categoryId: 'cat-existing',
          );
          final deletedProjectBase =
              buildProjectEntry(
                    id: 'proj-existing-deleted',
                    timestamp: base.add(const Duration(minutes: 1)),
                    categoryId: 'cat-existing',
                  )
                  as ProjectEntry;
          final deletedProject = deletedProjectBase.copyWith(
            meta: deletedProjectBase.meta.copyWith(
              deletedAt: base.add(const Duration(minutes: 2)),
            ),
          );
          final task = buildTaskEntry(
            id: 'task-existing-ignore',
            timestamp: base,
            status: TaskStatus.open(
              id: 'ts-existing-ignore',
              createdAt: base,
              utcOffset: 0,
            ),
            categoryId: 'cat-existing',
          );

          await db!.upsertJournalDbEntity(toDbEntity(activeProject));
          await db!.upsertJournalDbEntity(toDbEntity(deletedProject));
          await db!.upsertJournalDbEntity(toDbEntity(task));

          final result = await db!.getExistingProjectIds({
            'proj-existing-live',
            'proj-existing-deleted',
            'task-existing-ignore',
            'proj-missing',
          });

          expect(result, {'proj-existing-live'});
        },
      );

      test(
        'getProjectIdsForTaskIds returns distinct live project ids and ignores non-tasks',
        () async {
          expect(await db!.getProjectIdsForTaskIds({}), isEmpty);

          final base = DateTime(2024, 7, 11);
          final projectOne = buildProjectEntry(
            id: 'proj-task-lookup-1',
            timestamp: base,
            categoryId: 'cat-lookup',
          );
          final projectTwo = buildProjectEntry(
            id: 'proj-task-lookup-2',
            timestamp: base.add(const Duration(minutes: 1)),
            categoryId: 'cat-lookup',
          );
          final projectDeletedTarget = buildProjectEntry(
            id: 'proj-deleted-target',
            timestamp: base.add(const Duration(minutes: 5)),
            categoryId: 'cat-lookup',
          );
          final projectNoteTarget = buildProjectEntry(
            id: 'proj-note-target',
            timestamp: base.add(const Duration(minutes: 6)),
            categoryId: 'cat-lookup',
          );
          final linkedTaskOne = buildTaskEntry(
            id: 'task-project-one-a',
            timestamp: base,
            status: TaskStatus.open(
              id: 'ts-project-one-a',
              createdAt: base,
              utcOffset: 0,
            ),
            categoryId: 'cat-lookup',
          );
          final linkedTaskTwo = buildTaskEntry(
            id: 'task-project-one-b',
            timestamp: base.add(const Duration(minutes: 1)),
            status: TaskStatus.open(
              id: 'ts-project-one-b',
              createdAt: base.add(const Duration(minutes: 1)),
              utcOffset: 0,
            ),
            categoryId: 'cat-lookup',
          );
          final linkedTaskThree = buildTaskEntry(
            id: 'task-project-two',
            timestamp: base.add(const Duration(minutes: 2)),
            status: TaskStatus.open(
              id: 'ts-project-two',
              createdAt: base.add(const Duration(minutes: 2)),
              utcOffset: 0,
            ),
            categoryId: 'cat-lookup',
          );
          final unlinkedTask = buildTaskEntry(
            id: 'task-without-project',
            timestamp: base.add(const Duration(minutes: 3)),
            status: TaskStatus.open(
              id: 'ts-without-project',
              createdAt: base.add(const Duration(minutes: 3)),
              utcOffset: 0,
            ),
            categoryId: 'cat-lookup',
          );
          final deletedTaskBase =
              buildTaskEntry(
                    id: 'task-deleted-project',
                    timestamp: base.add(const Duration(minutes: 4)),
                    status: TaskStatus.open(
                      id: 'ts-deleted-project',
                      createdAt: base.add(const Duration(minutes: 4)),
                      utcOffset: 0,
                    ),
                    categoryId: 'cat-lookup',
                  )
                  as Task;
          final deletedTask = deletedTaskBase.copyWith(
            meta: deletedTaskBase.meta.copyWith(
              deletedAt: base.add(const Duration(minutes: 5)),
            ),
          );
          final note = createJournalEntry(
            'linked note body',
            id: 'note-linked-to-project',
          );

          await db!.upsertJournalDbEntity(toDbEntity(projectOne));
          await db!.upsertJournalDbEntity(toDbEntity(projectTwo));
          await db!.upsertJournalDbEntity(toDbEntity(projectDeletedTarget));
          await db!.upsertJournalDbEntity(toDbEntity(projectNoteTarget));
          await db!.upsertJournalDbEntity(toDbEntity(linkedTaskOne));
          await db!.upsertJournalDbEntity(toDbEntity(linkedTaskTwo));
          await db!.upsertJournalDbEntity(toDbEntity(linkedTaskThree));
          await db!.upsertJournalDbEntity(toDbEntity(unlinkedTask));
          await db!.upsertJournalDbEntity(toDbEntity(deletedTask));
          await db!.upsertJournalDbEntity(toDbEntity(note));

          await db!.upsertEntryLink(
            buildProjectLink(
              id: 'pl-project-one-a',
              fromId: 'proj-task-lookup-1',
              toId: 'task-project-one-a',
              timestamp: base,
            ),
          );
          await db!.upsertEntryLink(
            buildProjectLink(
              id: 'pl-project-one-b',
              fromId: 'proj-task-lookup-1',
              toId: 'task-project-one-b',
              timestamp: base.add(const Duration(minutes: 1)),
            ),
          );
          await db!.upsertEntryLink(
            buildProjectLink(
              id: 'pl-project-two',
              fromId: 'proj-task-lookup-2',
              toId: 'task-project-two',
              timestamp: base.add(const Duration(minutes: 2)),
            ),
          );
          await db!.upsertEntryLink(
            buildProjectLink(
              id: 'pl-project-deleted',
              fromId: 'proj-deleted-target',
              toId: 'task-deleted-project',
              timestamp: base.add(const Duration(minutes: 3)),
            ),
          );
          await db!.upsertEntryLink(
            buildProjectLink(
              id: 'pl-project-note',
              fromId: 'proj-note-target',
              toId: 'note-linked-to-project',
              timestamp: base.add(const Duration(minutes: 4)),
            ),
          );

          final result = await db!.getProjectIdsForTaskIds({
            'task-project-one-a',
            'task-project-one-b',
            'task-project-two',
            'task-without-project',
            'task-deleted-project',
            'note-linked-to-project',
            'task-missing',
          });

          expect(result, {'proj-task-lookup-1', 'proj-task-lookup-2'});
        },
      );

      test('getProjectLinkForTask returns active link', () async {
        final base = DateTime(2024, 7, 10);
        final link = buildProjectLink(
          id: 'pl-link-ft',
          fromId: 'proj-link-ft',
          toId: 'task-link-ft',
          timestamp: base,
        );

        await db!.upsertEntryLink(link);

        final result = await db!.getProjectLinkForTask('task-link-ft');

        expect(result, isNotNull);
        expect(result, isA<ProjectLink>());
        expect(result!.fromId, 'proj-link-ft');
        expect(result.toId, 'task-link-ft');
      });

      test('getProjectLinkForTask returns null for hidden link', () async {
        final base = DateTime(2024, 7, 11);
        await db!.upsertEntryLink(
          buildProjectLink(
            id: 'pl-hidden-link',
            fromId: 'proj-hidden-link',
            toId: 'task-hidden-link',
            timestamp: base,
            hidden: true,
          ),
        );

        final result = await db!.getProjectLinkForTask('task-hidden-link');
        expect(result, isNull);
      });

      test('getProjectLinkForTask returns null for no link', () async {
        final result = await db!.getProjectLinkForTask('no-link-task');
        expect(result, isNull);
      });

      test(
        'getProjectLinkForTask returns most recently updated link',
        () async {
          final base = DateTime(2024, 7, 12);
          // Create two active links (shouldn't normally happen, but tests
          // deterministic ordering)
          await db!.upsertEntryLink(
            EntryLink.project(
              id: 'pl-older',
              fromId: 'proj-older',
              toId: 'task-determ',
              createdAt: base,
              updatedAt: base,
              vectorClock: const VectorClock({'db': 1}),
            ),
          );
          await db!.upsertEntryLink(
            EntryLink.project(
              id: 'pl-newer',
              fromId: 'proj-newer',
              toId: 'task-determ',
              createdAt: base,
              updatedAt: base.add(const Duration(hours: 1)),
              vectorClock: const VectorClock({'db': 2}),
            ),
          );

          final result = await db!.getProjectLinkForTask('task-determ');

          expect(result, isNotNull);
          // Should return the most recently updated link
          expect(result!.fromId, 'proj-newer');
        },
      );

      test(
        'getVisibleProjects returns non-deleted projects ordered by '
        'dateFrom desc',
        () async {
          final base = DateTime(2024, 8, 1);
          final p1 = buildProjectEntry(
            id: 'proj-vis-1',
            timestamp: base,
            categoryId: 'cat-vis',
          );
          final p2 = buildProjectEntry(
            id: 'proj-vis-2',
            timestamp: base.add(const Duration(hours: 2)),
            categoryId: 'cat-vis',
          );
          final p3 = buildProjectEntry(
            id: 'proj-vis-3',
            timestamp: base.add(const Duration(hours: 1)),
            categoryId: 'cat-vis-other',
          );
          final deletedBase =
              buildProjectEntry(
                    id: 'proj-vis-deleted',
                    timestamp: base.add(const Duration(hours: 3)),
                    categoryId: 'cat-vis',
                  )
                  as ProjectEntry;
          final deletedProject = deletedBase.copyWith(
            meta: deletedBase.meta.copyWith(
              deletedAt: base.add(const Duration(hours: 4)),
            ),
          );

          await db!.upsertJournalDbEntity(toDbEntity(p1));
          await db!.upsertJournalDbEntity(toDbEntity(p2));
          await db!.upsertJournalDbEntity(toDbEntity(p3));
          await db!.upsertJournalDbEntity(toDbEntity(deletedProject));

          final result = await db!.getVisibleProjects();

          // Should exclude the deleted project
          final ids = result.map((p) => p.meta.id).toList();
          expect(ids, contains('proj-vis-1'));
          expect(ids, contains('proj-vis-2'));
          expect(ids, contains('proj-vis-3'));
          expect(ids, isNot(contains('proj-vis-deleted')));

          // Should be ordered by dateFrom descending
          final visIds = result
              .where(
                (p) => p.meta.id.startsWith('proj-vis-'),
              )
              .map((p) => p.meta.id)
              .toList();
          final idx1 = visIds.indexOf('proj-vis-2');
          final idx2 = visIds.indexOf('proj-vis-3');
          final idx3 = visIds.indexOf('proj-vis-1');
          expect(idx1, lessThan(idx2));
          expect(idx2, lessThan(idx3));
        },
      );

      test(
        'getProjectTaskRollups returns empty map for empty input',
        () async {
          final result = await db!.getProjectTaskRollups({});
          expect(result, isEmpty);
        },
      );

      test(
        'getProjectTaskRollups aggregates task counts by project',
        () async {
          final base = DateTime(2024, 8, 2);
          final project1 = buildProjectEntry(
            id: 'proj-rollup-1',
            timestamp: base,
            categoryId: 'cat-rollup',
          );
          final project2 = buildProjectEntry(
            id: 'proj-rollup-2',
            timestamp: base.add(const Duration(hours: 1)),
            categoryId: 'cat-rollup',
          );

          // Project 1 tasks: 1 DONE, 1 BLOCKED, 1 open
          final task1Done = buildTaskEntry(
            id: 'task-r1-done',
            timestamp: base,
            status: TaskStatus.done(
              id: 'ts-r1-done',
              createdAt: base,
              utcOffset: 0,
            ),
            categoryId: 'cat-rollup',
          );
          final task1Blocked = buildTaskEntry(
            id: 'task-r1-blocked',
            timestamp: base.add(const Duration(minutes: 1)),
            status: TaskStatus.blocked(
              id: 'ts-r1-blocked',
              createdAt: base.add(const Duration(minutes: 1)),
              utcOffset: 0,
              reason: 'waiting on dependency',
            ),
            categoryId: 'cat-rollup',
          );
          final task1Open = buildTaskEntry(
            id: 'task-r1-open',
            timestamp: base.add(const Duration(minutes: 2)),
            status: TaskStatus.open(
              id: 'ts-r1-open',
              createdAt: base.add(const Duration(minutes: 2)),
              utcOffset: 0,
            ),
            categoryId: 'cat-rollup',
          );

          // Project 2 tasks: 2 DONE
          final task2DoneA = buildTaskEntry(
            id: 'task-r2-done-a',
            timestamp: base.add(const Duration(minutes: 3)),
            status: TaskStatus.done(
              id: 'ts-r2-done-a',
              createdAt: base.add(const Duration(minutes: 3)),
              utcOffset: 0,
            ),
            categoryId: 'cat-rollup',
          );
          final task2DoneB = buildTaskEntry(
            id: 'task-r2-done-b',
            timestamp: base.add(const Duration(minutes: 4)),
            status: TaskStatus.done(
              id: 'ts-r2-done-b',
              createdAt: base.add(const Duration(minutes: 4)),
              utcOffset: 0,
            ),
            categoryId: 'cat-rollup',
          );

          // Insert all entities
          await db!.upsertJournalDbEntity(toDbEntity(project1));
          await db!.upsertJournalDbEntity(toDbEntity(project2));
          await db!.upsertJournalDbEntity(toDbEntity(task1Done));
          await db!.upsertJournalDbEntity(toDbEntity(task1Blocked));
          await db!.upsertJournalDbEntity(toDbEntity(task1Open));
          await db!.upsertJournalDbEntity(toDbEntity(task2DoneA));
          await db!.upsertJournalDbEntity(toDbEntity(task2DoneB));

          // Link tasks to projects
          await db!.upsertEntryLink(
            buildProjectLink(
              id: 'pl-r1-done',
              fromId: 'proj-rollup-1',
              toId: 'task-r1-done',
              timestamp: base,
            ),
          );
          await db!.upsertEntryLink(
            buildProjectLink(
              id: 'pl-r1-blocked',
              fromId: 'proj-rollup-1',
              toId: 'task-r1-blocked',
              timestamp: base.add(const Duration(minutes: 1)),
            ),
          );
          await db!.upsertEntryLink(
            buildProjectLink(
              id: 'pl-r1-open',
              fromId: 'proj-rollup-1',
              toId: 'task-r1-open',
              timestamp: base.add(const Duration(minutes: 2)),
            ),
          );
          await db!.upsertEntryLink(
            buildProjectLink(
              id: 'pl-r2-done-a',
              fromId: 'proj-rollup-2',
              toId: 'task-r2-done-a',
              timestamp: base.add(const Duration(minutes: 3)),
            ),
          );
          await db!.upsertEntryLink(
            buildProjectLink(
              id: 'pl-r2-done-b',
              fromId: 'proj-rollup-2',
              toId: 'task-r2-done-b',
              timestamp: base.add(const Duration(minutes: 4)),
            ),
          );

          final result = await db!.getProjectTaskRollups({
            'proj-rollup-1',
            'proj-rollup-2',
          });

          expect(result, hasLength(2));

          // Project 1: 3 total, 1 completed, 1 blocked
          final rollup1 = result['proj-rollup-1']!;
          expect(rollup1.totalTaskCount, 3);
          expect(rollup1.completedTaskCount, 1);
          expect(rollup1.blockedTaskCount, 1);

          // Project 2: 2 total, 2 completed, 0 blocked
          final rollup2 = result['proj-rollup-2']!;
          expect(rollup2.totalTaskCount, 2);
          expect(rollup2.completedTaskCount, 2);
          expect(rollup2.blockedTaskCount, 0);
        },
      );

      test(
        'getProjectTaskRollups filtered path excludes private tasks when '
        'private flag is off',
        () async {
          final base = DateTime(2024, 9, 1, 8);
          final project = buildProjectEntry(
            id: 'proj-priv-rollup',
            timestamp: base,
            categoryId: 'cat-priv-rollup',
          );
          // Public task linked to the project.
          final publicTask = buildTaskEntry(
            id: 'task-pub-rollup',
            timestamp: base,
            status: TaskStatus.done(
              id: 'ts-pub-rollup',
              createdAt: base,
              utcOffset: 0,
            ),
            categoryId: 'cat-priv-rollup',
          );
          // Private task linked to the same project.
          final privateTask = buildTaskEntry(
            id: 'task-priv-rollup',
            timestamp: base.add(const Duration(minutes: 1)),
            status: TaskStatus.done(
              id: 'ts-priv-rollup',
              createdAt: base.add(const Duration(minutes: 1)),
              utcOffset: 0,
            ),
            categoryId: 'cat-priv-rollup',
            privateFlag: true,
          );

          await db!.upsertJournalDbEntity(toDbEntity(project));
          await db!.upsertJournalDbEntity(toDbEntity(publicTask));
          await db!.upsertJournalDbEntity(toDbEntity(privateTask));
          await db!.upsertEntryLink(
            buildProjectLink(
              id: 'pl-pub-rollup',
              fromId: 'proj-priv-rollup',
              toId: 'task-pub-rollup',
              timestamp: base,
            ),
          );
          await db!.upsertEntryLink(
            buildProjectLink(
              id: 'pl-priv-rollup',
              fromId: 'proj-priv-rollup',
              toId: 'task-priv-rollup',
              timestamp: base.add(const Duration(minutes: 1)),
            ),
          );

          // With private visible (default) both tasks count.
          final all = await db!.getProjectTaskRollups({'proj-priv-rollup'});
          expect(all['proj-priv-rollup']!.totalTaskCount, 2);
          expect(all['proj-priv-rollup']!.completedTaskCount, 2);

          // Disable private entries -> filtered SQL branch drops the
          // private task from the aggregate.
          await db!.upsertConfigFlag(
            const ConfigFlag(
              name: privateFlag,
              description: 'Show private entries?',
              status: false,
            ),
          );

          final filtered = await db!.getProjectTaskRollups({
            'proj-priv-rollup',
          });
          expect(filtered['proj-priv-rollup']!.totalTaskCount, 1);
          expect(filtered['proj-priv-rollup']!.completedTaskCount, 1);
        },
      );

      test('getVisibleProjects returns active projects ordered by date '
          'desc', () async {
        final base = DateTime(2024, 9, 2, 8);
        final older = buildProjectEntry(
          id: 'vis-proj-older',
          timestamp: base,
          categoryId: 'cat-vis',
        );
        final newer = buildProjectEntry(
          id: 'vis-proj-newer',
          timestamp: base.add(const Duration(days: 1)),
          categoryId: 'cat-vis',
        );

        await db!.upsertJournalDbEntity(toDbEntity(older));
        await db!.upsertJournalDbEntity(toDbEntity(newer));

        final result = await db!.getVisibleProjects();
        final ids = result.map((p) => p.meta.id).toList();
        // dateFrom desc -> newer first.
        expect(
          ids.indexOf('vis-proj-newer'),
          lessThan(ids.indexOf('vis-proj-older')),
        );
      });

      test(
        'getVisibleProjects filtered path excludes private projects when '
        'private flag is off',
        () async {
          final base = DateTime(2024, 9, 3, 8);
          final publicProject = buildProjectEntry(
            id: 'vis-proj-public',
            timestamp: base,
            categoryId: 'cat-vis-priv',
          );
          final privateProject = buildProjectEntry(
            id: 'vis-proj-private',
            timestamp: base.add(const Duration(hours: 1)),
            categoryId: 'cat-vis-priv',
            privateFlag: true,
          );

          await db!.upsertJournalDbEntity(toDbEntity(publicProject));
          await db!.upsertJournalDbEntity(toDbEntity(privateProject));

          // Private visible (default) -> both returned.
          final all = await db!.getVisibleProjects();
          expect(
            all.map((p) => p.meta.id),
            containsAll(<String>['vis-proj-public', 'vis-proj-private']),
          );

          // Disable private -> filtered predicate drops the private project.
          await db!.upsertConfigFlag(
            const ConfigFlag(
              name: privateFlag,
              description: 'Show private entries?',
              status: false,
            ),
          );

          final filtered = await db!.getVisibleProjects();
          final filteredIds = filtered.map((p) => p.meta.id).toSet();
          expect(filteredIds, contains('vis-proj-public'));
          expect(filteredIds, isNot(contains('vis-proj-private')));
        },
      );
    });
  });
}
