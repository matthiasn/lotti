import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/agents/service/wake_prompt_reconstructor.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_trigger_tokens.dart';
import 'package:lotti/features/daily_os_next/agents/domain/week_context.dart';
import 'package:lotti/features/daily_os_next/agents/prompt/day_agent_prompt_sections.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../agents/test_utils.dart';
import '../prompt/day_agent_prompt_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const agentId = 'day-agent-001';
  const threadId = 'thread-001';
  const runKey = 'run-001';
  const dayId = 'dayplan-2026-05-25';
  const templateId = 'template-day';
  const versionId = 'template-day-v1';
  final now = DateTime(2026, 5, 25, 8);

  late MockAgentRepository repository;
  late MockAiConfigRepository aiConfigRepository;
  late MockCloudInferenceRepository cloudInferenceRepository;
  late MockAgentSyncService syncService;
  late MockAgentTemplateService templateService;
  late MockDomainLogger domainLogger;
  late _ConversationHarness conversationRepository;
  late AgentStateEntity currentState;
  late List<AgentDomainEntity> upsertedEntities;
  late List<String> changedTokens;

  AgentIdentityEntity identity() => makeTestIdentity(
    id: agentId,
    agentId: agentId,
    kind: AgentKinds.dayAgent,
    displayName: 'Shepherd',
    currentStateId: 'state-$agentId',
    config: const AgentConfig(profileId: 'profile-day', maxTurnsPerWake: 5),
    createdAt: now,
    updatedAt: now,
  );

  AgentStateEntity state({
    String activeDayId = dayId,
    int consecutiveFailureCount = 0,
    Map<String, int> toolCounterByKey = const {},
    DateTime? scheduledWakeAt,
  }) {
    return makeTestState(
      id: 'state-$agentId',
      agentId: agentId,
      slots: AgentSlots(activeDayId: activeDayId),
      updatedAt: now,
      consecutiveFailureCount: consecutiveFailureCount,
      toolCounterByKey: toolCounterByKey,
      scheduledWakeAt: scheduledWakeAt,
    );
  }

  AgentTemplateEntity template() => makeTestTemplate(
    id: templateId,
    agentId: templateId,
    kind: AgentTemplateKind.dayAgent,
    modelId: 'models/day',
    profileId: 'profile-day',
  );

  AgentTemplateVersionEntity version({
    String generalDirective = 'General day-agent directive.',
    String reportDirective = 'Report day-agent directive.',
    String directives = 'Legacy day-agent directive.',
  }) {
    return makeTestTemplateVersion(
      id: versionId,
      agentId: templateId,
      generalDirective: generalDirective,
      reportDirective: reportDirective,
      directives: directives,
      profileId: 'profile-day',
    );
  }

  void stubDomainLogger() {
    when(
      () => domainLogger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
        level: any(named: 'level'),
      ),
    ).thenReturn(null);
    when(
      () => domainLogger.error(
        any(),
        any(),
        message: any(named: 'message'),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
  }

  void stubInferenceProfile() {
    when(
      () => aiConfigRepository.getConfigById('profile-day'),
    ).thenAnswer(
      (_) async => testInferenceProfile(
        id: 'profile-day',
        thinkingModelId: 'models/day',
      ),
    );
    when(
      () => aiConfigRepository.getConfigsByType(AiConfigType.model),
    ).thenAnswer(
      (_) async => [
        testAiModel(
          id: 'model-day',
          providerModelId: 'models/day',
          inferenceProviderId: 'provider-day',
        ),
      ],
    );
    when(
      () => aiConfigRepository.getConfigById('provider-day'),
    ).thenAnswer(
      (_) async => testInferenceProvider(
        id: 'provider-day',
        apiKey: 'provider-key',
      ),
    );
  }

  DayAgentWorkflow workflow({
    MockSoulDocumentService? soulDocumentService,
    MockDayAgentCaptureService? captureService,
    MockDayAgentPlanService? planService,
    MockDayAgentKnowledgeService? knowledgeService,
    MockDayAgentWeekContextService? weekContextService,
  }) {
    return DayAgentWorkflow(
      agentRepository: repository,
      conversationRepository: conversationRepository,
      aiConfigRepository: aiConfigRepository,
      cloudInferenceRepository: cloudInferenceRepository,
      syncService: syncService,
      templateService: templateService,
      soulDocumentService: soulDocumentService,
      captureService: captureService,
      planService: planService,
      knowledgeService: knowledgeService,
      weekContextService: weekContextService,
      domainLogger: domainLogger,
      onPersistedStateChanged: changedTokens.add,
    );
  }

  /// Parses the last sent user message as a tagged-plaintext payload.
  ParsedDayAgentPrompt sentPrompt() =>
      ParsedDayAgentPrompt(conversationRepository.lastUserMessage!);

  Future<WakeResult> execute(
    DayAgentWorkflow sut, {
    Set<String>? triggerTokens,
  }) {
    return withClock(
      Clock.fixed(now),
      () => sut.execute(
        agentIdentity: identity(),
        runKey: runKey,
        triggerTokens: triggerTokens ?? {dayAgentPlanningDayToken(dayId)},
        threadId: threadId,
      ),
    );
  }

  /// Stubs the drafting-context lookups: the baseline plan (default none)
  /// and the decided-tasks hydration (default empty).
  void stubDraftingPlanContext(
    MockDayAgentPlanService planService, {
    DayPlanEntity? baselinePlan,
    List<DecidedTaskRef> decidedTasks = const [],
  }) {
    when(
      () => planService.draftPlanForDay(
        agentId: agentId,
        dayId: dayId,
      ),
    ).thenAnswer((_) async => baselinePlan);
    when(
      () => planService.hydrateDecidedTasks(
        allowedCategoryIds: any(named: 'allowedCategoryIds'),
        explicitTaskIds: any(named: 'explicitTaskIds'),
        parsedItems: any(named: 'parsedItems'),
      ),
    ).thenAnswer((_) async => decidedTasks);
  }

  void stubSuccessfulDraftToolCall(MockDayAgentPlanService planService) {
    when(
      () => planService.executeTool(
        agentId: agentId,
        threadId: threadId,
        runKey: runKey,
        toolName: DayAgentToolNames.draftDayPlan,
        args: any(named: 'args'),
      ),
    ).thenAnswer(
      (_) async => DayAgentDirectToolResult.success(
        const {'planId': 'day_agent_plan:dayplan-2026-05-25'},
      ),
    );
    conversationRepository.toolCalls = [
      _toolCall(
        id: 'draft-call',
        name: DayAgentToolNames.draftDayPlan,
        args: {
          'dayId': dayId,
          'blocks': <Object?>[],
        },
      ),
    ];
  }

  void stubCaptureContext(
    MockDayAgentCaptureService captureService, {
    String captureId = 'capture-1',
  }) {
    when(() => captureService.getCapture(captureId)).thenAnswer(
      (_) async => makeTestCapture(
        id: captureId,
        agentId: agentId,
        transcript: 'Prep demo and buy milk',
        capturedAt: DateTime(2026, 5, 25, 7, 45),
        createdAt: DateTime(2026, 5, 25, 7, 45),
      ),
    );
    when(
      () => captureService.buildTaskCorpusSnapshot(
        allowedCategoryIds: any(named: 'allowedCategoryIds'),
        day: any(named: 'day'),
      ),
    ).thenAnswer((_) async => const []);
  }

  setUp(() {
    repository = MockAgentRepository();
    aiConfigRepository = MockAiConfigRepository();
    cloudInferenceRepository = MockCloudInferenceRepository();
    syncService = MockAgentSyncService();
    templateService = MockAgentTemplateService();
    domainLogger = MockDomainLogger();
    conversationRepository = _ConversationHarness();
    currentState = state();
    upsertedEntities = [];
    changedTokens = [];

    stubDomainLogger();
    stubInferenceProfile();

    when(() => repository.getAgentState(agentId)).thenAnswer(
      (_) async => currentState,
    );
    when(
      () => repository.getMessagesByKind(agentId, AgentMessageKind.observation),
    ).thenAnswer((_) async => []);
    when(() => repository.getEntitiesByIds(any())).thenAnswer(
      (_) async => const <String, AgentDomainEntity>{},
    );
    // The memory substrate loads submitted captures each wake (inline
    // events); default to none.
    when(
      () => repository.getEntitiesByAgentId(agentId, type: any(named: 'type')),
    ).thenAnswer((_) async => const <AgentDomainEntity>[]);
    // Capture events are now built from lightweight metadata; transcripts are
    // resolved lazily per id via getEntity. Default: no captures.
    when(
      () => repository.getCaptureEventMetaByAgentId(agentId),
    ).thenAnswer((_) async => const []);
    when(
      () => repository.getAttentionPlanningInputsForWindow(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => const AttentionPlanningInputs.empty());
    when(
      () => repository.updateWakeRunTemplate(
        any(),
        any(),
        any(),
        resolvedModelId: any(named: 'resolvedModelId'),
        soulId: any(named: 'soulId'),
        soulVersionId: any(named: 'soulVersionId'),
      ),
    ).thenAnswer((_) async {});
    when(() => templateService.getTemplateForAgent(agentId)).thenAnswer(
      (_) async => template(),
    );
    when(() => templateService.getActiveVersion(templateId)).thenAnswer(
      (_) async => version(),
    );
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.single as AgentDomainEntity;
      upsertedEntities.add(entity);
      if (entity is AgentStateEntity) {
        currentState = entity;
      }
    });
    stubAppendMilestone(syncService);
    stubReconciledAgentState(syncService, repository);
  });

  group('DayAgentWorkflow', () {
    test('fails the wake when no reconciled agent state exists', () async {
      when(
        () => syncService.reconciledAgentState(agentId),
      ).thenAnswer((_) async => null);

      final result = await execute(workflow());

      expect(result.success, isFalse);
      expect(result.error, 'No agent state found');
      // Nothing ran: no conversation, no persisted entities.
      expect(conversationRepository.lastUserMessage, isNull);
      expect(upsertedEntities, isEmpty);
    });

    test('fails the wake when no day can be resolved from tokens', () async {
      // Post-cutover the planner has no activeDayId slot: a wake with no day
      // token and no capture cannot resolve a workspace and must fail fast
      // (ADR 0022 Decision 3).
      final result = await execute(workflow(), triggerTokens: const {});

      expect(result.success, isFalse);
      expect(result.error, 'No active day ID');
      expect(conversationRepository.lastUserMessage, isNull);
      expect(upsertedEntities, isEmpty);
    });

    test('fails the wake when no inference provider is configured', () async {
      // The profile resolves but its thinking model has no matching provider
      // model, so ProfileResolver.resolve() returns null and the wake aborts
      // before any conversation is started.
      when(
        () => aiConfigRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => const []);

      final result = await execute(workflow());

      expect(result.success, isFalse);
      expect(result.error, 'No inference provider configured');
      expect(conversationRepository.createdConversationCount, 0);
      expect(conversationRepository.lastUserMessage, isNull);
      expect(upsertedEntities, isEmpty);
    });

    // A null template context (no template, or no active version) forces the
    // profile to null, so the wake aborts at the inference-provider guard
    // BEFORE any conversation is created. The scaffold-only system prompt and
    // the `templateCtx != null` guard around updateWakeRunTemplate are
    // therefore unreachable while the profile guard fires first.
    for (final (name, stub) in [
      (
        'no template is assigned',
        () => when(
          () => templateService.getTemplateForAgent(agentId),
        ).thenAnswer((_) async => null),
      ),
      (
        'the active template version is missing',
        () => when(
          () => templateService.getActiveVersion(templateId),
        ).thenAnswer((_) async => null),
      ),
    ]) {
      test('aborts the wake when $name', () async {
        stub();

        final result = await execute(workflow());

        expect(result.success, isFalse);
        expect(result.error, 'No inference provider configured');
        expect(conversationRepository.createdConversationCount, 0);
        expect(upsertedEntities, isEmpty);
        verifyNever(
          () => repository.updateWakeRunTemplate(
            any(),
            any(),
            any(),
            resolvedModelId: any(named: 'resolvedModelId'),
            soulId: any(named: 'soulId'),
            soulVersionId: any(named: 'soulVersionId'),
          ),
        );
      });
    }

    test(
      'resolves the day from a planning_day token without the legacy slot',
      () async {
        // Empty slot proves the wake derives its day from trigger tokens
        // (ADR 0022), not from state.slots.activeDayId.
        currentState = state(activeDayId: '');

        final result = await execute(
          workflow(),
          triggerTokens: {dayAgentPlanningDayToken(dayId)},
        );

        expect(result.success, isTrue);
        expect(sentPrompt().section('day_id'), dayId);
      },
    );

    test(
      'fails fast when trigger tokens claim conflicting day workspaces',
      () async {
        final result = await execute(
          workflow(),
          triggerTokens: {
            dayAgentDraftingToken('dayplan-2026-05-25'),
            dayAgentRefineToken('dayplan-2026-05-26'),
          },
        );

        expect(result.success, isFalse);
        expect(result.error, contains('Ambiguous day workspace'));
        // Nothing ran: no conversation, no persisted entities.
        expect(conversationRepository.lastUserMessage, isNull);
        expect(upsertedEntities, isEmpty);
      },
    );

    test(
      'a capture-only wake resolves its day from the capture, not the slot',
      () async {
        // Empty slot + only a capture token: the day must come from the
        // capture's own dayId scope (ADR 0022), not state.slots.activeDayId.
        currentState = state(activeDayId: '');
        final captureService = MockDayAgentCaptureService();
        when(() => captureService.getCapture('capture-1')).thenAnswer(
          (_) async => makeTestCapture(
            id: 'capture-1',
            agentId: agentId,
            transcript: 'buy milk',
            capturedAt: DateTime(2026, 5, 25, 7),
            createdAt: DateTime(2026, 5, 25, 7),
            dayId: dayId,
          ),
        );
        when(
          () => captureService.buildTaskCorpusSnapshot(
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            day: any(named: 'day'),
          ),
        ).thenAnswer((_) async => const []);
        when(
          () => captureService.parsedItemsForCapture('capture-1'),
        ).thenAnswer((_) async => const []);
        when(
          () => captureService.executeTool(
            agentId: agentId,
            threadId: threadId,
            runKey: runKey,
            toolName: DayAgentToolNames.parseCaptureToItems,
            args: any(named: 'args'),
          ),
        ).thenAnswer(
          (_) async => DayAgentDirectToolResult.success(const {
            'captureId': 'capture-1',
            'items': [
              {
                'kind': 'newTask',
                'title': 'buy milk',
                'categoryId': 'home',
                'confidenceScore': 0.4,
              },
            ],
          }),
        );
        conversationRepository.toolCalls = [
          _toolCall(
            name: DayAgentToolNames.parseCaptureToItems,
            args: const {
              'captureId': 'capture-1',
              'items': [
                {
                  'kind': 'newTask',
                  'title': 'buy milk',
                  'categoryId': 'home',
                  'confidenceScore': 0.4,
                },
              ],
            },
          ),
        ];

        final result = await execute(
          workflow(captureService: captureService),
          triggerTokens: {dayAgentCaptureSubmittedToken('capture-1')},
        );

        expect(result.success, isTrue);
        expect(sentPrompt().section('day_id'), dayId);
      },
    );

    test(
      'a capture-only wake is ambiguous when its captures span two days',
      () async {
        currentState = state(activeDayId: '');
        final captureService = MockDayAgentCaptureService();
        when(() => captureService.getCapture('cap-a')).thenAnswer(
          (_) async => makeTestCapture(
            id: 'cap-a',
            agentId: agentId,
            dayId: 'dayplan-2026-05-25',
          ),
        );
        when(() => captureService.getCapture('cap-b')).thenAnswer(
          (_) async => makeTestCapture(
            id: 'cap-b',
            agentId: agentId,
            dayId: 'dayplan-2026-05-26',
          ),
        );

        final result = await execute(
          workflow(captureService: captureService),
          triggerTokens: {
            dayAgentCaptureSubmittedToken('cap-a'),
            dayAgentCaptureSubmittedToken('cap-b'),
          },
        );

        expect(result.success, isFalse);
        expect(
          result.error,
          contains('Ambiguous day workspace across captures'),
        );
        expect(conversationRepository.lastUserMessage, isNull);
      },
    );

    test(
      'record_observations is handled by the strategy and never routed to '
      'the capture or plan services',
      () async {
        // The workflow handler only routes capture/plan/set_next_wake names;
        // record_observations is intercepted by the strategy beforehand.
        expect(
          DayAgentToolNames.workflowHandlerTools,
          isNot(contains(DayAgentToolNames.recordObservations)),
        );

        final captureService = MockDayAgentCaptureService();
        final planService = MockDayAgentPlanService();
        conversationRepository.toolCalls = [
          _toolCall(
            name: DayAgentToolNames.recordObservations,
            args: {
              'observations': ['Morning wake was useful.'],
            },
          ),
        ];

        final result = await execute(
          workflow(captureService: captureService, planService: planService),
        );

        expect(result.success, isTrue);
        expect(
          conversationRepository.toolResponses.single,
          'Recorded 1 observation(s).',
        );
        verifyNever(
          () => captureService.executeTool(
            agentId: any(named: 'agentId'),
            threadId: any(named: 'threadId'),
            runKey: any(named: 'runKey'),
            toolName: any(named: 'toolName'),
            args: any(named: 'args'),
          ),
        );
        verifyNever(
          () => planService.executeTool(
            agentId: any(named: 'agentId'),
            threadId: any(named: 'threadId'),
            runKey: any(named: 'runKey'),
            toolName: any(named: 'toolName'),
            args: any(named: 'args'),
          ),
        );
      },
    );

    group('search_memory recall', () {
      test('recalls matching log detail through the dispatch', () async {
        when(() => syncService.repository).thenReturn(repository);
        when(
          () => repository.getMessagesByKind(agentId, AgentMessageKind.system),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getMessagesByKind(agentId, AgentMessageKind.summary),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getLinksFrom(agentId),
        ).thenAnswer((_) async => []);
        final capture =
            AgentDomainEntity.capture(
                  id: 'cap-1',
                  agentId: agentId,
                  transcript: 'remember to buy oat milk',
                  capturedAt: DateTime.utc(2026, 5, 20, 7),
                  createdAt: DateTime.utc(2026, 5, 20, 7, 1),
                  vectorClock: null,
                )
                as CaptureEntity;
        when(() => repository.getCaptureEventMetaByAgentId(agentId)).thenAnswer(
          (_) async => [
            (
              id: capture.id,
              createdAt: capture.createdAt,
              capturedAt: capture.capturedAt,
            ),
          ],
        );
        when(
          () => repository.getEntity('cap-1'),
        ).thenAnswer((_) async => capture);

        conversationRepository.toolCalls = [
          _toolCall(
            name: DayAgentToolNames.searchMemory,
            args: {'query': 'oat milk'},
          ),
        ];

        final result = await execute(workflow());

        expect(result.success, isTrue);
        final response = conversationRepository.toolResponses.single;
        expect(response, contains('remember to buy oat milk'));
        expect(response, contains('(capture'));
      });

      test('rejects a call with neither query nor ids', () async {
        conversationRepository.toolCalls = [
          _toolCall(
            name: DayAgentToolNames.searchMemory,
            args: {'query': '   '},
          ),
        ];

        final result = await execute(workflow());

        expect(result.success, isTrue);
        expect(
          conversationRepository.toolResponses.single,
          'Error: provide "query" keywords or "ids" to recall.',
        );
      });

      void stubLogReads() {
        when(() => syncService.repository).thenReturn(repository);
        when(
          () => repository.getMessagesByKind(agentId, AgentMessageKind.system),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getMessagesByKind(agentId, AgentMessageKind.summary),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getLinksFrom(agentId),
        ).thenAnswer((_) async => []);
      }

      test('reports no match when nothing in the log matches', () async {
        stubLogReads();
        final capture =
            AgentDomainEntity.capture(
                  id: 'cap-1',
                  agentId: agentId,
                  transcript: 'buy oat milk',
                  capturedAt: DateTime.utc(2026, 5, 20, 7),
                  createdAt: DateTime.utc(2026, 5, 20, 7, 1),
                  vectorClock: null,
                )
                as CaptureEntity;
        when(() => repository.getCaptureEventMetaByAgentId(agentId)).thenAnswer(
          (_) async => [
            (
              id: capture.id,
              createdAt: capture.createdAt,
              capturedAt: capture.capturedAt,
            ),
          ],
        );
        when(
          () => repository.getEntity('cap-1'),
        ).thenAnswer((_) async => capture);
        conversationRepository.toolCalls = [
          _toolCall(
            name: DayAgentToolNames.searchMemory,
            args: {'query': 'zzz nonsense'},
          ),
        ];

        final result = await execute(workflow());
        expect(result.success, isTrue);
        expect(
          conversationRepository.toolResponses.single,
          contains('No memory entries match'),
        );
      });

      test(
        'absorbs a capture-metadata load failure and still answers',
        () async {
          stubLogReads();
          when(
            () => repository.getCaptureEventMetaByAgentId(agentId),
          ).thenThrow(StateError('meta down'));
          conversationRepository.toolCalls = [
            _toolCall(
              name: DayAgentToolNames.searchMemory,
              args: {'query': 'anything'},
            ),
          ];

          final result = await execute(workflow());
          expect(result.success, isTrue);
          expect(
            conversationRepository.toolResponses.single,
            contains('No memory entries match'),
          );
        },
      );

      test('returns a tool error when the log search throws', () async {
        when(() => syncService.repository).thenReturn(repository);
        when(
          () => repository.getCaptureEventMetaByAgentId(agentId),
        ).thenAnswer((_) async => const []);
        when(
          () => repository.getMessagesByKind(agentId, AgentMessageKind.system),
        ).thenThrow(StateError('log down'));
        conversationRepository.toolCalls = [
          _toolCall(
            name: DayAgentToolNames.searchMemory,
            args: {'query': 'anything'},
          ),
        ];

        final result = await execute(workflow());
        expect(result.success, isTrue);
        expect(
          conversationRepository.toolResponses.single,
          contains('memory search failed'),
        );
      });

      test('follows a link by pulling up the entry by id', () async {
        stubLogReads();
        final capture =
            AgentDomainEntity.capture(
                  id: 'cap-1',
                  agentId: agentId,
                  transcript: 'remember to buy oat milk',
                  capturedAt: DateTime.utc(2026, 5, 20, 7),
                  createdAt: DateTime.utc(2026, 5, 20, 7, 1),
                  vectorClock: null,
                )
                as CaptureEntity;
        when(() => repository.getCaptureEventMetaByAgentId(agentId)).thenAnswer(
          (_) async => [
            (
              id: capture.id,
              createdAt: capture.createdAt,
              capturedAt: capture.capturedAt,
            ),
          ],
        );
        when(
          () => repository.getEntity('cap-1'),
        ).thenAnswer((_) async => capture);

        conversationRepository.toolCalls = [
          _toolCall(
            name: DayAgentToolNames.searchMemory,
            args: {
              'ids': ['cap-1'],
            },
          ),
        ];

        final result = await execute(workflow());
        expect(result.success, isTrue);
        final response = conversationRepository.toolResponses.single;
        expect(response, contains('for ids cap-1'));
        expect(response, contains('(id: cap-1)'));
        expect(response, contains('remember to buy oat milk'));
      });

      test('reports no match when none of the requested ids resolve', () async {
        stubLogReads();
        when(
          () => repository.getCaptureEventMetaByAgentId(agentId),
        ).thenAnswer((_) async => const []);
        conversationRepository.toolCalls = [
          _toolCall(
            name: DayAgentToolNames.searchMemory,
            args: {
              'ids': ['ghost'],
            },
          ),
        ];

        final result = await execute(workflow());
        expect(result.success, isTrue);
        expect(
          conversationRepository.toolResponses.single,
          'No memory entries match ids ghost.',
        );
      });

      test('renders author-time links and supersession on hits', () async {
        when(() => syncService.repository).thenReturn(repository);
        when(
          () => repository.getMessagesByKind(agentId, AgentMessageKind.system),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getMessagesByKind(agentId, AgentMessageKind.summary),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getLinksFrom(agentId),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getCaptureEventMetaByAgentId(agentId),
        ).thenAnswer((_) async => const []);

        AgentMessageEntity obs(String id, DateTime at) =>
            AgentDomainEntity.agentMessage(
                  id: id,
                  agentId: agentId,
                  threadId: id,
                  kind: AgentMessageKind.observation,
                  createdAt: at,
                  vectorClock: null,
                  contentEntryId: 'pl-$id',
                  metadata: const AgentMessageMetadata(),
                )
                as AgentMessageEntity;
        AgentMessagePayloadEntity payload(String id, String text) =>
            AgentDomainEntity.agentMessagePayload(
                  id: 'pl-$id',
                  agentId: agentId,
                  createdAt: DateTime.utc(2026, 5, 20),
                  vectorClock: null,
                  content: <String, Object?>{'text': text},
                )
                as AgentMessagePayloadEntity;

        when(
          () => repository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer(
          (_) async => [
            obs('obs-a', DateTime.utc(2026, 5, 20)),
            obs('obs-b', DateTime.utc(2026, 5, 21)),
            obs('obs-c', DateTime.utc(2026, 5, 22)),
          ],
        );
        when(
          () => repository.getEntity('pl-obs-a'),
        ).thenAnswer((_) async => payload('obs-a', 'old gym plan'));
        when(() => repository.getEntity('pl-obs-b')).thenAnswer(
          (_) async => payload(
            'obs-b',
            'new gym plan [[supersedes:obs-a]] [[relates:ghost]]',
          ),
        );
        when(
          () => repository.getEntity('pl-obs-c'),
        ).thenAnswer(
          (_) async => payload('obs-c', 'gym recap [[relates:obs-a]]'),
        );

        conversationRepository.toolCalls = [
          _toolCall(
            name: DayAgentToolNames.searchMemory,
            args: {'query': 'gym'},
          ),
        ];

        final result = await execute(workflow());
        expect(result.success, isTrue);
        final response = conversationRepository.toolResponses.single;
        // obs-a is flagged as superseded by the newer obs-b.
        expect(
          response,
          contains('(id: obs-a) old gym plan [superseded by obs-b]'),
        );
        // obs-b surfaces its outgoing links: supersedes keeps the old id, the
        // dead one is annotated.
        expect(
          response,
          contains('links: supersedes:obs-a, relates:ghost (not found)'),
        );
        // obs-c's relates link forward-follows the superseded target to live.
        expect(response, contains('links: relates:obs-a → obs-b'));
      });

      test('validates a link to a knowledge entry via its key', () async {
        final ks = MockDayAgentKnowledgeService();
        when(() => ks.activeFor(agentId)).thenAnswer((_) async => const []);
        when(() => ks.allFor(agentId)).thenAnswer(
          (_) async => [
            AgentDomainEntity.plannerKnowledge(
                  id: 'k1',
                  agentId: agentId,
                  key: 'deep-work',
                  hook: 'h',
                  statementText: 's',
                  source: KnowledgeSource.userStated,
                  status: KnowledgeStatus.confirmed,
                  createdAt: now,
                  updatedAt: now,
                  vectorClock: null,
                )
                as PlannerKnowledgeEntity,
          ],
        );
        when(() => syncService.repository).thenReturn(repository);
        when(
          () => repository.getMessagesByKind(agentId, AgentMessageKind.system),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getMessagesByKind(agentId, AgentMessageKind.summary),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getLinksFrom(agentId),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getCaptureEventMetaByAgentId(agentId),
        ).thenAnswer((_) async => const []);
        when(
          () => repository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer(
          (_) async => [
            AgentDomainEntity.agentMessage(
                  id: 'obs',
                  agentId: agentId,
                  threadId: 'obs',
                  kind: AgentMessageKind.observation,
                  createdAt: DateTime.utc(2026, 5, 20),
                  vectorClock: null,
                  contentEntryId: 'pl-obs',
                  metadata: const AgentMessageMetadata(),
                )
                as AgentMessageEntity,
          ],
        );
        when(() => repository.getEntity('pl-obs')).thenAnswer(
          (_) async =>
              AgentDomainEntity.agentMessagePayload(
                    id: 'pl-obs',
                    agentId: agentId,
                    createdAt: DateTime.utc(2026, 5, 20),
                    vectorClock: null,
                    content: const {'text': 'topic map [[relates:deep-work]]'},
                  )
                  as AgentMessagePayloadEntity,
        );

        conversationRepository.toolCalls = [
          _toolCall(
            name: DayAgentToolNames.searchMemory,
            args: {'query': 'topic'},
          ),
        ];

        final result = await execute(workflow(knowledgeService: ks));
        expect(result.success, isTrue);
        final response = conversationRepository.toolResponses.single;
        // The knowledge key resolves (not a dead link) because the workflow
        // widened validation with the planner's knowledge keys.
        expect(response, contains('links: relates:deep-work'));
        expect(response, isNot(contains('relates:deep-work (not found)')));
      });
    });

    group('propose_knowledge dispatch', () {
      test('routes propose_knowledge through the knowledge service', () async {
        final knowledgeService = MockDayAgentKnowledgeService();
        when(
          () => knowledgeService.executeTool(
            agentId: agentId,
            toolName: DayAgentToolNames.proposeKnowledge,
            args: any(named: 'args'),
          ),
        ).thenAnswer(
          (_) async => DayAgentDirectToolResult.success(const {
            'id': 'k1',
            'key': 'deep-work',
            'status': 'confirmed',
          }),
        );
        conversationRepository.toolCalls = [
          _toolCall(
            name: DayAgentToolNames.proposeKnowledge,
            args: {
              'key': 'deep-work',
              'hook': 'h',
              'statement': 's',
              'source': 'userStated',
            },
          ),
        ];

        final result = await execute(
          workflow(knowledgeService: knowledgeService),
        );
        expect(result.success, isTrue);
        verify(
          () => knowledgeService.executeTool(
            agentId: agentId,
            toolName: DayAgentToolNames.proposeKnowledge,
            args: any(named: 'args'),
          ),
        ).called(1);
      });

      test('errors when no knowledge service is configured', () async {
        conversationRepository.toolCalls = [
          _toolCall(
            name: DayAgentToolNames.proposeKnowledge,
            args: {'key': 'k', 'hook': 'h', 'statement': 's'},
          ),
        ];

        final result = await execute(workflow());
        expect(result.success, isTrue);
        expect(
          conversationRepository.toolResponses.single,
          contains('durable-knowledge tools are not configured'),
        );
      });
    });

    group('knowledge scope edge paths', () {
      test(
        'omits knowledge blocks when the knowledge service throws',
        () async {
          final knowledgeService = MockDayAgentKnowledgeService();
          when(
            () => knowledgeService.activeFor(agentId),
          ).thenThrow(StateError('knowledge down'));

          final result = await execute(
            workflow(knowledgeService: knowledgeService),
          );
          expect(result.success, isTrue);
          final sent = sentPrompt();
          expect(sent.has('knowledge_index'), isFalse);
          expect(sent.has('knowledge_statements'), isFalse);
        },
      );

      test(
        'injects project-scoped knowledge for a project-targeted claim',
        () async {
          final claim =
              AgentDomainEntity.attentionRequest(
                    id: 'c-proj',
                    agentId: 'task-agent',
                    kind: AttentionRequestKind.project,
                    title: 'Project X',
                    categoryId: 'work',
                    requestedMinutes: 60,
                    impact: 3,
                    urgency: 3,
                    energyFit: AttentionEnergyFit.high,
                    evidenceRefs: const [],
                    createdAt: DateTime.utc(2026, 5, 24),
                    vectorClock: null,
                    targetKind: 'project',
                    targetId: 'proj-1',
                  )
                  as AttentionRequestEntity;
          when(
            () => repository.getAttentionPlanningInputsForWindow(
              start: any(named: 'start'),
              end: any(named: 'end'),
            ),
          ).thenAnswer(
            (_) async => AttentionPlanningInputs(
              claims: [claim],
              standingAgreements: const [],
            ),
          );
          final knowledgeService = MockDayAgentKnowledgeService();
          when(() => knowledgeService.activeFor(agentId)).thenAnswer(
            (_) async => [
              AgentDomainEntity.plannerKnowledge(
                    id: 'k-proj',
                    agentId: agentId,
                    key: 'proj-pref',
                    hook: 'project hook',
                    statementText: 'Protect project X mornings.',
                    source: KnowledgeSource.userStated,
                    status: KnowledgeStatus.confirmed,
                    createdAt: DateTime(2026, 5, 20),
                    updatedAt: DateTime(2026, 5, 20),
                    vectorClock: null,
                    scope: 'project:proj-1',
                  )
                  as PlannerKnowledgeEntity,
            ],
          );

          final result = await execute(
            workflow(knowledgeService: knowledgeService),
          );
          expect(result.success, isTrue);
          // The project-targeted claim put project:proj-1 in touched scopes, so
          // the project-scoped statement is pulled in.
          expect(
            sentPrompt().section('knowledge_statements'),
            contains('Protect project X morn'),
          );
        },
      );
    });

    test('read-flips to a dayLog of capture transcripts and observations, '
        'dropping the recentObservations listing', () async {
      when(() => syncService.repository).thenReturn(repository);
      when(
        () => repository.getMessagesByKind(agentId, AgentMessageKind.system),
      ).thenAnswer((_) async => []);
      when(
        () => repository.getMessagesByKind(agentId, AgentMessageKind.summary),
      ).thenAnswer((_) async => []);
      when(() => repository.getLinksFrom(agentId)).thenAnswer((_) async => []);
      final capture =
          AgentDomainEntity.capture(
                id: 'cap-1',
                agentId: agentId,
                transcript: 'morning planning capture',
                capturedAt: DateTime.utc(2026, 5, 25, 7),
                createdAt: DateTime.utc(2026, 5, 25, 7, 1),
                vectorClock: null,
              )
              as CaptureEntity;
      // The substrate loads only lightweight metadata; the transcript is
      // resolved lazily (tail only) via getEntity.
      when(() => repository.getCaptureEventMetaByAgentId(agentId)).thenAnswer(
        (_) async => [
          (
            id: capture.id,
            createdAt: capture.createdAt,
            capturedAt: capture.capturedAt,
          ),
        ],
      );
      when(
        () => repository.getEntity('cap-1'),
      ).thenAnswer((_) async => capture);
      final obs = AgentDomainEntity.agentMessage(
        id: 'obs-1',
        agentId: agentId,
        threadId: 'old-thread',
        kind: AgentMessageKind.observation,
        createdAt: DateTime.utc(2026, 5, 25, 8),
        vectorClock: null,
        contentEntryId: 'obs-payload-1',
        metadata: const AgentMessageMetadata(),
      );
      when(
        () =>
            repository.getMessagesByKind(agentId, AgentMessageKind.observation),
      ).thenAnswer((_) async => [obs as AgentMessageEntity]);
      when(() => repository.getEntity('obs-payload-1')).thenAnswer(
        (_) async => AgentDomainEntity.agentMessagePayload(
          id: 'obs-payload-1',
          agentId: agentId,
          createdAt: DateTime.utc(2026, 5, 25, 8),
          vectorClock: null,
          content: const {'text': 'a day observation'},
        ),
      );

      final sut = DayAgentWorkflow(
        agentRepository: repository,
        conversationRepository: conversationRepository,
        aiConfigRepository: aiConfigRepository,
        cloudInferenceRepository: cloudInferenceRepository,
        syncService: syncService,
        templateService: templateService,
        domainLogger: domainLogger,
        onPersistedStateChanged: changedTokens.add,
      );
      final result = await execute(
        sut,
        triggerTokens: {dayAgentPlanningDayToken(dayId)},
      );
      expect(result.success, isTrue);

      // The SENT prompt carries the dayLog with capture transcripts and
      // observations interleaved in event order (capture 07:01 before
      // observation 08:00), superseding the recentObservations listing.
      final sent = conversationRepository.lastUserMessage!;
      expect(sent, contains('<day_log>'));
      expect(sent, contains('(id: cap-1, capture) morning planning capture'));
      expect(sent, contains('(id: obs-1, observation) a day observation'));
      expect(sent, isNot(contains('<recent_observations>')));
      expect(
        sent.indexOf('morning planning capture'),
        lessThan(sent.indexOf('a day observation')),
      );

      // The PERSISTED payload is a v2 record with the derivable line
      // stripped and the marker stored.
      final record = upsertedEntities
          .whereType<AgentMessagePayloadEntity>()
          .map((p) => p.content)
          .firstWhere((c) => c['promptFormat'] == 'v2');
      final head = record['head']! as String;
      final tail = record['tail']! as String;
      expect(record['wrap'], 'day-log-section');
      expect(head, contains('<day_id>'));
      // The whole derivable `<day_log>…</day_log>` section is stripped from
      // storage; head ends before it and tail begins after it.
      expect(head, isNot(contains('<day_log>')));
      expect(tail, isNot(contains('</day_log>')));
      expect(tail, contains('<trigger_tokens>'));
      // The derivable log content is gone from storage…
      expect(head + tail, isNot(contains('morning planning capture')));
      // …and the substrate supersedes the separate listing.
      expect(head + tail, isNot(contains('<recent_observations>')));
      final marker = record['log']! as Map<String, Object?>;
      expect(marker['until'], isNotNull);

      // End-to-end: the persisted record must reconstruct byte-identically
      // to the prompt the wake actually sent — the head/tail boundaries and
      // the re-rendered <day_log> section have to line up exactly (ADR 0020).
      when(
        () => repository.getEntitiesByAgentId(
          agentId,
          type: AgentEntityTypes.capture,
        ),
      ).thenAnswer((_) async => [capture]);
      final reconstructed = await WakePromptReconstructor(
        syncService: syncService,
      ).reconstruct(agentId: agentId, content: record);
      expect(reconstructed, conversationRepository.lastUserMessage);
    });

    test('falls back to the legacy prompt when the capture-entity load '
        'throws', () async {
      // The substrate is an optimization: a failed capture load is absorbed,
      // the read-flip gate stays closed, and the wake proceeds legacy-shaped.
      when(() => syncService.repository).thenReturn(repository);
      when(
        () => repository.getMessagesByKind(agentId, AgentMessageKind.system),
      ).thenAnswer((_) async => []);
      when(
        () => repository.getMessagesByKind(agentId, AgentMessageKind.summary),
      ).thenAnswer((_) async => []);
      when(() => repository.getLinksFrom(agentId)).thenAnswer((_) async => []);
      when(
        () => repository.getCaptureEventMetaByAgentId(agentId),
      ).thenThrow(StateError('capture table unavailable'));

      final sut = DayAgentWorkflow(
        agentRepository: repository,
        conversationRepository: conversationRepository,
        aiConfigRepository: aiConfigRepository,
        cloudInferenceRepository: cloudInferenceRepository,
        syncService: syncService,
        templateService: templateService,
        domainLogger: domainLogger,
        onPersistedStateChanged: changedTokens.add,
      );
      final result = await execute(
        sut,
        triggerTokens: {dayAgentPlanningDayToken(dayId)},
      );
      expect(result.success, isTrue);

      // No day_log in the sent prompt, and the persisted payload stays a
      // legacy full blob (no v2 record without a usable compacted log).
      expect(
        conversationRepository.lastUserMessage,
        isNot(contains('<day_log>')),
      );
      final v2Records = upsertedEntities
          .whereType<AgentMessagePayloadEntity>()
          .map((p) => p.content)
          .where((c) => c['promptFormat'] == 'v2');
      expect(v2Records, isEmpty);
    });

    test('renders attention-planning claims and standing agreements into the '
        'sent prompt', () async {
      when(() => syncService.repository).thenReturn(repository);
      when(
        () => repository.getMessagesByKind(agentId, AgentMessageKind.system),
      ).thenAnswer((_) async => []);
      when(
        () => repository.getMessagesByKind(agentId, AgentMessageKind.summary),
      ).thenAnswer((_) async => []);
      when(() => repository.getLinksFrom(agentId)).thenAnswer((_) async => []);

      final claim =
          AgentDomainEntity.attentionRequest(
                id: 'attn-claim-1',
                agentId: 'task-agent-7',
                kind: AttentionRequestKind.task,
                title: 'Finish tax packet',
                categoryId: 'work',
                requestedMinutes: 90,
                impact: 5,
                urgency: 4,
                energyFit: AttentionEnergyFit.high,
                evidenceRefs: const [
                  AttentionEvidenceRef(
                    kind: AttentionEvidenceKind.task,
                    id: 'task-9',
                    label: 'Tax packet',
                  ),
                ],
                scopeKind: AttentionClaimScopeKind.dateRange,
                earliestStart: DateTime.utc(2026, 5, 25, 9),
                latestEnd: DateTime.utc(2026, 5, 25, 17),
                deadline: DateTime.utc(2026, 5, 26, 12),
                targetId: 'task-9',
                targetKind: 'task',
                rationale: 'Due soon and still needs a focused block.',
                createdAt: DateTime.utc(2026, 5, 24, 8),
                vectorClock: null,
              )
              as AttentionRequestEntity;
      final agreement =
          AgentDomainEntity.standingAgreement(
                id: 'agreement-1',
                agentId: 'soul-agent-2',
                title: 'Exercise three times a week',
                scope: StandingAgreementScope.fitness,
                cadence: StandingAgreementCadence.weekly,
                categoryId: 'health',
                minCount: 3,
                priority: 2,
                rationale: 'Keep weekly movement consistent.',
                createdAt: DateTime.utc(2026, 5, 1, 8),
                updatedAt: DateTime.utc(2026, 5, 1, 8),
                vectorClock: null,
              )
              as StandingAgreementEntity;
      when(
        () => repository.getAttentionPlanningInputsForWindow(
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).thenAnswer(
        (_) async => AttentionPlanningInputs(
          claims: [claim],
          standingAgreements: [agreement],
        ),
      );

      final result = await execute(
        workflow(),
        triggerTokens: {dayAgentPlanningDayToken(dayId)},
      );
      expect(result.success, isTrue);

      final attentionPlanning = sentPrompt().json('attention_planning')! as Map;
      final claims = attentionPlanning['claims'] as List;
      expect(claims, hasLength(1));
      final renderedClaim = claims.single as Map;
      expect(renderedClaim['id'], 'attn-claim-1');
      expect(renderedClaim['kind'], 'task');
      expect(renderedClaim['requestedMinutes'], 90);
      expect(renderedClaim['energyFit'], 'high');
      expect(renderedClaim['scopeKind'], 'dateRange');
      expect(renderedClaim['earliestStart'], '2026-05-25T09:00:00.000Z');
      expect(renderedClaim['deadline'], '2026-05-26T12:00:00.000Z');
      expect(
        (renderedClaim['evidenceRefs'] as List).single,
        {'kind': 'task', 'id': 'task-9', 'label': 'Tax packet'},
      );

      final agreements = attentionPlanning['standingAgreements'] as List;
      expect(agreements, hasLength(1));
      final renderedAgreement = agreements.single as Map;
      expect(renderedAgreement['id'], 'agreement-1');
      expect(renderedAgreement['scope'], 'fitness');
      expect(renderedAgreement['cadence'], 'weekly');
      expect(renderedAgreement['enforcement'], 'target');
      expect(renderedAgreement['approvalMode'], 'ask');
      expect(renderedAgreement['minCount'], 3);
      expect(renderedAgreement['priority'], 2);
      expect(
        renderedAgreement['rationale'],
        'Keep weekly movement consistent.',
      );
    });

    test('absorbs a failure loading attention-planning inputs', () async {
      when(() => syncService.repository).thenReturn(repository);
      when(
        () => repository.getMessagesByKind(agentId, AgentMessageKind.system),
      ).thenAnswer((_) async => []);
      when(
        () => repository.getMessagesByKind(agentId, AgentMessageKind.summary),
      ).thenAnswer((_) async => []);
      when(() => repository.getLinksFrom(agentId)).thenAnswer((_) async => []);
      when(
        () => repository.getAttentionPlanningInputsForWindow(
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).thenThrow(StateError('attention window unavailable'));

      final result = await execute(
        workflow(),
        triggerTokens: {dayAgentPlanningDayToken(dayId)},
      );

      // The throwing load path is actually exercised: if the workflow stopped
      // calling getAttentionPlanningInputsForWindow, this test would no longer
      // be proving the failure is absorbed.
      verify(
        () => repository.getAttentionPlanningInputsForWindow(
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).called(1);

      // The load failure degrades to empty inputs, so the section is omitted
      // entirely (it is only rendered when non-empty) and the wake still
      // succeeds rather than propagating the error.
      expect(result.success, isTrue);
      expect(sentPrompt().has('attention_planning'), isFalse);
    });

    test(
      'records observations, schedules wake, and persists wake output',
      () async {
        final observationPayload = makeTestMessagePayload(
          id: 'payload-old-observation',
          agentId: agentId,
          createdAt: now.subtract(const Duration(hours: 2)),
          content: const {'text': 'Earlier wake was too late.'},
        );
        final observationMessage = makeTestMessage(
          id: 'old-observation',
          agentId: agentId,
          threadId: 'old-thread',
          kind: AgentMessageKind.observation,
          createdAt: now.subtract(const Duration(hours: 2)),
          contentEntryId: observationPayload.id,
          metadata: const AgentMessageMetadata(runKey: 'old-run'),
        );
        currentState = state(
          toolCounterByKey: const {
            'day_agent_set_next_wake:2026-05-24': 4,
            'unrelated_tool:host-a': 9,
          },
        );
        conversationRepository
          ..toolCalls = [
            _toolCall(
              name: DayAgentToolNames.recordObservations,
              args: {
                'observations': [
                  {
                    'text': 'Morning planning wake was useful.',
                    'priority': 'notable',
                    'category': 'operational',
                  },
                ],
              },
            ),
            _toolCall(
              id: 'call-set-wake',
              name: DayAgentToolNames.setNextWake,
              args: {
                'at': '2026-05-25T08:30:00',
                'reason': 'Check whether capture has started.',
              },
            ),
          ]
          ..finalResponse = 'Captured the morning planning state.'
          ..usage = const InferenceUsage(inputTokens: 11, outputTokens: 7);
        when(
          () => repository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => [observationMessage]);
        when(
          () => repository.getEntitiesByIds({observationPayload.id}),
        ).thenAnswer((_) async => {observationPayload.id: observationPayload});

        final result = await execute(workflow());

        expect(result.success, isTrue);
        expect(conversationRepository.deletedConversationCount, 1);
        expect(
          conversationRepository.lastTools.map((tool) => tool.function.name),
          containsAll([
            DayAgentToolNames.recordObservations,
            DayAgentToolNames.setNextWake,
          ]),
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('General day-agent directive.'),
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('Report day-agent directive.'),
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('current_local_time'),
        );

        final userPayload = sentPrompt();
        expect(userPayload.section('day_id'), dayId);
        expect(userPayload.section('plan_date'), '2026-05-25T00:00:00.000');
        expect(
          userPayload.section('current_local_time'),
          '2026-05-25T08:00:00.000',
        );
        // Volatile wall-clock must be the trailing section so the rest of the
        // payload stays a stable prefix across wakes (prefix/KV-cache reuse).
        expect(userPayload.tagsInOrder.last, 'current_local_time');
        expect(userPayload.json('trigger_tokens'), [
          dayAgentPlanningDayToken(dayId),
        ]);
        expect(
          userPayload.json('recent_observations'),
          [
            {
              'createdAt': '2026-05-25T06:00:00.000',
              'text': 'Earlier wake was too late.',
            },
          ],
        );

        // set_next_wake persists a day-scoped ScheduledWakeEntity record
        // (ADR 0022 Decision 12) rather than the clobberable state slot.
        final scheduledRecord = upsertedEntities
            .whereType<ScheduledWakeEntity>()
            .single;
        expect(scheduledRecord.scheduledAt, DateTime(2026, 5, 25, 8, 30));
        expect(scheduledRecord.status, ScheduledWakeStatus.pending);
        expect(scheduledRecord.workspaceKey, dayAgentWorkspaceKey(dayId));
        expect(
          scheduledRecord.triggerTokens,
          contains(dayAgentPlanningDayToken(dayId)),
        );
        expect(
          scheduledRecord.id,
          scheduledWakeRecordId(
            agentId,
            workspaceKey: dayAgentWorkspaceKey(dayId),
          ),
        );
        // No state carries scheduledWakeAt anymore; the cap counter is
        // re-keyed by (dayId, date) and the stale prior-date entry is GC'd.
        final scheduledState = upsertedEntities
            .whereType<AgentStateEntity>()
            .firstWhere(
              (state) => state.toolCounterByKey.keys.any(
                (k) => k.startsWith('day_agent_set_next_wake:'),
              ),
            );
        expect(scheduledState.scheduledWakeAt, isNull);
        expect(scheduledState.toolCounterByKey, {
          'unrelated_tool:host-a': 9,
          'day_agent_set_next_wake:$dayId:2026-05-25': 1,
        });
        expect(scheduledState.processedCounterByHost, isEmpty);

        final finalState = upsertedEntities.whereType<AgentStateEntity>().last;
        expect(finalState.lastWakeAt, now);
        expect(finalState.consecutiveFailureCount, 0);
        expect(finalState.wakeCounter.value, 1);
        // The completed wake event-sources lastWakeAt (PR 4, B2).
        expect(capturedMilestones(syncService), [AgentMilestone.wakeCompleted]);

        final payloads = upsertedEntities
            .whereType<AgentMessagePayloadEntity>();
        expect(
          payloads.map((payload) => payload.content['text']),
          containsAll([
            contains('Morning planning wake was useful.'),
            'Captured the morning planning state.',
          ]),
        );
        expect(
          upsertedEntities.whereType<WakeTokenUsageEntity>().single.modelId,
          'models/day',
        );
        expect(changedTokens, [agentId, agentId, dayId]);
      },
    );

    test(
      'set_next_wake normalizes a Z-suffixed time to naive-local so the due '
      'query orders it consistently against a local now',
      () async {
        currentState = state();
        conversationRepository
          ..toolCalls = [
            _toolCall(
              id: 'call-set-wake-utc',
              name: DayAgentToolNames.setNextWake,
              args: {
                // A UTC-suffixed instant, two days out so it clears the minimum
                // lead time regardless of the test machine's timezone.
                'at': '2026-05-27T12:00:00Z',
                'reason': 'Pre-warm the next morning.',
              },
            ),
          ]
          ..finalResponse = 'Scheduled.'
          ..usage = const InferenceUsage(inputTokens: 5, outputTokens: 3);

        final result = await execute(workflow());

        expect(result.success, isTrue);
        final rec = upsertedEntities.whereType<ScheduledWakeEntity>().single;
        // Persisted naive-local (no `Z`), so getDueScheduledWakeRecords'
        // lexicographic compare against a naive-local `now` stays correct —
        // and identical across devices in different timezones.
        expect(rec.scheduledAt.isUtc, isFalse);
        expect(
          rec.scheduledAt,
          DateTime.parse('2026-05-27T12:00:00Z').toLocal(),
        );
      },
    );

    test(
      'propagates the resolved model geminiThinkingMode to the wrapper',
      () async {
        when(
          () => aiConfigRepository.getConfigById('profile-day'),
        ).thenAnswer(
          (_) async => testInferenceProfile(
            id: 'profile-day',
          ),
        );
        when(
          () => aiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer(
          (_) async => [
            testAiModel(
              id: 'gemini-flash',
              inferenceProviderId: 'provider-day',
            ),
          ],
        );
        conversationRepository.finalResponse = 'Day-agent wake completed.';

        final result = await execute(workflow());

        expect(result.success, isTrue);
        expect(
          conversationRepository.sendMessageCalls.single.model,
          'models/gemini-3-flash-preview',
        );
        final inferenceRepo =
            conversationRepository.sendMessageCalls.single.inferenceRepo;
        expect(inferenceRepo, isA<CloudInferenceWrapper>());
        final wrapper = inferenceRepo as CloudInferenceWrapper;
        // testAiModel defaults to AiConfigModel.geminiThinkingMode == low.
        expect(wrapper.geminiThinkingMode, GeminiThinkingMode.low);
      },
    );

    test('includes capture context for capture-submitted wakes', () async {
      final capture = makeTestCapture(
        id: 'capture-1',
        agentId: agentId,
        transcript: 'Prep demo and buy milk',
        capturedAt: DateTime(2026, 5, 25, 7, 45),
        createdAt: DateTime(2026, 5, 25, 7, 45),
        audioRef: 'audio-1',
      );
      final captureService = MockDayAgentCaptureService();
      when(() => captureService.getCapture('capture-1')).thenAnswer(
        (_) async => capture,
      );
      when(
        () => captureService.buildTaskCorpusSnapshot(
          allowedCategoryIds: const <String>{},
          day: DateTime(2026, 5, 25),
        ),
      ).thenAnswer(
        (_) async => const [
          {
            'taskId': 'task-1',
            'title': 'Prep demo',
            'status': 'OPEN',
            'categoryId': 'work',
            'due': null,
            'estimateMinutes': 45,
            'priority': 'P2',
          },
        ],
      );
      when(
        () => captureService.executeTool(
          agentId: agentId,
          threadId: threadId,
          runKey: runKey,
          toolName: DayAgentToolNames.parseCaptureToItems,
          args: any(named: 'args'),
        ),
      ).thenAnswer(
        (_) async => DayAgentDirectToolResult.success(
          const {
            'captureId': 'capture-1',
            'items': [
              {'id': 'parsed-1'},
            ],
          },
        ),
      );
      conversationRepository.toolCalls = [
        _toolCall(
          name: DayAgentToolNames.parseCaptureToItems,
          args: const {
            'captureId': 'capture-1',
            'items': [
              {
                'kind': 'newTask',
                'title': 'Prep demo',
                'categoryId': 'work',
                'confidenceScore': 0.4,
              },
            ],
          },
        ),
      ];

      final result = await execute(
        workflow(captureService: captureService),
        triggerTokens: {
          dayAgentCaptureSubmittedToken('capture-1'),
          dayAgentPlanningDayToken(dayId),
        },
      );

      expect(result.success, isTrue);
      expectCanonicalSectionOrder(sentPrompt());
      final capturePayload =
          sentPrompt().json('capture')! as Map<String, dynamic>;
      expect(capturePayload['captureId'], 'capture-1');
      expect(capturePayload['transcript'], 'Prep demo and buy milk');
      expect(capturePayload['audioRef'], 'audio-1');
      expect(capturePayload['taskCorpus'], [
        {
          'taskId': 'task-1',
          'title': 'Prep demo',
          'status': 'OPEN',
          'categoryId': 'work',
          'due': null,
          'estimateMinutes': 45,
          'priority': 'P2',
        },
      ]);
    });

    group('capture wake parse enforcement', () {
      test(
        'forces parse_capture_to_items when a capture wake stops without '
        'parsing',
        () async {
          final captureService = MockDayAgentCaptureService();
          stubCaptureContext(captureService);
          when(
            () => captureService.executeTool(
              agentId: agentId,
              threadId: threadId,
              runKey: runKey,
              toolName: DayAgentToolNames.parseCaptureToItems,
              args: any(named: 'args'),
            ),
          ).thenAnswer(
            (_) async => DayAgentDirectToolResult.success(
              const {
                'captureId': 'capture-1',
                'items': [
                  {'id': 'parsed-1'},
                ],
              },
            ),
          );
          conversationRepository
            ..toolCallsByInvocation = [
              const <ChatCompletionMessageToolCall>[],
              [
                _toolCall(
                  id: 'parse-call',
                  name: DayAgentToolNames.parseCaptureToItems,
                  args: const {
                    'captureId': 'capture-1',
                    'items': [
                      {
                        'kind': 'newTask',
                        'title': 'Prep demo',
                        'categoryId': 'work',
                        'confidenceScore': 0.4,
                      },
                    ],
                  },
                ),
              ],
            ]
            ..usageByInvocation = const [
              InferenceUsage(inputTokens: 10, outputTokens: 5),
              InferenceUsage(inputTokens: 3, outputTokens: 2),
            ];

          final result = await execute(
            workflow(captureService: captureService),
            triggerTokens: {
              dayAgentCaptureSubmittedToken('capture-1'),
              dayAgentPlanningDayToken(dayId),
            },
          );

          expect(result.success, isTrue);
          expect(conversationRepository.sendMessageCalls, hasLength(2));
          expect(
            conversationRepository.sendMessageCalls.first.toolChoice,
            isNull,
          );

          final retryCall = conversationRepository.sendMessageCalls[1];
          expect(
            retryCall.message,
            contains('You did not call `parse_capture_to_items`'),
          );
          expect(retryCall.message, contains('capture `capture-1`'));
          expect(
            retryCall.tools.map((tool) => tool.function.name),
            [DayAgentToolNames.parseCaptureToItems],
          );
          retryCall.toolChoice!.map(
            mode: (_) => fail('Expected named tool choice, got mode.'),
            tool: (named) {
              expect(
                named.value.function.name,
                DayAgentToolNames.parseCaptureToItems,
              );
            },
          );

          final args =
              verify(
                    () => captureService.executeTool(
                      agentId: agentId,
                      threadId: threadId,
                      runKey: runKey,
                      toolName: DayAgentToolNames.parseCaptureToItems,
                      args: captureAny(named: 'args'),
                    ),
                  ).captured.single
                  as Map<String, dynamic>;
          expect(args['captureId'], 'capture-1');
          expect(args['items'], isA<List<Object?>>());

          final usage = upsertedEntities
              .whereType<WakeTokenUsageEntity>()
              .single;
          expect(usage.inputTokens, 13);
          expect(usage.outputTokens, 7);
        },
      );

      test(
        'fails the wake when the forced retry still omits parsing',
        () async {
          final captureService = MockDayAgentCaptureService();
          stubCaptureContext(captureService);
          conversationRepository.toolCallsByInvocation = [
            const <ChatCompletionMessageToolCall>[],
            const <ChatCompletionMessageToolCall>[],
          ];

          final result = await execute(
            workflow(captureService: captureService),
            triggerTokens: {
              dayAgentCaptureSubmittedToken('capture-1'),
              dayAgentPlanningDayToken(dayId),
            },
          );

          expect(result.success, isFalse);
          expect(result.error, contains('parse_capture_to_items'));
          expect(conversationRepository.sendMessageCalls, hasLength(2));
          expect(
            conversationRepository.sendMessageCalls[1].toolChoice,
            isNotNull,
          );
          final failureState = upsertedEntities
              .whereType<AgentStateEntity>()
              .last;
          expect(failureState.consecutiveFailureCount, 1);
          verifyNever(
            () => captureService.executeTool(
              agentId: any(named: 'agentId'),
              threadId: any(named: 'threadId'),
              runKey: any(named: 'runKey'),
              toolName: DayAgentToolNames.parseCaptureToItems,
              args: any(named: 'args'),
            ),
          );
        },
      );

      test(
        'does not force parsing when the submitted capture is unavailable',
        () async {
          final captureService = MockDayAgentCaptureService();
          when(() => captureService.getCapture('capture-1')).thenAnswer(
            (_) async => null,
          );

          final result = await execute(
            workflow(captureService: captureService),
            triggerTokens: {
              dayAgentCaptureSubmittedToken('capture-1'),
              dayAgentPlanningDayToken(dayId),
            },
          );

          expect(result.success, isTrue);
          expect(conversationRepository.sendMessageCalls, hasLength(1));
          expect(sentPrompt().has('capture'), isFalse);
          verify(
            () => captureService.getCapture('capture-1'),
          ).called(1);
          verifyNever(
            () => captureService.executeTool(
              agentId: any(named: 'agentId'),
              threadId: any(named: 'threadId'),
              runKey: any(named: 'runKey'),
              toolName: DayAgentToolNames.parseCaptureToItems,
              args: any(named: 'args'),
            ),
          );
        },
      );

      test(
        'fails the wake when parsing persists zero items',
        () async {
          final captureService = MockDayAgentCaptureService();
          stubCaptureContext(captureService);
          when(
            () => captureService.executeTool(
              agentId: agentId,
              threadId: threadId,
              runKey: runKey,
              toolName: DayAgentToolNames.parseCaptureToItems,
              args: any(named: 'args'),
            ),
          ).thenAnswer(
            (_) async => DayAgentDirectToolResult.success(
              const {'captureId': 'capture-1', 'items': <Object?>[]},
            ),
          );
          conversationRepository.toolCallsByInvocation = [
            const <ChatCompletionMessageToolCall>[],
            [
              _toolCall(
                id: 'parse-call',
                name: DayAgentToolNames.parseCaptureToItems,
                args: const {
                  'captureId': 'capture-1',
                  'items': [
                    {
                      'kind': 'newTask',
                      'title': 'Home-only item',
                      'categoryId': 'home',
                      'confidenceScore': 0.4,
                    },
                  ],
                },
              ),
            ],
          ];

          final result = await execute(
            workflow(captureService: captureService),
            triggerTokens: {
              dayAgentCaptureSubmittedToken('capture-1'),
              dayAgentPlanningDayToken(dayId),
            },
          );

          expect(result.success, isFalse);
          expect(result.error, contains('parse_capture_to_items'));
          expect(conversationRepository.sendMessageCalls, hasLength(2));
          verify(
            () => captureService.executeTool(
              agentId: agentId,
              threadId: threadId,
              runKey: runKey,
              toolName: DayAgentToolNames.parseCaptureToItems,
              args: any(named: 'args'),
            ),
          ).called(1);
        },
      );
    });

    test(
      'includes a null-baseline drafting context for drafting-token wakes',
      () async {
        final planService = MockDayAgentPlanService();
        stubDraftingPlanContext(planService);
        stubSuccessfulDraftToolCall(planService);

        final result = await execute(
          workflow(planService: planService),
          triggerTokens: {
            dayAgentDraftingToken(dayId),
            dayAgentPlanningDayToken(dayId),
          },
        );

        expect(result.success, isTrue);
        final draftingPayload =
            sentPrompt().json('drafting')! as Map<String, dynamic>;
        expect(draftingPayload['requested'], isTrue);
        expect(draftingPayload['baselinePlan'], isNull);
        expect(draftingPayload['decidedTasks'], isEmpty);
        verify(
          () => planService.draftPlanForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).called(1);
      },
    );

    test(
      'surfaces the existing draft as the baseline for drafting wakes',
      () async {
        final planService = MockDayAgentPlanService();
        final baselinePlan = makeTestDayPlan(
          agentId: agentId,
          planDate: DateTime(2026, 5, 25),
          data: DayPlanData(
            planDate: DateTime(2026, 5, 25),
            status: const DayPlanStatus.draft(),
            plannedBlocks: [
              PlannedBlock(
                id: 'block-1',
                categoryId: 'work',
                startTime: DateTime(2026, 5, 25, 9),
                endTime: DateTime(2026, 5, 25, 10),
                title: 'Prep demo',
                reason: 'High-energy window.',
              ),
            ],
          ),
          energyBands: [
            DayAgentEnergyBand(
              start: DateTime(2026, 5, 25, 9),
              end: DateTime(2026, 5, 25, 12),
              level: DayAgentEnergyLevel.high,
              label: 'HIGH ENERGY',
            ),
          ],
          capacityMinutes: 360,
          scheduledMinutes: 60,
          createdAt: DateTime(2026, 5, 25, 8),
          updatedAt: DateTime(2026, 5, 25, 8),
        );
        stubDraftingPlanContext(planService, baselinePlan: baselinePlan);
        stubSuccessfulDraftToolCall(planService);

        final result = await execute(
          workflow(planService: planService),
          triggerTokens: {
            dayAgentDraftingToken(dayId),
            dayAgentPlanningDayToken(dayId),
          },
        );

        expect(result.success, isTrue);
        final draftingPayload =
            sentPrompt().json('drafting')! as Map<String, dynamic>;
        final plan = draftingPayload['baselinePlan'] as Map<String, dynamic>;
        expect(plan['planId'], 'day_agent_plan:$dayId');
        expect(plan['capacityMinutes'], 360);
        expect(plan['scheduledMinutes'], 60);
        final blocks = plan['blocks'] as List<dynamic>;
        expect(blocks, hasLength(1));
        expect(
          (blocks.single as Map<String, dynamic>)['title'],
          'Prep demo',
        );
        final bands = plan['energyBands'] as List<dynamic>;
        expect(bands, hasLength(1));
        expect((bands.single as Map<String, dynamic>)['level'], 'high');
      },
    );

    test(
      'omits the drafting context when no drafting token is present',
      () async {
        final planService = MockDayAgentPlanService();

        final result = await execute(
          workflow(planService: planService),
          triggerTokens: {dayAgentPlanningDayToken(dayId)},
        );

        expect(result.success, isTrue);
        expect(sentPrompt().has('drafting'), isFalse);
        verifyNever(
          () => planService.draftPlanForDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        );
      },
    );

    test(
      'surfaces decided tasks and unlinked capture items for drafting',
      () async {
        final planService = MockDayAgentPlanService();
        final captureService = MockDayAgentCaptureService();
        final capture =
            AgentDomainEntity.capture(
                  id: 'capture-1',
                  agentId: agentId,
                  transcript: 'prep demo + buy milk',
                  capturedAt: DateTime(2026, 5, 25, 7, 45),
                  createdAt: DateTime(2026, 5, 25, 7, 45),
                  vectorClock: null,
                )
                as CaptureEntity;
        final parsedItem = makeTestParsedItem(
          id: 'parsed-1',
          agentId: agentId,
          captureId: 'capture-1',
          kind: ParsedItemKind.matched,
          title: 'Buy milk',
          categoryId: 'life',
          matchedTaskId: 'task-milk',
          createdAt: DateTime(2026, 5, 25, 7, 50),
        );
        final newParsedItem = makeTestParsedItem(
          id: 'parsed-new',
          agentId: agentId,
          captureId: 'capture-1',
          title: 'Prep demo follow-up',
          categoryId: 'work',
          confidence: ParsedItemConfidence.medium,
          confidenceScore: 0.6,
          spokenPhrase: 'prep the follow-up',
          estimateMinutes: 25,
          createdAt: DateTime(2026, 5, 25, 7, 51),
        );
        when(() => captureService.getCapture('capture-1')).thenAnswer(
          (_) async => capture,
        );
        when(
          () => captureService.buildTaskCorpusSnapshot(
            allowedCategoryIds: const <String>{},
            day: DateTime(2026, 5, 25),
          ),
        ).thenAnswer((_) async => const []);
        when(
          () => captureService.parsedItemsForCapture('capture-1'),
        ).thenAnswer((_) async => [parsedItem, newParsedItem]);
        when(
          () => planService.draftPlanForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer((_) async => null);
        when(
          () => planService.hydrateDecidedTasks(
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            explicitTaskIds: any(named: 'explicitTaskIds'),
            parsedItems: any(named: 'parsedItems'),
          ),
        ).thenAnswer(
          (_) async => const [
            DecidedTaskRef(
              id: 'task-1',
              title: 'Prep demo',
              categoryId: 'work',
            ),
            DecidedTaskRef(
              id: 'task-milk',
              title: 'Buy milk',
              categoryId: 'life',
            ),
          ],
        );
        stubSuccessfulDraftToolCall(planService);

        final result = await execute(
          workflow(
            planService: planService,
            captureService: captureService,
          ),
          triggerTokens: {
            dayAgentDraftingToken(dayId),
            dayAgentCaptureSubmittedToken('capture-1'),
            dayAgentDecidedTaskToken('task-1'),
            dayAgentDecidedCaptureItemToken('parsed-new'),
            dayId,
          },
        );

        expect(result.success, isTrue);
        final draftingPayload =
            sentPrompt().json('drafting')! as Map<String, dynamic>;
        final decidedTasks = draftingPayload['decidedTasks'] as List<dynamic>;
        expect(decidedTasks, hasLength(2));
        expect(
          (decidedTasks[0] as Map<String, dynamic>)['id'],
          'task-1',
        );
        expect(
          (decidedTasks[1] as Map<String, dynamic>)['title'],
          'Buy milk',
        );
        final decidedCaptureItems =
            draftingPayload['decidedCaptureItems'] as List<dynamic>;
        expect(decidedCaptureItems, hasLength(1));
        expect(
          (decidedCaptureItems.single as Map<String, dynamic>)['id'],
          'parsed-new',
        );
        expect(
          (decidedCaptureItems.single as Map<String, dynamic>)['title'],
          'Prep demo follow-up',
        );

        final hydrateCall = verify(
          () => planService.hydrateDecidedTasks(
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            explicitTaskIds: captureAny(named: 'explicitTaskIds'),
            parsedItems: captureAny(named: 'parsedItems'),
          ),
        ).captured;
        expect(hydrateCall.first, ['task-1']);
        final passedParsedItems = hydrateCall.last as List<ParsedItemEntity>;
        expect(passedParsedItems, hasLength(2));
        expect(passedParsedItems.first.matchedTaskId, 'task-milk');
      },
    );

    group('drafting wake final plan enforcement', () {
      test(
        'forces draft_day_plan when a drafting wake stops without drafting',
        () async {
          final planService = MockDayAgentPlanService();
          stubDraftingPlanContext(planService);
          when(
            () => planService.executeTool(
              agentId: agentId,
              threadId: threadId,
              runKey: runKey,
              toolName: DayAgentToolNames.draftDayPlan,
              args: any(named: 'args'),
            ),
          ).thenAnswer(
            (_) async => DayAgentDirectToolResult.success(
              const {'planId': 'day_agent_plan:dayplan-2026-05-25'},
            ),
          );
          conversationRepository
            ..toolCallsByInvocation = [
              const <ChatCompletionMessageToolCall>[],
              [
                _toolCall(
                  id: 'draft-call',
                  name: DayAgentToolNames.draftDayPlan,
                  args: {
                    'dayId': dayId,
                    'blocks': <Object?>[],
                  },
                ),
              ],
            ]
            ..usageByInvocation = const [
              InferenceUsage(inputTokens: 10, outputTokens: 5),
              InferenceUsage(inputTokens: 3, outputTokens: 2),
            ];

          final result = await execute(
            workflow(planService: planService),
            triggerTokens: {
              dayAgentDraftingToken(dayId),
              dayAgentPlanningDayToken(dayId),
            },
          );

          expect(result.success, isTrue);
          expect(conversationRepository.sendMessageCalls, hasLength(2));
          expect(
            conversationRepository.sendMessageCalls.first.toolChoice,
            isNull,
          );

          final retryCall = conversationRepository.sendMessageCalls[1];
          expect(
            retryCall.message,
            contains('You did not call `draft_day_plan`'),
          );
          expect(
            retryCall.tools.map((tool) => tool.function.name),
            [DayAgentToolNames.draftDayPlan],
          );
          retryCall.toolChoice!.map(
            mode: (_) => fail('Expected named tool choice, got mode.'),
            tool: (named) {
              expect(named.value.function.name, DayAgentToolNames.draftDayPlan);
            },
          );
          verify(
            () => planService.executeTool(
              agentId: agentId,
              threadId: threadId,
              runKey: runKey,
              toolName: DayAgentToolNames.draftDayPlan,
              args: any(named: 'args'),
            ),
          ).called(1);

          final usage = upsertedEntities
              .whereType<WakeTokenUsageEntity>()
              .single;
          expect(usage.inputTokens, 13);
          expect(usage.outputTokens, 7);
        },
      );

      test(
        'adopts the forced-retry usage when the first call returns none',
        () async {
          // Covers the null-left branch of the usage merge: when the initial
          // sendMessage reports no usage, the forced draft_day_plan retry's
          // usage is adopted verbatim (no merge against a null left operand).
          final planService = MockDayAgentPlanService();
          stubDraftingPlanContext(planService);
          when(
            () => planService.executeTool(
              agentId: agentId,
              threadId: threadId,
              runKey: runKey,
              toolName: DayAgentToolNames.draftDayPlan,
              args: any(named: 'args'),
            ),
          ).thenAnswer(
            (_) async => DayAgentDirectToolResult.success(
              const {'planId': 'day_agent_plan:dayplan-2026-05-25'},
            ),
          );
          conversationRepository
            ..toolCallsByInvocation = [
              const <ChatCompletionMessageToolCall>[],
              [
                _toolCall(
                  id: 'draft-call',
                  name: DayAgentToolNames.draftDayPlan,
                  args: {
                    'dayId': dayId,
                    'blocks': <Object?>[],
                  },
                ),
              ],
            ]
            ..usageByInvocation = const [
              null,
              InferenceUsage(inputTokens: 3, outputTokens: 2),
            ];

          final result = await execute(
            workflow(planService: planService),
            triggerTokens: {dayAgentDraftingToken(dayId), dayId},
          );

          expect(result.success, isTrue);
          expect(conversationRepository.sendMessageCalls, hasLength(2));
          final usage = upsertedEntities
              .whereType<WakeTokenUsageEntity>()
              .single;
          expect(usage.inputTokens, 3);
          expect(usage.outputTokens, 2);
        },
      );

      test(
        'does not force draft_day_plan on reconcile-only capture wakes',
        () async {
          final planService = MockDayAgentPlanService();
          conversationRepository.toolCallsByInvocation = [
            const <ChatCompletionMessageToolCall>[],
          ];

          final result = await execute(
            workflow(planService: planService),
            triggerTokens: {
              dayAgentCaptureSubmittedToken('capture-1'),
              dayAgentPlanningDayToken(dayId),
            },
          );

          expect(result.success, isTrue);
          expect(conversationRepository.sendMessageCalls, hasLength(1));
          expect(
            conversationRepository.sendMessageCalls.single.toolChoice,
            isNull,
          );
          verifyNever(
            () => planService.draftPlanForDay(
              agentId: any(named: 'agentId'),
              dayId: any(named: 'dayId'),
            ),
          );
        },
      );

      test(
        'fails the wake when the forced draft_day_plan call is rejected',
        () async {
          final planService = MockDayAgentPlanService();
          stubDraftingPlanContext(planService);
          when(
            () => planService.executeTool(
              agentId: agentId,
              threadId: threadId,
              runKey: runKey,
              toolName: DayAgentToolNames.draftDayPlan,
              args: any(named: 'args'),
            ),
          ).thenAnswer(
            (_) async => DayAgentDirectToolResult.failure(
              'draft_day_plan requires at least one block',
            ),
          );
          conversationRepository.toolCallsByInvocation = [
            const <ChatCompletionMessageToolCall>[],
            [
              _toolCall(
                id: 'draft-call',
                name: DayAgentToolNames.draftDayPlan,
                args: {
                  'dayId': dayId,
                  'blocks': <Object?>[],
                },
              ),
            ],
          ];

          final result = await execute(
            workflow(planService: planService),
            triggerTokens: {
              dayAgentDraftingToken(dayId),
              dayAgentPlanningDayToken(dayId),
            },
          );

          expect(result.success, isFalse);
          expect(result.error, contains('draft_day_plan'));
          verify(
            () => planService.executeTool(
              agentId: agentId,
              threadId: threadId,
              runKey: runKey,
              toolName: DayAgentToolNames.draftDayPlan,
              args: any(named: 'args'),
            ),
          ).called(1);
        },
      );

      test(
        'fails the wake when the forced retry still omits draft_day_plan',
        () async {
          final planService = MockDayAgentPlanService();
          stubDraftingPlanContext(planService);
          conversationRepository.toolCallsByInvocation = [
            const <ChatCompletionMessageToolCall>[],
            const <ChatCompletionMessageToolCall>[],
          ];

          final result = await execute(
            workflow(planService: planService),
            triggerTokens: {
              dayAgentDraftingToken(dayId),
              dayAgentPlanningDayToken(dayId),
            },
          );

          expect(result.success, isFalse);
          expect(result.error, contains('draft_day_plan'));
          expect(conversationRepository.sendMessageCalls, hasLength(2));
          expect(
            conversationRepository.sendMessageCalls[1].toolChoice,
            isNotNull,
          );
          final failureState = upsertedEntities
              .whereType<AgentStateEntity>()
              .last;
          expect(failureState.consecutiveFailureCount, 1);
          verifyNever(
            () => planService.executeTool(
              agentId: any(named: 'agentId'),
              threadId: any(named: 'threadId'),
              runKey: any(named: 'runKey'),
              toolName: DayAgentToolNames.draftDayPlan,
              args: any(named: 'args'),
            ),
          );
        },
      );
    });

    test(
      'surfaces the baseline plan for refine-token wakes',
      () async {
        final planService = MockDayAgentPlanService();
        final baselinePlan =
            AgentDomainEntity.dayPlan(
                  id: 'day_agent_plan:$dayId',
                  agentId: agentId,
                  dayId: dayId,
                  planDate: DateTime(2026, 5, 25),
                  data: DayPlanData(
                    planDate: DateTime(2026, 5, 25),
                    status: const DayPlanStatus.draft(),
                    plannedBlocks: [
                      PlannedBlock(
                        id: 'block-1',
                        categoryId: 'work',
                        startTime: DateTime(2026, 5, 25, 9),
                        endTime: DateTime(2026, 5, 25, 10),
                        title: 'Prep demo',
                        reason: 'Morning focus.',
                      ),
                    ],
                  ),
                  capacityMinutes: 360,
                  scheduledMinutes: 60,
                  createdAt: DateTime(2026, 5, 25, 8),
                  updatedAt: DateTime(2026, 5, 25, 8),
                  vectorClock: null,
                )
                as DayPlanEntity;
        when(
          () => planService.draftPlanForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer((_) async => baselinePlan);

        final result = await execute(
          workflow(planService: planService),
          triggerTokens: {
            dayAgentRefineToken(dayId),
            dayAgentPlanningDayToken(dayId),
          },
        );

        expect(result.success, isTrue);
        final refinePayload =
            sentPrompt().json('refine')! as Map<String, dynamic>;
        expect(refinePayload['requested'], isTrue);
        final plan = refinePayload['baselinePlan'] as Map<String, dynamic>;
        expect(plan['planId'], 'day_agent_plan:$dayId');
        final blocks = plan['blocks'] as List<dynamic>;
        expect(
          (blocks.single as Map<String, dynamic>)['id'],
          'block-1',
        );
        // hydrateDecidedTasks must NOT be called on a refine wake.
        verifyNever(
          () => planService.hydrateDecidedTasks(
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            explicitTaskIds: any(named: 'explicitTaskIds'),
            parsedItems: any(named: 'parsedItems'),
          ),
        );
      },
    );

    test(
      'refine context carries a null baselinePlan when no draft exists',
      () async {
        final planService = MockDayAgentPlanService();
        when(
          () => planService.draftPlanForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer((_) async => null);

        final result = await execute(
          workflow(planService: planService),
          triggerTokens: {
            dayAgentRefineToken(dayId),
            dayAgentPlanningDayToken(dayId),
          },
        );

        expect(result.success, isTrue);
        final refinePayload =
            sentPrompt().json('refine')! as Map<String, dynamic>;
        expect(refinePayload['requested'], isTrue);
        expect(refinePayload['baselinePlan'], isNull);
      },
    );

    test(
      'omits the refine context when no refine token is present',
      () async {
        final planService = MockDayAgentPlanService();

        final result = await execute(
          workflow(planService: planService),
          triggerTokens: {dayAgentPlanningDayToken(dayId)},
        );

        expect(result.success, isTrue);
        expect(sentPrompt().has('refine'), isFalse);
      },
    );

    test('delegates capture tools to the configured capture service', () async {
      final captureService = MockDayAgentCaptureService();
      when(
        () => captureService.executeTool(
          agentId: agentId,
          threadId: threadId,
          runKey: runKey,
          toolName: DayAgentToolNames.matchToCorpus,
          args: any(named: 'args'),
        ),
      ).thenAnswer(
        (_) async => DayAgentDirectToolResult.success(
          const {'candidates': <Object?>[]},
        ),
      );
      conversationRepository.toolCalls = [
        _toolCall(
          name: DayAgentToolNames.matchToCorpus,
          args: {'phrase': 'prep demo'},
        ),
      ];

      final result = await execute(workflow(captureService: captureService));

      expect(result.success, isTrue);
      expect(conversationRepository.toolResponses.single, contains('[]'));
      final args =
          verify(
                () => captureService.executeTool(
                  agentId: agentId,
                  threadId: threadId,
                  runKey: runKey,
                  toolName: DayAgentToolNames.matchToCorpus,
                  args: captureAny(named: 'args'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(args, {'phrase': 'prep demo'});
    });

    test(
      'returns a tool error when capture tools are not configured',
      () async {
        conversationRepository.toolCalls = [
          _toolCall(
            name: DayAgentToolNames.matchToCorpus,
            args: {'phrase': 'prep demo'},
          ),
        ];

        final result = await execute(workflow());

        expect(result.success, isTrue);
        expect(
          conversationRepository.toolResponses.single,
          contains('capture/reconcile tools are not configured'),
        );
      },
    );

    test('delegates plan tools to the configured plan service', () async {
      final planService = MockDayAgentPlanService();
      when(
        () => planService.executeTool(
          agentId: agentId,
          threadId: threadId,
          runKey: runKey,
          toolName: DayAgentToolNames.draftDayPlan,
          args: any(named: 'args'),
        ),
      ).thenAnswer(
        (_) async => DayAgentDirectToolResult.success(
          const {'planId': 'day_agent_plan:dayplan-2026-05-25'},
        ),
      );
      conversationRepository.toolCalls = [
        _toolCall(
          name: DayAgentToolNames.draftDayPlan,
          args: {
            'dayId': dayId,
            'blocks': <Object?>[],
          },
        ),
      ];

      final result = await execute(workflow(planService: planService));

      expect(result.success, isTrue);
      expect(
        conversationRepository.toolResponses.single,
        contains('day_agent_plan:dayplan-2026-05-25'),
      );
      final args =
          verify(
                () => planService.executeTool(
                  agentId: agentId,
                  threadId: threadId,
                  runKey: runKey,
                  toolName: DayAgentToolNames.draftDayPlan,
                  args: captureAny(named: 'args'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(args, {
        'dayId': dayId,
        'blocks': <Object?>[],
      });
    });

    test('rejects a tool call targeting a different day workspace', () async {
      // ADR 0022 Decision 4: under one planner the model must never mutate a
      // day other than the wake's workspace.
      final planService = MockDayAgentPlanService();
      conversationRepository.toolCalls = [
        _toolCall(
          name: DayAgentToolNames.draftDayPlan,
          args: const {
            'dayId': 'dayplan-2026-05-26',
            'blocks': <Object?>[],
          },
        ),
      ];

      final result = await execute(workflow(planService: planService));

      expect(result.success, isTrue);
      expect(
        conversationRepository.toolResponses.single,
        contains('does not match the wake workspace'),
      );
      // The mismatched call is rejected before reaching the plan service.
      verifyNever(
        () => planService.executeTool(
          agentId: any(named: 'agentId'),
          threadId: any(named: 'threadId'),
          runKey: any(named: 'runKey'),
          toolName: any(named: 'toolName'),
          args: any(named: 'args'),
        ),
      );
    });

    test(
      'injects the durable-knowledge hook index + scoped statements',
      () async {
        final knowledgeService = MockDayAgentKnowledgeService();
        final globalEntry =
            AgentDomainEntity.plannerKnowledge(
                  id: 'k-global',
                  agentId: agentId,
                  key: 'deep-work',
                  hook: 'no deep work before 10',
                  statementText: 'Never schedule deep work before 10:00.',
                  source: KnowledgeSource.userStated,
                  status: KnowledgeStatus.confirmed,
                  createdAt: DateTime(2026, 5, 20),
                  updatedAt: DateTime(2026, 5, 20),
                  vectorClock: null,
                )
                as PlannerKnowledgeEntity;
        when(
          () => knowledgeService.activeFor(agentId),
        ).thenAnswer((_) async => [globalEntry]);

        final result = await execute(
          workflow(knowledgeService: knowledgeService),
        );

        expect(result.success, isTrue);
        final sent = sentPrompt();
        // Hook index always present; the global statement is pulled in.
        expect(
          sent.section('knowledge_index'),
          contains('[deep-work] no deep work before 10 (scope: global)'),
        );
        expect(
          sent.section('knowledge_statements'),
          contains('Never schedule deep work before 10:00.'),
        );
        // Prefix-cache stability: the always-on index leads the prefix, the
        // per-wake scope-filtered statements trail it, and the wall-clock is
        // the last (most volatile) section.
        expect(
          sent.indexOf('knowledge_index'),
          lessThan(sent.indexOf('knowledge_statements')),
        );
        expect(
          sent.indexOf('knowledge_statements'),
          lessThan(sent.indexOf('current_local_time')),
        );
        expect(sent.tagsInOrder.last, 'current_local_time');
      },
    );

    test('omits knowledge blocks when there is no active knowledge', () async {
      final knowledgeService = MockDayAgentKnowledgeService();
      when(
        () => knowledgeService.activeFor(agentId),
      ).thenAnswer((_) async => []);

      final result = await execute(
        workflow(knowledgeService: knowledgeService),
      );

      expect(result.success, isTrue);
      final sent = sentPrompt();
      expect(sent.has('knowledge_index'), isFalse);
      expect(sent.has('knowledge_statements'), isFalse);
    });

    test(
      'durable knowledge is injected once via knowledgeStatements — never '
      'folded into the day log (ADR 0022 compaction exemption)',
      () async {
        final knowledgeService = MockDayAgentKnowledgeService();
        const statement = 'Never schedule deep work before 10:00.';
        when(() => knowledgeService.activeFor(agentId)).thenAnswer(
          (_) async => [
            AgentDomainEntity.plannerKnowledge(
                  id: 'k1',
                  agentId: agentId,
                  key: 'deep-work',
                  hook: 'no deep work before 10',
                  statementText: statement,
                  source: KnowledgeSource.userStated,
                  status: KnowledgeStatus.confirmed,
                  createdAt: DateTime(2026, 5, 20),
                  updatedAt: DateTime(2026, 5, 20),
                  vectorClock: null,
                )
                as PlannerKnowledgeEntity,
          ],
        );

        final result = await execute(
          workflow(knowledgeService: knowledgeService),
        );

        expect(result.success, isTrue);
        // Exactly one occurrence: the knowledge is a domain entity surfaced
        // only via knowledgeStatements, never pulled into the compaction fold.
        final raw = conversationRepository.lastUserMessage!;
        expect(statement.allMatches(raw).length, 1);
      },
    );

    test(
      'a category-scoped statement is withheld when the wake touches no '
      'matching category',
      () async {
        final knowledgeService = MockDayAgentKnowledgeService();
        when(() => knowledgeService.activeFor(agentId)).thenAnswer(
          (_) async => [
            AgentDomainEntity.plannerKnowledge(
                  id: 'k-fitness',
                  agentId: agentId,
                  key: 'gym',
                  hook: 'protect gym blocks',
                  statementText: 'Protect gym 3x/week.',
                  source: KnowledgeSource.userStated,
                  status: KnowledgeStatus.confirmed,
                  createdAt: DateTime(2026, 5, 20),
                  updatedAt: DateTime(2026, 5, 20),
                  vectorClock: null,
                  scope: 'category:fitness',
                )
                as PlannerKnowledgeEntity,
          ],
        );

        final result = await execute(
          workflow(knowledgeService: knowledgeService),
        );

        expect(result.success, isTrue);
        final sent = sentPrompt();
        // Hook index always lists the key (discovery)...
        expect(sent.section('knowledge_index'), contains('[gym]'));
        // ...but the full statement is withheld since this wake touches no
        // fitness category.
        expect(sent.has('knowledge_statements'), isFalse);
      },
    );

    test(
      'scope-filtered statements trail the dayLog so a changing statement set '
      'cannot evict the large dayLog prefix (C1)',
      () async {
        // A wake with BOTH durable knowledge and a compacted dayLog: the
        // always-on index must lead the prefix, the dayLog sits in the stable
        // middle, and the per-wake scope-filtered statements trail it.
        when(() => syncService.repository).thenReturn(repository);
        when(
          () => repository.getMessagesByKind(agentId, AgentMessageKind.system),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getMessagesByKind(agentId, AgentMessageKind.summary),
        ).thenAnswer((_) async => []);
        when(
          () => repository.getLinksFrom(agentId),
        ).thenAnswer((_) async => []);
        final capture =
            AgentDomainEntity.capture(
                  id: 'cap-x',
                  agentId: agentId,
                  transcript: 'a folded capture transcript',
                  capturedAt: DateTime.utc(2026, 5, 25, 7),
                  createdAt: DateTime.utc(2026, 5, 25, 7, 1),
                  vectorClock: null,
                )
                as CaptureEntity;
        when(() => repository.getCaptureEventMetaByAgentId(agentId)).thenAnswer(
          (_) async => [
            (
              id: capture.id,
              createdAt: capture.createdAt,
              capturedAt: capture.capturedAt,
            ),
          ],
        );
        when(
          () => repository.getEntity('cap-x'),
        ).thenAnswer((_) async => capture);

        final knowledgeService = MockDayAgentKnowledgeService();
        when(() => knowledgeService.activeFor(agentId)).thenAnswer(
          (_) async => [
            AgentDomainEntity.plannerKnowledge(
                  id: 'k-global',
                  agentId: agentId,
                  key: 'deep-work',
                  hook: 'no deep work before 10',
                  statementText: 'Never schedule deep work before 10:00.',
                  source: KnowledgeSource.userStated,
                  status: KnowledgeStatus.confirmed,
                  createdAt: DateTime(2026, 5, 20),
                  updatedAt: DateTime(2026, 5, 20),
                  vectorClock: null,
                )
                as PlannerKnowledgeEntity,
          ],
        );
        when(
          () => repository.getAttentionPlanningInputsForWindow(
            start: any(named: 'start'),
            end: any(named: 'end'),
          ),
        ).thenAnswer(
          (_) async => AttentionPlanningInputs(
            claims: [
              AgentDomainEntity.attentionRequest(
                    id: 'attn-c1',
                    agentId: 'task-agent',
                    kind: AttentionRequestKind.task,
                    title: 'Focus block',
                    categoryId: 'work',
                    requestedMinutes: 45,
                    impact: 3,
                    urgency: 3,
                    energyFit: AttentionEnergyFit.high,
                    evidenceRefs: const [],
                    createdAt: DateTime(2026, 5, 24),
                    vectorClock: null,
                  )
                  as AttentionRequestEntity,
            ],
            standingAgreements: const [],
          ),
        );

        final result = await execute(
          workflow(knowledgeService: knowledgeService),
        );

        expect(result.success, isTrue);
        final sent = sentPrompt();
        // The C1 invariant: index → day_log → statements — and the volatile
        // attention claims must never drift ahead of the (much larger,
        // byte-stable) day log.
        expect(sent.has('knowledge_index'), isTrue);
        expect(sent.has('day_log'), isTrue);
        expect(
          sent.indexOf('knowledge_index'),
          lessThan(sent.indexOf('day_log')),
        );
        expect(
          sent.indexOf('day_log'),
          lessThan(sent.indexOf('attention_planning')),
        );
        expect(
          sent.indexOf('attention_planning'),
          lessThan(sent.indexOf('knowledge_statements')),
        );
        expectCanonicalSectionOrder(sent);
      },
    );

    test('returns a tool error when plan tools are not configured', () async {
      conversationRepository.toolCalls = [
        _toolCall(
          name: DayAgentToolNames.draftDayPlan,
          args: {
            'dayId': dayId,
            'blocks': <Object?>[],
          },
        ),
      ];

      final result = await execute(workflow());

      expect(result.success, isTrue);
      expect(
        conversationRepository.toolResponses.single,
        contains('day-plan tools are not configured'),
      );
    });

    test('persists no observation entities when none were recorded', () async {
      // A wake where the model calls no record_observations leaves
      // strategy.extractObservations() empty; _persistObservations must then
      // write nothing while the wake still completes successfully.
      conversationRepository.finalResponse = 'Nothing notable this wake.';

      final result = await execute(workflow());

      expect(result.success, isTrue);
      final observationEntities = upsertedEntities
          .whereType<AgentMessageEntity>()
          .where((m) => m.kind == AgentMessageKind.observation);
      expect(observationEntities, isEmpty);
      // The wake still reached completion (the thought payload is persisted).
      expect(
        upsertedEntities.whereType<AgentMessagePayloadEntity>().map(
          (p) => p.content['text'],
        ),
        contains('Nothing notable this wake.'),
      );
    });

    test('persists no thought when the model returns no final text', () async {
      // The harness defaults finalResponse to null, so the conversation ends
      // with no assistant text. recordFinalResponse(null) leaves the strategy
      // finalResponse null and _persistThought writes nothing — yet the wake
      // still completes successfully.
      expect(conversationRepository.finalResponse, isNull);

      final result = await execute(workflow());

      expect(result.success, isTrue);
      final thoughtMessages = upsertedEntities
          .whereType<AgentMessageEntity>()
          .where((m) => m.kind == AgentMessageKind.thought);
      expect(thoughtMessages, isEmpty);
      // The wake still event-sources its completion.
      expect(
        upsertedEntities.whereType<AgentStateEntity>().last.lastWakeAt,
        now,
      );
    });

    test(
      'includes the newest 20 observations in chronological order',
      () async {
        final payloadsById = <String, AgentMessagePayloadEntity>{};
        final observations = <AgentMessageEntity>[
          for (var index = 0; index < 25; index++)
            AgentDomainEntity.agentMessage(
                  id: 'observation-$index',
                  agentId: agentId,
                  threadId: 'observation-thread',
                  kind: AgentMessageKind.observation,
                  createdAt: now.subtract(Duration(minutes: 25 - index)),
                  vectorClock: null,
                  contentEntryId: 'payload-$index',
                  metadata: AgentMessageMetadata(
                    runKey: 'observation-run-$index',
                  ),
                )
                as AgentMessageEntity,
        ];
        for (var index = 0; index < observations.length; index++) {
          payloadsById['payload-$index'] =
              AgentDomainEntity.agentMessagePayload(
                    id: 'payload-$index',
                    agentId: agentId,
                    createdAt: observations[index].createdAt,
                    vectorClock: null,
                    content: {'text': 'Observation $index'},
                  )
                  as AgentMessagePayloadEntity;
        }
        when(
          () => repository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => observations);
        when(() => repository.getEntitiesByIds(any())).thenAnswer(
          (invocation) async {
            final ids =
                invocation.positionalArguments.single as Iterable<String>;
            final payloads = <String, AgentDomainEntity>{};
            for (final id in ids) {
              final payload = payloadsById[id];
              if (payload != null) {
                payloads[id] = payload;
              }
            }
            return payloads;
          },
        );

        final result = await execute(workflow());

        expect(result.success, isTrue);
        final recentObservations =
            sentPrompt().json('recent_observations')! as List<dynamic>;
        expect(recentObservations, hasLength(20));
        expect(
          recentObservations.first,
          {
            'createdAt': '2026-05-25T07:40:00.000',
            'text': 'Observation 5',
          },
        );
        expect(
          recentObservations.last,
          {
            'createdAt': '2026-05-25T07:59:00.000',
            'text': 'Observation 24',
          },
        );
        expect(
          recentObservations,
          isNot(
            contains(
              containsPair('text', 'Observation 4'),
            ),
          ),
        );
      },
    );

    test('sorts observations with the same timestamp by stable id', () async {
      final createdAt = now.subtract(const Duration(minutes: 30));
      final payloadA =
          AgentDomainEntity.agentMessagePayload(
                id: 'payload-a',
                agentId: agentId,
                createdAt: createdAt,
                vectorClock: null,
                content: const {'text': 'A observation'},
              )
              as AgentMessagePayloadEntity;
      final payloadB =
          AgentDomainEntity.agentMessagePayload(
                id: 'payload-b',
                agentId: agentId,
                createdAt: createdAt,
                vectorClock: null,
                content: const {'text': 'B observation'},
              )
              as AgentMessagePayloadEntity;
      final observationB =
          AgentDomainEntity.agentMessage(
                id: 'observation-b',
                agentId: agentId,
                threadId: 'observation-thread',
                kind: AgentMessageKind.observation,
                createdAt: createdAt,
                vectorClock: null,
                contentEntryId: payloadB.id,
                metadata: const AgentMessageMetadata(runKey: 'old-run'),
              )
              as AgentMessageEntity;
      final observationA =
          AgentDomainEntity.agentMessage(
                id: 'observation-a',
                agentId: agentId,
                threadId: 'observation-thread',
                kind: AgentMessageKind.observation,
                createdAt: createdAt,
                vectorClock: null,
                contentEntryId: payloadA.id,
                metadata: const AgentMessageMetadata(runKey: 'old-run'),
              )
              as AgentMessageEntity;
      when(
        () => repository.getMessagesByKind(
          agentId,
          AgentMessageKind.observation,
        ),
      ).thenAnswer((_) async => [observationB, observationA]);
      when(
        () => repository.getEntitiesByIds({payloadA.id, payloadB.id}),
      ).thenAnswer(
        (_) async => {
          payloadA.id: payloadA,
          payloadB.id: payloadB,
        },
      );

      final result = await execute(workflow());

      expect(result.success, isTrue);
      final recentObservations =
          sentPrompt().json('recent_observations')! as List<dynamic>;
      expect(
        recentObservations.map(
          (observation) => (observation as Map<String, dynamic>)['text'],
        ),
        ['A observation', 'B observation'],
      );
    });

    test('clears consumed scheduled wakes after a successful wake', () async {
      currentState = state(
        scheduledWakeAt: now.subtract(const Duration(minutes: 1)),
      );

      final result = await execute(workflow());

      expect(result.success, isTrue);
      final finalState = upsertedEntities.whereType<AgentStateEntity>().last;
      expect(finalState.lastWakeAt, now);
      expect(finalState.scheduledWakeAt, isNull);
    });

    test('preserves future scheduled wakes after a successful wake', () async {
      final futureWakeAt = now.add(const Duration(hours: 1));
      currentState = state(scheduledWakeAt: futureWakeAt);

      final result = await execute(workflow());

      expect(result.success, isTrue);
      final finalState = upsertedEntities.whereType<AgentStateEntity>().last;
      expect(finalState.scheduledWakeAt, futureWakeAt);
    });

    test('clears a scheduled wake landing exactly on now', () async {
      // The remaining-wake gate keeps a wake only when it is STRICTLY after
      // now (`isAfter`), so a wake whose time equals the wake instant is
      // treated as already due and cleared — the boundary between the
      // past-clears and future-preserves cases above.
      currentState = state(scheduledWakeAt: now);

      final result = await execute(workflow());

      expect(result.success, isTrue);
      final finalState = upsertedEntities.whereType<AgentStateEntity>().last;
      expect(finalState.scheduledWakeAt, isNull);
    });

    test('continues when user message persistence fails', () async {
      // Match on the entity being written (the `user`-kind message) rather
      // than a positional write count, so the test keeps targeting the
      // user-message write even if the wake gains an earlier write.
      var threwForUserMessage = false;
      when(() => syncService.upsertEntity(any())).thenAnswer((
        invocation,
      ) async {
        final entity =
            invocation.positionalArguments.single as AgentDomainEntity;
        if (entity is AgentMessageEntity &&
            entity.kind == AgentMessageKind.user) {
          threwForUserMessage = true;
          throw StateError('user message write failed');
        }
        upsertedEntities.add(entity);
        if (entity is AgentStateEntity) {
          currentState = entity;
        }
      });

      final result = await execute(workflow());

      expect(result.success, isTrue);
      // The failure was actually injected on the user-message write.
      expect(threwForUserMessage, isTrue);
      verify(
        () => domainLogger.error(
          any(),
          any(),
          message: 'failed to persist day-agent user message',
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
      expect(
        upsertedEntities.whereType<AgentStateEntity>().last.lastWakeAt,
        now,
      );
    });

    for (final scenario in const [
      _ToolValidationScenario(
        name: 'rejects missing at',
        args: {'reason': 'Missing time.'},
        expectedResponse: 'ISO-8601 date-time string',
      ),
      _ToolValidationScenario(
        name: 'rejects unparsable at',
        args: {'at': 'not-a-date', 'reason': 'Bad parse.'},
        expectedResponse: 'parseable as an ISO-8601',
      ),
      _ToolValidationScenario(
        name: 'rejects empty reason',
        args: {'at': '2026-05-25T08:30:00', 'reason': '   '},
        expectedResponse: 'reason',
      ),
      _ToolValidationScenario(
        name: 'rejects short lead time',
        args: {'at': '2026-05-25T08:14:59', 'reason': 'Too soon.'},
        expectedResponse: 'at least 15 minutes',
      ),
    ]) {
      test(scenario.name, () async {
        conversationRepository.toolCalls = [
          _toolCall(name: DayAgentToolNames.setNextWake, args: scenario.args),
        ];

        final result = await execute(workflow());

        expect(result.success, isTrue);
        expect(
          conversationRepository.toolResponses.single,
          contains(scenario.expectedResponse),
        );
        // A rejected set_next_wake persists no scheduled-wake record.
        expect(upsertedEntities.whereType<ScheduledWakeEntity>(), isEmpty);
      });
    }

    test('rejects scheduled wakes after the daily cap is reached', () async {
      // Cap key is now (dayId, date)-scoped (ADR 0022 Decision 12).
      currentState = state(
        toolCounterByKey: {'day_agent_set_next_wake:$dayId:2026-05-25': 4},
      );
      conversationRepository.toolCalls = [
        _toolCall(
          name: DayAgentToolNames.setNextWake,
          args: const {
            'at': '2026-05-25T08:30:00',
            'reason': 'Past the cap.',
          },
        ),
      ];

      final result = await execute(workflow());

      expect(result.success, isTrue);
      expect(
        conversationRepository.toolResponses.single,
        contains('daily scheduled-wake cap reached'),
      );
      // The cap blocks both the record and any state mutation for the wake.
      expect(upsertedEntities.whereType<ScheduledWakeEntity>(), isEmpty);
    });

    test(
      'returns a tool error when state disappears during scheduling',
      () async {
        var stateReadCount = 0;
        when(() => repository.getAgentState(agentId)).thenAnswer((_) async {
          stateReadCount++;
          if (stateReadCount == 2) return null;
          return currentState;
        });
        conversationRepository.toolCalls = [
          _toolCall(
            name: DayAgentToolNames.setNextWake,
            args: const {
              'at': '2026-05-25T08:30:00',
              'reason': 'State race.',
            },
          ),
        ];

        final result = await execute(workflow());

        expect(result.success, isTrue);
        expect(
          conversationRepository.toolResponses.single,
          contains('agent state not found'),
        );
        expect(
          upsertedEntities.whereType<AgentStateEntity>().any(
            (state) => state.scheduledWakeAt != null,
          ),
          isFalse,
        );
      },
    );

    test('bumps failure count when conversation execution throws', () async {
      currentState = state(
        consecutiveFailureCount: 2,
        scheduledWakeAt: now.subtract(const Duration(minutes: 1)),
      );
      conversationRepository.errorToThrow = Exception('model failed');

      final result = await execute(workflow());

      expect(result.success, isFalse);
      expect(result.error, contains('model failed'));
      final failureState = upsertedEntities.whereType<AgentStateEntity>().last;
      expect(failureState.consecutiveFailureCount, 3);
      expect(failureState.scheduledWakeAt, isNull);
      expect(conversationRepository.deletedConversationCount, 1);
      verify(
        () => domainLogger.error(
          any(),
          any(),
          message: 'day-agent wake failed',
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
    });

    test('logs when failure-count persistence also fails', () async {
      currentState = state(consecutiveFailureCount: 2);
      conversationRepository.errorToThrow = Exception('model failed');
      when(() => syncService.upsertEntity(any())).thenAnswer(
        (invocation) async {
          final entity =
              invocation.positionalArguments.single as AgentDomainEntity;
          if (entity is AgentStateEntity) {
            throw StateError('state update failed');
          }
          upsertedEntities.add(entity);
        },
      );

      final result = await execute(workflow());

      expect(result.success, isFalse);
      expect(result.error, contains('model failed'));
      verify(
        () => domainLogger.error(
          any(),
          any(),
          message: 'day-agent wake failed',
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
      verify(
        () => domainLogger.error(
          any(),
          any(),
          message: 'failed to update day-agent failure count',
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
    });

    test(
      'rejects an unparsable day id from the wake token',
      () async {
        // A planning_day token whose id is not a parseable dayplan must be
        // rejected before any conversation starts.
        final result = await execute(
          workflow(),
          triggerTokens: {dayAgentPlanningDayToken('not-a-day-plan')},
        );

        expect(result.success, isFalse);
        expect(result.error, contains('Invalid active day ID'));
        expect(conversationRepository.createdConversationCount, 0);
      },
    );

    group('week context', () {
      MockDayAgentWeekContextService weekContextStub({WeekContext? context}) {
        final service = MockDayAgentWeekContextService();
        when(
          () => service.buildForDay(
            agentId: any(named: 'agentId'),
            planDate: any(named: 'planDate'),
            now: any(named: 'now'),
          ),
        ).thenAnswer((_) async => context);
        return service;
      }

      const sampleContext = WeekContext(
        recentDays:
            'Sun Jun 7 — no plan. Work: 9h recorded. '
            'Total recorded: 9h.',
        weekAhead: 'Fri Jun 12 — draft plan: Work 4h.',
      );

      test(
        'renders recent_days + week_ahead after knowledge statements and '
        'before the mode section',
        () async {
          final knowledgeService = MockDayAgentKnowledgeService();
          when(() => knowledgeService.activeFor(agentId)).thenAnswer(
            (_) async => [
              AgentDomainEntity.plannerKnowledge(
                    id: 'k-global',
                    agentId: agentId,
                    key: 'deep-work',
                    hook: 'no deep work before 10',
                    statementText: 'Never schedule deep work before 10:00.',
                    source: KnowledgeSource.userStated,
                    status: KnowledgeStatus.confirmed,
                    createdAt: DateTime(2026, 5, 20),
                    updatedAt: DateTime(2026, 5, 20),
                    vectorClock: null,
                  )
                  as PlannerKnowledgeEntity,
            ],
          );
          final planService = MockDayAgentPlanService();
          stubDraftingPlanContext(planService);
          stubSuccessfulDraftToolCall(planService);
          when(
            () => repository.getAttentionPlanningInputsForWindow(
              start: any(named: 'start'),
              end: any(named: 'end'),
            ),
          ).thenAnswer(
            (_) async => AttentionPlanningInputs(
              claims: [
                AgentDomainEntity.attentionRequest(
                      id: 'attn-1',
                      agentId: 'task-agent',
                      kind: AttentionRequestKind.task,
                      title: 'Focus block',
                      categoryId: 'work',
                      requestedMinutes: 45,
                      impact: 3,
                      urgency: 3,
                      energyFit: AttentionEnergyFit.high,
                      evidenceRefs: const [],
                      createdAt: DateTime(2026, 5, 24),
                      vectorClock: null,
                    )
                    as AttentionRequestEntity,
              ],
              standingAgreements: const [],
            ),
          );

          final result = await execute(
            workflow(
              knowledgeService: knowledgeService,
              planService: planService,
              weekContextService: weekContextStub(context: sampleContext),
            ),
            triggerTokens: {
              dayAgentDraftingToken(dayId),
              dayAgentPlanningDayToken(dayId),
            },
          );

          expect(result.success, isTrue);
          final sent = sentPrompt();
          expect(sent.section('recent_days'), sampleContext.recentDays);
          expect(sent.section('week_ahead'), sampleContext.weekAhead);
          // Volatility ordering (the plan-mandated chain): day-stable
          // attention claims, then per-wake knowledge statements, then the
          // week context (its today-so-far line churns with tracked time),
          // then the per-wake mode section.
          expect(
            sent.indexOf('attention_planning'),
            lessThan(sent.indexOf('knowledge_statements')),
          );
          expect(
            sent.indexOf('knowledge_statements'),
            lessThan(sent.indexOf('recent_days')),
          );
          expect(
            sent.indexOf('recent_days'),
            lessThan(sent.indexOf('week_ahead')),
          );
          expect(
            sent.indexOf('week_ahead'),
            lessThan(sent.indexOf('drafting')),
          );
          expectCanonicalSectionOrder(sent);
        },
      );

      test(
        'refine wakes carry week context before the refine section, in '
        'canonical order',
        () async {
          final planService = MockDayAgentPlanService();
          when(
            () => planService.draftPlanForDay(
              agentId: agentId,
              dayId: dayId,
            ),
          ).thenAnswer((_) async => null);

          final result = await execute(
            workflow(
              planService: planService,
              weekContextService: weekContextStub(context: sampleContext),
            ),
            triggerTokens: {
              dayAgentRefineToken(dayId),
              dayAgentPlanningDayToken(dayId),
            },
          );

          expect(result.success, isTrue);
          final sent = sentPrompt();
          expect(
            sent.indexOf('week_ahead'),
            lessThan(sent.indexOf('refine')),
          );
          expectCanonicalSectionOrder(sent);
        },
      );

      test('omits the sections when the service yields null', () async {
        final result = await execute(
          workflow(weekContextService: weekContextStub()),
        );

        expect(result.success, isTrue);
        final sent = sentPrompt();
        expect(sent.has('recent_days'), isFalse);
        expect(sent.has('week_ahead'), isFalse);
      });

      test('absorbs an unexpected service throw (sections absent, wake '
          'succeeds)', () async {
        final service = MockDayAgentWeekContextService();
        when(
          () => service.buildForDay(
            agentId: any(named: 'agentId'),
            planDate: any(named: 'planDate'),
            now: any(named: 'now'),
          ),
        ).thenThrow(StateError('service bug'));

        final result = await execute(
          workflow(weekContextService: service),
        );

        expect(result.success, isTrue);
        final sent = sentPrompt();
        expect(sent.has('recent_days'), isFalse);
        expect(sent.has('week_ahead'), isFalse);
      });

      test('omits each section independently', () async {
        const historyOnly = WeekContext(
          recentDays: 'Sun Jun 7 — no plan. Nothing recorded.',
          weekAhead: null,
        );
        final result = await execute(
          workflow(weekContextService: weekContextStub(context: historyOnly)),
        );

        expect(result.success, isTrue);
        final sent = sentPrompt();
        expect(sent.section('recent_days'), historyOnly.recentDays);
        expect(sent.has('week_ahead'), isFalse);
      });

      test('builds week context for the wake-resolved plan date', () async {
        final service = weekContextStub(context: sampleContext);

        await execute(workflow(weekContextService: service));

        verify(
          () => service.buildForDay(
            agentId: agentId,
            planDate: DateTime(2026, 5, 25),
            // The wake's own clock read is passed through so the section's
            // day classification matches current_local_time.
            now: now,
          ),
        ).called(1);
      });

      test(
        'capture-submitted wakes (day from capture fallback) skip the '
        'week-context build entirely',
        () async {
          currentState = state(activeDayId: '');
          final service = weekContextStub(context: sampleContext);
          final captureService = MockDayAgentCaptureService();
          stubCaptureContext(captureService);
          when(
            () => captureService.parsedItemsForCapture('capture-1'),
          ).thenAnswer((_) async => const []);
          when(
            () => captureService.executeTool(
              agentId: agentId,
              threadId: threadId,
              runKey: runKey,
              toolName: DayAgentToolNames.parseCaptureToItems,
              args: any(named: 'args'),
            ),
          ).thenAnswer(
            (_) async => DayAgentDirectToolResult.success(const {
              'captureId': 'capture-1',
              'items': [
                {'kind': 'newTask', 'title': 'x', 'categoryId': 'home'},
              ],
            }),
          );
          conversationRepository.toolCalls = [
            _toolCall(
              name: DayAgentToolNames.parseCaptureToItems,
              args: const {
                'captureId': 'capture-1',
                'items': [
                  {
                    'kind': 'newTask',
                    'title': 'x',
                    'categoryId': 'home',
                    'confidenceScore': 0.4,
                  },
                ],
              },
            ),
          ];

          final result = await execute(
            workflow(
              captureService: captureService,
              weekContextService: service,
            ),
            triggerTokens: {dayAgentCaptureSubmittedToken('capture-1')},
          );

          expect(result.success, isTrue);
          verifyNever(
            () => service.buildForDay(
              agentId: any(named: 'agentId'),
              planDate: any(named: 'planDate'),
              now: any(named: 'now'),
            ),
          );
          expect(sentPrompt().has('recent_days'), isFalse);
        },
      );

      test(
        'write_day_summary dispatches to the service, bypassing the blanket '
        'workspace-day guard (wall-clock window is the service contract)',
        () async {
          final service = weekContextStub(context: sampleContext);
          when(
            () => service.executeTool(
              agentId: agentId,
              toolName: DayAgentToolNames.writeDaySummary,
              args: any(named: 'args'),
            ),
          ).thenAnswer(
            (_) async => DayAgentDirectToolResult.success(const {
              'dayId': 'dayplan-2026-05-24',
              'updated': false,
            }),
          );
          // The summary targets YESTERDAY relative to the wake clock — a
          // different day than the wake workspace. The blanket guard would
          // reject it; the week-context branch must run first.
          conversationRepository.toolCalls = [
            _toolCall(
              name: DayAgentToolNames.writeDaySummary,
              args: const {
                'dayId': 'dayplan-2026-05-24',
                'text': 'Calm day; finished early.',
              },
            ),
          ];

          final result = await execute(
            workflow(weekContextService: service),
          );

          expect(result.success, isTrue);
          expect(
            conversationRepository.toolResponses.single,
            isNot(contains('does not match the wake workspace')),
          );
          expect(
            conversationRepository.toolResponses.single,
            contains('dayplan-2026-05-24'),
          );
          final captured =
              verify(
                    () => service.executeTool(
                      agentId: agentId,
                      toolName: DayAgentToolNames.writeDaySummary,
                      args: captureAny(named: 'args'),
                    ),
                  ).captured.single
                  as Map<String, dynamic>;
          expect(captured['text'], 'Calm day; finished early.');
        },
      );

      test(
        'other day-scoped tools still hit the blanket guard even with the '
        'week-context service configured',
        () async {
          final service = weekContextStub(context: sampleContext);
          final planService = MockDayAgentPlanService();
          conversationRepository.toolCalls = [
            _toolCall(
              name: DayAgentToolNames.draftDayPlan,
              args: const {
                'dayId': 'dayplan-2026-05-26',
                'blocks': <Object?>[],
              },
            ),
          ];

          final result = await execute(
            workflow(planService: planService, weekContextService: service),
          );

          expect(result.success, isTrue);
          expect(
            conversationRepository.toolResponses.single,
            contains('does not match the wake workspace'),
          );
        },
      );

      test(
        'write_day_summary returns a tool error when the service is not '
        'configured',
        () async {
          conversationRepository.toolCalls = [
            _toolCall(
              name: DayAgentToolNames.writeDaySummary,
              args: const {
                'dayId': 'dayplan-2026-05-25',
                'text': 'note',
              },
            ),
          ];

          final result = await execute(workflow());

          expect(result.success, isTrue);
          expect(
            conversationRepository.toolResponses.single,
            contains('week-context tools are not configured'),
          );
        },
      );

      test('offers the write_day_summary tool only when configured', () async {
        await execute(workflow(weekContextService: weekContextStub()));
        expect(
          conversationRepository.lastTools.map((t) => t.function.name),
          contains(DayAgentToolNames.writeDaySummary),
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('Week context'),
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('Sustainability beats'),
        );

        // The gated block keeps exactly one blank line on each seam.
        expect(
          conversationRepository.lastSystemMessage,
          contains('shut down a day.\n\nWeek context'),
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('contradiction.\n\nYour memory'),
        );

        await execute(workflow());
        expect(
          conversationRepository.lastTools.map((t) => t.function.name),
          isNot(contains(DayAgentToolNames.writeDaySummary)),
        );
        expect(
          conversationRepository.lastSystemMessage,
          isNot(contains('Week context')),
        );
        // No double blank line where the gated block collapsed to nothing.
        expect(
          conversationRepository.lastSystemMessage,
          contains('shut down a day.\n\nYour memory'),
        );
      });
    });

    test(
      'includes soul sections in the system prompt when one is assigned',
      () async {
        final soulService = MockSoulDocumentService();
        when(
          () => soulService.resolveActiveSoulForTemplate(templateId),
        ).thenAnswer(
          (_) async => makeTestSoulDocumentVersion(
            voiceDirective: 'Use the Shepherd voice.',
            toneBounds: 'Stay candid.',
            coachingStyle: 'Ask for one concrete next action.',
            antiSycophancyPolicy: 'Do not flatter.',
          ),
        );

        final result = await execute(
          workflow(soulDocumentService: soulService),
        );

        expect(result.success, isTrue);
        expect(
          conversationRepository.lastSystemMessage,
          contains('## Personality'),
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('Use the Shepherd voice.'),
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('## Tone Bounds'),
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('Stay candid.'),
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('## Coaching Style'),
        );
        expect(
          conversationRepository.lastSystemMessage,
          contains('## Anti-Sycophancy Policy'),
        );
      },
    );
  });
}

/// Pins the cache invariant the prompt-section vocabulary declares: the
/// payload's sections must appear exactly in the canonical stable→volatile
/// order of [DayAgentPromptTags.all]. Any reordering that would hurt the
/// prefix cache (e.g. a volatile section drifting ahead of `day_log`) fails
/// here by name.
void expectCanonicalSectionOrder(ParsedDayAgentPrompt sent) {
  expect(
    sent.tagsInOrder,
    DayAgentPromptTags.all.where(sent.has).toList(),
  );
}

ChatCompletionMessageToolCall _toolCall({
  required String name,
  required Map<String, dynamic> args,
  String id = 'call-1',
}) {
  return ChatCompletionMessageToolCall(
    id: id,
    type: ChatCompletionMessageToolCallType.function,
    function: ChatCompletionMessageFunctionCall(
      name: name,
      arguments: jsonEncode(args),
    ),
  );
}

class _ToolValidationScenario {
  const _ToolValidationScenario({
    required this.name,
    required this.args,
    required this.expectedResponse,
  });

  final String name;
  final Map<String, dynamic> args;
  final String expectedResponse;
}

class _ConversationHarness extends ConversationRepository {
  final Map<String, ConversationManager> _managers =
      <String, ConversationManager>{};
  int createdConversationCount = 0;
  int deletedConversationCount = 0;

  List<ChatCompletionMessageToolCall> toolCalls = const [];
  String? finalResponse;
  InferenceUsage? usage;
  Exception? errorToThrow;
  String? lastSystemMessage;
  String? lastUserMessage;
  List<ChatCompletionTool> lastTools = const [];
  final sendMessageCalls =
      <
        ({
          InferenceRepositoryInterface inferenceRepo,
          String message,
          String model,
          ChatCompletionToolChoiceOption? toolChoice,
          List<ChatCompletionTool> tools,
        })
      >[];
  List<List<ChatCompletionMessageToolCall>> toolCallsByInvocation = const [];
  List<InferenceUsage?> usageByInvocation = const [];
  final toolResponses = <String>[];

  @override
  String createConversation({
    String? systemMessage,
    int maxTurns = 20,
  }) {
    createdConversationCount++;
    lastSystemMessage = systemMessage;
    final id = 'conversation-$createdConversationCount';
    _managers[id] = ConversationManager(
      conversationId: id,
      maxTurns: maxTurns,
    )..initialize(systemMessage: systemMessage);
    return id;
  }

  @override
  ConversationManager? getConversation(String conversationId) {
    return _managers[conversationId];
  }

  @override
  Future<InferenceUsage?> sendMessage({
    required String conversationId,
    required String message,
    required String model,
    required AiConfigInferenceProvider provider,
    required InferenceRepositoryInterface inferenceRepo,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    double temperature = 0.7,
    ConversationStrategy? strategy,
  }) async {
    final thrown = errorToThrow;
    if (thrown != null) throw thrown;

    lastUserMessage = message;
    lastTools = tools ?? const [];
    sendMessageCalls.add(
      (
        inferenceRepo: inferenceRepo,
        message: message,
        model: model,
        toolChoice: toolChoice,
        tools: tools ?? const <ChatCompletionTool>[],
      ),
    );
    final invocationIndex = sendMessageCalls.length - 1;
    final manager = _managers[conversationId]!..addUserMessage(message);
    final selectedToolCalls = invocationIndex < toolCallsByInvocation.length
        ? toolCallsByInvocation[invocationIndex]
        : toolCalls;
    if (selectedToolCalls.isNotEmpty) {
      manager.addAssistantMessage(toolCalls: selectedToolCalls);
      await strategy!.processToolCalls(
        toolCalls: selectedToolCalls,
        manager: manager,
      );
      toolResponses
        ..clear()
        ..addAll(
          manager.messages
              .where(
                (message) => message.role == ChatCompletionMessageRole.tool,
              )
              .map((message) => message.content)
              .whereType<String>(),
        );
    }
    if (finalResponse != null) {
      manager.addAssistantMessage(content: finalResponse);
    }
    if (invocationIndex < usageByInvocation.length) {
      return usageByInvocation[invocationIndex];
    }
    return usage;
  }

  @override
  void deleteConversation(String conversationId) {
    deletedConversationCount++;
    _managers.remove(conversationId)?.dispose();
  }
}
