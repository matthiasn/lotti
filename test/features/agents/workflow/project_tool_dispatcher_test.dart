import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/project_tool_dispatcher.dart';
import 'package:lotti/services/domain_logging.dart';
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
        final domainLogger = MockDomainLogger();
        final loggingDispatcher = ProjectToolDispatcher(
          projectRepository: mockProjectRepository,
          persistenceLogic: mockPersistenceLogic,
          entitiesCacheService: mockEntitiesCacheService,
          taskAgentService: mockTaskAgentService,
          domainLogger: domainLogger,
        );
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
        when(
          () => domainLogger.error(
            any(),
            any(),
            message: any(named: 'message'),
            stackTrace: any(named: 'stackTrace'),
            subDomain: any(named: 'subDomain'),
          ),
        ).thenReturn(null);

        final result = await loggingDispatcher.dispatch(
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
        final captured = verify(
          () => domainLogger.error(
            LogDomain.agentWorkflow,
            any(),
            message: captureAny(named: 'message'),
            stackTrace: any(named: 'stackTrace'),
            subDomain: any(named: 'subDomain'),
          ),
        ).captured;
        final message = captured.single as String;
        expect(message, contains('[id:task-0]'));
        expect(message, isNot(contains(taskId)));
      },
    );

    test('create_task rejects non-string priority', () async {
      when(
        () => mockProjectRepository.getProjectById(projectId),
      ).thenAnswer((_) async => project);

      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.createTask,
        {'title': 'Write docs', 'priority': 42},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Invalid priority');
    });

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

    test('create_task accepts additional priority aliases', () async {
      final createdTask = makeTestTask(id: taskId, title: 'Write docs');
      final capturedPriorities = <TaskPriority>[];

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
      ).thenAnswer((invocation) async {
        capturedPriorities.add(
          (invocation.namedArguments[#data]! as TaskData).priority,
        );
        return createdTask;
      });
      when(
        () => mockProjectRepository.linkTaskToProject(
          projectId: projectId,
          taskId: taskId,
        ),
      ).thenAnswer((_) async => true);

      final cases = <String, TaskPriority>{
        'P0': TaskPriority.p0Urgent,
        'P2': TaskPriority.p2Medium,
        'P3': TaskPriority.p3Low,
      };

      for (final entry in cases.entries) {
        final result = await dispatcher.dispatch(
          ProjectAgentToolNames.createTask,
          {
            'title': 'Write docs',
            'priority': entry.key,
          },
          projectId,
        );
        expect(result.success, isTrue);
      }

      expect(capturedPriorities, cases.values.toList());
    });

    test('dispatch returns error for unknown tool name', () async {
      final result = await dispatcher.dispatch(
        'nonexistent_tool',
        <String, dynamic>{},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.output, contains('Unknown tool: nonexistent_tool'));
      expect(result.errorMessage, contains('not registered'));
    });

    test('recommend_next_steps rejects non-list steps', () async {
      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.recommendNextSteps,
        {'steps': 'not a list'},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Type validation failed for steps');
    });

    test('recommend_next_steps rejects empty steps list', () async {
      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.recommendNextSteps,
        {'steps': <dynamic>[]},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Type validation failed for steps');
    });

    test('update_project_status rejects non-string status', () async {
      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.updateProjectStatus,
        {'status': 42},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Type validation failed for status');
    });

    test('update_project_status rejects empty string status', () async {
      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.updateProjectStatus,
        {'status': '   '},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Type validation failed for status');
    });

    test(
      'update_project_status returns failure when project not found',
      () async {
        when(
          () => mockProjectRepository.getProjectById(projectId),
        ).thenAnswer((_) async => null);

        final result = await dispatcher.dispatch(
          ProjectAgentToolNames.updateProjectStatus,
          {'status': 'active'},
          projectId,
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, 'Project lookup failed');
      },
    );

    test('update_project_status rejects unrecognised status string', () async {
      when(
        () => mockProjectRepository.getProjectById(projectId),
      ).thenAnswer((_) async => project);

      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.updateProjectStatus,
        {'status': 'nonsense'},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Invalid project status');
      expect(result.output, contains('unsupported project status'));
    });

    test('update_project_status accepts additional status aliases', () async {
      final capturedStatuses = <ProjectStatus>[];

      when(
        () => mockProjectRepository.getProjectById(projectId),
      ).thenAnswer((_) async => project);
      when(
        () => mockProjectRepository.updateProject(any()),
      ).thenAnswer((invocation) async {
        capturedStatuses.add(
          (invocation.positionalArguments.single as ProjectEntry).data.status,
        );
        return true;
      });

      final cases = <String, Type>{
        'done': ProjectCompleted,
        'canceled': ProjectArchived,
      };

      for (final entry in cases.entries) {
        final result = await dispatcher.dispatch(
          ProjectAgentToolNames.updateProjectStatus,
          {'status': entry.key},
          projectId,
        );
        expect(result.success, isTrue);
      }

      expect(capturedStatuses, hasLength(2));
      expect(capturedStatuses[0], isA<ProjectCompleted>());
      expect(capturedStatuses[1], isA<ProjectArchived>());
    });

    test('update_project_status returns failure when update fails', () async {
      when(
        () => mockProjectRepository.getProjectById(projectId),
      ).thenAnswer((_) async => project);
      when(
        () => mockProjectRepository.updateProject(any()),
      ).thenAnswer((_) async => false);

      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.updateProjectStatus,
        {'status': 'completed'},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Project update failed');
    });

    test('create_task rejects missing title', () async {
      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.createTask,
        <String, dynamic>{},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Missing or empty title');
    });

    test('create_task rejects empty title', () async {
      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.createTask,
        {'title': '   '},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Missing or empty title');
    });

    test('create_task returns failure when project not found', () async {
      when(
        () => mockProjectRepository.getProjectById(projectId),
      ).thenAnswer((_) async => null);

      final result = await dispatcher.dispatch(
        ProjectAgentToolNames.createTask,
        {'title': 'Write docs'},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Project lookup failed');
    });

    test(
      'create_task returns failure when createTaskEntry returns null',
      () async {
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
        expect(result.errorMessage, 'Task creation failed');
      },
    );

    test('create_task reports rollback failure when rollback throws', () async {
      final createdTask = makeTestTask(id: taskId, title: 'Write docs');
      final domainLogger = MockDomainLogger();
      final loggingDispatcher = ProjectToolDispatcher(
        projectRepository: mockProjectRepository,
        persistenceLogic: mockPersistenceLogic,
        entitiesCacheService: mockEntitiesCacheService,
        taskAgentService: mockTaskAgentService,
        domainLogger: domainLogger,
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
          any(),
          deletedAt: any(named: 'deletedAt'),
        ),
      ).thenThrow(Exception('DB write failed'));
      when(
        () => domainLogger.error(
          any(),
          any(),
          message: any(named: 'message'),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenReturn(null);

      final result = await loggingDispatcher.dispatch(
        ProjectAgentToolNames.createTask,
        {'title': 'Write docs'},
        projectId,
      );

      expect(result.success, isFalse);
      expect(result.output, contains('Rollback failed'));
      expect(result.errorMessage, contains('rollback failed'));
      final captured = verify(
        () => domainLogger.error(
          LogDomain.agentWorkflow,
          any(),
          message: captureAny(named: 'message'),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).captured;
      final message = captured.single as String;
      expect(message, contains('[id:task-0]'));
      expect(message, isNot(contains(taskId)));
    });

    test('create_task skips auto-assign when no taskAgentService', () async {
      final noServiceDispatcher = ProjectToolDispatcher(
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

      final result = await noServiceDispatcher.dispatch(
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
    });

    test(
      'create_task skips auto-assign when category has no template',
      () async {
        final createdTask = makeTestTask(id: taskId, title: 'Write docs');
        final noTemplateCategory = CategoryDefinition(
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
        ).thenReturn(noTemplateCategory);
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

    test(
      'create_task skips auto-assign when the project has no category',
      () async {
        final uncategorizedProject = makeTestProject(
          id: projectId,
        );
        final createdTask = makeTestTask(id: taskId, title: 'Write docs');

        when(
          () => mockProjectRepository.getProjectById(projectId),
        ).thenAnswer((_) async => uncategorizedProject);
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
        verify(() => mockEntitiesCacheService.getCategoryById(null)).called(1);
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
      'create_task skips auto-assign when category lookup returns null',
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
  });

  group('parseProjectStatus / isSameSemanticStatus properties', () {
    glados.Glados(
      glados.any.projectStatusScenario,
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'every alias parses to its group and semantic equality follows groups',
      (scenario) {
        final now = DateTime(2026, 3, 15, 10);

        final parsed = ProjectToolDispatcher.parseProjectStatus(
          scenario.styledAlias,
          reason: scenario.reason,
          now: now,
        );
        expect(parsed, isNotNull, reason: scenario.styledAlias);
        expect(
          parsed!.runtimeType,
          scenario.expectedType,
          reason: scenario.styledAlias,
        );

        // On-hold normalizes blank reasons to the fallback string.
        if (parsed is ProjectOnHold) {
          final reason = scenario.reason;
          expect(
            parsed.reason,
            (reason == null || reason.trim().isEmpty)
                ? 'No reason provided'
                : reason.trim(),
          );
        }

        // Same group (and same normalized reason) -> semantically equal.
        final sameGroup = ProjectToolDispatcher.parseProjectStatus(
          scenario.sameGroupAlias,
          reason: scenario.reason,
          now: now.add(const Duration(minutes: 5)),
        );
        expect(
          ProjectToolDispatcher.isSameSemanticStatus(parsed, sameGroup!),
          isTrue,
          reason: '${scenario.styledAlias} vs ${scenario.sameGroupAlias}',
        );

        // Different group -> never semantically equal.
        final otherGroup = ProjectToolDispatcher.parseProjectStatus(
          scenario.otherGroupAlias,
          reason: scenario.reason,
          now: now,
        );
        expect(
          ProjectToolDispatcher.isSameSemanticStatus(parsed, otherGroup!),
          isFalse,
          reason: '${scenario.styledAlias} vs ${scenario.otherGroupAlias}',
        );
      },
      tags: 'glados',
    );

    test('unknown status strings parse to null', () {
      for (final raw in ['', 'bogus', 'reopened', 'in flight']) {
        expect(
          ProjectToolDispatcher.parseProjectStatus(
            raw,
            reason: null,
            now: DateTime(2026, 3, 15),
          ),
          isNull,
          reason: raw,
        );
      }
    });
  });

  group('parseTaskPriority', () {
    test('maps every alias case-insensitively and defaults null to P2', () {
      const expected = {
        'CRITICAL': TaskPriority.p0Urgent,
        'P0': TaskPriority.p0Urgent,
        'HIGH': TaskPriority.p1High,
        'P1': TaskPriority.p1High,
        'MEDIUM': TaskPriority.p2Medium,
        'P2': TaskPriority.p2Medium,
        'LOW': TaskPriority.p3Low,
        'P3': TaskPriority.p3Low,
      };
      for (final entry in expected.entries) {
        expect(
          ProjectToolDispatcher.parseTaskPriority(entry.key),
          entry.value,
          reason: entry.key,
        );
        expect(
          ProjectToolDispatcher.parseTaskPriority(
            ' ${entry.key.toLowerCase()} ',
          ),
          entry.value,
          reason: 'lowercase ${entry.key}',
        );
      }

      // Absent priority defaults to medium; junk is rejected.
      expect(
        ProjectToolDispatcher.parseTaskPriority(null),
        TaskPriority.p2Medium,
      );
      expect(ProjectToolDispatcher.parseTaskPriority('P9'), isNull);
      expect(ProjectToolDispatcher.parseTaskPriority(42), isNull);
    });
  });
}

/// Alias groups accepted by [ProjectToolDispatcher.parseProjectStatus]:
/// (canonical alias, all accepted aliases) per semantic status group.
const _statusAliasGroups = <(String, List<String>)>[
  ('open', ['open']),
  ('active', ['active', 'on_track', 'in_progress']),
  ('monitoring', ['monitoring', 'monitor']),
  ('on_hold', ['on_hold', 'hold', 'blocked', 'at_risk']),
  ('completed', ['completed', 'complete', 'done']),
  ('archived', ['archived', 'archive', 'cancelled', 'canceled']),
];

/// Deterministic scenario: an alias styled with seed-driven casing,
/// separators and padding, plus a same-group and other-group alias.
class _ProjectStatusScenario {
  _ProjectStatusScenario(int groupIndex, int seed) {
    final (canonical, aliases) =
        _statusAliasGroups[groupIndex % _statusAliasGroups.length];
    // The freezed union cases have private concrete types; resolve the
    // expected runtimeType by parsing the canonical alias once.
    expectedType = ProjectToolDispatcher.parseProjectStatus(
      canonical,
      reason: 'r',
      now: DateTime(2026),
    )!.runtimeType;
    final alias = aliases[seed % aliases.length];
    sameGroupAlias = aliases[(seed + 1) % aliases.length];
    final (_, otherAliases) =
        _statusAliasGroups[(groupIndex +
                1 +
                seed % (_statusAliasGroups.length - 1)) %
            _statusAliasGroups.length];
    otherGroupAlias = otherAliases[seed % otherAliases.length];

    // Style: vary the separator ('_' / '-' / ' '), casing and padding —
    // all of which parseProjectStatus normalizes away.
    final separator = ['_', '-', ' '][seed % 3];
    var styled = alias.replaceAll('_', separator);
    styled = switch (seed % 3) {
      0 => styled.toUpperCase(),
      1 => styled[0].toUpperCase() + styled.substring(1),
      _ => styled,
    };
    styledAlias = '${' ' * (seed % 2)}$styled${' ' * ((seed ~/ 2) % 2)}';

    reason = switch (seed % 4) {
      0 => null,
      1 => '',
      2 => '   ',
      _ => '  needs review $seed  ',
    };
  }

  late final Type expectedType;
  late final String styledAlias;
  late final String sameGroupAlias;
  late final String otherGroupAlias;
  late final String? reason;
}

extension _AnyProjectStatusScenario on glados.Any {
  glados.Generator<_ProjectStatusScenario> get projectStatusScenario =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(0, _statusAliasGroups.length),
        glados.IntAnys(this).intInRange(0, 1 << 16),
        _ProjectStatusScenario.new,
      );
}
