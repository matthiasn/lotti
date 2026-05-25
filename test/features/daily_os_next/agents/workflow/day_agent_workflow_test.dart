import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
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
  }) {
    return makeTestState(
      id: 'state-$agentId',
      agentId: agentId,
      slots: AgentSlots(activeDayId: activeDayId),
      updatedAt: now,
      consecutiveFailureCount: consecutiveFailureCount,
      toolCounterByKey: toolCounterByKey,
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

  DayAgentWorkflow workflow({MockSoulDocumentService? soulDocumentService}) {
    return DayAgentWorkflow(
      agentRepository: repository,
      conversationRepository: conversationRepository,
      aiConfigRepository: aiConfigRepository,
      cloudInferenceRepository: cloudInferenceRepository,
      syncService: syncService,
      templateService: templateService,
      soulDocumentService: soulDocumentService,
      domainLogger: domainLogger,
      onPersistedStateChanged: changedTokens.add,
    );
  }

  Future<WakeResult> execute(DayAgentWorkflow sut) {
    return withClock(
      Clock.fixed(now),
      () => sut.execute(
        agentIdentity: identity(),
        runKey: runKey,
        triggerTokens: {'capture-1', dayId},
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
      currentState = state(consecutiveFailureCount: 2);
      conversationRepository.errorToThrow = Exception('model failed');

      final result = await execute(workflow());

      expect(result.success, isFalse);
      expect(result.error, contains('model failed'));
      final failureState = upsertedEntities.whereType<AgentStateEntity>().last;
      expect(failureState.consecutiveFailureCount, 3);
      expect(failureState.revision, 2);
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
