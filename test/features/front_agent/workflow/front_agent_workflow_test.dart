import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/front_chat_tokens.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/ai_attribution.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/service/front_routing_index_builder.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_strategy.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_workflow.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';
import '../../agents/workflow/task_agent_workflow_test_helpers.dart';

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
  void seedMessage({String messageId = 'msg-1', String? text = input}) {
    final payload = makeTestMessagePayload(
      id: 'payload-1',
      agentId: frontAgentId,
      content: {'text': ?text},
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
      domainLogger: MockDomainLogger(),
    );
  });

  Future<WakeResultLike> run({String messageId = 'msg-1'}) async {
    final result = await workflow.executeUserMessage(
      agentIdentity: identity,
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
      'system prompt is the contract',
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

        await run();

        expect(system, frontAgentSystemPrompt);
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
      expect(result.error, contains('Front agent workflow failed'));
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
        expect(result.error, contains('inference setup is unavailable'));
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
      },
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
