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
import '../test_utils.dart';
import '../../projects/test_utils.dart';

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
          awaitContent: true,
        ),
      ).thenAnswer((_) async => makeTestIdentity(agentId: 'agent-001'));

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
  });
}
