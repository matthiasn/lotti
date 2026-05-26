import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../agents/test_utils.dart';

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
        error: any(named: 'error'),
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
      domainLogger: domainLogger,
      onPersistedStateChanged: changedTokens.add,
    );
  }

  Future<WakeResult> execute(
    DayAgentWorkflow sut, {
    Set<String>? triggerTokens,
  }) {
    return withClock(
      Clock.fixed(now),
      () => sut.execute(
        agentIdentity: identity(),
        runKey: runKey,
        triggerTokens: triggerTokens ?? {'capture-1', dayId},
        threadId: threadId,
      ),
    );
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
  });

  group('DayAgentWorkflow', () {
    test(
      'records observations, schedules wake, and persists wake output',
      () async {
        final observationPayload =
            AgentDomainEntity.agentMessagePayload(
                  id: 'payload-old-observation',
                  agentId: agentId,
                  createdAt: now.subtract(const Duration(hours: 2)),
                  vectorClock: null,
                  content: const {'text': 'Earlier wake was too late.'},
                )
                as AgentMessagePayloadEntity;
        final observationMessage =
            AgentDomainEntity.agentMessage(
                  id: 'old-observation',
                  agentId: agentId,
                  threadId: 'old-thread',
                  kind: AgentMessageKind.observation,
                  createdAt: now.subtract(const Duration(hours: 2)),
                  vectorClock: null,
                  contentEntryId: observationPayload.id,
                  metadata: const AgentMessageMetadata(runKey: 'old-run'),
                )
                as AgentMessageEntity;
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

        final userPayload =
            jsonDecode(conversationRepository.lastUserMessage!)
                as Map<String, dynamic>;
        expect(userPayload['dayId'], dayId);
        expect(userPayload['planDate'], '2026-05-25T00:00:00.000');
        expect(userPayload['triggerTokens'], ['capture-1', dayId]);
        expect(
          userPayload['recentObservations'],
          [
            {
              'createdAt': '2026-05-25T06:00:00.000',
              'text': 'Earlier wake was too late.',
            },
          ],
        );

        final scheduledState = upsertedEntities
            .whereType<AgentStateEntity>()
            .firstWhere((state) => state.scheduledWakeAt != null);
        expect(scheduledState.scheduledWakeAt, DateTime(2026, 5, 25, 8, 30));
        expect(scheduledState.toolCounterByKey, {
          'unrelated_tool:host-a': 9,
          'day_agent_set_next_wake:2026-05-25': 1,
        });
        expect(scheduledState.processedCounterByHost, isEmpty);

        final finalState = upsertedEntities.whereType<AgentStateEntity>().last;
        expect(finalState.lastWakeAt, now);
        expect(finalState.consecutiveFailureCount, 0);
        expect(finalState.wakeCounter, 1);

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

    test('includes capture context for capture-submitted wakes', () async {
      final capture =
          AgentDomainEntity.capture(
                id: 'capture-1',
                agentId: agentId,
                transcript: 'Prep demo and buy milk',
                capturedAt: DateTime(2026, 5, 25, 7, 45),
                createdAt: DateTime(2026, 5, 25, 7, 45),
                vectorClock: null,
                audioRef: 'audio-1',
              )
              as CaptureEntity;
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

      final result = await execute(
        workflow(captureService: captureService),
        triggerTokens: {dayAgentCaptureSubmittedToken('capture-1'), dayId},
      );

      expect(result.success, isTrue);
      final userPayload =
          jsonDecode(conversationRepository.lastUserMessage!)
              as Map<String, dynamic>;
      final capturePayload = userPayload['capture'] as Map<String, dynamic>;
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

    test(
      'includes a null-baseline drafting context for drafting-token wakes',
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
          triggerTokens: {dayAgentDraftingToken(dayId), dayId},
        );

        expect(result.success, isTrue);
        final userPayload =
            jsonDecode(conversationRepository.lastUserMessage!)
                as Map<String, dynamic>;
        final draftingPayload = userPayload['drafting'] as Map<String, dynamic>;
        expect(draftingPayload['requested'], isTrue);
        expect(draftingPayload['baselinePlan'], isNull);
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
          triggerTokens: {dayAgentDraftingToken(dayId), dayId},
        );

        expect(result.success, isTrue);
        final userPayload =
            jsonDecode(conversationRepository.lastUserMessage!)
                as Map<String, dynamic>;
        final draftingPayload = userPayload['drafting'] as Map<String, dynamic>;
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
          triggerTokens: {dayId},
        );

        expect(result.success, isTrue);
        final userPayload =
            jsonDecode(conversationRepository.lastUserMessage!)
                as Map<String, dynamic>;
        expect(userPayload.containsKey('drafting'), isFalse);
        verifyNever(
          () => planService.draftPlanForDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        );
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
        final userPayload =
            jsonDecode(conversationRepository.lastUserMessage!)
                as Map<String, dynamic>;
        final recentObservations =
            userPayload['recentObservations'] as List<dynamic>;
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
      final userPayload =
          jsonDecode(conversationRepository.lastUserMessage!)
              as Map<String, dynamic>;
      final recentObservations =
          userPayload['recentObservations'] as List<dynamic>;
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

    test('continues when user message persistence fails', () async {
      var writeCount = 0;
      when(() => syncService.upsertEntity(any())).thenAnswer((
        invocation,
      ) async {
        writeCount++;
        final entity =
            invocation.positionalArguments.single as AgentDomainEntity;
        if (writeCount == 1) {
          throw StateError('user payload write failed');
        }
        upsertedEntities.add(entity);
        if (entity is AgentStateEntity) {
          currentState = entity;
        }
      });

      final result = await execute(workflow());

      expect(result.success, isTrue);
      verify(
        () => domainLogger.error(
          any(),
          'failed to persist day-agent user message',
          error: any(named: 'error'),
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
        expect(
          upsertedEntities.whereType<AgentStateEntity>().any(
            (state) => state.scheduledWakeAt != null,
          ),
          isFalse,
        );
      });
    }

    test('rejects scheduled wakes after the daily cap is reached', () async {
      currentState = state(
        toolCounterByKey: const {'day_agent_set_next_wake:2026-05-25': 4},
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
      expect(
        upsertedEntities.whereType<AgentStateEntity>().any(
          (state) => state.scheduledWakeAt != null,
        ),
        isFalse,
      );
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
      expect(failureState.revision, 2);
      expect(failureState.scheduledWakeAt, isNull);
      expect(conversationRepository.deletedConversationCount, 1);
      verify(
        () => domainLogger.error(
          any(),
          'day-agent wake failed',
          error: any(named: 'error'),
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
          'day-agent wake failed',
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
      verify(
        () => domainLogger.error(
          any(),
          'failed to update day-agent failure count',
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
    });

    test(
      'rejects invalid active day IDs before starting a conversation',
      () async {
        currentState = state(activeDayId: 'not-a-day-plan');

        final result = await execute(workflow());

        expect(result.success, isFalse);
        expect(result.error, contains('Invalid active day ID'));
        expect(conversationRepository.createdConversationCount, 0);
      },
    );

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
    final manager = _managers[conversationId]!..addUserMessage(message);
    if (toolCalls.isNotEmpty) {
      manager.addAssistantMessage(toolCalls: toolCalls);
      await strategy!.processToolCalls(toolCalls: toolCalls, manager: manager);
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
    return usage;
  }

  @override
  void deleteConversation(String conversationId) {
    deletedConversationCount++;
    _managers.remove(conversationId)?.dispose();
  }
}
