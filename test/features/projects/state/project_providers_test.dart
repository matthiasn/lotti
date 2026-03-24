import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  late MockProjectRepository mockRepo;
  late StreamController<Set<String>> updateStreamController;
  late ProviderContainer container;

  const categoryId = 'cat-1';
  const taskId = 'task-1';

  setUp(() {
    mockRepo = MockProjectRepository();
    updateStreamController = StreamController<Set<String>>.broadcast();

    when(
      () => mockRepo.updateStream,
    ).thenAnswer((_) => updateStreamController.stream);

    container = ProviderContainer(
      overrides: [
        projectRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    updateStreamController.close();
  });

  group('projectsForCategoryProvider', () {
    test('fetches projects for category', () async {
      final projects = [
        makeTestProject(categoryId: categoryId),
        makeTestProject(title: 'Project 2', categoryId: categoryId),
      ];
      when(
        () => mockRepo.getProjectsForCategory(categoryId),
      ).thenAnswer((_) async => projects);

      final result = await container.read(
        projectsForCategoryProvider(categoryId).future,
      );

      expect(result, hasLength(2));
      expect(result.first.data.title, 'Test Project');
    });

    test('returns empty list when no projects', () async {
      when(
        () => mockRepo.getProjectsForCategory(categoryId),
      ).thenAnswer((_) async => []);

      final result = await container.read(
        projectsForCategoryProvider(categoryId).future,
      );

      expect(result, isEmpty);
    });
  });

  group('projectForTaskProvider', () {
    test('returns project for linked task', () async {
      final project = makeTestProject(categoryId: categoryId);
      when(
        () => mockRepo.getProjectForTask(taskId),
      ).thenAnswer((_) async => project);

      final result = await container.read(
        projectForTaskProvider(taskId).future,
      );

      expect(result, isNotNull);
      expect(result!.data.title, 'Test Project');
    });

    test('returns null for unlinked task', () async {
      when(
        () => mockRepo.getProjectForTask(taskId),
      ).thenAnswer((_) async => null);

      final result = await container.read(
        projectForTaskProvider(taskId).future,
      );

      expect(result, isNull);
    });

    test('re-fetches when stream emits matching task id', () async {
      final project = makeTestProject(categoryId: categoryId);
      when(
        () => mockRepo.getProjectForTask(taskId),
      ).thenAnswer((_) async => project);

      await container.read(projectForTaskProvider(taskId).future);

      when(
        () => mockRepo.getProjectForTask(taskId),
      ).thenAnswer((_) async => null);

      updateStreamController.add({taskId});
      await Future<void>.delayed(Duration.zero);

      final result = await container.read(
        projectForTaskProvider(taskId).future,
      );
      expect(result, isNull);
    });

    test('re-fetches when stream emits projectNotification', () async {
      final project = makeTestProject(categoryId: categoryId);
      when(
        () => mockRepo.getProjectForTask(taskId),
      ).thenAnswer((_) async => project);

      await container.read(projectForTaskProvider(taskId).future);

      when(
        () => mockRepo.getProjectForTask(taskId),
      ).thenAnswer((_) async => null);

      updateStreamController.add({projectNotification});
      await Future<void>.delayed(Duration.zero);

      final result = await container.read(
        projectForTaskProvider(taskId).future,
      );
      expect(result, isNull);
    });
  });

  group('projectTaskCountProvider', () {
    const projectId = 'proj-1';

    test('returns task count for a project', () async {
      final tasks = [makeTestTask(), makeTestTask()];
      when(
        () => mockRepo.getTasksForProject(projectId),
      ).thenAnswer((_) async => tasks);

      final result = await container.read(
        projectTaskCountProvider(projectId).future,
      );

      expect(result, 2);
    });

    test('returns 0 when project has no tasks', () async {
      when(
        () => mockRepo.getTasksForProject(projectId),
      ).thenAnswer((_) async => []);

      final result = await container.read(
        projectTaskCountProvider(projectId).future,
      );

      expect(result, 0);
    });

    test('re-fetches when stream emits matching project id', () async {
      when(
        () => mockRepo.getTasksForProject(projectId),
      ).thenAnswer((_) async => [makeTestTask()]);

      await container.read(projectTaskCountProvider(projectId).future);

      when(
        () => mockRepo.getTasksForProject(projectId),
      ).thenAnswer((_) async => [makeTestTask(), makeTestTask()]);

      updateStreamController.add({projectId});
      await Future<void>.delayed(Duration.zero);

      final result = await container.read(
        projectTaskCountProvider(projectId).future,
      );
      expect(result, 2);
    });

    test('re-fetches when stream emits projectNotification', () async {
      when(
        () => mockRepo.getTasksForProject(projectId),
      ).thenAnswer((_) async => [makeTestTask()]);

      await container.read(projectTaskCountProvider(projectId).future);

      when(
        () => mockRepo.getTasksForProject(projectId),
      ).thenAnswer((_) async => []);

      updateStreamController.add({projectNotification});
      await Future<void>.delayed(Duration.zero);

      final result = await container.read(
        projectTaskCountProvider(projectId).future,
      );
      expect(result, 0);
    });
  });

  group('projectHealthMetricsProvider', () {
    const projectId = 'proj-health';
    const agentId = 'agent-health';

    test(
      'returns null without reading the report provider when no project agent exists',
      () async {
        var reportRead = false;
        final scopedContainer = ProviderContainer(
          overrides: [
            projectRepositoryProvider.overrideWithValue(mockRepo),
            projectAgentProvider(projectId).overrideWith((ref) async => null),
            agentReportProvider(agentId).overrideWith((ref) async {
              reportRead = true;
              throw StateError('report provider should not be read');
            }),
          ],
        );
        addTearDown(scopedContainer.dispose);

        final result = await scopedContainer.read(
          projectHealthMetricsProvider(projectId).future,
        );

        expect(result, isNull);
        expect(reportRead, isFalse);
      },
    );

    test('returns null when the project agent has no report yet', () async {
      final scopedContainer = ProviderContainer(
        overrides: [
          projectRepositoryProvider.overrideWithValue(mockRepo),
          projectAgentProvider(projectId).overrideWith(
            (ref) async => _makeProjectAgent(agentId),
          ),
          agentReportProvider(agentId).overrideWith((ref) async => null),
        ],
      );
      addTearDown(scopedContainer.dispose);

      final result = await scopedContainer.read(
        projectHealthMetricsProvider(projectId).future,
      );

      expect(result, isNull);
    });

    test(
      'reads the health band from the latest project-agent report',
      () async {
        final scopedContainer = ProviderContainer(
          overrides: [
            projectRepositoryProvider.overrideWithValue(mockRepo),
            projectAgentProvider(projectId).overrideWith(
              (ref) async => _makeProjectAgent(agentId),
            ),
            agentReportProvider(agentId).overrideWith(
              (ref) async => AgentDomainEntity.agentReport(
                id: 'report-1',
                agentId: agentId,
                scope: 'current',
                createdAt: DateTime(2026, 4, 2, 9),
                vectorClock: null,
                content: '# Status Report',
                provenance: const {
                  'project_health_band': 'blocked',
                  'project_health_rationale':
                      'A dependency is still blocking the next step.',
                  'project_health_confidence': 0.91,
                },
              ),
            ),
          ],
        );
        addTearDown(scopedContainer.dispose);

        final result = await scopedContainer.read(
          projectHealthMetricsProvider(projectId).future,
        );

        expect(result, isNotNull);
        expect(result!.band, ProjectHealthBand.blocked);
        expect(
          result.rationale,
          'A dependency is still blocking the next step.',
        );
        expect(result.confidence, 0.91);
      },
    );
  });
}

AgentDomainEntity _makeProjectAgent(String agentId) {
  return AgentDomainEntity.agent(
    id: agentId,
    agentId: agentId,
    kind: 'project_agent',
    displayName: 'Project Agent',
    lifecycle: AgentLifecycle.active,
    mode: AgentInteractionMode.autonomous,
    allowedCategoryIds: const {},
    currentStateId: 'state-1',
    config: const AgentConfig(),
    createdAt: DateTime(2026, 4, 2, 9),
    updatedAt: DateTime(2026, 4, 2, 9),
    vectorClock: null,
  );
}
