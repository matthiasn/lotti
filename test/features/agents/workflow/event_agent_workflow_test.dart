import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/soul_document_service.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/event_agent_workflow.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
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

  /// A workflow wired with a real [DomainLogger] (so the `domainLogger != null`
  /// logging branches execute) and an optional soul-document service.
  EventAgentWorkflow buildLoggedWorkflow({SoulDocumentService? soul}) =>
      EventAgentWorkflow(
        agentRepository: mockAgentRepository,
        conversationRepository: mockConversationRepository,
        aiConfigRepository: mockAiConfigRepository,
        cloudInferenceRepository: mockCloudInferenceRepository,
        journalRepository: mockJournalRepository,
        syncService: mockSyncService,
        templateService: mockTemplateService,
        soulDocumentService: soul,
        domainLogger: DomainLogger(loggingService: LoggingService())
          ..enabledDomains.add(LogDomain.agentWorkflow),
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
    InferenceUsage? usage,
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
          return usage;
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
      'persists the final assistant thought and the wake token usage',
      () async {
        // The conversation leaves a final assistant message (the agent's thought)
        // and reports token usage with data.
        when(() => mockConversationManager.messages).thenReturn(const [
          ChatCompletionMessage.assistant(
            content: 'I wove the linked photos and notes into a warm recap.',
          ),
        ]);
        stubReportPublishingRun(
          usage: const InferenceUsage(inputTokens: 120, outputTokens: 80),
        );

        final result = await run();
        expect(result.success, isTrue);

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        // The final response is persisted as a thought payload + a thought-kind
        // message that links to it.
        final thoughtPayloads = captured
            .whereType<AgentMessagePayloadEntity>()
            .where(
              (p) =>
                  p.content['text'] ==
                  'I wove the linked photos and notes into a warm recap.',
            )
            .toList();
        expect(thoughtPayloads, hasLength(1));
        final thoughtMessages = captured
            .whereType<AgentMessageEntity>()
            .where(
              (m) =>
                  m.kind == AgentMessageKind.thought &&
                  m.contentEntryId == thoughtPayloads.single.id,
            )
            .toList();
        expect(thoughtMessages, hasLength(1));

        // Token usage is event-sourced for accounting.
        final usage = captured.whereType<WakeTokenUsageEntity>().toList();
        expect(usage, hasLength(1));
        expect(usage.single.inputTokens, 120);
        expect(usage.single.outputTokens, 80);
      },
    );

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

    test('keeps the gate armed and counts a failure when even the retry '
        'produces no recap', () async {
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
      // A wake that produced no recap — even after the forced retry — is a
      // failure, not a no-op success.
      expect(result.success, isFalse);

      final captured = verify(
        () => mockSyncService.upsertEntity(captureAny()),
      ).captured;
      expect(captured.whereType<AgentReportEntity>(), isEmpty);

      // The content gate stays armed (input state had awaitingContent: true) so
      // a later content arrival re-triggers the agent instead of leaving the
      // event with a permanently empty recap, and the failure is counted.
      final states = captured.whereType<AgentStateEntity>().toList();
      expect(states.last.awaitingContent, isTrue);
      expect(states.last.consecutiveFailureCount, 1);

      // No wake-completed milestone for a wake that completed nothing.
      verifyNever(
        () => mockSyncService.appendMilestone(
          agentId: any(named: 'agentId'),
          milestone: AgentMilestone.wakeCompleted,
          createdAt: any(named: 'createdAt'),
          threadId: any(named: 'threadId'),
          runKey: any(named: 'runKey'),
        ),
      );
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

  group('resilience + edge paths (domain logger configured)', () {
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
      'swallows a failed user-message persist and still lands the recap',
      () async {
        stubProviderResolution();
        stubReportPublishingRun();
        // Only the user-kind message write fails; everything else succeeds.
        when(() => mockSyncService.upsertEntity(any())).thenAnswer((inv) async {
          final entity = inv.positionalArguments.first;
          if (entity is AgentMessageEntity &&
              entity.kind == AgentMessageKind.user) {
            throw Exception('user persist boom');
          }
        });

        final result = await buildLoggedWorkflow().execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {eventId},
          threadId: threadId,
        );

        expect(result.success, isTrue);
      },
    );

    test(
      'swallows a failed provenance write and still lands the recap',
      () async {
        stubProviderResolution();
        stubReportPublishingRun();
        when(
          () => mockAgentRepository.updateWakeRunTemplate(
            any(),
            any(),
            any(),
            resolvedModelId: any(named: 'resolvedModelId'),
            soulId: any(named: 'soulId'),
            soulVersionId: any(named: 'soulVersionId'),
          ),
        ).thenThrow(Exception('provenance boom'));

        final result = await buildLoggedWorkflow().execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {eventId},
          threadId: threadId,
        );

        expect(result.success, isTrue);
      },
    );

    test(
      'merges token usage across the first pass and the forced retry',
      () async {
        stubProviderResolution();
        // Allow the forced retry to actually invoke the delegate a second time.
        // First pass: usage but no recap. Forced retry (toolChoice set): publishes
        // the recap and reports more usage → the two are merged.
        mockConversationRepository.maxDelegateCalls = 2;
        // ignore: cascade_invocations
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
              if (toolChoice != null && strategy != null) {
                final manager = mockConversationRepository.getConversation(
                  conversationId,
                )!;
                when(
                  () => manager.addToolResponse(
                    toolCallId: any(named: 'toolCallId'),
                    response: any(named: 'response'),
                  ),
                ).thenReturn(null);
                await strategy.processToolCalls(
                  toolCalls: [
                    ChatCompletionMessageToolCall(
                      id: 'call-forced',
                      type: ChatCompletionMessageToolCallType.function,
                      function: ChatCompletionMessageFunctionCall(
                        name: EventAgentToolNames.updateReport,
                        arguments: jsonEncode({
                          'oneLiner': 'one',
                          'tldr': 'two',
                          'content': 'three',
                        }),
                      ),
                    ),
                  ],
                  manager: manager,
                );
                return const InferenceUsage(inputTokens: 10, outputTokens: 5);
              }
              return const InferenceUsage(inputTokens: 100, outputTokens: 50);
            };

        final result = await buildLoggedWorkflow().execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {eventId},
          threadId: threadId,
        );

        expect(result.success, isTrue);
        final usage = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured.whereType<WakeTokenUsageEntity>().toList();
        expect(usage, hasLength(1));
        // 100+10 in, 50+5 out — proves the merge ran.
        expect(usage.single.inputTokens, 110);
        expect(usage.single.outputTokens, 55);
      },
    );

    test(
      'swallows a failed token-usage persist and still lands the recap',
      () async {
        stubProviderResolution();
        stubReportPublishingRun(
          usage: const InferenceUsage(inputTokens: 100, outputTokens: 50),
        );
        when(() => mockSyncService.upsertEntity(any())).thenAnswer((inv) async {
          if (inv.positionalArguments.first is WakeTokenUsageEntity) {
            throw Exception('usage persist boom');
          }
        });

        final result = await buildLoggedWorkflow().execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {eventId},
          threadId: threadId,
        );

        expect(result.success, isTrue);
      },
    );

    test(
      'logs and fails the wake when the failure-count write also throws',
      () async {
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
        // The error-path failure-count write then also throws → inner catch logs.
        when(() => mockSyncService.upsertEntity(any())).thenAnswer((inv) async {
          if (inv.positionalArguments.first is AgentStateEntity) {
            throw Exception('state persist boom');
          }
        });

        final result = await buildLoggedWorkflow().execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {eventId},
          threadId: threadId,
        );

        expect(result.success, isFalse);
      },
    );

    test('fails the wake when the forced report retry itself throws', () async {
      stubProviderResolution();
      // Allow the forced retry to actually invoke the delegate a second time.
      mockConversationRepository.maxDelegateCalls = 2;
      // First pass publishes nothing; the forced retry (toolChoice set) throws.
      // ignore: cascade_invocations
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
            if (toolChoice != null) {
              throw Exception('forced retry boom');
            }
            return null;
          };

      final result = await buildLoggedWorkflow().execute(
        agentIdentity: testAgentIdentity,
        runKey: runKey,
        triggerTokens: {eventId},
        threadId: threadId,
      );

      // No recap produced → failed wake (and the retry failure was logged).
      expect(result.success, isFalse);
    });

    test(
      'resolves the active soul for the template when a soul service is set',
      () async {
        stubProviderResolution();
        stubReportPublishingRun();
        final soul = MockSoulDocumentService();
        when(
          () => soul.resolveActiveSoulForTemplate(any()),
        ).thenAnswer((_) async => null);

        final result = await buildLoggedWorkflow(soul: soul).execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {eventId},
          threadId: threadId,
        );

        expect(result.success, isTrue);
        verify(
          () => soul.resolveActiveSoulForTemplate(testTemplate.id),
        ).called(1);
      },
    );

    test('buildHumanSummary labels follow-up proposals and falls back', () {
      expect(
        EventAgentWorkflow.buildHumanSummary(
          EventAgentToolNames.suggestFollowUpTask,
          {'title': '  Share the album  '},
        ),
        'Follow-up task: Share the album',
      );
      expect(
        EventAgentWorkflow.buildHumanSummary(
          EventAgentToolNames.suggestFollowUpTask,
          {'title': '   '},
        ),
        'Suggest a follow-up task',
      );
      // Defensive fallback for any other (future) deferred tool name.
      expect(
        EventAgentWorkflow.buildHumanSummary('some_other_tool', const {}),
        'Deferred: some_other_tool',
      );
    });
  });
}

typedef WakeResultLike = ({bool success, String? error});
