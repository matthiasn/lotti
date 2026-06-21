import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/event_agent_workflow.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';
import 'task_agent_workflow_test_helpers.dart';

void main() {
  late MockAgentRepository mockAgentRepository;
  late MockAgentSyncService mockSyncService;
  late MockConversationRepository mockConversationRepository;
  late MockAiConfigRepository mockAiConfigRepository;
  late MockCloudInferenceRepository mockCloudInferenceRepository;
  late MockConversationManager mockConversationManager;
  late MockJournalRepository mockJournalRepository;
  late MockAgentTemplateService mockTemplateService;
  late EventAgentWorkflow workflow;

  const agentId = 'agent-001';
  const eventId = 'event-001';
  const runKey = 'run-key-001';
  const threadId = 'thread-001';

  final eventTime = DateTime(2026, 6, 20, 19, 30);

  final testAgentIdentity = makeTestIdentity(
    kind: 'event_agent',
    config: const AgentConfig(profileId: 'profile-001'),
  );

  final testAgentState = makeTestState(
    slots: const AgentSlots(activeEventId: eventId),
    awaitingContent: true,
  );
  final testAgentStateNoEvent = makeTestState();

  final testTemplate = makeTestTemplate(kind: AgentTemplateKind.eventAgent);
  final testTemplateVersion = makeTestTemplateVersion(
    directives: 'You narrate events.',
  );

  final geminiProvider =
      AiConfig.inferenceProvider(
            id: 'gemini-provider-001',
            baseUrl: 'https://generativelanguage.googleapis.com',
            apiKey: 'test-api-key',
            name: 'Gemini',
            createdAt: DateTime(2024),
            inferenceProviderType: InferenceProviderType.gemini,
          )
          as AiConfigInferenceProvider;
  final testProfile =
      AiConfig.inferenceProfile(
            id: 'profile-001',
            name: 'Test Profile',
            createdAt: DateTime(2024),
            thinkingModelId: 'models/test-model-v1',
          )
          as AiConfigInferenceProfile;
  final testModel =
      AiConfig.model(
            id: 'model-001',
            name: 'Test Model',
            providerModelId: 'models/test-model-v1',
            inferenceProviderId: 'gemini-provider-001',
            createdAt: DateTime(2024),
            inputModalities: const [Modality.text],
            outputModalities: const [Modality.text],
            isReasoningModel: true,
            supportsFunctionCalling: true,
            description: 'Test model',
          )
          as AiConfigModel;

  JournalEntity eventEntity() => JournalEntity.event(
    meta: Metadata(
      id: eventId,
      createdAt: eventTime,
      updatedAt: eventTime,
      dateFrom: eventTime,
      dateTo: eventTime.add(const Duration(hours: 4)),
    ),
    data: const EventData(
      title: "Maya's 30th",
      stars: 4.5,
      status: EventStatus.completed,
    ),
    entryText: const EntryText(
      plainText: 'great night',
      markdown: 'great night',
    ),
  );

  EventAgentWorkflow buildWorkflow() => EventAgentWorkflow(
    agentRepository: mockAgentRepository,
    conversationRepository: mockConversationRepository,
    aiConfigRepository: mockAiConfigRepository,
    cloudInferenceRepository: mockCloudInferenceRepository,
    journalRepository: mockJournalRepository,
    syncService: mockSyncService,
    templateService: mockTemplateService,
  );

  void stubProviderResolution() {
    when(
      () => mockTemplateService.getTemplateForAgent(agentId),
    ).thenAnswer((_) async => testTemplate);
    when(
      () => mockTemplateService.getActiveVersion(testTemplate.id),
    ).thenAnswer((_) async => testTemplateVersion);
    when(
      () => mockAiConfigRepository.getConfigById('profile-001'),
    ).thenAnswer((_) async => testProfile);
    when(
      () => mockAiConfigRepository.getConfigById('gemini-provider-001'),
    ).thenAnswer((_) async => geminiProvider);
    when(
      () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => [testModel]);
  }

  /// Drives the strategy to publish a recap (and optional observations /
  /// follow-up proposals) the way the LLM would, via the conversation delegate.
  void stubReportPublishingRun({
    List<String> observations = const [],
    List<String> followUpTitles = const [],
  }) {
    mockConversationRepository.sendMessageDelegate =
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
          if (strategy != null) {
            final manager = mockConversationRepository.getConversation(
              conversationId,
            )!;
            when(
              () => manager.addToolResponse(
                toolCallId: any(named: 'toolCallId'),
                response: any(named: 'response'),
              ),
            ).thenReturn(null);

            final calls = <ChatCompletionMessageToolCall>[
              ChatCompletionMessageToolCall(
                id: 'call-rpt',
                type: ChatCompletionMessageToolCallType.function,
                function: ChatCompletionMessageFunctionCall(
                  name: EventAgentToolNames.updateReport,
                  arguments: jsonEncode({
                    'oneLiner': "Maya's 30th, rooftop at dusk.",
                    'tldr': 'A warm rooftop birthday. 🎂',
                    'content': '# The night\nEveryone showed up.',
                  }),
                ),
              ),
              if (observations.isNotEmpty)
                ChatCompletionMessageToolCall(
                  id: 'call-obs',
                  type: ChatCompletionMessageToolCallType.function,
                  function: ChatCompletionMessageFunctionCall(
                    name: EventAgentToolNames.recordObservations,
                    arguments: jsonEncode({'observations': observations}),
                  ),
                ),
              for (var i = 0; i < followUpTitles.length; i++)
                ChatCompletionMessageToolCall(
                  id: 'call-followup-$i',
                  type: ChatCompletionMessageToolCallType.function,
                  function: ChatCompletionMessageFunctionCall(
                    name: EventAgentToolNames.suggestFollowUpTask,
                    arguments: jsonEncode({'title': followUpTitles[i]}),
                  ),
                ),
            ];

            await strategy.processToolCalls(toolCalls: calls, manager: manager);
          }
          return null;
        };
  }

  setUp(() async {
    mockAgentRepository = MockAgentRepository();
    mockSyncService = MockAgentSyncService();
    mockConversationManager = MockConversationManager();
    mockConversationRepository = MockConversationRepository(
      mockConversationManager,
    );
    mockAiConfigRepository = MockAiConfigRepository();
    mockCloudInferenceRepository = MockCloudInferenceRepository();
    mockJournalRepository = MockJournalRepository();
    mockTemplateService = MockAgentTemplateService();

    registerAllFallbackValues();

    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<PersistenceLogic>(MockPersistenceLogic());
      },
    );

    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
    stubAppendMilestone(mockSyncService);
    stubReconciledAgentState(mockSyncService, mockAgentRepository);
    when(() => mockAgentRepository.getEntitiesByIds(any())).thenAnswer((
      invocation,
    ) async {
      final ids = invocation.positionalArguments.first as Iterable<String>;
      final result = <String, AgentDomainEntity>{};
      for (final id in ids) {
        final entity = await mockAgentRepository.getEntity(id);
        if (entity != null) result[id] = entity;
      }
      return result;
    });
    when(
      () => mockAgentRepository.updateWakeRunTemplate(
        any(),
        any(),
        any(),
        resolvedModelId: any(named: 'resolvedModelId'),
        soulId: any(named: 'soulId'),
        soulVersionId: any(named: 'soulVersionId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockAgentRepository.getLatestReport(any(), any()),
    ).thenAnswer((_) async => null);
    when(
      () => mockAgentRepository.getMessagesByKind(
        agentId,
        AgentMessageKind.observation,
      ),
    ).thenAnswer((_) async => []);
    when(
      () => mockAgentRepository.getReportHead(agentId, 'current'),
    ).thenAnswer((_) async => null);
    when(
      () => mockJournalRepository.getLinkedEntities(linkedTo: eventId),
    ).thenAnswer((_) async => []);
    when(() => mockConversationManager.messages).thenReturn([]);

    workflow = buildWorkflow();
  });

  tearDown(tearDownTestGetIt);

  Future<WakeResultLike> run() async {
    final result = await workflow.execute(
      agentIdentity: testAgentIdentity,
      runKey: runKey,
      triggerTokens: {eventId},
      threadId: threadId,
    );
    return (success: result.success, error: result.error);
  }

  group('early abort conditions', () {
    test('fails when agent state is null', () async {
      when(
        () => mockAgentRepository.getAgentState(agentId),
      ).thenAnswer((_) async => null);

      final result = await run();

      expect(result.success, isFalse);
      expect(result.error, contains('No agent state'));
      verifyNever(() => mockSyncService.upsertEntity(any()));
    });

    test('fails when there is no active event id', () async {
      when(
        () => mockAgentRepository.getAgentState(agentId),
      ).thenAnswer((_) async => testAgentStateNoEvent);

      final result = await run();

      expect(result.success, isFalse);
      expect(result.error, contains('No active event ID'));
      verifyNever(() => mockSyncService.upsertEntity(any()));
    });

    test('fails when the event entity is not found', () async {
      when(
        () => mockAgentRepository.getAgentState(agentId),
      ).thenAnswer((_) async => testAgentState);
      when(
        () => mockJournalRepository.getJournalEntityById(eventId),
      ).thenAnswer((_) async => null);

      final result = await run();

      expect(result.success, isFalse);
      expect(result.error, contains('Event not found'));
      verifyNever(() => mockSyncService.upsertEntity(any()));
    });

    test('fails when no inference provider can be resolved', () async {
      when(
        () => mockAgentRepository.getAgentState(agentId),
      ).thenAnswer((_) async => testAgentState);
      when(
        () => mockJournalRepository.getJournalEntityById(eventId),
      ).thenAnswer((_) async => eventEntity());
      when(
        () => mockTemplateService.getTemplateForAgent(agentId),
      ).thenAnswer((_) async => null);

      final result = await run();

      expect(result.success, isFalse);
      expect(result.error, contains('No inference provider'));
      verifyNever(() => mockSyncService.upsertEntity(any()));
    });
  });

  group('successful execution', () {
    setUp(() {
      when(
        () => mockAgentRepository.getAgentState(agentId),
      ).thenAnswer((_) async => testAgentState);
      when(
        () => mockJournalRepository.getJournalEntityById(eventId),
      ).thenAnswer((_) async => eventEntity());
      stubProviderResolution();
    });

    test(
      'persists the recap, updates the head, and clears the content gate',
      () async {
        stubReportPublishingRun();

        final result = await run();
        expect(result.success, isTrue);

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        final reports = captured.whereType<AgentReportEntity>().toList();
        expect(reports, hasLength(1));
        expect(reports.first.content, '# The night\nEveryone showed up.');
        expect(reports.first.tldr, 'A warm rooftop birthday. 🎂');
        expect(reports.first.oneLiner, "Maya's 30th, rooftop at dusk.");
        // No health band / provenance for events.
        expect(reports.first.provenance, isEmpty);

        expect(captured.whereType<AgentReportHeadEntity>(), hasLength(1));

        // The run reached inference, so the awaiting-content gate is cleared.
        final states = captured.whereType<AgentStateEntity>().toList();
        expect(states, isNotEmpty);
        expect(states.last.awaitingContent, isFalse);

        // The wake-completed milestone was event-sourced.
        expect(
          capturedMilestones(mockSyncService),
          contains(AgentMilestone.wakeCompleted),
        );
      },
    );

    test('persists observations recorded during the wake', () async {
      stubReportPublishingRun(observations: ['send the album to the group']);

      await run();

      final captured = verify(
        () => mockSyncService.upsertEntity(captureAny()),
      ).captured;
      final payloads = captured
          .whereType<AgentMessagePayloadEntity>()
          .where((p) => p.content['text'] == 'send the album to the group')
          .toList();
      expect(payloads, hasLength(1));
    });

    test(
      'persists suggested follow-ups as a pending change set on the event',
      () async {
        stubReportPublishingRun(
          followUpTitles: ['Share the album with the group'],
        );

        await run();

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final changeSets = captured.whereType<ChangeSetEntity>().toList();
        expect(changeSets, hasLength(1));
        expect(changeSets.single.taskId, eventId);
        expect(changeSets.single.status, ChangeSetStatus.pending);
        final item = changeSets.single.items.single;
        expect(item.toolName, EventAgentToolNames.suggestFollowUpTask);
        expect(item.humanSummary, contains('Share the album with the group'));
      },
    );

    test('forces a recap when the first pass publishes none', () async {
      mockConversationRepository.maxDelegateCalls = 2;
      var calls = 0;
      mockConversationRepository.sendMessageDelegate =
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
            if (strategy != null) {
              final manager = mockConversationRepository.getConversation(
                conversationId,
              )!;
              when(
                () => manager.addToolResponse(
                  toolCallId: any(named: 'toolCallId'),
                  response: any(named: 'response'),
                ),
              ).thenReturn(null);
              // First pass: publish nothing. Forced retry (call 2): publish.
              if (calls >= 2) {
                await strategy.processToolCalls(
                  toolCalls: [
                    ChatCompletionMessageToolCall(
                      id: 'call-rpt',
                      type: ChatCompletionMessageToolCallType.function,
                      function: ChatCompletionMessageFunctionCall(
                        name: EventAgentToolNames.updateReport,
                        arguments: jsonEncode({
                          'oneLiner': 'forced',
                          'tldr': 'forced recap',
                          'content': '# Forced\nrecovered.',
                        }),
                      ),
                    ),
                  ],
                  manager: manager,
                );
              }
            }
            return null;
          };

      final result = await run();
      expect(result.success, isTrue);
      expect(calls, 2); // the forced retry fired

      final captured = verify(
        () => mockSyncService.upsertEntity(captureAny()),
      ).captured;
      final reports = captured.whereType<AgentReportEntity>().toList();
      expect(reports, hasLength(1));
      expect(reports.single.content, '# Forced\nrecovered.');
    });

    test('clears the gate and persists no recap when even the retry produces '
        'none', () async {
      mockConversationRepository.sendMessageDelegate =
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
          }) async => null; // never publishes a recap

      final result = await run();
      expect(result.success, isTrue);

      final captured = verify(
        () => mockSyncService.upsertEntity(captureAny()),
      ).captured;
      expect(captured.whereType<AgentReportEntity>(), isEmpty);
      // The gate is still cleared (content has arrived); the agent will re-wake
      // on the next event edit via its (now live) subscription.
      final states = captured.whereType<AgentStateEntity>().toList();
      expect(states.last.awaitingContent, isFalse);
    });

    test('increments the failure count when the conversation throws', () async {
      mockConversationRepository.sendMessageDelegate =
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
          }) async => throw Exception('inference exploded');

      final result = await run();

      expect(result.success, isFalse);
      final captured = verify(
        () => mockSyncService.upsertEntity(captureAny()),
      ).captured;
      final states = captured.whereType<AgentStateEntity>().toList();
      expect(states.last.consecutiveFailureCount, 1);
    });
  });
}

typedef WakeResultLike = ({bool success, String? error});
