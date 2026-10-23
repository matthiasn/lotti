import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/service/front_routing_index_builder.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_strategy.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_workflow.dart';
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
      'the prompt carries the index, the recent turns and the pending '
      'message in that order, and the system prompt is the contract',
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
              createdAt: DateTime(2026, 10, 22, 9),
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
              createdAt: DateTime(2026, 10, 22, 8),
            ),
            makeTestMessage(
              id: 'old-thought',
              agentId: frontAgentId,
              runKey: 'run-0',
            ),
          ],
        );

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
        expect(sent, contains('- user: old-user\n- reply_to_user: old-reply'));
        expect(sent, isNot(contains('old-thought')));
        expect(sent, isNot(contains('old-reply-log')));
        expect(sent, isNot(contains('- user: msg-1')));
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
              return null;
            };

      final result = await run();

      expect(result.success, isTrue);
      expect(messages.last, frontDispatchRepairInstruction);
      expect(conversationRepository.turnBudgets, [
        frontProviderCallsPerTurn,
        frontProviderCallsPerTurn - 1,
      ]);
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

    test(
      'a persistence failure after the record committed is contained',
      () async {
        seedMessage();
        stubModel((_) => [call('dispatch', dispatchArgs())]);
        syncService.transactionDelegate = commitThenThrowTransaction;
        // The committed dispatch record is readable, which is the marker.
        when(() => repository.getEntity(any())).thenAnswer((invocation) async {
          final id = invocation.positionalArguments.first as String;
          if (id == frontAgentDispatchMessageId(frontAgentId, runKey)) {
            return upserts.whereType<AgentMessageEntity>().firstWhere(
              (m) => m.id == id,
            );
          }
          return null;
        });
        seedMessage();

        final result = await run();

        expect(result.success, isTrue);
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
