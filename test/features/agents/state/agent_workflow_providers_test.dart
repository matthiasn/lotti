import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/workflow/event_agent_workflow.dart';
import 'package:lotti/features/agents/workflow/improver_agent_workflow.dart';
import 'package:lotti/features/agents/workflow/project_agent_workflow.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_week_context_service.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  group('dayAgentWorkflowProvider', () {
    setUp(() async {
      await setUpTestGetIt(
        additionalSetup: () {
          getIt.registerSingleton<Fts5Db>(MockFts5Db());
        },
      );
    });

    tearDown(tearDownTestGetIt);

    test('resolves dependencies and wires persisted-state notifications', () {
      final repository = MockAgentRepository();
      final syncService = MockAgentSyncService();
      final journalDb = MockJournalDb();
      final journalRepository = MockJournalRepository();
      final aiConfigRepository = MockAiConfigRepository();
      final cloudInferenceRepository = MockCloudInferenceRepository();
      final templateService = MockAgentTemplateService();
      final soulDocumentService = MockSoulDocumentService();
      final domainLogger = MockDomainLogger();
      final wakeOrchestrator = MockWakeOrchestrator();
      final notifications = MockUpdateNotifications();
      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(repository),
          conversationRepositoryProvider.overrideWith(
            ConversationRepository.new,
          ),
          aiConfigRepositoryProvider.overrideWithValue(aiConfigRepository),
          cloudInferenceRepositoryProvider.overrideWithValue(
            cloudInferenceRepository,
          ),
          agentSyncServiceProvider.overrideWithValue(syncService),
          journalDbProvider.overrideWithValue(journalDb),
          journalRepositoryProvider.overrideWithValue(journalRepository),
          wakeOrchestratorProvider.overrideWithValue(wakeOrchestrator),
          agentTemplateServiceProvider.overrideWithValue(templateService),
          soulDocumentServiceProvider.overrideWithValue(soulDocumentService),
          domainLoggerProvider.overrideWithValue(domainLogger),
          updateNotificationsProvider.overrideWithValue(notifications),
        ],
      );
      addTearDown(container.dispose);

      final workflow = container.read(dayAgentWorkflowProvider);

      expect(workflow, isA<DayAgentWorkflow>());
      expect(workflow.captureService, isA<DayAgentCaptureService>());
      expect(workflow.planService, isA<DayAgentPlanService>());
      expect(workflow.captureService?.agentRepository, same(repository));
      expect(workflow.captureService?.syncService, same(syncService));
      expect(workflow.captureService?.journalDb, same(journalDb));
      expect(
        workflow.captureService?.journalRepository,
        same(journalRepository),
      );
      expect(workflow.captureService?.orchestrator, same(wakeOrchestrator));
      expect(workflow.captureService?.domainLogger, same(domainLogger));
      expect(workflow.planService?.agentRepository, same(repository));
      expect(workflow.planService?.syncService, same(syncService));
      expect(workflow.planService?.journalDb, same(journalDb));
      expect(workflow.planService?.domainLogger, same(domainLogger));
      expect(workflow.weekContextService, isA<DayAgentWeekContextService>());
      expect(workflow.weekContextService?.agentRepository, same(repository));
      expect(workflow.weekContextService?.syncService, same(syncService));
      expect(workflow.weekContextService?.journalDb, same(journalDb));
      expect(workflow.weekContextService?.domainLogger, same(domainLogger));
      workflow.onPersistedStateChanged?.call('day-agent-001');
      verify(
        () => notifications.notifyUiOnly({
          'day-agent-001',
          agentNotification,
        }),
      ).called(1);
    });
  });

  group('other workflow providers', () {
    late MockAgentRepository repository;
    late MockAgentSyncService syncService;
    late MockAgentTemplateService templateService;
    late MockUpdateNotifications notifications;
    late ProviderContainer container;

    setUp(() async {
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..registerSingleton<Fts5Db>(MockFts5Db())
            ..registerSingleton<EntitiesCacheService>(
              MockEntitiesCacheService(),
            )
            ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
            ..registerSingleton<TimeService>(MockTimeService());
        },
      );

      repository = MockAgentRepository();
      syncService = MockAgentSyncService();
      templateService = MockAgentTemplateService();
      notifications = MockUpdateNotifications();

      container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(repository),
          conversationRepositoryProvider.overrideWith(
            ConversationRepository.new,
          ),
          aiConfigRepositoryProvider.overrideWithValue(
            MockAiConfigRepository(),
          ),
          cloudInferenceRepositoryProvider.overrideWithValue(
            MockCloudInferenceRepository(),
          ),
          agentSyncServiceProvider.overrideWithValue(syncService),
          journalDbProvider.overrideWithValue(MockJournalDb()),
          journalRepositoryProvider.overrideWithValue(
            MockJournalRepository(),
          ),
          wakeOrchestratorProvider.overrideWithValue(MockWakeOrchestrator()),
          agentTemplateServiceProvider.overrideWithValue(templateService),
          soulDocumentServiceProvider.overrideWithValue(
            MockSoulDocumentService(),
          ),
          domainLoggerProvider.overrideWithValue(MockDomainLogger()),
          updateNotificationsProvider.overrideWithValue(notifications),
          // Repositories that would otherwise resolve deep GetIt graphs.
          aiInputRepositoryProvider.overrideWithValue(
            MockAiInputRepository(),
          ),
          checklistRepositoryProvider.overrideWithValue(
            MockChecklistRepository(),
          ),
          labelsRepositoryProvider.overrideWithValue(MockLabelsRepository()),
          taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
          projectRepositoryProvider.overrideWithValue(
            MockProjectRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    tearDown(tearDownTestGetIt);

    test('taskAgentWorkflowProvider wires resolved dependencies', () {
      final workflow = container.read(taskAgentWorkflowProvider);

      expect(workflow, isA<TaskAgentWorkflow>());
      expect(workflow.agentRepository, same(repository));
      expect(workflow.syncService, same(syncService));
      expect(workflow.templateService, same(templateService));
    });

    test(
      'projectAgentWorkflowProvider wires dependencies and persisted-state '
      'notifications',
      () {
        final workflow = container.read(projectAgentWorkflowProvider);

        expect(workflow, isA<ProjectAgentWorkflow>());
        expect(workflow.agentRepository, same(repository));
        expect(workflow.syncService, same(syncService));

        workflow.onPersistedStateChanged?.call('project-agent-001');
        verify(
          () => notifications.notifyUiOnly({
            'project-agent-001',
            agentNotification,
          }),
        ).called(1);
      },
    );

    test(
      'eventAgentWorkflowProvider wires dependencies and persisted-state '
      'notifications',
      () {
        final workflow = container.read(eventAgentWorkflowProvider);

        expect(workflow, isA<EventAgentWorkflow>());
        expect(workflow.agentRepository, same(repository));
        expect(workflow.syncService, same(syncService));
        expect(workflow.templateService, same(templateService));
        // The leaner event workflow has no input-capture or compaction
        // summarizer, but optional services it does take are still resolved.
        expect(workflow.soulDocumentService, isA<MockSoulDocumentService>());
        expect(workflow.domainLogger, isA<MockDomainLogger>());

        workflow.onPersistedStateChanged?.call('event-agent-001');
        verify(
          () => notifications.notifyUiOnly({
            'event-agent-001',
            agentNotification,
          }),
        ).called(1);
      },
    );

    test(
      'improverAgentWorkflowProvider composes the evolution workflow',
      () {
        final workflow = container.read(improverAgentWorkflowProvider);

        expect(workflow, isA<ImproverAgentWorkflow>());
        expect(workflow.repository, same(repository));
        expect(workflow.syncService, same(syncService));
        // The composed evolution workflow is the provider-resolved one.
        expect(
          workflow.evolutionWorkflow,
          same(container.read(templateEvolutionWorkflowProvider)),
        );
        expect(
          workflow.evolutionWorkflow.templateService,
          same(templateService),
        );
      },
    );
  });
}
