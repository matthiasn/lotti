import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  final testDate = DateTime(2024, 3, 15, 10, 30);

  late MockJournalDb mockDb;
  late MockPersistenceLogic mockPersistence;
  late MockUpdateNotifications mockNotifications;
  late MockVectorClockService mockVectorClockService;
  late MockOutboxService mockOutboxService;
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

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    mockDb = MockJournalDb();
    mockPersistence = MockPersistenceLogic();
    mockNotifications = MockUpdateNotifications();
    mockVectorClockService = MockVectorClockService();
    mockOutboxService = MockOutboxService();

    // Register OutboxService in GetIt (used by _enqueueLinkSync)
    await getIt.reset();
    getIt.registerSingleton<OutboxService>(mockOutboxService);
    when(
      () => mockOutboxService.enqueueMessage(any()),
    ).thenAnswer((_) async {});

    repository = ProjectRepository(
      journalDb: mockDb,
      persistenceLogic: mockPersistence,
      updateNotifications: mockNotifications,
      vectorClockService: mockVectorClockService,
    );
  });

  tearDown(() async {
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
    });
  });

  group('linkTaskToProject', () {
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
      'soft-deletes old link when moving task to different project',
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
        // Should have called upsertEntryLink twice: once for soft-delete,
        // once for new link
        verify(() => mockDb.upsertEntryLink(any())).called(2);
        // Verify sync was enqueued for both operations
        verify(() => mockOutboxService.enqueueMessage(any())).called(2);
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

      final result = await repository.unlinkTaskFromProject('task-001');

      expect(result, isTrue);
      final captured =
          verify(() => mockDb.upsertEntryLink(captureAny())).captured.single
              as EntryLink;
      expect(captured.deletedAt, isNotNull);
      expect(captured.hidden, isTrue);
      // Verify sync was enqueued
      verify(() => mockOutboxService.enqueueMessage(any())).called(1);
    });
  });
}
