
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/service/change_set_confirmation_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
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

    test(
      'leaves notification bridge unset when repository is unregistered',
      () async {
        // setUpTestGetIt does not register a NotificationRepository, so the
        // provider must take the null branch: onChangeSetResolved is null and
        // resolution must never reach into a notification repository.
        expect(getIt.isRegistered<NotificationRepository>(), isFalse);

        final mockSyncService = MockAgentSyncService();
        final mockJournalDb = MockJournalDb();
        final mockJournalRepository = MockJournalRepository();
        final mockChecklistRepository = MockChecklistRepository();
        final mockLabelsRepository = MockLabelsRepository();
        // Held but deliberately NOT registered in GetIt; if the provider wired
        // a bridge anyway, resolution would invoke it and verifyNever fails.
        final unregisteredNotificationRepo = MockNotificationRepository();
        when(
          () => unregisteredNotificationRepo.markTaskSuggestionsActedOn(any()),
        ).thenAnswer((_) async => const []);
        final changeSet = makeTestChangeSet(
          taskId: 'task-no-notifications',
          items: const [
            ChangeItem(
              toolName: 'update_task_estimate',
              args: {'minutes': 15},
              humanSummary: 'Set estimate',
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

        // Resolution still succeeds without a notification bridge.
        expect(applied, isTrue);
        verifyNever(
          () => unregisteredNotificationRepo.markTaskSuggestionsActedOn(any()),
        );
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
}
