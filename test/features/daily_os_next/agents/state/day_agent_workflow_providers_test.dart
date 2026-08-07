import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_week_context_service.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_workflow_providers.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow.dart';
import 'package:lotti/features/daily_os_next/state/day_processing_runtime_provider.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/repository/task_dependency_resolver.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_data/entity_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  group('dayAgentWorkflowProvider', () {
    setUp(() async {
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..registerSingleton<Fts5Db>(MockFts5Db())
            ..registerSingleton<Directory>(Directory.systemTemp);
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
      final dayProcessingOutbox = MockDayProcessingOutboxRepository();
      final container = ProviderContainer(
        overrides: [
          dayProcessingOutboxRepositoryProvider.overrideWithValue(
            dayProcessingOutbox,
          ),
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
      expect(workflow.captureService?.outbox, same(dayProcessingOutbox));
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
      expect(workflow.dayAudioEntryContextService?.journalDb, same(journalDb));
      expect(
        workflow.dayAudioEntryContextService?.assetRoot?.path,
        Directory.systemTemp.path,
      );
      expect(workflow.dependencyResolver, isA<TaskDependencyResolver>());
      expect(
        workflow.dependencyResolver?.journalRepository,
        same(journalRepository),
      );
      workflow.onPersistedStateChanged?.call('day-agent-001');
      verify(
        () => notifications.notifyUiOnly({
          'day-agent-001',
          agentNotification,
        }),
      ).called(1);
    });
  });

  group('dayAgentWakeRunnersProvider', () {
    test('registers exactly the day_agent kind', () {
      final container = ProviderContainer(
        overrides: [
          dayAgentWorkflowProvider.overrideWithValue(MockDayAgentWorkflow()),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(dayAgentWakeRunnersProvider).keys,
        [AgentKinds.dayAgent],
      );
    });

    test(
      'its runner forwards every wake argument to the day workflow',
      () async {
        // The registry is the seam the shared runtime dispatches through, so an
        // argument dropped here would silently change wake behaviour.
        final workflow = MockDayAgentWorkflow();
        when(
          () => workflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer((_) async => const WakeResult(success: true));

        final container = ProviderContainer(
          overrides: [dayAgentWorkflowProvider.overrideWithValue(workflow)],
        );
        addTearDown(container.dispose);

        final identity = makeTestIdentity(
          agentId: 'day_agent:dayplan-2026-08-06',
        );
        final result =
            await container.read(
              dayAgentWakeRunnersProvider,
            )[AgentKinds.dayAgent]!(
              agentIdentity: identity,
              runKey: 'run-7',
              triggerTokens: const {'planning_day:dayplan-2026-08-06'},
              threadId: 'thread-7',
            );

        expect(result.success, isTrue);
        verify(
          () => workflow.execute(
            agentIdentity: identity,
            runKey: 'run-7',
            triggerTokens: const {'planning_day:dayplan-2026-08-06'},
            threadId: 'thread-7',
          ),
        ).called(1);
      },
    );

    test('its runner surfaces a failed WakeResult unchanged', () async {
      // The runtime turns `success: false` into a thrown StateError carrying
      // `error`, so the runner must not swallow or rewrite either field.
      final workflow = MockDayAgentWorkflow();
      when(
        () => workflow.execute(
          agentIdentity: any(named: 'agentIdentity'),
          runKey: any(named: 'runKey'),
          triggerTokens: any(named: 'triggerTokens'),
          threadId: any(named: 'threadId'),
        ),
      ).thenAnswer(
        (_) async => const WakeResult(success: false, error: 'plan write lost'),
      );

      final container = ProviderContainer(
        overrides: [dayAgentWorkflowProvider.overrideWithValue(workflow)],
      );
      addTearDown(container.dispose);

      final result =
          await container.read(
            dayAgentWakeRunnersProvider,
          )[AgentKinds.dayAgent]!(
            agentIdentity: makeTestIdentity(agentId: 'day_agent:d'),
            runKey: 'r',
            triggerTokens: const {},
            threadId: 't',
          );

      expect(result.success, isFalse);
      expect(result.error, 'plan write lost');
    });
  });
}
