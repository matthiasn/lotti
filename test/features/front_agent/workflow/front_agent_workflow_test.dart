import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/front_chat_tokens.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/ai_attribution.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';
import 'package:lotti/features/front_agent/model/front_turn_failure.dart';
import 'package:lotti/features/front_agent/service/front_routing_index_builder.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_strategy.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_workflow.dart';
import 'package:lotti/features/front_agent/workflow/front_inference_stall_guard.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';
import '../../agents/workflow/task_agent_workflow_test_helpers.dart';
import '../../categories/test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const runKey = 'run-1';
  const threadId = 'thread-1';
  const input = 'Buy the hose.';
  //             0123456789012

  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late MockJournalDb journalDb;
  late MockAiConfigRepository aiConfigRepository;
  late MockConversationManager manager;
  late MockConversationRepository conversationRepository;
  late List<AgentDomainEntity> upserts;
  late FrontAgentWorkflow workflow;
  late MockDomainLogger domainLogger;

  final identity = makeTestIdentity(
    id: frontAgentId,
    agentId: frontAgentId,
    kind: AgentKinds.frontAgent,
    allowedCategoryIds: {'work'},
  );
  final provider =
      AiConfig.inferenceProvider(
            id: 'melious-provider',
            baseUrl: 'https://api.melious.ai',
            apiKey: 'key',
            name: 'Melious',
            createdAt: DateTime(2026),
            inferenceProviderType: InferenceProviderType.melious,
          )
          as AiConfigInferenceProvider;
  final flash =
      AiConfig.model(
            id: 'model-flash',
            name: 'Flash',
            providerModelId: meliousDeepseekV41FlashModelId,
            inferenceProviderId: provider.id,
            createdAt: DateTime(2026),
            inputModalities: const [Modality.text],
            outputModalities: const [Modality.text],
            isReasoningModel: true,
            supportsFunctionCalling: true,
            description: 'flash',
          )
          as AiConfigModel;

  ChatCompletionMessageToolCall call(String name, Map<String, dynamic> args) =>
      ChatCompletionMessageToolCall(
        id: 'call-$name',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: name,
          arguments: jsonEncode(args),
        ),
      );

  Map<String, dynamic> dispatchArgs() => {
    'segments': [
      {
        'start': 0,
        'end': input.length,
        'text': input,
        'intent': 'instruction',
        'destination': {'kind': 'task', 'id': 'garden'},
        'confidence': 0.9,
      },
    ],
  };

  /// Seeds the durable user turn the wake token names.
  void seedMessage({
    String messageId = 'msg-1',
    String? text = input,
    List<String>? chips,
  }) {
    final payload = makeTestMessagePayload(
      id: 'payload-1',
      agentId: frontAgentId,
      content: {'text': ?text, frontCategoriesKey: ?chips},
    );
    final message = makeTestMessage(
      id: messageId,
      agentId: frontAgentId,
      threadId: messageId,
      kind: AgentMessageKind.user,
      contentEntryId: payload.id,
    );
    when(
      () => repository.getEntity(messageId),
    ).thenAnswer((_) async => message);
    when(
      () => repository.getEntity(payload.id),
    ).thenAnswer((_) async => payload);
  }

  /// The model's one turn: it calls [toolCalls] through the strategy.
  void stubModel(
    List<ChatCompletionMessageToolCall> Function(int call) toolCalls, {
    int maxCalls = 1,
    void Function(String message)? onMessage,
  }) {
    var calls = 0;
    conversationRepository
      ..maxDelegateCalls = maxCalls
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
            onMessage?.call(message);
            when(() => manager.turnCount).thenReturn(calls);
            await (strategy! as FrontAgentStrategy).processToolCalls(
              toolCalls: toolCalls(calls),
              manager: manager,
            );
            return null;
          };
  }

  setUp(() {
    repository = MockAgentRepository();
    syncService = MockAgentSyncService();
    journalDb = MockJournalDb();
    aiConfigRepository = MockAiConfigRepository();
    manager = MockConversationManager();
    conversationRepository = MockConversationRepository(manager);
    domainLogger = MockDomainLogger();
    upserts = [];
    when(() => manager.turnCount).thenReturn(0);
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      upserts.add(invocation.positionalArguments.first as AgentDomainEntity);
    });
    when(() => repository.getEntity(any())).thenAnswer((_) async => null);
    when(() => repository.getAgentMessages(any())).thenAnswer((_) async => []);
    // An index with one task, built from an otherwise empty world.
    when(
      () => journalDb.getTasksDueOnOrBefore(any()),
    ).thenAnswer((_) async => const []);
    when(
      () => journalDb.getOpenTasksForDayAgentCorpus(
        categoryIds: any(named: 'categoryIds'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => [makeGardenTask()]);
    when(
      () => journalDb.getVisibleProjects(),
    ).thenAnswer((_) async => const []);
    when(() => journalDb.getAllCategories()).thenAnswer(
      (_) async => [
        CategoryTestUtils.createTestCategory(id: 'work', name: 'Work'),
        CategoryTestUtils.createTestCategory(id: 'home', name: 'Home'),
      ],
    );
    when(
      () => journalDb.getAllCategoriesIncludingPrivate(),
    ).thenAnswer((_) async => const []);
    when(
      () => repository.getLatestTaskReportsForTaskIds(any()),
    ).thenAnswer((_) async => const {});
    when(
      () => repository.getLinksToMultiple(any(), type: any(named: 'type')),
    ).thenAnswer((_) async => const {});
    when(
      () => repository.getLatestReportsByAgentIds(any(), any()),
    ).thenAnswer((_) async => const {});
    when(
      () => repository.getAgentIdentitiesByLifecycle(AgentLifecycle.active),
    ).thenAnswer((_) async => const []);
    when(
      () => repository.getEntitiesByIds(any()),
    ).thenAnswer((_) async => const {});
    // The built-in cheap model resolves.
    when(
      () => aiConfigRepository.getDefaultProfileId(),
    ).thenAnswer((_) async => null);
    when(
      () => aiConfigRepository.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => [flash]);
    when(
      () => aiConfigRepository.getConfigById(provider.id),
    ).thenAnswer((_) async => provider);

    workflow = FrontAgentWorkflow(
      repository: repository,
      syncService: syncService,
      conversationRepository: conversationRepository,
      cloudInferenceRepository: MockCloudInferenceRepository(),
      aiConfigRepository: aiConfigRepository,
      indexBuilder: FrontRoutingIndexBuilder(
        journalDb: journalDb,
        agentRepository: repository,
      ),
      domainLogger: domainLogger,
    );
  });

  Future<WakeResultLike> run({
    String messageId = 'msg-1',
    AgentIdentityEntity? agentIdentity,
  }) async {
    final result = await workflow.executeUserMessage(
      agentIdentity: agentIdentity ?? identity,
      runKey: runKey,
      triggerTokens: {frontChatMessageTriggerToken(messageId)},
      threadId: threadId,
      messageId: messageId,
    );
    return (success: result.success, error: result.error);
  }

  group('the source turn', () {
    test('a missing message fails the wake before any inference', () async {
      final result = await run(messageId: 'nope');
      expect(result.success, isFalse);
      expect(result.error, contains('source message is unavailable'));
      expect(conversationRepository.sendMessageDelegateCallCount, 0);
    });

    test('a message of another agent or without text fails the wake', () async {
      seedMessage(text: null);
      final result = await run();
      expect(result.success, isFalse);
      expect(result.error, contains('payload is unavailable'));
    });
  });

  group('a routed turn', () {
    test('persists the dispatch record under deterministic ids, keyed to '
        'the source message, and reports success', () async {
      seedMessage();
      stubModel(
        (_) => [
          call('reply_to_user', {'message': 'Filed under Garden.'}),
          call('dispatch', dispatchArgs()),
        ],
      );

      final result = await run();

      expect(result.success, isTrue);
      final dispatch = upserts.whereType<AgentMessageEntity>().singleWhere(
        (m) => m.id == frontAgentDispatchMessageId(frontAgentId, runKey),
      );
      expect(dispatch.kind, AgentMessageKind.action);
      expect(dispatch.metadata.toolName, FrontAgentToolNames.dispatch);
      expect(dispatch.metadata.runKey, runKey);
      expect(dispatch.threadId, threadId);
      expect(dispatch.metadata.operationId, 'msg-1');
      final payload = upserts
          .whereType<AgentMessagePayloadEntity>()
          .singleWhere(
            (p) => p.id == dispatch.contentEntryId,
          );
      expect(payload.content['input'], input);
      final stored = frontDispatchFromPayload(payload)!;
      expect(stored.segments.single.destinationId, 'garden');
      expect(stored.segments.single.kind, FrontDestinationKind.task);

      final reply = upserts.whereType<AgentMessageEntity>().singleWhere(
        (m) => m.id == frontAgentReplyMessageId(frontAgentId, runKey),
      );
      expect(reply.metadata.toolName, AgentConversationToolNames.replyToUser);
      expect(reply.metadata.operationId, 'msg-1');
      // No question was asked, so no question record exists.
      expect(
        upserts.whereType<AgentMessageEntity>().where(
          (m) => m.id == frontAgentAskMessageId(frontAgentId, runKey),
        ),
        isEmpty,
      );
      // The conversation is cleaned up and the first call had the full
      // three-call budget.
      expect(conversationRepository.deletedConversationIds, ['test-conv-id']);
      expect(conversationRepository.turnBudgets, [frontProviderCallsPerTurn]);
      expect(conversationRepository.lastConsumptionAgentId, isNull);
    });

    test(
      'the prompt carries the index, the recent turns of this '
      'conversation only and the pending message in that order, and the '
      'system prompt is the contract followed by her manner',
      () async {
        seedMessage();
        String? system;
        String? sent;
        conversationRepository = MockConversationRepository(
          manager,
          onSystemMessage: (s) => system = s,
        );
        workflow = FrontAgentWorkflow(
          repository: repository,
          syncService: syncService,
          conversationRepository: conversationRepository,
          cloudInferenceRepository: MockCloudInferenceRepository(),
          aiConfigRepository: aiConfigRepository,
          indexBuilder: FrontRoutingIndexBuilder(
            journalDb: journalDb,
            agentRepository: repository,
          ),
          domainLogger: MockDomainLogger(),
          sass: () => CompanionSass.sassy,
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
              temperature = 0.7,
              strategy,
            }) async {
              sent = message;
              when(() => manager.turnCount).thenReturn(1);
              await (strategy! as FrontAgentStrategy).processToolCalls(
                toolCalls: [call('dispatch', dispatchArgs())],
                manager: manager,
              );
              expect(model, meliousDeepseekV41FlashModelId);
              expect(temperature, 0);
              expect(tools!.map((t) => t.function.name), [
                'dispatch',
                'read_tldr',
                'match_to_corpus',
                'list_due_tasks',
                'summarize_logged_time',
                'list_closed_tasks',
                'summarize_pull_requests',
                'ask_user',
                'reply_to_user',
              ]);
              return null;
            };
        // An earlier answered turn and this wake's own source turn.
        when(() => repository.getAgentMessages(frontAgentId)).thenAnswer(
          (_) async => [
            makeTestMessage(
              id: 'msg-1',
              agentId: frontAgentId,
              kind: AgentMessageKind.user,
              contentEntryId: 'payload-1',
            ),
            makeTestMessage(
              id: 'old-reply',
              agentId: frontAgentId,
              kind: AgentMessageKind.action,
              metadata: const AgentMessageMetadata(
                toolName: 'reply_to_user',
                runKey: 'run-0',
                operationId: 'old-user',
              ),
              contentEntryId: 'old-reply-payload',
              createdAt: DateTime(2026, 10, 22, 9),
            ),
            // Another conversation's turn and its reply: another subject.
            makeTestMessage(
              id: 'other-user',
              agentId: frontAgentId,
              kind: AgentMessageKind.user,
              contentEntryId: 'other-user-payload',
              createdAt: DateTime(2026, 10, 22, 10),
            ),
            makeTestMessage(
              id: 'other-reply',
              agentId: frontAgentId,
              kind: AgentMessageKind.action,
              metadata: const AgentMessageMetadata(
                toolName: 'reply_to_user',
                runKey: 'run-9',
                operationId: 'other-user',
              ),
              contentEntryId: 'other-reply-payload',
              createdAt: DateTime(2026, 10, 22, 10, 1),
            ),
            // The strategy's log row for the same tool: no operationId, so
            // it is not a turn.
            makeTestMessage(
              id: 'old-reply-log',
              agentId: frontAgentId,
              kind: AgentMessageKind.action,
              toolName: 'reply_to_user',
              runKey: 'run-0',
              createdAt: DateTime(2026, 10, 22, 9),
            ),
            makeTestMessage(
              id: 'old-user',
              agentId: frontAgentId,
              kind: AgentMessageKind.user,
              contentEntryId: 'old-user-payload',
              createdAt: DateTime(2026, 10, 22, 8),
            ),
            makeTestMessage(
              id: 'old-thought',
              agentId: frontAgentId,
              runKey: 'run-0',
            ),
          ],
        );
        // Payloads are read in batches: the user turns' (for their
        // conversation), then the tail's.
        final payloads = {
          'payload-1': makeTestMessagePayload(
            id: 'payload-1',
            agentId: frontAgentId,
            content: {'text': input},
          ),
          'old-user-payload': makeTestMessagePayload(
            id: 'old-user-payload',
            agentId: frontAgentId,
            content: const {'text': 'What about the garden?'},
          ),
          'old-reply-payload': makeTestMessagePayload(
            id: 'old-reply-payload',
            agentId: frontAgentId,
            content: const {'text': 'Filed under Garden.'},
          ),
          'other-user-payload': makeTestMessagePayload(
            id: 'other-user-payload',
            agentId: frontAgentId,
            content: const {
              'text': 'Count the hatchlings',
              'conversationId': 'c-other',
            },
          ),
          'other-reply-payload': makeTestMessagePayload(
            id: 'other-reply-payload',
            agentId: frontAgentId,
            content: const {'text': 'Forty-two.'},
          ),
        };
        final batches = <Set<String>>[];
        when(() => repository.getEntitiesByIds(any())).thenAnswer((
          invocation,
        ) async {
          final ids = invocation.positionalArguments.first as Set<String>;
          batches.add(ids);
          return {
            for (final id in ids) id: ?payloads[id],
          };
        });

        // An expectation that fails inside the model call fails the wake,
        // which is caught: the result is what says it held.
        final result = await run();
        expect(result.success, isTrue);

        // The contract, then her manner at the sass the user set.
        expect(
          system,
          '$frontAgentSystemPrompt\n\n'
          '${frontAgentPersonality(CompanionSass.sassy)}',
        );
        expect(sent, isNotNull);
        final indexAt = sent!.indexOf('<routing_index>');
        final recentAt = sent!.indexOf('<recent_turns>');
        final clockAt = sent!.indexOf('<current_local_time>');
        final pendingAt = sent!.indexOf(frontPendingUserMessageHeader);
        expect(
          [indexAt, recentAt, clockAt, pendingAt],
          [
            isNonNegative,
            greaterThan(indexAt),
            greaterThan(recentAt),
            greaterThan(clockAt),
          ],
        );
        expect(sent, contains('- task:garden | Garden | OPEN'));
        // The words, in order, never the ids; the log row and the pending
        // message itself stay out of the tail.
        expect(
          sent,
          contains(
            '- user: What about the garden?\n- reply: Filed under Garden.',
          ),
        );
        expect(sent, isNot(contains('Count the hatchlings')));
        expect(sent, isNot(contains('Forty-two')));
        expect(batches.last, {'old-user-payload', 'old-reply-payload'});
        expect(sent, isNot(contains('old-thought')));
        expect(sent, isNot(contains('old-reply')));
        expect(sent, isNot(contains('old-user')));
        expect(sent, isNot(contains('- user: $input')));
        expect(sent, endsWith('$input\n$frontPendingUserMessageFooter'));
      },
    );
  });

  group('a follow-up to a task the conversation named', () {
    test('the closed task her earlier reply linked reaches the prompt '
        'after the recent turns, and one sentence becomes a follow-up '
        'draft with its priority, due day and backdated start', () async {
      seedMessage();
      final now = DateTime(2026, 11, 2, 9, 30);
      final stamp = DateTime(2026, 10);
      final done = TaskStatus.done(id: 's', createdAt: stamp, utcOffset: 0);
      when(() => repository.getAgentMessages(frontAgentId)).thenAnswer(
        (_) async => [
          makeTestMessage(
            id: 'msg-1',
            agentId: frontAgentId,
            kind: AgentMessageKind.user,
            contentEntryId: 'payload-1',
          ),
          makeTestMessage(
            id: 'old-user',
            agentId: frontAgentId,
            kind: AgentMessageKind.user,
            contentEntryId: 'old-user-payload',
            createdAt: DateTime(2026, 11, 2, 9),
          ),
          makeTestMessage(
            id: 'old-reply',
            agentId: frontAgentId,
            kind: AgentMessageKind.action,
            metadata: const AgentMessageMetadata(
              toolName: 'reply_to_user',
              runKey: 'run-0',
              operationId: 'old-user',
            ),
            contentEntryId: 'old-reply-payload',
            createdAt: DateTime(2026, 11, 2, 9, 1),
          ),
        ],
      );
      final payloads = {
        'payload-1': makeTestMessagePayload(
          id: 'payload-1',
          agentId: frontAgentId,
          content: {'text': input},
        ),
        'old-user-payload': makeTestMessagePayload(
          id: 'old-user-payload',
          agentId: frontAgentId,
          content: const {'text': 'What did I finish yesterday?'},
        ),
        'old-reply-payload': makeTestMessagePayload(
          id: 'old-reply-payload',
          agentId: frontAgentId,
          content: const {
            'text': 'You finished [Prune the roses](lotti://task/roses).',
          },
        ),
      };
      when(() => repository.getEntitiesByIds(any())).thenAnswer(
        (invocation) async => {
          for (final id in invocation.positionalArguments.first as Set<String>)
            id: ?payloads[id],
        },
      );
      when(() => journalDb.getJournalEntitiesForIds({'roses'})).thenAnswer(
        (_) async => [
          JournalEntity.task(
            meta: Metadata(
              id: 'roses',
              createdAt: stamp,
              updatedAt: stamp,
              dateFrom: stamp,
              dateTo: stamp,
              categoryId: 'work',
            ),
            data: TaskData(
              status: done,
              statusHistory: [done],
              dateFrom: stamp,
              dateTo: stamp,
              title: 'Prune the roses',
            ),
          ),
        ],
      );
      String? sent;
      stubModel(
        onMessage: (message) => sent = message,
        (_) => [
          call('dispatch', {
            'segments': [
              {
                'start': 0,
                'end': input.length,
                'text': input,
                'intent': 'instruction',
                'destination': {'kind': 'new', 'newKind': 'task'},
                'confidence': 0.9,
                'task': {
                  'title': 'Mulch the roses',
                  'followsUpTaskId': 'roses',
                  'priority': 'P1',
                  'due': '2026-11-02',
                  'startedMinutesAgo': 5,
                },
              },
            ],
          }),
        ],
      );

      final result = await withClock(Clock.fixed(now), run);

      expect(result.success, isTrue);
      final recentAt = sent!.indexOf('<recent_turns>');
      final namedAt = sent!.indexOf(
        '<conversation_tasks>\n- task:roses | Prune the roses | DONE | '
        'category:work\n'
        '</conversation_tasks>',
      );
      final clockAt = sent!.indexOf('<current_local_time>');
      expect(namedAt, greaterThan(recentAt));
      expect(clockAt, greaterThan(namedAt));

      final payload = upserts
          .whereType<AgentMessagePayloadEntity>()
          .singleWhere(
            (p) => p.content['segments'] is List,
          );
      final draft = frontDispatchFromPayload(payload)!.segments.single.task!;
      expect(draft.title, 'Mulch the roses');
      expect(draft.followsUpTaskId, 'roses');
      expect(draft.priority, TaskPriority.p1High);
      expect(draft.due, DateTime(2026, 11, 2));
      expect(draft.startedAt, DateTime(2026, 11, 2, 9, 25));
    });
  });

  group('the repair round', () {
    test('a turn that ends without a terminal call gets the repair '
        'instruction once, within the remaining budget', () async {
      seedMessage();
      final messages = <String>[];
      var calls = 0;
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
            }) async {
              calls++;
              messages.add(message);
              when(() => manager.turnCount).thenReturn(calls);
              final s = strategy! as FrontAgentStrategy;
              await s.processToolCalls(
                toolCalls: calls == 1
                    ? [
                        call('read_tldr', {
                          'ids': ['task:garden'],
                        }),
                      ]
                    : [call('dispatch', dispatchArgs())],
                manager: manager,
              );
              return calls == 1
                  ? const InferenceUsage(inputTokens: 10, outputTokens: 5)
                  : const InferenceUsage(inputTokens: 20, outputTokens: 7);
            };

      final result = await run();

      expect(result.success, isTrue);
      expect(messages.last, frontDispatchRepairInstruction);
      expect(conversationRepository.turnBudgets, [
        frontProviderCallsPerTurn,
        frontProviderCallsPerTurn - 1,
      ]);
      // Both rounds' usage is one synced row for the wake.
      final usage = upserts.whereType<WakeTokenUsageEntity>().single;
      expect(usage.inputTokens, 30);
      expect(usage.outputTokens, 12);
      expect(usage.runKey, runKey);
      expect(usage.modelId, meliousDeepseekV41FlashModelId);
    });

    test('with the budget spent and no terminal call, the wake fails closed '
        'and persists no reply of its own', () async {
      seedMessage();
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
            when(() => manager.turnCount).thenReturn(frontProviderCallsPerTurn);
            return null;
          };

      final result = await run();

      expect(result.success, isFalse);
      expect(
        FrontTurnFailure.fromWakeError(result.error),
        FrontTurnFailure.noAnswer,
      );
      // The full log says what went wrong, not just the type.
      final logged = verify(
        () => domainLogger.error(
          LogDomain.agentWorkflow,
          captureAny(),
          subDomain: 'frontAgent',
          message: 'front agent turn failed',
          stackTrace: any(named: 'stackTrace'),
        ),
      ).captured.single;
      expect(
        logged.toString(),
        'front turn produced no dispatch, question or reply',
      );
      expect(conversationRepository.turnBudgets, hasLength(1));
      expect(upserts.whereType<AgentMessageEntity>(), isEmpty);
      expect(conversationRepository.deletedConversationIds, ['test-conv-id']);
    });
  });

  group('frontRecentTurnOf', () {
    AgentMessageEntity action(String toolName) => makeTestMessage(
      id: 'm',
      agentId: frontAgentId,
      kind: AgentMessageKind.action,
      metadata: AgentMessageMetadata(
        toolName: toolName,
        runKey: 'run-0',
        operationId: 'u',
      ),
      contentEntryId: 'p',
    );
    AgentMessagePayloadEntity payload(Map<String, Object?> content) =>
        makeTestMessagePayload(
          id: 'p',
          agentId: frontAgentId,
          content: content,
        );

    test('renders a question with its option labels and ids', () {
      final turn = frontRecentTurnOf(
        action(FrontAgentToolNames.askUser),
        payload({
          'question': 'The garden or the shed?',
          'options': [
            {'kind': 'task', 'id': 'garden', 'label': 'Garden'},
            {'kind': 'task', 'id': 'shed', 'label': 'Shed'},
          ],
        }),
      );
      expect(turn, (
        role: 'question',
        text:
            'The garden or the shed? — options: Garden (task:garden), '
            'Shed (task:shed)',
      ));
    });

    test('renders a dispatch as its segments and destinations', () {
      final turn = frontRecentTurnOf(
        action(FrontAgentToolNames.dispatch),
        payload({
          'input': 'Buy the hose. Learn the accordion. Whatever.',
          'segments': [
            const FrontDispatchSegment(
              start: 0,
              end: 13,
              text: 'Buy the hose.',
              intent: FrontSegmentIntent.instruction,
              kind: FrontDestinationKind.task,
              destinationId: 'garden',
              confidence: 0.9,
            ).toJson(),
            const FrontDispatchSegment(
              start: 14,
              end: 34,
              text: 'Learn the accordion.',
              intent: FrontSegmentIntent.statement,
              kind: FrontDestinationKind.newThing,
              newKind: FrontNewKind.goal,
              confidence: 0.3,
            ).toJson(),
            const FrontDispatchSegment(
              start: 35,
              end: 44,
              text: 'Whatever.',
              intent: FrontSegmentIntent.statement,
              kind: FrontDestinationKind.unrouted,
              confidence: 0,
            ).toJson(),
          ],
        }),
      );
      expect(turn, (
        role: 'dispatch',
        text:
            '"Buy the hose." → task:garden; "Learn the accordion." → new '
            'goal; "Whatever." → unrouted',
      ));
    });

    test('renders user and reply text, collapsed and clipped', () {
      final user = makeTestMessage(
        id: 'u',
        agentId: frontAgentId,
        kind: AgentMessageKind.user,
        contentEntryId: 'p',
      );
      expect(
        frontRecentTurnOf(user, payload({'text': '  two\n\nlines  '})),
        (role: 'user', text: 'two lines'),
      );
      final long = 'x' * (frontRecentTurnMaxChars + 10);
      final reply = frontRecentTurnOf(
        action(FrontAgentToolNames.replyToUser),
        payload({'text': long}),
      );
      expect(reply!.role, 'reply');
      expect(reply.text.length, frontRecentTurnMaxChars + 1);
      expect(reply.text, endsWith('…'));
    });

    test('a payload of the wrong shape, or an unknown tool, is nothing', () {
      expect(
        frontRecentTurnOf(action(FrontAgentToolNames.askUser), payload({})),
        isNull,
      );
      expect(
        frontRecentTurnOf(
          action(FrontAgentToolNames.replyToUser),
          payload({'text': 1}),
        ),
        isNull,
      );
      expect(
        frontRecentTurnOf(action(FrontAgentToolNames.dispatch), payload({})),
        isNull,
      );
      expect(
        frontRecentTurnOf(action('record_observations'), payload({})),
        isNull,
      );
      final user = makeTestMessage(
        id: 'u',
        agentId: frontAgentId,
        kind: AgentMessageKind.user,
        contentEntryId: 'p',
      );
      expect(frontRecentTurnOf(user, payload({'text': null})), isNull);
    });
  });

  test('a payload that is not a dispatch record reads back as nothing', () {
    expect(frontDispatchFromPayload(makeTestMessagePayload()), isNull);
    expect(
      frontDispatchFromPayload(
        makeTestMessagePayload(content: const {'segments': <Object?>[]}),
      )?.segments,
      isEmpty,
    );
  });

  group('a question about what is due', () {
    test(
      'is answered from the due tasks of today, each named as a link',
      () async {
        final task = makeGardenTask();
        final dueToday = task.copyWith(
          data: task.data.copyWith(due: DateTime(2026, 11, 2, 17)),
        );
        when(
          () => journalDb.getTasksDueOnOrBefore(any()),
        ).thenAnswer((_) async => [dueToday]);
        seedMessage();
        String? listed;
        conversationRepository.maxDelegateCalls = 1;
        stubModel(
          (_) => [
            call('list_due_tasks', {'which': 'today'}),
            call('reply_to_user', {'message': 'Due today: task:garden.'}),
          ],
        );
        when(
          () => manager.addToolResponse(
            toolCallId: 'call-list_due_tasks',
            response: any(named: 'response'),
          ),
        ).thenAnswer((invocation) {
          listed = invocation.namedArguments[#response] as String;
        });

        final result = await withClock(
          Clock.fixed(DateTime(2026, 11, 2, 9)),
          run,
        );

        expect(result.success, isTrue);
        // Today's local midnight: the read covers the day and what is overdue
        // (the index's corpus reads due tasks too, by its own clock).
        expect(
          verify(
            () => journalDb.getTasksDueOnOrBefore(captureAny()),
          ).captured,
          contains(DateTime(2026, 11, 2)),
        );
        expect(
          listed,
          contains('task:garden | Garden | OPEN | due 2026-11-02'),
        );
        final reply = upserts
            .whereType<AgentMessagePayloadEntity>()
            .singleWhere(
              (p) => p.content.containsKey('text') && p.agentId == frontAgentId,
            );
        expect(
          reply.content['text'],
          'Due today: [Garden](lotti://task/garden).',
        );
        // No time was summed: nothing to chart.
        expect(reply.content.containsKey('loggedTime'), isFalse);
        // Which window the list was read from: the label over her list.
        expect(reply.content['dueTasks'], {
          'window': 'today',
          'today': '2026-11-02',
          'through': '2026-11-02',
        });
      },
    );

    test('the chips the turn was sent with narrow her index and her due '
        'list, and the categories are named to her', () async {
      final task = makeGardenTask();
      final overdueAtHome = task.copyWith(
        meta: task.meta.copyWith(id: 'dishes', categoryId: 'home'),
        data: task.data.copyWith(title: 'Dishes', due: DateTime(2026, 11)),
      );
      final overdueAtWork = task.copyWith(
        data: task.data.copyWith(due: DateTime(2026, 10, 30)),
      );
      when(
        () => journalDb.getTasksDueOnOrBefore(any()),
      ).thenAnswer((_) async => [overdueAtHome, overdueAtWork]);
      seedMessage(chips: ['home']);
      String? prompt;
      String? listed;
      stubModel(
        (_) => [
          call('list_due_tasks', {'which': 'overdue'}),
          call('reply_to_user', {'message': 'Overdue at home: task:dishes.'}),
        ],
        onMessage: (message) => prompt ??= message,
      );
      when(
        () => manager.addToolResponse(
          toolCallId: 'call-list_due_tasks',
          response: any(named: 'response'),
        ),
      ).thenAnswer((invocation) {
        listed = invocation.namedArguments[#response] as String;
      });

      final result = await withClock(
        Clock.fixed(DateTime(2026, 11, 2, 9)),
        () => run(
          agentIdentity: makeTestIdentity(
            id: frontAgentId,
            agentId: frontAgentId,
            kind: AgentKinds.frontAgent,
            allowedCategoryIds: {'work', 'home'},
          ),
        ),
      );

      expect(result.success, isTrue);
      verify(
        () => journalDb.getOpenTasksForDayAgentCorpus(
          categoryIds: {'home'},
          limit: any(named: 'limit'),
        ),
      ).called(1);
      expect(
        prompt,
        contains(
          '## Categories (2; this conversation is narrowed to the chosen '
          'ones)\n- category:home | Home | chosen\n- category:work | Work\n',
        ),
      );
      expect(
        listed,
        'Open tasks overdue (due before 2026-11-02) (1):\n'
        '- task:dishes | Dishes | OPEN | due 2026-11-01 | Home',
      );
    });

    test(
      'a what-did-I-complete question lists the tasks closed in the '
      'window by when they closed, inside the chips, never dispatched',
      () async {
        final garden = makeGardenTask();
        final open = garden.data.status;
        // Created in October, completed yesterday: listed for yesterday.
        final done = TaskStatus.done(
          id: 'done',
          createdAt: DateTime(2026, 11, 1, 16),
          utcOffset: 0,
        );
        final dishes = garden.copyWith(
          meta: garden.meta.copyWith(id: 'dishes', categoryId: 'home'),
          data: garden.data.copyWith(
            title: 'Dishes',
            status: done,
            statusHistory: [open, done],
          ),
        );
        // Completed yesterday too, but outside the chips.
        final report = dishes.copyWith(
          meta: dishes.meta.copyWith(id: 'report', categoryId: 'work'),
          data: dishes.data.copyWith(title: 'Report'),
        );
        when(
          () => journalDb.getTasksUpdatedSince(any()),
        ).thenAnswer((_) async => [dishes, report]);
        seedMessage(chips: ['home']);
        String? listed;
        stubModel(
          (_) => [
            call('list_closed_tasks', {'period': 'yesterday'}),
            call('reply_to_user', {
              'message': 'Yesterday you completed:\n- Dishes',
            }),
          ],
        );
        when(
          () => manager.addToolResponse(
            toolCallId: 'call-list_closed_tasks',
            response: any(named: 'response'),
          ),
        ).thenAnswer((invocation) {
          listed = invocation.namedArguments[#response] as String;
        });

        final result = await withClock(
          Clock.fixed(DateTime(2026, 11, 2, 9)),
          () => run(
            agentIdentity: makeTestIdentity(
              id: frontAgentId,
              agentId: frontAgentId,
              kind: AgentKinds.frontAgent,
              allowedCategoryIds: {'work', 'home'},
            ),
          ),
        );

        expect(result.success, isTrue);
        verify(
          () => journalDb.getTasksUpdatedSince(DateTime(2026, 11)),
        ).called(1);
        expect(
          listed,
          'Tasks completed or rejected yesterday (2026-11-01): 1 '
          '(1 completed, 0 rejected), oldest first:\n'
          '- task:dishes | Dishes | completed 2026-11-01 | Home',
        );
        final reply = upserts.whereType<AgentMessageEntity>().singleWhere(
          (m) => m.id == frontAgentReplyMessageId(frontAgentId, runKey),
        );
        expect(reply.metadata.toolName, AgentConversationToolNames.replyToUser);
        // Her reply stores every task found, drawn as cards under her words.
        final payload = upserts
            .whereType<AgentMessagePayloadEntity>()
            .singleWhere(
              (p) => p.content.containsKey('text') && p.agentId == frontAgentId,
            );
        expect(payload.content['closedTasks'], [
          {
            'id': 'dishes',
            'title': 'Dishes',
            'closedAt': DateTime(2026, 11, 1, 16).toUtc().toIso8601String(),
            'categoryId': 'home',
          },
        ]);
        expect(
          upserts.whereType<AgentMessageEntity>().where(
            (m) => m.id == frontAgentDispatchMessageId(frontAgentId, runKey),
          ),
          isEmpty,
        );
      },
    );

    test("a time question is summed from the journal over yesterday's local "
        'day inside the chips and answered in her words', () async {
      when(
        () => journalDb.insightsTimeRows(
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      ).thenAnswer(
        (_) async => [
          (
            entryId: 'e1',
            dateFrom: DateTime(2026, 11, 1, 9),
            dateTo: DateTime(2026, 11, 1, 10, 30),
            categoryId: 'home',
          ),
          (
            entryId: 'e2',
            dateFrom: DateTime(2026, 11, 1, 11),
            dateTo: DateTime(2026, 11, 1, 13),
            categoryId: 'work',
          ),
        ],
      );
      // The home entry was logged on a task: it is listed with its time.
      final garden = makeGardenTask();
      final dishes = garden.copyWith(
        meta: garden.meta.copyWith(id: 'dishes', categoryId: 'home'),
        data: garden.data.copyWith(title: 'Dishes'),
      );
      when(() => journalDb.basicLinksForEntryIds({'e1'})).thenAnswer(
        (_) async => [
          EntryLink.basic(
            id: 'dishes>e1',
            fromId: 'dishes',
            toId: 'e1',
            createdAt: DateTime(2026, 11),
            updatedAt: DateTime(2026, 11),
            vectorClock: null,
          ),
        ],
      );
      when(
        () => journalDb.getJournalEntitiesForIdsUnordered({'dishes'}),
      ).thenAnswer((_) async => [dishes]);
      when(
        () => journalDb.getProjectIdMapForTasks({'dishes'}),
      ).thenAnswer((_) async => const {});
      seedMessage(chips: ['home']);
      String? summed;
      stubModel(
        (_) => [
          call('summarize_logged_time', {
            'period': 'yesterday',
            'tasks': true,
          }),
          call('reply_to_user', {'message': 'Yesterday: 1h 30m on Home.'}),
        ],
      );
      when(
        () => manager.addToolResponse(
          toolCallId: 'call-summarize_logged_time',
          response: any(named: 'response'),
        ),
      ).thenAnswer((invocation) {
        summed = invocation.namedArguments[#response] as String;
      });

      final result = await withClock(
        Clock.fixed(DateTime(2026, 11, 2, 9)),
        () => run(
          agentIdentity: makeTestIdentity(
            id: frontAgentId,
            agentId: frontAgentId,
            kind: AgentKinds.frontAgent,
            allowedCategoryIds: {'work', 'home'},
          ),
        ),
      );

      expect(result.success, isTrue);
      verify(
        () => journalDb.insightsTimeRows(
          start: DateTime(2026, 11),
          end: DateTime(2026, 11, 2),
        ),
      ).called(1);
      expect(
        summed,
        'Time logged yesterday (2026-11-01): 1h 30m in total, by category, '
        'largest first:\n'
        '- Home: 1h 30m\n'
        'Tasks the time went to (1), largest first:\n'
        '- task:dishes | Dishes | OPEN | last logged 2026-11-01 | 1h 30m',
      );
      final reply = upserts.whereType<AgentMessageEntity>().singleWhere(
        (m) => m.id == frontAgentReplyMessageId(frontAgentId, runKey),
      );
      expect(reply.metadata.toolName, AgentConversationToolNames.replyToUser);
      // Her reply stores what to chart — the day summed, inside the chips —
      // never the figures.
      final payload = upserts
          .whereType<AgentMessagePayloadEntity>()
          .singleWhere(
            (p) => p.content.containsKey('text') && p.agentId == frontAgentId,
          );
      expect(payload.content['loggedTime'], {
        'startDay': epochDay(DateTime(2026, 11)),
        'endDayExclusive': epochDay(DateTime(2026, 11, 2)),
        'categoryIds': ['home'],
      });
      expect(
        upserts.whereType<AgentMessageEntity>().where(
          (m) => m.id == frontAgentDispatchMessageId(frontAgentId, runKey),
        ),
        isEmpty,
      );
    });

    test('a pull request question is counted from what the device stores '
        'and her reply keeps what to chart, never the figures', () async {
      when(() => journalDb.pullRequestStatRows()).thenAnswer(
        (_) async => [
          (
            entryId: 'pr-entry',
            key: 'penguin/colony#7',
            taskCategoryId: 'home',
            title: 'Fish ledger',
            authorLogin: 'pingu',
            createdAt: DateTime.utc(2026, 11, 1, 10),
            mergedAt: null,
            additions: 120,
            deletions: 30,
          ),
        ],
      );
      seedMessage(chips: ['home']);
      String? counted;
      stubModel(
        (_) => [
          call('summarize_pull_requests', {'pastDays': 14}),
          call('reply_to_user', {
            'message': 'You created 1 PR adding 120 lines and deleting 30.',
          }),
        ],
      );
      when(
        () => manager.addToolResponse(
          toolCallId: 'call-summarize_pull_requests',
          response: any(named: 'response'),
        ),
      ).thenAnswer((invocation) {
        counted = invocation.namedArguments[#response] as String;
      });

      final result = await withClock(
        Clock.fixed(DateTime(2026, 11, 2, 9)),
        () => run(
          agentIdentity: makeTestIdentity(
            id: frontAgentId,
            agentId: frontAgentId,
            kind: AgentKinds.frontAgent,
            allowedCategoryIds: {'work', 'home'},
          ),
        ),
      );

      expect(result.success, isTrue);
      expect(counted, contains('- opened: 1, +120 -30 lines'));
      final payload = upserts
          .whereType<AgentMessagePayloadEntity>()
          .singleWhere(
            (p) => p.content.containsKey('text') && p.agentId == frontAgentId,
          );
      expect(payload.content['pullRequests'], {
        'startDay': epochDay(DateTime(2026, 10, 20)),
        'endDayExclusive': epochDay(DateTime(2026, 11, 3)),
        'categoryIds': ['home'],
      });
      expect(payload.content.containsKey('loggedTime'), isFalse);
    });
  });

  group('a question', () {
    test('is persisted as its own record with the options', () async {
      seedMessage();
      stubModel(
        (_) => [
          call('ask_user', {
            'question': 'The garden task?',
            'options': [
              {'kind': 'task', 'id': 'garden', 'label': 'Garden'},
            ],
          }),
        ],
      );

      final result = await run();

      expect(result.success, isTrue);
      final ask = upserts.whereType<AgentMessageEntity>().singleWhere(
        (m) => m.id == frontAgentAskMessageId(frontAgentId, runKey),
      );
      expect(ask.metadata.toolName, FrontAgentToolNames.askUser);
      final payload = upserts
          .whereType<AgentMessagePayloadEntity>()
          .singleWhere(
            (p) => p.id == ask.contentEntryId,
          );
      expect(payload.content['question'], 'The garden task?');
      expect(payload.content['options'], [
        {'kind': 'task', 'id': 'garden', 'label': 'Garden'},
      ]);
      expect(
        upserts.whereType<AgentMessageEntity>().where(
          (m) => m.metadata.toolName == FrontAgentToolNames.dispatch,
        ),
        isEmpty,
      );
    });
  });

  group('consumption accounting', () {
    late MockAiAttributionService attribution;

    setUp(() {
      attribution = MockAiAttributionService();
      getIt
        ..registerSingleton<AiInteractionCapture>(MockAiInteractionCapture())
        ..registerSingleton<AiAttributionService>(attribution);
      addTearDown(getIt.reset);
      // The envelope's preparation fails: the helper contains that, so
      // bookkeeping can never fail or re-run a wake.
      when(
        () => attribution.prepareCompletion(
          attributionId: any(named: 'attributionId'),
          outputs: any(named: 'outputs'),
          status: any(named: 'status'),
          errorCode: any(named: 'errorCode'),
          errorSummary: any(named: 'errorSummary'),
        ),
      ).thenThrow(StateError('no envelope'));
    });

    test('a routed turn is attributed to the front agent and its envelope '
        'closed carrierless', () async {
      seedMessage();
      stubModel((_) => [call('dispatch', dispatchArgs())]);

      final result = await run();

      expect(result.success, isTrue);
      expect(conversationRepository.lastConsumptionAgentId, frontAgentId);
      expect(conversationRepository.lastConsumptionWakeRunKey, runKey);
      expect(conversationRepository.lastConsumptionThreadId, threadId);
      verify(
        () => attribution.prepareCompletion(
          attributionId: any(named: 'attributionId'),
          outputs: any(named: 'outputs'),
          status: AiWorkStatus.partial,
          errorCode: 'output_carrier_unavailable',
          errorSummary: any(named: 'errorSummary'),
        ),
      ).called(1);
    });

    test('a failed turn closes its envelope as failed', () async {
      seedMessage();
      syncService.transactionDelegate = <T>(action) async {
        throw StateError('database closed');
      };
      stubModel((_) => [call('dispatch', dispatchArgs())]);

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
  });

  test('the tail carries only the last six turns', () async {
    seedMessage();
    String? sent;
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
          sent = message;
          when(() => manager.turnCount).thenReturn(1);
          await (strategy! as FrontAgentStrategy).processToolCalls(
            toolCalls: [call('dispatch', dispatchArgs())],
            manager: manager,
          );
          return null;
        };
    when(() => repository.getAgentMessages(frontAgentId)).thenAnswer(
      (_) async => [
        for (var i = 1; i <= 8; i++)
          makeTestMessage(
            id: 'turn-$i',
            agentId: frontAgentId,
            kind: AgentMessageKind.user,
            contentEntryId: 'turn-$i-payload',
            createdAt: DateTime(2026, 10, 22, i),
          ),
      ],
    );
    when(() => repository.getEntitiesByIds(any())).thenAnswer((
      invocation,
    ) async {
      final ids = invocation.positionalArguments.first as Set<String>;
      return {
        for (final id in ids)
          id: makeTestMessagePayload(
            id: id,
            agentId: frontAgentId,
            content: {'text': 'said in $id'},
          ),
      };
    });

    await run();

    expect(sent, isNot(contains('turn-1-payload')));
    expect(sent, isNot(contains('turn-2-payload')));
    expect(sent, contains('- user: said in turn-3-payload'));
    expect(sent, contains('- user: said in turn-8-payload'));
  });

  group('failure handling', () {
    test(
      'an unresolvable inference setup fails before building anything',
      () async {
        seedMessage();
        when(
          () => aiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => const []);

        final result = await run();

        expect(result.success, isFalse);
        expect(
          FrontTurnFailure.fromWakeError(result.error),
          FrontTurnFailure.noModel,
        );
        verifyNever(
          () => journalDb.getOpenTasksForDayAgentCorpus(
            categoryIds: any(named: 'categoryIds'),
            limit: any(named: 'limit'),
          ),
        );
      },
    );

    /// Every record the transaction wrote is readable afterwards — the
    /// marker a committed-then-failed-flush turn is recognised by.
    void committedRecordsAreReadable() {
      when(() => repository.getEntity(any())).thenAnswer((invocation) async {
        final id = invocation.positionalArguments.first as String;
        for (final message in upserts.whereType<AgentMessageEntity>()) {
          if (message.id == id) return message;
        }
        return null;
      });
      seedMessage();
    }

    test(
      'a persistence failure after the records committed is contained — '
      'a dispatch with its reply',
      () async {
        seedMessage();
        stubModel(
          (_) => [
            call('reply_to_user', {'message': 'Filed.'}),
            call('dispatch', dispatchArgs()),
          ],
        );
        syncService.transactionDelegate = commitThenThrowTransaction;
        committedRecordsAreReadable();

        final result = await run();

        expect(result.success, isTrue);
      },
    );

    test(
      'a persistence failure after the records committed is contained — '
      'a question alone',
      () async {
        seedMessage();
        stubModel(
          (_) => [
            call('ask_user', {'question': 'Which?'}),
          ],
        );
        syncService.transactionDelegate = commitThenThrowTransaction;
        committedRecordsAreReadable();

        final result = await run();

        expect(result.success, isTrue);
      },
    );

    test(
      'a committed dispatch whose reply never landed is not taken for a '
      'committed turn',
      () async {
        seedMessage();
        stubModel(
          (_) => [
            call('reply_to_user', {'message': 'Filed.'}),
            call('dispatch', dispatchArgs()),
          ],
        );
        syncService.transactionDelegate = commitThenThrowTransaction;
        committedRecordsAreReadable();
        // The reply record is the one that cannot be read back.
        when(
          () => repository.getEntity(
            frontAgentReplyMessageId(frontAgentId, runKey),
          ),
        ).thenAnswer((_) async => null);

        final result = await run();

        expect(result.success, isFalse);
      },
    );

    test(
      'a persistence failure before anything committed fails the wake',
      () async {
        seedMessage();
        stubModel((_) => [call('dispatch', dispatchArgs())]);
        syncService.transactionDelegate = <T>(action) async {
          throw StateError('database closed');
        };

        final result = await run();

        expect(result.success, isFalse);
        expect(result.error, contains('StateError'));
        // A database failure is not the provider's: no provider line.
        expect(
          FrontTurnFailure.fromWakeError(result.error),
          FrontTurnFailure.unknown,
        );
      },
    );

    test('a provider error names its cause, never its message', () async {
      seedMessage();
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
          }) async => throw Exception(
            'Mistral API error (HTTP 429, type=rate_limited, secret body)',
          );

      final result = await run();

      expect(result.success, isFalse);
      expect(
        FrontTurnFailure.fromWakeError(result.error),
        FrontTurnFailure.rateLimit,
      );
      expect(result.error, isNot(contains('secret body')));
    });
  });

  group('latency', () {
    test(
      'her calls go through the stall guard, keyed to her prompt cache',
      () async {
        seedMessage();
        Object? sentThrough;
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
              sentThrough = inferenceRepo;
              when(() => manager.turnCount).thenReturn(1);
              await (strategy! as FrontAgentStrategy).processToolCalls(
                toolCalls: [
                  call('reply_to_user', {'message': 'Hi.'}),
                ],
                manager: manager,
              );
              return null;
            };

        await run();

        final guard = sentThrough! as FrontInferenceStallGuard;
        expect(guard.stallTimeout, frontInferenceStallTimeout);
        expect(
          (guard.delegate as CloudInferenceWrapper).promptCacheKey,
          frontAgentId,
        );

        // A resend is logged, so a stall shows up beside the timings.
        guard.onRetry!();
        verify(
          () => domainLogger.log(
            LogDomain.agentWorkflow,
            'front turn provider call stalled; sending it again',
            subDomain: 'frontAgent',
          ),
        ).called(1);
      },
    );

    test('one log line says where the turn spent its time', () async {
      seedMessage();
      stubModel((_) => [call('dispatch', dispatchArgs())]);

      await run();

      final line =
          verify(
                () => domainLogger.log(
                  LogDomain.agentWorkflow,
                  captureAny(that: startsWith('front turn timings:')),
                  subDomain: 'frontAgent',
                ),
              ).captured.single
              as String;
      expect(
        line,
        matches(
          RegExp(
            r'^front turn timings: model=\d+ms index=\d+ms history=\d+ms '
            r'inference\(calls=1\)=\d+ms persist=\d+ms total=\d+ms$',
          ),
        ),
      );
    });

    test('a failed turn logs its timings with the failure', () async {
      seedMessage();
      when(() => repository.getAgentMessages(any())).thenThrow(
        StateError('database closed'),
      );

      await run();

      final line =
          verify(
                () => domainLogger.log(
                  LogDomain.agentWorkflow,
                  captureAny(that: startsWith('front turn timings:')),
                  subDomain: 'frontAgent',
                ),
              ).captured.single
              as String;
      expect(line, contains('index='));
      expect(line, isNot(contains('history=')));
      expect(line, contains('failed=unknown'));
    });
  });

  test('the turn names the weekday beside the clock, so "this weekend" is '
      'read off it rather than worked out', () {
    expect(
      renderFrontTurn(
        index: FrontRoutingIndex(),
        recent: const [],
        input: 'what was closed in @Lotti this weekend',
        now: DateTime(2026, 11, 8, 18),
      ),
      contains(
        '<current_local_time>2026-11-08T18:00:00.000 (Sunday)</current_local_time>',
      ),
    );
  });
}

typedef WakeResultLike = ({bool success, String? error});

/// The one open task of the test world.
Task makeGardenTask() {
  final stamp = DateTime(2026, 10);
  final status = TaskStatus.open(id: 's', createdAt: stamp, utcOffset: 0);
  return JournalEntity.task(
        meta: Metadata(
          id: 'garden',
          createdAt: stamp,
          updatedAt: stamp,
          dateFrom: stamp,
          dateTo: stamp,
          categoryId: 'work',
        ),
        data: TaskData(
          status: status,
          statusHistory: [status],
          dateFrom: stamp,
          dateTo: stamp,
          title: 'Garden',
        ),
      )
      as Task;
}
