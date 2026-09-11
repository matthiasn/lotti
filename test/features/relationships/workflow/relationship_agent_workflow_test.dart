import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/classes/relationship_trigger_tokens.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:lotti/features/relationships/model/relationship_health_metrics.dart';
import 'package:lotti/features/relationships/runtime/relationship_agent_phase_a.dart';
import 'package:lotti/features/relationships/workflow/relationship_agent_contract.dart';
import 'package:lotti/features/relationships/workflow/relationship_agent_workflow.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/workflow/task_agent_workflow_test_helpers.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const relationshipId = 'person-1';
  final agentId = relationshipAgentIdFor(relationshipId);
  final testDate = DateTime(2026, 8, 1, 9);
  final now = DateTime(2026, 8, 16, 12);

  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late MockRelationshipRepository relationshipRepository;
  late MockAiConfigRepository aiConfigRepository;
  late MockConversationManager conversationManager;
  late MockConversationRepository conversationRepository;
  late List<AgentDomainEntity> upserts;
  late RelationshipAgentWorkflow workflow;

  AgentIdentityEntity identity() =>
      AgentDomainEntity.agent(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.relationshipAgent,
            displayName: 'Anna',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: '$agentId:state',
            config: const AgentConfig(),
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          )
          as AgentIdentityEntity;

  Metadata meta(String id, {DateTime? dateFrom, DateTime? deletedAt}) =>
      Metadata(
        id: id,
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: dateFrom ?? testDate,
        dateTo: dateFrom ?? testDate,
        deletedAt: deletedAt,
      );

  RelationshipEntry relationship({
    bool important = true,
    DateTime? deletedAt,
    String? profileId,
  }) => RelationshipEntry(
    meta: meta(relationshipId, deletedAt: deletedAt),
    data: RelationshipData(
      title: 'Anna',
      important: important,
      checkInCadenceDays: 7,
      profileId: profileId,
      status: RelationshipStatus.active(
        id: 'status-1',
        createdAt: testDate,
        utcOffset: 0,
      ),
    ),
  );

  CheckInEntry checkIn(String id, DateTime at) => CheckInEntry(
    meta: meta(id, dateFrom: at),
    data: const CheckInData(
      relationshipId: relationshipId,
      interactionType: CheckInInteractionType.call,
    ),
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

  void stubGlmResolution() {
    when(
      () => aiConfigRepository.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => [glmModel]);
    when(
      () => aiConfigRepository.getConfigById('melious-provider'),
    ).thenAnswer((_) async => meliousProvider);
  }

  LottiToolCall toolCall(
    String name,
    Map<String, dynamic> args, {
    String id = 'call-1',
  }) => LottiToolCall(id: id, name: name, arguments: jsonEncode(args));

  Map<String, dynamic> briefingArgs() => {
    'healthBand': 'needsAttention',
    'healthRationale': 'Two difficult calls in a row, per your sentiments.',
    'oneLiner': 'It has been a while — reach out to Anna.',
    'tldr': 'You last spoke over two weeks ago.',
    'content': 'Full briefing: reach out about the move…',
  };

  Map<String, dynamic> adArgs() => {
    'headline': "Check in with Anna — it's been 2 weeks.",
    'tagline': 'Last time: the move.',
    'tone': 'nudge',
    'animation': 'steady',
  };

  setUp(() {
    repository = MockAgentRepository();
    syncService = MockAgentSyncService();
    relationshipRepository = MockRelationshipRepository();
    aiConfigRepository = MockAiConfigRepository();
    conversationManager = MockConversationManager();
    conversationRepository = MockConversationRepository(conversationManager);
    when(() => conversationManager.messages).thenReturn(const []);
    upserts = [];
    when(
      () => repository.getProposalLedger(agentId, taskId: relationshipId),
    ).thenAnswer((_) async => const ProposalLedger.empty());
    workflow = RelationshipAgentWorkflow(
      repository: repository,
      syncService: syncService,
      phaseA: RelationshipAgentPhaseA(
        repository: repository,
        syncService: syncService,
        relationshipRepository: relationshipRepository,
      ),
      relationshipRepository: relationshipRepository,
      conversationRepository: conversationRepository,
      cloudInferenceRepository: MockCloudInferenceRepository(),
      aiConfigRepository: aiConfigRepository,
    );
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
    when(
      () => repository.getLatestReport(any(), any()),
    ).thenAnswer((_) async => null);
    when(
      () => repository.getReportHead(any(), any()),
    ).thenAnswer((_) async => null);
    when(
      () => repository.getEntitiesByAgentId(any(), type: any(named: 'type')),
    ).thenAnswer((_) async => []);
    when(
      () => repository.getLinksFrom(
        agentId,
        type: AgentLinkTypes.agentRelationship,
      ),
    ).thenAnswer(
      (_) async => [
        _relationshipLink(agentId, relationshipId, testDate),
      ],
    );
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      upserts.add(invocation.positionalArguments.first as AgentDomainEntity);
    });
    // No state row unless a test seeds one: the outcome stamp then has
    // nothing to write, which keeps every older test's upsert list intact.
    when(() => repository.getAgentState(any())).thenAnswer((_) async => null);
    when(
      () =>
          relationshipRepository.getRelationshipByIdUnfiltered(relationshipId),
    ).thenAnswer((_) async => relationship());
    when(
      () => relationshipRepository.getAllCheckInsForRelationship(
        relationshipId,
      ),
    ).thenAnswer(
      // Overdue on the 7-day cadence as of `now`.
      (_) async => [checkIn('c-1', DateTime(2026, 8, 1, 18))],
    );
    when(
      () => relationshipRepository.getLinkedTasks(relationshipId),
    ).thenAnswer((_) async => []);
    when(
      () => aiConfigRepository.getConfigsByType(any()),
    ).thenAnswer((_) async => []);
    when(
      () => aiConfigRepository.getConfigById(any()),
    ).thenAnswer((_) async => null);
  });

  Future<WakeResult> run({
    Set<String> tokens = const {},
    String? pendingUserMessage,
  }) => withClock(
    Clock.fixed(now),
    () => workflow.execute(
      agentIdentity: identity(),
      runKey: 'run-1',
      triggerTokens: tokens,
      threadId: 'thread-1',
      pendingUserMessage: pendingUserMessage,
    ),
  );

  void stubTaskProposal() {
    stubGlmResolution();
    conversationRepository
      ..maxDelegateCalls = 1
      ..sendMessageDelegate =
          ({
            required conversationId,
            required message,
            required model,
            required provider,
            required inferenceRepo,
            tools,
            toolChoice,
            temperature = 0,
            strategy,
          }) async {
            expect(message, contains('checkInId=c-1'));
            expect(message, contains('PROPOSALS'));
            await strategy!.processToolCalls(
              toolCalls: [
                toolCall(RelationshipAgentToolNames.createAndLinkTask, {
                  'title': 'Send Pip the checklist',
                  'description': 'I promised to send the checklist.',
                  'sourceCheckInId': 'c-1',
                  'reason': 'An explicit commitment.',
                }),
                toolCall(
                  RelationshipAgentToolNames.updateRelationshipReport,
                  briefingArgs(),
                  id: 'report',
                ),
                toolCall(
                  RelationshipAgentToolNames.createRelationshipAd,
                  adArgs(),
                  id: 'ad',
                ),
              ],
              manager: conversationManager,
            );
            return null;
          };
  }

  test(
    'defers the task in a relationship-scoped change set with evidence',
    () async {
      stubTaskProposal();
      expect((await run()).success, isTrue);
      final set = upserts.whereType<ChangeSetEntity>().single;
      expect(set.taskId, relationshipId);
      expect(set.agentId, agentId);
      expect(set.status, ChangeSetStatus.pending);
      expect(set.items.single.args['sourceCheckInId'], 'c-1');
      expect(
        set.items.single.humanSummary,
        'Create task: Send Pip the checklist',
      );
    },
  );

  for (final status in [
    ChangeItemStatus.pending,
    ChangeItemStatus.confirmed,
    ChangeItemStatus.rejected,
  ]) {
    test('does not repeat a $status task when its rationale changes', () async {
      stubTaskProposal();
      expect((await run()).success, isTrue);
      final previous = upserts.whereType<ChangeSetEntity>().single;
      final item = previous.items.single.copyWith(
        args: {...previous.items.single.args, 'reason': 'Different rationale'},
      );
      final entry = LedgerEntry(
        changeSetId: 'previous',
        itemIndex: 0,
        toolName: item.toolName,
        args: item.args,
        humanSummary: item.humanSummary,
        fingerprint: ChangeItem.fingerprint(item),
        status: status,
        createdAt: now,
      );
      when(
        () => repository.getProposalLedger(agentId, taskId: relationshipId),
      ).thenAnswer(
        (_) async => ProposalLedger(
          open: status == ChangeItemStatus.pending ? [entry] : [],
          resolved: status == ChangeItemStatus.pending ? [] : [entry],
        ),
      );
      upserts.clear();
      conversationRepository.maxDelegateCalls = 2;
      expect((await run()).success, isTrue);
      expect(upserts.whereType<ChangeSetEntity>(), isEmpty);
    });
  }

  test('a retry never replaces an already persisted proposal set', () async {
    stubTaskProposal();
    expect((await run()).success, isTrue);
    final previous = upserts.whereType<ChangeSetEntity>().single;
    when(
      () => repository.getEntity(previous.id),
    ).thenAnswer((_) async => previous);
    upserts.clear();
    conversationRepository.maxDelegateCalls = 2;
    expect((await run()).success, isTrue);
    expect(upserts.whereType<ChangeSetEntity>(), isEmpty);
  });

  group('the €0 gates — no inference without a live fact', () {
    test('an agent with no link is a benign no-op', () async {
      when(
        () => repository.getLinksFrom(
          agentId,
          type: AgentLinkTypes.agentRelationship,
        ),
      ).thenAnswer((_) async => []);
      final result = await run();
      expect(result.success, isTrue);
      expect(conversationRepository.sendMessageDelegateCallCount, 0);
    });

    test('a deleted person silences automatic wakes and fails interactive '
        'ones visibly', () async {
      when(
        () => relationshipRepository.getRelationshipByIdUnfiltered(
          relationshipId,
        ),
      ).thenAnswer((_) async => relationship(deletedAt: testDate));
      expect((await run()).success, isTrue);
      expect(
        (await run(pendingUserMessage: 'How is Anna?')).success,
        isFalse,
      );
      expect(conversationRepository.sendMessageDelegateCallCount, 0);
    });

    test('an armed fact that no longer holds consumes itself before any '
        'inference — a check-in landed while the escalation rode sync '
        '(ADR 0059)', () async {
      // Fresh check-in: cadence ok; briefing already covers it.
      when(
        () => relationshipRepository.getAllCheckInsForRelationship(
          relationshipId,
        ),
      ).thenAnswer((_) async => [checkIn('c-2', DateTime(2026, 8, 15, 18))]);
      when(() => repository.getLatestReport(any(), any())).thenAnswer(
        (_) async =>
            AgentDomainEntity.agentReport(
                  id: 'report-0',
                  agentId: agentId,
                  scope: AgentReportScopes.current,
                  createdAt: DateTime(2026, 8, 15, 20),
                  vectorClock: null,
                  content: 'covered',
                )
                as AgentReportEntity,
      );
      final result = await run(
        tokens: {relationshipEscalationWorkspaceKey('2026-08-08')},
      );
      expect(result.success, isTrue);
      expect(conversationRepository.sendMessageDelegateCallCount, 0);
      expect(upserts, isEmpty);
    });

    test('an unimportant person never spends automatically, but Brief me '
        'still answers — the user asked directly', () async {
      when(
        () => relationshipRepository.getRelationshipByIdUnfiltered(
          relationshipId,
        ),
      ).thenAnswer((_) async => relationship(important: false));
      final auto = await run(
        tokens: {relationshipEscalationWorkspaceKey('2026-08-08')},
      );
      expect(auto.success, isTrue);
      expect(conversationRepository.sendMessageDelegateCallCount, 0);
    });
  });

  test(
    'an unresolvable provider re-arms the consumed escalation — a '
    'temporarily unconfigured provider must not orphan the episode',
    () async {
      final result = await run(
        tokens: {relationshipEscalationWorkspaceKey('2026-08-08')},
      );
      expect(result.success, isFalse);
      final rearmed = upserts.whereType<ScheduledWakeEntity>().single;
      expect(
        rearmed.workspaceKey,
        relationshipEscalationWorkspaceKey('2026-08-08'),
      );
      // Strictly LATER than the consumed record's episode deadline — the
      // resolver's reschedule-beats-consume path. A pending twin at the
      // consumed record's own instant would lose to consumption-is-terminal
      // on any peer echo, orphaning the retry fleet-wide.
      expect(rearmed.scheduledAt, now.toUtc());
      expect(rearmed.scheduledAt.isAfter(DateTime.utc(2026, 8, 8)), isTrue);
      // The ORIGINAL tokens ride along verbatim (the baseline token cannot
      // be regenerated after the register transitioned).
      expect(
        rearmed.triggerTokens,
        [relationshipEscalationWorkspaceKey('2026-08-08')],
      );
      expect(rearmed.status, ScheduledWakeStatus.pending);
      expect(conversationRepository.sendMessageDelegateCallCount, 0);
    },
  );

  test('a due escalation produces the briefing report (with the grounded '
      'band as provenance) and mints ONE banner with the deterministic '
      'run-scoped id', () async {
    stubGlmResolution();
    conversationRepository
      ..maxDelegateCalls = 1
      ..sendMessageDelegate =
          ({
            required conversationId,
            required message,
            required model,
            required provider,
            required inferenceRepo,
            tools,
            toolChoice,
            temperature = 0,
            strategy,
          }) async {
            expect(message, contains('FACTS'));
            expect(temperature, 0);
            await strategy!.processToolCalls(
              toolCalls: [
                toolCall(
                  RelationshipAgentToolNames.updateRelationshipReport,
                  briefingArgs(),
                ),
                toolCall(
                  RelationshipAgentToolNames.createRelationshipAd,
                  adArgs(),
                  id: 'call-2',
                ),
              ],
              manager: conversationManager,
            );
            return null;
          };

    final result = await run(
      tokens: {relationshipEscalationWorkspaceKey('2026-08-08')},
    );

    expect(result.success, isTrue);
    expect(result.reportUpdated, isTrue);
    final report = upserts.whereType<AgentReportEntity>().single;
    expect(report.tldr, contains('two weeks'));
    expect(
      report.provenance[RelationshipReportProvenanceKeys.healthBand],
      'needsAttention',
    );
    expect(
      report.provenance[RelationshipReportProvenanceKeys.healthRationale],
      contains('difficult calls'),
    );
    expect(report.provenance['relationshipId'], relationshipId);
    expect(upserts.whereType<AgentReportHeadEntity>(), hasLength(1));

    final banner = upserts.whereType<RelationshipNudgeEntity>().single;
    expect(banner.id, relationshipAdId(agentId, 'run-1'));
    expect(banner.status, NudgeStatus.active);
    expect(banner.brief.headline, contains('2 weeks'));
    expect(banner.staleAt, now.toUtc().add(const Duration(hours: 72)));
    expect(banner.triggerRegisterId, relationshipHealthId(agentId));
    // UTC stamps: updatedAt feeds the nudge LWW tiebreak, and a local
    // instant serializes without an offset, shifting on a syncing peer.
    expect(banner.createdAt, now.toUtc());
    expect(banner.updatedAt, now.toUtc());
    // The in-memory conversation is deleted after the wake — the
    // ConversationRepository map is app-lifetime, so a missed cleanup
    // accumulates every FACTS block and transcript for the session.
    expect(
      conversationRepository.deletedConversationIds,
      contains('test-conv-id'),
    );
  });

  group('the standing report head', () {
    /// One wake that publishes a briefing for the 2026-08-08 due day.
    Future<WakeResult> publishBriefing() {
      stubGlmResolution();
      conversationRepository
        ..maxDelegateCalls = 1
        ..sendMessageDelegate =
            ({
              required conversationId,
              required message,
              required model,
              required provider,
              required inferenceRepo,
              tools,
              toolChoice,
              temperature = 0,
              strategy,
            }) async {
              await strategy!.processToolCalls(
                toolCalls: [
                  toolCall(
                    RelationshipAgentToolNames.updateRelationshipReport,
                    briefingArgs(),
                  ),
                ],
                manager: conversationManager,
              );
              return null;
            };
      return run(tokens: {relationshipEscalationWorkspaceKey('2026-08-08')});
    }

    AgentReportEntity publishedReport(String dueDayKey) =>
        AgentDomainEntity.agentReport(
              id: 'report-published',
              agentId: agentId,
              scope: AgentReportScopes.current,
              createdAt: testDate,
              vectorClock: null,
              content: 'standing',
              provenance: <String, Object?>{'dueDayKey': dueDayKey},
            )
            as AgentReportEntity;

    void stubHeadPointingAt(AgentReportEntity report) {
      when(() => repository.getReportHead(any(), any())).thenAnswer(
        (_) async =>
            AgentDomainEntity.agentReportHead(
                  id: 'head-1',
                  agentId: agentId,
                  scope: AgentReportScopes.current,
                  reportId: report.id,
                  updatedAt: testDate,
                  vectorClock: null,
                )
                as AgentReportHeadEntity,
      );
      when(
        () => repository.getEntity(report.id),
      ).thenAnswer((_) async => report);
    }

    test("is stamped with the DUE DAY's last instant once that day is "
        'over, not the wall clock — generic LWW must resolve two '
        'lease-elected devices by due day, not by who finished last', () async {
      expect((await publishBriefing()).success, isTrue);

      final head = upserts.whereType<AgentReportHeadEntity>().single;
      expect(head.updatedAt, DateTime.utc(2026, 8, 8, 23, 59, 59));
      expect(head.updatedAt.isUtc, isTrue);
      expect(
        head.updatedAt.isBefore(now),
        isTrue,
        reason: 'the wall clock would have been 2026-08-16',
      );
    });

    test('is stamped with the wall clock while the due day is still '
        'running — an in-period head must not be back-dated', () async {
      // Check-in on the 15th, 7-day cadence → due day 2026-08-22, ahead of
      // `now`. A report-refresh episode still publishes a briefing.
      when(
        () => relationshipRepository.getAllCheckInsForRelationship(
          relationshipId,
        ),
      ).thenAnswer((_) async => [checkIn('c-2', DateTime(2026, 8, 15, 12))]);
      stubGlmResolution();
      conversationRepository
        ..maxDelegateCalls = 1
        ..sendMessageDelegate =
            ({
              required conversationId,
              required message,
              required model,
              required provider,
              required inferenceRepo,
              tools,
              toolChoice,
              temperature = 0,
              strategy,
            }) async {
              await strategy!.processToolCalls(
                toolCalls: [
                  toolCall(
                    RelationshipAgentToolNames.updateRelationshipReport,
                    briefingArgs(),
                  ),
                ],
                manager: conversationManager,
              );
              return null;
            };

      await run(tokens: {relationshipReportRefreshTriggerToken});

      expect(
        upserts.whereType<AgentReportHeadEntity>().single.updatedAt,
        now,
      );
    });

    test('does not advance when the published briefing carries a NEWER due '
        'day — a delayed overdue escalation must not put an older briefing '
        'back at the head', () async {
      stubHeadPointingAt(publishedReport('2026-08-15'));

      final result = await publishBriefing();

      expect(result.success, isTrue);
      expect(result.reportUpdated, isFalse);
      // The report ROW still publishes — it is history, not the head.
      expect(upserts.whereType<AgentReportEntity>(), hasLength(1));
      expect(upserts.whereType<AgentReportHeadEntity>(), isEmpty);
    });

    test('advances over an OLDER published due day', () async {
      stubHeadPointingAt(publishedReport('2026-08-01'));

      final result = await publishBriefing();

      expect(result.reportUpdated, isTrue);
      expect(
        upserts.whereType<AgentReportHeadEntity>().single.reportId,
        upserts.whereType<AgentReportEntity>().single.id,
      );
    });

    test('advances when the published report carries no due day at all — '
        'a briefing written before the provenance key existed must not '
        'pin the head forever', () async {
      stubHeadPointingAt(
        AgentDomainEntity.agentReport(
              id: 'report-legacy',
              agentId: agentId,
              scope: AgentReportScopes.current,
              createdAt: testDate,
              vectorClock: null,
              content: 'standing',
            )
            as AgentReportEntity,
      );

      final result = await publishBriefing();

      expect(result.reportUpdated, isTrue);
      expect(
        upserts.whereType<AgentReportHeadEntity>().single.reportId,
        upserts.whereType<AgentReportEntity>().single.id,
      );
    });

    test('advances when there is no head yet — the first briefing', () async {
      final result = await publishBriefing();

      expect(result.reportUpdated, isTrue);
      expect(upserts.whereType<AgentReportHeadEntity>(), hasLength(1));
    });
  });

  test('a facts-message write that fails returns a failed WakeResult, '
      'deletes the conversation and re-arms the consumed escalation — '
      'it used to throw out of execute past all three', () async {
    stubGlmResolution();
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.first as AgentDomainEntity;
      if (entity is AgentMessagePayloadEntity) {
        throw StateError('outbox flush failed');
      }
      upserts.add(entity);
    });

    final result = await run(
      tokens: {relationshipEscalationWorkspaceKey('2026-08-08')},
    );

    expect(result.success, isFalse);
    expect(result.error, contains('outbox flush failed'));
    expect(
      conversationRepository.deletedConversationIds,
      contains('test-conv-id'),
      reason: 'the finally-cleanup must cover this write too',
    );
    final rearmed = upserts.whereType<ScheduledWakeEntity>().single;
    expect(
      rearmed.workspaceKey,
      relationshipEscalationWorkspaceKey('2026-08-08'),
    );
    expect(rearmed.status, ScheduledWakeStatus.pending);
    // No inference was paid for.
    expect(conversationRepository.sendMessageDelegateCallCount, 0);
  });

  test(
    'banner copy is sanitized before persisting — an id the model echoed '
    'from FACTS never renders on the dock (the goal-workflow rule)',
    () async {
      stubGlmResolution();
      conversationRepository
        ..maxDelegateCalls = 1
        ..sendMessageDelegate =
            ({
              required conversationId,
              required message,
              required model,
              required provider,
              required inferenceRepo,
              tools,
              toolChoice,
              temperature = 0,
              strategy,
            }) async {
              await strategy!.processToolCalls(
                toolCalls: [
                  toolCall(
                    RelationshipAgentToolNames.createRelationshipAd,
                    {
                      ...adArgs(),
                      'headline':
                          'Check in with Anna '
                          '(id: 6af9c4b0-1234-4abc-8def-a1b2c3d4e5f6)',
                    },
                  ),
                ],
                manager: conversationManager,
              );
              return null;
            };

      final result = await run(
        tokens: {relationshipEscalationWorkspaceKey('2026-08-08')},
      );

      expect(result.success, isTrue);
      final banner = upserts.whereType<RelationshipNudgeEntity>().single;
      expect(banner.brief.headline, 'Check in with Anna');
      expect(banner.brief.headline, isNot(contains('6af9c4b0')));
    },
  );

  test('the quiet window binds inside the output transaction: a banner '
      'dismissed today blocks the freshly created one', () async {
    stubGlmResolution();
    when(
      () => repository.getEntitiesByAgentId(any(), type: any(named: 'type')),
    ).thenAnswer(
      (_) async => [
        AgentDomainEntity.relationshipNudge(
          id: 'ad-dismissed',
          agentId: agentId,
          status: NudgeStatus.dismissed,
          brief: const NudgeBrief(
            headline: 'old',
            tone: NudgeTone.nudge,
            animation: NudgeBannerAnimation.steady,
          ),
          briefDigest: 'd',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
          dismissedAt: now.subtract(const Duration(hours: 1)),
        ),
      ],
    );
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0,
          strategy,
        }) async {
          await strategy!.processToolCalls(
            toolCalls: [
              toolCall(
                RelationshipAgentToolNames.updateRelationshipReport,
                briefingArgs(),
              ),
              toolCall(
                RelationshipAgentToolNames.createRelationshipAd,
                adArgs(),
                id: 'call-2',
              ),
            ],
            manager: conversationManager,
          );
          return null;
        };

    await run(tokens: {relationshipEscalationWorkspaceKey('2026-08-08')});
    expect(
      upserts.whereType<RelationshipNudgeEntity>(),
      isEmpty,
      reason: 'the rest-of-day quiet window holds (ADR 0055)',
    );
    expect(
      upserts.whereType<AgentReportEntity>(),
      hasLength(1),
      reason: 'the briefing itself still publishes',
    );
  });

  test('the persistence fence: a person deleted while the model was '
      'thinking gets NOTHING published beside them', () async {
    stubGlmResolution();
    var reads = 0;
    when(
      () =>
          relationshipRepository.getRelationshipByIdUnfiltered(relationshipId),
    ).thenAnswer((_) async {
      reads++;
      // Alive for the single pre-inference read (model resolution reuses
      // it), deleted for the in-transaction fence re-read.
      return reads <= 1 ? relationship() : relationship(deletedAt: now);
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
          temperature = 0,
          strategy,
        }) async {
          await strategy!.processToolCalls(
            toolCalls: [
              toolCall(
                RelationshipAgentToolNames.updateRelationshipReport,
                briefingArgs(),
              ),
            ],
            manager: conversationManager,
          );
          return null;
        };

    final result = await run(
      tokens: {relationshipEscalationWorkspaceKey('2026-08-08')},
    );
    expect(result.success, isTrue);
    expect(upserts.whereType<AgentReportEntity>(), isEmpty);
    expect(upserts.whereType<AgentReportHeadEntity>(), isEmpty);
  });

  test('the persistence fence honors REVOKED consent: un-marking important '
      'while the model was thinking silences this very wake — no report, '
      'no head, no banner, not just quiet from the next tick on', () async {
    stubGlmResolution();
    var reads = 0;
    when(
      () =>
          relationshipRepository.getRelationshipByIdUnfiltered(relationshipId),
    ).thenAnswer((_) async {
      reads++;
      // Important for the pre-inference eligibility gate, un-marked for
      // the in-transaction fence re-read.
      return reads <= 1 ? relationship() : relationship(important: false);
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
          temperature = 0,
          strategy,
        }) async {
          await strategy!.processToolCalls(
            toolCalls: [
              toolCall(
                RelationshipAgentToolNames.updateRelationshipReport,
                briefingArgs(),
              ),
              toolCall(
                RelationshipAgentToolNames.createRelationshipAd,
                adArgs(),
                id: 'call-2',
              ),
            ],
            manager: conversationManager,
          );
          return null;
        };

    final result = await run(
      tokens: {relationshipEscalationWorkspaceKey('2026-08-08')},
    );
    expect(result.success, isTrue);
    expect(upserts.whereType<AgentReportEntity>(), isEmpty);
    expect(upserts.whereType<AgentReportHeadEntity>(), isEmpty);
    expect(upserts.whereType<RelationshipNudgeEntity>(), isEmpty);
  });

  test('the consent fence exempts the explicit Brief me — the user asked '
      'directly, so the briefing publishes even for an un-marked '
      'person', () async {
    stubGlmResolution();
    when(
      () =>
          relationshipRepository.getRelationshipByIdUnfiltered(relationshipId),
    ).thenAnswer((_) async => relationship(important: false));
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0,
          strategy,
        }) async {
          await strategy!.processToolCalls(
            toolCalls: [
              toolCall(
                RelationshipAgentToolNames.updateRelationshipReport,
                briefingArgs(),
              ),
            ],
            manager: conversationManager,
          );
          return null;
        };

    final result = await run(tokens: {relationshipReportRefreshTriggerToken});
    expect(result.success, isTrue);
    expect(upserts.whereType<AgentReportEntity>(), hasLength(1));
  });

  test('an interactive turn persists the visible reply under its stable '
      'run-scoped carrier id', () async {
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
          temperature = 0,
          strategy,
        }) async {
          expect(message, contains('PENDING USER MESSAGE'));
          await strategy!.processToolCalls(
            toolCalls: [
              toolCall(RelationshipAgentToolNames.replyToUser, {
                'message': 'You last spoke two weeks ago, about the move.',
              }),
              toolCall(
                RelationshipAgentToolNames.updateRelationshipReport,
                briefingArgs(),
                id: 'call-2',
              ),
            ],
            manager: conversationManager,
          );
          return null;
        };

    final result = await run(pendingUserMessage: 'How are things with Anna?');
    expect(result.success, isTrue);
    // The strategy's per-tool-call recording also writes action rows; the
    // stable carrier id is what makes the VISIBLE reply recognizable.
    final reply = upserts.whereType<AgentMessageEntity>().singleWhere(
      (m) => m.id == relationshipAgentReplyMessageId(agentId, 'run-1'),
    );
    expect(reply.kind, AgentMessageKind.action);
    expect(reply.metadata.toolName, 'reply_to_user');
  });

  test('executeUserMessage refuses an unavailable source turn instead of '
      'inventing one', () async {
    final result = await withClock(
      Clock.fixed(now),
      () => workflow.executeUserMessage(
        agentIdentity: identity(),
        runKey: 'run-1',
        triggerTokens: const {},
        threadId: 'thread-1',
        messageId: 'missing-message',
      ),
    );
    expect(result.success, isFalse);
    expect(conversationRepository.sendMessageDelegateCallCount, 0);
  });

  AgentMessageEntity sourceTurn({
    String? owner,
    String? contentEntryId = 'payload-1',
  }) =>
      AgentDomainEntity.agentMessage(
            id: 'msg-1',
            agentId: owner ?? agentId,
            threadId: 'thread-0',
            kind: AgentMessageKind.user,
            createdAt: testDate,
            vectorClock: null,
            contentEntryId: contentEntryId,
            metadata: const AgentMessageMetadata(),
          )
          as AgentMessageEntity;

  Future<WakeResult> runUserMessage() => withClock(
    Clock.fixed(now),
    () => workflow.executeUserMessage(
      agentIdentity: identity(),
      runKey: 'run-1',
      triggerTokens: const {},
      threadId: 'thread-1',
      messageId: 'msg-1',
    ),
  );

  test('executeUserMessage refuses a source turn owned by ANOTHER agent — '
      "one agent must never answer from another's mailbox", () async {
    when(
      () => repository.getEntity('msg-1'),
    ).thenAnswer((_) async => sourceTurn(owner: 'someone-else'));
    final result = await runUserMessage();
    expect(result.success, isFalse);
    expect(result.error, contains('source message'));
    expect(conversationRepository.sendMessageDelegateCallCount, 0);
  });

  test('executeUserMessage refuses a turn whose payload is gone', () async {
    when(
      () => repository.getEntity('msg-1'),
    ).thenAnswer((_) async => sourceTurn());
    final result = await runUserMessage();
    expect(result.success, isFalse);
    expect(result.error, contains('payload'));
    expect(conversationRepository.sendMessageDelegateCallCount, 0);
  });

  test('executeUserMessage resolves the durable turn and enters the run '
      'as the pending user message', () async {
    when(
      () => repository.getEntity('msg-1'),
    ).thenAnswer((_) async => sourceTurn());
    when(() => repository.getEntity('payload-1')).thenAnswer(
      (_) async =>
          AgentDomainEntity.agentMessagePayload(
                id: 'payload-1',
                agentId: agentId,
                createdAt: testDate,
                vectorClock: null,
                content: const <String, Object?>{'text': '  How is Anna?  '},
              )
              as AgentMessagePayloadEntity,
    );
    // No provider stubs: the delegated interactive run reaches the model
    // resolution step and fails THERE — proof the €0 gates admitted it.
    final result = await runUserMessage();
    expect(result.success, isFalse);
    expect(result.error, contains('no inference provider'));
  });

  test('the mixin wiring exposes the injected logger and the workflow log '
      'domain', () {
    final logger = MockDomainLogger();
    final wired = RelationshipAgentWorkflow(
      repository: repository,
      syncService: syncService,
      phaseA: RelationshipAgentPhaseA(
        repository: repository,
        syncService: syncService,
        relationshipRepository: relationshipRepository,
      ),
      relationshipRepository: relationshipRepository,
      conversationRepository: conversationRepository,
      cloudInferenceRepository: MockCloudInferenceRepository(),
      aiConfigRepository: aiConfigRepository,
      domainLogger: logger,
    );
    expect(wired.domainLogger, same(logger));
    expect(wired.errorLogDomain, LogDomain.agentWorkflow);
    expect(workflow.domainLogger, isNull);
  });

  test('an explicit Brief me pins the refresh directive into the facts, '
      'persists the assistant close as a thought, and records the wake '
      'token usage', () async {
    stubGlmResolution();
    when(() => conversationManager.messages).thenReturn(
      const [
        LottiMessage.assistant(content: 'Done — see the briefing.'),
      ],
    );
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0,
          strategy,
        }) async {
          expect(message, contains('USER EXPLICITLY REQUESTED'));
          await strategy!.processToolCalls(
            toolCalls: [
              toolCall(RelationshipAgentToolNames.updateRelationshipReport, {
                ...briefingArgs(),
                'healthConfidence': 0.8,
              }),
            ],
            manager: conversationManager,
          );
          return const InferenceUsage(inputTokens: 800, outputTokens: 120);
        };

    final result = await run(tokens: {relationshipReportRefreshTriggerToken});

    expect(result.success, isTrue);
    final report = upserts.whereType<AgentReportEntity>().single;
    expect(
      report.provenance[RelationshipReportProvenanceKeys.healthConfidence],
      0.8,
    );
    expect(
      upserts.whereType<AgentMessagePayloadEntity>().where(
        (p) => p.content['text'] == 'Done — see the briefing.',
      ),
      hasLength(1),
      reason: 'the assistant close persists as a durable thought payload',
    );
    final usage = upserts.whereType<WakeTokenUsageEntity>().single;
    expect(usage.inputTokens, 800);
    expect(usage.outputTokens, 120);
    expect(usage.modelId, 'glm-5.2');
  });

  test('a rejected usage row never fails the wake it accounts for', () async {
    stubGlmResolution();
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.first as AgentDomainEntity;
      if (entity is WakeTokenUsageEntity) {
        throw StateError('usage row rejected');
      }
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
          temperature = 0,
          strategy,
        }) async {
          await strategy!.processToolCalls(
            toolCalls: [
              toolCall(
                RelationshipAgentToolNames.updateRelationshipReport,
                briefingArgs(),
              ),
              toolCall(
                RelationshipAgentToolNames.createRelationshipAd,
                adArgs(),
                id: 'call-2',
              ),
            ],
            manager: conversationManager,
          );
          return const InferenceUsage(inputTokens: 100);
        };

    final result = await run(
      tokens: {relationshipEscalationWorkspaceKey('2026-08-08')},
    );
    expect(result.success, isTrue);
    expect(upserts.whereType<AgentReportEntity>(), hasLength(1));
  });

  test('a wake that owed a briefing but received none forces ONE pinned '
      'retry, merging the usage of both passes', () async {
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
            temperature = 0,
            strategy,
          }) async {
            if (conversationRepository.sendMessageDelegateCallCount == 1) {
              // First pass: the model produced nothing.
              return const InferenceUsage(inputTokens: 500);
            }
            expect(message, contains('briefing is required'));
            await strategy!.processToolCalls(
              toolCalls: [
                toolCall(
                  RelationshipAgentToolNames.updateRelationshipReport,
                  briefingArgs(),
                ),
                toolCall(
                  RelationshipAgentToolNames.createRelationshipAd,
                  adArgs(),
                  id: 'call-2',
                ),
              ],
              manager: conversationManager,
            );
            return const InferenceUsage(inputTokens: 300);
          };

    final result = await run(
      tokens: {relationshipEscalationWorkspaceKey('2026-08-08')},
    );
    expect(result.success, isTrue);
    expect(conversationRepository.sendMessageDelegateCallCount, 2);
    expect(upserts.whereType<AgentReportEntity>(), hasLength(1));
    expect(
      upserts.whereType<WakeTokenUsageEntity>().single.inputTokens,
      800,
      reason: 'primary and pinned-retry usage merge into one row',
    );
  });

  test('a pinned retry that itself throws is contained — the primary '
      "pass's outcome still persists", () async {
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
            temperature = 0,
            strategy,
          }) async {
            if (conversationRepository.sendMessageDelegateCallCount == 1) {
              return null;
            }
            throw Exception('retry provider down');
          };

    final result = await run(
      tokens: {relationshipEscalationWorkspaceKey('2026-08-08')},
    );
    expect(result.success, isTrue);
    expect(conversationRepository.sendMessageDelegateCallCount, 2);
    expect(upserts.whereType<AgentReportEntity>(), isEmpty);
  });

  test('an interactive turn that never produces a visible reply fails '
      'loudly instead of silently swallowing the user message', () async {
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
          temperature = 0,
          strategy,
        }) async => null;

    final result = await run(pendingUserMessage: 'How is Anna?');
    expect(result.success, isFalse);
    expect(result.error, contains('no visible reply'));
  });

  test('a deferred outbox-flush failure AFTER the interactive reply '
      'committed is not reported as a failed turn — that would duplicate '
      'the visible reply on retry', () async {
    stubGlmResolution();
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.first as AgentDomainEntity;
      if (entity is AgentReportHeadEntity) {
        throw StateError('deferred outbox flush failed');
      }
      upserts.add(entity);
    });
    when(
      () => repository.getEntity(
        relationshipAgentReplyMessageId(agentId, 'run-1'),
      ),
    ).thenAnswer(
      (_) async =>
          AgentDomainEntity.agentMessage(
                id: relationshipAgentReplyMessageId(agentId, 'run-1'),
                agentId: agentId,
                threadId: 'thread-1',
                kind: AgentMessageKind.action,
                createdAt: now,
                vectorClock: null,
                metadata: const AgentMessageMetadata(runKey: 'run-1'),
              )
              as AgentMessageEntity,
    );
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0,
          strategy,
        }) async {
          await strategy!.processToolCalls(
            toolCalls: [
              toolCall(RelationshipAgentToolNames.replyToUser, {
                'message': 'You last spoke two weeks ago.',
              }),
              toolCall(
                RelationshipAgentToolNames.updateRelationshipReport,
                briefingArgs(),
                id: 'call-2',
              ),
            ],
            manager: conversationManager,
          );
          return null;
        };

    final result = await run(pendingUserMessage: 'How is Anna?');
    expect(result.success, isTrue);
  });

  test('a persistence failure with NO committed reply rethrows and '
      're-arms the consumed escalation', () async {
    stubGlmResolution();
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.first as AgentDomainEntity;
      if (entity is AgentReportHeadEntity) {
        throw StateError('write rejected');
      }
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
          temperature = 0,
          strategy,
        }) async {
          await strategy!.processToolCalls(
            toolCalls: [
              toolCall(
                RelationshipAgentToolNames.updateRelationshipReport,
                briefingArgs(),
              ),
            ],
            manager: conversationManager,
          );
          return null;
        };

    final result = await run(
      tokens: {relationshipEscalationWorkspaceKey('2026-08-08')},
    );
    expect(result.success, isFalse);
    final rearmed = upserts.whereType<ScheduledWakeEntity>().single;
    expect(
      rearmed.workspaceKey,
      relationshipEscalationWorkspaceKey('2026-08-08'),
    );
    expect(rearmed.scheduledAt, now.toUtc());
    expect(
      rearmed.triggerTokens,
      [relationshipEscalationWorkspaceKey('2026-08-08')],
    );
  });

  test('a re-arm write failure is contained — the wake still reports its '
      'own error', () async {
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.first as AgentDomainEntity;
      if (entity is ScheduledWakeEntity) {
        throw StateError('wake store unavailable');
      }
      upserts.add(entity);
    });
    final result = await run(
      tokens: {relationshipEscalationWorkspaceKey('2026-08-08')},
    );
    expect(result.success, isFalse);
    expect(result.error, contains('no inference provider'));
  });

  test('the model may snooze the active banner it was shown; a snoozed '
      'row also blocks minting a second banner', () async {
    stubGlmResolution();
    when(
      () => repository.getEntitiesByAgentId(any(), type: any(named: 'type')),
    ).thenAnswer(
      (_) async => [
        AgentDomainEntity.relationshipNudge(
          id: 'ad-live',
          agentId: agentId,
          status: NudgeStatus.active,
          brief: const NudgeBrief(
            headline: 'Call Anna.',
            tone: NudgeTone.nudge,
            animation: NudgeBannerAnimation.steady,
          ),
          briefDigest: 'd',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
          activatedAt: DateTime(2026, 8, 15),
        ),
      ],
    );
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0,
          strategy,
        }) async {
          await strategy!.processToolCalls(
            toolCalls: [
              toolCall(RelationshipAgentToolNames.snoozeRelationshipAd, {
                'adId': 'ad-live',
                'until': '2026-08-17T09:00:00+02:00',
                'reason': 'User plans to call tomorrow morning.',
              }),
              toolCall(
                RelationshipAgentToolNames.updateRelationshipReport,
                briefingArgs(),
                id: 'call-2',
              ),
              toolCall(
                RelationshipAgentToolNames.createRelationshipAd,
                adArgs(),
                id: 'call-3',
              ),
            ],
            manager: conversationManager,
          );
          return null;
        };

    final result = await run(
      tokens: {relationshipEscalationWorkspaceKey('2026-08-08')},
    );
    expect(result.success, isTrue);
    final snoozed = upserts.whereType<RelationshipNudgeEntity>().single;
    expect(snoozed.id, 'ad-live');
    expect(snoozed.snoozedUntil, DateTime.utc(2026, 8, 17, 7));
    expect(
      upserts.whereType<RelationshipNudgeEntity>().where(
        (n) => n.id == relationshipAdId(agentId, 'run-1'),
      ),
      isEmpty,
      reason: 'a fresh active (snoozed) row blocks a second banner',
    );
  });

  test("the person's own AI profile routes inference ahead of the default "
      'model (ADR 0059 Decision 7)', () async {
    when(
      () =>
          relationshipRepository.getRelationshipByIdUnfiltered(relationshipId),
    ).thenAnswer((_) async => relationship(profileId: 'profile-1'));
    when(() => aiConfigRepository.getConfigById('profile-1')).thenAnswer(
      (_) async => AiConfig.inferenceProfile(
        id: 'profile-1',
        name: 'My profile',
        createdAt: DateTime(2026),
        thinkingModelId: 'model-claude',
      ),
    );
    // The configured model catalogue holds ONLY the profile's model — the
    // default melious route cannot resolve, so success proves the
    // person-profile route was taken.
    final claudeModel =
        AiConfig.model(
              id: 'model-claude',
              name: 'Claude',
              providerModelId: 'claude-x',
              inferenceProviderId: 'anthropic-provider',
              createdAt: DateTime(2026),
              inputModalities: const [Modality.text],
              outputModalities: const [Modality.text],
              isReasoningModel: true,
              supportsFunctionCalling: true,
              description: 'claude',
            )
            as AiConfigModel;
    when(
      () => aiConfigRepository.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => [claudeModel]);
    when(
      () => aiConfigRepository.getConfigById('anthropic-provider'),
    ).thenAnswer(
      (_) async => AiConfig.inferenceProvider(
        id: 'anthropic-provider',
        baseUrl: 'https://api.anthropic.com',
        apiKey: 'key',
        name: 'Anthropic',
        createdAt: DateTime(2026),
        inferenceProviderType: InferenceProviderType.anthropic,
      ),
    );
    conversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0,
          strategy,
        }) async {
          expect(model, 'claude-x');
          expect(provider.name, 'Anthropic');
          await strategy!.processToolCalls(
            toolCalls: [
              toolCall(
                RelationshipAgentToolNames.updateRelationshipReport,
                briefingArgs(),
              ),
            ],
            manager: conversationManager,
          );
          return null;
        };

    final result = await run(
      tokens: {relationshipEscalationWorkspaceKey('2026-08-08')},
    );
    expect(result.success, isTrue);
    expect(upserts.whereType<AgentReportEntity>(), hasLength(1));
  });

  group('resolveRelationshipAgentModel — the chain (ADR 0040 Decision 6)', () {
    final anthropicProvider =
        AiConfig.inferenceProvider(
              id: 'anthropic-provider',
              baseUrl: 'https://api.anthropic.com',
              apiKey: 'key',
              name: 'Anthropic',
              createdAt: DateTime(2026),
              inferenceProviderType: InferenceProviderType.anthropic,
            )
            as AiConfigInferenceProvider;
    final claudeModel =
        AiConfig.model(
              id: 'model-claude',
              name: 'Claude',
              providerModelId: 'claude-x',
              inferenceProviderId: 'anthropic-provider',
              createdAt: DateTime(2026),
              inputModalities: const [Modality.text],
              outputModalities: const [Modality.text],
              isReasoningModel: true,
              supportsFunctionCalling: true,
              description: 'claude',
            )
            as AiConfigModel;

    RelationshipEntry personInCategory({String? profileId}) =>
        relationship(profileId: profileId).copyWith(
          meta: meta(relationshipId).copyWith(categoryId: 'cat-1'),
        );

    /// The catalogue holds ONLY the category profile's model, so a resolved
    /// route proves the category step and nothing else.
    void stubCategoryProfileOnClaude() {
      when(() => aiConfigRepository.getConfigById('profile-cat')).thenAnswer(
        (_) async => AiConfig.inferenceProfile(
          id: 'profile-cat',
          name: 'Family profile',
          createdAt: DateTime(2026),
          thinkingModelId: 'model-claude',
        ),
      );
      when(
        () => aiConfigRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => [claudeModel]);
      when(
        () => aiConfigRepository.getConfigById('anthropic-provider'),
      ).thenAnswer((_) async => anthropicProvider);
    }

    Future<String?> categoryLookup(String categoryId) async =>
        categoryId == 'cat-1' ? 'profile-cat' : null;

    test("the category's default profile routes when neither the person nor "
        'the agent pins one — the ordinary setup', () async {
      stubCategoryProfileOnClaude();

      final resolved = await resolveRelationshipAgentModel(
        relationship: personInCategory(),
        agentIdentity: identity(),
        aiConfigRepository: aiConfigRepository,
        categoryProfileLookup: categoryLookup,
      );

      expect(resolved?.profileId, 'profile-cat');
      expect(resolved?.modelId, 'claude-x');
      expect(resolved?.provider.id, 'anthropic-provider');
    });

    test('without a category lookup the same person has no route at all — '
        'the chain "Brief me" used to hit', () async {
      stubCategoryProfileOnClaude();

      final resolved = await resolveRelationshipAgentModel(
        relationship: personInCategory(),
        agentIdentity: identity(),
        aiConfigRepository: aiConfigRepository,
      );

      expect(resolved, isNull);
    });

    test(
      "the person's own profile still wins over the category default",
      () async {
        stubCategoryProfileOnClaude();
        // The person's profile routes through the melious default model.
        when(() => aiConfigRepository.getConfigById('profile-1')).thenAnswer(
          (_) async => AiConfig.inferenceProfile(
            id: 'profile-1',
            name: 'Mine',
            createdAt: DateTime(2026),
            thinkingModelId: 'model-glm',
          ),
        );
        when(
          () => aiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [claudeModel, glmModel]);
        when(
          () => aiConfigRepository.getConfigById('melious-provider'),
        ).thenAnswer((_) async => meliousProvider);

        final resolved = await resolveRelationshipAgentModel(
          relationship: personInCategory(profileId: 'profile-1'),
          agentIdentity: identity(),
          aiConfigRepository: aiConfigRepository,
          categoryProfileLookup: categoryLookup,
        );

        expect(resolved?.profileId, 'profile-1');
        expect(resolved?.provider.id, 'melious-provider');
      },
    );

    test('a dangling category default falls through to the validated default '
        'model', () async {
      stubGlmResolution();

      final resolved = await resolveRelationshipAgentModel(
        relationship: personInCategory(),
        agentIdentity: identity(),
        aiConfigRepository: aiConfigRepository,
        categoryProfileLookup: (_) async => 'gone',
      );

      expect(resolved?.profileId, isNull);
      expect(resolved?.provider.id, 'melious-provider');
    });

    test('an explicit profile resolves before the category lookup runs — a '
        'failing category read cannot take down a pinned route', () async {
      stubGlmResolution();
      when(() => aiConfigRepository.getConfigById('profile-1')).thenAnswer(
        (_) async => AiConfig.inferenceProfile(
          id: 'profile-1',
          name: 'Mine',
          createdAt: DateTime(2026),
          thinkingModelId: 'model-glm',
        ),
      );

      final resolved = await resolveRelationshipAgentModel(
        relationship: personInCategory(profileId: 'profile-1'),
        agentIdentity: identity(),
        aiConfigRepository: aiConfigRepository,
        categoryProfileLookup: (_) async =>
            throw StateError('the category read failed'),
      );

      expect(resolved?.profileId, 'profile-1');
    });

    test('a person without a category never consults the lookup', () async {
      stubGlmResolution();

      final resolved = await resolveRelationshipAgentModel(
        relationship: relationship(),
        agentIdentity: identity(),
        aiConfigRepository: aiConfigRepository,
        categoryProfileLookup: (_) async =>
            throw StateError('lookup must not run without a category'),
      );

      expect(resolved?.provider.id, 'melious-provider');
    });

    test('the workflow routes a run through its own category lookup — a '
        'briefing lands for a category-routed person where the two-step '
        'chain failed', () async {
      stubCategoryProfileOnClaude();
      when(
        () => relationshipRepository.getRelationshipByIdUnfiltered(
          relationshipId,
        ),
      ).thenAnswer((_) async => personInCategory());
      conversationRepository.sendMessageDelegate =
          ({
            required conversationId,
            required message,
            required model,
            required provider,
            required inferenceRepo,
            tools,
            toolChoice,
            temperature = 0,
            strategy,
          }) async {
            expect(model, 'claude-x');
            expect(provider.name, 'Anthropic');
            await strategy!.processToolCalls(
              toolCalls: [
                toolCall(
                  RelationshipAgentToolNames.updateRelationshipReport,
                  briefingArgs(),
                ),
              ],
              manager: conversationManager,
            );
            return null;
          };
      final tokens = {relationshipEscalationWorkspaceKey('2026-08-08')};

      // The default construction (no lookup) is the regression: no route.
      final unwired = await run(tokens: tokens);
      expect(unwired.success, isFalse);
      expect(unwired.error, contains('no inference provider'));

      workflow = RelationshipAgentWorkflow(
        repository: repository,
        syncService: syncService,
        phaseA: RelationshipAgentPhaseA(
          repository: repository,
          syncService: syncService,
          relationshipRepository: relationshipRepository,
        ),
        relationshipRepository: relationshipRepository,
        conversationRepository: conversationRepository,
        cloudInferenceRepository: MockCloudInferenceRepository(),
        aiConfigRepository: aiConfigRepository,
        categoryProfileLookup: categoryLookup,
      );
      upserts.clear();
      final wired = await run(tokens: tokens);
      expect(wired.success, isTrue);
      expect(upserts.whereType<AgentReportEntity>(), hasLength(1));
    });
  });

  group('with the consumption pair registered', () {
    late MockAiAttributionService attribution;

    AiWorkAttribution envelope(String id, {AiWorkStatus? status}) =>
        AiWorkAttribution(
          id: id,
          workType: AiWorkType.agentReport,
          status: status ?? AiWorkStatus.succeeded,
          initiator: AiActorSnapshot(
            type: AiActorType.agent,
            id: agentId,
            displayName: 'Anna',
          ),
          trigger: const AiTriggerSnapshot(type: AiTriggerType.automatic),
          startedAt: now,
          completedAt: now,
          vectorClock: null,
        );

    setUp(() {
      attribution = MockAiAttributionService();
      getIt
        ..registerSingleton<AiInteractionCapture>(MockAiInteractionCapture())
        ..registerSingleton<AiAttributionService>(attribution);
      addTearDown(getIt.reset);
      when(() => attribution.finalize(any())).thenAnswer((_) async {});
    });

    test('the briefing report carries the envelope and the session is '
        'finalized after the transaction', () async {
      final open = envelope('attr-1');
      when(
        () => attribution.prepareCompletion(
          attributionId: any(named: 'attributionId'),
          outputs: any(named: 'outputs'),
        ),
      ).thenAnswer((_) async => open);
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
            temperature = 0,
            strategy,
          }) async {
            await strategy!.processToolCalls(
              toolCalls: [
                toolCall(
                  RelationshipAgentToolNames.updateRelationshipReport,
                  briefingArgs(),
                ),
              ],
              manager: conversationManager,
            );
            return null;
          };

      final result = await run(
        tokens: {relationshipEscalationWorkspaceKey('2026-08-08')},
      );
      expect(result.success, isTrue);
      expect(conversationRepository.lastConsumptionAgentId, agentId);
      expect(conversationRepository.lastConsumptionWakeRunKey, 'run-1');
      final report = upserts.whereType<AgentReportEntity>().single;
      expect(report.provenance.keys, contains(aiAttributionProvenanceKey));
      verify(() => attribution.finalize(open)).called(1);
    });

    test('a finalize failure is contained: the persisted briefing still '
        'reports a successful wake', () async {
      final open = envelope('attr-1');
      when(
        () => attribution.prepareCompletion(
          attributionId: any(named: 'attributionId'),
          outputs: any(named: 'outputs'),
        ),
      ).thenAnswer((_) async => open);
      when(
        () => attribution.finalize(open),
      ).thenThrow(StateError('rollup store unavailable'));
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
            temperature = 0,
            strategy,
          }) async {
            await strategy!.processToolCalls(
              toolCalls: [
                toolCall(
                  RelationshipAgentToolNames.updateRelationshipReport,
                  briefingArgs(),
                ),
              ],
              manager: conversationManager,
            );
            return null;
          };

      final result = await run(
        tokens: {relationshipEscalationWorkspaceKey('2026-08-08')},
      );
      expect(result.success, isTrue);
      expect(upserts.whereType<AgentReportEntity>(), hasLength(1));
    });

    test('a report-less interactive wake is terminalized as carrierless — '
        'no perpetually in-flight sessions', () async {
      final closed = envelope('attr-closed', status: AiWorkStatus.partial);
      when(
        () => attribution.prepareCompletion(
          attributionId: any(named: 'attributionId'),
          outputs: any(named: 'outputs'),
          status: any(named: 'status'),
          errorCode: any(named: 'errorCode'),
          errorSummary: any(named: 'errorSummary'),
        ),
      ).thenAnswer((_) async => closed);
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
            temperature = 0,
            strategy,
          }) async {
            await strategy!.processToolCalls(
              toolCalls: [
                toolCall(RelationshipAgentToolNames.replyToUser, {
                  'message': 'All quiet with Anna.',
                }),
              ],
              manager: conversationManager,
            );
            return null;
          };

      final result = await run(pendingUserMessage: 'How is Anna?');
      expect(result.success, isTrue);
      verify(() => attribution.finalize(closed)).called(1);
    });

    test('a failed wake closes its envelope as failed', () async {
      final closed = envelope('attr-failed', status: AiWorkStatus.failed);
      when(
        () => attribution.prepareCompletion(
          attributionId: any(named: 'attributionId'),
          outputs: any(named: 'outputs'),
          status: any(named: 'status'),
          errorCode: any(named: 'errorCode'),
          errorSummary: any(named: 'errorSummary'),
        ),
      ).thenAnswer((_) async => closed);
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
            temperature = 0,
            strategy,
          }) async => throw Exception('provider exploded');

      final result = await run(
        tokens: {relationshipEscalationWorkspaceKey('2026-08-08')},
      );
      expect(result.success, isFalse);
      verify(() => attribution.finalize(closed)).called(1);
      // The finally-cleanup holds on the failure path too.
      expect(
        conversationRepository.deletedConversationIds,
        contains('test-conv-id'),
      );
    });
  });
  group('the wake outcome on the state row', () {
    AgentStateEntity stateRow({int failures = 0}) =>
        AgentDomainEntity.agentState(
              id: '$agentId:state',
              agentId: agentId,
              slots: const AgentSlots(),
              updatedAt: testDate,
              vectorClock: null,
              consecutiveFailureCount: failures,
            )
            as AgentStateEntity;

    void succeedingModel() {
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
            temperature = 0,
            strategy,
          }) async {
            await strategy!.processToolCalls(
              toolCalls: [
                toolCall(
                  RelationshipAgentToolNames.updateRelationshipReport,
                  briefingArgs(),
                ),
              ],
              manager: conversationManager,
            );
            return const InferenceUsage(inputTokens: 100);
          };
    }

    void explodingModel() {
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
            temperature = 0,
            strategy,
          }) async => throw Exception('provider exploded');
    }

    AgentStateEntity stamped() => upserts.whereType<AgentStateEntity>().single;

    test(
      'a successful wake stamps lastWakeAt and clears the failure streak',
      () async {
        when(
          () => repository.getAgentState(agentId),
        ).thenAnswer((_) async => stateRow(failures: 2));
        succeedingModel();

        final result = await run(
          tokens: {relationshipEscalationWorkspaceKey('2026-08-08')},
        );

        expect(result.success, isTrue);
        expect(stamped().consecutiveFailureCount, 0);
        expect(stamped().lastWakeAt, now);
      },
    );

    test('a failed wake stamps lastWakeAt and bumps the failure streak — the '
        "person page's card reads both to show failed", () async {
      when(
        () => repository.getAgentState(agentId),
      ).thenAnswer((_) async => stateRow(failures: 2));
      explodingModel();

      final result = await run(
        tokens: {relationshipEscalationWorkspaceKey('2026-08-08')},
      );

      expect(result.success, isFalse);
      expect(stamped().consecutiveFailureCount, 3);
      expect(stamped().lastWakeAt, now);
    });

    test('a wake that finds no model to run on is stamped as failed too — '
        'the card must read Failed · Choose a model, not wait for a briefing '
        'that cannot come', () async {
      when(
        () => repository.getAgentState(agentId),
      ).thenAnswer((_) async => stateRow(failures: 2));
      // No stubGlmResolution(): the default stubs resolve no profile and no
      // model, so execution returns before the try block.

      final result = await run(
        tokens: {relationshipEscalationWorkspaceKey('2026-08-08')},
      );

      expect(result.success, isFalse);
      expect(result.error, contains('no inference provider'));
      expect(stamped().consecutiveFailureCount, 3);
      expect(stamped().lastWakeAt, now);
    });

    test('no state row means nothing to stamp', () async {
      explodingModel();

      await run(tokens: {relationshipEscalationWorkspaceKey('2026-08-08')});

      expect(upserts.whereType<AgentStateEntity>(), isEmpty);
    });

    test('a stamp that fails to write is contained — the wake keeps its own '
        'verdict', () async {
      when(
        () => repository.getAgentState(agentId),
      ).thenAnswer((_) async => stateRow());
      when(() => syncService.upsertEntity(any())).thenAnswer((
        invocation,
      ) async {
        final entity =
            invocation.positionalArguments.first as AgentDomainEntity;
        if (entity is AgentStateEntity) throw StateError('state locked');
        upserts.add(entity);
      });
      succeedingModel();

      final result = await run(
        tokens: {relationshipEscalationWorkspaceKey('2026-08-08')},
      );

      expect(result.success, isTrue);
      expect(upserts.whereType<AgentReportEntity>(), hasLength(1));
    });
  });
}

/// The agent→relationship link used across the tests.
AgentLink _relationshipLink(
  String agentId,
  String relationshipId,
  DateTime at,
) => AgentLink.agentRelationship(
  id: relationshipAgentLinkId(agentId),
  fromId: agentId,
  toId: relationshipId,
  createdAt: at,
  updatedAt: at,
  vectorClock: null,
);
