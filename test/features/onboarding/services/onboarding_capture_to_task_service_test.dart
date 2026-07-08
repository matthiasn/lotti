import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/services/onboarding_capture_to_task_service.dart';
import 'package:lotti/features/onboarding/services/onboarding_task_structuring_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';
import '../../categories/test_utils.dart';

void main() {
  late MockOnboardingTaskStructuringService structuring;
  late MockOnboardingMetricsRepository metrics;
  late MockPersistenceLogic persistence;
  late MockJournalRepository journalRepository;
  late MockCategoryRepository categoryRepository;
  late MockTaskAgentService taskAgentService;
  late MockAgentSyncService syncService;
  late OnboardingCaptureToTaskService service;

  const categoryId = 'cat-1';
  final fixedNow = DateTime(2026, 6, 21, 9);

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(
      AgentDomainEntity.changeSet(
        id: 'fallback',
        agentId: 'fallback',
        taskId: 'fallback',
        threadId: 'fallback',
        runKey: 'fallback',
        status: ChangeSetStatus.pending,
        items: const [],
        createdAt: DateTime(2026),
        vectorClock: null,
      ),
    );
  });

  void stubMetrics() {
    when(
      () => metrics.recordEvent(
        any(),
        provider: any(named: 'provider'),
        reason: any(named: 'reason'),
        valueBucket: any(named: 'valueBucket'),
      ),
    ).thenAnswer((_) async {});
  }

  void stubStructureSuccess(OnboardingStructuredTask result) {
    when(
      () => structuring.structure(
        transcript: any(named: 'transcript'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => result);
  }

  void stubStructureFailure(OnboardingStructuringFailure failure) {
    when(
      () => structuring.structure(
        transcript: any(named: 'transcript'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenThrow(OnboardingStructuringException(failure));
  }

  void stubCreateTask(Task? task) {
    when(
      () => persistence.createTaskEntry(
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => task);
  }

  TaskData capturedTaskData() =>
      verify(
            () => persistence.createTaskEntry(
              data: captureAny(named: 'data'),
              entryText: any(named: 'entryText'),
              categoryId: any(named: 'categoryId'),
            ),
          ).captured.single
          as TaskData;

  void stubCreateLink({bool success = true}) {
    when(
      () => persistence.createLink(
        fromId: any(named: 'fromId'),
        toId: any(named: 'toId'),
      ),
    ).thenAnswer((_) async => success);
  }

  void stubCategory(CategoryDefinition? category) {
    when(
      () => categoryRepository.getCategoryById(any()),
    ).thenAnswer((_) async => category);
  }

  void stubCreateTaskAgent({String agentId = 'agent-1'}) {
    when(
      () => taskAgentService.createTaskAgent(
        taskId: any(named: 'taskId'),
        templateId: any(named: 'templateId'),
        profileId: any(named: 'profileId'),
        allowedCategoryIds: any(named: 'allowedCategoryIds'),
        additionalWakeTokens: any(named: 'additionalWakeTokens'),
      ),
    ).thenAnswer((_) async => makeTestIdentity(agentId: agentId));
  }

  /// The single change set the service seeded through the agent's sync service.
  /// Fails the test if nothing was seeded.
  ChangeSetEntity seededChangeSet() => verify(
    () => syncService.upsertEntity(captureAny()),
  ).captured.whereType<ChangeSetEntity>().single;

  setUp(() {
    structuring = MockOnboardingTaskStructuringService();
    metrics = MockOnboardingMetricsRepository();
    persistence = MockPersistenceLogic();
    journalRepository = MockJournalRepository();
    categoryRepository = MockCategoryRepository();
    taskAgentService = MockTaskAgentService();
    syncService = MockAgentSyncService();
    when(
      () => journalRepository.updateCategoryId(
        any(),
        categoryId: any(named: 'categoryId'),
      ),
    ).thenAnswer((_) async => true);
    // The service seeds checklist proposals through the created agent's own
    // sync service (a public field on TaskAgentService).
    when(() => taskAgentService.syncService).thenReturn(syncService);
    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
    service = OnboardingCaptureToTaskService(
      structuringService: structuring,
      metricsRepository: metrics,
      categoryRepository: categoryRepository,
      taskAgentService: taskAgentService,
      persistenceLogic: persistence,
      journalRepository: journalRepository,
      clock: () => fixedNow,
    );
    stubMetrics();
    // Default: a plain category with no default template or profile, so agent
    // assignment stays out of the way of unrelated tests.
    stubCategory(CategoryTestUtils.createTestCategory(id: categoryId));
  });

  group('real aha (structuring succeeds)', () {
    test('creates an in-progress task and records realAha', () async {
      stubStructureSuccess(
        const OnboardingStructuredTask(
          title: 'Call the dentist',
          checklistItems: ['Find number', 'Book slot'],
        ),
      );
      stubCreateTask(TestTaskFactory.create(id: 'task-1'));

      final result = await service.createTaskFromTranscript(
        transcript: 'call the dentist and book a slot',
        categoryId: categoryId,
        providerName: 'gemini',
      );

      expect(result.isRealAha, isTrue);
      expect(result.created, isTrue);
      expect(result.title, 'Call the dentist');
      // The structured checklist rides back on the result (the UI still knows
      // what was extracted), even though it is now proposed rather than
      // committed.
      expect(result.checklistItems, ['Find number', 'Book slot']);

      // The created task carries the structured title and lands already in
      // progress (the user spoke it into being and is dropped onto it).
      final data = capturedTaskData();
      expect(data.title, 'Call the dentist');
      expect(
        data.status.maybeMap(inProgress: (_) => true, orElse: () => false),
        isTrue,
      );

      // The default category carries no agent, so there is nothing to attribute
      // proposals to — nothing is seeded.
      verifyNever(() => syncService.upsertEntity(any()));

      // Funnel: make-task tapped up front, then realAha (with provider).
      verify(
        () => metrics.recordEvent(
          OnboardingEventName.makeTaskTapped,
          provider: 'gemini',
        ),
      ).called(1);
      verify(
        () => metrics.recordEvent(
          OnboardingEventName.realAha,
          provider: 'gemini',
        ),
      ).called(1);
      verifyNever(
        () => metrics.recordEvent(
          OnboardingEventName.structuringFloorUsed,
          provider: any(named: 'provider'),
        ),
      );
    });

    test('falls short of a real aha when the task fails to persist', () async {
      stubStructureSuccess(
        const OnboardingStructuredTask(title: 'X', checklistItems: ['a']),
      );
      stubCreateTask(null);

      final result = await service.createTaskFromTranscript(
        transcript: 'something',
        categoryId: categoryId,
      );

      expect(result.isRealAha, isFalse);
      expect(result.created, isFalse);
      verify(
        () => metrics.recordEvent(
          OnboardingEventName.structuringFailed,
          reason: 'persist_failed',
          provider: any(named: 'provider'),
        ),
      ).called(1);
      verifyNever(
        () => metrics.recordEvent(
          OnboardingEventName.realAha,
          provider: any(named: 'provider'),
        ),
      );
    });
  });

  group('audio linking', () {
    test('links the captured audio entry under the structured task', () async {
      stubStructureSuccess(
        const OnboardingStructuredTask(
          title: 'Call the dentist',
          checklistItems: [],
        ),
      );
      stubCreateTask(TestTaskFactory.create(id: 'task-1'));
      stubCreateLink();

      final result = await service.createTaskFromTranscript(
        transcript: 'call the dentist',
        categoryId: categoryId,
        audioId: 'audio-1',
      );

      expect(result.created, isTrue);
      verify(
        () => persistence.createLink(fromId: 'task-1', toId: 'audio-1'),
      ).called(1);
      // The audio entry also inherits the task's category — the capture
      // controller persisted it uncategorized.
      verify(
        () => journalRepository.updateCategoryId(
          'audio-1',
          categoryId: categoryId,
        ),
      ).called(1);
    });

    test('links the audio under the floor task on a soft landing', () async {
      stubStructureFailure(OnboardingStructuringFailure.requestFailed);
      stubCreateTask(TestTaskFactory.create(id: 'floor-1'));
      stubCreateLink();

      final result = await service.createTaskFromTranscript(
        transcript: 'do the thing',
        categoryId: categoryId,
        audioId: 'audio-2',
      );

      expect(result.created, isTrue);
      verify(
        () => persistence.createLink(fromId: 'floor-1', toId: 'audio-2'),
      ).called(1);
    });

    test('creates no link on the typed path (no audio entry)', () async {
      stubStructureSuccess(
        const OnboardingStructuredTask(title: 'Typed', checklistItems: []),
      );
      stubCreateTask(TestTaskFactory.create(id: 'task-1'));

      await service.createTaskFromTranscript(
        transcript: 'typed thought',
        categoryId: categoryId,
      );

      verifyNever(
        () => persistence.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
        ),
      );
      verifyNever(
        () => journalRepository.updateCategoryId(
          any(),
          categoryId: any(named: 'categoryId'),
        ),
      );
    });

    test(
      'defaults to a real JournalRepository when none is injected',
      () async {
        stubStructureSuccess(
          const OnboardingStructuredTask(
            title: 'Defaulted',
            checklistItems: [],
          ),
        );
        stubCreateTask(TestTaskFactory.create(id: 'task-1'));
        final defaulted = OnboardingCaptureToTaskService(
          structuringService: structuring,
          metricsRepository: metrics,
          categoryRepository: categoryRepository,
          taskAgentService: taskAgentService,
          persistenceLogic: persistence,
          clock: () => fixedNow,
        );

        // The typed path (no audioId) never touches the journal repository, so
        // the constructor default is exercised without hitting getIt.
        final result = await defaulted.createTaskFromTranscript(
          transcript: 'hello',
          categoryId: categoryId,
        );

        expect(result.created, isTrue);
        expect(result.title, 'Defaulted');
      },
    );

    test('keeps the task when the link write throws', () async {
      stubStructureSuccess(
        const OnboardingStructuredTask(title: 'Resilient', checklistItems: []),
      );
      stubCreateTask(TestTaskFactory.create(id: 'task-1'));
      when(
        () => persistence.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
        ),
      ).thenThrow(Exception('link write failed'));

      final result = await service.createTaskFromTranscript(
        transcript: 'still lands',
        categoryId: categoryId,
        audioId: 'audio-3',
      );

      // The link is best-effort: its failure never costs the user the task.
      expect(result.created, isTrue);
      expect(result.isRealAha, isTrue);
    });
  });

  group('agent auto-assignment', () {
    final agentCategory = CategoryTestUtils.createTestCategory(
      id: categoryId,
      defaultTemplateId: 'template-laura-001',
      defaultProfileId: 'profile-melious-001',
    );

    test(
      'spawns the category default agent for the structured task and '
      'inherits the profile',
      () async {
        stubStructureSuccess(
          const OnboardingStructuredTask(
            title: 'Call the dentist',
            checklistItems: ['Find number'],
          ),
        );
        stubCreateTask(TestTaskFactory.create(id: 'task-1'));
        stubCategory(agentCategory);
        stubCreateTaskAgent();

        final result = await service.createTaskFromTranscript(
          transcript: 'call the dentist',
          categoryId: categoryId,
        );

        expect(result.created, isTrue);
        // The task inherits the category's default profile, mirroring the
        // normal creation path in create_entry.dart.
        expect(capturedTaskData().profileId, 'profile-melious-001');
        // The agent is created with the category's template and profile,
        // scoped to the destination category — and NOT content-awaiting: the
        // creation wake must run the first turn immediately. Typed path -> no
        // audio token.
        verify(
          () => taskAgentService.createTaskAgent(
            taskId: 'task-1',
            templateId: 'template-laura-001',
            profileId: 'profile-melious-001',
            allowedCategoryIds: {categoryId},
            // ignore: avoid_redundant_argument_values
            additionalWakeTokens: const <String>{},
          ),
        ).called(1);
      },
    );

    test(
      'seeds the structured checklist as pending proposals under the agent',
      () async {
        stubStructureSuccess(
          const OnboardingStructuredTask(
            title: 'Call the dentist',
            checklistItems: ['Find number', 'Book slot'],
          ),
        );
        stubCreateTask(TestTaskFactory.create(id: 'task-1'));
        stubCategory(agentCategory);
        stubCreateTaskAgent(agentId: 'agent-7');

        await service.createTaskFromTranscript(
          transcript: 'call the dentist and book a slot',
          categoryId: categoryId,
        );

        // Rather than committing the checklist, the service seeds it as a
        // pending change set attributed to the just-created agent, so it lands
        // on the task page as confirmable proposals ("Confirm all").
        final changeSet = seededChangeSet();
        expect(changeSet.status, ChangeSetStatus.pending);
        expect(changeSet.agentId, 'agent-7');
        expect(changeSet.taskId, 'task-1');
        // The batch is exploded into one pending add_checklist_item per line,
        // so >1 item surfaces the "Confirm all" button.
        expect(changeSet.items.length, 2);
        expect(
          changeSet.items.every((i) => i.status == ChangeItemStatus.pending),
          isTrue,
        );
        expect(
          changeSet.items.every(
            (i) => i.toolName == TaskAgentToolNames.addChecklistItem,
          ),
          isTrue,
        );
        expect(
          changeSet.items.map((i) => i.args['title']),
          ['Find number', 'Book slot'],
        );
      },
    );

    test('seeds no proposals when there is no checklist', () async {
      stubStructureSuccess(
        const OnboardingStructuredTask(
          title: 'Water plants',
          checklistItems: [],
        ),
      );
      stubCreateTask(TestTaskFactory.create(id: 'task-1'));
      stubCategory(agentCategory);
      stubCreateTaskAgent();

      final result = await service.createTaskFromTranscript(
        transcript: 'water the plants',
        categoryId: categoryId,
      );

      expect(result.created, isTrue);
      // An agent is still assigned, but there is nothing to propose.
      verify(
        () => taskAgentService.createTaskAgent(
          taskId: any(named: 'taskId'),
          templateId: any(named: 'templateId'),
          profileId: any(named: 'profileId'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
          additionalWakeTokens: any(named: 'additionalWakeTokens'),
        ),
      ).called(1);
      verifyNever(() => syncService.upsertEntity(any()));
    });

    test('keeps the task and aha when proposal seeding throws', () async {
      stubStructureSuccess(
        const OnboardingStructuredTask(
          title: 'Resilient',
          checklistItems: ['Find number'],
        ),
      );
      stubCreateTask(TestTaskFactory.create(id: 'task-1'));
      stubCategory(agentCategory);
      stubCreateTaskAgent();
      when(
        () => syncService.upsertEntity(any()),
      ).thenThrow(StateError('sync backend down'));

      final result = await service.createTaskFromTranscript(
        transcript: 'still lands',
        categoryId: categoryId,
      );

      // Seeding is best-effort: its failure never costs the user the task or the
      // aha — the agent's own wake will still populate the checklist.
      expect(result.created, isTrue);
      expect(result.isRealAha, isTrue);
    });

    test(
      'hands the spoken capture to the agent wake so the first turn attends '
      'to the transcript',
      () async {
        stubStructureSuccess(
          const OnboardingStructuredTask(
            title: 'Call the dentist',
            checklistItems: [],
          ),
        );
        stubCreateTask(TestTaskFactory.create(id: 'task-1'));
        stubCreateLink();
        stubCategory(agentCategory);
        stubCreateTaskAgent();

        await service.createTaskFromTranscript(
          transcript: 'call the dentist',
          categoryId: categoryId,
          audioId: 'audio-1',
        );

        verify(
          () => taskAgentService.createTaskAgent(
            taskId: 'task-1',
            templateId: 'template-laura-001',
            profileId: 'profile-melious-001',
            allowedCategoryIds: {categoryId},
            additionalWakeTokens: {'audio-1'},
          ),
        ).called(1);
      },
    );

    test('spawns the agent for the floor task on a soft landing', () async {
      stubStructureFailure(OnboardingStructuringFailure.requestFailed);
      stubCreateTask(TestTaskFactory.create(id: 'floor-1'));
      stubCategory(agentCategory);
      stubCreateTaskAgent();

      final result = await service.createTaskFromTranscript(
        transcript: 'do the thing',
        categoryId: categoryId,
      );

      expect(result.created, isTrue);
      verify(
        () => taskAgentService.createTaskAgent(
          taskId: 'floor-1',
          templateId: 'template-laura-001',
          profileId: 'profile-melious-001',
          allowedCategoryIds: {categoryId},
          // ignore: avoid_redundant_argument_values
          additionalWakeTokens: const <String>{},
        ),
      ).called(1);
      // The floor task has no structured checklist, so nothing is seeded.
      verifyNever(() => syncService.upsertEntity(any()));
    });

    test(
      'creates no agent when the category has no default template',
      () async {
        stubStructureSuccess(
          const OnboardingStructuredTask(title: 'Plain', checklistItems: []),
        );
        stubCreateTask(TestTaskFactory.create(id: 'task-1'));

        final result = await service.createTaskFromTranscript(
          transcript: 'plain task',
          categoryId: categoryId,
        );

        expect(result.created, isTrue);
        verifyNever(
          () => taskAgentService.createTaskAgent(
            taskId: any(named: 'taskId'),
            templateId: any(named: 'templateId'),
            profileId: any(named: 'profileId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            additionalWakeTokens: any(named: 'additionalWakeTokens'),
          ),
        );
      },
    );

    test('keeps the task when agent creation throws', () async {
      stubStructureSuccess(
        const OnboardingStructuredTask(title: 'Resilient', checklistItems: []),
      );
      stubCreateTask(TestTaskFactory.create(id: 'task-1'));
      stubCategory(agentCategory);
      when(
        () => taskAgentService.createTaskAgent(
          taskId: any(named: 'taskId'),
          templateId: any(named: 'templateId'),
          profileId: any(named: 'profileId'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
          additionalWakeTokens: any(named: 'additionalWakeTokens'),
        ),
      ).thenThrow(StateError('agent backend down'));

      final result = await service.createTaskFromTranscript(
        transcript: 'still lands',
        categoryId: categoryId,
      );

      // Agent creation is best-effort: its failure never costs the user the
      // task or the aha.
      expect(result.created, isTrue);
      expect(result.isRealAha, isTrue);
    });

    test(
      'keeps the task, without profile or agent, when the category lookup '
      'throws',
      () async {
        stubStructureSuccess(
          const OnboardingStructuredTask(
            title: 'No lookup',
            checklistItems: [],
          ),
        );
        stubCreateTask(TestTaskFactory.create(id: 'task-1'));
        when(
          () => categoryRepository.getCategoryById(any()),
        ).thenThrow(Exception('db down'));

        final result = await service.createTaskFromTranscript(
          transcript: 'no lookup',
          categoryId: categoryId,
        );

        expect(result.created, isTrue);
        expect(capturedTaskData().profileId, isNull);
        verifyNever(
          () => taskAgentService.createTaskAgent(
            taskId: any(named: 'taskId'),
            templateId: any(named: 'templateId'),
            profileId: any(named: 'profileId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            additionalWakeTokens: any(named: 'additionalWakeTokens'),
          ),
        );
      },
    );
  });

  group('soft landing (structuring fails)', () {
    test('creates a title-only task from the first sentence', () async {
      stubStructureFailure(OnboardingStructuringFailure.parseError);
      stubCreateTask(TestTaskFactory.create(id: 'floor-1'));

      final result = await service.createTaskFromTranscript(
        transcript: 'Buy oat milk on the way home. Also water the plants.',
        categoryId: categoryId,
        providerName: 'mistral',
      );

      expect(result.isRealAha, isFalse);
      expect(result.created, isTrue);
      expect(result.failure, OnboardingStructuringFailure.parseError);
      // Floor title is the first sentence only.
      expect(result.title, 'Buy oat milk on the way home');
      expect(capturedTaskData().title, 'Buy oat milk on the way home');

      verify(
        () => metrics.recordEvent(
          OnboardingEventName.structuringFailed,
          reason: 'parseError',
          provider: 'mistral',
        ),
      ).called(1);
      verify(
        () => metrics.recordEvent(
          OnboardingEventName.structuringFloorUsed,
          provider: 'mistral',
        ),
      ).called(1);
    });

    test('collapses whitespace and caps a long transcript title', () async {
      stubStructureFailure(OnboardingStructuringFailure.requestFailed);
      stubCreateTask(TestTaskFactory.create(id: 'floor-1'));
      final longTranscript = 'word ${'really ' * 40}long';

      final result = await service.createTaskFromTranscript(
        transcript: longTranscript,
        categoryId: categoryId,
      );

      expect(result.title.length, 80);
      expect(result.title, isNot(contains('  ')));
    });

    test('never makes a blank task for an empty transcript', () async {
      stubStructureFailure(OnboardingStructuringFailure.emptyTranscript);

      final result = await service.createTaskFromTranscript(
        transcript: '   ',
        categoryId: categoryId,
      );

      expect(result.created, isFalse);
      expect(result.title, isEmpty);
      verify(
        () => metrics.recordEvent(
          OnboardingEventName.structuringFailed,
          reason: 'emptyTranscript',
          provider: any(named: 'provider'),
        ),
      ).called(1);
      verifyNever(
        () => persistence.createTaskEntry(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
        ),
      );
      verifyNever(
        () => metrics.recordEvent(
          OnboardingEventName.structuringFloorUsed,
          provider: any(named: 'provider'),
        ),
      );
    });

    test(
      'does not record floor-used when the floor task fails to persist',
      () async {
        stubStructureFailure(OnboardingStructuringFailure.requestFailed);
        stubCreateTask(null);

        final result = await service.createTaskFromTranscript(
          transcript: 'do the thing',
          categoryId: categoryId,
        );

        expect(result.created, isFalse);
        expect(result.title, 'do the thing');
        verifyNever(
          () => metrics.recordEvent(
            OnboardingEventName.structuringFloorUsed,
            provider: any(named: 'provider'),
          ),
        );
      },
    );
  });

  group('provider wiring', () {
    late MockOnboardingTaskStructuringService wiredStructuring;
    late MockPersistenceLogic wiredPersistence;
    late MockOnboardingMetricsRepository wiredMetrics;

    setUp(() {
      wiredStructuring = MockOnboardingTaskStructuringService();
      wiredPersistence = MockPersistenceLogic();
      wiredMetrics = MockOnboardingMetricsRepository();
      // The provider resolves PersistenceLogic and the metrics repo from getIt,
      // with no explicit clock.
      getIt
        ..registerSingleton<JournalDb>(MockJournalDb())
        ..registerSingleton<DomainLogger>(MockDomainLogger())
        ..registerSingleton<PersistenceLogic>(wiredPersistence)
        ..registerSingleton<OnboardingMetricsRepository>(wiredMetrics);
    });
    tearDown(() async {
      await getIt.reset();
    });

    test('builds a service from app providers that creates a task', () async {
      when(
        () => wiredStructuring.structure(
          transcript: any(named: 'transcript'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer(
        (_) async =>
            const OnboardingStructuredTask(title: 'Wired', checklistItems: []),
      );
      when(
        () => wiredPersistence.createTaskEntry(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => TestTaskFactory.create(id: 'wired-task'));
      when(
        () => wiredMetrics.recordEvent(
          any(),
          provider: any(named: 'provider'),
          reason: any(named: 'reason'),
          valueBucket: any(named: 'valueBucket'),
        ),
      ).thenAnswer((_) async {});

      final wiredCategoryRepository = MockCategoryRepository();
      when(
        () => wiredCategoryRepository.getCategoryById(any()),
      ).thenAnswer((_) async => null);
      final container = ProviderContainer(
        overrides: [
          onboardingTaskStructuringServiceProvider.overrideWithValue(
            wiredStructuring,
          ),
          categoryRepositoryProvider.overrideWithValue(
            wiredCategoryRepository,
          ),
          taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
        ],
      );
      addTearDown(container.dispose);

      final wired = container.read(onboardingCaptureToTaskServiceProvider);
      final result = await wired.createTaskFromTranscript(
        transcript: 'hello',
        categoryId: categoryId,
      );

      // Proves the provider wired the structuring service, persistence, and
      // metrics repo together.
      expect(result.isRealAha, isTrue);
      expect(result.title, 'Wired');
      verify(
        () => wiredMetrics.recordEvent(
          OnboardingEventName.realAha,
          provider: any(named: 'provider'),
        ),
      ).called(1);
    });
  });
}
