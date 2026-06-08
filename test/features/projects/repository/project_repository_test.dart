import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
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

  // setUpTestGetIt pre-registers several core services; tests that need a
  // mock variant swap it in instead of double-registering.
  void reRegister<T extends Object>(T instance) {
    if (getIt.isRegistered<T>()) {
      getIt.unregister<T>();
    }
    getIt.registerSingleton<T>(instance);
  }

  setUp(() async {
    mockDb = MockJournalDb();
    mockPersistence = MockPersistenceLogic();
    mockNotifications = MockUpdateNotifications();
    mockVectorClockService = MockVectorClockService();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockOutboxService = MockOutboxService();
    updateStreamController = StreamController<Set<String>>.broadcast();

    // Register OutboxService via the central helper (used by
    // _enqueueLinkSync); setUpTestGetIt owns reset + base registrations.
    await setUpTestGetIt(
      additionalSetup: () {
        if (getIt.isRegistered<OutboxService>()) {
          getIt.unregister<OutboxService>();
        }
        getIt.registerSingleton<OutboxService>(mockOutboxService);
      },
    );
    when(
      () => mockOutboxService.enqueueMessage(any()),
    ).thenAnswer((_) async {});

    // Canonical happy-path stubs shared by most tests; individual tests
    // re-stub these (mocktail last-wins) for error/edge paths.
    when(() => mockNotifications.notify(any())).thenReturn(null);
    when(() => mockDb.upsertEntryLink(any())).thenAnswer((_) async => 1);
    when(
      () => mockDb.journalEntityById('project-001'),
    ).thenAnswer((_) async => projectEntry);
    when(
      () => mockDb.journalEntityById('task-001'),
    ).thenAnswer((_) async => taskEntry);
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
    await tearDownTestGetIt();
  });

  group('getProjectById', () {
    test('returns ProjectEntry when entity is a project', () async {
      final result = await repository.getProjectById('project-001');

      expect(result, isA<ProjectEntry>());
      expect(result?.data.title, 'Test Project');
    });

    test('returns null when entity is not a project', () async {
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

    test('emits error when getProjectsOverview throws', () async {
      when(
        () => mockDb.getVisibleProjects(),
      ).thenThrow(Exception('database failure'));

      final stream = repository.watchProjectsOverview(
        query: const ProjectsQuery(),
      );

      await expectLater(
        stream,
        emitsError(isA<Exception>()),
      );
    });

    test(
      'refreshes on PROJECT_ENTITY_UPDATE:project-001 notification',
      () async {
        var repositoryCallCount = 0;
        final project = makeTestProject(
          id: 'project-001',
          title: 'My Project',
          categoryId: workCategory.id,
        );

        when(() => mockDb.getVisibleProjects()).thenAnswer((_) async {
          repositoryCallCount++;
          return [project];
        });
        when(
          () => mockDb.getProjectTaskRollups(any()),
        ).thenAnswer(
          (_) async => {
            'project-001': (
              totalTaskCount: repositoryCallCount,
              completedTaskCount: 0,
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
              (s) => s.groups.single.projects.single.taskRollup.totalTaskCount,
              'initial totalTaskCount',
              1,
            ),
            isA<ProjectsOverviewSnapshot>().having(
              (s) => s.groups.single.projects.single.taskRollup.totalTaskCount,
              'refreshed totalTaskCount',
              2,
            ),
          ]),
        );

        await Future<void>.microtask(() {});
        updateStreamController.add({
          projectEntityUpdateNotification('project-001'),
        });
        await expectation;
      },
    );

    test('skips refresh for irrelevant notification IDs', () async {
      when(() => mockDb.getVisibleProjects()).thenAnswer(
        (_) async => [projectEntry],
      );
      when(
        () => mockDb.getProjectTaskRollups(any()),
      ).thenAnswer(
        (_) async => {
          'project-001': (
            totalTaskCount: 1,
            completedTaskCount: 0,
            blockedTaskCount: 0,
          ),
        },
      );

      final stream = repository.watchProjectsOverview(
        query: const ProjectsQuery(),
      );

      final emissions = <ProjectsOverviewSnapshot>[];
      final subscription = stream.listen(emissions.add);

      // Wait for initial emission
      await pumpEventQueue();

      expect(emissions, hasLength(1));

      // Emit an unrelated ID that is not a project, task token, category,
      // or private toggle token
      updateStreamController.add({'unrelated-entity-999'});
      await pumpEventQueue();

      // No additional emission should have occurred
      expect(emissions, hasLength(1));

      await subscription.cancel();
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

    test('returns false when persistence returns null', () async {
      // Exercises the `result ?? false` coalescing branch: a null result
      // must be treated as failure — no notification is emitted.
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
      ).thenAnswer((_) async => null);

      final result = await repository.updateProject(projectEntry);

      expect(result, isFalse);
      verifyNever(() => mockNotifications.notify(any()));
    });
  });

  group('linkTaskToProject', () {
    test('creates new link when task has no existing project', () async {
      when(
        () => mockDb.getProjectLinkForTask('task-001'),
      ).thenAnswer((_) async => null);
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

      // Verify notifications include entity IDs, the project token, and
      // the propagated form so the wake orchestrator defers the parent
      // project agent's wake to the next 06:00 instead of firing immediately
      // on every task link.
      verify(
        () => mockNotifications.notify({
          'project-001',
          'task-001',
          projectNotification,
          projectEntityUpdateNotification('project-001'),
          propagatedNotification(
            projectEntityUpdateNotification('project-001'),
          ),
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

      final result = await repository.linkTaskToProject(
        projectId: 'missing',
        taskId: 'task-001',
      );

      expect(result, isFalse);
    });

    test('returns false when task does not exist', () async {
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
          () => mockDb.getProjectLinkForTask('task-001'),
        ).thenAnswer((_) async => oldLink);
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
        // Notifications include the old project, new project, task, and
        // the bare + propagated forms of each project token so wake
        // orchestrator subscriptions on the project IDs defer to morning
        // (relinking is a task-link side-effect, not a direct project
        // edit).
        verify(
          () => mockNotifications.notify({
            'project-old',
            'task-001',
            'project-001',
            projectNotification,
            projectEntityUpdateNotification('project-old'),
            projectEntityUpdateNotification('project-001'),
            propagatedNotification(
              projectEntityUpdateNotification('project-old'),
            ),
            propagatedNotification(
              projectEntityUpdateNotification('project-001'),
            ),
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
          propagatedNotification(
            projectEntityUpdateNotification('project-001'),
          ),
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

  group('sequence-log integration', () {
    late MockSyncSequenceLogService mockSequenceLog;
    late MockDomainLogger mockDomainLogger;

    // These mocks are swapped into getIt via `reRegister` (unregister-if-
    // present + registerSingleton). No inner tearDown is needed: the outer
    // `tearDownTestGetIt()` performs a full `getIt.reset()` after every test,
    // so these registrations never outlive the test that created them. The
    // central helper owns cleanup; per-key teardown here would be redundant.
    setUp(() {
      mockSequenceLog = MockSyncSequenceLogService();
      mockDomainLogger = MockDomainLogger();
      when(
        () => mockSequenceLog.recordSentEntryLink(
          linkId: any(named: 'linkId'),
          vectorClock: any(named: 'vectorClock'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockDomainLogger.error(
          any<LogDomain>(),
          any<Object>(),
          message: any<String>(named: 'message'),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenReturn(null);
      reRegister<SyncSequenceLogService>(mockSequenceLog);
      reRegister<DomainLogger>(mockDomainLogger);
    });

    test('linkTaskToProject records the new link sequence', () async {
      when(
        () => mockDb.getProjectLinkForTask('task-001'),
      ).thenAnswer((_) async => null);
      when(
        mockVectorClockService.getNextVectorClock,
      ).thenAnswer((_) async => const VectorClock({'d': 1}));

      final result = await repository.linkTaskToProject(
        projectId: 'project-001',
        taskId: 'task-001',
      );

      expect(result, isTrue);
      verify(
        () => mockSequenceLog.recordSentEntryLink(
          linkId: any(named: 'linkId'),
          vectorClock: const VectorClock({'d': 1}),
        ),
      ).called(1);
    });

    test(
      'relinkTask records both the soft-delete and the new link sequence',
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
          () => mockDb.getProjectLinkForTask('task-001'),
        ).thenAnswer((_) async => oldLink);
        when(
          mockVectorClockService.getNextVectorClock,
        ).thenAnswer((_) async => const VectorClock({'d': 1}));

        await repository.linkTaskToProject(
          projectId: 'project-001',
          taskId: 'task-001',
        );

        verify(
          () => mockSequenceLog.recordSentEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
          ),
        ).called(2);
      },
    );

    test(
      'unlinkTaskFromProject records the soft-deleted link sequence',
      () async {
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
        when(
          mockVectorClockService.getNextVectorClock,
        ).thenAnswer((_) async => const VectorClock({'d': 2}));

        await repository.unlinkTaskFromProject('task-001');

        verify(
          () => mockSequenceLog.recordSentEntryLink(
            linkId: 'link-001',
            vectorClock: const VectorClock({'d': 2}),
          ),
        ).called(1);
      },
    );

    test(
      'sequence-record failure is swallowed and routed through DomainLogger; '
      'the link write is still considered successful and sync still enqueues',
      () async {
        when(
          () => mockSequenceLog.recordSentEntryLink(
            linkId: any(named: 'linkId'),
            vectorClock: any(named: 'vectorClock'),
          ),
        ).thenThrow(StateError('sequence ledger boom'));
        when(
          () => mockDb.getProjectLinkForTask('task-001'),
        ).thenAnswer((_) async => null);
        when(
          mockVectorClockService.getNextVectorClock,
        ).thenAnswer((_) async => const VectorClock({'d': 1}));

        final result = await repository.linkTaskToProject(
          projectId: 'project-001',
          taskId: 'task-001',
        );

        expect(result, isTrue);
        verify(
          () => mockDomainLogger.error(
            LogDomain.sync,
            any<Object>(),
            message: any<String>(
              named: 'message',
              that: contains('sequence record failed after project link'),
            ),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'linkTaskToProject.recordSent',
          ),
        ).called(1);
        verify(() => mockOutboxService.enqueueMessage(any())).called(1);
      },
    );
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

  group('getProjectsOverview — extra categories without cache entry', () {
    // Lines 162, 164-166: exercises the null-name fallback in the sort
    // comparator for extra category IDs not present in categoriesById.
    test(
      'sorts extra categories by id when category definition is absent',
      () async {
        // Two projects with category IDs that are NOT in the sorted list and
        // NOT in categoriesById, so the sort falls back to the raw ID string.
        final projectZebra = makeTestProject(
          id: 'project-z',
          title: 'Zebra Project',
          categoryId: 'zzz-unknown',
        );
        final projectAlpha = makeTestProject(
          id: 'project-a',
          title: 'Alpha Project',
          categoryId: 'aaa-unknown',
        );

        // Neither unknown category is in entitiesCache → falls back to id sort.
        when(
          () => mockEntitiesCacheService.categoriesById,
        ).thenReturn({
          // Intentionally empty: no entry for 'aaa-unknown' or 'zzz-unknown'.
        });
        when(
          () => mockEntitiesCacheService.sortedCategories,
        ).thenReturn([]);

        when(() => mockDb.getVisibleProjects()).thenAnswer(
          (_) async => [projectZebra, projectAlpha],
        );
        when(
          () => mockDb.getProjectTaskRollups(any()),
        ).thenAnswer((_) async => {});

        final result = await repository.getProjectsOverview(
          query: const ProjectsQuery(),
        );

        // 'aaa-unknown' sorts before 'zzz-unknown' alphabetically.
        expect(result.groups, hasLength(2));
        expect(result.groups[0].categoryId, 'aaa-unknown');
        expect(result.groups[1].categoryId, 'zzz-unknown');
      },
    );

    test(
      'sorts extra categories by name when one has a definition and one does not',
      () async {
        // 'known-cat' has a CategoryDefinition with name "Bravo".
        // 'orphan-cat' has no definition — falls back to its raw ID "orphan-cat".
        // Alphabetically "Bravo" < "orphan-cat", so known-cat group comes first.
        final knownProject = makeTestProject(
          id: 'project-known',
          title: 'Known Project',
          categoryId: 'known-cat',
        );
        final orphanProject = makeTestProject(
          id: 'project-orphan',
          title: 'Orphan Project',
          categoryId: 'orphan-cat',
        );

        final bravoCategory = CategoryTestUtils.createTestCategory(
          id: 'known-cat',
          name: 'Bravo',
        );

        when(
          () => mockEntitiesCacheService.categoriesById,
        ).thenReturn({bravoCategory.id: bravoCategory});
        when(
          () => mockEntitiesCacheService.sortedCategories,
        ).thenReturn([]); // neither is in the sorted list → both are extras

        when(() => mockDb.getVisibleProjects()).thenAnswer(
          (_) async => [orphanProject, knownProject],
        );
        when(
          () => mockDb.getProjectTaskRollups(any()),
        ).thenAnswer((_) async => {});

        final result = await repository.getProjectsOverview(
          query: const ProjectsQuery(),
        );

        expect(result.groups, hasLength(2));
        // 'Bravo'.toLowerCase() < 'orphan-cat'.toLowerCase()
        expect(result.groups[0].categoryId, 'known-cat');
        expect(result.groups[1].categoryId, 'orphan-cat');
      },
    );
  });

  group('watchProjectsOverview — pending re-fetch', () {
    // Lines 229, 231: a second notification arrives while the first fetch is
    // still in flight; pendingRefetch is set and triggers a second doFetch().
    test('coalesces concurrent notifications into a single re-fetch', () async {
      // Each call to getVisibleProjects completes synchronously in our mock,
      // but we need to simulate overlap. We use a Completer so the first fetch
      // pauses until we explicitly let it through.
      final firstFetchCompleter = Completer<List<ProjectEntry>>();
      var callCount = 0;

      final projectV1 = makeTestProject(
        id: 'project-prf',
        title: 'V1',
        categoryId: workCategory.id,
      );
      final projectV2 = makeTestProject(
        id: 'project-prf',
        title: 'V2',
        categoryId: workCategory.id,
      );

      when(() => mockDb.getVisibleProjects()).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return firstFetchCompleter.future;
        }
        return [projectV2];
      });
      when(
        () => mockDb.getProjectTaskRollups(any()),
      ).thenAnswer(
        (_) async => {
          'project-prf': (
            totalTaskCount: 1,
            completedTaskCount: 0,
            blockedTaskCount: 0,
          ),
        },
      );

      final stream = repository.watchProjectsOverview(
        query: const ProjectsQuery(),
      );

      // Collect emitted titles.
      final emittedTitles = <String>[];
      final subscription = stream.listen((snapshot) {
        for (final group in snapshot.groups) {
          for (final item in group.projects) {
            emittedTitles.add(item.project.data.title);
          }
        }
      });

      // Let onListen fire — starts first fetch (which is now paused).
      await Future<void>.microtask(() {});

      // Two rapid notifications arrive while fetch-1 is still in flight.
      updateStreamController
        ..add({taskNotification})
        ..add({projectNotification});
      await Future<void>.microtask(() {});

      // Release the first fetch — the pendingRefetch flag causes a second
      // doFetch() in the finally block.
      firstFetchCompleter.complete([projectV1]);

      // Allow both doFetch completions to propagate — drain the event queue
      // deterministically (fake-time policy).
      await pumpEventQueue();

      await subscription.cancel();

      // The stream must have emitted at least two snapshots: one for the
      // initial V1 fetch and one for the coalesced V2 re-fetch.
      expect(emittedTitles, containsAllInOrder(['V1', 'V2']));
      // All rapid notifications were coalesced — only two DB calls total.
      expect(callCount, 2);
    });
  });

  group('outbox-failure error logging', () {
    // Lines 367, 506, 517, 544, 555: DomainLogger.error is called when
    // OutboxService.enqueueMessage throws after a committed link write.
    late MockDomainLogger mockDomainLogger;

    setUp(() {
      mockDomainLogger = MockDomainLogger();
      when(
        () => mockDomainLogger.error(
          any<LogDomain>(),
          any<Object>(),
          message: any<String>(named: 'message'),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String>(named: 'subDomain'),
        ),
      ).thenReturn(null);
      reRegister<DomainLogger>(mockDomainLogger);
    });

    test(
      'linkTaskToProject logs DomainLogger.error when outbox enqueue throws',
      () async {
        // Make outbox throw *after* the link row is written.
        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenThrow(StateError('outbox boom'));

        when(
          () => mockDb.getProjectLinkForTask('task-001'),
        ).thenAnswer((_) async => null);
        when(
          mockVectorClockService.getNextVectorClock,
        ).thenAnswer((_) async => const VectorClock({'d': 1}));

        // The operation should still return true — commit-on-write invariant.
        final result = await repository.linkTaskToProject(
          projectId: 'project-001',
          taskId: 'task-001',
        );

        expect(result, isTrue);
        verify(
          () => mockDomainLogger.error(
            LogDomain.sync,
            any<Object>(),
            message: any<String>(
              named: 'message',
              that: contains('outbox enqueue failed after linkTaskToProject'),
            ),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'linkTaskToProject.enqueue',
          ),
        ).called(1);
      },
    );

    test(
      '_relinkTask logs DomainLogger.error when outbox enqueue throws',
      () async {
        final oldLink = EntryLink.project(
          id: 'link-relink',
          fromId: 'project-old',
          toId: 'task-001',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenThrow(StateError('outbox boom during relink'));

        when(
          () => mockDb.getProjectLinkForTask('task-001'),
        ).thenAnswer((_) async => oldLink);
        when(
          mockVectorClockService.getNextVectorClock,
        ).thenAnswer((_) async => const VectorClock({'d': 2}));

        // The relink should succeed (link rows persisted) but log the error.
        final result = await repository.linkTaskToProject(
          projectId: 'project-001',
          taskId: 'task-001',
        );

        expect(result, isTrue);
        verify(
          () => mockDomainLogger.error(
            LogDomain.sync,
            any<Object>(),
            message: any<String>(
              named: 'message',
              that: contains('outbox enqueue failed after _relinkTask'),
            ),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: '_relinkTask.enqueue',
          ),
        ).called(1);
      },
    );

    test(
      'unlinkTaskFromProject logs DomainLogger.error when outbox enqueue throws',
      () async {
        final existingLink = EntryLink.project(
          id: 'link-unlink',
          fromId: 'project-001',
          toId: 'task-001',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenThrow(StateError('outbox boom during unlink'));

        when(
          () => mockDb.getProjectLinkForTask('task-001'),
        ).thenAnswer((_) async => existingLink);
        when(
          mockVectorClockService.getNextVectorClock,
        ).thenAnswer((_) async => const VectorClock({'d': 3}));

        // The unlink should succeed — link row already soft-deleted on disk.
        final result = await repository.unlinkTaskFromProject('task-001');

        expect(result, isTrue);
        verify(
          () => mockDomainLogger.error(
            LogDomain.sync,
            any<Object>(),
            message: any<String>(
              named: 'message',
              that: contains('outbox enqueue failed after _softDeleteLink'),
            ),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: '_softDeleteLink.enqueue',
          ),
        ).called(1);
      },
    );
  });

  group('inheritProjectFromTask', () {
    test('returns false when source task has no project', () async {
      when(
        () => mockDb.getProjectForTask('source-task'),
      ).thenAnswer((_) async => null);

      final result = await repository.inheritProjectFromTask(
        sourceTaskId: 'source-task',
        newTaskId: 'new-task',
      );

      expect(result, isFalse);
      verifyNever(() => mockDb.journalEntityById(any()));
    });

    test('links new task to the source task project when found', () async {
      when(
        () => mockDb.getProjectForTask('source-task'),
      ).thenAnswer((_) async => projectEntry);
      // linkTaskToProject internals
      final newTaskMeta = taskMeta.copyWith(id: 'new-task');
      final newTaskEntry = Task(
        meta: newTaskMeta,
        data: taskEntry.data,
      );
      when(
        () => mockDb.journalEntityById('new-task'),
      ).thenAnswer((_) async => newTaskEntry);
      when(
        () => mockDb.getProjectLinkForTask('new-task'),
      ).thenAnswer((_) async => null);
      when(
        mockVectorClockService.getNextVectorClock,
      ).thenAnswer((_) async => const VectorClock({'d': 5}));

      final result = await repository.inheritProjectFromTask(
        sourceTaskId: 'source-task',
        newTaskId: 'new-task',
      );

      expect(result, isTrue);
      // Verify the new task was linked to project-001.
      final captured =
          verify(() => mockDb.upsertEntryLink(captureAny())).captured.single
              as EntryLink;
      expect(captured.fromId, 'project-001');
      expect(captured.toId, 'new-task');
    });
  });

  group('projectRepositoryProvider', () {
    // Line 593: exercises the Riverpod provider factory that reads all
    // five dependencies from getIt. Rather than a constructor smoke test, we
    // assert the factory actually wires each getIt registration into the
    // repository by exercising methods that route through them.
    test(
      'wires getIt dependencies into the constructed repository',
      () async {
        // Register all five dependencies the factory reads from getIt.
        reRegister<JournalDb>(mockDb);
        reRegister<EntitiesCacheService>(mockEntitiesCacheService);
        reRegister<PersistenceLogic>(mockPersistence);
        reRegister<UpdateNotifications>(mockNotifications);
        reRegister<VectorClockService>(mockVectorClockService);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        final repo = container.read(projectRepositoryProvider);

        // The provider must cache the same instance across reads (keepAlive).
        expect(
          identical(repo, container.read(projectRepositoryProvider)),
          isTrue,
        );

        // The wired JournalDb is reachable: getProjectById routes through it.
        final project = await repo.getProjectById('project-001');
        expect(project?.data.title, 'Test Project');
        verify(() => mockDb.journalEntityById('project-001')).called(1);

        // The wired PersistenceLogic + UpdateNotifications are reachable:
        // updateProject bumps metadata, persists, and notifies.
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

        final updated = await repo.updateProject(projectEntry);
        expect(updated, isTrue);
        verify(
          () => mockNotifications.notify({
            projectEntityUpdateNotification(projectEntry.id),
          }),
        ).called(1);
      },
    );
  });

  group('watchProjectsOverview — cancellation', () {
    test(
      'cancelling the stream disposes the notification subscription: later '
      'notifications trigger no further DB fetches',
      () async {
        var fetches = 0;
        when(() => mockDb.getVisibleProjects()).thenAnswer((_) async {
          fetches++;
          return [
            makeTestProject(
              id: 'project-c1',
              title: 'P',
              categoryId: workCategory.id,
            ),
          ];
        });
        when(() => mockDb.getProjectTaskRollups(any())).thenAnswer(
          (_) async => {},
        );

        final stream = repository.watchProjectsOverview(
          query: const ProjectsQuery(),
        );
        final sub = stream.listen((_) {});
        await pumpEventQueue();
        final fetchesBeforeCancel = fetches;
        expect(fetchesBeforeCancel, greaterThan(0));

        await sub.cancel();

        // A relevant notification after cancel must not re-fetch.
        updateStreamController.add({projectNotification});
        await pumpEventQueue();

        expect(fetches, fetchesBeforeCancel);
      },
    );

    test(
      'cancelling during an in-flight fetch never adds to the closed '
      'controller (isClosed guard)',
      () async {
        final gate = Completer<List<ProjectEntry>>();
        var calls = 0;
        when(() => mockDb.getVisibleProjects()).thenAnswer((_) {
          calls++;
          return gate.future;
        });
        when(() => mockDb.getProjectTaskRollups(any())).thenAnswer(
          (_) async => {},
        );

        final events = <ProjectsOverviewSnapshot>[];
        final sub = repository
            .watchProjectsOverview(query: const ProjectsQuery())
            .listen(events.add);
        await pumpEventQueue();
        expect(calls, 1);

        // Cancel while the initial fetch is still pending, then let the
        // fetch complete — the guard must swallow the late snapshot.
        await sub.cancel();
        gate.complete([
          makeTestProject(
            id: 'project-late',
            title: 'Late',
            categoryId: workCategory.id,
          ),
        ]);
        await pumpEventQueue();

        expect(events, isEmpty);
      },
    );
  });

  group('getProjectsOverview — uncategorized ordering', () {
    test('projects with a null categoryId group last', () async {
      when(() => mockDb.getVisibleProjects()).thenAnswer(
        (_) async => [
          makeTestProject(
            id: 'project-uncat',
            title: 'No category',
          ),
          makeTestProject(
            id: 'project-work',
            title: 'Work project',
            categoryId: workCategory.id,
          ),
        ],
      );
      when(() => mockDb.getProjectTaskRollups(any())).thenAnswer(
        (_) async => {},
      );

      final result = await repository.getProjectsOverview(
        query: const ProjectsQuery(),
      );

      expect(result.groups, hasLength(2));
      expect(result.groups.first.categoryId, workCategory.id);
      expect(result.groups.last.categoryId, isNull);
      expect(
        result.groups.last.projects.single.project.meta.id,
        'project-uncat',
      );
    });
  });

  group('debugProjectsOverviewNeedsRefresh — Glados properties', () {
    ProjectsOverviewSnapshot snapshotWith({
      required List<String> projectIds,
      required String categoryId,
    }) {
      return ProjectsOverviewSnapshot(
        groups: [
          ProjectCategoryGroup(
            categoryId: categoryId,
            category: workCategory,
            projects: [
              for (final id in projectIds)
                ProjectListItemData(
                  project: makeTestProject(
                    id: id,
                    title: id,
                    categoryId: categoryId,
                  ),
                  category: workCategory,
                  taskRollup: const ProjectTaskRollupData(),
                ),
            ],
          ),
        ],
      );
    }

    glados.Glados<int>(
      glados.IntAnys(glados.any).intInRange(0, 1 << 12),
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'broad tokens always refresh; snapshot members (bare or prefixed) '
      'refresh; unknown ids never refresh',
      (seed) {
        final snapshot = snapshotWith(
          projectIds: ['proj-$seed', 'proj-x$seed'],
          categoryId: 'cat-$seed',
        );

        // Any broad token alone triggers a refresh.
        for (final token in [
          projectNotification,
          taskNotification,
          categoriesNotification,
          privateToggleNotification,
        ]) {
          expect(
            repository.debugProjectsOverviewNeedsRefresh({token}, snapshot),
            isTrue,
            reason: token,
          );
        }

        // A member project id refreshes — bare and prefix-wrapped agree.
        expect(
          repository.debugProjectsOverviewNeedsRefresh(
            {'proj-$seed'},
            snapshot,
          ),
          isTrue,
        );
        expect(
          repository.debugProjectsOverviewNeedsRefresh(
            {projectEntityUpdateNotification('proj-$seed')},
            snapshot,
          ),
          isTrue,
        );

        // The snapshot's category id refreshes too.
        expect(
          repository.debugProjectsOverviewNeedsRefresh(
            {'cat-$seed'},
            snapshot,
          ),
          isTrue,
        );

        // Unrecognised ids never refresh.
        expect(
          repository.debugProjectsOverviewNeedsRefresh(
            {'unrelated-$seed', projectEntityUpdateNotification('nope-$seed')},
            snapshot,
          ),
          isFalse,
        );
      },
      tags: 'glados',
    );
  });

  group('resolveAffectedProjectIds — properties', () {
    test(
      'result is the union of direct and task-derived ids, and prefixed ids '
      'normalize to their bare form',
      () async {
        when(() => mockDb.getExistingProjectIds(any())).thenAnswer(
          (invocation) async {
            final ids = invocation.positionalArguments.first as Set<String>;
            return {
              for (final id in ids)
                if (id.startsWith('proj-')) id,
            };
          },
        );
        when(() => mockDb.getProjectIdsForTaskIds(any())).thenAnswer(
          (invocation) async {
            final ids = invocation.positionalArguments.first as Set<String>;
            return {
              for (final id in ids)
                if (id.startsWith('task-')) 'proj-of-$id',
            };
          },
        );

        final bare = await repository.resolveAffectedProjectIds(
          {'proj-1', 'task-2', 'noise'},
        );
        expect(bare, {'proj-1', 'proj-of-task-2'});

        // Prefix-wrapped ids resolve identically to their bare forms.
        final prefixed = await repository.resolveAffectedProjectIds({
          projectEntityUpdateNotification('proj-1'),
          projectEntityUpdateNotification('task-2'),
          'noise',
        });
        expect(prefixed, bare);
      },
    );
  });
}
