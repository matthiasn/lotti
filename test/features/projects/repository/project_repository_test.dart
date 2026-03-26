import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../categories/test_utils.dart';
import '../test_utils.dart';

void main() {
  final testDate = DateTime(2024, 3, 15, 10, 30);

  late MockJournalDb mockDb;
  late MockPersistenceLogic mockPersistence;
  late MockUpdateNotifications mockNotifications;
  late MockVectorClockService mockVectorClockService;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockOutboxService mockOutboxService;
  late StreamController<Set<String>> updateStreamController;
  late ProjectRepository repository;

  final projectMeta = Metadata(
    id: 'project-001',
    createdAt: testDate,
    updatedAt: testDate,
    dateFrom: testDate,
    dateTo: testDate,
    categoryId: 'cat-1',
  );

  final projectEntry = ProjectEntry(
    meta: projectMeta,
    data: ProjectData(
      title: 'Test Project',
      status: ProjectStatus.active(
        id: 'status-1',
        createdAt: testDate,
        utcOffset: 60,
      ),
      dateFrom: testDate,
      dateTo: testDate,
    ),
  );

  final taskMeta = Metadata(
    id: 'task-001',
    createdAt: testDate,
    updatedAt: testDate,
    dateFrom: testDate,
    dateTo: testDate,
    categoryId: 'cat-1',
  );

  final taskEntry = Task(
    meta: taskMeta,
    data: TaskData(
      status: TaskStatus.open(
        id: 'ts-1',
        createdAt: testDate,
        utcOffset: 60,
      ),
      dateFrom: testDate,
      dateTo: testDate,
      statusHistory: [],
      title: 'Test Task',
    ),
  );

  final workCategory = CategoryTestUtils.createTestCategory(
    id: 'cat-1',
    name: 'Work',
  );
  final studyCategory = CategoryTestUtils.createTestCategory(
    id: 'cat-2',
    name: 'Study',
  );

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    mockDb = MockJournalDb();
    mockPersistence = MockPersistenceLogic();
    mockNotifications = MockUpdateNotifications();
    mockVectorClockService = MockVectorClockService();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockOutboxService = MockOutboxService();
    updateStreamController = StreamController<Set<String>>.broadcast();

    // Register OutboxService in GetIt (used by _enqueueLinkSync)
    await getIt.reset();
    getIt.registerSingleton<OutboxService>(mockOutboxService);
    when(
      () => mockOutboxService.enqueueMessage(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockNotifications.updateStream,
    ).thenAnswer((_) => updateStreamController.stream);
    when(
      () => mockEntitiesCacheService.categoriesById,
    ).thenReturn({
      workCategory.id: workCategory,
      studyCategory.id: studyCategory,
    });
    when(
      () => mockEntitiesCacheService.sortedCategories,
    ).thenReturn([workCategory, studyCategory]);

    repository = ProjectRepository(
      journalDb: mockDb,
      entitiesCacheService: mockEntitiesCacheService,
      persistenceLogic: mockPersistence,
      updateNotifications: mockNotifications,
      vectorClockService: mockVectorClockService,
    );
  });

  tearDown(() async {
    await updateStreamController.close();
    await getIt.reset();
  });

  group('getProjectById', () {
    test('returns ProjectEntry when entity is a project', () async {
      when(
        () => mockDb.journalEntityById('project-001'),
      ).thenAnswer((_) async => projectEntry);

      final result = await repository.getProjectById('project-001');

      expect(result, isA<ProjectEntry>());
      expect(result?.data.title, 'Test Project');
    });

    test('returns null when entity is not a project', () async {
      when(
        () => mockDb.journalEntityById('task-001'),
      ).thenAnswer((_) async => taskEntry);

      final result = await repository.getProjectById('task-001');

      expect(result, isNull);
    });

    test('returns null when entity does not exist', () async {
      when(
        () => mockDb.journalEntityById('nonexistent'),
      ).thenAnswer((_) async => null);

      final result = await repository.getProjectById('nonexistent');

      expect(result, isNull);
    });
  });

  group('getProjectsForCategory', () {
    test('delegates to JournalDb', () async {
      when(
        () => mockDb.getProjectsForCategory('cat-1'),
      ).thenAnswer((_) async => [projectEntry]);

      final result = await repository.getProjectsForCategory('cat-1');

      expect(result, hasLength(1));
      expect(result.first.data.title, 'Test Project');
      verify(() => mockDb.getProjectsForCategory('cat-1')).called(1);
    });
  });

  group('getTasksForProject', () {
    test('delegates to JournalDb', () async {
      when(
        () => mockDb.getTasksForProject('project-001'),
      ).thenAnswer((_) async => [taskEntry]);

      final result = await repository.getTasksForProject('project-001');

      expect(result, hasLength(1));
      expect(result.first.data.title, 'Test Task');
      verify(() => mockDb.getTasksForProject('project-001')).called(1);
    });
  });

  group('getProjectForTask', () {
    test('delegates to JournalDb', () async {
      when(
        () => mockDb.getProjectForTask('task-001'),
      ).thenAnswer((_) async => projectEntry);

      final result = await repository.getProjectForTask('task-001');

      expect(result, isA<ProjectEntry>());
      expect(result?.data.title, 'Test Project');
    });
  });

  group('getProjectsOverview', () {
    test(
      'groups visible projects by category and maps batch task rollups',
      () async {
        final secondProject = makeTestProject(
          id: 'project-002',
          title: 'Study Project',
          categoryId: studyCategory.id,
        );

        when(() => mockDb.getVisibleProjects()).thenAnswer(
          (_) async => [projectEntry, secondProject],
        );
        when(
          () => mockDb.getProjectTaskRollups({'project-001', 'project-002'}),
        ).thenAnswer(
          (_) async => {
            'project-001': (
              totalTaskCount: 5,
              completedTaskCount: 3,
              blockedTaskCount: 1,
            ),
            'project-002': (
              totalTaskCount: 2,
              completedTaskCount: 1,
              blockedTaskCount: 0,
            ),
          },
        );

        final result = await repository.getProjectsOverview(
          query: const ProjectsQuery(),
        );

        expect(result.groups, hasLength(2));
        expect(result.groups.first.category?.name, 'Work');
        expect(
          result.groups.first.projects.single.taskRollup.totalTaskCount,
          5,
        );
        expect(
          result.groups[1].projects.single.taskRollup.completedTaskCount,
          1,
        );
        verifyNever(() => mockDb.getProjectsForCategory(any()));
        verifyNever(() => mockDb.getTasksForProject(any()));
      },
    );
  });

  group('watchProjectsOverview', () {
    test('re-fetches the grouped snapshot on relevant notifications', () async {
      var repositoryCallCount = 0;
      final initialProject = makeTestProject(
        id: 'project-010',
        title: 'Initial Project',
        categoryId: workCategory.id,
      );
      final updatedProject = makeTestProject(
        id: 'project-011',
        title: 'Updated Project',
        categoryId: workCategory.id,
      );

      when(() => mockDb.getVisibleProjects()).thenAnswer((_) async {
        return repositoryCallCount++ == 0
            ? [initialProject]
            : [initialProject, updatedProject];
      });
      when(
        () => mockDb.getProjectTaskRollups(any()),
      ).thenAnswer((invocation) async {
        final ids = invocation.positionalArguments.first as Set<String>;
        return {
          for (final id in ids)
            id: (
              totalTaskCount: id == 'project-011' ? 2 : 1,
              completedTaskCount: 0,
              blockedTaskCount: 0,
            ),
        };
      });

      final stream = repository.watchProjectsOverview(
        query: const ProjectsQuery(),
      );

      final expectation = expectLater(
        stream,
        emitsInOrder([
          isA<ProjectsOverviewSnapshot>().having(
            (snapshot) => snapshot.totalProjectCount,
            'initial project count',
            1,
          ),
          isA<ProjectsOverviewSnapshot>().having(
            (snapshot) => snapshot.totalProjectCount,
            'updated project count',
            2,
          ),
        ]),
      );

      await Future<void>.microtask(() {});
      updateStreamController.add({taskNotification});
      await expectation;
    });

    test('re-fetches when an existing project id changes status', () async {
      var repositoryCallCount = 0;
      final activeProject = makeTestProject(
        id: 'project-020',
        title: 'Device Sync',
        status: ProjectStatus.active(
          id: 'status-active',
          createdAt: testDate,
          utcOffset: 60,
        ),
        categoryId: workCategory.id,
      );
      final completedProject = makeTestProject(
        id: 'project-020',
        title: 'Device Sync',
        status: ProjectStatus.completed(
          id: 'status-completed',
          createdAt: testDate.add(const Duration(hours: 1)),
          utcOffset: 60,
        ),
        categoryId: workCategory.id,
      );

      when(() => mockDb.getVisibleProjects()).thenAnswer((_) async {
        return repositoryCallCount++ == 0
            ? [activeProject]
            : [completedProject];
      });
      when(
        () => mockDb.getProjectTaskRollups({'project-020'}),
      ).thenAnswer(
        (_) async => {
          'project-020': (
            totalTaskCount: 5,
            completedTaskCount: 5,
            blockedTaskCount: 0,
          ),
        },
      );

      final stream = repository.watchProjectsOverview(
        query: const ProjectsQuery(),
      );

      final expectation = expectLater(
        stream,
        emitsInOrder([
          isA<ProjectsOverviewSnapshot>().having(
            (snapshot) =>
                snapshot.groups.single.projects.single.project.data.status,
            'initial status',
            isA<ProjectActive>(),
          ),
          isA<ProjectsOverviewSnapshot>().having(
            (snapshot) =>
                snapshot.groups.single.projects.single.project.data.status,
            'updated status',
            isA<ProjectCompleted>(),
          ),
        ]),
      );

      await Future<void>.microtask(() {});
      updateStreamController.add({'project-020'});
      await expectation;
    });
  });

  group('createProject', () {
    test('persists via PersistenceLogic and returns project', () async {
      when(
        () => mockPersistence.createDbEntity(projectEntry),
      ).thenAnswer((_) async => true);

      final result = await repository.createProject(project: projectEntry);

      expect(result, isA<ProjectEntry>());
      verify(() => mockPersistence.createDbEntity(projectEntry)).called(1);
    });

    test('returns null when persistence fails', () async {
      when(
        () => mockPersistence.createDbEntity(projectEntry),
      ).thenAnswer((_) async => false);

      final result = await repository.createProject(project: projectEntry);

      expect(result, isNull);
    });

    test('returns null when persistence returns null', () async {
      when(
        () => mockPersistence.createDbEntity(projectEntry),
      ).thenAnswer((_) async => null);

      final result = await repository.createProject(project: projectEntry);

      expect(result, isNull);
    });
  });

  group('updateProject', () {
    test('bumps metadata and persists', () async {
      final updatedMeta = projectMeta.copyWith(
        updatedAt: DateTime(2024, 3, 16),
        vectorClock: const VectorClock({'device-1': 2}),
      );

      when(
        () => mockPersistence.updateMetadata(projectMeta),
      ).thenAnswer((_) async => updatedMeta);
      when(
        () => mockPersistence.updateDbEntity(
          projectEntry.copyWith(meta: updatedMeta),
        ),
      ).thenAnswer((_) async => true);

      final result = await repository.updateProject(projectEntry);

      expect(result, isTrue);
      verify(() => mockPersistence.updateMetadata(projectMeta)).called(1);
      verify(
        () => mockNotifications.notify({
          projectEntityUpdateNotification(projectEntry.id),
        }),
      ).called(1);
    });

    test('returns false when persistence fails', () async {
      final updatedMeta = projectMeta.copyWith(
        updatedAt: DateTime(2024, 3, 16),
        vectorClock: const VectorClock({'device-1': 2}),
      );

      when(
        () => mockPersistence.updateMetadata(projectMeta),
      ).thenAnswer((_) async => updatedMeta);
      when(
        () => mockPersistence.updateDbEntity(
          projectEntry.copyWith(meta: updatedMeta),
        ),
      ).thenAnswer((_) async => false);

      final result = await repository.updateProject(projectEntry);

      expect(result, isFalse);
      verifyNever(() => mockNotifications.notify(any()));
    });
  });

  group('linkTaskToProject', () {
    test('creates new link when task has no existing project', () async {
      when(
        () => mockDb.journalEntityById('project-001'),
      ).thenAnswer((_) async => projectEntry);
      when(
        () => mockDb.journalEntityById('task-001'),
      ).thenAnswer((_) async => taskEntry);
      when(
        () => mockDb.getProjectLinkForTask('task-001'),
      ).thenAnswer((_) async => null);
      when(() => mockDb.upsertEntryLink(any())).thenAnswer((_) async => 1);
      when(() => mockNotifications.notify(any())).thenReturn(null);
      when(
        mockVectorClockService.getNextVectorClock,
      ).thenAnswer((_) async => const VectorClock({'d': 1}));

      final result = await repository.linkTaskToProject(
        projectId: 'project-001',
        taskId: 'task-001',
      );

      expect(result, isTrue);

      // Verify link was created with correct fromId/toId
      final captured =
          verify(() => mockDb.upsertEntryLink(captureAny())).captured.single
              as EntryLink;
      expect(captured, isA<ProjectLink>());
      expect(captured.fromId, 'project-001');
      expect(captured.toId, 'task-001');
      expect(captured.hidden, isNull);

      // Verify notifications include entity IDs and project token
      verify(
        () => mockNotifications.notify({
          'project-001',
          'task-001',
          projectNotification,
          projectEntityUpdateNotification('project-001'),
        }),
      ).called(1);

      // Verify sync enqueued
      verify(() => mockOutboxService.enqueueMessage(any())).called(1);
    });

    test('rejects cross-category linking', () async {
      final crossCategoryTask = Task(
        meta: taskMeta.copyWith(categoryId: 'cat-different'),
        data: taskEntry.data,
      );

      when(
        () => mockDb.journalEntityById('project-001'),
      ).thenAnswer((_) async => projectEntry);
      when(
        () => mockDb.journalEntityById('task-cross'),
      ).thenAnswer((_) async => crossCategoryTask);

      final result = await repository.linkTaskToProject(
        projectId: 'project-001',
        taskId: 'task-cross',
      );

      expect(result, isFalse);
    });

    test('rejects non-Task entity', () async {
      // A note entity should not be linkable as a "task"
      final noteEntry = JournalEntity.journalEntry(
        meta: taskMeta,
        entryText: const EntryText(plainText: 'Just a note'),
      );

      when(
        () => mockDb.journalEntityById('project-001'),
      ).thenAnswer((_) async => projectEntry);
      when(
        () => mockDb.journalEntityById('task-001'),
      ).thenAnswer((_) async => noteEntry);

      final result = await repository.linkTaskToProject(
        projectId: 'project-001',
        taskId: 'task-001',
      );

      expect(result, isFalse);
      verifyNever(() => mockDb.upsertEntryLink(any()));
    });

    test('returns false when project does not exist', () async {
      when(
        () => mockDb.journalEntityById('missing'),
      ).thenAnswer((_) async => null);
      when(
        () => mockDb.journalEntityById('task-001'),
      ).thenAnswer((_) async => taskEntry);

      final result = await repository.linkTaskToProject(
        projectId: 'missing',
        taskId: 'task-001',
      );

      expect(result, isFalse);
    });

    test('returns false when task does not exist', () async {
      when(
        () => mockDb.journalEntityById('project-001'),
      ).thenAnswer((_) async => projectEntry);
      when(
        () => mockDb.journalEntityById('missing'),
      ).thenAnswer((_) async => null);

      final result = await repository.linkTaskToProject(
        projectId: 'project-001',
        taskId: 'missing',
      );

      expect(result, isFalse);
    });

    test('returns false when upsert affects zero rows', () async {
      when(
        () => mockDb.journalEntityById('project-001'),
      ).thenAnswer((_) async => projectEntry);
      when(
        () => mockDb.journalEntityById('task-001'),
      ).thenAnswer((_) async => taskEntry);
      when(
        () => mockDb.getProjectLinkForTask('task-001'),
      ).thenAnswer((_) async => null);
      when(() => mockDb.upsertEntryLink(any())).thenAnswer((_) async => 0);
      when(
        mockVectorClockService.getNextVectorClock,
      ).thenAnswer((_) async => const VectorClock({'d': 1}));

      final result = await repository.linkTaskToProject(
        projectId: 'project-001',
        taskId: 'task-001',
      );

      expect(result, isFalse);
      verifyNever(() => mockNotifications.notify(any()));
      verifyNever(() => mockOutboxService.enqueueMessage(any()));
    });

    test('returns true if task is already linked to same project', () async {
      final existingLink = EntryLink.project(
        id: 'link-existing',
        fromId: 'project-001',
        toId: 'task-001',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
      );

      when(
        () => mockDb.journalEntityById('project-001'),
      ).thenAnswer((_) async => projectEntry);
      when(
        () => mockDb.journalEntityById('task-001'),
      ).thenAnswer((_) async => taskEntry);
      when(
        () => mockDb.getProjectLinkForTask('task-001'),
      ).thenAnswer((_) async => existingLink);

      final result = await repository.linkTaskToProject(
        projectId: 'project-001',
        taskId: 'task-001',
      );

      expect(result, isTrue);
      verifyNever(() => mockDb.upsertEntryLink(any()));
    });

    test(
      'atomically soft-deletes old link and creates new one in transaction',
      () async {
        final oldLink = EntryLink.project(
          id: 'link-old',
          fromId: 'project-old',
          toId: 'task-001',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        when(
          () => mockDb.journalEntityById('project-001'),
        ).thenAnswer((_) async => projectEntry);
        when(
          () => mockDb.journalEntityById('task-001'),
        ).thenAnswer((_) async => taskEntry);
        when(
          () => mockDb.getProjectLinkForTask('task-001'),
        ).thenAnswer((_) async => oldLink);
        when(() => mockDb.upsertEntryLink(any())).thenAnswer((_) async => 1);
        when(() => mockNotifications.notify(any())).thenReturn(null);
        when(
          mockVectorClockService.getNextVectorClock,
        ).thenAnswer((_) async => const VectorClock({'d': 1}));

        final result = await repository.linkTaskToProject(
          projectId: 'project-001',
          taskId: 'task-001',
        );

        expect(result, isTrue);
        // Both writes happen inside the transaction
        verify(() => mockDb.upsertEntryLink(any())).called(2);
        // Sync enqueued for both delete and create after commit
        verify(() => mockOutboxService.enqueueMessage(any())).called(2);
        // Notifications include old project, new project, task, and token
        verify(
          () => mockNotifications.notify({
            'project-old',
            'task-001',
            'project-001',
            projectNotification,
            projectEntityUpdateNotification('project-old'),
            projectEntityUpdateNotification('project-001'),
          }),
        ).called(1);
      },
    );

    test(
      'returns false when soft-delete fails during relink transaction',
      () async {
        final oldLink = EntryLink.project(
          id: 'link-old',
          fromId: 'project-old',
          toId: 'task-001',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        when(
          () => mockDb.journalEntityById('project-001'),
        ).thenAnswer((_) async => projectEntry);
        when(
          () => mockDb.journalEntityById('task-001'),
        ).thenAnswer((_) async => taskEntry);
        when(
          () => mockDb.getProjectLinkForTask('task-001'),
        ).thenAnswer((_) async => oldLink);
        // Soft-delete upsert returns 0 (failure)
        when(() => mockDb.upsertEntryLink(any())).thenAnswer((_) async => 0);
        when(
          mockVectorClockService.getNextVectorClock,
        ).thenAnswer((_) async => const VectorClock({'d': 1}));

        final result = await repository.linkTaskToProject(
          projectId: 'project-001',
          taskId: 'task-001',
        );

        expect(result, isFalse);
        // Only the soft-delete was attempted; insert skipped
        verify(() => mockDb.upsertEntryLink(any())).called(1);
        // No side effects on failure
        verifyNever(() => mockNotifications.notify(any()));
        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      },
    );

    test(
      'returns false when insert fails after soft-delete in transaction',
      () async {
        final oldLink = EntryLink.project(
          id: 'link-old',
          fromId: 'project-old',
          toId: 'task-001',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        when(
          () => mockDb.journalEntityById('project-001'),
        ).thenAnswer((_) async => projectEntry);
        when(
          () => mockDb.journalEntityById('task-001'),
        ).thenAnswer((_) async => taskEntry);
        when(
          () => mockDb.getProjectLinkForTask('task-001'),
        ).thenAnswer((_) async => oldLink);
        // First call (soft-delete) succeeds, second call (insert) fails
        var callCount = 0;
        when(() => mockDb.upsertEntryLink(any())).thenAnswer((_) async {
          callCount++;
          return callCount == 1 ? 1 : 0;
        });
        when(
          mockVectorClockService.getNextVectorClock,
        ).thenAnswer((_) async => const VectorClock({'d': 1}));

        final result = await repository.linkTaskToProject(
          projectId: 'project-001',
          taskId: 'task-001',
        );

        expect(result, isFalse);
        // Both writes were attempted inside transaction
        verify(() => mockDb.upsertEntryLink(any())).called(2);
        // No side effects — transaction failed
        verifyNever(() => mockNotifications.notify(any()));
        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      },
    );
  });

  group('unlinkTaskFromProject', () {
    test('returns false when no link exists', () async {
      when(
        () => mockDb.getProjectLinkForTask('task-001'),
      ).thenAnswer((_) async => null);

      final result = await repository.unlinkTaskFromProject('task-001');

      expect(result, isFalse);
    });

    test('soft-deletes existing link with hidden flag', () async {
      final existingLink = EntryLink.project(
        id: 'link-001',
        fromId: 'project-001',
        toId: 'task-001',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
      );

      when(
        () => mockDb.getProjectLinkForTask('task-001'),
      ).thenAnswer((_) async => existingLink);
      when(() => mockDb.upsertEntryLink(any())).thenAnswer((_) async => 1);
      when(() => mockNotifications.notify(any())).thenReturn(null);
      when(
        mockVectorClockService.getNextVectorClock,
      ).thenAnswer((_) async => const VectorClock({'d': 2}));

      final result = await repository.unlinkTaskFromProject('task-001');

      expect(result, isTrue);
      final captured =
          verify(() => mockDb.upsertEntryLink(captureAny())).captured.single
              as EntryLink;
      expect(captured.deletedAt, isNotNull);
      expect(captured.hidden, isTrue);
      expect(captured.vectorClock, const VectorClock({'d': 2}));
      verify(
        () => mockNotifications.notify({
          'project-001',
          'task-001',
          projectNotification,
          projectEntityUpdateNotification('project-001'),
        }),
      ).called(1);
      // Verify sync was enqueued
      verify(() => mockOutboxService.enqueueMessage(any())).called(1);
    });

    test('returns false when soft-delete upsert fails', () async {
      final existingLink = EntryLink.project(
        id: 'link-001',
        fromId: 'project-001',
        toId: 'task-001',
        createdAt: testDate,
        updatedAt: testDate,
        vectorClock: null,
      );

      when(
        () => mockDb.getProjectLinkForTask('task-001'),
      ).thenAnswer((_) async => existingLink);
      when(() => mockDb.upsertEntryLink(any())).thenAnswer((_) async => 0);
      when(
        mockVectorClockService.getNextVectorClock,
      ).thenAnswer((_) async => const VectorClock({'d': 2}));

      final result = await repository.unlinkTaskFromProject('task-001');

      expect(result, isFalse);
      verifyNever(() => mockNotifications.notify(any()));
      verifyNever(() => mockOutboxService.enqueueMessage(any()));
    });
  });

  group('updateStream', () {
    test('delegates to UpdateNotifications', () {
      final stream = Stream<Set<String>>.fromIterable([
        {'project-001'},
      ]);
      when(
        () => mockNotifications.updateStream,
      ).thenAnswer((_) => stream);

      expect(repository.updateStream, stream);
    });
  });

  group('resolveAffectedProjectIds', () {
    test('combines direct project ids with task-derived project ids', () async {
      when(
        () => mockDb.getExistingProjectIds({'project-001', 'task-001'}),
      ).thenAnswer((_) async => {'project-001'});
      when(
        () => mockDb.getProjectIdsForTaskIds({'project-001', 'task-001'}),
      ).thenAnswer((_) async => {'project-002'});

      final result = await repository.resolveAffectedProjectIds({
        'project-001',
        'task-001',
      });

      expect(result, {'project-001', 'project-002'});
    });

    test('strips PROJECT_ENTITY_UPDATE: prefix before DB lookup', () async {
      when(
        () => mockDb.getExistingProjectIds({'project-001'}),
      ).thenAnswer((_) async => {'project-001'});
      when(
        () => mockDb.getProjectIdsForTaskIds({'project-001'}),
      ).thenAnswer((_) async => {});

      final result = await repository.resolveAffectedProjectIds({
        projectEntityUpdateNotification('project-001'),
      });

      expect(result, {'project-001'});
    });
  });
}
