import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/service/change_set_confirmation_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository mockRepository;

  setUp(() {
    mockRepository = MockAgentRepository();
  });

  group('pendingChangeSetsProvider', () {
    test('returns empty list when no agent exists for task', () async {
      final container = ProviderContainer(
        overrides: [
          taskAgentProvider('task-001').overrideWith(
            (ref) async => null,
          ),
          agentRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      // Keep a subscription alive to prevent premature disposal.
      final sub = container.listen(
        pendingChangeSetsProvider('task-001'),
        (_, _) {},
      );
      addTearDown(sub.close);

      final result = await container.read(
        pendingChangeSetsProvider('task-001').future,
      );

      expect(result, isEmpty);
      verifyNever(
        () => mockRepository.getPendingChangeSets(
          any(),
          taskId: any(named: 'taskId'),
        ),
      );
    });

    test('fetches change sets from repo when agent exists', () async {
      final agent = makeTestIdentity();
      final changeSet = makeTestChangeSet(agentId: agent.agentId);

      when(
        () => mockRepository.getPendingChangeSets(
          agent.agentId,
          taskId: 'task-001',
        ),
      ).thenAnswer((_) async => [changeSet]);

      final updateController = StreamController<Set<String>>.broadcast();
      addTearDown(updateController.close);

      final container = ProviderContainer(
        overrides: [
          taskAgentProvider('task-001').overrideWith(
            (ref) async => agent,
          ),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          agentUpdateStreamProvider(agent.agentId).overrideWith(
            (ref) => updateController.stream,
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        pendingChangeSetsProvider('task-001'),
        (_, _) {},
      );
      addTearDown(sub.close);

      final result = await container.read(
        pendingChangeSetsProvider('task-001').future,
      );

      expect(result, hasLength(1));
      expect(result.first, isA<ChangeSetEntity>());

      verify(
        () => mockRepository.getPendingChangeSets(
          agent.agentId,
          taskId: 'task-001',
        ),
      ).called(1);
    });

    test('returns empty list when agent is not an identity entity', () async {
      // Return a non-agent variant (agentState) — mapOrNull returns null.
      final state = makeTestState();

      final container = ProviderContainer(
        overrides: [
          taskAgentProvider('task-001').overrideWith(
            (ref) async => state,
          ),
          agentRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        pendingChangeSetsProvider('task-001'),
        (_, _) {},
      );
      addTearDown(sub.close);

      final result = await container.read(
        pendingChangeSetsProvider('task-001').future,
      );

      expect(result, isEmpty);
      verifyNever(
        () => mockRepository.getPendingChangeSets(
          any(),
          taskId: any(named: 'taskId'),
        ),
      );
    });
  });

  group('pendingChangeSetsProvider deduplication', () {
    test(
      'collapses duplicate change sets with identical pending items',
      () async {
        final agent = makeTestIdentity();
        const sharedItems = [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Set estimate to 2 hours',
          ),
        ];

        // Two change sets with identical pending items (race condition).
        final older = makeTestChangeSet(
          id: 'cs-older',
          agentId: agent.agentId,
          items: sharedItems,
          createdAt: DateTime(2024, 3, 15, 10),
        );
        final newer = makeTestChangeSet(
          id: 'cs-newer',
          agentId: agent.agentId,
          items: sharedItems,
          createdAt: DateTime(2024, 3, 15, 11),
        );

        when(
          () => mockRepository.getPendingChangeSets(
            agent.agentId,
            taskId: 'task-001',
          ),
        ).thenAnswer((_) async => [older, newer]);

        final updateController = StreamController<Set<String>>.broadcast();
        addTearDown(updateController.close);

        final container = ProviderContainer(
          overrides: [
            taskAgentProvider('task-001').overrideWith(
              (ref) async => agent,
            ),
            agentRepositoryProvider.overrideWithValue(mockRepository),
            agentUpdateStreamProvider(agent.agentId).overrideWith(
              (ref) => updateController.stream,
            ),
          ],
        );
        addTearDown(container.dispose);

        final sub = container.listen(
          pendingChangeSetsProvider('task-001'),
          (_, _) {},
        );
        addTearDown(sub.close);

        final result = await container.read(
          pendingChangeSetsProvider('task-001').future,
        );

        expect(result, hasLength(1));
        expect((result.first as ChangeSetEntity).id, 'cs-newer');
      },
    );

    test('keeps change sets with different pending items', () async {
      final agent = makeTestIdentity();

      final set1 = makeTestChangeSet(
        id: 'cs-1',
        agentId: agent.agentId,
        items: const [
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'Fix bug'},
            humanSummary: 'Set title',
          ),
        ],
      );
      final set2 = makeTestChangeSet(
        id: 'cs-2',
        agentId: agent.agentId,
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 60},
            humanSummary: 'Set estimate',
          ),
        ],
      );

      when(
        () => mockRepository.getPendingChangeSets(
          agent.agentId,
          taskId: 'task-001',
        ),
      ).thenAnswer((_) async => [set1, set2]);

      final updateController = StreamController<Set<String>>.broadcast();
      addTearDown(updateController.close);

      final container = ProviderContainer(
        overrides: [
          taskAgentProvider('task-001').overrideWith(
            (ref) async => agent,
          ),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          agentUpdateStreamProvider(agent.agentId).overrideWith(
            (ref) => updateController.stream,
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        pendingChangeSetsProvider('task-001'),
        (_, _) {},
      );
      addTearDown(sub.close);

      final result = await container.read(
        pendingChangeSetsProvider('task-001').future,
      );

      expect(result, hasLength(2));
    });

    test('returns single set unchanged', () async {
      final agent = makeTestIdentity();
      final changeSet = makeTestChangeSet(agentId: agent.agentId);

      when(
        () => mockRepository.getPendingChangeSets(
          agent.agentId,
          taskId: 'task-001',
        ),
      ).thenAnswer((_) async => [changeSet]);

      final updateController = StreamController<Set<String>>.broadcast();
      addTearDown(updateController.close);

      final container = ProviderContainer(
        overrides: [
          taskAgentProvider('task-001').overrideWith(
            (ref) async => agent,
          ),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          agentUpdateStreamProvider(agent.agentId).overrideWith(
            (ref) => updateController.stream,
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        pendingChangeSetsProvider('task-001'),
        (_, _) {},
      );
      addTearDown(sub.close);

      final result = await container.read(
        pendingChangeSetsProvider('task-001').future,
      );

      expect(result, hasLength(1));
      expect((result.first as ChangeSetEntity).id, changeSet.id);
    });
  });

  group('projectPendingChangeSetsProvider', () {
    test('returns empty list when no agent exists for project', () async {
      final container = ProviderContainer(
        overrides: [
          projectAgentProvider('project-001').overrideWith(
            (ref) async => null,
          ),
          agentRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        projectPendingChangeSetsProvider('project-001'),
        (_, _) {},
      );
      addTearDown(sub.close);

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

      final container = ProviderContainer(
        overrides: [
          projectAgentProvider('project-001').overrideWith(
            (ref) async => agent,
          ),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          agentUpdateStreamProvider(agent.agentId).overrideWith(
            (ref) => updateController.stream,
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        projectPendingChangeSetsProvider('project-001'),
        (_, _) {},
      );
      addTearDown(sub.close);

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

  group('projectAcceptedRecommendationsProvider', () {
    test('returns empty list when no project agent exists', () async {
      final container = ProviderContainer(
        overrides: [
          projectAgentProvider('project-001').overrideWith(
            (ref) async => null,
          ),
          agentRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        projectAcceptedRecommendationsProvider('project-001'),
        (_, _) {},
      );
      addTearDown(sub.close);

      final result = await container.read(
        projectAcceptedRecommendationsProvider('project-001').future,
      );

      expect(result, isEmpty);
      verifyNever(
        () => mockRepository.getRecentDecisions(
          any(),
          taskId: any(named: 'taskId'),
          limit: any(named: 'limit'),
        ),
      );
    });

    test(
      'maps confirmed recommendation decisions into accepted steps',
      () async {
        final agent = makeTestIdentity();
        final updateController = StreamController<Set<String>>.broadcast();
        addTearDown(updateController.close);

        final validDecision =
            AgentDomainEntity.changeDecision(
                  id: 'decision-accepted',
                  agentId: agent.agentId,
                  changeSetId: 'change-set-001',
                  itemIndex: 0,
                  toolName: ProjectAgentToolNames.recommendNextSteps,
                  verdict: ChangeDecisionVerdict.confirmed,
                  taskId: 'project-001',
                  humanSummary: 'Recommend next steps',
                  args: const {
                    'steps': [
                      {
                        'title': 'Unblock QA',
                        'rationale': 'Staging data is missing',
                        'priority': 'high',
                      },
                      {
                        'title': 'Write launch checklist',
                      },
                    ],
                  },
                  createdAt: DateTime(2024, 3, 16),
                  vectorClock: null,
                )
                as ChangeDecisionEntity;
        final rejectedDecision =
            AgentDomainEntity.changeDecision(
                  id: 'decision-rejected',
                  agentId: agent.agentId,
                  changeSetId: 'change-set-001',
                  itemIndex: 1,
                  toolName: ProjectAgentToolNames.recommendNextSteps,
                  verdict: ChangeDecisionVerdict.rejected,
                  taskId: 'project-001',
                  humanSummary: 'Rejected steps',
                  args: const {
                    'steps': [
                      {'title': 'Should not render'},
                    ],
                  },
                  createdAt: DateTime(2024, 3, 16),
                  vectorClock: null,
                )
                as ChangeDecisionEntity;
        final otherToolDecision =
            AgentDomainEntity.changeDecision(
                  id: 'decision-other-tool',
                  agentId: agent.agentId,
                  changeSetId: 'change-set-001',
                  itemIndex: 2,
                  toolName: ProjectAgentToolNames.updateProjectStatus,
                  verdict: ChangeDecisionVerdict.confirmed,
                  taskId: 'project-001',
                  humanSummary: 'Other tool',
                  args: const {
                    'status': 'active',
                  },
                  createdAt: DateTime(2024, 3, 16),
                  vectorClock: null,
                )
                as ChangeDecisionEntity;
        final malformedDecision =
            AgentDomainEntity.changeDecision(
                  id: 'decision-malformed',
                  agentId: agent.agentId,
                  changeSetId: 'change-set-001',
                  itemIndex: 3,
                  toolName: ProjectAgentToolNames.recommendNextSteps,
                  verdict: ChangeDecisionVerdict.confirmed,
                  taskId: 'project-001',
                  humanSummary: 'Malformed steps',
                  args: const {
                    'steps': [
                      {'title': '  '},
                      {'rationale': 'Missing title'},
                    ],
                  },
                  createdAt: DateTime(2024, 3, 16),
                  vectorClock: null,
                )
                as ChangeDecisionEntity;

        when(
          () => mockRepository.getRecentDecisions(
            agent.agentId,
            taskId: 'project-001',
            limit: 20,
          ),
        ).thenAnswer(
          (_) async => [
            validDecision,
            rejectedDecision,
            otherToolDecision,
            malformedDecision,
          ],
        );

        final container = ProviderContainer(
          overrides: [
            projectAgentProvider('project-001').overrideWith(
              (ref) async => agent,
            ),
            agentRepositoryProvider.overrideWithValue(mockRepository),
            agentUpdateStreamProvider(agent.agentId).overrideWith(
              (ref) => updateController.stream,
            ),
          ],
        );
        addTearDown(container.dispose);

        final sub = container.listen(
          projectAcceptedRecommendationsProvider('project-001'),
          (_, _) {},
        );
        addTearDown(sub.close);

        final result = await container.read(
          projectAcceptedRecommendationsProvider('project-001').future,
        );

        expect(result, hasLength(2));
        expect(result[0].title, 'Unblock QA');
        expect(result[0].rationale, 'Staging data is missing');
        expect(result[0].priority, 'HIGH');
        expect(result[1].title, 'Write launch checklist');
        expect(result[1].rationale, isNull);
        expect(result[1].priority, isNull);
      },
    );
  });

  group('changeSetConfirmationServiceProvider', () {
    late MockPersistenceLogic mockPersistenceLogic;
    late MockEntitiesCacheService mockEntitiesCacheService;

    setUp(() async {
      mockPersistenceLogic = MockPersistenceLogic();
      mockEntitiesCacheService = MockEntitiesCacheService();
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
            ..registerSingleton<TimeService>(TimeService())
            ..registerSingleton<EntitiesCacheService>(
              mockEntitiesCacheService,
            );
        },
      );
    });

    tearDown(tearDownTestGetIt);

    test('creates service with resolved dependencies', () {
      final mockSyncService = MockAgentSyncService();
      final mockJournalDb = MockJournalDb();
      final mockJournalRepository = MockJournalRepository();
      final mockChecklistRepository = MockChecklistRepository();
      final mockLabelsRepository = MockLabelsRepository();

      final container = ProviderContainer(
        overrides: [
          agentSyncServiceProvider.overrideWithValue(mockSyncService),
          journalDbProvider.overrideWithValue(mockJournalDb),
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          checklistRepositoryProvider.overrideWithValue(
            mockChecklistRepository,
          ),
          labelsRepositoryProvider.overrideWithValue(mockLabelsRepository),
          domainLoggerProvider.overrideWithValue(MockDomainLogger()),
          taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(changeSetConfirmationServiceProvider);

      expect(service, isA<ChangeSetConfirmationService>());
    });

    test('creates project-scoped service with resolved dependencies', () {
      final mockSyncService = MockAgentSyncService();
      final mockJournalDb = MockJournalDb();
      final mockProjectRepository = MockProjectRepository();
      final mockLabelsRepository = MockLabelsRepository();

      final container = ProviderContainer(
        overrides: [
          agentSyncServiceProvider.overrideWithValue(mockSyncService),
          journalDbProvider.overrideWithValue(mockJournalDb),
          projectRepositoryProvider.overrideWithValue(mockProjectRepository),
          labelsRepositoryProvider.overrideWithValue(mockLabelsRepository),
          domainLoggerProvider.overrideWithValue(MockDomainLogger()),
          taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(
        projectChangeSetConfirmationServiceProvider,
      );

      expect(service, isA<ChangeSetConfirmationService>());
    });
  });
}
