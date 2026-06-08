import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/project_recommendation_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository mockRepository;

  setUp(() {
    mockRepository = MockAgentRepository();
  });

  /// Builds the standard project-agent container: projectAgent override,
  /// repository override, and (when [agent] + [updateController] are given)
  /// the agent-update stream override. Optionally keeps [listenTo] alive
  /// and registers all disposals via addTearDown.
  ProviderContainer createProjectAgentContainer({
    required String projectId,
    AgentDomainEntity? agent,
    StreamController<Set<String>>? updateController,
    ProviderListenable<Object?>? listenTo,
  }) {
    final container = ProviderContainer(
      overrides: [
        projectAgentProvider(projectId).overrideWith((ref) async => agent),
        agentRepositoryProvider.overrideWithValue(mockRepository),
        if (agent != null && updateController != null)
          agentUpdateStreamProvider(agent.agentId).overrideWith(
            (ref) => updateController.stream,
          ),
      ],
    );
    addTearDown(container.dispose);
    if (listenTo != null) {
      final sub = container.listen(listenTo, (_, _) {});
      addTearDown(sub.close);
    }
    return container;
  }

  group('projectPendingChangeSetsProvider', () {
    test('returns empty list when no agent exists for project', () async {
      final container = createProjectAgentContainer(
        projectId: 'project-001',
        listenTo: projectPendingChangeSetsProvider('project-001'),
      );

      final result = await container.read(
        projectPendingChangeSetsProvider('project-001').future,
      );

      expect(result, isEmpty);
      verifyNever(
        () => mockRepository.getPendingChangeSets(
          any(),
          taskId: any(named: 'taskId'),
        ),
      );
    });

    test('fetches change sets from repo when project agent exists', () async {
      final agent = makeTestIdentity();
      final changeSet = makeTestChangeSet(
        agentId: agent.agentId,
        taskId: 'project-001',
      );

      when(
        () => mockRepository.getPendingChangeSets(
          agent.agentId,
          taskId: 'project-001',
        ),
      ).thenAnswer((_) async => [changeSet]);

      final updateController = StreamController<Set<String>>.broadcast();
      addTearDown(updateController.close);

      final container = createProjectAgentContainer(
        projectId: 'project-001',
        agent: agent,
        updateController: updateController,
        listenTo: projectPendingChangeSetsProvider('project-001'),
      );

      final result = await container.read(
        projectPendingChangeSetsProvider('project-001').future,
      );

      expect(result, hasLength(1));
      expect(result[0], isA<ChangeSetEntity>());

      verify(
        () => mockRepository.getPendingChangeSets(
          agent.agentId,
          taskId: 'project-001',
        ),
      ).called(1);
    });
  });

  group('projectRecommendationsProvider', () {
    test('returns empty list when no project agent exists', () async {
      final container = createProjectAgentContainer(
        projectId: 'project-001',
        listenTo: projectRecommendationsProvider('project-001'),
      );

      final result = await container.read(
        projectRecommendationsProvider('project-001').future,
      );

      expect(result, isEmpty);
      verifyNever(
        () => mockRepository.getEntitiesByAgentId(
          any(),
          type: any(named: 'type'),
          limit: any(named: 'limit'),
        ),
      );
    });

    test(
      'returns empty list when project agent is not an identity entity',
      () async {
        final container = createProjectAgentContainer(
          projectId: 'project-001',
          agent: makeTestState(),
          listenTo: projectRecommendationsProvider('project-001'),
        );

        final result = await container.read(
          projectRecommendationsProvider('project-001').future,
        );

        expect(result, isEmpty);
        verifyNever(
          () => mockRepository.getEntitiesByAgentId(
            any(),
            type: any(named: 'type'),
            limit: any(named: 'limit'),
          ),
        );
      },
    );

    test(
      'returns active project recommendations ordered for display',
      () async {
        final agent = makeTestIdentity();
        final updateController = StreamController<Set<String>>.broadcast();
        addTearDown(updateController.close);

        final olderActive = makeTestProjectRecommendation(
          id: 'pr-older',
          agentId: agent.agentId,
          title: 'Older recommendation',
          createdAt: DateTime(2024, 3, 15, 9),
          updatedAt: DateTime(2024, 3, 15, 9),
        );
        final secondInBatch = makeTestProjectRecommendation(
          id: 'pr-second',
          agentId: agent.agentId,
          title: 'Second in latest batch',
          position: 1,
          createdAt: DateTime(2024, 3, 16, 9),
          updatedAt: DateTime(2024, 3, 16, 9),
          priority: null,
          rationale: null,
        );
        final firstInBatch = makeTestProjectRecommendation(
          id: 'pr-first',
          agentId: agent.agentId,
          title: 'First in latest batch',
          createdAt: DateTime(2024, 3, 16, 9),
          updatedAt: DateTime(2024, 3, 16, 9),
          priority: 'MEDIUM',
        );
        final resolved = makeTestProjectRecommendation(
          id: 'pr-resolved',
          agentId: agent.agentId,
          title: 'Resolved recommendation',
          status: ProjectRecommendationStatus.resolved,
        );
        final otherProject = makeTestProjectRecommendation(
          id: 'pr-other-project',
          agentId: agent.agentId,
          projectId: 'project-999',
          title: 'Other project recommendation',
        );

        when(
          () => mockRepository.getEntitiesByAgentId(
            agent.agentId,
            type: AgentEntityTypes.projectRecommendation,
          ),
        ).thenAnswer(
          (_) async => [
            olderActive,
            secondInBatch,
            firstInBatch,
            resolved,
            otherProject,
          ],
        );

        final container = createProjectAgentContainer(
          projectId: 'project-001',
          agent: agent,
          updateController: updateController,
          listenTo: projectRecommendationsProvider('project-001'),
        );

        final result = await container.read(
          projectRecommendationsProvider('project-001').future,
        );

        expect(result, hasLength(3));
        expect(result[0].id, 'pr-first');
        expect(result[1].id, 'pr-second');
        expect(result[2].id, 'pr-older');
      },
    );
  });

  group('projectRecommendationServiceProvider', () {
    test('creates the service when optional notifications are absent', () {
      final mockSyncService = MockAgentSyncService();
      final mockLogger = MockDomainLogger();
      final container = ProviderContainer(
        overrides: [
          agentSyncServiceProvider.overrideWithValue(mockSyncService),
          domainLoggerProvider.overrideWithValue(mockLogger),
          maybeUpdateNotificationsProvider.overrideWith((ref) => null),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(projectRecommendationServiceProvider);

      expect(service, isA<ProjectRecommendationService>());
    });
  });
}
