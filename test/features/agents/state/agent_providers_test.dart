import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_link.dart' as model;
import 'package:lotti/features/agents/projection/join_plan.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/feedback_extraction_service.dart';
import 'package:lotti/features/agents/service/improver_agent_service.dart';
import 'package:lotti/features/agents/service/project_activity_monitor.dart';
import 'package:lotti/features/agents/service/standing_agreement_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/wake/scheduled_wake_manager.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/features/agents/workflow/improver_agent_workflow.dart';
import 'package:lotti/features/agents/workflow/project_agent_workflow.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/agents/workflow/template_evolution_workflow.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/ollama_embedding_repository.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart'
    show journalDbProvider, loggingServiceProvider, outboxServiceProvider;
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/utils/consts.dart' show enableForkHealingFlag;
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../projects/test_utils.dart';
import '../sync/fork_test_support.dart';
import '../test_utils.dart';
import '../workflow/task_agent_workflow_test_helpers.dart';
import 'agent_providers_test_helpers.dart';

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(const Stream<Set<String>>.empty());
  });

  late MockAgentService mockService;
  late MockAgentRepository mockRepository;
  late MockAiConfigRepository mockAiConfigRepo;

  setUp(() {
    mockService = MockAgentService();
    mockRepository = MockAgentRepository();
    mockAiConfigRepo = MockAiConfigRepository();
  });

  /// Helper to create a [ProviderContainer] with common mocks overridden.
  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        agentServiceProvider.overrideWithValue(mockService),
        agentRepositoryProvider.overrideWithValue(mockRepository),
        aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('dependency providers', () {
    setUp(() async {
      await getIt.reset();
    });

    tearDown(() async {
      await getIt.reset();
    });

    test('maybeUpdateNotificationsProvider returns null when unregistered', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(maybeUpdateNotificationsProvider), isNull);
    });

    test('updateNotificationsProvider throws when unregistered', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(updateNotificationsProvider),
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains(
              'UpdateNotifications is not registered in GetIt',
            ),
          ),
        ),
      );
    });

    test('updateNotificationsProvider returns registered instance', () {
      final mockNotifications = MockUpdateNotifications();
      getIt.registerSingleton<UpdateNotifications>(mockNotifications);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(updateNotificationsProvider),
        same(mockNotifications),
      );
    });

    test('maybeSyncEventProcessorProvider returns null when unregistered', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(maybeSyncEventProcessorProvider), isNull);
    });

    test('maybeSyncEventProcessorProvider returns registered instance', () {
      final mockProcessor = MockSyncEventProcessor();
      getIt.registerSingleton<SyncEventProcessor>(mockProcessor);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(maybeSyncEventProcessorProvider),
        same(mockProcessor),
      );
    });
  });

  group('domainLoggerProvider', () {
    test('creates DomainLogger and seeds initial flags', () async {
      final container = ProviderContainer(
        overrides: [
          loggingServiceProvider.overrideWithValue(LoggingService()),
          configFlagProvider(
            LogDomain.agentRuntime.flagName,
          ).overrideWith((ref) => Stream.value(true)),
          configFlagProvider(
            LogDomain.agentWorkflow.flagName,
          ).overrideWith((ref) => Stream.value(false)),
          configFlagProvider(
            LogDomain.sync.flagName,
          ).overrideWith((ref) => Stream.value(true)),
        ],
      );
      addTearDown(container.dispose);

      // Read + listen to ensure the provider stays alive and processes
      // stream events from configFlagProvider.
      final sub = container.listen(domainLoggerProvider, (_, _) {});
      addTearDown(sub.close);
      final logger = container.read(domainLoggerProvider);
      expect(logger, isA<DomainLogger>());

      // Let the config flag streams emit so ref.listen fires.
      await pumpEventQueue();
      await container.pump();

      expect(logger.enabledDomains, contains(LogDomain.agentRuntime));
      expect(logger.enabledDomains, isNot(contains(LogDomain.agentWorkflow)));
      expect(logger.enabledDomains, contains(LogDomain.sync));
    });

    test('updates enabledDomains when config flags change', () async {
      final runtimeController = StreamController<bool>.broadcast();
      final workflowController = StreamController<bool>.broadcast();
      final syncController = StreamController<bool>.broadcast();
      addTearDown(runtimeController.close);
      addTearDown(workflowController.close);
      addTearDown(syncController.close);

      final container = ProviderContainer(
        overrides: [
          loggingServiceProvider.overrideWithValue(LoggingService()),
          configFlagProvider(
            LogDomain.agentRuntime.flagName,
          ).overrideWith((ref) => runtimeController.stream),
          configFlagProvider(
            LogDomain.agentWorkflow.flagName,
          ).overrideWith((ref) => workflowController.stream),
          configFlagProvider(
            LogDomain.sync.flagName,
          ).overrideWith((ref) => syncController.stream),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(domainLoggerProvider, (_, _) {});
      addTearDown(sub.close);
      final logger = container.read(domainLoggerProvider);

      // Initially empty because streams haven't emitted yet.
      expect(logger.enabledDomains, isEmpty);

      // Emit: agent_runtime=true, agent_workflow=true, sync=false.
      runtimeController.add(true);
      workflowController.add(true);
      syncController.add(false);
      await pumpEventQueue();
      await container.pump();

      expect(logger.enabledDomains, contains(LogDomain.agentRuntime));
      expect(logger.enabledDomains, contains(LogDomain.agentWorkflow));
      expect(logger.enabledDomains, isNot(contains(LogDomain.sync)));

      // Toggle: agent_runtime off, sync on.
      runtimeController.add(false);
      syncController.add(true);
      await pumpEventQueue();
      await container.pump();

      expect(logger.enabledDomains, isNot(contains(LogDomain.agentRuntime)));
      expect(logger.enabledDomains, contains(LogDomain.agentWorkflow));
      expect(logger.enabledDomains, contains(LogDomain.sync));
    });

    test('uses registered DomainLogger and seeds prewarmed flags', () async {
      await getIt.reset();
      final registeredLogger = DomainLogger(loggingService: LoggingService());
      getIt.registerSingleton<DomainLogger>(registeredLogger);
      addTearDown(getIt.reset);
      final runtimeController = StreamController<bool>.broadcast();
      final workflowController = StreamController<bool>.broadcast();
      final syncController = StreamController<bool>.broadcast();
      addTearDown(runtimeController.close);
      addTearDown(workflowController.close);
      addTearDown(syncController.close);

      final container = ProviderContainer(
        overrides: [
          configFlagProvider(
            LogDomain.agentRuntime.flagName,
          ).overrideWith((ref) => runtimeController.stream),
          configFlagProvider(
            LogDomain.agentWorkflow.flagName,
          ).overrideWith((ref) => workflowController.stream),
          configFlagProvider(
            LogDomain.sync.flagName,
          ).overrideWith((ref) => syncController.stream),
        ],
      );
      addTearDown(container.dispose);
      final runtimeSub = container.listen(
        configFlagProvider(LogDomain.agentRuntime.flagName),
        (_, _) {},
      );
      final workflowSub = container.listen(
        configFlagProvider(LogDomain.agentWorkflow.flagName),
        (_, _) {},
      );
      final syncSub = container.listen(
        configFlagProvider(LogDomain.sync.flagName),
        (_, _) {},
      );
      addTearDown(runtimeSub.close);
      addTearDown(workflowSub.close);
      addTearDown(syncSub.close);

      runtimeController.add(true);
      workflowController.add(false);
      syncController.add(false);
      await pumpEventQueue();

      final logger = container.read(domainLoggerProvider);

      expect(logger, same(registeredLogger));
      expect(logger.enabledDomains, contains(LogDomain.agentRuntime));
    });
  });

  group('agentDatabaseProvider', () {
    test('creates database and closes on dispose', () async {
      final db = AgentDatabase(inMemoryDatabase: true, background: false);
      getIt.registerSingleton<AgentDatabase>(db);
      addTearDown(() async {
        await db.close();
        await getIt.reset();
      });

      final container = ProviderContainer();

      final resolved = container.read(agentDatabaseProvider);
      expect(resolved, isA<AgentDatabase>());
      expect(resolved, same(db));

      // Dispose should not error.
      container.dispose();
    });
  });

  group('agentRepositoryProvider', () {
    test('creates repository wrapping the database', () async {
      final db = AgentDatabase(inMemoryDatabase: true, background: false);
      getIt.registerSingleton<AgentDatabase>(db);
      addTearDown(() async {
        await db.close();
        await getIt.reset();
      });

      final container = ProviderContainer(
        overrides: [
          domainLoggerProvider.overrideWithValue(
            DomainLogger(loggingService: LoggingService()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final repo = container.read(agentRepositoryProvider);
      expect(repo, isA<AgentRepository>());
    });
  });

  group('agentSyncServiceProvider', () {
    test('injects repository, outbox, and vector clock service', () async {
      final mockOutboxService = MockOutboxService();
      final mockVectorClockService = MockVectorClockService();
      getIt.registerSingleton<VectorClockService>(mockVectorClockService);
      addTearDown(() async => getIt.reset());

      const stampedClock = VectorClock({'host': 1});
      when(
        () => mockVectorClockService.getNextVectorClock(
          previous: any(named: 'previous'),
        ),
      ).thenAnswer((_) async => stampedClock);

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepository),
          outboxServiceProvider.overrideWithValue(mockOutboxService),
        ],
      );
      addTearDown(container.dispose);

      final syncService = container.read(agentSyncServiceProvider);

      // Verify the repository was injected.
      expect(syncService.repository, same(mockRepository));

      // Verify the outbox service was injected by exercising upsertEntity.
      final entity = makeTestIdentity();
      when(() => mockRepository.upsertEntity(any())).thenAnswer((_) async {});
      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      await syncService.upsertEntity(entity);

      // Entity is stamped with vector clock before persisting.
      final stamped = entity.copyWith(vectorClock: stampedClock);
      verify(() => mockRepository.upsertEntity(stamped)).called(1);
      verify(() => mockOutboxService.enqueueMessage(any())).called(1);
    });
  });

  group('projectActivityMonitorProvider', () {
    test('creates the monitor from injected dependencies', () {
      final mockNotifications = MockUpdateNotifications();
      final mockSyncService = MockAgentSyncService();
      final mockProjectRepository = MockProjectRepository();
      final logger = DomainLogger(loggingService: LoggingService());

      final container = ProviderContainer(
        overrides: [
          updateNotificationsProvider.overrideWithValue(mockNotifications),
          agentRepositoryProvider.overrideWithValue(mockRepository),
          projectRepositoryProvider.overrideWithValue(mockProjectRepository),
          agentSyncServiceProvider.overrideWithValue(mockSyncService),
          domainLoggerProvider.overrideWithValue(logger),
        ],
      );
      addTearDown(container.dispose);

      final monitor = container.read(projectActivityMonitorProvider);

      expect(monitor, isA<ProjectActivityMonitor>());

      // Dispose should exercise the provider cleanup hook without errors.
      container.dispose();
    });
  });

  group('agentReportProvider', () {
    test('returns report entity when service finds one', () async {
      final report = makeTestReport();

      when(
        () => mockService.getAgentReport(kTestAgentId),
      ).thenAnswer((_) async => report);

      final container = createContainer();
      final result = await container.read(
        agentReportProvider(kTestAgentId).future,
      );

      expect(result, equals(report));
      verify(() => mockService.getAgentReport(kTestAgentId)).called(1);
    });

    test('returns null when service finds no report', () async {
      when(
        () => mockService.getAgentReport(kTestAgentId),
      ).thenAnswer((_) async => null);

      final container = createContainer();
      final result = await container.read(
        agentReportProvider(kTestAgentId).future,
      );

      expect(result, isNull);
      verify(() => mockService.getAgentReport(kTestAgentId)).called(1);
    });
  });

  group('agentStateProvider', () {
    test('returns state entity when repository finds one', () async {
      final state = makeTestState();

      when(
        () => mockRepository.getAgentState(kTestAgentId),
      ).thenAnswer((_) async => state);

      final container = createContainer();
      final result = await container.read(
        agentStateProvider(kTestAgentId).future,
      );

      expect(result, equals(state));
      verify(() => mockRepository.getAgentState(kTestAgentId)).called(1);
    });

    test('returns null when repository finds no state', () async {
      when(
        () => mockRepository.getAgentState(kTestAgentId),
      ).thenAnswer((_) async => null);

      final container = createContainer();
      final result = await container.read(
        agentStateProvider(kTestAgentId).future,
      );

      expect(result, isNull);
      verify(() => mockRepository.getAgentState(kTestAgentId)).called(1);
    });
  });

  group('agentIdentityProvider', () {
    test('returns identity entity when service finds one', () async {
      final identity = makeTestIdentity();

      when(
        () => mockService.getAgent(kTestAgentId),
      ).thenAnswer((_) async => identity);

      final container = createContainer();
      final result = await container.read(
        agentIdentityProvider(kTestAgentId).future,
      );

      expect(result, equals(identity));
      verify(() => mockService.getAgent(kTestAgentId)).called(1);
    });

    test('returns null when service finds no agent', () async {
      when(
        () => mockService.getAgent(kTestAgentId),
      ).thenAnswer((_) async => null);

      final container = createContainer();
      final result = await container.read(
        agentIdentityProvider(kTestAgentId).future,
      );

      expect(result, isNull);
      verify(() => mockService.getAgent(kTestAgentId)).called(1);
    });
  });

  group('taskAgentWorkflowProvider', () {
    late MockAiInputRepository mockAiInputRepository;
    late MockAiConfigRepository mockAiConfigRepository;
    late MockJournalDb mockJournalDb;
    late MockCloudInferenceRepository mockCloudInferenceRepository;
    late MockJournalRepository mockJournalRepository;
    late MockChecklistRepository mockChecklistRepository;
    late MockLabelsRepository mockLabelsRepository;
    late MockAgentSyncService mockAgentSyncService;
    late MockAgentTemplateService mockAgentTemplateService;
    late MockUpdateNotifications mockNotifications;
    late DomainLogger domainLogger;

    setUp(() async {
      await getIt.reset();
      mockAiInputRepository = MockAiInputRepository();
      mockAiConfigRepository = MockAiConfigRepository();
      mockJournalDb = MockJournalDb();
      mockCloudInferenceRepository = MockCloudInferenceRepository();
      mockJournalRepository = MockJournalRepository();
      mockChecklistRepository = MockChecklistRepository();
      mockLabelsRepository = MockLabelsRepository();
      mockAgentSyncService = MockAgentSyncService();
      mockAgentTemplateService = MockAgentTemplateService();
      mockNotifications = MockUpdateNotifications();
      domainLogger = DomainLogger(loggingService: LoggingService());
    });

    tearDown(() async {
      await getIt.reset();
    });

    ProviderContainer createTaskWorkflowContainer() {
      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepository),
          conversationRepositoryProvider.overrideWith(
            ConversationRepository.new,
          ),
          aiInputRepositoryProvider.overrideWithValue(mockAiInputRepository),
          aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepository),
          journalDbProvider.overrideWithValue(mockJournalDb),
          cloudInferenceRepositoryProvider.overrideWithValue(
            mockCloudInferenceRepository,
          ),
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          checklistRepositoryProvider.overrideWithValue(
            mockChecklistRepository,
          ),
          labelsRepositoryProvider.overrideWithValue(mockLabelsRepository),
          agentSyncServiceProvider.overrideWithValue(mockAgentSyncService),
          agentTemplateServiceProvider.overrideWithValue(
            mockAgentTemplateService,
          ),
          updateNotificationsProvider.overrideWithValue(mockNotifications),
          domainLoggerProvider.overrideWithValue(domainLogger),
          projectRepositoryProvider.overrideWithValue(
            MockProjectRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('leaves embedding dependencies null when they are unregistered', () {
      final container = createTaskWorkflowContainer();

      final workflow = container.read(taskAgentWorkflowProvider);

      expect(workflow.embeddingStore, isNull);
      expect(workflow.embeddingRepository, isNull);
    });

    test('wires optional embedding dependencies from GetIt', () {
      final mockEmbeddingStore = MockEmbeddingStore();
      final mockEmbeddingRepository = MockOllamaEmbeddingRepository();
      getIt
        ..registerSingleton<EmbeddingStore>(mockEmbeddingStore)
        ..registerSingleton<OllamaEmbeddingRepository>(
          mockEmbeddingRepository,
        );

      final container = createTaskWorkflowContainer();
      final workflow = container.read(taskAgentWorkflowProvider);

      expect(workflow.embeddingStore, same(mockEmbeddingStore));
      expect(workflow.embeddingRepository, same(mockEmbeddingRepository));
    });

    test('wires optional notification bridge from GetIt', () {
      final mockNotificationRepository = MockNotificationRepository();
      getIt.registerSingleton<NotificationRepository>(
        mockNotificationRepository,
      );

      final container = createTaskWorkflowContainer();
      final workflow = container.read(taskAgentWorkflowProvider);

      expect(workflow.changeSetNotificationService, isNotNull);
    });
  });

  group('agentInitializationProvider', () {
    late InitProviderBench bench;

    setUp(() async {
      bench = await InitProviderBench.create();
    });

    tearDown(tearDownTestGetIt);

    test(
      'starts orchestrator and restores subscriptions when enabled',
      () async {
        final container = bench.createContainer();
        await bench.initAndSubscribe(container);

        verify(() => bench.mockOrchestrator.start(any())).called(1);
        verify(() => bench.mockTemplateService.seedDefaults()).called(1);
        verify(
          () => bench.mockTaskAgentService.restoreSubscriptions(),
        ).called(1);
        verify(
          () => bench.mockDayAgentService.restoreSubscriptions(),
        ).called(1);
      },
    );

    test('starts scheduled wake manager when enabled', () async {
      final container = bench.createContainer();
      await bench.initAndSubscribe(container);

      verify(() => bench.mockScheduledWakeManager.start()).called(1);
    });

    test('starts the project activity monitor when enabled', () async {
      final container = bench.createContainer();
      await bench.initAndSubscribe(container);

      verify(() => bench.mockProjectActivityMonitor.start()).called(1);
    });

    test('sets wakeExecutor on orchestrator when enabled', () async {
      final container = bench.createContainer();
      await bench.initAndSubscribe(container);

      // The orchestrator's wakeExecutor setter should have been called.
      verify(() => bench.mockOrchestrator.wakeExecutor = any()).called(1);
    });

    test(
      'wakeExecutor returns null when agent identity not found',
      () async {
        when(
          () => bench.mockService.getAgent(kTestAgentId),
        ).thenAnswer((_) async => null);

        final capture = bench.captureWakeExecutor();
        final container = bench.createContainer();
        await bench.initAndSubscribe(container);

        final result = await capture.executor(
          kTestAgentId,
          'run-key-1',
          {'tok-a'},
          'thread-1',
        );

        expect(result, isNull);
        verify(() => bench.mockService.getAgent(kTestAgentId)).called(1);
      },
    );

    test(
      'wakeExecutor executes workflow and returns mutated entries',
      () async {
        final identity = makeTestIdentity();
        final mutated = <String, VectorClock>{
          'entry-1': const VectorClock({}),
        };

        when(
          () => bench.mockService.getAgent(kTestAgentId),
        ).thenAnswer((_) async => identity);
        when(
          () => bench.mockWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer(
          (_) async => WakeResult(success: true, mutatedEntries: mutated),
        );

        final capture = bench.captureWakeExecutor();
        final container = bench.createContainer();
        await bench.initAndSubscribe(container);

        final result = await capture.executor(
          kTestAgentId,
          'run-key-1',
          {'tok-a'},
          'thread-1',
        );

        expect(result, equals(mutated));
        verify(
          () => bench.mockWorkflow.execute(
            agentIdentity: identity,
            runKey: 'run-key-1',
            triggerTokens: {'tok-a'},
            threadId: 'thread-1',
          ),
        ).called(1);
      },
    );

    test(
      'wakeExecutor throws when workflow returns unsuccessful result',
      () async {
        final identity = makeTestIdentity();

        when(
          () => bench.mockService.getAgent(kTestAgentId),
        ).thenAnswer((_) async => identity);
        when(
          () => bench.mockWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer(
          (_) async => const WakeResult(
            success: false,
            error: 'workflow failed',
          ),
        );

        final capture = bench.captureWakeExecutor();
        final container = bench.createContainer();
        await bench.initAndSubscribe(container);

        await expectLater(
          capture.executor(
            kTestAgentId,
            'run-key-fail',
            {'tok-fail'},
            'thread-fail',
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'workflow failed',
            ),
          ),
        );

        final mockNotifications =
            getIt<UpdateNotifications>() as MockUpdateNotifications;
        verifyNever(
          () => mockNotifications.notify(
            {kTestAgentId, 'AGENT_CHANGED'},
          ),
        );
      },
    );

    test(
      'wakeExecutor fires update notification after successful execution',
      () async {
        final identity = makeTestIdentity();
        final mutated = <String, VectorClock>{
          'entry-1': const VectorClock({}),
        };

        when(
          () => bench.mockService.getAgent(kTestAgentId),
        ).thenAnswer((_) async => identity);
        when(
          () => bench.mockWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer(
          (_) async => WakeResult(success: true, mutatedEntries: mutated),
        );

        final capture = bench.captureWakeExecutor();
        final container = bench.createContainer();
        await bench.initAndSubscribe(container);

        // Execute the wakeExecutor — this should fire a notification
        // with the agent ID so detail providers self-invalidate.
        await capture.executor(
          kTestAgentId,
          'run-key-2',
          {'tok-b'},
          'thread-2',
        );

        final mockNotifications =
            getIt<UpdateNotifications>() as MockUpdateNotifications;
        verify(
          () => mockNotifications.notifyUiOnly(
            {kTestAgentId, 'AGENT_CHANGED'},
          ),
        ).called(1);
      },
    );

    test(
      'wakeExecutor includes templateId in notification when template exists',
      () async {
        final identity = makeTestIdentity();
        final mutated = <String, VectorClock>{
          'entry-1': const VectorClock({}),
        };
        final template = makeTestTemplate(
          id: 'tpl-1',
          agentId: 'tpl-1',
        );

        when(
          () => bench.mockService.getAgent(kTestAgentId),
        ).thenAnswer((_) async => identity);
        when(
          () => bench.mockWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer(
          (_) async => WakeResult(success: true, mutatedEntries: mutated),
        );
        when(
          () => bench.mockTemplateService.getTemplateForAgent(kTestAgentId),
        ).thenAnswer((_) async => template);

        final capture = bench.captureWakeExecutor();
        final container = bench.createContainer();
        await bench.initAndSubscribe(container);

        await capture.executor(
          kTestAgentId,
          'run-key-tpl',
          {'tok-c'},
          'thread-tpl',
        );

        final mockNotifications =
            getIt<UpdateNotifications>() as MockUpdateNotifications;
        verify(
          () => mockNotifications.notifyUiOnly(
            {kTestAgentId, 'tpl-1', 'AGENT_CHANGED'},
          ),
        ).called(1);
      },
    );

    test(
      'wakeExecutor still notifies without templateId when the template '
      'lookup throws',
      () async {
        final identity = makeTestIdentity();
        final mutated = <String, VectorClock>{
          'entry-1': const VectorClock({}),
        };

        when(
          () => bench.mockService.getAgent(kTestAgentId),
        ).thenAnswer((_) async => identity);
        when(
          () => bench.mockWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer(
          (_) async => WakeResult(success: true, mutatedEntries: mutated),
        );
        // The template lookup failing must NOT fail the completed wake:
        // the error is swallowed and the notification fires without the
        // templateId token.
        when(
          () => bench.mockTemplateService.getTemplateForAgent(kTestAgentId),
        ).thenThrow(StateError('template lookup failed'));

        final capture = bench.captureWakeExecutor();
        final container = bench.createContainer();
        await bench.initAndSubscribe(container);

        final result = await capture.executor(
          kTestAgentId,
          'run-key-err',
          {'tok-e'},
          'thread-err',
        );
        expect(result, mutated);

        final mockNotifications =
            getIt<UpdateNotifications>() as MockUpdateNotifications;
        verify(
          () => mockNotifications.notifyUiOnly(
            {kTestAgentId, 'AGENT_CHANGED'},
          ),
        ).called(1);
      },
    );

    test(
      'wakeExecutor includes taskId and parent projectId for task-agent wakes',
      () async {
        final identity = makeTestIdentity();
        final mutated = <String, VectorClock>{
          'entry-1': const VectorClock({}),
        };
        const taskId = 'task-123';
        const projectId = 'project-123';
        final timestamp = DateTime(2024, 3, 15, 10);

        when(
          () => bench.mockService.getAgent(kTestAgentId),
        ).thenAnswer((_) async => identity);
        when(
          () => bench.mockWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer(
          (_) async => WakeResult(success: true, mutatedEntries: mutated),
        );
        when(
          () => bench.mockRepository.getLinksFrom(
            kTestAgentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer(
          (_) async => [
            model.AgentLink.agentTask(
              id: 'task-link-1',
              fromId: kTestAgentId,
              toId: taskId,
              createdAt: timestamp,
              updatedAt: timestamp,
              vectorClock: null,
            ),
          ],
        );
        when(
          () => bench.mockProjectRepository.getProjectForTask(taskId),
        ).thenAnswer((_) async => makeTestProject(id: projectId));

        final capture = bench.captureWakeExecutor();
        final container = bench.createContainer();
        await bench.initAndSubscribe(container);

        await capture.executor(
          kTestAgentId,
          'run-key-task-project',
          {'tok-project'},
          'thread-task-project',
        );

        final mockNotifications =
            getIt<UpdateNotifications>() as MockUpdateNotifications;
        verify(
          () => mockNotifications.notifyUiOnly(
            {kTestAgentId, taskId, projectId, agentNotification},
          ),
        ).called(1);
      },
    );

    test(
      'wakeExecutor still notifies when getTemplateForAgent throws',
      () async {
        final identity = makeTestIdentity();
        final mutated = <String, VectorClock>{
          'entry-1': const VectorClock({}),
        };

        when(
          () => bench.mockService.getAgent(kTestAgentId),
        ).thenAnswer((_) async => identity);
        when(
          () => bench.mockWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer(
          (_) async => WakeResult(success: true, mutatedEntries: mutated),
        );
        when(
          () => bench.mockTemplateService.getTemplateForAgent(kTestAgentId),
        ).thenThrow(Exception('db connection lost'));

        final capture = bench.captureWakeExecutor();
        final container = bench.createContainer();
        await bench.initAndSubscribe(container);

        final result = await capture.executor(
          kTestAgentId,
          'run-key-err',
          {'tok-d'},
          'thread-err',
        );

        // Wake still succeeds — returns mutated entries
        expect(result, mutated);

        // Notification is still sent with just agentId (no templateId)
        final mockNotifications =
            getIt<UpdateNotifications>() as MockUpdateNotifications;
        verify(
          () => mockNotifications.notifyUiOnly(
            {kTestAgentId, 'AGENT_CHANGED'},
          ),
        ).called(1);
      },
    );

    test(
      'wakeExecutor routes improver agent to improver workflow',
      () async {
        final identity = makeTestIdentity(
          kind: AgentKinds.templateImprover,
        );
        final mutated = <String, VectorClock>{
          'entry-improver': const VectorClock({}),
        };

        when(
          () => bench.mockService.getAgent(kTestAgentId),
        ).thenAnswer((_) async => identity);
        when(
          () => bench.mockImproverWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer(
          (_) async => WakeResult(success: true, mutatedEntries: mutated),
        );

        final capture = bench.captureWakeExecutor();
        final container = bench.createContainer();
        await bench.initAndSubscribe(container);

        final result = await capture.executor(
          kTestAgentId,
          'run-key-improver',
          {'tok-a'},
          'thread-improver',
        );

        expect(result, equals(mutated));
        verify(
          () => bench.mockImproverWorkflow.execute(
            agentIdentity: identity,
            runKey: 'run-key-improver',
            threadId: 'thread-improver',
          ),
        ).called(1);

        // Should NOT call task agent workflow.
        verifyNever(
          () => bench.mockWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        );
      },
    );

    test(
      'wakeExecutor routes project agent to project workflow',
      () async {
        final identity = makeTestIdentity(
          kind: AgentKinds.projectAgent,
        );
        final mutated = <String, VectorClock>{
          'entry-project': const VectorClock({}),
        };

        when(
          () => bench.mockService.getAgent(kTestAgentId),
        ).thenAnswer((_) async => identity);
        when(
          () => bench.mockProjectWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer(
          (_) async => WakeResult(success: true, mutatedEntries: mutated),
        );

        final capture = bench.captureWakeExecutor();
        final container = bench.createContainer();
        await bench.initAndSubscribe(container);

        final result = await capture.executor(
          kTestAgentId,
          'run-key-project',
          {'tok-p'},
          'thread-project',
        );

        expect(result, equals(mutated));
        verify(
          () => bench.mockProjectWorkflow.execute(
            agentIdentity: identity,
            runKey: 'run-key-project',
            triggerTokens: {'tok-p'},
            threadId: 'thread-project',
          ),
        ).called(1);

        // Notification still fires for the project agent.
        final mockNotifications =
            getIt<UpdateNotifications>() as MockUpdateNotifications;
        verify(
          () => mockNotifications.notifyUiOnly(
            {kTestAgentId, 'AGENT_CHANGED'},
          ),
        ).called(1);

        // Should NOT call task or improver workflow.
        verifyNever(
          () => bench.mockWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        );
        verifyNever(
          () => bench.mockImproverWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            threadId: any(named: 'threadId'),
          ),
        );
      },
    );

    test(
      'wakeExecutor routes day agent to day workflow',
      () async {
        final identity = makeTestIdentity(
          kind: AgentKinds.dayAgent,
        );
        final mutated = <String, VectorClock>{
          'entry-day': const VectorClock({}),
        };

        when(
          () => bench.mockService.getAgent(kTestAgentId),
        ).thenAnswer((_) async => identity);
        when(
          () => bench.mockDayWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer(
          (_) async => WakeResult(success: true, mutatedEntries: mutated),
        );

        final capture = bench.captureWakeExecutor();
        final container = bench.createContainer();
        await bench.initAndSubscribe(container);

        final result = await capture.executor(
          kTestAgentId,
          'run-key-day',
          {'dayplan-2026-05-25'},
          'thread-day',
        );

        expect(result, equals(mutated));
        verify(
          () => bench.mockDayWorkflow.execute(
            agentIdentity: identity,
            runKey: 'run-key-day',
            triggerTokens: {'dayplan-2026-05-25'},
            threadId: 'thread-day',
          ),
        ).called(1);

        final mockNotifications =
            getIt<UpdateNotifications>() as MockUpdateNotifications;
        verify(
          () => mockNotifications.notifyUiOnly(
            {kTestAgentId, 'dayplan-2026-05-25', 'AGENT_CHANGED'},
          ),
        ).called(1);

        verifyNever(
          () => bench.mockWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        );
      },
    );

    test(
      'wakeExecutor throws when day workflow returns failure',
      () async {
        final identity = makeTestIdentity(
          kind: AgentKinds.dayAgent,
        );

        when(
          () => bench.mockService.getAgent(kTestAgentId),
        ).thenAnswer((_) async => identity);
        when(
          () => bench.mockDayWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer(
          (_) async => const WakeResult(
            success: false,
            error: 'day workflow failed',
          ),
        );

        final capture = bench.captureWakeExecutor();
        final container = bench.createContainer();
        await bench.initAndSubscribe(container);

        await expectLater(
          capture.executor(
            kTestAgentId,
            'run-key-day-fail',
            {'dayplan-2026-05-25'},
            'thread-day-fail',
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'day workflow failed',
            ),
          ),
        );

        final mockNotifications =
            getIt<UpdateNotifications>() as MockUpdateNotifications;
        verifyNever(
          () => mockNotifications.notifyUiOnly(any()),
        );
      },
    );

    test(
      'wakeExecutor throws when project workflow returns failure',
      () async {
        final identity = makeTestIdentity(
          kind: AgentKinds.projectAgent,
        );

        when(
          () => bench.mockService.getAgent(kTestAgentId),
        ).thenAnswer((_) async => identity);
        when(
          () => bench.mockProjectWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer(
          (_) async => const WakeResult(
            success: false,
            error: 'project failed',
          ),
        );

        final capture = bench.captureWakeExecutor();
        final container = bench.createContainer();
        await bench.initAndSubscribe(container);

        await expectLater(
          capture.executor(
            kTestAgentId,
            'run-key-project-fail',
            {'tok-p'},
            'thread-project-fail',
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'project failed',
            ),
          ),
        );
      },
    );

    test(
      'wakeExecutor uses id tiebreaker when task links share createdAt',
      () async {
        final identity = makeTestIdentity();
        final mutated = <String, VectorClock>{
          'entry-tie': const VectorClock({}),
        };
        // Two task links with the SAME createdAt — sort must fall back to
        // id comparison (descending), so 'task-aaa' wins over 'task-bbb'
        // (because the sort is `b.id.compareTo(a.id)`).
        final timestamp = DateTime(2024, 3, 15, 10);

        when(
          () => bench.mockService.getAgent(kTestAgentId),
        ).thenAnswer((_) async => identity);
        when(
          () => bench.mockWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer(
          (_) async => WakeResult(success: true, mutatedEntries: mutated),
        );
        when(
          () => bench.mockRepository.getLinksFrom(
            kTestAgentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer(
          (_) async => [
            model.AgentLink.agentTask(
              id: 'task-link-aaa',
              fromId: kTestAgentId,
              toId: 'task-aaa',
              createdAt: timestamp,
              updatedAt: timestamp,
              vectorClock: null,
            ),
            model.AgentLink.agentTask(
              id: 'task-link-bbb',
              fromId: kTestAgentId,
              toId: 'task-bbb',
              createdAt: timestamp,
              updatedAt: timestamp,
              vectorClock: null,
            ),
          ],
        );

        final capture = bench.captureWakeExecutor();
        final container = bench.createContainer();
        await bench.initAndSubscribe(container);

        await capture.executor(
          kTestAgentId,
          'run-key-tie',
          {'tok-tie'},
          'thread-tie',
        );

        // After sort by id desc, 'task-link-bbb' wins (b > a). It should
        // appear in the notification token set.
        final mockNotifications =
            getIt<UpdateNotifications>() as MockUpdateNotifications;
        verify(
          () => mockNotifications.notifyUiOnly(
            {kTestAgentId, 'task-bbb', 'AGENT_CHANGED'},
          ),
        ).called(1);
      },
    );

    test(
      'wakeExecutor swallows getLinksFrom failure and still notifies',
      () async {
        final identity = makeTestIdentity();
        final mutated = <String, VectorClock>{
          'entry-err': const VectorClock({}),
        };

        when(
          () => bench.mockService.getAgent(kTestAgentId),
        ).thenAnswer((_) async => identity);
        when(
          () => bench.mockWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            triggerTokens: any(named: 'triggerTokens'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer(
          (_) async => WakeResult(success: true, mutatedEntries: mutated),
        );
        when(
          () => bench.mockRepository.getLinksFrom(
            kTestAgentId,
            type: AgentLinkTypes.agentTask,
          ),
        ).thenThrow(Exception('repo down'));

        final capture = bench.captureWakeExecutor();
        final container = bench.createContainer();
        await bench.initAndSubscribe(container);

        // The wake itself still succeeds — the catch swallows the repo
        // failure and proceeds with the notification (without taskId).
        final result = await capture.executor(
          kTestAgentId,
          'run-key-err',
          {'tok-err'},
          'thread-err',
        );
        expect(result, mutated);

        final mockNotifications =
            getIt<UpdateNotifications>() as MockUpdateNotifications;
        verify(
          () => mockNotifications.notifyUiOnly(
            {kTestAgentId, 'AGENT_CHANGED'},
          ),
        ).called(1);
      },
    );

    test(
      'wakeExecutor throws when improver workflow returns failure',
      () async {
        final identity = makeTestIdentity(
          kind: AgentKinds.templateImprover,
        );

        when(
          () => bench.mockService.getAgent(kTestAgentId),
        ).thenAnswer((_) async => identity);
        when(
          () => bench.mockImproverWorkflow.execute(
            agentIdentity: any(named: 'agentIdentity'),
            runKey: any(named: 'runKey'),
            threadId: any(named: 'threadId'),
          ),
        ).thenAnswer(
          (_) async => const WakeResult(
            success: false,
            error: 'improver failed',
          ),
        );

        final capture = bench.captureWakeExecutor();
        final container = bench.createContainer();
        await bench.initAndSubscribe(container);

        await expectLater(
          capture.executor(
            kTestAgentId,
            'run-key-fail',
            {'tok-a'},
            'thread-fail',
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'improver failed',
            ),
          ),
        );
      },
    );

    test('wires repository and orchestrator into SyncEventProcessor', () async {
      final mockProcessor = MockSyncEventProcessor();
      final mockHandler = MockBackfillResponseHandler();
      when(() => mockProcessor.backfillResponseHandler).thenReturn(mockHandler);
      getIt.registerSingleton<SyncEventProcessor>(mockProcessor);

      final container = bench.createContainer();
      await bench.initAndSubscribe(container);

      verify(
        () => mockProcessor.wakeOrchestrator = bench.mockOrchestrator,
      ).called(1);
      verify(
        () => mockProcessor.agentRepository = any(that: isNotNull),
      ).called(1);
      verify(
        () => mockHandler.agentRepository = any(that: isNotNull),
      ).called(1);
    });

    test('clears SyncEventProcessor fields on dispose', () async {
      final mockProcessor = MockSyncEventProcessor();
      final mockHandler = MockBackfillResponseHandler();
      when(() => mockProcessor.backfillResponseHandler).thenReturn(mockHandler);
      getIt.registerSingleton<SyncEventProcessor>(mockProcessor);

      final container = bench.createContainer();

      final sub = container.listen(
        agentInitializationProvider,
        (_, _) {},
      );

      await container.read(agentInitializationProvider.future);

      sub.close();
      container.dispose();

      verify(() => mockProcessor.wakeOrchestrator = null).called(1);
      verify(() => mockProcessor.agentRepository = null).called(1);
      verify(() => mockHandler.agentRepository = null).called(1);
    });

    test('stops orchestrator on dispose', () async {
      final container = bench.createContainer();

      final sub = container.listen(
        agentInitializationProvider,
        (_, _) {},
      );

      await container.read(agentInitializationProvider.future);

      sub.close();
      container.dispose();

      verify(() => bench.mockOrchestrator.stop()).called(1);
    });
  });

  group('wakeQueueProvider', () {
    test('supports enqueue and dequeue', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final queue = container.read(wakeQueueProvider);

      // Queue starts empty.
      expect(queue.dequeue(), isNull);

      // Enqueue a job and dequeue it.
      final job = WakeJob(
        agentId: kTestAgentId,
        runKey: 'run-1',
        reason: 'subscription',
        triggerTokens: {'tok-a'},
        createdAt: DateTime(2024, 3, 15),
      );
      final added = queue.enqueue(job);
      expect(added, isTrue);

      final dequeued = queue.dequeue();
      expect(dequeued, isNotNull);
      expect(dequeued!.agentId, kTestAgentId);
      expect(dequeued.runKey, 'run-1');
    });

    test('deduplicates by run key', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final queue = container.read(wakeQueueProvider);

      final job = WakeJob(
        agentId: kTestAgentId,
        runKey: 'dup-key',
        reason: 'subscription',
        triggerTokens: {'tok'},
        createdAt: DateTime(2024, 3, 15),
      );
      expect(queue.enqueue(job), isTrue);
      expect(queue.enqueue(job), isFalse);
    });
  });

  group('wakeRunnerProvider', () {
    test('supports lock acquisition and release', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final runner = container.read(wakeRunnerProvider);

      // Acquire lock.
      final acquired = await runner.tryAcquire(kTestAgentId);
      expect(acquired, isTrue);
      expect(runner.isRunning(kTestAgentId), isTrue);

      // Release lock.
      runner.release(kTestAgentId);
      expect(runner.isRunning(kTestAgentId), isFalse);
    });

    test('disposes runner when container is disposed', () async {
      final container = ProviderContainer();

      final runner = container.read(wakeRunnerProvider);
      final acquired = await runner.tryAcquire(kTestAgentId);
      expect(acquired, isTrue);

      // Dispose should call runner.dispose() without error.
      container.dispose();
    });
  });

  group('wakeOrchestratorProvider', () {
    test('creates orchestrator with injected dependencies', () {
      final mockRepo = MockAgentRepository();
      final queue = WakeQueue();
      final runner = WakeRunner();
      addTearDown(runner.dispose);

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepo),
          wakeQueueProvider.overrideWithValue(queue),
          wakeRunnerProvider.overrideWithValue(runner),
          domainLoggerProvider.overrideWithValue(
            DomainLogger(loggingService: LoggingService()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final orchestrator = container.read(wakeOrchestratorProvider);
      expect(orchestrator, isA<WakeOrchestrator>());
      expect(orchestrator.repository, same(mockRepo));
      expect(orchestrator.queue, same(queue));
      expect(orchestrator.runner, same(runner));
    });

    test(
      'wires persisted-state callback to UpdateNotifications when registered',
      () async {
        final mockRepo = MockAgentRepository();
        final queue = WakeQueue();
        final runner = WakeRunner();
        final mockNotifications = MockUpdateNotifications();
        addTearDown(runner.dispose);

        when(
          () => mockNotifications.notifyUiOnly(any()),
        ).thenReturn(null);

        await getIt.reset();
        getIt.registerSingleton<UpdateNotifications>(mockNotifications);
        addTearDown(getIt.reset);

        final container = ProviderContainer(
          overrides: [
            agentRepositoryProvider.overrideWithValue(mockRepo),
            wakeQueueProvider.overrideWithValue(queue),
            wakeRunnerProvider.overrideWithValue(runner),
            domainLoggerProvider.overrideWithValue(
              DomainLogger(loggingService: LoggingService()),
            ),
          ],
        );
        addTearDown(container.dispose);

        final orchestrator = container.read(wakeOrchestratorProvider);
        orchestrator.onPersistedStateChanged?.call(kTestAgentId);

        verify(
          () => mockNotifications.notifyUiOnly(
            {kTestAgentId, agentNotification},
          ),
        ).called(1);
      },
    );

    test('wires syncEntityWriter to AgentSyncService', () async {
      final mockRepo = MockAgentRepository();
      final mockSyncService = MockAgentSyncService();
      final queue = WakeQueue();
      final runner = WakeRunner();
      addTearDown(runner.dispose);
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepo),
          agentSyncServiceProvider.overrideWithValue(mockSyncService),
          wakeQueueProvider.overrideWithValue(queue),
          wakeRunnerProvider.overrideWithValue(runner),
          domainLoggerProvider.overrideWithValue(
            DomainLogger(loggingService: LoggingService()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final orchestrator = container.read(wakeOrchestratorProvider);
      final entity = makeTestState(
        id: 'state-sync-writer',
        agentId: 'agent-sync-writer',
      );

      await orchestrator.syncEntityWriter!(entity);

      verify(() => mockSyncService.upsertEntity(entity)).called(1);
    });

    test('wires the fork-healing hook to the journalDb flag and the sync '
        'service', () async {
      // Exercises the PRODUCTION wiring: the hook reads the
      // `enable_fork_healing` flag through journalDb per invocation and,
      // when on, heals through the provider's sync service.
      final bench = makeForkBench();
      await seedForkInto(bench.repo, head: 'b'); // a 2-head fork {a, b}
      final queue = WakeQueue();
      final runner = WakeRunner();
      addTearDown(runner.dispose);

      final journalDb = MockJournalDb();
      var flag = false;
      when(
        () => journalDb.getConfigFlag(enableForkHealingFlag),
      ).thenAnswer((_) async => flag);

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(MockAgentRepository()),
          agentSyncServiceProvider.overrideWithValue(bench.service),
          journalDbProvider.overrideWithValue(journalDb),
          wakeQueueProvider.overrideWithValue(queue),
          wakeRunnerProvider.overrideWithValue(runner),
          domainLoggerProvider.overrideWithValue(
            DomainLogger(loggingService: LoggingService()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final orchestrator = container.read(wakeOrchestratorProvider);

      // Flag off: the hook returns without touching the log.
      await orchestrator.onWakeStart!('agent-1', 'rk-1', 'thread-1');
      expect(
        headsOfLog(bench.repo.messages, bench.repo.links).toSet(),
        {'a', 'b'},
      );

      // Flag flipped on: the SAME captured hook heals on the next wake.
      flag = true;
      await orchestrator.onWakeStart!('agent-1', 'rk-2', 'thread-1');
      expect(headsOfLog(bench.repo.messages, bench.repo.links), [
        computeJoinId(['a', 'b']),
      ]);
    });

    group('taskContentChecker', () {
      late MockAgentRepository mockRepo;
      late MockJournalDb mockDb;

      setUp(() {
        mockRepo = MockAgentRepository();
        mockDb = MockJournalDb();
      });

      test('returns true when task has non-empty title', () async {
        when(() => mockDb.journalEntityById('task-1')).thenAnswer(
          (_) async => JournalEntity.task(
            meta: Metadata(
              id: 'task-1',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              dateFrom: DateTime(2024),
              dateTo: DateTime(2024),
            ),
            data: TaskData(
              status: taskStatusFromString(''),
              title: 'Has a title',
              statusHistory: [],
              dateTo: DateTime(2024),
              dateFrom: DateTime(2024),
              estimate: Duration.zero,
            ),
          ),
        );

        final container = createCheckerContainer(
          mockRepo: mockRepo,
          mockDb: mockDb,
        );
        final orchestrator = container.read(wakeOrchestratorProvider);
        final result = await orchestrator.taskContentChecker!('task-1');
        expect(result, isTrue);
      });

      test('returns true when task has non-empty body text', () async {
        when(() => mockDb.journalEntityById('task-2')).thenAnswer(
          (_) async => JournalEntity.task(
            meta: Metadata(
              id: 'task-2',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              dateFrom: DateTime(2024),
              dateTo: DateTime(2024),
            ),
            data: TaskData(
              status: taskStatusFromString(''),
              title: '',
              statusHistory: [],
              dateTo: DateTime(2024),
              dateFrom: DateTime(2024),
              estimate: Duration.zero,
            ),
            entryText: const EntryText(plainText: 'Some body text'),
          ),
        );

        final container = createCheckerContainer(
          mockRepo: mockRepo,
          mockDb: mockDb,
        );
        final orchestrator = container.read(wakeOrchestratorProvider);
        final result = await orchestrator.taskContentChecker!('task-2');
        expect(result, isTrue);
      });

      test('returns true when linked entry has text', () async {
        when(() => mockDb.journalEntityById('task-3')).thenAnswer(
          (_) async => JournalEntity.task(
            meta: Metadata(
              id: 'task-3',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              dateFrom: DateTime(2024),
              dateTo: DateTime(2024),
            ),
            data: TaskData(
              status: taskStatusFromString(''),
              title: '',
              statusHistory: [],
              dateTo: DateTime(2024),
              dateFrom: DateTime(2024),
              estimate: Duration.zero,
            ),
          ),
        );
        when(() => mockDb.getLinkedEntities('task-3')).thenAnswer(
          (_) async => [
            JournalEntity.journalEntry(
              meta: Metadata(
                id: 'linked-1',
                createdAt: DateTime(2024),
                updatedAt: DateTime(2024),
                dateFrom: DateTime(2024),
                dateTo: DateTime(2024),
              ),
              entryText: const EntryText(plainText: 'Linked content'),
            ),
          ],
        );

        final container = createCheckerContainer(
          mockRepo: mockRepo,
          mockDb: mockDb,
        );
        final orchestrator = container.read(wakeOrchestratorProvider);
        final result = await orchestrator.taskContentChecker!('task-3');
        expect(result, isTrue);
      });

      test(
        'returns false when task and linked entries have no content',
        () async {
          when(() => mockDb.journalEntityById('task-4')).thenAnswer(
            (_) async => JournalEntity.task(
              meta: Metadata(
                id: 'task-4',
                createdAt: DateTime(2024),
                updatedAt: DateTime(2024),
                dateFrom: DateTime(2024),
                dateTo: DateTime(2024),
              ),
              data: TaskData(
                status: taskStatusFromString(''),
                title: '',
                statusHistory: [],
                dateTo: DateTime(2024),
                dateFrom: DateTime(2024),
                estimate: Duration.zero,
              ),
            ),
          );
          when(() => mockDb.getLinkedEntities('task-4')).thenAnswer(
            (_) async => <JournalEntity>[],
          );

          final container = createCheckerContainer(
            mockRepo: mockRepo,
            mockDb: mockDb,
          );
          final orchestrator = container.read(wakeOrchestratorProvider);
          final result = await orchestrator.taskContentChecker!('task-4');
          expect(result, isFalse);
        },
      );

      test('returns false when entity is not a Task', () async {
        when(() => mockDb.journalEntityById('entry-1')).thenAnswer(
          (_) async => JournalEntity.journalEntry(
            meta: Metadata(
              id: 'entry-1',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              dateFrom: DateTime(2024),
              dateTo: DateTime(2024),
            ),
          ),
        );
        when(() => mockDb.getLinkedEntities('entry-1')).thenAnswer(
          (_) async => <JournalEntity>[],
        );

        final container = createCheckerContainer(
          mockRepo: mockRepo,
          mockDb: mockDb,
        );
        final orchestrator = container.read(wakeOrchestratorProvider);
        final result = await orchestrator.taskContentChecker!('entry-1');
        expect(result, isFalse);
      });
    });
  });

  group('agentServiceProvider', () {
    test('creates service with injected dependencies', () {
      final mockRepo = MockAgentRepository();
      final mockOrchestrator = MockWakeOrchestrator();
      final mockSyncService = MockAgentSyncService();
      final mockOutbox = MockOutboxService();
      final mockNotifications = MockUpdateNotifications();

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepo),
          wakeOrchestratorProvider.overrideWithValue(mockOrchestrator),
          agentSyncServiceProvider.overrideWithValue(mockSyncService),
          outboxServiceProvider.overrideWithValue(mockOutbox),
          updateNotificationsProvider.overrideWithValue(mockNotifications),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(agentServiceProvider);
      expect(service, isA<AgentService>());
      expect(service.repository, same(mockRepo));
      expect(service.orchestrator, same(mockOrchestrator));

      service.onPersistedStateChanged?.call('agent-1');

      verify(
        () => mockNotifications.notifyUiOnly({'agent-1', agentNotification}),
      ).called(1);
    });
  });

  group('agentTemplateServiceProvider', () {
    test('creates service with injected dependencies', () {
      final mockRepo = MockAgentRepository();
      final mockSyncService = MockAgentSyncService();
      final mockOutbox = MockOutboxService();

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepo),
          agentSyncServiceProvider.overrideWithValue(mockSyncService),
          outboxServiceProvider.overrideWithValue(mockOutbox),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(agentTemplateServiceProvider);
      expect(service, isA<AgentTemplateService>());
      expect(service.repository, same(mockRepo));
    });
  });

  group('standingAgreementServiceProvider', () {
    test('creates service with injected dependencies', () {
      final mockRepo = MockAgentRepository();
      final mockSyncService = MockAgentSyncService();
      final mockOutbox = MockOutboxService();

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepo),
          agentSyncServiceProvider.overrideWithValue(mockSyncService),
          outboxServiceProvider.overrideWithValue(mockOutbox),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(standingAgreementServiceProvider);
      expect(service, isA<StandingAgreementService>());
      expect(service.repository, same(mockRepo));
      expect(service.syncService, same(mockSyncService));
    });
  });

  group('scheduledWakeManagerProvider', () {
    test('creates ScheduledWakeManager instance', () {
      final mockRepo = MockAgentRepository();
      final mockOrchestrator = MockWakeOrchestrator();
      final mockSyncService = MockAgentSyncService();
      final notifications = UpdateNotifications();

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepo),
          wakeOrchestratorProvider.overrideWithValue(mockOrchestrator),
          agentSyncServiceProvider.overrideWithValue(mockSyncService),
          updateNotificationsProvider.overrideWithValue(notifications),
          domainLoggerProvider.overrideWithValue(MockDomainLogger()),
        ],
      );
      addTearDown(() {
        notifications.dispose();
        container.dispose();
      });

      final manager = container.read(scheduledWakeManagerProvider);
      expect(manager, isA<ScheduledWakeManager>());
    });
  });

  group('feedbackExtractionServiceProvider', () {
    test('creates FeedbackExtractionService instance', () {
      final mockRepo = MockAgentRepository();
      final mockSync = MockAgentSyncService();
      final mockOutbox = MockOutboxService();

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepo),
          agentSyncServiceProvider.overrideWithValue(mockSync),
          outboxServiceProvider.overrideWithValue(mockOutbox),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(feedbackExtractionServiceProvider);
      expect(service, isA<FeedbackExtractionService>());
    });
  });

  group('improverAgentServiceProvider', () {
    test('resolves dependencies through real provider', () {
      final mockRepo = MockAgentRepository();
      final mockSync = MockAgentSyncService();
      final mockOutbox = MockOutboxService();
      final mockOrchestrator = MockWakeOrchestrator();
      final mockNotifications = MockUpdateNotifications();

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepo),
          agentSyncServiceProvider.overrideWithValue(mockSync),
          outboxServiceProvider.overrideWithValue(mockOutbox),
          wakeOrchestratorProvider.overrideWithValue(mockOrchestrator),
          updateNotificationsProvider.overrideWithValue(mockNotifications),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(improverAgentServiceProvider);
      expect(service, isA<ImproverAgentService>());

      service.onPersistedStateChanged?.call('agent-2');

      verify(
        () => mockNotifications.notifyUiOnly({'agent-2', agentNotification}),
      ).called(1);
    });
  });

  group('projectAgentWorkflowProvider', () {
    test('resolves dependencies and wires persisted-state notifications', () {
      final mockRepo = MockAgentRepository();
      final mockSync = MockAgentSyncService();
      final mockOutbox = MockOutboxService();
      final mockConversationRepository = MockConversationRepository(
        MockConversationManager(),
      );
      final mockAiConfig = MockAiConfigRepository();
      final mockCloudInference = MockCloudInferenceRepository();
      final mockJournalRepository = MockJournalRepository();
      final mockTemplateService = MockAgentTemplateService();
      final mockNotifications = MockUpdateNotifications();
      final domainLogger = DomainLogger(loggingService: LoggingService());

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepo),
          agentSyncServiceProvider.overrideWithValue(mockSync),
          outboxServiceProvider.overrideWithValue(mockOutbox),
          conversationRepositoryProvider.overrideWith(
            () => mockConversationRepository,
          ),
          aiConfigRepositoryProvider.overrideWithValue(mockAiConfig),
          cloudInferenceRepositoryProvider.overrideWithValue(
            mockCloudInference,
          ),
          journalRepositoryProvider.overrideWithValue(mockJournalRepository),
          agentTemplateServiceProvider.overrideWithValue(mockTemplateService),
          updateNotificationsProvider.overrideWithValue(mockNotifications),
          domainLoggerProvider.overrideWithValue(domainLogger),
          journalDbProvider.overrideWithValue(MockJournalDb()),
        ],
      );
      addTearDown(container.dispose);

      final workflow = container.read(projectAgentWorkflowProvider);
      expect(workflow, isA<ProjectAgentWorkflow>());

      workflow.onPersistedStateChanged?.call('agent-3');

      verify(
        () => mockNotifications.notifyUiOnly({'agent-3', agentNotification}),
      ).called(1);
    });
  });

  group('improverAgentWorkflowProvider', () {
    test('resolves dependencies through real provider', () {
      final mockRepo = MockAgentRepository();
      final mockSync = MockAgentSyncService();
      final mockOutbox = MockOutboxService();
      final mockOrchestrator = MockWakeOrchestrator();
      final mockTemplateWorkflow = MockTemplateEvolutionWorkflow();
      final mockLogging = MockLoggingService();
      final mockNotifications = MockUpdateNotifications();

      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepo),
          agentSyncServiceProvider.overrideWithValue(mockSync),
          outboxServiceProvider.overrideWithValue(mockOutbox),
          wakeOrchestratorProvider.overrideWithValue(mockOrchestrator),
          templateEvolutionWorkflowProvider.overrideWithValue(
            mockTemplateWorkflow,
          ),
          updateNotificationsProvider.overrideWithValue(mockNotifications),
          loggingServiceProvider.overrideWithValue(mockLogging),
        ],
      );
      addTearDown(container.dispose);

      final workflow = container.read(improverAgentWorkflowProvider);
      expect(workflow, isA<ImproverAgentWorkflow>());
    });
  });

  group('templateEvolutionWorkflowProvider', () {
    late MockAgentRepository mockRepo;
    late MockAgentSyncService mockSync;
    late MockOutboxService mockOutbox;
    late MockWakeOrchestrator mockOrchestrator;
    late MockAiConfigRepository mockAiConfig;
    late MockCloudInferenceRepository mockCloudInference;
    late MockUpdateNotifications mockNotifications;
    late MockImproverAgentService mockImproverService;

    setUp(() {
      mockRepo = MockAgentRepository();
      mockSync = MockAgentSyncService();
      mockOutbox = MockOutboxService();
      mockOrchestrator = MockWakeOrchestrator();
      mockAiConfig = MockAiConfigRepository();
      mockCloudInference = MockCloudInferenceRepository();
      mockNotifications = MockUpdateNotifications();
      mockImproverService = MockImproverAgentService();
    });

    ProviderContainer createWorkflowContainer({
      MockImproverAgentService? improverOverride,
    }) {
      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(mockRepo),
          agentSyncServiceProvider.overrideWithValue(mockSync),
          outboxServiceProvider.overrideWithValue(mockOutbox),
          wakeOrchestratorProvider.overrideWithValue(mockOrchestrator),
          aiConfigRepositoryProvider.overrideWithValue(mockAiConfig),
          cloudInferenceRepositoryProvider.overrideWithValue(
            mockCloudInference,
          ),
          updateNotificationsProvider.overrideWithValue(mockNotifications),
          if (improverOverride != null)
            improverAgentServiceProvider.overrideWithValue(improverOverride),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('resolves dependencies through real provider', () {
      final container = createWorkflowContainer();

      final workflow = container.read(templateEvolutionWorkflowProvider);
      expect(workflow, isA<TemplateEvolutionWorkflow>());
    });

    test('onSessionCompleted schedules next ritual for improver', () async {
      final identity = makeTestIdentity(
        kind: AgentKinds.templateImprover,
      );
      when(
        () => mockImproverService.getImproverForTemplate(any()),
      ).thenAnswer((_) async => identity);
      when(
        () => mockImproverService.scheduleNextRitual(any()),
      ).thenAnswer((_) async {});

      final container = createWorkflowContainer(
        improverOverride: mockImproverService,
      );

      final workflow = container.read(templateEvolutionWorkflowProvider);
      expect(workflow.onSessionCompleted, isNotNull);

      // Fire the callback manually.
      workflow.onSessionCompleted!('template-123', 'session-456');

      await pumpEventQueue();

      verify(
        () => mockImproverService.getImproverForTemplate('template-123'),
      ).called(1);
      verify(
        () => mockImproverService.scheduleNextRitual(identity.agentId),
      ).called(1);
    });

    test('onSessionCompleted is no-op when no improver exists', () async {
      when(
        () => mockImproverService.getImproverForTemplate(any()),
      ).thenAnswer((_) async => null);

      final container = createWorkflowContainer(
        improverOverride: mockImproverService,
      );

      final workflow = container.read(templateEvolutionWorkflowProvider);
      workflow.onSessionCompleted!('template-123', 'session-456');

      await pumpEventQueue();

      verify(
        () => mockImproverService.getImproverForTemplate('template-123'),
      ).called(1);
      verifyNever(
        () => mockImproverService.scheduleNextRitual(any()),
      );
    });
  });

  group('agentInitializationProvider — orphan cleanup', () {
    late InitProviderBench bench;

    setUp(() async {
      bench = await InitProviderBench.create();
    });

    tearDown(tearDownTestGetIt);

    test('calls abandonOrphanedWakeRuns on startup', () async {
      when(
        () => bench.mockRepository.abandonOrphanedWakeRuns(),
      ).thenAnswer((_) async => 0);

      final container = bench.createContainer();
      await bench.initAndSubscribe(container);

      verify(() => bench.mockRepository.abandonOrphanedWakeRuns()).called(1);
    });

    test('logs when orphaned runs are found', () async {
      when(
        () => bench.mockRepository.abandonOrphanedWakeRuns(),
      ).thenAnswer((_) async => 3);

      final container = bench.createContainer();
      await bench.initAndSubscribe(container);

      // Should complete without error even when orphans exist.
      verify(() => bench.mockRepository.abandonOrphanedWakeRuns()).called(1);
    });
  });

  group('agentInitializationProvider - SyncEventProcessor not registered', () {
    late InitProviderBench bench;

    setUp(() async {
      bench = await InitProviderBench.create();
    });

    tearDown(tearDownTestGetIt);

    test('skips SyncEventProcessor when not registered in GetIt', () async {
      // Ensure SyncEventProcessor is NOT registered.
      expect(getIt.isRegistered<SyncEventProcessor>(), isFalse);

      final container = bench.createContainer();
      await bench.initAndSubscribe(container);

      verify(() => bench.mockOrchestrator.start(any())).called(1);
      verify(() => bench.mockTemplateService.seedDefaults()).called(1);
      verify(
        () => bench.mockTaskAgentService.restoreSubscriptions(),
      ).called(1);
      verify(
        () => bench.mockDayAgentService.restoreSubscriptions(),
      ).called(1);
    });
  });

  group('forkHealingHook', () {
    test('returns a hook that heals a fork when run', () async {
      final bench = makeForkBench();
      await seedForkInto(bench.repo, head: 'b'); // a 2-head fork {a, b}

      final hook = forkHealingHook(
        () => bench.service,
        () => DateTime(2024, 2),
        isEnabled: () async => true,
      );
      await hook('agent-1', 'run-key', 'thread-1');

      // The fork collapsed to a single head: the content-addressed join.
      expect(headsOfLog(bench.repo.messages, bench.repo.links), [
        computeJoinId(['a', 'b']),
      ]);
    });

    test('stamps the join with the supplied wake timestamp', () async {
      final bench = makeForkBench();
      await seedForkInto(bench.repo, head: 'b');

      final hook = forkHealingHook(
        () => bench.service,
        () => DateTime(2024, 7, 4),
        isEnabled: () async => true,
      );
      await hook('agent-1', 'rk', 'thread-1');

      final join = bench.repo.messages.firstWhere(
        (m) => m.id == computeJoinId(['a', 'b']),
      );
      expect(join.createdAt, DateTime(2024, 7, 4));
    });

    test('consults the flag per invocation: off → no join, flipped on → '
        'heals on the next wake without a rebuild', () async {
      // The orchestrator captures the hook once at initialization; a Settings
      // toggle must reach the NEXT invocation of the same closure.
      final bench = makeForkBench();
      await seedForkInto(bench.repo, head: 'b');

      var flag = false;
      final hook = forkHealingHook(
        () => bench.service,
        () => DateTime(2024, 2),
        isEnabled: () async => flag,
      );

      await hook('agent-1', 'rk-1', 'thread-1');
      // Disabled: the fork remains un-joined.
      expect(
        headsOfLog(bench.repo.messages, bench.repo.links).toSet(),
        {'a', 'b'},
      );

      flag = true;
      await hook('agent-1', 'rk-2', 'thread-1');
      expect(headsOfLog(bench.repo.messages, bench.repo.links), [
        computeJoinId(['a', 'b']),
      ]);
    });
  });
}
