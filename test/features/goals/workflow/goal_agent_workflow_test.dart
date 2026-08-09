import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_criterion.dart';
import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
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
  _FakeReader() : super(journalDb: MockJournalDb());

  @override
  Future<GoalSignalWindow> read({
    required GoalCriterion criteria,
    required DateTime reference,
    int shortTermDays = 3,
  }) async => const GoalSignalWindow();
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

  Future<WakeResult> run({AgentIdentityEntity? identityOverride}) => withClock(
    fixedClock,
    () => workflow.execute(
      agentIdentity: identityOverride ?? identity,
      runKey: 'run-1',
      triggerTokens: const {'goal-escalation:2026-08-09'},
      threadId: 'thread-1',
    ),
  );

  test('a goal without a spec head is a clean no-op — no inference', () async {
    final result = await run();
    expect(result.success, isTrue);
    expect(conversationRepository.sendMessageDelegateCallCount, 0);
    expect(upserts, isEmpty);
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

  test('a full wake persists FACTS, report + head, the new ad, and token '
      'usage — all attributed to glm-5.2', () async {
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
          expect(model, 'glm-5.2');
          expect(provider.id, 'melious-provider');
          expect(temperature, 0);
          expect(message, startsWith('FACTS (deterministic'));
          expect(tools, hasLength(goalAgentTools.length));
          await (strategy! as GoalAgentStrategy).processToolCalls(
            toolCalls: [
              toolCall(GoalAgentToolNames.updateGoalReport, {
                'status': 'insufficientData',
                'oneLiner': 'No step data this window.',
                'tldr': 'The tracker went quiet; nothing to judge yet.',
              }, id: 'call-a'),
              toolCall(GoalAgentToolNames.createGoalAd, {
                'headline': 'Your pedometer misses you.',
                'tone': 'encourage',
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

    final userMessages = upserts.whereType<AgentMessageEntity>().where(
      (m) => m.kind == AgentMessageKind.user,
    );
    expect(userMessages, hasLength(1), reason: 'the FACTS blob is inspectable');

    final report = upserts.whereType<AgentReportEntity>().single;
    expect(report.tldr, 'The tracker went quiet; nothing to judge yet.');
    expect(report.provenance['trackStatus'], 'insufficientData');
    final head = upserts.whereType<AgentReportHeadEntity>().single;
    expect(head.reportId, report.id);

    final nudge = upserts.whereType<GoalNudgeEntity>().single;
    expect(nudge.status, GoalNudgeStatus.active);
    expect(nudge.brief.headline, 'Your pedometer misses you.');
    expect(nudge.brief.accent, GoalBannerAccent.tide);
    expect(nudge.briefDigest, goalBriefDigest(nudge.brief));
    expect(nudge.staleAt, now.add(goalAdLifetime));
    expect(nudge.runKey, 'run-1');
    expect(nudge.triggerProgressId, goalProgressId(agentId, '2026-08-09'));

    final usage = upserts.whereType<WakeTokenUsageEntity>().single;
    expect(usage.modelId, 'glm-5.2');
    expect(usage.inputTokens, 900);
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

  test('persistOutputs: retire is dismissal-terminal-safe, rerun requires a '
      'retired ad and increments the activation count, and a revision '
      'proposal lands as a pending ChangeSet', () async {
    GoalNudgeEntity nudgeRow(String id, GoalNudgeStatus status) =>
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
              vectorClock: null,
            )
            as GoalNudgeEntity;

    final strategy = GoalAgentStrategy(
      syncService: syncService,
      agentId: agentId,
      threadId: 'thread-1',
      runKey: 'run-1',
      knownAdIds: {'ad-dismissed', 'ad-retired', 'ad-active', 'ad-gone'},
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
      ],
      manager: conversationManager,
    );

    stubSpec();
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
          derivation: await GoalAgentPhaseA(
            repository: repository,
            syncService: MockAgentSyncService(),
            signalReader: _FakeReader(),
          ).deriveWakeFacts(agentId: agentId, version: version!, now: now),
          nudges: [
            nudgeRow('ad-dismissed', GoalNudgeStatus.dismissed),
            nudgeRow('ad-retired', GoalNudgeStatus.retired),
            nudgeRow('ad-active', GoalNudgeStatus.active),
          ],
          now: now,
        );
      },
    );

    final written = upserts.whereType<GoalNudgeEntity>().toList();
    // The dismissed ad was NOT retired (terminal), the missing ad was
    // skipped, the active ad was NOT re-run but WAS retired; the retired
    // ad was re-run.
    expect(written, hasLength(2));
    final retired = written.singleWhere((n) => n.id == 'ad-active');
    expect(retired.status, GoalNudgeStatus.retired);
    expect(retired.provenance['retireReason'], 'quota completed');
    final rerun = written.singleWhere((n) => n.id == 'ad-retired');
    expect(rerun.status, GoalNudgeStatus.active);
    expect(rerun.activationCount, 2);
    expect(rerun.provenance['rerunReason'], 'proven copy');

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
          // Forced retry (first evaluation transitions): publish the report.
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
                }, id: 'call-a'),
                toolCall(GoalAgentToolNames.createGoalAd, {
                  'headline': 'Late but not forgotten.',
                  'tone': 'encourage',
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
      final nudge = upserts.whereType<GoalNudgeEntity>().single;
      expect(
        nudge.triggerProgressId,
        goalProgressId(agentId, '2026-08-06'),
        reason: 'the ad is evidence for the period that armed the wake',
      );
    },
  );

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
    final version =
        await repository.getEntity('$agentId:spec-v1')
            as GoalSpecVersionEntity?;
    final derivation = await GoalAgentPhaseA(
      repository: repository,
      syncService: MockAgentSyncService(),
      signalReader: _FakeReader(),
    ).deriveWakeFacts(agentId: agentId, version: version!, now: now);

    // Cooldown: the model ignored dismissalCooldownActive — persistence
    // must still hold the 24h quiet contract.
    await withClock(
      fixedClock,
      () async => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-1',
        threadId: 'thread-1',
        strategy: await loaded([
          {
            'headline': 'Ignore the quiet.',
            'tone': 'nudge',
            'animation': 'pulse',
          },
        ]),
        derivation: derivation,
        nudges: [recentlyDismissed],
        now: now,
      ),
    );
    expect(upserts.whereType<GoalNudgeEntity>(), isEmpty);

    // Dedupe: two identical copies in one response → one row.
    await withClock(
      fixedClock,
      () async => workflow.persistOutputs(
        agentId: agentId,
        runKey: 'run-1',
        threadId: 'thread-1',
        strategy: await loaded([
          {'headline': 'Same words.', 'tone': 'nudge', 'animation': 'pulse'},
          {'headline': 'Same words.', 'tone': 'nudge', 'animation': 'wave'},
        ]),
        derivation: derivation,
        nudges: const [],
        now: now,
      ),
    );
    expect(upserts.whereType<GoalNudgeEntity>(), hasLength(1));
  });
}
