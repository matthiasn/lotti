import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/project_tool_dispatcher.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../projects/test_utils.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockProjectRepository mockProjectRepository;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockTaskAgentService mockTaskAgentService;
  late ProjectToolDispatcher dispatcher;

  const projectId = 'project-001';
  const taskId = 'task-001';
  final project = makeTestProject(
    id: projectId,
    categoryId: 'cat-001',
  );

  setUp(() {
    mockProjectRepository = MockProjectRepository();
    mockPersistenceLogic = MockPersistenceLogic();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockTaskAgentService = MockTaskAgentService();

    dispatcher = ProjectToolDispatcher(
      projectRepository: mockProjectRepository,
      persistenceLogic: mockPersistenceLogic,
      entitiesCacheService: mockEntitiesCacheService,
      taskAgentService: mockTaskAgentService,
    );
  });

  group('ProjectToolDispatcher', () {
    test('recommend_next_steps acknowledges non-empty steps', () async {
      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.recommendNextSteps,
        {
          'steps': [
            {'title': 'Ship alpha', 'rationale': 'Unblock beta users'},
          ],
        },
        projectId,
      );

      expect(result.success, isTrue);
      expect(result.output, contains('Accepted 1 recommended next step'));
      expect(result.mutatedEntityId, isNull);
    });

    test(
      'recommend_next_steps rejects steps without valid titles',
      () async {
        final result = await dispatcher.dispatch(
          ProjectAgentToolNames.recommendNextSteps,
          {
            'steps': [
              {'rationale': 'Missing title field'},
              {'title': '', 'rationale': 'Empty title'},
              {'title': '  ', 'rationale': 'Whitespace-only title'},
            ],
          },
          projectId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('no valid recommended steps'));
      },
    );

    test(
      'recommend_next_steps counts only steps with valid titles',
      () async {
        final result = await dispatcher.dispatch(
          ProjectAgentToolNames.recommendNextSteps,
          {
            'steps': [
              {'title': 'Ship alpha', 'rationale': 'Unblock beta users'},
              {'rationale': 'Missing title'},
              {'title': 'Run QA', 'priority': 'HIGH'},
            ],
          },
          projectId,
        );

        expect(result.success, isTrue);
        expect(result.output, contains('Accepted 2 recommended next step'));
      },
    );

    test(
      'update_project_status maps alias to onHold and appends history',
      () async {
        when(
          () => mockProjectRepository.getProjectById(projectId),
        ).thenAnswer((_) async => project);
        when(
          () => mockProjectRepository.updateProject(any()),
        ).thenAnswer((_) async => true);

        final result = await dispatcher.dispatch(
          ProjectAgentToolNames.updateProjectStatus,
          {
            'status': 'at_risk',
            'reason': 'Dependency delayed',
          },
          projectId,
        );

        expect(result.success, isTrue);
        expect(result.mutatedEntityId, projectId);

        verify(
          () => mockProjectRepository.updateProject(
            any(
              that: isA<ProjectEntry>()
                  .having(
                    (entry) => entry.data.status,
                    'status',
                    isA<ProjectOnHold>().having(
                      (status) => status.reason,
                      'reason',
                      'Dependency delayed',
                    ),
                  )
                  .having(
                    (entry) => entry.data.statusHistory.length,
                    'statusHistory.length',
                    1,
                  )
                  .having(
                    (entry) => entry.data.statusHistory.first,
                    'statusHistory.first',
                    isA<ProjectOpen>(),
                  ),
            ),
          ),
        ).called(1);
      },
    );

    test(
      'update_project_status is a no-op when project is already active',
      () async {
        final activeProject = makeTestProject(
          id: projectId,
          categoryId: 'cat-001',
          status: ProjectStatus.active(
            id: 'status-001',
            createdAt: DateTime(2024, 3, 15),
            utcOffset: 0,
          ),
        );

        when(
          () => mockProjectRepository.getProjectById(projectId),
        ).thenAnswer((_) async => activeProject);

        final result = await dispatcher.dispatch(
          ProjectAgentToolNames.updateProjectStatus,
          {'status': 'active'},
          projectId,
        );

        expect(result.success, isTrue);
        expect(result.output, contains('already has status Active'));
        verifyNever(() => mockProjectRepository.updateProject(any()));
      },
    );

    test(
      'update_project_status defaults on-hold reason when omitted',
      () async {
        when(
          () => mockProjectRepository.getProjectById(projectId),
        ).thenAnswer((_) async => project);
        when(
          () => mockProjectRepository.updateProject(any()),
        ).thenAnswer((_) async => true);

        final result = await dispatcher.dispatch(
          ProjectAgentToolNames.updateProjectStatus,
          {'status': 'on_hold', 'reason': '   '},
          projectId,
        );

        expect(result.success, isTrue);

        verify(
          () => mockProjectRepository.updateProject(
            any(
              that: isA<ProjectEntry>().having(
                (entry) => entry.data.status,
                'status',
                isA<ProjectOnHold>().having(
                  (status) => status.reason,
                  'reason',
                  'No reason provided',
                ),
              ),
            ),
          ),
        ).called(1);
      },
    );

    test(
      'update_project_status ignores non-string reason without throwing',
      () async {
        when(
          () => mockProjectRepository.getProjectById(projectId),
        ).thenAnswer((_) async => project);
        when(
          () => mockProjectRepository.updateProject(any()),
        ).thenAnswer((_) async => true);

        final result = await dispatcher.dispatch(
          ProjectAgentToolNames.updateProjectStatus,
          {'status': 'on_hold', 'reason': 42},
          projectId,
        );

        expect(result.success, isTrue);

        verify(
          () => mockProjectRepository.updateProject(
            any(
              that: isA<ProjectEntry>().having(
                (entry) => entry.data.status,
                'status',
                isA<ProjectOnHold>().having(
                  (status) => status.reason,
                  'reason',
                  'No reason provided',
                ),
              ),
            ),
          ),
        ).called(1);
      },
    );

    test('create_task creates, links, and auto-assigns a task agent', () async {
      final createdTask = makeTestTask(id: taskId, title: 'Write docs');
      final category = CategoryDefinition(
        id: 'cat-001',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        name: 'Platform',
        vectorClock: null,
        private: false,
        active: true,
        defaultProfileId: 'profile-001',
        defaultTemplateId: 'template-001',
      );

      when(
        () => mockProjectRepository.getProjectById(projectId),
      ).thenAnswer((_) async => project);
      when(
        () => mockEntitiesCacheService.getCategoryById('cat-001'),
      ).thenReturn(category);
      when(
        () => mockPersistenceLogic.createTaskEntry(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => createdTask);
      when(
        () => mockProjectRepository.linkTaskToProject(
          projectId: projectId,
          taskId: taskId,
        ),
      ).thenAnswer((_) async => true);
      when(
        () => mockTaskAgentService.createTaskAgent(
          taskId: taskId,
          templateId: 'template-001',
          profileId: 'profile-001',
          allowedCategoryIds: {'cat-001'},
        ),
      ).thenAnswer((_) async => makeTestIdentity());

      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.createTask,
        {
          'title': 'Write docs',
          'description': 'Document the rollout',
          'priority': 'HIGH',
        },
        projectId,
      );

      expect(result.success, isTrue);
      expect(result.mutatedEntityId, taskId);

      verify(
        () => mockPersistenceLogic.createTaskEntry(
          data: any(
            named: 'data',
            that: isA<TaskData>()
                .having((data) => data.title, 'title', 'Write docs')
                .having(
                  (data) => data.priority,
                  'priority',
                  TaskPriority.p1High,
                )
                .having(
                  (data) => data.profileId,
                  'profileId',
                  'profile-001',
                ),
          ),
          entryText: any(named: 'entryText'),
          categoryId: 'cat-001',
        ),
      ).called(1);
      verify(
        () => mockProjectRepository.linkTaskToProject(
          projectId: projectId,
          taskId: taskId,
        ),
      ).called(1);
      verify(
        () => mockTaskAgentService.createTaskAgent(
          taskId: taskId,
          templateId: 'template-001',
          profileId: 'profile-001',
          allowedCategoryIds: {'cat-001'},
          awaitContent: true,
        ),
      ).called(1);
    });

    test(
      'create_task rolls back the created task when project linking fails',
      () async {
        final createdTask = makeTestTask(id: taskId, title: 'Write docs');
        final category = CategoryDefinition(
          id: 'cat-001',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          name: 'Platform',
          vectorClock: null,
          private: false,
          active: true,
          defaultProfileId: 'profile-001',
          defaultTemplateId: 'template-001',
        );
        final deletedTask = createdTask.copyWith(
          meta: createdTask.meta.copyWith(
            deletedAt: DateTime(2024, 3, 16),
          ),
        );

        when(
          () => mockProjectRepository.getProjectById(projectId),
        ).thenAnswer((_) async => project);
        when(
          () => mockEntitiesCacheService.getCategoryById('cat-001'),
        ).thenReturn(category);
        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => createdTask);
        when(
          () => mockProjectRepository.linkTaskToProject(
            projectId: projectId,
            taskId: taskId,
          ),
        ).thenAnswer((_) async => false);
        when(
          () => mockPersistenceLogic.updateMetadata(
            createdTask.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer((_) async => deletedTask.meta);
        when(
          () => mockPersistenceLogic.updateDbEntity(any()),
        ).thenAnswer((_) async => true);

        final result = await dispatcher.dispatch(
          ProjectAgentToolNames.createTask,
          {
            'title': 'Write docs',
            'description': 'Document the rollout',
          },
          projectId,
        );

        expect(result.success, isFalse);
        expect(
          result.output,
          contains('Rolled back the created task'),
        );
        expect(
          result.errorMessage,
          contains('Failed to link the new task to the project'),
        );

        verify(
          () => mockPersistenceLogic.updateDbEntity(
            any(
              that: isA<Task>().having(
                (task) => task.meta.deletedAt,
                'deletedAt',
                isNotNull,
              ),
            ),
          ),
        ).called(1);
        verifyNever(
          () => mockTaskAgentService.createTaskAgent(
            taskId: any(named: 'taskId'),
            templateId: any(named: 'templateId'),
            profileId: any(named: 'profileId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            awaitContent: any(named: 'awaitContent'),
          ),
        );
      },
    );

    test(
      'create_task returns warning when task-agent auto-assignment fails',
      () async {
        final createdTask = makeTestTask(id: taskId, title: 'Write docs');
        final category = CategoryDefinition(
          id: 'cat-001',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          name: 'Platform',
          vectorClock: null,
          private: false,
          active: true,
          defaultProfileId: 'profile-001',
          defaultTemplateId: 'template-001',
        );

        when(
          () => mockProjectRepository.getProjectById(projectId),
        ).thenAnswer((_) async => project);
        when(
          () => mockEntitiesCacheService.getCategoryById('cat-001'),
        ).thenReturn(category);
        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => createdTask);
        when(
          () => mockProjectRepository.linkTaskToProject(
            projectId: projectId,
            taskId: taskId,
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockTaskAgentService.createTaskAgent(
            taskId: taskId,
            templateId: 'template-001',
            profileId: 'profile-001',
            allowedCategoryIds: {'cat-001'},
            awaitContent: true,
          ),
        ).thenThrow(Exception('template failure'));

        final result = await dispatcher.dispatch(
          ProjectAgentToolNames.createTask,
          {'title': 'Write docs'},
          projectId,
        );

        expect(result.success, isTrue);
        expect(
          result.errorMessage,
          contains('failed to auto-assign a task agent'),
        );
        expect(
          result.output,
          contains('Warning: failed to auto-assign a task agent'),
        );
      },
    );

    test('create_task rejects unknown priority values', () async {
      when(
        () => mockProjectRepository.getProjectById(projectId),
      ).thenAnswer((_) async => project);

      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.createTask,
        {
          'title': 'Write docs',
          'priority': 'ASAP',
        },
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Invalid priority');
      verifyNever(
        () => mockPersistenceLogic.createTaskEntry(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
        ),
      );
    });

    test('dispatch returns error for unknown tool name', () async {
      final result = await dispatcher.dispatch(
        'nonexistent_tool',
        <String, dynamic>{},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.output, contains('Unknown tool: nonexistent_tool'));
      expect(
        result.errorMessage,
        contains('not registered for the Project Agent'),
      );
    });

    test('recommend_next_steps rejects non-list steps', () async {
      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.recommendNextSteps,
        {'steps': 'not a list'},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.output, contains('"steps" must be a non-empty array'));
    });

    test('recommend_next_steps rejects empty steps list', () async {
      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.recommendNextSteps,
        {'steps': <Map<String, dynamic>>[]},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.output, contains('"steps" must be a non-empty array'));
    });

    test('update_project_status rejects non-string status', () async {
      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.updateProjectStatus,
        {'status': 42},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.output, contains('"status" must be a non-empty string'));
    });

    test('update_project_status rejects empty status', () async {
      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.updateProjectStatus,
        {'status': '  '},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.output, contains('"status" must be a non-empty string'));
    });

    test('update_project_status fails when project not found', () async {
      when(
        () => mockProjectRepository.getProjectById(projectId),
      ).thenAnswer((_) async => null);

      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.updateProjectStatus,
        {'status': 'active'},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.output, contains('Project $projectId not found'));
    });

    test('update_project_status rejects unsupported status value', () async {
      when(
        () => mockProjectRepository.getProjectById(projectId),
      ).thenAnswer((_) async => project);

      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.updateProjectStatus,
        {'status': 'galaxy_brain'},
        projectId,
      );

      expect(result.success, isFalse);
      expect(
        result.output,
        contains('unsupported project status "galaxy_brain"'),
      );
    });

    test('update_project_status fails when repository update fails', () async {
      when(
        () => mockProjectRepository.getProjectById(projectId),
      ).thenAnswer((_) async => project);
      when(
        () => mockProjectRepository.updateProject(any()),
      ).thenAnswer((_) async => false);

      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.updateProjectStatus,
        {'status': 'active'},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.output, contains('failed to update project status'));
    });

    for (final entry in {
      'active': ProjectActive,
      'in_progress': ProjectActive,
      'on_track': ProjectActive,
      'completed': ProjectCompleted,
      'complete': ProjectCompleted,
      'done': ProjectCompleted,
      'archived': ProjectArchived,
      'archive': ProjectArchived,
      'cancelled': ProjectArchived,
      'canceled': ProjectArchived,
    }.entries) {
      test(
        'update_project_status parses "${entry.key}" alias correctly',
        () async {
          when(
            () => mockProjectRepository.getProjectById(projectId),
          ).thenAnswer((_) async => project);
          when(
            () => mockProjectRepository.updateProject(any()),
          ).thenAnswer((_) async => true);

          final result = await dispatcher.dispatch(
            ProjectAgentToolNames.updateProjectStatus,
            {'status': entry.key},
            projectId,
          );

          expect(result.success, isTrue);
          expect(result.mutatedEntityId, projectId);

          final captured = verify(
            () => mockProjectRepository.updateProject(captureAny()),
          ).captured;
          final updated = captured.first as ProjectEntry;
          expect(
            updated.data.status,
            isA<Object>().having(
              (s) => s.runtimeType,
              'runtimeType',
              entry.value,
            ),
          );
        },
      );
    }

    test(
      'update_project_status is a no-op when project is already completed',
      () async {
        final completedProject = makeTestProject(
          id: projectId,
          categoryId: 'cat-001',
          status: ProjectStatus.completed(
            id: 'status-c',
            createdAt: DateTime(2024, 3, 15),
            utcOffset: 0,
          ),
        );

        when(
          () => mockProjectRepository.getProjectById(projectId),
        ).thenAnswer((_) async => completedProject);

        final result = await dispatcher.dispatch(
          ProjectAgentToolNames.updateProjectStatus,
          {'status': 'completed'},
          projectId,
        );

        expect(result.success, isTrue);
        expect(result.output, contains('already has status Completed'));
        verifyNever(() => mockProjectRepository.updateProject(any()));
      },
    );

    test(
      'update_project_status is a no-op when project is already archived',
      () async {
        final archivedProject = makeTestProject(
          id: projectId,
          categoryId: 'cat-001',
          status: ProjectStatus.archived(
            id: 'status-a',
            createdAt: DateTime(2024, 3, 15),
            utcOffset: 0,
          ),
        );

        when(
          () => mockProjectRepository.getProjectById(projectId),
        ).thenAnswer((_) async => archivedProject);

        final result = await dispatcher.dispatch(
          ProjectAgentToolNames.updateProjectStatus,
          {'status': 'archived'},
          projectId,
        );

        expect(result.success, isTrue);
        expect(result.output, contains('already has status Archived'));
        verifyNever(() => mockProjectRepository.updateProject(any()));
      },
    );

    test(
      'update_project_status is a no-op when on_hold with same reason',
      () async {
        final onHoldProject = makeTestProject(
          id: projectId,
          categoryId: 'cat-001',
          status: ProjectStatus.onHold(
            id: 'status-h',
            createdAt: DateTime(2024, 3, 15),
            utcOffset: 0,
            reason: 'Waiting on vendor',
          ),
        );

        when(
          () => mockProjectRepository.getProjectById(projectId),
        ).thenAnswer((_) async => onHoldProject);

        final result = await dispatcher.dispatch(
          ProjectAgentToolNames.updateProjectStatus,
          {'status': 'on_hold', 'reason': 'Waiting on vendor'},
          projectId,
        );

        expect(result.success, isTrue);
        expect(result.output, contains('already has status On Hold'));
        verifyNever(() => mockProjectRepository.updateProject(any()));
      },
    );

    test(
      'update_project_status changes on_hold when reason differs',
      () async {
        final onHoldProject = makeTestProject(
          id: projectId,
          categoryId: 'cat-001',
          status: ProjectStatus.onHold(
            id: 'status-h',
            createdAt: DateTime(2024, 3, 15),
            utcOffset: 0,
            reason: 'Old reason',
          ),
        );

        when(
          () => mockProjectRepository.getProjectById(projectId),
        ).thenAnswer((_) async => onHoldProject);
        when(
          () => mockProjectRepository.updateProject(any()),
        ).thenAnswer((_) async => true);

        final result = await dispatcher.dispatch(
          ProjectAgentToolNames.updateProjectStatus,
          {'status': 'on_hold', 'reason': 'New reason'},
          projectId,
        );

        expect(result.success, isTrue);
        expect(result.mutatedEntityId, projectId);
        verify(() => mockProjectRepository.updateProject(any())).called(1);
      },
    );

    test('create_task rejects non-string title', () async {
      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.createTask,
        {'title': 123},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.output, contains('"title" must be a non-empty string'));
    });

    test('create_task rejects empty title', () async {
      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.createTask,
        {'title': '   '},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.output, contains('"title" must be a non-empty string'));
    });

    test('create_task fails when project not found', () async {
      when(
        () => mockProjectRepository.getProjectById(projectId),
      ).thenAnswer((_) async => null);

      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.createTask,
        {'title': 'Write docs'},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.output, contains('Project $projectId not found'));
    });

    test('create_task fails when createTaskEntry returns null', () async {
      when(
        () => mockProjectRepository.getProjectById(projectId),
      ).thenAnswer((_) async => project);
      when(
        () => mockEntitiesCacheService.getCategoryById('cat-001'),
      ).thenReturn(null);
      when(
        () => mockPersistenceLogic.createTaskEntry(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => null);

      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.createTask,
        {'title': 'Write docs'},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.output, contains('failed to create task'));
    });

    test(
      'create_task reports rollback failure when link and rollback both fail',
      () async {
        final createdTask = makeTestTask(id: taskId, title: 'Write docs');

        when(
          () => mockProjectRepository.getProjectById(projectId),
        ).thenAnswer((_) async => project);
        when(
          () => mockEntitiesCacheService.getCategoryById('cat-001'),
        ).thenReturn(null);
        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => createdTask);
        when(
          () => mockProjectRepository.linkTaskToProject(
            projectId: projectId,
            taskId: taskId,
          ),
        ).thenAnswer((_) async => false);
        when(
          () => mockPersistenceLogic.updateMetadata(
            createdTask.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenThrow(Exception('db error'));

        final result = await dispatcher.dispatch(
          ProjectAgentToolNames.createTask,
          {'title': 'Write docs'},
          projectId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('Rollback failed'));
        expect(result.output, contains('manual cleanup may be required'));
        expect(result.errorMessage, contains('rollback failed'));
      },
    );

    test(
      'create_task skips auto-assign when taskAgentService is null',
      () async {
        final noAgentDispatcher = ProjectToolDispatcher(
          projectRepository: mockProjectRepository,
          persistenceLogic: mockPersistenceLogic,
          entitiesCacheService: mockEntitiesCacheService,
        );
        final createdTask = makeTestTask(id: taskId, title: 'Write docs');

        when(
          () => mockProjectRepository.getProjectById(projectId),
        ).thenAnswer((_) async => project);
        when(
          () => mockEntitiesCacheService.getCategoryById('cat-001'),
        ).thenReturn(null);
        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => createdTask);
        when(
          () => mockProjectRepository.linkTaskToProject(
            projectId: projectId,
            taskId: taskId,
          ),
        ).thenAnswer((_) async => true);

        final result = await noAgentDispatcher.dispatch(
          ProjectAgentToolNames.createTask,
          {'title': 'Write docs'},
          projectId,
        );

        expect(result.success, isTrue);
        expect(result.errorMessage, isNull);
        verifyNever(
          () => mockTaskAgentService.createTaskAgent(
            taskId: any(named: 'taskId'),
            templateId: any(named: 'templateId'),
            profileId: any(named: 'profileId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            awaitContent: any(named: 'awaitContent'),
          ),
        );
      },
    );

    test(
      'create_task skips auto-assign when category has no templateId',
      () async {
        final createdTask = makeTestTask(id: taskId, title: 'Write docs');
        final categoryWithoutTemplate = CategoryDefinition(
          id: 'cat-001',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          name: 'Platform',
          vectorClock: null,
          private: false,
          active: true,
        );

        when(
          () => mockProjectRepository.getProjectById(projectId),
        ).thenAnswer((_) async => project);
        when(
          () => mockEntitiesCacheService.getCategoryById('cat-001'),
        ).thenReturn(categoryWithoutTemplate);
        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => createdTask);
        when(
          () => mockProjectRepository.linkTaskToProject(
            projectId: projectId,
            taskId: taskId,
          ),
        ).thenAnswer((_) async => true);

        final result = await dispatcher.dispatch(
          ProjectAgentToolNames.createTask,
          {'title': 'Write docs'},
          projectId,
        );

        expect(result.success, isTrue);
        expect(result.errorMessage, isNull);
        verifyNever(
          () => mockTaskAgentService.createTaskAgent(
            taskId: any(named: 'taskId'),
            templateId: any(named: 'templateId'),
            profileId: any(named: 'profileId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            awaitContent: any(named: 'awaitContent'),
          ),
        );
      },
    );

    test('create_task uses default MEDIUM priority when omitted', () async {
      final createdTask = makeTestTask(id: taskId, title: 'No priority');

      when(
        () => mockProjectRepository.getProjectById(projectId),
      ).thenAnswer((_) async => project);
      when(
        () => mockEntitiesCacheService.getCategoryById('cat-001'),
      ).thenReturn(null);
      when(
        () => mockPersistenceLogic.createTaskEntry(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => createdTask);
      when(
        () => mockProjectRepository.linkTaskToProject(
          projectId: projectId,
          taskId: taskId,
        ),
      ).thenAnswer((_) async => true);

      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.createTask,
        {'title': 'No priority'},
        projectId,
      );

      expect(result.success, isTrue);

      verify(
        () => mockPersistenceLogic.createTaskEntry(
          data: any(
            named: 'data',
            that: isA<TaskData>().having(
              (data) => data.priority,
              'priority',
              TaskPriority.p2Medium,
            ),
          ),
          entryText: any(named: 'entryText'),
          categoryId: 'cat-001',
        ),
      ).called(1);
    });

    for (final entry in {
      'CRITICAL': TaskPriority.p0Urgent,
      'P0': TaskPriority.p0Urgent,
      'HIGH': TaskPriority.p1High,
      'P1': TaskPriority.p1High,
      'MEDIUM': TaskPriority.p2Medium,
      'P2': TaskPriority.p2Medium,
      'LOW': TaskPriority.p3Low,
      'P3': TaskPriority.p3Low,
    }.entries) {
      test(
        'create_task parses priority "${entry.key}" correctly',
        () async {
          final createdTask = makeTestTask(id: taskId, title: 'Prioritized');

          when(
            () => mockProjectRepository.getProjectById(projectId),
          ).thenAnswer((_) async => project);
          when(
            () => mockEntitiesCacheService.getCategoryById('cat-001'),
          ).thenReturn(null);
          when(
            () => mockPersistenceLogic.createTaskEntry(
              data: any(named: 'data'),
              entryText: any(named: 'entryText'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer((_) async => createdTask);
          when(
            () => mockProjectRepository.linkTaskToProject(
              projectId: projectId,
              taskId: taskId,
            ),
          ).thenAnswer((_) async => true);

          final result = await dispatcher.dispatch(
            ProjectAgentToolNames.createTask,
            {'title': 'Prioritized', 'priority': entry.key},
            projectId,
          );

          expect(result.success, isTrue);

          verify(
            () => mockPersistenceLogic.createTaskEntry(
              data: any(
                named: 'data',
                that: isA<TaskData>().having(
                  (data) => data.priority,
                  'priority',
                  entry.value,
                ),
              ),
              entryText: any(named: 'entryText'),
              categoryId: 'cat-001',
            ),
          ).called(1);
        },
      );
    }

    test(
      'create_task rollback returns false when updateDbEntity returns false',
      () async {
        final createdTask = makeTestTask(id: taskId, title: 'Write docs');
        final deletedTask = createdTask.copyWith(
          meta: createdTask.meta.copyWith(
            deletedAt: DateTime(2024, 3, 16),
          ),
        );

        when(
          () => mockProjectRepository.getProjectById(projectId),
        ).thenAnswer((_) async => project);
        when(
          () => mockEntitiesCacheService.getCategoryById('cat-001'),
        ).thenReturn(null);
        when(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => createdTask);
        when(
          () => mockProjectRepository.linkTaskToProject(
            projectId: projectId,
            taskId: taskId,
          ),
        ).thenAnswer((_) async => false);
        when(
          () => mockPersistenceLogic.updateMetadata(
            createdTask.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer((_) async => deletedTask.meta);
        when(
          () => mockPersistenceLogic.updateDbEntity(any()),
        ).thenAnswer((_) async => false);

        final result = await dispatcher.dispatch(
          ProjectAgentToolNames.createTask,
          {'title': 'Write docs'},
          projectId,
        );

        expect(result.success, isFalse);
        expect(result.output, contains('Rollback failed'));
        expect(result.output, contains('manual cleanup may be required'));
      },
    );
  });
}
