import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/classes/goal_trigger_tokens.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_reader.dart';
import 'package:lotti/features/goals/evaluation/goal_signal_window.dart';
import 'package:lotti/features/goals/runtime/goal_agent_phase_a.dart';
import 'package:lotti/features/goals/runtime/goal_wake_facts.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/features/goals/workflow/goal_agent_strategy.dart';
import 'package:lotti/features/goals/workflow/goal_agent_workflow.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';
import '../../agents/workflow/task_agent_workflow_test_helpers.dart';

class _FakeReader extends GoalSignalReader {
  _FakeReader([this.window = const GoalSignalWindow()])
    : super(journalDb: MockJournalDb());

  final GoalSignalWindow window;

  @override
  Future<GoalSignalWindow> read({
    required GoalCriterion criteria,
    required DateTime reference,
    int shortTermDays = 3,
  }) async => window;
}

GoalAgentWorkflow _offTrackWorkflow(
  MockAgentRepository repository,
  MockAgentSyncService syncService,
  MockConversationRepository conversationRepository,
  MockCloudInferenceRepository cloudInferenceRepository,
  MockAiConfigRepository aiConfigRepository,
) => GoalAgentWorkflow(
  repository: repository,
  syncService: syncService,
  phaseA: GoalAgentPhaseA(
    repository: repository,
    syncService: syncService,
    signalReader: _FakeReader(
      GoalSignalWindow(
        quantitativeDailySums: {
          'cumulative_step_count': {
            for (var day = 3; day <= 9; day++) DateTime.utc(2026, 8, day): 6000,
          },
        },
      ),
    ),
  ),
  conversationRepository: conversationRepository,
  cloudInferenceRepository: cloudInferenceRepository,
  aiConfigRepository: aiConfigRepository,
);

Future<GoalWakeDerivation> _offTrackDerivation(
  MockAgentRepository repository,
  GoalSpecVersionEntity version,
  DateTime now,
) => GoalAgentPhaseA(
  repository: repository,
  syncService: MockAgentSyncService(),
  signalReader: _FakeReader(
    GoalSignalWindow(
      quantitativeDailySums: {
        'cumulative_step_count': {
          for (var day = 3; day <= 9; day++) DateTime.utc(2026, 8, day): 6000,
        },
      },
    ),
  ),
).deriveWakeFacts(agentId: version.agentId, version: version, now: now);

Future<GoalWakeDerivation> _onTrackDerivation(
  MockAgentRepository repository,
  GoalSpecVersionEntity version,
  DateTime now,
) => GoalAgentPhaseA(
  repository: repository,
  syncService: MockAgentSyncService(),
  signalReader: _FakeReader(
    GoalSignalWindow(
      quantitativeDailySums: {
        'cumulative_step_count': {
          for (var day = 3; day <= 9; day++) DateTime.utc(2026, 8, day): 11000,
        },
      },
    ),
  ),
).deriveWakeFacts(agentId: version.agentId, version: version, now: now);

void _stubBadPrior(
  MockAgentRepository repository,
  String agentId,
  DateTime now,
) {
  when(
    () => repository.getEntity(goalProgressId(agentId, '2026-08-08')),
  ).thenAnswer(
    (_) async => AgentDomainEntity.goalProgress(
      id: goalProgressId(agentId, '2026-08-08'),
      agentId: agentId,
      periodKey: '2026-08-08',
      trackStatus: GoalTrackStatus.atRisk,
      attainment: 0.6,
      dataCoverage: 1,
      satisfied: false,
      specVersionId: '$agentId:spec-v1',
      createdAt: now,
      updatedAt: now,
      vectorClock: null,
    ),
  );
}

void main() {
  const agentId = 'goal-1';
  final now = DateTime(2026, 8, 9, 12);
  final fixedClock = Clock.fixed(now);

  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late MockConversationRepository conversationRepository;
  late MockAiConfigRepository aiConfigRepository;
  late MockCloudInferenceRepository cloudInferenceRepository;
  late MockConversationManager conversationManager;
  late List<AgentDomainEntity> upserts;
  late GoalAgentWorkflow workflow;

  final identity = makeTestIdentity(
    id: agentId,
    agentId: agentId,
    kind: AgentKinds.goalAgent,
  );

  final meliousProvider =
      AiConfig.inferenceProvider(
            id: 'melious-provider',
            baseUrl: 'https://api.melious.ai',
            apiKey: 'key',
            name: 'Melious',
            createdAt: DateTime(2026),
            inferenceProviderType: InferenceProviderType.melious,
          )
          as AiConfigInferenceProvider;
  final glmModel =
      AiConfig.model(
            id: 'model-glm',
            name: 'GLM 5.2',
            providerModelId: 'glm-5.2',
            inferenceProviderId: 'melious-provider',
            createdAt: DateTime(2026),
            inputModalities: const [Modality.text],
            outputModalities: const [Modality.text],
            isReasoningModel: true,
            supportsFunctionCalling: true,
            description: 'glm',
          )
          as AiConfigModel;

  void stubSpec({DateTime? startDate}) {
    when(() => repository.getEntity(goalSpecHeadId(agentId))).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecHead(
        id: goalSpecHeadId(agentId),
        agentId: agentId,
        versionId: '$agentId:spec-v1',
        updatedAt: DateTime(2026),
        vectorClock: null,
      ),
    );
    when(() => repository.getEntity('$agentId:spec-v1')).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecVersion(
        id: '$agentId:spec-v1',
        agentId: agentId,
        version: 1,
        status: GoalSpecVersionStatus.active,
        authoredBy: 'user',
        title: 'Steps',
        statement: 'Average 10,000 steps per day.',
        criteria: const GoalCriterion.metric(
          criterionId: 'steps',
          dataType: 'cumulative_step_count',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 10000,
        ),
        createdAt: DateTime(2026),
        vectorClock: null,
        startDate: startDate,
      ),
    );
  }

  void stubGlmResolution() {
    when(
      () => aiConfigRepository.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => [glmModel]);
    when(
      () => aiConfigRepository.getConfigById('melious-provider'),
    ).thenAnswer((_) async => meliousProvider);
  }

  ChatCompletionMessageToolCall toolCall(
    String name,
    Map<String, dynamic> args, {
    String id = 'call-1',
  }) => ChatCompletionMessageToolCall(
    id: id,
    type: ChatCompletionMessageToolCallType.function,
    function: ChatCompletionMessageFunctionCall(
      name: name,
      arguments: jsonEncode(args),
    ),
  );

  setUpAll(registerAllFallbackValues);

  test(
    'banner replacement intent excludes courtesy and explanation prompts',
    () {
      expect(
        isExplicitGoalAdReplacementRequest('Please explain this banner.'),
        isFalse,
      );
      expect(
        isExplicitGoalAdReplacementRequest('Please show me another banner ad.'),
        isTrue,
      );
      expect(
        isExplicitGoalAdReplacementRequest('I want to snooze this banner.'),
        isFalse,
      );
      expect(
        isExplicitGoalAdReplacementRequest("Please don't replace the banner."),
        isFalse,
      );
      expect(
        isExplicitGoalAdReplacementRequest(
          "I don't want another banner ad.",
        ),
        isFalse,
      );
      expect(
        isExplicitGoalAdReplacementRequest("I don't want a banner."),
        isFalse,
      );
      expect(
        isExplicitGoalAdReplacementRequest('I see no banner.'),
        isTrue,
      );
      expect(
        isExplicitGoalAdReplacementRequest(
          'Yes and I want a reminder banner ad of this.',
        ),
        isTrue,
      );
      expect(
        isExplicitGoalAdReplacementRequest(
          'yes now',
          previousAssistantMessage:
              "If you'd like a fresh banner right now, just say the word.",
        ),
        isTrue,
      );
      expect(
        isExplicitGoalAdReplacementRequest(
          'yes now',
          previousAssistantMessage: 'Want to squeeze in a walk today?',
        ),
        isFalse,
      );
    },
  );

  setUp(() {
    repository = MockAgentRepository();
    syncService = MockAgentSyncService();
    conversationManager = MockConversationManager();
    conversationRepository = MockConversationRepository(conversationManager);
    aiConfigRepository = MockAiConfigRepository();
    cloudInferenceRepository = MockCloudInferenceRepository();
    upserts = [];
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.goalNudge,
      ),
    ).thenAnswer((_) async => []);
    when(
      () => repository.getMessagesByKind(
        agentId,
        AgentMessageKind.observation,
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => repository.getReportHead(agentId, AgentReportScopes.current),
    ).thenAnswer((_) async => null);
    when(
      () => repository.getLatestReport(agentId, AgentReportScopes.current),
    ).thenAnswer((_) async => null);
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      upserts.add(invocation.positionalArguments.first as AgentDomainEntity);
    });
    when(() => conversationManager.messages).thenReturn(const []);
    workflow = GoalAgentWorkflow(
      repository: repository,
      syncService: syncService,
      phaseA: GoalAgentPhaseA(
        repository: repository,
        syncService: syncService,
        signalReader: _FakeReader(),
      ),
      conversationRepository: conversationRepository,
      cloudInferenceRepository: cloudInferenceRepository,
      aiConfigRepository: aiConfigRepository,
    );
  });

  Future<WakeResult> run({
    AgentIdentityEntity? identityOverride,
    Set<String> triggerTokens = const {'goal-escalation:2026-08-09'},
  }) => withClock(
    fixedClock,
    () => workflow.execute(
      agentIdentity: identityOverride ?? identity,
      runKey: 'run-1',
      triggerTokens: triggerTokens,
      threadId: 'thread-1',
    ),
  );

  test('a goal without a spec head is a clean no-op — no inference', () async {
    final result = await run();
    expect(result.success, isTrue);
    expect(conversationRepository.sendMessageDelegateCallCount, 0);
    expect(upserts, isEmpty);
  });

  test('an interactive turn without a spec head fails for retry', () async {
    final result = await withClock(
      fixedClock,
      () => workflow.execute(
        agentIdentity: identity,
        runKey: 'run-1',
        triggerTokens: const {},
        threadId: 'thread-1',
        pendingUserMessage: 'How am I doing?',
      ),
    );

    expect(result.success, isFalse);
    expect(result.error, contains('spec head'));
    expect(conversationRepository.sendMessageDelegateCallCount, 0);
  });

  test('a dangling spec head fails the wake', () async {
    when(() => repository.getEntity(goalSpecHeadId(agentId))).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecHead(
        id: goalSpecHeadId(agentId),
        agentId: agentId,
        versionId: 'missing',
        updatedAt: DateTime(2026),
        vectorClock: null,
      ),
    );
    final result = await run();
    expect(result.success, isFalse);
    expect(result.error, contains('points at nothing'));
  });

  test('no resolvable provider aborts BEFORE any conversation', () async {
    stubSpec();
    when(
      () => aiConfigRepository.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => []);
    final result = await run();
    expect(result.success, isFalse);
    expect(result.error, contains('no inference provider'));
    expect(conversationRepository.sendMessageDelegateCallCount, 0);
  });

  test('a foreign-agent chat payload is rejected before inference', () async {
    when(() => repository.getEntity('message-foreign')).thenAnswer(
      (_) async => AgentDomainEntity.agentMessage(
        id: 'message-foreign',
        agentId: agentId,
        threadId: 'chat',
        kind: AgentMessageKind.user,
        createdAt: now,
        vectorClock: null,
        contentEntryId: 'payload-foreign',
        metadata: const AgentMessageMetadata(),
      ),
    );
    when(() => repository.getEntity('payload-foreign')).thenAnswer(
      (_) async => AgentDomainEntity.agentMessagePayload(
        id: 'payload-foreign',
        agentId: 'other-agent',
        createdAt: now,
        vectorClock: null,
        content: const {'text': 'private text'},
      ),
    );

    final result = await workflow.executeUserMessage(
      agentIdentity: identity,
      runKey: 'chat-run',
      triggerTokens: const {'goal-chat-message:message-foreign'},
      threadId: 'chat',
      messageId: 'message-foreign',
    );

    expect(result.success, isFalse);
    expect(result.error, contains('payload is unavailable'));
    expect(conversationRepository.sendMessageDelegateCallCount, 0);
  });

  test('a failed chat turn never re-arms the scheduled escalation', () async {
    stubSpec();
    when(
      () => aiConfigRepository.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => []);
    when(() => repository.getEntity('message-chat')).thenAnswer(
      (_) async => AgentDomainEntity.agentMessage(
        id: 'message-chat',
        agentId: agentId,
        threadId: 'chat',
        kind: AgentMessageKind.user,
        createdAt: now,
        vectorClock: null,
        contentEntryId: 'payload-chat',
        metadata: const AgentMessageMetadata(),
      ),
    );
    when(() => repository.getEntity('payload-chat')).thenAnswer(
      (_) async => AgentDomainEntity.agentMessagePayload(
        id: 'payload-chat',
        agentId: agentId,
        createdAt: now,
        vectorClock: null,
        content: const {'text': 'How am I doing?'},
      ),
    );

    final result = await workflow.executeUserMessage(
      agentIdentity: identity,
      runKey: 'chat-run',
      triggerTokens: const {'goal-chat-message:message-chat'},
      threadId: 'chat',
      messageId: 'message-chat',
    );

    expect(result.success, isFalse);
    expect(upserts.whereType<ScheduledWakeEntity>(), isEmpty);
  });

  test('an interactive wake without a visible reply fails instead of silently '
      'acknowledging the source turn', () async {
    stubSpec();
    stubGlmResolution();
    when(() => repository.getEntity('message-silent')).thenAnswer(
      (_) async => AgentDomainEntity.agentMessage(
        id: 'message-silent',
        agentId: agentId,
        threadId: 'chat',
        kind: AgentMessageKind.user,
        createdAt: now,
        vectorClock: null,
        contentEntryId: 'payload-silent',
        metadata: const AgentMessageMetadata(),
      ),
    );
    when(() => repository.getEntity('payload-silent')).thenAnswer(
      (_) async => AgentDomainEntity.agentMessagePayload(
        id: 'payload-silent',
        agentId: agentId,
        createdAt: now,
        vectorClock: null,
        content: const {'text': 'How am I doing?'},
      ),
    );
    conversationRepository
      ..maxDelegateCalls = 2
      ..sendMessageDelegate =
          ({
            required conversationId,
            required message,
            required model,
            required provider,
            required inferenceRepo,
            tools,
            toolChoice,
            temperature = 0.7,
            strategy,
          }) async => null;

    final result = await workflow.executeUserMessage(
      agentIdentity: identity,
      runKey: 'chat-run',
      triggerTokens: const {'goal-chat-message:message-silent'},
      threadId: 'chat',
      messageId: 'message-silent',
    );

    expect(result.success, isFalse);
    expect(result.error, contains('no visible reply'));
    expect(conversationRepository.sendMessageDelegateCallCount, 2);
  });

  test('a full wake persists FACTS, report + head, the new ad, and token '
      'usage — all attributed to glm-5.2', () async {
    stubSpec();
    stubGlmResolution();
    workflow = _offTrackWorkflow(
      repository,
      syncService,
      conversationRepository,
      cloudInferenceRepository,
      aiConfigRepository,
    );
    _stubBadPrior(repository, agentId, now);
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0.7,
          strategy,
        }) async {
          expect(model, 'glm-5.2');
          expect(provider.id, 'melious-provider');
          expect(temperature, 0);
          expect(message, startsWith('FACTS (deterministic'));
          expect(tools, hasLength(goalAgentTools.length));
          await (strategy! as GoalAgentStrategy).processToolCalls(
            toolCalls: [
              toolCall(GoalAgentToolNames.updateGoalReport, {
                'status': 'offTrack',
                'oneLiner': 'Averaging 6k of 10k steps.',
                'tldr': 'The rolling week slid well under target.',
              }, id: 'call-a'),
              toolCall(GoalAgentToolNames.createGoalAd, {
                'headline': 'Your pedometer misses you.',
                'tone': 'nudge',
                'animation': 'steady',
                'accent': 'tide',
              }, id: 'call-b'),
            ],
            manager: conversationManager,
          );
          return const InferenceUsage(inputTokens: 900, outputTokens: 120);
        };

    final result = await run();
    expect(result.success, isTrue);
    // Consumption attribution is gated on the capture+attribution pair
    // being registered (not in this test process): the workflow must pass
    // null owners rather than attribute an unmeasured wake.
    expect(conversationRepository.lastConsumptionAgentId, isNull);

    final contextMessages = upserts.whereType<AgentMessageEntity>().where(
      (m) => m.kind == AgentMessageKind.system,
    );
    expect(
      contextMessages,
      hasLength(1),
      reason: 'the FACTS blob is inspectable but not user-authored',
    );

    final report = upserts.whereType<AgentReportEntity>().single;
    expect(report.tldr, 'The rolling week slid well under target.');
    expect(report.provenance['trackStatus'], 'offTrack');
    final head = upserts.whereType<AgentReportHeadEntity>().single;
    expect(head.reportId, report.id);

    final nudge = upserts.whereType<GoalNudgeEntity>().single;
    expect(nudge.status, GoalNudgeStatus.active);
    expect(nudge.brief.headline, 'Your pedometer misses you.');
    expect(nudge.brief.accent, GoalBannerAccent.tide);
    expect(nudge.briefDigest, goalBriefDigest(nudge.brief));
    expect(nudge.staleAt, now.toUtc().add(goalAdLifetime));
    expect(nudge.runKey, 'run-1');
    expect(nudge.triggerProgressId, goalProgressId(agentId, '2026-08-09'));

    final usage = upserts.whereType<WakeTokenUsageEntity>().single;
    expect(usage.modelId, 'glm-5.2');
    expect(usage.inputTokens, 900);
  });

  test('a contextual yes-now banner request overrides dismissal cooldown '
      'and cannot retire the requested banner', () async {
    stubSpec();
    stubGlmResolution();
    workflow = _offTrackWorkflow(
      repository,
      syncService,
      conversationRepository,
      cloudInferenceRepository,
      aiConfigRepository,
    );
    _stubBadPrior(repository, agentId, now);
    const retiredBrief = GoalNudgeBrief(
      headline: 'Below target.',
      tone: GoalNudgeTone.nudge,
      animation: GoalBannerAnimation.steady,
    );
    final dismissedTransitionBanner = AgentDomainEntity.goalNudge(
      id: 'goal_nudge:$agentId:2026-08-09:atRisk:$agentId:spec-v1',
      agentId: agentId,
      status: GoalNudgeStatus.dismissed,
      brief: retiredBrief,
      briefDigest: goalBriefDigest(retiredBrief),
      createdAt: now.subtract(const Duration(hours: 2)),
      updatedAt: now.subtract(const Duration(hours: 1)),
      vectorClock: null,
      dismissedAt: now.subtract(const Duration(hours: 1)),
    );
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.goalNudge,
      ),
    ).thenAnswer((_) async => [dismissedTransitionBanner]);
    final source = AgentDomainEntity.agentMessage(
      id: 'message-1',
      agentId: agentId,
      threadId: 'message-1',
      kind: AgentMessageKind.user,
      createdAt: now,
      vectorClock: null,
      contentEntryId: 'payload-1',
      metadata: const AgentMessageMetadata(),
    );
    when(
      () => repository.getEntity('message-1'),
    ).thenAnswer((_) async => source);
    when(() => repository.getEntity('payload-1')).thenAnswer(
      (_) async => AgentDomainEntity.agentMessagePayload(
        id: 'payload-1',
        agentId: agentId,
        createdAt: now,
        vectorClock: null,
        content: const {'text': 'yes now'},
      ),
    );
    final priorReply =
        AgentDomainEntity.agentMessage(
              id: 'prior-reply',
              agentId: agentId,
              threadId: 'prior-thread',
              kind: AgentMessageKind.action,
              createdAt: now.subtract(const Duration(minutes: 1)),
              vectorClock: null,
              contentEntryId: 'prior-reply-payload',
              metadata: const AgentMessageMetadata(
                toolName: AgentConversationToolNames.replyToUser,
              ),
            )
            as AgentMessageEntity;
    when(
      () => repository.getMessagesByKind(
        agentId,
        AgentMessageKind.action,
        limit: 12,
      ),
    ).thenAnswer((_) async => [priorReply]);
    when(() => repository.getEntity('prior-reply-payload')).thenAnswer(
      (_) async => AgentDomainEntity.agentMessagePayload(
        id: 'prior-reply-payload',
        agentId: agentId,
        createdAt: now.subtract(const Duration(minutes: 1)),
        vectorClock: null,
        content: const {
          'text':
              "If you'd like me to put a fresh banner up right now, just "
              'say the word.',
        },
      ),
    );
    conversationRepository.maxDelegateCalls = 3;
    var calls = 0;
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0.7,
          strategy,
        }) async {
          calls += 1;
          final goalStrategy = strategy! as GoalAgentStrategy;
          if (calls == 1) {
            expect(
              message,
              contains('PENDING USER MESSAGE:\nyes now'),
            );
            expect(message, contains('overrides dismissal cooldown'));
            // The primary turn answers and reports, but refuses/forgets the
            // requested ad. Deterministic policy must force the tool next.
            await goalStrategy.processToolCalls(
              toolCalls: [
                toolCall(GoalAgentToolNames.replyToUser, {
                  'message': 'Cooldown says no banner right now.',
                }),
                toolCall(GoalAgentToolNames.updateGoalReport, {
                  'status': 'offTrack',
                  'oneLiner': 'The week is below target.',
                  'tldr': 'One more walk would help.',
                }, id: 'call-report'),
              ],
              manager: conversationManager,
            );
          } else if (calls == 2) {
            expect(message, contains('Dismissal cooldown does not block'));
            expect(
              [for (final tool in tools!) tool.function.name],
              [GoalAgentToolNames.createGoalAd],
            );
            expect(toolChoice, isNotNull);
            await goalStrategy.processToolCalls(
              toolCalls: [
                toolCall(
                  GoalAgentToolNames.createGoalAd,
                  {
                    'headline': 'Your trainers filed a missing-person report.',
                    'tagline': 'One strong walk gets you moving again.',
                    'cta': 'Show up today',
                    'tone': 'roast',
                    'animation': 'pulse',
                  },
                  id: 'call-2',
                ),
              ],
              manager: conversationManager,
            );
          } else {
            expect(message, contains('A banner was created in this wake'));
            expect(
              [for (final tool in tools!) tool.function.name],
              [GoalAgentToolNames.replyToUser],
            );
            expect(toolChoice, isNotNull);
            await goalStrategy.processToolCalls(
              toolCalls: [
                toolCall(GoalAgentToolNames.replyToUser, {
                  'message':
                      'Your new banner is live '
                      '(id: 123e4567-e89b-12d3-a456-426614174000).',
                }, id: 'call-3'),
              ],
              manager: conversationManager,
            );
          }
          return null;
        };

    final result = await withClock(
      fixedClock,
      () => workflow.executeUserMessage(
        agentIdentity: identity,
        runKey: 'chat-run',
        triggerTokens: const {'goal-chat-message:message-1'},
        threadId: 'chat-run',
        messageId: 'message-1',
      ),
    );

    expect(result.success, isTrue);
    expect(
      calls,
      3,
      reason: 'primary turn, forced banner, then corrected visible reply',
    );
    expect(
      upserts.whereType<AgentMessageEntity>().where(
        (message) => message.kind == AgentMessageKind.user,
      ),
      isEmpty,
      reason: 'the source user turn was already durable before the wake',
    );
    expect(
      upserts.whereType<AgentMessagePayloadEntity>().where(
        (payload) => payload.content.values.any(
          (value) => value is String && value.contains('Cooldown says no'),
        ),
      ),
      isEmpty,
      reason:
          'a stale cooldown refusal must not become a visible chat bubble; '
          'the content-free action/tool trace may remain in internals',
    );
    expect(
      upserts.whereType<AgentMessagePayloadEntity>().any(
        (payload) => payload.content['text'] == 'Your new banner is live.',
      ),
      isTrue,
    );
    final replacement = upserts.whereType<GoalNudgeEntity>().single;
    expect(replacement.status, GoalNudgeStatus.active);
    expect(
      replacement.id,
      'goal_nudge:$agentId:2026-08-09:chat:message-1:$agentId:spec-v1',
    );
    expect(
      replacement.brief.headline,
      'Your trainers filed a missing-person report.',
    );
  });

  test('a first-evaluation wake that ends without a report gets exactly one '
      'pinned update_goal_report retry', () async {
    stubSpec();
    stubGlmResolution();
    conversationRepository.maxDelegateCalls = 3;
    final toolChoices = <ChatCompletionToolChoiceOption?>[];
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0.7,
          strategy,
        }) async {
          toolChoices.add(toolChoice);
          if (toolChoices.length == 2) {
            expect(
              tools!.single.function.name,
              GoalAgentToolNames.updateGoalReport,
              reason: 'the retry restricts the surface to the report tool',
            );
            await (strategy! as GoalAgentStrategy).processToolCalls(
              toolCalls: [
                toolCall(GoalAgentToolNames.updateGoalReport, {
                  'status': 'insufficientData',
                  'oneLiner': 'No data.',
                  'tldr': 'Tracker quiet.',
                }),
              ],
              manager: conversationManager,
            );
          }
          return null;
        };

    final result = await run();
    expect(result.success, isTrue);
    expect(toolChoices, hasLength(2), reason: 'primary + one forced retry');
    expect(toolChoices.first, isNull);
    expect(toolChoices.last, isNotNull);
    expect(upserts.whereType<AgentReportEntity>(), hasLength(1));
  });

  test('an explicit detail-page refresh forces a standing report even when '
      'the recomputed status did not change', () async {
    stubSpec();
    stubGlmResolution();
    when(
      () => repository.getEntity(goalProgressId(agentId, '2026-08-09')),
    ).thenAnswer(
      (_) async => AgentDomainEntity.goalProgress(
        id: goalProgressId(agentId, '2026-08-09'),
        agentId: agentId,
        periodKey: '2026-08-09',
        trackStatus: GoalTrackStatus.insufficientData,
        attainment: 0,
        dataCoverage: 0,
        satisfied: false,
        specVersionId: '$agentId:spec-v1',
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
      ),
    );
    conversationRepository.maxDelegateCalls = 2;
    var calls = 0;
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0.7,
          strategy,
        }) async {
          calls += 1;
          if (calls == 1) {
            expect(message, contains('USER REQUESTED REPORT REFRESH'));
          } else {
            expect(message, contains('editing a habit day'));
            expect(
              [for (final tool in tools!) tool.function.name],
              [GoalAgentToolNames.updateGoalReport],
            );
            expect(toolChoice, isNotNull);
            await (strategy! as GoalAgentStrategy).processToolCalls(
              toolCalls: [
                toolCall(GoalAgentToolNames.updateGoalReport, {
                  'status': 'insufficientData',
                  'oneLiner': 'The edited day is accounted for.',
                  'tldr': 'The standing report now reflects the correction.',
                }),
              ],
              manager: conversationManager,
            );
          }
          return null;
        };

    final result = await run(
      triggerTokens: const {goalReportRefreshTriggerToken},
    );

    expect(result.success, isTrue);
    expect(calls, 2, reason: 'primary turn plus one forced report tool turn');
    final report = upserts.whereType<AgentReportEntity>().single;
    expect(report.oneLiner, 'The edited day is accounted for.');
  });

  test('persistOutputs: retire is dismissal-terminal-safe, rerun requires a '
      'retired ad and increments the activation count, and a revision '
      'proposal lands as a pending ChangeSet', () async {
    GoalNudgeEntity nudgeRow(
      String id,
      GoalNudgeStatus status, {
      DateTime? staleAt,
      Map<String, String> provenance = const {},
    }) =>
        AgentDomainEntity.goalNudge(
              id: id,
              agentId: agentId,
              status: status,
              brief: const GoalNudgeBrief(
                headline: 'h',
                tone: GoalNudgeTone.nudge,
                animation: GoalBannerAnimation.steady,
              ),
              briefDigest: 'd',
              createdAt: DateTime(2026, 8),
              updatedAt: DateTime(2026, 8),
              staleAt: staleAt,
              vectorClock: null,
              provenance: provenance,
            )
            as GoalNudgeEntity;

    final strategy = GoalAgentStrategy(
      syncService: syncService,
      agentId: agentId,
      threadId: 'thread-1',
      runKey: 'run-1',
      knownAdIds: {
        'ad-dismissed',
        'ad-retired',
        'ad-active',
        'ad-snooze',
        'ad-snooze-long',
        'ad-gone',
      },
    );
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.goalNudge,
      ),
    ).thenAnswer(
      (_) async => [
        nudgeRow('ad-dismissed', GoalNudgeStatus.dismissed),
        nudgeRow(
          'ad-retired',
          GoalNudgeStatus.retired,
          provenance: const {
            'snoozedUntil': '2026-08-10T08:30:00.000Z',
            'snoozeReason': 'old snooze',
            'snoozedAt': '2026-08-09T08:30:00.000Z',
            'campaign': 'morning-walk',
          },
        ),
        nudgeRow('ad-active', GoalNudgeStatus.active),
        nudgeRow('ad-snooze', GoalNudgeStatus.active),
        nudgeRow(
          'ad-snooze-long',
          GoalNudgeStatus.active,
          staleAt: DateTime.utc(2100),
        ),
      ],
    );
    // The retire loops re-read each row inside the transaction.
    when(() => repository.getEntity('ad-dismissed')).thenAnswer(
      (_) async => nudgeRow('ad-dismissed', GoalNudgeStatus.dismissed),
    );
    when(() => repository.getEntity('ad-active')).thenAnswer(
      (_) async => nudgeRow('ad-active', GoalNudgeStatus.active),
    );
    await strategy.processToolCalls(
      toolCalls: [
        toolCall(GoalAgentToolNames.retireGoalAd, {
          'adId': 'ad-dismissed',
          'reason': 'stale',
        }, id: 'c1'),
        toolCall(GoalAgentToolNames.retireGoalAd, {
          'adId': 'ad-gone',
          'reason': 'stale',
        }, id: 'c2'),
        toolCall(GoalAgentToolNames.rerunGoalAd, {
          'adId': 'ad-retired',
          'reason': 'proven copy',
        }, id: 'c3'),
        toolCall(GoalAgentToolNames.rerunGoalAd, {
          'adId': 'ad-active',
          'reason': 'already running',
        }, id: 'c4'),
        toolCall(GoalAgentToolNames.proposeGoalRevision, {
          'changes': {'targetValue': 8000},
          'rationale': 'user asked to ease off',
        }, id: 'c5'),
        toolCall(GoalAgentToolNames.retireGoalAd, {
          'adId': 'ad-active',
          'reason': 'quota completed',
        }, id: 'c6'),
        toolCall(GoalAgentToolNames.snoozeGoalAd, {
          'adId': 'ad-snooze',
          'until': '2099-08-12T08:30:00Z',
          'reason': 'user asked for later',
        }, id: 'c7'),
        toolCall(GoalAgentToolNames.snoozeGoalAd, {
          'adId': 'ad-snooze-long',
          'until': '2099-08-12T08:30:00Z',
          'reason': 'keep the longer lifetime',
        }, id: 'c8'),
      ],
      manager: conversationManager,
    );

    stubSpec();
    _stubBadPrior(repository, agentId, now);
    await withClock(
      fixedClock,
      () async {
        final version =
            await repository.getEntity('$agentId:spec-v1')
                as GoalSpecVersionEntity?;
        await workflow.persistOutputs(
          agentId: agentId,
          runKey: 'run-1',
          threadId: 'thread-1',
          strategy: strategy,
          derivation: await _offTrackDerivation(repository, version!, now),
          now: now,
        );
      },
    );

    final written = upserts.whereType<GoalNudgeEntity>().toList();
    // The dismissed ad was NOT retired (terminal), the missing ad was
    // skipped, the active ad was NOT re-run but WAS retired; the retired
    // ad was re-run.
    expect(written, hasLength(4));
    final retired = written.singleWhere((n) => n.id == 'ad-active');
    expect(retired.status, GoalNudgeStatus.retired);
    expect(retired.provenance['retireReason'], 'quota completed');
    final rerun = written.singleWhere((n) => n.id == 'ad-retired');
    expect(rerun.status, GoalNudgeStatus.active);
    expect(rerun.activationCount, 2);
    expect(rerun.provenance['rerunReason'], 'proven copy');
    expect(rerun.provenance['campaign'], 'morning-walk');
    expect(rerun.provenance, isNot(contains('snoozedUntil')));
    expect(rerun.provenance, isNot(contains('snoozeReason')));
    expect(rerun.provenance, isNot(contains('snoozedAt')));
    final snoozed = written.singleWhere((n) => n.id == 'ad-snooze');
    expect(snoozed.status, GoalNudgeStatus.active);
    expect(
      snoozed.provenance['snoozedUntil'],
      '2099-08-12T08:30:00.000Z',
    );
    expect(snoozed.provenance['snoozeReason'], 'user asked for later');
    expect(
      snoozed.staleAt,
      DateTime.utc(2099, 8, 12, 8, 30).add(goalAdLifetime),
      reason: 'the banner must remain live after its snooze expires',
    );
    final longLived = written.singleWhere((n) => n.id == 'ad-snooze-long');
    expect(
      longLived.staleAt,
      DateTime.utc(2100),
      reason: 'snoozing must never shorten an existing useful lifetime',
    );

    final changeSet = upserts.whereType<ChangeSetEntity>().single;
    expect(changeSet.status, ChangeSetStatus.pending);
    expect(changeSet.taskId, agentId);
    expect(
      changeSet.items.single.args['changes'],
      {'targetValue': 8000},
    );
  });

  test('kitchen sink: profile override, reusable library in FACTS, '
      'observation payload resolution, thought + observation persistence, '
      'and retry-usage merging', () async {
    stubSpec();
    _stubBadPrior(repository, agentId, now);
    final profileIdentity = makeTestIdentity(
      id: agentId,
      agentId: agentId,
      kind: AgentKinds.goalAgent,
      config: const AgentConfig(profileId: 'profile-1'),
    );
    final profile =
        AiConfig.inferenceProfile(
              id: 'profile-1',
              name: 'Goals profile',
              createdAt: DateTime(2026),
              thinkingModelId: 'glm-5.2',
            )
            as AiConfigInferenceProfile;
    when(
      () => aiConfigRepository.getConfigById('profile-1'),
    ).thenAnswer((_) async => profile);
    stubGlmResolution();

    // A retired, top-rated ad → offered as reusable, so its id is legal.
    final reusable =
        AgentDomainEntity.goalNudge(
              id: 'ad-top',
              agentId: agentId,
              status: GoalNudgeStatus.retired,
              brief: const GoalNudgeBrief(
                headline: 'h',
                tone: GoalNudgeTone.nudge,
                animation: GoalBannerAnimation.steady,
              ),
              briefDigest: 'd',
              createdAt: DateTime(2026, 8),
              updatedAt: DateTime(2026, 8),
              vectorClock: null,
              ratings: [
                GoalNudgeRating(
                  activation: 1,
                  ratedAt: DateTime(2026, 8, 2),
                  rating: 5,
                ),
              ],
            )
            as GoalNudgeEntity;
    final activeAd =
        AgentDomainEntity.goalNudge(
              id: 'ad-live',
              agentId: agentId,
              status: GoalNudgeStatus.active,
              brief: const GoalNudgeBrief(
                headline: 'live',
                tone: GoalNudgeTone.nudge,
                animation: GoalBannerAnimation.steady,
              ),
              briefDigest: 'd2',
              createdAt: DateTime(2026, 8),
              updatedAt: DateTime(2026, 8),
              vectorClock: null,
            )
            as GoalNudgeEntity;
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.goalNudge,
      ),
    ).thenAnswer((_) async => [reusable, activeAd]);

    // One observation whose payload text must land in the FACTS block.
    when(
      () => repository.getMessagesByKind(
        agentId,
        AgentMessageKind.observation,
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => [
        AgentDomainEntity.agentMessage(
              id: 'msg-1',
              agentId: agentId,
              threadId: 'old-thread',
              kind: AgentMessageKind.observation,
              createdAt: DateTime(2026, 8),
              vectorClock: null,
              contentEntryId: 'payload-1',
              metadata: const AgentMessageMetadata(runKey: 'old-run'),
            )
            as AgentMessageEntity,
      ],
    );
    when(() => repository.getEntity('payload-1')).thenAnswer(
      (_) async => AgentDomainEntity.agentMessagePayload(
        id: 'payload-1',
        agentId: agentId,
        createdAt: DateTime(2026, 8),
        vectorClock: null,
        content: const <String, Object?>{'text': 'User prefers roast tone.'},
      ),
    );

    when(() => conversationManager.messages).thenReturn([
      const ChatCompletionMessage.assistant(
        content: 'Re-running the proven banner.',
      ),
    ]);
    workflow = _offTrackWorkflow(
      repository,
      syncService,
      conversationRepository,
      cloudInferenceRepository,
      aiConfigRepository,
    );

    conversationRepository.maxDelegateCalls = 2;
    var calls = 0;
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0.7,
          strategy,
        }) async {
          calls++;
          if (calls == 1) {
            expect(message, contains('User prefers roast tone.'));
            expect(message, contains('ad-top'));
            await (strategy! as GoalAgentStrategy).processToolCalls(
              toolCalls: [
                toolCall(GoalAgentToolNames.rerunGoalAd, {
                  'adId': 'ad-top',
                  'reason': 'proven copy',
                }, id: 'call-a'),
                toolCall(GoalAgentToolNames.recordGoalObservation, {
                  'note': 'Roast tone confirmed effective.',
                }, id: 'call-b'),
              ],
              manager: conversationManager,
            );
            return const InferenceUsage(inputTokens: 800, outputTokens: 90);
          }
          // Forced retry (the transition wake missed its report).
          await (strategy! as GoalAgentStrategy).processToolCalls(
            toolCalls: [
              toolCall(GoalAgentToolNames.updateGoalReport, {
                'status': 'offTrack',
                'oneLiner': 'Behind.',
                'tldr': 'The week slid under target.',
              }),
            ],
            manager: conversationManager,
          );
          return const InferenceUsage(inputTokens: 200, outputTokens: 40);
        };

    final result = await run(identityOverride: profileIdentity);
    expect(result.success, isTrue);

    final rerun = upserts.whereType<GoalNudgeEntity>().single;
    expect(rerun.status, GoalNudgeStatus.active);
    expect(rerun.activationCount, 2);

    // The strategy's mixin records in-conversation assistant markers as
    // thoughts too; the workflow's final thought is the one carrying a
    // payload.
    final thought = upserts.whereType<AgentMessageEntity>().where(
      (m) => m.kind == AgentMessageKind.thought && m.contentEntryId != null,
    );
    expect(thought, hasLength(1));
    final observation = upserts.whereType<AgentMessageEntity>().where(
      (m) => m.kind == AgentMessageKind.observation,
    );
    expect(observation, hasLength(1));

    final usage = upserts.whereType<WakeTokenUsageEntity>().single;
    expect(usage.inputTokens, 1000, reason: 'primary + retry usage merged');
  });

  test('with the consumption pair registered, the report carries the '
      'attribution envelope and owners flow to sendMessage', () async {
    final attribution = MockAiAttributionService();
    getIt
      ..registerSingleton<AiInteractionCapture>(MockAiInteractionCapture())
      ..registerSingleton<AiAttributionService>(attribution);
    addTearDown(getIt.reset);
    final envelope = AiWorkAttribution(
      id: 'attr-1',
      workType: AiWorkType.agentReport,
      status: AiWorkStatus.succeeded,
      initiator: const AiActorSnapshot(
        type: AiActorType.agent,
        id: agentId,
        displayName: 'Steps goal',
      ),
      trigger: const AiTriggerSnapshot(type: AiTriggerType.automatic),
      startedAt: now,
      completedAt: now,
      vectorClock: null,
    );
    when(
      () => attribution.prepareCompletion(
        attributionId: any(named: 'attributionId'),
        outputs: any(named: 'outputs'),
      ),
    ).thenAnswer((_) async => envelope);
    when(() => attribution.finalize(any())).thenAnswer((_) async {});

    stubSpec();
    stubGlmResolution();
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0.7,
          strategy,
        }) async {
          await (strategy! as GoalAgentStrategy).processToolCalls(
            toolCalls: [
              toolCall(GoalAgentToolNames.updateGoalReport, {
                'status': 'insufficientData',
                'oneLiner': 'No data.',
                'tldr': 'Quiet tracker.',
              }),
            ],
            manager: conversationManager,
          );
          return null;
        };

    final result = await run();
    expect(result.success, isTrue);
    expect(conversationRepository.lastConsumptionAgentId, agentId);
    expect(conversationRepository.lastConsumptionWakeRunKey, 'run-1');
    final report = upserts.whereType<AgentReportEntity>().single;
    expect(report.provenance.keys, contains(aiAttributionProvenanceKey));
    // The session must not stay open: the envelope is finalized after the
    // transaction so consumption rollups see the wake as completed.
    verify(() => attribution.finalize(envelope)).called(1);
  });

  test('a report-less wake with consumption registered is terminalized as '
      'carrierless — no perpetually in-flight sessions', () async {
    final attribution = MockAiAttributionService();
    getIt
      ..registerSingleton<AiInteractionCapture>(MockAiInteractionCapture())
      ..registerSingleton<AiAttributionService>(attribution);
    addTearDown(getIt.reset);
    final closed = AiWorkAttribution(
      id: 'attr-closed',
      workType: AiWorkType.agentReport,
      status: AiWorkStatus.partial,
      initiator: const AiActorSnapshot(
        type: AiActorType.agent,
        id: agentId,
        displayName: 'Steps goal',
      ),
      trigger: const AiTriggerSnapshot(type: AiTriggerType.automatic),
      startedAt: now,
      completedAt: now,
      vectorClock: null,
    );
    when(
      () => attribution.prepareCompletion(
        attributionId: any(named: 'attributionId'),
        outputs: any(named: 'outputs'),
        status: any(named: 'status'),
        errorCode: any(named: 'errorCode'),
        errorSummary: any(named: 'errorSummary'),
      ),
    ).thenAnswer((_) async => closed);
    when(() => attribution.finalize(any())).thenAnswer((_) async {});

    stubSpec();
    stubGlmResolution();
    conversationRepository
      ..maxDelegateCalls = 2
      ..sendMessageDelegate =
          ({
            required conversationId,
            required message,
            required model,
            required provider,
            required inferenceRepo,
            tools,
            toolChoice,
            temperature = 0.7,
            strategy,
          }) async => null;

    final result = await run();
    expect(result.success, isTrue);
    verify(
      () => attribution.prepareCompletion(
        attributionId: any(named: 'attributionId'),
        outputs: any(named: 'outputs'),
        status: AiWorkStatus.partial,
        errorCode: 'output_carrier_unavailable',
        errorSummary: any(named: 'errorSummary'),
      ),
    ).called(1);
    verify(() => attribution.finalize(closed)).called(1);
  });

  test(
    'an inference failure is contained as a failed wake, not a crash',
    () async {
      stubSpec();
      stubGlmResolution();
      conversationRepository.sendMessageDelegate =
          ({
            required conversationId,
            required message,
            required model,
            required provider,
            required inferenceRepo,
            tools,
            toolChoice,
            temperature = 0.7,
            strategy,
          }) async {
            throw StateError('provider melted');
          };
      final result = await run();
      expect(result.success, isFalse);
      expect(result.error, contains('provider melted'));
    },
  );

  test(
    'a failing forced retry is swallowed — the partial wake persists',
    () async {
      stubSpec();
      stubGlmResolution();
      conversationRepository.maxDelegateCalls = 2;
      var calls = 0;
      conversationRepository.sendMessageDelegate =
          ({
            required conversationId,
            required message,
            required model,
            required provider,
            required inferenceRepo,
            tools,
            toolChoice,
            temperature = 0.7,
            strategy,
          }) async {
            calls++;
            if (calls == 2) throw StateError('retry melted');
            return null;
          };
      final result = await run();
      expect(result.success, isTrue);
      expect(calls, 2);
      expect(upserts.whereType<AgentReportEntity>(), isEmpty);
    },
  );

  test("Phase A's own register write cannot erase the transition: the "
      'FACTS baseline is the prior day, so materialChange survives', () async {
    stubSpec();
    stubGlmResolution();
    // Phase A already wrote today's row with the NEW status before arming
    // this escalation — naive re-derivation would see no transition.
    when(
      () => repository.getEntity(goalProgressId(agentId, '2026-08-09')),
    ).thenAnswer(
      (_) async => AgentDomainEntity.goalProgress(
        id: goalProgressId(agentId, '2026-08-09'),
        agentId: agentId,
        periodKey: '2026-08-09',
        trackStatus: GoalTrackStatus.insufficientData,
        attainment: 0,
        dataCoverage: 0,
        satisfied: false,
        specVersionId: '$agentId:spec-v1',
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
      ),
    );
    String? factsSeen;
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0.7,
          strategy,
        }) async {
          factsSeen = message;
          await (strategy! as GoalAgentStrategy).processToolCalls(
            toolCalls: [
              toolCall(GoalAgentToolNames.updateGoalReport, {
                'status': 'insufficientData',
                'oneLiner': 'No data.',
                'tldr': 'Quiet tracker.',
              }),
            ],
            manager: conversationManager,
          );
          return null;
        };

    final result = await run();
    expect(result.success, isTrue);
    expect(
      factsSeen,
      contains('"materialChangeSinceLastReport": true'),
      reason: 'the transition that armed Phase B must reach the model',
    );
  });

  test(
    'a stale escalation evaluates ITS period, not the day it runs on',
    () async {
      stubSpec();
      stubGlmResolution();
      workflow = _offTrackWorkflow(
        repository,
        syncService,
        conversationRepository,
        cloudInferenceRepository,
        aiConfigRepository,
      );
      // Prior bad day under the SAME (old) spec version → grace exhausted
      // → offTrack, so the ad is policy-eligible.
      when(
        () => repository.getEntity(goalProgressId(agentId, '2026-08-05')),
      ).thenAnswer(
        (_) async => AgentDomainEntity.goalProgress(
          id: goalProgressId(agentId, '2026-08-05'),
          agentId: agentId,
          periodKey: '2026-08-05',
          trackStatus: GoalTrackStatus.atRisk,
          attainment: 0.6,
          dataCoverage: 1,
          satisfied: false,
          specVersionId: '$agentId:spec-v0',
          createdAt: DateTime(2026, 8, 5),
          updatedAt: DateTime(2026, 8, 5),
          vectorClock: null,
        ),
      );
      // The old period's register was computed under a superseded spec —
      // the wake must be judged against THAT version, not today's head.
      when(
        () => repository.getEntity(goalProgressId(agentId, '2026-08-06')),
      ).thenAnswer(
        (_) async => AgentDomainEntity.goalProgress(
          id: goalProgressId(agentId, '2026-08-06'),
          agentId: agentId,
          periodKey: '2026-08-06',
          trackStatus: GoalTrackStatus.atRisk,
          attainment: 0.6,
          dataCoverage: 1,
          satisfied: false,
          specVersionId: '$agentId:spec-v0',
          createdAt: DateTime(2026, 8, 6),
          updatedAt: DateTime(2026, 8, 6),
          vectorClock: null,
        ),
      );
      when(() => repository.getEntity('$agentId:spec-v0')).thenAnswer(
        (_) async => AgentDomainEntity.goalSpecVersion(
          id: '$agentId:spec-v0',
          agentId: agentId,
          version: 0,
          status: GoalSpecVersionStatus.superseded,
          authoredBy: 'user',
          title: 'Steps (original)',
          statement: 'The ORIGINAL statement that armed this period.',
          criteria: const GoalCriterion.metric(
            criterionId: 'steps',
            dataType: 'cumulative_step_count',
            window: GoalWindow.rollingDays(count: 7),
            aggregation: GoalAggregation.dailySumThenAverage,
            target: 8000,
          ),
          createdAt: DateTime(2026, 7),
          vectorClock: null,
        ),
      );
      String? factsSeen;
      conversationRepository.sendMessageDelegate =
          ({
            required conversationId,
            required message,
            required model,
            required provider,
            required inferenceRepo,
            tools,
            toolChoice,
            temperature = 0.7,
            strategy,
          }) async {
            factsSeen = message;
            await (strategy! as GoalAgentStrategy).processToolCalls(
              toolCalls: [
                toolCall(GoalAgentToolNames.updateGoalReport, {
                  'status': 'offTrack',
                  'oneLiner': 'Behind on the old spec.',
                  'tldr': 'That week slid under target.',
                }, id: 'call-a'),
                toolCall(GoalAgentToolNames.createGoalAd, {
                  'headline': 'Late but not forgotten.',
                  'tone': 'nudge',
                  'animation': 'steady',
                }, id: 'call-b'),
              ],
              manager: conversationManager,
            );
            return null;
          };

      final result = await withClock(
        fixedClock,
        () => workflow.execute(
          agentIdentity: identity,
          runKey: 'run-late',
          // Armed three days ago; processed only now.
          triggerTokens: const {'goal-escalation:2026-08-06'},
          threadId: 'thread-late',
        ),
      );
      expect(result.success, isTrue);
      expect(
        upserts.whereType<GoalNudgeEntity>(),
        isEmpty,
        reason:
            'a superseded-spec wake records history, never a new '
            'banner beside the revised goal',
      );
      expect(
        factsSeen,
        contains('The ORIGINAL statement that armed this period.'),
        reason: 'the period is judged against the spec that armed it',
      );
    },
  );

  test('a wake resolved onto a NON-HEAD active version no-ops before any '
      'inference spend — split-brain approvals cost nothing', () async {
    stubSpec();
    // The escalation period's register was armed under a different,
    // still-ACTIVE version (a disconnected same-ordinal approval).
    when(
      () => repository.getEntity(goalProgressId(agentId, '2026-08-06')),
    ).thenAnswer(
      (_) async => AgentDomainEntity.goalProgress(
        id: goalProgressId(agentId, '2026-08-06'),
        agentId: agentId,
        periodKey: '2026-08-06',
        trackStatus: GoalTrackStatus.atRisk,
        attainment: 0.6,
        dataCoverage: 1,
        satisfied: false,
        specVersionId: '$agentId:spec-v2-loser',
        createdAt: DateTime(2026, 8, 6),
        updatedAt: DateTime(2026, 8, 6),
        vectorClock: null,
      ),
    );
    when(() => repository.getEntity('$agentId:spec-v2-loser')).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecVersion(
        id: '$agentId:spec-v2-loser',
        agentId: agentId,
        version: 2,
        status: GoalSpecVersionStatus.active,
        authoredBy: 'user',
        title: 'Steps (split-brain)',
        statement: 'x',
        criteria: const GoalCriterion.metric(
          criterionId: 'steps',
          dataType: 'cumulative_step_count',
          window: GoalWindow.rollingDays(count: 7),
          aggregation: GoalAggregation.dailySumThenAverage,
          target: 9000,
        ),
        createdAt: DateTime(2026, 8, 6),
        vectorClock: null,
      ),
    );
    var inferenceRan = false;
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0.7,
          strategy,
        }) async {
          inferenceRan = true;
          return null;
        };

    final result = await withClock(
      fixedClock,
      () => workflow.execute(
        agentIdentity: identity,
        runKey: 'run-splitbrain',
        triggerTokens: const {'goal-escalation:2026-08-06'},
        threadId: 'thread-sb',
      ),
    );
    expect(result.success, isTrue);
    expect(inferenceRan, isFalse, reason: 'no model spend on a doomed wake');
    expect(upserts, isEmpty);
  });

  test('persistOutputs: a spec head that moved during the wake fences '
      'every output — nothing publishes beside the revised goal', () async {
    stubSpec();
    _stubBadPrior(repository, agentId, now);
    // The wake derived against v1, but a revision landed v2 meanwhile.
    final version =
        await repository.getEntity('$agentId:spec-v1')
            as GoalSpecVersionEntity?;
    final derivation = await _offTrackDerivation(repository, version!, now);
    when(() => repository.getEntity(goalSpecHeadId(agentId))).thenAnswer(
      (_) async => AgentDomainEntity.goalSpecHead(
        id: goalSpecHeadId(agentId),
        agentId: agentId,
        versionId: '$agentId:spec-v2',
        updatedAt: now,
        vectorClock: null,
      ),
    );
    final strategy = GoalAgentStrategy(
      syncService: syncService,
      agentId: agentId,
      threadId: 'thread-1',
      runKey: 'run-1',
      knownAdIds: const {},
    );
    await strategy.processToolCalls(
      toolCalls: [
        toolCall(GoalAgentToolNames.updateGoalReport, {
          'status': 'offTrack',
          'oneLiner': 'Two days behind on the OLD target.',
          'tldr': 't',
        }, id: 'c1'),
      ],
      manager: conversationManager,
    );

    final finalized = await withClock(
      fixedClock,
      () => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-1',
        threadId: 'thread-1',
        strategy: strategy,
        derivation: derivation,
        now: now,
      ),
    );

    expect(finalized, isFalse);
    // The conversation's own message trail (thought/action/toolResult)
    // already landed while the model ran — the fence stops the OUTPUTS:
    // no report, no head move, no banner.
    expect(upserts.whereType<AgentReportEntity>(), isEmpty);
    expect(upserts.whereType<AgentReportHeadEntity>(), isEmpty);
    expect(
      upserts.whereType<GoalNudgeEntity>(),
      isEmpty,
      reason: 'a superseded-spec wake must not publish report or ads',
    );
  });

  test(
    'persistOutputs: an interactive turn fenced by a concurrent revision '
    'fails instead of silently leaving its durable user turn unanswered',
    () async {
      stubSpec();
      _stubBadPrior(repository, agentId, now);
      final version =
          await repository.getEntity('$agentId:spec-v1')
              as GoalSpecVersionEntity?;
      final derivation = await _offTrackDerivation(repository, version!, now);
      when(() => repository.getEntity(goalSpecHeadId(agentId))).thenAnswer(
        (_) async => AgentDomainEntity.goalSpecHead(
          id: goalSpecHeadId(agentId),
          agentId: agentId,
          versionId: '$agentId:spec-v2',
          updatedAt: now,
          vectorClock: null,
        ),
      );
      final strategy = GoalAgentStrategy(
        syncService: syncService,
        agentId: agentId,
        threadId: 'thread-chat',
        runKey: 'run-chat',
        knownAdIds: const {},
      );
      await strategy.processToolCalls(
        toolCalls: [
          toolCall(GoalAgentToolNames.replyToUser, {
            'message': 'This reply belongs to the old goal.',
          }),
        ],
        manager: conversationManager,
      );

      await expectLater(
        withClock(
          fixedClock,
          () => workflow.persistOutputs(
            agentId: agentId,
            runKey: 'run-chat',
            threadId: 'thread-chat',
            strategy: strategy,
            derivation: derivation,
            now: now,
            replyToUser: true,
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('concurrent spec revision'),
          ),
        ),
      );
      expect(
        upserts.whereType<AgentMessageEntity>().where(
          (message) => message.contentEntryId != null,
        ),
        isEmpty,
      );
      expect(upserts.whereType<AgentMessagePayloadEntity>(), isEmpty);
    },
  );

  test('persistOutputs: a superseded-spec wake keeps its report as history '
      'but touches NO banners and never advances the head', () async {
    stubSpec();
    _stubBadPrior(repository, agentId, now);
    final staleVersion =
        AgentDomainEntity.goalSpecVersion(
              id: '$agentId:spec-v0',
              agentId: agentId,
              version: 0,
              status: GoalSpecVersionStatus.superseded,
              authoredBy: 'user',
              title: 'Steps (original)',
              statement: 'x',
              criteria: const GoalCriterion.metric(
                criterionId: 'steps',
                dataType: 'cumulative_step_count',
                window: GoalWindow.rollingDays(count: 7),
                aggregation: GoalAggregation.dailySumThenAverage,
                target: 10000,
              ),
              createdAt: DateTime(2026, 7),
              vectorClock: null,
            )
            as GoalSpecVersionEntity;
    // Ad-ineligible historical facts over a CURRENT active banner: the
    // deterministic recovery retire must not fire across spec versions.
    final derivation = await _onTrackDerivation(repository, staleVersion, now);
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.goalNudge,
      ),
    ).thenAnswer(
      (_) async => [
        AgentDomainEntity.goalNudge(
              id: 'ad-current',
              agentId: agentId,
              status: GoalNudgeStatus.active,
              brief: const GoalNudgeBrief(
                headline: 'The revised goal still needs you.',
                tone: GoalNudgeTone.nudge,
                animation: GoalBannerAnimation.steady,
              ),
              briefDigest: 'd',
              createdAt: DateTime(2026, 8),
              updatedAt: DateTime(2026, 8),
              vectorClock: null,
            )
            as GoalNudgeEntity,
      ],
    );
    final strategy = GoalAgentStrategy(
      syncService: syncService,
      agentId: agentId,
      threadId: 'thread-1',
      runKey: 'run-1',
      knownAdIds: const {'ad-current'},
    );
    await strategy.processToolCalls(
      toolCalls: [
        toolCall(GoalAgentToolNames.updateGoalReport, {
          'status': 'onTrack',
          'oneLiner': 'That old week ended fine.',
          'tldr': 't',
        }, id: 'c1'),
        toolCall(GoalAgentToolNames.retireGoalAd, {
          'adId': 'ad-current',
          'reason': 'not mine to touch',
        }, id: 'c2'),
      ],
      manager: conversationManager,
    );

    await withClock(
      fixedClock,
      () => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-1',
        threadId: 'thread-1',
        strategy: strategy,
        derivation: derivation,
        now: now,
      ),
    );

    expect(
      upserts.whereType<AgentReportEntity>(),
      hasLength(1),
      reason: 'the historical report row still lands',
    );
    expect(
      upserts.whereType<AgentReportHeadEntity>(),
      isEmpty,
      reason: 'a superseded-spec wake never advances the shared head',
    );
    expect(
      upserts.whereType<GoalNudgeEntity>(),
      isEmpty,
      reason: "the current goal's banner is not this wake's to retire",
    );
  });

  test('persistOutputs: an ad-ineligible status retires every remaining '
      'active ad deterministically — recovery does not depend on the '
      'model calling retire_goal_ad', () async {
    stubSpec();
    _stubBadPrior(repository, agentId, now);
    final version =
        await repository.getEntity('$agentId:spec-v1')
            as GoalSpecVersionEntity?;
    final derivation = await _onTrackDerivation(repository, version!, now);
    GoalNudgeEntity recoveryRow(String id, GoalNudgeStatus status) =>
        AgentDomainEntity.goalNudge(
              id: id,
              agentId: agentId,
              status: status,
              brief: const GoalNudgeBrief(
                headline: 'Still on the couch?',
                tone: GoalNudgeTone.nudge,
                animation: GoalBannerAnimation.steady,
              ),
              briefDigest: 'd-$id',
              createdAt: DateTime(2026, 8),
              updatedAt: DateTime(2026, 8),
              vectorClock: null,
            )
            as GoalNudgeEntity;
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.goalNudge,
      ),
    ).thenAnswer(
      (_) async => [
        recoveryRow('ad-obsolete', GoalNudgeStatus.active),
        // The snapshot is read INSIDE the output transaction, so a
        // dismissal that landed while the model was thinking is already
        // visible in it — and must be skipped, not retired.
        recoveryRow('ad-just-dismissed', GoalNudgeStatus.dismissed),
      ],
    );
    final strategy = GoalAgentStrategy(
      syncService: syncService,
      agentId: agentId,
      threadId: 'thread-1',
      runKey: 'run-1',
      knownAdIds: const {'ad-obsolete'},
    );
    await strategy.processToolCalls(
      toolCalls: [
        toolCall(GoalAgentToolNames.updateGoalReport, {
          'status': 'onTrack',
          'oneLiner': 'Back on pace.',
          'tldr': 't',
        }, id: 'c1'),
      ],
      manager: conversationManager,
    );

    await withClock(
      fixedClock,
      () => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-1',
        threadId: 'thread-1',
        strategy: strategy,
        derivation: derivation,
        now: now,
      ),
    );

    final retired = upserts.whereType<GoalNudgeEntity>().single;
    expect(retired.id, 'ad-obsolete');
    expect(retired.status, GoalNudgeStatus.retired);
    expect(
      retired.provenance['retireReason'],
      'status no longer permits ads',
    );
  });

  test('persistOutputs: an active dismissal cooldown suppresses creates '
      'and reruns; duplicate brief digests collapse to one row', () async {
    final recentlyDismissed =
        AgentDomainEntity.goalNudge(
              id: 'ad-quiet',
              agentId: agentId,
              status: GoalNudgeStatus.dismissed,
              brief: const GoalNudgeBrief(
                headline: 'dismissed',
                tone: GoalNudgeTone.nudge,
                animation: GoalBannerAnimation.steady,
              ),
              briefDigest: 'd-quiet',
              createdAt: DateTime(2026, 8),
              updatedAt: DateTime(2026, 8),
              vectorClock: null,
              dismissedAt: now.subtract(const Duration(hours: 2)),
            )
            as GoalNudgeEntity;

    Future<GoalAgentStrategy> loaded(
      List<Map<String, dynamic>> creations,
    ) async {
      final strategy = GoalAgentStrategy(
        syncService: syncService,
        agentId: agentId,
        threadId: 'thread-1',
        runKey: 'run-1',
        knownAdIds: const {},
      );
      await strategy.processToolCalls(
        toolCalls: [
          for (final (i, args) in creations.indexed)
            toolCall(GoalAgentToolNames.createGoalAd, args, id: 'c$i'),
        ],
        manager: conversationManager,
      );
      return strategy;
    }

    stubSpec();
    _stubBadPrior(repository, agentId, now);
    final version =
        await repository.getEntity('$agentId:spec-v1')
            as GoalSpecVersionEntity?;
    final derivation = await _offTrackDerivation(
      repository,
      version!,
      now,
    );

    // Cooldown: the model ignored dismissalCooldownActive — persistence
    // must still hold the 24h quiet contract, for creates AND reruns.
    final logger = MockDomainLogger();
    when(
      () => logger.error(
        any(),
        any<Object>(),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
        message: any(named: 'message'),
      ),
    ).thenReturn(null);
    final logged = GoalAgentWorkflow(
      repository: repository,
      syncService: syncService,
      phaseA: GoalAgentPhaseA(
        repository: repository,
        syncService: syncService,
        signalReader: _FakeReader(),
      ),
      conversationRepository: conversationRepository,
      cloudInferenceRepository: cloudInferenceRepository,
      aiConfigRepository: aiConfigRepository,
      domainLogger: logger,
    );
    final rerunning = GoalAgentStrategy(
      syncService: syncService,
      agentId: agentId,
      threadId: 'thread-1',
      runKey: 'run-1',
      knownAdIds: const {'ad-reusable'},
    );
    await rerunning.processToolCalls(
      toolCalls: [
        toolCall(GoalAgentToolNames.createGoalAd, {
          'headline': 'Ignore the quiet.',
          'tone': 'nudge',
          'animation': 'pulse',
        }, id: 'c0'),
        toolCall(GoalAgentToolNames.rerunGoalAd, {
          'adId': 'ad-reusable',
          'reason': 'still great',
        }, id: 'c1'),
      ],
      manager: conversationManager,
    );
    await withClock(
      fixedClock,
      () async {
        when(
          () => repository.getEntitiesByAgentId(
            agentId,
            type: AgentEntityTypes.goalNudge,
          ),
        ).thenAnswer((_) async => [recentlyDismissed]);
        return logged.persistOutputs(
          agentId: agentId,
          runKey: 'run-1',
          threadId: 'thread-1',
          strategy: rerunning,
          derivation: derivation,
          now: now,
        );
      },
    );
    expect(upserts.whereType<GoalNudgeEntity>(), isEmpty);

    // Dedupe: the same copy as a RETIRED library entry → skipped (an
    // in-response duplicate is already blocked by the fresh-active guard).
    const sameWords = GoalNudgeBrief(
      headline: 'Same words.',
      tone: GoalNudgeTone.nudge,
      animation: GoalBannerAnimation.pulse,
    );
    await withClock(
      fixedClock,
      () async {
        when(
          () => repository.getEntitiesByAgentId(
            agentId,
            type: AgentEntityTypes.goalNudge,
          ),
        ).thenAnswer(
          (_) async => [
            AgentDomainEntity.goalNudge(
                  id: 'ad-old-copy',
                  agentId: agentId,
                  status: GoalNudgeStatus.retired,
                  brief: sameWords,
                  briefDigest: goalBriefDigest(sameWords),
                  createdAt: DateTime(2026, 8),
                  updatedAt: DateTime(2026, 8),
                  vectorClock: null,
                )
                as GoalNudgeEntity,
          ],
        );
        return workflow.persistOutputs(
          agentId: agentId,
          runKey: 'run-1',
          threadId: 'thread-1',
          strategy: await loaded([
            {'headline': 'Same words.', 'tone': 'nudge', 'animation': 'wave'},
          ]),
          derivation: derivation,
          now: now,
        );
      },
    );
    expect(upserts.whereType<GoalNudgeEntity>(), isEmpty);
  });

  test('persistOutputs: an explicit chat ad request overrides dismissal '
      'cooldown, replaces a rated banner, and permits recovery copy', () async {
    stubSpec();
    _stubBadPrior(repository, agentId, now);
    final version =
        await repository.getEntity('$agentId:spec-v1')
            as GoalSpecVersionEntity?;
    final derivation = await _offTrackDerivation(repository, version!, now);

    Future<GoalAgentStrategy> creating(String headline) async {
      final strategy = GoalAgentStrategy(
        syncService: syncService,
        agentId: agentId,
        threadId: 'thread-chat',
        runKey: 'run-chat',
        knownAdIds: const {},
      );
      await strategy.processToolCalls(
        toolCalls: [
          toolCall(GoalAgentToolNames.createGoalAd, {
            'headline': headline,
            'tone': 'nudge',
            'animation': 'pulse',
          }),
        ],
        manager: conversationManager,
      );
      return strategy;
    }

    final dismissed =
        AgentDomainEntity.goalNudge(
              id: 'ad-dismissed',
              agentId: agentId,
              status: GoalNudgeStatus.dismissed,
              brief: const GoalNudgeBrief(
                headline: 'Quiet now.',
                tone: GoalNudgeTone.nudge,
                animation: GoalBannerAnimation.steady,
              ),
              briefDigest: 'dismissed-digest',
              createdAt: now.subtract(const Duration(hours: 3)),
              updatedAt: now.subtract(const Duration(hours: 1)),
              vectorClock: null,
              dismissedAt: now.subtract(const Duration(hours: 1)),
            )
            as GoalNudgeEntity;
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.goalNudge,
      ),
    ).thenAnswer((_) async => [dismissed]);

    final postDismissalStrategy = await creating(
      'The requested post-dismissal banner.',
    );
    await withClock(
      fixedClock,
      () => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-chat-1',
        threadId: 'thread-chat-1',
        strategy: postDismissalStrategy,
        derivation: derivation,
        now: now,
        replyToUser: true,
        userRequestedAd: true,
        adCreationDiscriminator: 'chat:message-1',
      ),
    );
    final afterDismissal = upserts.whereType<GoalNudgeEntity>().single;
    expect(afterDismissal.status, GoalNudgeStatus.active);
    expect(
      afterDismissal.brief.headline,
      'The requested post-dismissal banner.',
    );
    upserts.clear();

    const ratedBrief = GoalNudgeBrief(
      headline: 'Already rated.',
      tone: GoalNudgeTone.nudge,
      animation: GoalBannerAnimation.steady,
    );
    final ratedActive =
        AgentDomainEntity.goalNudge(
              id: 'ad-rated-active',
              agentId: agentId,
              status: GoalNudgeStatus.active,
              brief: ratedBrief,
              briefDigest: goalBriefDigest(ratedBrief),
              createdAt: now.subtract(const Duration(hours: 3)),
              updatedAt: now.subtract(const Duration(hours: 1)),
              vectorClock: null,
              activatedAt: now.subtract(const Duration(hours: 3)),
              ratings: [
                GoalNudgeRating(
                  activation: 1,
                  ratedAt: now.subtract(const Duration(hours: 1)),
                  rating: 4,
                ),
              ],
            )
            as GoalNudgeEntity;
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.goalNudge,
      ),
    ).thenAnswer((_) async => [ratedActive]);

    final postRatingStrategy = await creating('The replacement after rating.');
    await withClock(
      fixedClock,
      () => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-chat-2',
        threadId: 'thread-chat-2',
        strategy: postRatingStrategy,
        derivation: derivation,
        now: now,
        replyToUser: true,
        userRequestedAd: true,
        adCreationDiscriminator: 'chat:message-2',
      ),
    );

    final afterRating = upserts.whereType<GoalNudgeEntity>().toList();
    expect(afterRating, hasLength(2));
    final retired = afterRating.singleWhere(
      (nudge) => nudge.id == 'ad-rated-active',
    );
    expect(retired.status, GoalNudgeStatus.retired);
    expect(
      retired.provenance['retireReason'],
      'replaced by explicit chat request',
    );
    final replacement = afterRating.singleWhere(
      (nudge) => nudge.id != 'ad-rated-active',
    );
    expect(replacement.status, GoalNudgeStatus.active);
    expect(replacement.brief.headline, 'The replacement after rating.');

    upserts.clear();
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.goalNudge,
      ),
    ).thenAnswer((_) async => [ratedActive]);
    final duplicateStrategy = await creating('Already rated.');
    await withClock(
      fixedClock,
      () => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-chat-3',
        threadId: 'thread-chat-3',
        strategy: duplicateStrategy,
        derivation: derivation,
        now: now,
        replyToUser: true,
        userRequestedAd: true,
        adCreationDiscriminator: 'chat:message-3',
      ),
    );

    expect(
      upserts.whereType<GoalNudgeEntity>(),
      isEmpty,
      reason: 'a duplicate candidate must not retire the active banner',
    );

    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.goalNudge,
      ),
    ).thenAnswer((_) async => []);
    final recovering = GoalWakeDerivation(
      version: derivation.version,
      facts: GoalWakeFacts(
        trackStatus: GoalTrackStatus.recovering,
        previousStatus: GoalTrackStatus.atRisk,
        evaluation: derivation.facts.evaluation,
        shortTermAttainment: derivation.facts.shortTermAttainment,
      ),
      periodKey: derivation.periodKey,
      priors: derivation.priors,
      existingToday: derivation.existingToday,
    );
    final recoveryStrategy = await creating(
      'Recovery deserves a banner too.',
    );
    await withClock(
      fixedClock,
      () => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-chat-4',
        threadId: 'thread-chat-4',
        strategy: recoveryStrategy,
        derivation: recovering,
        now: now,
        replyToUser: true,
        userRequestedAd: true,
        adCreationDiscriminator: 'chat:message-4',
      ),
    );
    expect(upserts.whereType<GoalNudgeEntity>(), hasLength(1));
    expect(
      upserts.whereType<GoalNudgeEntity>().single.status,
      GoalNudgeStatus.active,
    );
  });

  test('persistOutputs: a fresh active row scopes to its own spec version — '
      'the matching version blocks a new banner, a foreign version does '
      'not', () async {
    stubSpec();
    _stubBadPrior(repository, agentId, now);
    final version =
        await repository.getEntity('$agentId:spec-v1')
            as GoalSpecVersionEntity?;
    final derivation = await _offTrackDerivation(repository, version!, now);

    GoalNudgeEntity freshRow(String id, String specVersionId) =>
        AgentDomainEntity.goalNudge(
              id: id,
              agentId: agentId,
              status: GoalNudgeStatus.active,
              brief: const GoalNudgeBrief(
                headline: 'h',
                tone: GoalNudgeTone.nudge,
                animation: GoalBannerAnimation.steady,
              ),
              briefDigest: 'd-$id',
              createdAt: now,
              updatedAt: now,
              activatedAt: now,
              vectorClock: null,
              provenance: {'specVersionId': specVersionId},
            )
            as GoalNudgeEntity;

    Future<GoalAgentStrategy> creating() async {
      final strategy = GoalAgentStrategy(
        syncService: syncService,
        agentId: agentId,
        threadId: 'thread-1',
        runKey: 'run-1',
        knownAdIds: const {},
      );
      await strategy.processToolCalls(
        toolCalls: [
          toolCall(GoalAgentToolNames.createGoalAd, {
            'headline': 'New copy.',
            'tone': 'nudge',
            'animation': 'steady',
          }, id: 'c1'),
        ],
        manager: conversationManager,
      );
      return strategy;
    }

    // A row provenanced to THIS wake's spec version is visible: it counts
    // as a fresh active and blocks the new create.
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.goalNudge,
      ),
    ).thenAnswer((_) async => [freshRow('ad-matching', version.id)]);
    final matchingStrategy = await creating();
    await withClock(
      fixedClock,
      () => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-1',
        threadId: 'thread-1',
        strategy: matchingStrategy,
        derivation: derivation,
        now: now,
      ),
    );
    expect(
      upserts.whereType<GoalNudgeEntity>(),
      isEmpty,
      reason: 'the same-version fresh active row blocks the new banner',
    );

    // A row provenanced to a DIFFERENT spec version is invisible: it
    // neither blocks the fresh-active guard nor sits in the reuse pool,
    // so the create proceeds.
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.goalNudge,
      ),
    ).thenAnswer(
      (_) async => [freshRow('ad-foreign', '$agentId:spec-v0')],
    );
    final foreignStrategy = await creating();
    await withClock(
      fixedClock,
      () => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-1',
        threadId: 'thread-1',
        strategy: foreignStrategy,
        derivation: derivation,
        now: now,
      ),
    );
    expect(
      upserts.whereType<GoalNudgeEntity>().where(
        (n) => n.id != 'ad-foreign',
      ),
      hasLength(1),
      reason:
          'a foreign-version row is invisible — it never counts as a '
          'fresh active, so a new banner for THIS version lands',
    );
  });

  test('persistOutputs: a superseded-spec wake suppresses rerun requests — '
      'a wake evaluating a historical version must not resurrect any '
      'ad', () async {
    stubSpec();
    _stubBadPrior(repository, agentId, now);
    final staleVersion =
        AgentDomainEntity.goalSpecVersion(
              id: '$agentId:spec-v0',
              agentId: agentId,
              version: 0,
              status: GoalSpecVersionStatus.superseded,
              authoredBy: 'user',
              title: 'Steps (original)',
              statement: 'x',
              criteria: const GoalCriterion.metric(
                criterionId: 'steps',
                dataType: 'cumulative_step_count',
                window: GoalWindow.rollingDays(count: 7),
                aggregation: GoalAggregation.dailySumThenAverage,
                target: 10000,
              ),
              createdAt: DateTime(2026, 7),
              vectorClock: null,
            )
            as GoalSpecVersionEntity;
    final derivation = await _offTrackDerivation(repository, staleVersion, now);

    final strategy = GoalAgentStrategy(
      syncService: syncService,
      agentId: agentId,
      threadId: 'thread-1',
      runKey: 'run-1',
      knownAdIds: const {'ad-retired'},
    );
    await strategy.processToolCalls(
      toolCalls: [
        toolCall(GoalAgentToolNames.rerunGoalAd, {
          'adId': 'ad-retired',
          'reason': 'bring it back',
        }, id: 'c1'),
      ],
      manager: conversationManager,
    );

    await withClock(
      fixedClock,
      () => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-1',
        threadId: 'thread-1',
        strategy: strategy,
        derivation: derivation,
        now: now,
      ),
    );

    expect(
      upserts.whereType<GoalNudgeEntity>(),
      isEmpty,
      reason:
          'a superseded-spec wake must not reactivate any ad, even one it '
          'names directly',
    );
  });

  test('persistOutputs: a superseded-spec wake suppresses revision '
      'proposals — approving one would distort the newer goal', () async {
    stubSpec();
    _stubBadPrior(repository, agentId, now);
    final staleVersion =
        AgentDomainEntity.goalSpecVersion(
              id: '$agentId:spec-v0',
              agentId: agentId,
              version: 0,
              status: GoalSpecVersionStatus.superseded,
              authoredBy: 'user',
              title: 'Steps (original)',
              statement: 'x',
              criteria: const GoalCriterion.metric(
                criterionId: 'steps',
                dataType: 'cumulative_step_count',
                window: GoalWindow.rollingDays(count: 7),
                aggregation: GoalAggregation.dailySumThenAverage,
                target: 10000,
              ),
              createdAt: DateTime(2026, 7),
              vectorClock: null,
            )
            as GoalSpecVersionEntity;
    final derivation = await _offTrackDerivation(repository, staleVersion, now);

    final strategy = GoalAgentStrategy(
      syncService: syncService,
      agentId: agentId,
      threadId: 'thread-1',
      runKey: 'run-1',
      knownAdIds: const {},
    );
    await strategy.processToolCalls(
      toolCalls: [
        toolCall(GoalAgentToolNames.proposeGoalRevision, {
          'changes': {'targetValue': 8000},
          'rationale': 'the old target no longer fits',
        }, id: 'c1'),
      ],
      manager: conversationManager,
    );

    await withClock(
      fixedClock,
      () => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-1',
        threadId: 'thread-1',
        strategy: strategy,
        derivation: derivation,
        now: now,
      ),
    );

    expect(
      upserts.whereType<ChangeSetEntity>(),
      isEmpty,
      reason:
          'a superseded-spec wake must never mint a ChangeSet against the '
          'revised goal',
    );
  });

  test('persistOutputs: the SAME transition recurring within one day skips '
      'a second create for that deterministic id — the earlier row is '
      'left untouched', () async {
    stubSpec();
    _stubBadPrior(repository, agentId, now);
    final version =
        await repository.getEntity('$agentId:spec-v1')
            as GoalSpecVersionEntity?;
    final derivation = await _offTrackDerivation(repository, version!, now);

    Future<GoalAgentStrategy> creating(String headline) async {
      final strategy = GoalAgentStrategy(
        syncService: syncService,
        agentId: agentId,
        threadId: 'thread-1',
        runKey: 'run-1',
        knownAdIds: const {},
      );
      await strategy.processToolCalls(
        toolCalls: [
          toolCall(GoalAgentToolNames.createGoalAd, {
            'headline': headline,
            'tone': 'nudge',
            'animation': 'steady',
          }, id: 'c1'),
        ],
        manager: conversationManager,
      );
      return strategy;
    }

    // First wake: nothing exists yet, so the create lands and its
    // deterministic id is captured for the second wake below.
    final firstStrategy = await creating('First transition banner.');
    await withClock(
      fixedClock,
      () => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-1',
        threadId: 'thread-1',
        strategy: firstStrategy,
        derivation: derivation,
        now: now,
      ),
    );
    final created = upserts.whereType<GoalNudgeEntity>().single;
    upserts.clear();

    // Second wake: the SAME transition recurs (identical period, baseline
    // and spec version), so the deterministic id collides with the
    // earlier row — which is retired, so it does not trip the
    // fresh-active guard first, and the new brief's digest differs, so
    // it does not trip the digest guard first either.
    final priorRow = created.copyWith(
      status: GoalNudgeStatus.retired,
      retiredAt: now.subtract(const Duration(hours: 1)),
    );
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.goalNudge,
      ),
    ).thenAnswer((_) async => [priorRow]);

    final secondStrategy = await creating(
      'Second transition banner, same day.',
    );
    await withClock(
      fixedClock,
      () => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-1',
        threadId: 'thread-1',
        strategy: secondStrategy,
        derivation: derivation,
        now: now,
      ),
    );

    expect(
      upserts.whereType<GoalNudgeEntity>(),
      isEmpty,
      reason:
          "the recurring transition's deterministic id already exists — "
          "no second banner is minted and the earlier row's state is "
          'left alone',
    );
  });

  test('with consumption registered, a failed wake is terminalized as '
      'FAILED — no perpetually open session on the exception path', () async {
    final attribution = MockAiAttributionService();
    getIt
      ..registerSingleton<AiInteractionCapture>(MockAiInteractionCapture())
      ..registerSingleton<AiAttributionService>(attribution);
    addTearDown(getIt.reset);
    final closed = AiWorkAttribution(
      id: 'attr-failed',
      workType: AiWorkType.agentReport,
      status: AiWorkStatus.failed,
      initiator: const AiActorSnapshot(
        type: AiActorType.agent,
        id: agentId,
        displayName: 'Steps goal',
      ),
      trigger: const AiTriggerSnapshot(type: AiTriggerType.automatic),
      startedAt: now,
      completedAt: now,
      vectorClock: null,
    );
    when(
      () => attribution.prepareCompletion(
        attributionId: any(named: 'attributionId'),
        outputs: any(named: 'outputs'),
        status: any(named: 'status'),
        errorCode: any(named: 'errorCode'),
        errorSummary: any(named: 'errorSummary'),
      ),
    ).thenAnswer((_) async => closed);
    when(() => attribution.finalize(any())).thenAnswer((_) async {});

    stubSpec();
    stubGlmResolution();
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0.7,
          strategy,
        }) async {
          throw StateError('provider melted');
        };

    final result = await run();
    expect(result.success, isFalse);
    verify(
      () => attribution.prepareCompletion(
        attributionId: any(named: 'attributionId'),
        outputs: any(named: 'outputs'),
        status: AiWorkStatus.failed,
        errorCode: 'StateError',
        errorSummary: any(named: 'errorSummary'),
      ),
    ).called(1);
  });

  test('a finalize failure is contained — the persisted wake still '
      'succeeds and the session is left for recovery', () async {
    final attribution = MockAiAttributionService();
    getIt
      ..registerSingleton<AiInteractionCapture>(MockAiInteractionCapture())
      ..registerSingleton<AiAttributionService>(attribution);
    addTearDown(getIt.reset);
    final envelope = AiWorkAttribution(
      id: 'attr-2',
      workType: AiWorkType.agentReport,
      status: AiWorkStatus.succeeded,
      initiator: const AiActorSnapshot(
        type: AiActorType.agent,
        id: agentId,
        displayName: 'Steps goal',
      ),
      trigger: const AiTriggerSnapshot(type: AiTriggerType.automatic),
      startedAt: now,
      completedAt: now,
      vectorClock: null,
    );
    when(
      () => attribution.prepareCompletion(
        attributionId: any(named: 'attributionId'),
        outputs: any(named: 'outputs'),
      ),
    ).thenAnswer((_) async => envelope);
    when(() => attribution.finalize(any())).thenThrow(StateError('db busy'));

    stubSpec();
    stubGlmResolution();
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0.7,
          strategy,
        }) async {
          await (strategy! as GoalAgentStrategy).processToolCalls(
            toolCalls: [
              toolCall(GoalAgentToolNames.updateGoalReport, {
                'status': 'insufficientData',
                'oneLiner': 'No data.',
                'tldr': 'Quiet tracker.',
              }),
            ],
            manager: conversationManager,
          );
          return null;
        };

    final result = await run();
    expect(result.success, isTrue);
    expect(upserts.whereType<AgentReportEntity>(), hasLength(1));
  });

  test("yesterday's register row feeds the FACTS baseline", () async {
    stubSpec();
    stubGlmResolution();
    when(
      () => repository.getEntity(goalProgressId(agentId, '2026-08-08')),
    ).thenAnswer(
      (_) async => AgentDomainEntity.goalProgress(
        id: goalProgressId(agentId, '2026-08-08'),
        agentId: agentId,
        periodKey: '2026-08-08',
        trackStatus: GoalTrackStatus.onTrack,
        attainment: 1,
        dataCoverage: 1,
        satisfied: true,
        specVersionId: '$agentId:spec-v1',
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
      ),
    );
    String? factsSeen;
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0.7,
          strategy,
        }) async {
          factsSeen = message;
          await (strategy! as GoalAgentStrategy).processToolCalls(
            toolCalls: [
              toolCall(GoalAgentToolNames.updateGoalReport, {
                'status': 'insufficientData',
                'oneLiner': 'No data.',
                'tldr': 'Quiet tracker.',
              }),
            ],
            manager: conversationManager,
          );
          return null;
        };

    final result = await run();
    expect(result.success, isTrue);
    expect(factsSeen, contains('"lastReportStatus": "onTrack"'));
  });

  test('the baseline token wins over the prior-day fallback — a same-day '
      'second transition back to the old status still reports', () async {
    stubSpec();
    stubGlmResolution();
    // Yesterday: onTrack. This morning: transitioned to offTrack (reported).
    // Now: back to insufficientData... derived status differs from the
    // token baseline, so the change must surface even though the naive
    // prior-day baseline would also differ here; the discriminating
    // assertion is lastReportStatus = the TOKEN's status, not yesterday's.
    when(
      () => repository.getEntity(goalProgressId(agentId, '2026-08-08')),
    ).thenAnswer(
      (_) async => AgentDomainEntity.goalProgress(
        id: goalProgressId(agentId, '2026-08-08'),
        agentId: agentId,
        periodKey: '2026-08-08',
        trackStatus: GoalTrackStatus.onTrack,
        attainment: 1,
        dataCoverage: 1,
        satisfied: true,
        specVersionId: '$agentId:spec-v1',
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
      ),
    );
    String? factsSeen;
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0.7,
          strategy,
        }) async {
          factsSeen = message;
          await (strategy! as GoalAgentStrategy).processToolCalls(
            toolCalls: [
              toolCall(GoalAgentToolNames.updateGoalReport, {
                'status': 'insufficientData',
                'oneLiner': 'No data.',
                'tldr': 'Quiet tracker.',
              }),
            ],
            manager: conversationManager,
          );
          return null;
        };

    final result = await withClock(
      fixedClock,
      () => workflow.execute(
        agentIdentity: identity,
        runKey: 'run-1',
        triggerTokens: const {
          'goal-escalation:2026-08-09',
          'goal-baseline:offTrack',
        },
        threadId: 'thread-1',
      ),
    );
    expect(result.success, isTrue);
    expect(factsSeen, contains('"lastReportStatus": "offTrack"'));
  });

  test('an older period cannot replace a newer standing report head', () async {
    final strategy = GoalAgentStrategy(
      syncService: syncService,
      agentId: agentId,
      threadId: 'thread-1',
      runKey: 'run-1',
      knownAdIds: const {},
    );
    await strategy.processToolCalls(
      toolCalls: [
        toolCall(GoalAgentToolNames.updateGoalReport, {
          'status': 'insufficientData',
          'oneLiner': 'Old news.',
          'tldr': 'From an overdue period.',
        }),
      ],
      manager: conversationManager,
    );
    // The published report belongs to a NEWER period.
    when(
      () => repository.getLatestReport(agentId, AgentReportScopes.current),
    ).thenAnswer(
      (_) async =>
          AgentDomainEntity.agentReport(
                id: 'report-new',
                agentId: agentId,
                scope: AgentReportScopes.current,
                createdAt: now,
                vectorClock: null,
                content: 'current standing',
                provenance: const <String, Object?>{'periodKey': '2026-08-09'},
              )
              as AgentReportEntity,
    );
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.goalNudge,
      ),
    ).thenAnswer((_) async => []);

    stubSpec();
    final version =
        await repository.getEntity('$agentId:spec-v1')
            as GoalSpecVersionEntity?;
    final oldDerivation =
        await GoalAgentPhaseA(
          repository: repository,
          syncService: MockAgentSyncService(),
          signalReader: _FakeReader(),
        ).deriveWakeFacts(
          agentId: agentId,
          version: version!,
          now: DateTime(2026, 8, 6, 23),
        );
    await withClock(
      fixedClock,
      () => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-1',
        threadId: 'thread-1',
        strategy: strategy,
        derivation: oldDerivation,
        now: now,
      ),
    );
    // The report row itself lands (history), but the head stays put.
    expect(upserts.whereType<AgentReportEntity>(), hasLength(1));
    expect(upserts.whereType<AgentReportHeadEntity>(), isEmpty);
  });

  test('a fresh active ad blocks a second create, but the retire+create '
      'swap stays legal', () async {
    GoalNudgeEntity activeRow(String id) =>
        AgentDomainEntity.goalNudge(
              id: id,
              agentId: agentId,
              status: GoalNudgeStatus.active,
              brief: const GoalNudgeBrief(
                headline: 'live',
                tone: GoalNudgeTone.nudge,
                animation: GoalBannerAnimation.steady,
              ),
              briefDigest: 'd-$id',
              createdAt: DateTime(2026, 8),
              updatedAt: DateTime(2026, 8),
              vectorClock: null,
              activatedAt: now.subtract(const Duration(hours: 2)),
            )
            as GoalNudgeEntity;
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.goalNudge,
      ),
    ).thenAnswer((_) async => [activeRow('ad-live')]);
    when(
      () => repository.getEntity('ad-live'),
    ).thenAnswer((_) async => activeRow('ad-live'));

    stubSpec();
    _stubBadPrior(repository, agentId, now);
    final version =
        await repository.getEntity('$agentId:spec-v1')
            as GoalSpecVersionEntity?;
    final derivation = await _offTrackDerivation(repository, version!, now);

    Future<GoalAgentStrategy> strategyWith(
      List<ChatCompletionMessageToolCall> calls,
    ) async {
      final strategy = GoalAgentStrategy(
        syncService: syncService,
        agentId: agentId,
        threadId: 'thread-1',
        runKey: 'run-1',
        knownAdIds: const {'ad-live'},
      );
      await strategy.processToolCalls(
        toolCalls: calls,
        manager: conversationManager,
      );
      return strategy;
    }

    // Second ad while one is fresh and active: suppressed.
    await withClock(
      fixedClock,
      () async => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-1',
        threadId: 'thread-1',
        strategy: await strategyWith([
          toolCall(GoalAgentToolNames.createGoalAd, {
            'headline': 'A second banner.',
            'tone': 'nudge',
            'animation': 'pulse',
          }),
        ]),
        derivation: derivation,
        now: now,
      ),
    );
    expect(upserts.whereType<GoalNudgeEntity>(), isEmpty);

    // Retire + create in one wake: the swap is the P14 pattern and legal.
    await withClock(
      fixedClock,
      () async => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-1',
        threadId: 'thread-1',
        strategy: await strategyWith([
          toolCall(GoalAgentToolNames.retireGoalAd, {
            'adId': 'ad-live',
            'reason': 'dimension satisfied',
          }, id: 'c1'),
          toolCall(GoalAgentToolNames.createGoalAd, {
            'headline': 'Sell the failing criterion.',
            'tone': 'nudge',
            'animation': 'pulse',
          }, id: 'c2'),
        ]),
        derivation: derivation,
        now: now,
      ),
    );
    final written = upserts.whereType<GoalNudgeEntity>().toList();
    expect(written, hasLength(2));
    expect(
      written.singleWhere((n) => n.id == 'ad-live').status,
      GoalNudgeStatus.retired,
    );
    expect(
      written.singleWhere((n) => n.id != 'ad-live').status,
      GoalNudgeStatus.active,
    );
  });

  test('a failed wake re-arms its escalation with a later deadline so the '
      'period is retried', () async {
    stubSpec();
    stubGlmResolution();
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0.7,
          strategy,
        }) async {
          throw StateError('provider melted');
        };
    final result = await run();
    expect(result.success, isFalse);
    final rearmed = upserts.whereType<ScheduledWakeEntity>().singleWhere(
      (w) => isGoalEscalationWorkspace(w.workspaceKey),
    );
    expect(rearmed.status, ScheduledWakeStatus.pending);
    expect(rearmed.scheduledAt, now.toUtc());
    expect(rearmed.triggerTokens, contains('goal-escalation:2026-08-09'));
  });

  test('offTrack with no fresh ad and no cooldown forces exactly one ad '
      'retry restricted to the ad tools', () async {
    stubSpec();
    stubGlmResolution();
    // Bad week + a bad prior register row → grace exhausted → offTrack.
    workflow = _offTrackWorkflow(
      repository,
      syncService,
      conversationRepository,
      cloudInferenceRepository,
      aiConfigRepository,
    );
    _stubBadPrior(repository, agentId, now);

    conversationRepository.maxDelegateCalls = 3;
    final callTools = <List<String>>[];
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0.7,
          strategy,
        }) async {
          callTools.add([for (final t in tools!) t.function.name]);
          if (callTools.length == 2) {
            expect(
              message,
              contains('The goal is offTrack'),
              reason: 'the forced-ad prompt names the ACTUAL status',
            );
          }
          if (callTools.length == 1) {
            // The model reports but "forgets" the required ad.
            await (strategy! as GoalAgentStrategy).processToolCalls(
              toolCalls: [
                toolCall(GoalAgentToolNames.updateGoalReport, {
                  'status': 'offTrack',
                  'oneLiner': 'Averaging 6k of 10k.',
                  'tldr': 'The week slid under target.',
                }),
              ],
              manager: conversationManager,
            );
          } else {
            await (strategy! as GoalAgentStrategy).processToolCalls(
              toolCalls: [
                toolCall(GoalAgentToolNames.createGoalAd, {
                  'headline': 'Your inner couch potato is winning.',
                  'tone': 'nudge',
                  'animation': 'pulse',
                }),
              ],
              manager: conversationManager,
            );
          }
          return const InferenceUsage(inputTokens: 500, outputTokens: 50);
        };

    final result = await run();
    expect(result.success, isTrue);
    expect(callTools, hasLength(2), reason: 'primary + one forced ad retry');
    expect(
      callTools.last.toSet(),
      {GoalAgentToolNames.createGoalAd, GoalAgentToolNames.rerunGoalAd},
      reason: 'the retry restricts the surface to the ad tools',
    );
    expect(upserts.whereType<GoalNudgeEntity>(), hasLength(1));
    final usage = upserts.whereType<WakeTokenUsageEntity>().single;
    expect(usage.inputTokens, 1000, reason: 'primary + ad-retry merged');
  });

  test(
    'a new at-risk goal gets its first banner without waiting for a trend',
    () async {
      stubSpec();
      stubGlmResolution();
      workflow = _offTrackWorkflow(
        repository,
        syncService,
        conversationRepository,
        cloudInferenceRepository,
        aiConfigRepository,
      );
      conversationRepository.maxDelegateCalls = 3;
      var calls = 0;
      conversationRepository.sendMessageDelegate =
          ({
            required conversationId,
            required message,
            required model,
            required provider,
            required inferenceRepo,
            tools,
            toolChoice,
            temperature = 0.7,
            strategy,
          }) async {
            calls++;
            if (calls == 1) {
              await (strategy! as GoalAgentStrategy).processToolCalls(
                toolCalls: [
                  toolCall(GoalAgentToolNames.updateGoalReport, {
                    'status': 'atRisk',
                    'oneLiner': 'The first window starts behind.',
                    'tldr': 'Two walks will recover the window.',
                  }),
                ],
                manager: conversationManager,
              );
            } else {
              await (strategy! as GoalAgentStrategy).processToolCalls(
                toolCalls: [
                  toolCall(GoalAgentToolNames.createGoalAd, {
                    'headline': 'Your trainers are waiting.',
                    'tone': 'nudge',
                    'animation': 'pulse',
                  }),
                ],
                manager: conversationManager,
              );
            }
            return null;
          };

      final result = await run(triggerTokens: const {});

      expect(result.success, isTrue);
      expect(calls, 2, reason: 'primary evaluation + required first banner');
      expect(upserts.whereType<GoalNudgeEntity>(), hasLength(1));
    },
  );

  test('a fresh active ad satisfies the P5 requirement — no forced ad '
      'retry fires', () async {
    stubSpec();
    stubGlmResolution();
    workflow = _offTrackWorkflow(
      repository,
      syncService,
      conversationRepository,
      cloudInferenceRepository,
      aiConfigRepository,
    );
    _stubBadPrior(repository, agentId, now);
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.goalNudge,
      ),
    ).thenAnswer(
      (_) async => [
        AgentDomainEntity.goalNudge(
              id: 'ad-live',
              agentId: agentId,
              status: GoalNudgeStatus.active,
              brief: const GoalNudgeBrief(
                headline: 'live',
                tone: GoalNudgeTone.nudge,
                animation: GoalBannerAnimation.steady,
              ),
              briefDigest: 'd-live',
              createdAt: DateTime(2026, 8),
              updatedAt: DateTime(2026, 8),
              vectorClock: null,
              activatedAt: now.subtract(const Duration(hours: 2)),
            )
            as GoalNudgeEntity,
      ],
    );
    var calls = 0;
    conversationRepository
      ..maxDelegateCalls = 3
      ..sendMessageDelegate =
          ({
            required conversationId,
            required message,
            required model,
            required provider,
            required inferenceRepo,
            tools,
            toolChoice,
            temperature = 0.7,
            strategy,
          }) async {
            calls++;
            await (strategy! as GoalAgentStrategy).processToolCalls(
              toolCalls: [
                toolCall(GoalAgentToolNames.updateGoalReport, {
                  'status': 'offTrack',
                  'oneLiner': 'Averaging 6k of 10k.',
                  'tldr': 'The week slid under target.',
                }),
              ],
              manager: conversationManager,
            );
            return null;
          };
    final result = await run();
    expect(result.success, isTrue);
    expect(calls, 1, reason: 'the fresh active ad already satisfies P5');
  });

  test('a throwing forced-ad retry is contained — the wake still '
      'persists its report', () async {
    stubSpec();
    stubGlmResolution();
    workflow = _offTrackWorkflow(
      repository,
      syncService,
      conversationRepository,
      cloudInferenceRepository,
      aiConfigRepository,
    );
    _stubBadPrior(repository, agentId, now);
    var calls = 0;
    conversationRepository
      ..maxDelegateCalls = 3
      ..sendMessageDelegate =
          ({
            required conversationId,
            required message,
            required model,
            required provider,
            required inferenceRepo,
            tools,
            toolChoice,
            temperature = 0.7,
            strategy,
          }) async {
            calls++;
            if (calls == 2) throw StateError('retry melted');
            await (strategy! as GoalAgentStrategy).processToolCalls(
              toolCalls: [
                toolCall(GoalAgentToolNames.updateGoalReport, {
                  'status': 'offTrack',
                  'oneLiner': 'Averaging 6k of 10k.',
                  'tldr': 'The week slid under target.',
                }),
              ],
              manager: conversationManager,
            );
            return null;
          };
    final result = await run();
    expect(result.success, isTrue);
    expect(calls, 2);
    expect(upserts.whereType<AgentReportEntity>(), hasLength(1));
  });

  test('a failing escalation re-arm is itself contained', () async {
    stubSpec();
    stubGlmResolution();
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.first as AgentDomainEntity;
      if (entity is ScheduledWakeEntity) throw StateError('db locked');
      upserts.add(entity);
    });
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0.7,
          strategy,
        }) async {
          throw StateError('provider melted');
        };
    final result = await run();
    expect(result.success, isFalse);
    expect(result.error, contains('provider melted'));
  });

  test('persistOutputs: an ineligible status suppresses ads, an atRisk '
      'worsening trend permits them, and banner copy is sanitized', () async {
    stubSpec();
    final version =
        await repository.getEntity('$agentId:spec-v1')
            as GoalSpecVersionEntity?;
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.goalNudge,
      ),
    ).thenAnswer((_) async => []);

    Future<GoalAgentStrategy> creatingWithTagline(
      String headline, [
      String? tagline,
    ]) async {
      final strategy = GoalAgentStrategy(
        syncService: syncService,
        agentId: agentId,
        threadId: 'thread-1',
        runKey: 'run-1',
        knownAdIds: const {},
      );
      await strategy.processToolCalls(
        toolCalls: [
          toolCall(GoalAgentToolNames.createGoalAd, {
            'headline': headline,
            'tagline': ?tagline,
            'tone': 'nudge',
            'animation': 'pulse',
          }),
        ],
        manager: conversationManager,
      );
      return strategy;
    }

    Future<GoalAgentStrategy> creating(String headline) =>
        creatingWithTagline(headline);

    // insufficientData (default fake reader): the model's ad is refused —
    // and a rerun of a retired library ad is refused the same way.
    final retiredLibraryAd =
        AgentDomainEntity.goalNudge(
              id: 'ad-lib',
              agentId: agentId,
              status: GoalNudgeStatus.retired,
              brief: const GoalNudgeBrief(
                headline: 'old',
                tone: GoalNudgeTone.nudge,
                animation: GoalBannerAnimation.steady,
              ),
              briefDigest: 'd-lib',
              createdAt: DateTime(2026, 8),
              updatedAt: DateTime(2026, 8),
              vectorClock: null,
            )
            as GoalNudgeEntity;
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.goalNudge,
      ),
    ).thenAnswer((_) async => [retiredLibraryAd]);
    final rerunning = GoalAgentStrategy(
      syncService: syncService,
      agentId: agentId,
      threadId: 'thread-1',
      runKey: 'run-1',
      knownAdIds: const {'ad-lib'},
    );
    await rerunning.processToolCalls(
      toolCalls: [
        toolCall(GoalAgentToolNames.rerunGoalAd, {
          'adId': 'ad-lib',
          'reason': 'bring it back',
        }),
      ],
      manager: conversationManager,
    );
    await withClock(
      fixedClock,
      () async => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-1',
        threadId: 'thread-1',
        strategy: rerunning,
        derivation: await GoalAgentPhaseA(
          repository: repository,
          syncService: MockAgentSyncService(),
          signalReader: _FakeReader(),
        ).deriveWakeFacts(agentId: agentId, version: version!, now: now),
        now: now,
      ),
    );
    expect(upserts.whereType<GoalNudgeEntity>(), isEmpty);
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.goalNudge,
      ),
    ).thenAnswer((_) async => []);

    // insufficientData (default fake reader): the model's ad is refused.
    await withClock(
      fixedClock,
      () async => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-1',
        threadId: 'thread-1',
        strategy: await creating('No data, but here is a banner anyway.'),
        derivation: await GoalAgentPhaseA(
          repository: repository,
          syncService: MockAgentSyncService(),
          signalReader: _FakeReader(),
        ).deriveWakeFacts(agentId: agentId, version: version!, now: now),
        now: now,
      ),
    );
    expect(upserts.whereType<GoalNudgeEntity>(), isEmpty);

    // At risk without a three-day decline is ineligible for an automatic ad,
    // but the same structured create action is honored when it comes from an
    // interactive turn: the user explicitly asked for the banner.
    final firstAtRisk = await _offTrackDerivation(repository, version!, now);
    final steadyAtRisk = GoalWakeDerivation(
      version: firstAtRisk.version,
      facts: firstAtRisk.facts,
      periodKey: firstAtRisk.periodKey,
      priors: [
        AgentDomainEntity.goalProgress(
              id: goalProgressId(agentId, '2026-08-08'),
              agentId: agentId,
              periodKey: '2026-08-08',
              trackStatus: GoalTrackStatus.atRisk,
              attainment: firstAtRisk.facts.evaluation.attainment,
              dataCoverage: 1,
              satisfied: false,
              specVersionId: version.id,
              createdAt: now.subtract(const Duration(days: 1)),
              updatedAt: now.subtract(const Duration(days: 1)),
              vectorClock: null,
            )
            as GoalProgressEntity,
      ],
      existingToday: firstAtRisk.existingToday,
    );
    expect(steadyAtRisk.facts.trackStatus, GoalTrackStatus.atRisk);
    await withClock(
      fixedClock,
      () async => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-1',
        threadId: 'thread-1',
        strategy: await creating('Automatic at-risk banner.'),
        derivation: steadyAtRisk,
        now: now,
      ),
    );
    expect(upserts.whereType<GoalNudgeEntity>(), isEmpty);

    await withClock(
      fixedClock,
      () async => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-chat',
        threadId: 'thread-chat',
        strategy: await creating('One more walk. Make it count.'),
        derivation: steadyAtRisk,
        now: now,
        replyToUser: true,
        userRequestedAd: true,
        adCreationDiscriminator: 'chat:message-1',
      ),
    );
    final requested = upserts.whereType<GoalNudgeEntity>().single;
    expect(requested.status, GoalNudgeStatus.active);
    expect(requested.brief.headline, 'One more walk. Make it count.');
    upserts.clear();

    // atRisk with a strictly worsening trend (good prior days, bad today):
    // eligible — and the persisted copy is sanitized.
    for (final (period, attainment) in [
      ('2026-08-08', 0.85),
      ('2026-08-07', 0.9),
    ]) {
      when(
        () => repository.getEntity(goalProgressId(agentId, period)),
      ).thenAnswer(
        (_) async => AgentDomainEntity.goalProgress(
          id: goalProgressId(agentId, period),
          agentId: agentId,
          periodKey: period,
          trackStatus: GoalTrackStatus.onTrack,
          attainment: attainment,
          dataCoverage: 1,
          satisfied: true,
          specVersionId: '$agentId:spec-v1',
          createdAt: now,
          updatedAt: now,
          vectorClock: null,
        ),
      );
    }
    final atRisk = await _offTrackDerivation(repository, version, now);
    expect(atRisk.facts.trackStatus, GoalTrackStatus.atRisk);
    await withClock(
      fixedClock,
      () async => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-1',
        threadId: 'thread-1',
        strategy: await creatingWithTagline(
          'Lace up (id: 123e4567-e89b-12d3-a456-426614174000)',
          'Six quiet days (123e4567-e89b-12d3-a456-426614174000)',
        ),
        derivation: atRisk,
        now: now,
      ),
    );
    final nudge = upserts.whereType<GoalNudgeEntity>().single;
    expect(nudge.brief.headline, 'Lace up');
    expect(nudge.brief.tagline, 'Six quiet days');
    expect(nudge.briefDigest, goalBriefDigest(nudge.brief));
  });

  test('an unresolvable provider re-arms the escalation — configuring it '
      'later must retry the period', () async {
    stubSpec();
    when(
      () => aiConfigRepository.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => []);
    final result = await run();
    expect(result.success, isFalse);
    final rearmed = upserts.whereType<ScheduledWakeEntity>().singleWhere(
      (w) => isGoalEscalationWorkspace(w.workspaceKey),
    );
    expect(rearmed.status, ScheduledWakeStatus.pending);
  });

  test('a bookkeeping failure after committed outputs neither fails the '
      'wake nor re-arms the escalation', () async {
    stubSpec();
    stubGlmResolution();
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.first as AgentDomainEntity;
      if (entity is WakeTokenUsageEntity) throw StateError('outbox rejected');
      upserts.add(entity);
    });
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0.7,
          strategy,
        }) async {
          await (strategy! as GoalAgentStrategy).processToolCalls(
            toolCalls: [
              toolCall(GoalAgentToolNames.updateGoalReport, {
                'status': 'insufficientData',
                'oneLiner': 'No data.',
                'tldr': 'Quiet tracker.',
              }),
            ],
            manager: conversationManager,
          );
          return const InferenceUsage(inputTokens: 100, outputTokens: 10);
        };
    final result = await run();
    expect(
      result.success,
      isTrue,
      reason:
          'outputs committed — bookkeeping '
          'must not fail the wake',
    );
    expect(upserts.whereType<AgentReportEntity>(), hasLength(1));
    expect(
      upserts.whereType<ScheduledWakeEntity>().where(
        (w) => isGoalEscalationWorkspace(w.workspaceKey),
      ),
      isEmpty,
      reason: 'no re-arm: the wake must not be re-billed',
    );
  });

  test('an overdue period stamps the head with the PERIOD end, so '
      'cross-device LWW orders concurrent heads by period', () async {
    final strategy = GoalAgentStrategy(
      syncService: syncService,
      agentId: agentId,
      threadId: 'thread-1',
      runKey: 'run-1',
      knownAdIds: const {},
    );
    await strategy.processToolCalls(
      toolCalls: [
        toolCall(GoalAgentToolNames.updateGoalReport, {
          'status': 'insufficientData',
          'oneLiner': 'Old period.',
          'tldr': 'Overdue evaluation.',
        }),
      ],
      manager: conversationManager,
    );
    when(
      () => repository.getEntitiesByAgentId(
        agentId,
        type: AgentEntityTypes.goalNudge,
      ),
    ).thenAnswer((_) async => []);
    stubSpec();
    final version =
        await repository.getEntity('$agentId:spec-v1')
            as GoalSpecVersionEntity?;
    final oldDerivation =
        await GoalAgentPhaseA(
          repository: repository,
          syncService: MockAgentSyncService(),
          signalReader: _FakeReader(),
        ).deriveWakeFacts(
          agentId: agentId,
          version: version!,
          now: DateTime(2026, 8, 6, 23),
        );
    await withClock(
      fixedClock,
      () => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-1',
        threadId: 'thread-1',
        strategy: strategy,
        derivation: oldDerivation,
        now: now,
      ),
    );
    final head = upserts.whereType<AgentReportHeadEntity>().single;
    expect(
      head.updatedAt,
      DateTime.utc(2026, 8, 6, 23, 59, 59),
      reason: 'UTC, so period order is timezone-independent across devices',
    );
  });
}
