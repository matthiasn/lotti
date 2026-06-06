import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/service/change_set_confirmation_service.dart';
import 'package:lotti/features/agents/service/project_recommendation_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
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
import '../../projects/test_utils.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository mockRepository;

  setUp(() {
    mockRepository = MockAgentRepository();
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

  group('projectRecommendationsProvider', () {
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
        projectRecommendationsProvider('project-001'),
        (_, _) {},
      );
      addTearDown(sub.close);

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
        final container = ProviderContainer(
          overrides: [
            projectAgentProvider('project-001').overrideWith(
              (ref) async => makeTestState(),
            ),
            agentRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        final sub = container.listen(
          projectRecommendationsProvider('project-001'),
          (_, _) {},
        );
        addTearDown(sub.close);

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
          projectRecommendationsProvider('project-001'),
          (_, _) {},
        );
        addTearDown(sub.close);

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
          agentRepositoryProvider.overrideWithValue(mockRepository),
          projectRepositoryProvider.overrideWithValue(
            MockProjectRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(changeSetConfirmationServiceProvider);

      expect(service, isA<ChangeSetConfirmationService>());
    });

    test(
      'wires notification bridge when notification repository is registered',
      () async {
        final mockSyncService = MockAgentSyncService();
        final mockNotificationRepository = MockNotificationRepository();
        final mockJournalDb = MockJournalDb();
        final mockJournalRepository = MockJournalRepository();
        final mockChecklistRepository = MockChecklistRepository();
        final mockLabelsRepository = MockLabelsRepository();
        final changeSet = makeTestChangeSet(
          taskId: 'task-provider-notifications',
          items: const [
            ChangeItem(
              toolName: 'update_task_estimate',
              args: {'minutes': 30},
              humanSummary: 'Set estimate',
            ),
          ],
        );

        if (getIt.isRegistered<NotificationRepository>()) {
          getIt.unregister<NotificationRepository>();
        }
        getIt.registerSingleton<NotificationRepository>(
          mockNotificationRepository,
        );
        when(() => mockSyncService.repository).thenReturn(mockRepository);
        when(() => mockRepository.getEntity(any())).thenAnswer((_) async {
          return null;
        });
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockNotificationRepository.markTaskSuggestionsActedOn(any()),
        ).thenAnswer((_) async => const []);

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
            agentRepositoryProvider.overrideWithValue(mockRepository),
            projectRepositoryProvider.overrideWithValue(
              MockProjectRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final service = container.read(changeSetConfirmationServiceProvider);
        final applied = await service.rejectItem(changeSet, 0);

        expect(applied, isTrue);
        verify(
          () => mockNotificationRepository.markTaskSuggestionsActedOn(
            'task-provider-notifications',
          ),
        ).called(1);
      },
    );

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

    test(
      'project-scoped service records confirmed recommendations for recommend_next_steps',
      () async {
        final mockSyncService = MockAgentSyncService();
        final mockProjectRepository = MockProjectRepository();
        final mockTaskAgentService = MockTaskAgentService();
        final mockLabelsRepository = MockLabelsRepository();
        final mockRecommendationService = MockProjectRecommendationService();
        final mockLogger = MockDomainLogger();
        final changeSet = makeTestChangeSet(
          taskId: 'project-001',
          items: const [
            ChangeItem(
              toolName: ProjectAgentToolNames.recommendNextSteps,
              args: {
                'steps': [
                  {'title': 'Verify the rollout'},
                ],
              },
              humanSummary: 'Recommend the next step',
            ),
          ],
        );

        when(() => mockSyncService.repository).thenReturn(mockRepository);
        when(
          () => mockRepository.getEntity(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockRecommendationService.recordConfirmedRecommendations(
            changeSet: any(named: 'changeSet'),
            decision: any(named: 'decision'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockLogger.log(
            any(),
            any(),
            subDomain: any(named: 'subDomain'),
          ),
        ).thenReturn(null);

        final container = ProviderContainer(
          overrides: [
            agentSyncServiceProvider.overrideWithValue(mockSyncService),
            projectRepositoryProvider.overrideWithValue(mockProjectRepository),
            taskAgentServiceProvider.overrideWithValue(mockTaskAgentService),
            labelsRepositoryProvider.overrideWithValue(mockLabelsRepository),
            projectRecommendationServiceProvider.overrideWithValue(
              mockRecommendationService,
            ),
            domainLoggerProvider.overrideWithValue(mockLogger),
          ],
        );
        addTearDown(container.dispose);

        final service = container.read(
          projectChangeSetConfirmationServiceProvider,
        );
        final result = await service.confirmItem(changeSet, 0);

        expect(result.success, isTrue);
        verify(
          () => mockRecommendationService.recordConfirmedRecommendations(
            changeSet: any(named: 'changeSet'),
            decision: any(named: 'decision'),
          ),
        ).called(1);
      },
    );

    test(
      'project-scoped service skips recommendation recording for non-recommend tools',
      () async {
        final mockSyncService = MockAgentSyncService();
        final mockProjectRepository = MockProjectRepository();
        final mockTaskAgentService = MockTaskAgentService();
        final mockLabelsRepository = MockLabelsRepository();
        final mockRecommendationService = MockProjectRecommendationService();
        final mockLogger = MockDomainLogger();
        final changeSet = makeTestChangeSet(
          taskId: 'project-001',
          items: const [
            ChangeItem(
              toolName: ProjectAgentToolNames.updateProjectStatus,
              args: {'status': 'active'},
              humanSummary: 'Mark the project active',
            ),
          ],
        );

        when(() => mockSyncService.repository).thenReturn(mockRepository);
        when(
          () => mockRepository.getEntity(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockProjectRepository.getProjectById('project-001'),
        ).thenAnswer((_) async => makeTestProject(id: 'project-001'));
        when(
          () => mockProjectRepository.updateProject(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockLogger.log(
            any(),
            any(),
            subDomain: any(named: 'subDomain'),
          ),
        ).thenReturn(null);

        final container = ProviderContainer(
          overrides: [
            agentSyncServiceProvider.overrideWithValue(mockSyncService),
            projectRepositoryProvider.overrideWithValue(mockProjectRepository),
            taskAgentServiceProvider.overrideWithValue(mockTaskAgentService),
            labelsRepositoryProvider.overrideWithValue(mockLabelsRepository),
            projectRecommendationServiceProvider.overrideWithValue(
              mockRecommendationService,
            ),
            domainLoggerProvider.overrideWithValue(mockLogger),
          ],
        );
        addTearDown(container.dispose);

        final service = container.read(
          projectChangeSetConfirmationServiceProvider,
        );
        final result = await service.confirmItem(changeSet, 0);

        expect(result.success, isTrue);
        verifyNever(
          () => mockRecommendationService.recordConfirmedRecommendations(
            changeSet: any(named: 'changeSet'),
            decision: any(named: 'decision'),
          ),
        );
      },
    );
  });

  // Tests for _deduplicateChangeSets — exercised via
  // projectPendingChangeSetsProvider so we can reach the private function.
  group('_deduplicateChangeSets (via projectPendingChangeSetsProvider)', () {
    Future<List<AgentDomainEntity>> fetchDeduped(
      List<ChangeSetEntity> rawSets,
    ) async {
      final agent = makeTestIdentity();
      final updateController = StreamController<Set<String>>.broadcast();
      addTearDown(updateController.close);

      when(
        () => mockRepository.getPendingChangeSets(
          agent.agentId,
          taskId: 'project-ded',
        ),
      ).thenAnswer((_) async => rawSets);

      final container = ProviderContainer(
        overrides: [
          projectAgentProvider('project-ded').overrideWith(
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
        projectPendingChangeSetsProvider('project-ded'),
        (_, _) {},
      );
      addTearDown(sub.close);

      return container.read(
        projectPendingChangeSetsProvider('project-ded').future,
      );
    }

    test(
      'passes through a single change set without deduplication',
      () async {
        final cs = makeTestChangeSet(id: 'cs-single');
        final result = await fetchDeduped([cs]);

        expect(result, hasLength(1));
        expect(result.first, isA<ChangeSetEntity>());
      },
    );

    test(
      'two change sets with identical pending-item fingerprints — keeps only the newer one',
      () async {
        const item = ChangeItem(
          toolName: 'update_task_estimate',
          args: {'minutes': 60},
          humanSummary: 'Set estimate',
        );
        final older = makeTestChangeSet(
          id: 'cs-older',
          createdAt: DateTime(2024, 3, 15, 9),
          items: const [item],
        );
        final newer = makeTestChangeSet(
          id: 'cs-newer',
          createdAt: DateTime(2024, 3, 15, 11),
          items: const [item],
        );

        final result = await fetchDeduped([older, newer]);

        expect(result, hasLength(1));
        expect(result.first.id, 'cs-newer');
      },
    );

    test(
      'deduplication also keeps newer when older is encountered second',
      () async {
        const item = ChangeItem(
          toolName: 'update_task_estimate',
          args: {'minutes': 60},
          humanSummary: 'Set estimate',
        );
        final older = makeTestChangeSet(
          id: 'cs-older2',
          createdAt: DateTime(2024, 3, 15, 8),
          items: const [item],
        );
        final newer = makeTestChangeSet(
          id: 'cs-newer2',
          createdAt: DateTime(2024, 3, 15, 12),
          items: const [item],
        );

        // Pass newer first so the older entity arrives after the seen map
        // already has an entry — exercises the isAfter branch going false.
        final result = await fetchDeduped([newer, older]);

        expect(result, hasLength(1));
        expect(result.first.id, 'cs-newer2');
      },
    );

    test(
      'two change sets with different fingerprints are both preserved',
      () async {
        final cs1 = makeTestChangeSet(
          id: 'cs-fp-a',
          items: const [
            ChangeItem(
              toolName: 'update_task_estimate',
              args: {'minutes': 30},
              humanSummary: 'Set 30 min',
            ),
          ],
        );
        final cs2 = makeTestChangeSet(
          id: 'cs-fp-b',
          items: const [
            ChangeItem(
              toolName: 'update_task_status',
              args: {'status': 'done'},
              humanSummary: 'Mark done',
            ),
          ],
        );

        final result = await fetchDeduped([cs1, cs2]);

        expect(result, hasLength(2));
        expect(result.map((e) => e.id), containsAll(['cs-fp-a', 'cs-fp-b']));
      },
    );

    test(
      'fully-resolved change set (no pending items) is keyed by entity id and not collapsed with another resolved set',
      () async {
        // Both sets have no pending items → empty fingerprint → keyed by id.
        final resolved1 = makeTestChangeSet(
          id: 'cs-res-1',
          items: const [
            ChangeItem(
              toolName: 'update_task_estimate',
              args: {'minutes': 30},
              humanSummary: 'Confirmed',
              status: ChangeItemStatus.confirmed,
            ),
          ],
        );
        final resolved2 = makeTestChangeSet(
          id: 'cs-res-2',
          items: const [
            ChangeItem(
              toolName: 'update_task_status',
              args: {'status': 'done'},
              humanSummary: 'Confirmed',
              status: ChangeItemStatus.confirmed,
            ),
          ],
        );

        final result = await fetchDeduped([resolved1, resolved2]);

        // Neither set is dropped because they each have unique entity IDs.
        expect(result, hasLength(2));
        expect(
          result.map((e) => e.id),
          containsAll(['cs-res-1', 'cs-res-2']),
        );
      },
    );

    test(
      'three change sets: two duplicates and one unique — keeps newest duplicate and the unique',
      () async {
        const dupItem = ChangeItem(
          toolName: 'add_checklist_item',
          args: {'text': 'Write tests'},
          humanSummary: 'Add item',
        );
        final dup1 = makeTestChangeSet(
          id: 'cs-dup-1',
          createdAt: DateTime(2024, 3, 15, 7),
          items: const [dupItem],
        );
        final dup2 = makeTestChangeSet(
          id: 'cs-dup-2',
          createdAt: DateTime(2024, 3, 15, 10),
          items: const [dupItem],
        );
        final unique = makeTestChangeSet(
          id: 'cs-unique',
          items: const [
            ChangeItem(
              toolName: 'update_task_status',
              args: {'status': 'in_progress'},
              humanSummary: 'Move to in-progress',
            ),
          ],
        );

        final result = await fetchDeduped([dup1, dup2, unique]);

        expect(result, hasLength(2));
        final ids = result.map((e) => e.id).toSet();
        expect(ids, contains('cs-dup-2'));
        expect(ids, contains('cs-unique'));
        expect(ids, isNot(contains('cs-dup-1')));
      },
    );
  });
}
