import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_event.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../ai_consumption/test_utils.dart';

// ChatCompletionMessage is a sealed class and cannot be faked

class FakeChatCompletionMessageToolCall extends Fake
    implements ChatCompletionMessageToolCall {}

class FakeConversationManager extends Fake implements ConversationManager {}

AiInteractionCaptureTestBench _registerInteractionCapture() {
  final bench = AiInteractionCaptureTestBench.create()..register();
  addTearDown(bench.unregister);
  return bench;
}

List<AiConsumptionEvent> _capturedEvents(
  AiInteractionCaptureTestBench bench,
) => verify(
  () => bench.service.recordInteraction(
    attributionId: any(named: 'attributionId'),
    event: captureAny(named: 'event'),
  ),
).captured.cast<AiConsumptionEvent>();

/// Shared 8-argument stub for `generateTextWithMessages`;
/// chain `.thenAnswer(...)` with the stream (or function) the test needs.
When<Stream<CreateChatCompletionStreamResponse>> _stubGenerateText(
  MockOllamaInferenceRepository mock,
) {
  return when(
    () => mock.generateTextWithMessages(
      messages: any(named: 'messages'),
      model: any(named: 'model'),
      provider: any(named: 'provider'),
      tools: any(named: 'tools'),
      temperature: any(named: 'temperature'),
      thoughtSignatures: any(named: 'thoughtSignatures'),
      signatureCollector: any(named: 'signatureCollector'),
      turnIndex: any(named: 'turnIndex'),
      impactCollector: any(named: 'impactCollector'),
    ),
  );
}

CreateChatCompletionStreamResponse _deltaResponse(
  ChatCompletionStreamResponseDelta delta,
) => CreateChatCompletionStreamResponse(
  id: 'loop-response',
  choices: [ChatCompletionStreamResponseChoice(index: 0, delta: delta)],
  object: 'chat.completion.chunk',
  created: 1710500000,
);

CreateChatCompletionStreamResponse _contentResponse(String content) =>
    _deltaResponse(ChatCompletionStreamResponseDelta(content: content));

/// [count] complete tool calls in one delta without ids or indices: Gemini's
/// style for two or more, one OpenAI-style call without an id for one. Either
/// way the repository synthesizes the ids.
CreateChatCompletionStreamResponse _idlessToolCallsResponse(int count) =>
    _deltaResponse(
      ChatCompletionStreamResponseDelta(
        toolCalls: [
          for (var i = 0; i < count; i++)
            ChatCompletionStreamMessageToolCallChunk(
              type: ChatCompletionStreamMessageToolCallChunkType.function,
              function: ChatCompletionStreamMessageFunctionCall(
                name: 'tool_$i',
                arguments: '{"n":$i}',
              ),
            ),
        ],
      ),
    );

/// The history of a send whose one tool round nobody ran (no strategy, or
/// one that did not answer): the user turn, the assistant's [calls] as
/// (id, name, arguments), and one [unansweredToolCallResult] per call.
void _expectToolRoundNotRun(
  ConversationManager? manager,
  List<(String, String, String)> calls,
) {
  final messages = manager!.messages;
  expect(messages.map((m) => m.role), [
    ChatCompletionMessageRole.user,
    ChatCompletionMessageRole.assistant,
    for (final _ in calls) ChatCompletionMessageRole.tool,
  ]);
  expect(
    messages[1]
        .mapOrNull(assistant: (assistant) => assistant.toolCalls)
        ?.map((c) => (c.id, c.function.name, c.function.arguments)),
    calls,
  );
  expect(
    messages
        .skip(2)
        .map((m) => m.mapOrNull(tool: (t) => (t.toolCallId, t.content))),
    [for (final call in calls) (call.$1, unansweredToolCallResult)],
  );
}

/// What a strict provider rejects in a request's history: the request-time
/// invariants of `specs/tla/ConversationLoop.tla` (`OpensWithUserTurn`,
/// `NoOrphanResult`, `EveryCallAnswered`).
List<String> _protocolFaults(List<ChatCompletionMessage> messages) {
  final faults = <String>[];
  final turns = messages
      .where((message) => message.role != ChatCompletionMessageRole.system)
      .toList();
  if (turns.isNotEmpty && turns.first.role != ChatCompletionMessageRole.user) {
    faults.add('opens with ${turns.first.role.name}');
  }
  var roundIds = <String>{};
  var open = <String>{};
  for (final message in turns) {
    final result = message.mapOrNull(tool: (tool) => tool.toolCallId);
    if (result != null) {
      if (!roundIds.contains(result)) faults.add('orphan result $result');
      open.remove(result);
      continue;
    }
    if (open.isNotEmpty) faults.add('unanswered $open');
    roundIds = {
      ...?message
          .mapOrNull(assistant: (assistant) => assistant.toolCalls)
          ?.map((call) => call.id),
    };
    open = {...roundIds};
  }
  if (open.isNotEmpty) faults.add('unanswered $open');
  return faults;
}

/// One adversarial wake: the model calls `callsPerRound[r]` tools in round r
/// (cycling), and the strategy answers every call and always continues, like
/// a task agent that never calls `update_report`. The provider fails every
/// request past [requestCap], so a loop without a working limit ends too.
Future<({List<List<ChatCompletionMessage>> requests, List<String> ids})>
_runAdversarialWake({
  required ConversationRepository repository,
  required AiConfigInferenceProvider provider,
  required int maxTurns,
  required List<int> callsPerRound,
  int requestCap = 60,
}) async {
  final requests = <List<ChatCompletionMessage>>[];
  final ids = <String>[];
  final inference = MockOllamaInferenceRepository();
  final strategy = MockConversationStrategy();
  _stubGenerateText(inference).thenAnswer((invocation) {
    requests.add(
      invocation.namedArguments[#messages] as List<ChatCompletionMessage>,
    );
    if (requests.length > requestCap) {
      return Stream.error(StateError('runaway loop'));
    }
    return Stream.value(
      _idlessToolCallsResponse(
        callsPerRound[(requests.length - 1) % callsPerRound.length],
      ),
    );
  });
  when(
    () => strategy.processToolCalls(
      toolCalls: any(named: 'toolCalls'),
      manager: any(named: 'manager'),
    ),
  ).thenAnswer((invocation) async {
    final manager = invocation.namedArguments[#manager] as ConversationManager;
    for (final call
        in invocation.namedArguments[#toolCalls]
            as List<ChatCompletionMessageToolCall>) {
      ids.add(call.id);
      manager.addToolResponse(toolCallId: call.id, response: 'ok');
    }
    return ConversationAction.continueConversation;
  });
  when(() => strategy.getContinuationPrompt(any())).thenReturn('Continue.');

  await repository.sendMessage(
    conversationId: repository.createConversation(
      systemMessage: 'system',
      maxTurns: maxTurns,
    ),
    message: 'wake',
    model: 'test-model',
    provider: provider,
    inferenceRepo: inference,
    strategy: strategy,
  );
  return (requests: requests, ids: ids);
}

void main() {
  late ProviderContainer container;
  late ConversationRepository repository;
  late MockOllamaInferenceRepository mockOllamaRepo;
  late MockConversationStrategy mockStrategy;

  setUpAll(() {
    registerAllFallbackValues();
    // registerFallbackValue(FakeChatCompletionMessage()); // Not needed as ChatCompletionMessage is sealed
    registerFallbackValue(FakeChatCompletionMessageToolCall());
    registerFallbackValue(FakeAiConfigInferenceProvider());
    registerFallbackValue(FakeConversationManager());
    registerFallbackValue(ThoughtSignatureCollector());
    registerFallbackValue(<String, String>{});
    registerFallbackValue(fallbackAiConsumptionEvent);
  });

  setUp(() {
    container = ProviderContainer();
    repository = container.read(conversationRepositoryProvider.notifier);
    mockOllamaRepo = MockOllamaInferenceRepository();
    mockStrategy = MockConversationStrategy();
  });

  tearDown(() {
    container.dispose();
  });

  group('ConversationRepository', () {
    test('createConversation creates new conversation with unique ID', () {
      final id1 = repository.createConversation();
      final id2 = repository.createConversation();

      expect(id1, isNotEmpty);
      expect(id2, isNotEmpty);
      expect(id1, isNot(equals(id2)));

      final manager1 = repository.getConversation(id1);
      final manager2 = repository.getConversation(id2);

      expect(manager1, isNotNull);
      expect(manager2, isNotNull);
      expect(manager1, isNot(equals(manager2)));
    });

    test('createConversation with system message', () {
      const systemMessage = 'You are a helpful assistant';
      final id = repository.createConversation(systemMessage: systemMessage);
      final manager = repository.getConversation(id);

      expect(manager, isNotNull);
      expect(manager!.messages.length, 1);
      expect(manager.messages.first.role, ChatCompletionMessageRole.system);
      expect(manager.messages.first.content, systemMessage);
    });

    test('createConversation with custom maxTurns', () {
      final id = repository.createConversation(maxTurns: 5);
      final manager = repository.getConversation(id);

      expect(manager, isNotNull);
      expect(manager!.maxTurns, 5);
    });

    test('getConversation returns null for non-existent ID', () {
      final manager = repository.getConversation('non-existent');
      expect(manager, isNull);
    });

    test('deleteConversation removes conversation', () {
      final id = repository.createConversation();
      var manager = repository.getConversation(id);
      expect(manager, isNotNull);

      repository.deleteConversation(id);
      manager = repository.getConversation(id);
      expect(manager, isNull);
    });

    test('dispose cleans up all conversations', () {
      // Create conversations
      final ids = <String>[];
      for (var i = 0; i < 3; i++) {
        ids.add(repository.createConversation());
      }

      // Dispose container (which calls repository's dispose)
      container.dispose();

      // Create new container
      container = ProviderContainer();
      repository = container.read(conversationRepositoryProvider.notifier);

      // Check all conversations are gone by trying to get each one
      for (final id in ids) {
        expect(repository.getConversation(id), isNull);
      }
    });

    group('sendMessage', () {
      late String conversationId;
      late AiConfigInferenceProvider provider;

      setUp(() {
        conversationId = repository.createConversation();
        provider = AiConfigInferenceProvider(
          id: 'test-provider',
          name: 'Test Provider',
          baseUrl: 'http://localhost:11434',
          apiKey: '',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inferenceProviderType: InferenceProviderType.ollama,
        );
      });

      test('throws error for non-existent conversation', () async {
        expect(
          () => repository.sendMessage(
            conversationId: 'non-existent',
            message: 'Hello',
            model: 'test-model',
            provider: provider,
            inferenceRepo: mockOllamaRepo,
          ),
          throwsArgumentError,
        );
      });

      test('adds user message and gets response', () async {
        _stubGenerateText(mockOllamaRepo).thenAnswer(
          (_) => Stream.fromIterable([
            const CreateChatCompletionStreamResponse(
              id: 'test-response',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(
                    content: 'Hello, human!',
                  ),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1710500000,
            ),
          ]),
        );

        // Start sendMessage in background
        await repository.sendMessage(
          conversationId: conversationId,
          message: 'Hello, AI!',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
        );

        final manager = repository.getConversation(conversationId)!;
        expect(manager.messages.length, 2);
        expect(manager.messages[0].role, ChatCompletionMessageRole.user);
        expect(manager.messages[1].role, ChatCompletionMessageRole.assistant);
        expect(manager.messages[1].content, 'Hello, human!');
      });

      test('forces temperature 1.0 for OpenAI providers', () async {
        final openAiProvider = AiConfigInferenceProvider(
          id: 'openai-provider',
          name: 'OpenAI',
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'key',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inferenceProviderType: InferenceProviderType.openAi,
        );
        _stubGenerateText(mockOllamaRepo).thenAnswer(
          (_) => Stream.fromIterable([
            const CreateChatCompletionStreamResponse(
              id: 'r',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(content: 'ok'),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1710500000,
            ),
          ]),
        );

        await repository.sendMessage(
          conversationId: conversationId,
          message: 'Hello',
          model: 'gpt-5',
          provider: openAiProvider,
          inferenceRepo: mockOllamaRepo,
          temperature: 0.2,
        );

        final captured = verify(
          () => mockOllamaRepo.generateTextWithMessages(
            messages: any(named: 'messages'),
            model: any(named: 'model'),
            provider: any(named: 'provider'),
            tools: any(named: 'tools'),
            temperature: captureAny(named: 'temperature'),
            thoughtSignatures: any(named: 'thoughtSignatures'),
            signatureCollector: any(named: 'signatureCollector'),
            turnIndex: any(named: 'turnIndex'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).captured;
        expect(captured.single, 1.0);
      });

      test(
        'passes the caller temperature through for non-OpenAI providers',
        () async {
          _stubGenerateText(mockOllamaRepo).thenAnswer(
            (_) => Stream.fromIterable([
              const CreateChatCompletionStreamResponse(
                id: 'r',
                choices: [
                  ChatCompletionStreamResponseChoice(
                    index: 0,
                    delta: ChatCompletionStreamResponseDelta(content: 'ok'),
                  ),
                ],
                object: 'chat.completion.chunk',
                created: 1710500000,
              ),
            ]),
          );

          await repository.sendMessage(
            conversationId: conversationId,
            message: 'Hello',
            model: 'test-model',
            provider: provider,
            inferenceRepo: mockOllamaRepo,
            temperature: 0.2,
          );

          final captured = verify(
            () => mockOllamaRepo.generateTextWithMessages(
              messages: any(named: 'messages'),
              model: any(named: 'model'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
              temperature: captureAny(named: 'temperature'),
              thoughtSignatures: any(named: 'thoughtSignatures'),
              signatureCollector: any(named: 'signatureCollector'),
              turnIndex: any(named: 'turnIndex'),
              impactCollector: any(named: 'impactCollector'),
            ),
          ).captured;
          expect(captured.single, 0.2);
        },
      );

      test('forwards toolChoice to generateTextWithMessages', () async {
        const toolChoice = ChatCompletionToolChoiceOption.tool(
          ChatCompletionNamedToolChoice(
            type: ChatCompletionNamedToolChoiceType.function,
            function: ChatCompletionFunctionCallOption(name: 'update_report'),
          ),
        );

        when(
          () => mockOllamaRepo.generateTextWithMessages(
            messages: any(named: 'messages'),
            model: any(named: 'model'),
            provider: any(named: 'provider'),
            tools: any(named: 'tools'),
            toolChoice: any(named: 'toolChoice'),
            temperature: any(named: 'temperature'),
            thoughtSignatures: any(named: 'thoughtSignatures'),
            signatureCollector: any(named: 'signatureCollector'),
            turnIndex: any(named: 'turnIndex'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable([
            const CreateChatCompletionStreamResponse(
              id: 'r',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(content: 'done'),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1710500000,
            ),
          ]),
        );

        await repository.sendMessage(
          conversationId: conversationId,
          message: 'Force the report',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
          toolChoice: toolChoice,
        );

        final captured = verify(
          () => mockOllamaRepo.generateTextWithMessages(
            messages: any(named: 'messages'),
            model: any(named: 'model'),
            provider: any(named: 'provider'),
            tools: any(named: 'tools'),
            toolChoice: captureAny(named: 'toolChoice'),
            temperature: any(named: 'temperature'),
            thoughtSignatures: any(named: 'thoughtSignatures'),
            signatureCollector: any(named: 'signatureCollector'),
            turnIndex: any(named: 'turnIndex'),
            impactCollector: any(named: 'impactCollector'),
          ),
        ).captured;
        expect(captured.single, toolChoice);
      });

      test(
        'strips <think> blocks from assistant content before persisting',
        () async {
          final streamController =
              StreamController<CreateChatCompletionStreamResponse>();

          _stubGenerateText(
            mockOllamaRepo,
          ).thenAnswer((_) => streamController.stream);

          final sendFuture = repository.sendMessage(
            conversationId: conversationId,
            message: 'Why is the sky blue?',
            model: 'gemma4:e4b',
            provider: provider,
            inferenceRepo: mockOllamaRepo,
          );

          // Stream chunks the way Ollama emits thinking + content:
          // `<think>...</think>` interleaved with the visible answer.
          for (final chunk in const [
            '<think>',
            'private reasoning the user must never see again',
            '</think>',
            'The sky is blue because of Rayleigh scattering.',
          ]) {
            streamController.add(
              CreateChatCompletionStreamResponse(
                id: 'chunk',
                choices: [
                  ChatCompletionStreamResponseChoice(
                    index: 0,
                    delta: ChatCompletionStreamResponseDelta(content: chunk),
                  ),
                ],
                object: 'chat.completion.chunk',
                created: 1710500000,
              ),
            );
          }
          await streamController.close();
          await sendFuture;

          final manager = repository.getConversation(conversationId)!;
          final assistantContent = manager.messages.last.content;
          expect(assistantContent, isNotNull);
          expect(assistantContent, isNot(contains('<think>')));
          expect(assistantContent, isNot(contains('</think>')));
          expect(assistantContent, isNot(contains('private reasoning')));
          expect(
            assistantContent,
            equals('The sky is blue because of Rayleigh scattering.'),
          );
        },
      );

      test('drops assistant content that is only a <think> block', () async {
        _stubGenerateText(mockOllamaRepo).thenAnswer(
          (_) => Stream.fromIterable([
            const CreateChatCompletionStreamResponse(
              id: 'chunk',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(
                    content: '<think>private reasoning</think>',
                  ),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1710500000,
            ),
          ]),
        );

        await repository.sendMessage(
          conversationId: conversationId,
          message: 'Think only',
          model: 'gemma4:e4b',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
        );

        final manager = repository.getConversation(conversationId)!;
        // The assistant turn is still recorded so turn accounting stays
        // accurate, but its persisted content is null instead of a stale
        // `<think>` payload.
        expect(manager.messages.last.role, ChatCompletionMessageRole.assistant);
        expect(manager.messages.last.content, isNull);
      });

      test('handles tool calls', () async {
        _stubGenerateText(mockOllamaRepo).thenAnswer(
          (_) => Stream.fromIterable([
            const CreateChatCompletionStreamResponse(
              id: 'test-response',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(
                    toolCalls: [
                      ChatCompletionStreamMessageToolCallChunk(
                        index: 0,
                        id: 'tool-1',
                        type: ChatCompletionStreamMessageToolCallChunkType
                            .function,
                        function: ChatCompletionStreamMessageFunctionCall(
                          name: 'test_function',
                          arguments: '{"arg": "value"}',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1710500000,
            ),
          ]),
        );

        // Start sendMessage
        await repository.sendMessage(
          conversationId: conversationId,
          message: 'Call a function',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
          tools: [
            const ChatCompletionTool(
              type: ChatCompletionToolType.function,
              function: FunctionObject(
                name: 'test_function',
                description: 'A test function',
              ),
            ),
          ],
        );

        final manager = repository.getConversation(conversationId)!;
        _expectToolRoundNotRun(manager, [
          ('tool-1', 'test_function', '{"arg": "value"}'),
        ]);
      });

      test('handles strategy with continue action', () async {
        final streamController =
            StreamController<CreateChatCompletionStreamResponse>();

        _stubGenerateText(
          mockOllamaRepo,
        ).thenAnswer((_) => streamController.stream);

        when(
          () => mockStrategy.processToolCalls(
            toolCalls: any(named: 'toolCalls'),
            manager: any(named: 'manager'),
          ),
        ).thenAnswer((_) async => ConversationAction.continueConversation);

        when(
          () => mockStrategy.getContinuationPrompt(any()),
        ).thenReturn('Continue processing');

        // Start sendMessage
        final sendFuture = repository.sendMessage(
          conversationId: conversationId,
          message: 'Process with strategy',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
          strategy: mockStrategy,
          tools: [
            const ChatCompletionTool(
              type: ChatCompletionToolType.function,
              function: FunctionObject(
                name: 'test_function',
                description: 'A test function',
              ),
            ),
          ],
        );

        // First response with tool call
        streamController
          ..add(
            const CreateChatCompletionStreamResponse(
              id: 'test-response-1',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(
                    toolCalls: [
                      ChatCompletionStreamMessageToolCallChunk(
                        index: 0,
                        id: 'tool-1',
                        type: ChatCompletionStreamMessageToolCallChunkType
                            .function,
                        function: ChatCompletionStreamMessageFunctionCall(
                          name: 'test_function',
                          arguments: '{"arg": "value"}',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1710500000,
            ),
          )
          // Second response after continuation
          ..add(
            const CreateChatCompletionStreamResponse(
              id: 'test-response-2',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(
                    content: 'Final response',
                  ),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1710500000,
            ),
          );

        await streamController.close();
        await sendFuture;

        verify(
          () => mockStrategy.processToolCalls(
            toolCalls: any(named: 'toolCalls'),
            manager: any(named: 'manager'),
          ),
        ).called(1);
        verify(() => mockStrategy.getContinuationPrompt(any())).called(1);
      });

      test('handles strategy with complete action', () async {
        _stubGenerateText(mockOllamaRepo).thenAnswer(
          (_) => Stream.fromIterable([
            const CreateChatCompletionStreamResponse(
              id: 'test-response',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(
                    toolCalls: [
                      ChatCompletionStreamMessageToolCallChunk(
                        index: 0,
                        id: 'tool-1',
                        type: ChatCompletionStreamMessageToolCallChunkType
                            .function,
                        function: ChatCompletionStreamMessageFunctionCall(
                          name: 'test_function',
                          arguments: '{"arg": "value"}',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1710500000,
            ),
          ]),
        );

        when(
          () => mockStrategy.processToolCalls(
            toolCalls: any(named: 'toolCalls'),
            manager: any(named: 'manager'),
          ),
        ).thenAnswer((_) async => ConversationAction.complete);

        // Start sendMessage
        await repository.sendMessage(
          conversationId: conversationId,
          message: 'Process and complete',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
          strategy: mockStrategy,
          tools: [
            const ChatCompletionTool(
              type: ChatCompletionToolType.function,
              function: FunctionObject(
                name: 'test_function',
                description: 'A test function',
              ),
            ),
          ],
        );

        verify(
          () => mockStrategy.processToolCalls(
            toolCalls: any(named: 'toolCalls'),
            manager: any(named: 'manager'),
          ),
        ).called(1);
        verifyNever(() => mockStrategy.getContinuationPrompt(any()));
      });

      test('handles maximum turns limit', () async {
        // Create conversation with low turn limit
        conversationId = repository.createConversation(maxTurns: 2);

        // Mock all three stream responses upfront
        var callCount = 0;
        _stubGenerateText(mockOllamaRepo).thenAnswer((_) {
          callCount++;
          return Stream.value(
            CreateChatCompletionStreamResponse(
              id: 'response-$callCount',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(
                    content: 'Response $callCount',
                  ),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1710500000,
            ),
          );
        });

        // Send three messages
        await repository.sendMessage(
          conversationId: conversationId,
          message: 'First message',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
        );

        await repository.sendMessage(
          conversationId: conversationId,
          message: 'Second message',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
        );

        // Third message - check if it even processes
        final manager = repository.getConversation(conversationId)!;

        // After 2 turns, canContinue should be false
        expect(manager.canContinue(), false);

        await repository.sendMessage(
          conversationId: conversationId,
          message: 'Third message',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
        );

        // Verify that we're at the turn limit (user message may have been added)
        expect(manager.turnCount, lessThanOrEqualTo(3));
        expect(manager.canContinue(), false);
        expect(manager.lastError, 'Maximum conversation turns reached');

        // Verify that the conversation has the expected number of messages
        // 2 turns = 4 messages (2 user + 2 assistant) + possibly 1 more user message
        expect(manager.messages.length, lessThanOrEqualTo(5));
      });

      test('handles errors during API call', () async {
        // Use the shared 8-argument stub so the matcher includes `turnIndex`
        // (which `sendMessage` always supplies). An inline stub that omits
        // `turnIndex` would fail to match the real call, so the resulting
        // error would come from an unmatched mock rather than the thrown
        // exception under test.
        _stubGenerateText(mockOllamaRepo).thenThrow(Exception('API Error'));

        final manager = repository.getConversation(conversationId)!;

        await repository.sendMessage(
          conversationId: conversationId,
          message: 'This will fail',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
        );

        expect(manager.lastError, contains('API Error'));
      });

      test(
        'handles tool call arguments accumulation with StringBuffer',
        () async {
          final streamController =
              StreamController<CreateChatCompletionStreamResponse>();

          _stubGenerateText(
            mockOllamaRepo,
          ).thenAnswer((_) => streamController.stream);

          final sendFuture = repository.sendMessage(
            conversationId: conversationId,
            message: 'Accumulate tool args',
            model: 'test-model',
            provider: provider,
            inferenceRepo: mockOllamaRepo,
            tools: [
              const ChatCompletionTool(
                type: ChatCompletionToolType.function,
                function: FunctionObject(
                  name: 'test_function',
                  description: 'A test function',
                ),
              ),
            ],
          );

          // First chunk with tool call name and partial arguments
          streamController
            ..add(
              const CreateChatCompletionStreamResponse(
                id: 'test-response',
                choices: [
                  ChatCompletionStreamResponseChoice(
                    index: 0,
                    delta: ChatCompletionStreamResponseDelta(
                      toolCalls: [
                        ChatCompletionStreamMessageToolCallChunk(
                          index: 0,
                          id: 'tool-1',
                          type: ChatCompletionStreamMessageToolCallChunkType
                              .function,
                          function: ChatCompletionStreamMessageFunctionCall(
                            name: 'test_function',
                            arguments: '{"arg',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                object: 'chat.completion.chunk',
                created: 1710500000,
              ),
            )
            // Second chunk with more arguments
            ..add(
              const CreateChatCompletionStreamResponse(
                id: 'test-response',
                choices: [
                  ChatCompletionStreamResponseChoice(
                    index: 0,
                    delta: ChatCompletionStreamResponseDelta(
                      toolCalls: [
                        ChatCompletionStreamMessageToolCallChunk(
                          index: 0,
                          id: 'tool-1',
                          type: ChatCompletionStreamMessageToolCallChunkType
                              .function,
                          function: ChatCompletionStreamMessageFunctionCall(
                            arguments: '": "value"}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                object: 'chat.completion.chunk',
                created: 1710500000,
              ),
            );

          await streamController.close();
          await sendFuture;

          // The fragments reassemble into one call with its complete JSON.
          _expectToolRoundNotRun(repository.getConversation(conversationId), [
            ('tool-1', 'test_function', '{"arg": "value"}'),
          ]);
        },
      );

      test('handles split UTF-8 characters in tool call arguments', () async {
        final streamController =
            StreamController<CreateChatCompletionStreamResponse>();

        _stubGenerateText(
          mockOllamaRepo,
        ).thenAnswer((_) => streamController.stream);

        final sendFuture = repository.sendMessage(
          conversationId: conversationId,
          message: 'Test UTF-8 splitting',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
          tools: [
            const ChatCompletionTool(
              type: ChatCompletionToolType.function,
              function: FunctionObject(
                name: 'test_function',
                description: 'A test function',
              ),
            ),
          ],
        );

        // First chunk ending mid-UTF8 character (emoji 😀 = F0 9F 98 80)
        streamController
          ..add(
            const CreateChatCompletionStreamResponse(
              id: 'test-response',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(
                    toolCalls: [
                      ChatCompletionStreamMessageToolCallChunk(
                        index: 0,
                        id: 'tool-1',
                        type: ChatCompletionStreamMessageToolCallChunkType
                            .function,
                        function: ChatCompletionStreamMessageFunctionCall(
                          name: 'test_function',
                          arguments: '{"emoji": "',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1710500000,
            ),
          )
          // Second chunk with emoji and rest
          ..add(
            const CreateChatCompletionStreamResponse(
              id: 'test-response',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(
                    toolCalls: [
                      ChatCompletionStreamMessageToolCallChunk(
                        index: 0,
                        id: 'tool-1',
                        type: ChatCompletionStreamMessageToolCallChunkType
                            .function,
                        function: ChatCompletionStreamMessageFunctionCall(
                          arguments: '😀"}',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1710500000,
            ),
          );

        await streamController.close();
        await sendFuture;

        // Verify the conversation was updated with proper UTF-8 handling
        final manager = repository.getConversation(conversationId);
        expect(manager, isNotNull);
        _expectToolRoundNotRun(manager, [
          ('tool-1', 'test_function', '{"emoji": "😀"}'),
        ]);
      });

      test('handles invalid tool call with missing function name', () async {
        _stubGenerateText(mockOllamaRepo).thenAnswer(
          (_) => Stream.fromIterable([
            const CreateChatCompletionStreamResponse(
              id: 'test-response',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(
                    toolCalls: [
                      ChatCompletionStreamMessageToolCallChunk(
                        index: 0,
                        id: 'tool-1',
                        type: ChatCompletionStreamMessageToolCallChunkType
                            .function,
                        function: ChatCompletionStreamMessageFunctionCall(
                          arguments: '{"arg": "value"}',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1710500000,
            ),
          ]),
        );

        await repository.sendMessage(
          conversationId: conversationId,
          message: 'Missing function name test',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
          tools: [
            const ChatCompletionTool(
              type: ChatCompletionToolType.function,
              function: FunctionObject(
                name: 'test_function',
                description: 'A test function',
              ),
            ),
          ],
        );

        // Tool call should be added with empty function name
        final manager = repository.getConversation(conversationId);
        expect(manager, isNotNull);
        _expectToolRoundNotRun(manager, [('tool-1', '', '{"arg": "value"}')]);
      });

      test('handles empty tool call IDs', () async {
        final streamController =
            StreamController<CreateChatCompletionStreamResponse>();

        _stubGenerateText(
          mockOllamaRepo,
        ).thenAnswer((_) => streamController.stream);

        final sendFuture = repository.sendMessage(
          conversationId: conversationId,
          message: 'Empty tool call ID',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
          tools: [
            const ChatCompletionTool(
              type: ChatCompletionToolType.function,
              function: FunctionObject(
                name: 'test_function',
                description: 'A test function',
              ),
            ),
          ],
        );

        // First chunk with empty tool call ID
        streamController
          ..add(
            const CreateChatCompletionStreamResponse(
              id: 'test-response',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(
                    toolCalls: [
                      ChatCompletionStreamMessageToolCallChunk(
                        index: 0,
                        id: '', // Empty ID
                        type: ChatCompletionStreamMessageToolCallChunkType
                            .function,
                        function: ChatCompletionStreamMessageFunctionCall(
                          name: 'test_function',
                          arguments: '{"arg": ',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1710500000,
            ),
          )
          // Second chunk completing the arguments
          ..add(
            const CreateChatCompletionStreamResponse(
              id: 'test-response',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(
                    toolCalls: [
                      ChatCompletionStreamMessageToolCallChunk(
                        index: 0,
                        id: '', // Still empty
                        type: ChatCompletionStreamMessageToolCallChunkType
                            .function,
                        function: ChatCompletionStreamMessageFunctionCall(
                          arguments: '"value"}',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1710500000,
            ),
          );

        await streamController.close();
        await sendFuture;

        // Verify the conversation was updated with auto-generated ID
        final manager = repository.getConversation(conversationId);
        expect(manager, isNotNull);
        _expectToolRoundNotRun(manager, [
          ('tool_turn1_0', 'test_function', '{"arg": "value"}'),
        ]);
      });

      test('handles multiple tool calls with separate buffers', () async {
        final streamController =
            StreamController<CreateChatCompletionStreamResponse>();

        _stubGenerateText(
          mockOllamaRepo,
        ).thenAnswer((_) => streamController.stream);

        final sendFuture = repository.sendMessage(
          conversationId: conversationId,
          message: 'Multiple tool calls',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
          tools: [
            const ChatCompletionTool(
              type: ChatCompletionToolType.function,
              function: FunctionObject(
                name: 'function_a',
                description: 'Function A',
              ),
            ),
            const ChatCompletionTool(
              type: ChatCompletionToolType.function,
              function: FunctionObject(
                name: 'function_b',
                description: 'Function B',
              ),
            ),
          ],
        );

        // First chunk with two tool calls
        streamController
          ..add(
            const CreateChatCompletionStreamResponse(
              id: 'test-response',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(
                    toolCalls: [
                      ChatCompletionStreamMessageToolCallChunk(
                        index: 0,
                        id: 'tool-1',
                        type: ChatCompletionStreamMessageToolCallChunkType
                            .function,
                        function: ChatCompletionStreamMessageFunctionCall(
                          name: 'function_a',
                          arguments: '{"a": ',
                        ),
                      ),
                      ChatCompletionStreamMessageToolCallChunk(
                        index: 1,
                        id: 'tool-2',
                        type: ChatCompletionStreamMessageToolCallChunkType
                            .function,
                        function: ChatCompletionStreamMessageFunctionCall(
                          name: 'function_b',
                          arguments: '{"b": ',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1710500000,
            ),
          )
          // Second chunk completing both
          ..add(
            const CreateChatCompletionStreamResponse(
              id: 'test-response',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(
                    toolCalls: [
                      ChatCompletionStreamMessageToolCallChunk(
                        index: 0,
                        id: 'tool-1',
                        type: ChatCompletionStreamMessageToolCallChunkType
                            .function,
                        function: ChatCompletionStreamMessageFunctionCall(
                          arguments: '1}',
                        ),
                      ),
                      ChatCompletionStreamMessageToolCallChunk(
                        index: 1,
                        id: 'tool-2',
                        type: ChatCompletionStreamMessageToolCallChunkType
                            .function,
                        function: ChatCompletionStreamMessageFunctionCall(
                          arguments: '2}',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1710500000,
            ),
          );

        await streamController.close();
        await sendFuture;

        // Verify both tool calls were accumulated separately
        final manager = repository.getConversation(conversationId);
        expect(manager, isNotNull);
        _expectToolRoundNotRun(manager, [
          ('tool-1', 'function_a', '{"a": 1}'),
          ('tool-2', 'function_b', '{"b": 2}'),
        ]);
      });

      test(
        'handles Gemini-style multiple complete tool calls in one chunk',
        () async {
          _stubGenerateText(mockOllamaRepo).thenAnswer(
            (_) => Stream.fromIterable([
              const CreateChatCompletionStreamResponse(
                id: 'gemini-response',
                choices: [
                  ChatCompletionStreamResponseChoice(
                    index: 0,
                    delta: ChatCompletionStreamResponseDelta(
                      toolCalls: [
                        // First tool call - empty ID, null index, complete arguments
                        ChatCompletionStreamMessageToolCallChunk(
                          id: '', // Empty ID
                          // index is null (not specified)
                          type: ChatCompletionStreamMessageToolCallChunkType
                              .function,
                          function: ChatCompletionStreamMessageFunctionCall(
                            name: 'function_a',
                            arguments: '{"param": "value1"}',
                          ),
                        ),
                        // Second tool call - empty ID, null index, complete arguments
                        ChatCompletionStreamMessageToolCallChunk(
                          id: '', // Empty ID
                          // index is null (not specified)
                          type: ChatCompletionStreamMessageToolCallChunkType
                              .function,
                          function: ChatCompletionStreamMessageFunctionCall(
                            name: 'function_b',
                            arguments: '{"param": "value2"}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                object: 'chat.completion.chunk',
                created: 1710500000,
              ),
            ]),
          );

          await repository.sendMessage(
            conversationId: conversationId,
            message: 'Gemini-style tool calls',
            model: 'test-model',
            provider: provider,
            inferenceRepo: mockOllamaRepo,
            tools: [
              const ChatCompletionTool(
                type: ChatCompletionToolType.function,
                function: FunctionObject(
                  name: 'function_a',
                  description: 'First function',
                ),
              ),
              const ChatCompletionTool(
                type: ChatCompletionToolType.function,
                function: FunctionObject(
                  name: 'function_b',
                  description: 'Second function',
                ),
              ),
            ],
          );

          // Verify both tool calls were detected as Gemini-style and processed
          final manager = repository.getConversation(conversationId);
          expect(manager, isNotNull);
          _expectToolRoundNotRun(manager, [
            ('tool_turn1_0', 'function_a', '{"param": "value1"}'),
            ('tool_turn1_1', 'function_b', '{"param": "value2"}'),
          ]);
        },
      );

      test('handles strategy with wait action', () async {
        _stubGenerateText(mockOllamaRepo).thenAnswer(
          (_) => Stream.fromIterable([
            const CreateChatCompletionStreamResponse(
              id: 'test-response',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(
                    toolCalls: [
                      ChatCompletionStreamMessageToolCallChunk(
                        index: 0,
                        id: 'tool-1',
                        type: ChatCompletionStreamMessageToolCallChunkType
                            .function,
                        function: ChatCompletionStreamMessageFunctionCall(
                          name: 'test_function',
                          arguments: '{}',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1710500000,
            ),
          ]),
        );

        when(
          () => mockStrategy.processToolCalls(
            toolCalls: any(named: 'toolCalls'),
            manager: any(named: 'manager'),
          ),
        ).thenAnswer((_) async => ConversationAction.wait);

        await repository.sendMessage(
          conversationId: conversationId,
          message: 'Process and wait',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
          strategy: mockStrategy,
          tools: [
            const ChatCompletionTool(
              type: ChatCompletionToolType.function,
              function: FunctionObject(
                name: 'test_function',
                description: 'A test function',
              ),
            ),
          ],
        );

        // Verify strategy was called
        verify(
          () => mockStrategy.processToolCalls(
            toolCalls: any(named: 'toolCalls'),
            manager: any(named: 'manager'),
          ),
        ).called(1);

        // getContinuationPrompt should NOT be called for wait action
        verifyNever(() => mockStrategy.getContinuationPrompt(any()));
      });

      test('handles strategy with null continuation prompt', () async {
        _stubGenerateText(mockOllamaRepo).thenAnswer(
          (_) => Stream.fromIterable([
            const CreateChatCompletionStreamResponse(
              id: 'test-response',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(
                    toolCalls: [
                      ChatCompletionStreamMessageToolCallChunk(
                        index: 0,
                        id: 'tool-1',
                        type: ChatCompletionStreamMessageToolCallChunkType
                            .function,
                        function: ChatCompletionStreamMessageFunctionCall(
                          name: 'test_function',
                          arguments: '{}',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1710500000,
            ),
          ]),
        );

        when(
          () => mockStrategy.processToolCalls(
            toolCalls: any(named: 'toolCalls'),
            manager: any(named: 'manager'),
          ),
        ).thenAnswer((_) async => ConversationAction.continueConversation);

        // Return null for continuation prompt - should stop the loop
        when(() => mockStrategy.getContinuationPrompt(any())).thenReturn(null);

        await repository.sendMessage(
          conversationId: conversationId,
          message: 'Continue but no prompt',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
          strategy: mockStrategy,
          tools: [
            const ChatCompletionTool(
              type: ChatCompletionToolType.function,
              function: FunctionObject(
                name: 'test_function',
                description: 'A test function',
              ),
            ),
          ],
        );

        // Verify strategy was called but loop ended
        verify(
          () => mockStrategy.processToolCalls(
            toolCalls: any(named: 'toolCalls'),
            manager: any(named: 'manager'),
          ),
        ).called(1);
        verify(() => mockStrategy.getContinuationPrompt(any())).called(1);

        // Should only have 2 messages (user + assistant) since loop ended
        final manager = repository.getConversation(conversationId);
        _expectToolRoundNotRun(manager, [('tool-1', 'test_function', '{}')]);
      });
      test('returns accumulated usage from single-turn response', () async {
        final streamController =
            StreamController<CreateChatCompletionStreamResponse>();

        _stubGenerateText(
          mockOllamaRepo,
        ).thenAnswer((_) => streamController.stream);

        final sendFuture = repository.sendMessage(
          conversationId: conversationId,
          message: 'Hello',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
        );

        streamController
          ..add(
            const CreateChatCompletionStreamResponse(
              id: 'resp',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(content: 'Hi'),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1700000000,
            ),
          )
          ..add(
            const CreateChatCompletionStreamResponse(
              id: 'resp',
              choices: [],
              object: 'chat.completion.chunk',
              created: 1700000000,
              usage: CompletionUsage(
                promptTokens: 100,
                completionTokens: 50,
                totalTokens: 150,
              ),
            ),
          );
        await streamController.close();

        final usage = await sendFuture;

        expect(usage, isNotNull);
        expect(usage!.inputTokens, 100);
        expect(usage.outputTokens, 50);
      });

      test(
        'returns accumulated usage across multi-turn conversation',
        () async {
          var callCount = 0;

          _stubGenerateText(mockOllamaRepo).thenAnswer((_) {
            callCount++;
            if (callCount == 1) {
              // First turn: tool call with usage
              return Stream.fromIterable([
                const CreateChatCompletionStreamResponse(
                  id: 'resp-1',
                  choices: [
                    ChatCompletionStreamResponseChoice(
                      index: 0,
                      delta: ChatCompletionStreamResponseDelta(
                        toolCalls: [
                          ChatCompletionStreamMessageToolCallChunk(
                            index: 0,
                            id: 'tool-1',
                            type: ChatCompletionStreamMessageToolCallChunkType
                                .function,
                            function: ChatCompletionStreamMessageFunctionCall(
                              name: 'test_function',
                              arguments: '{}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  object: 'chat.completion.chunk',
                  created: 1700000000,
                  usage: CompletionUsage(
                    promptTokens: 80,
                    completionTokens: 20,
                    totalTokens: 100,
                  ),
                ),
              ]);
            } else {
              // Second turn: final response with usage
              return Stream.fromIterable([
                const CreateChatCompletionStreamResponse(
                  id: 'resp-2',
                  choices: [
                    ChatCompletionStreamResponseChoice(
                      index: 0,
                      delta: ChatCompletionStreamResponseDelta(content: 'Done'),
                    ),
                  ],
                  object: 'chat.completion.chunk',
                  created: 1700000000,
                  usage: CompletionUsage(
                    promptTokens: 120,
                    completionTokens: 30,
                    totalTokens: 150,
                  ),
                ),
              ]);
            }
          });

          when(
            () => mockStrategy.processToolCalls(
              toolCalls: any(named: 'toolCalls'),
              manager: any(named: 'manager'),
            ),
          ).thenAnswer((_) async => ConversationAction.continueConversation);

          when(
            () => mockStrategy.getContinuationPrompt(any()),
          ).thenReturn('Continue');

          final usage = await repository.sendMessage(
            conversationId: conversationId,
            message: 'Multi-turn',
            model: 'test-model',
            provider: provider,
            inferenceRepo: mockOllamaRepo,
            strategy: mockStrategy,
            tools: [
              const ChatCompletionTool(
                type: ChatCompletionToolType.function,
                function: FunctionObject(
                  name: 'test_function',
                  description: 'A test function',
                ),
              ),
            ],
          );

          expect(usage, isNotNull);
          // 80 + 120 = 200 input, 20 + 30 = 50 output
          expect(usage!.inputTokens, 200);
          expect(usage.outputTokens, 50);
        },
      );

      test('returns null when no usage data in response', () async {
        _stubGenerateText(mockOllamaRepo).thenAnswer(
          (_) => Stream.fromIterable([
            const CreateChatCompletionStreamResponse(
              id: 'resp',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(content: 'Hi'),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1700000000,
            ),
          ]),
        );

        final usage = await repository.sendMessage(
          conversationId: conversationId,
          message: 'No usage',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
        );

        expect(usage, isNull);
      });

      test(
        'stores thought signatures captured during the turn on the manager '
        'for reuse in subsequent turns',
        () async {
          _stubGenerateText(mockOllamaRepo).thenAnswer((invocation) {
            // Simulate a Gemini adapter capturing a signature mid-stream via
            // the collector sendMessage passed down.
            (invocation.namedArguments[#signatureCollector]
                    as ThoughtSignatureCollector?)
                ?.addSignature('tool-1', 'sig-abc');
            return Stream.fromIterable([
              const CreateChatCompletionStreamResponse(
                id: 'resp',
                choices: [
                  ChatCompletionStreamResponseChoice(
                    index: 0,
                    delta: ChatCompletionStreamResponseDelta(content: 'Hi'),
                  ),
                ],
                object: 'chat.completion.chunk',
                created: 1710500000,
              ),
            ]);
          });

          await repository.sendMessage(
            conversationId: conversationId,
            message: 'Sign this',
            model: 'test-model',
            provider: provider,
            inferenceRepo: mockOllamaRepo,
          );

          final manager = repository.getConversation(conversationId)!;
          expect(
            manager.thoughtSignatures,
            containsPair('tool-1', 'sig-abc'),
          );
        },
      );

      test('captures reasoning and cached tokens from usage details', () async {
        _stubGenerateText(mockOllamaRepo).thenAnswer(
          (_) => Stream.fromIterable([
            const CreateChatCompletionStreamResponse(
              id: 'resp',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(content: 'Hi'),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1700000000,
              usage: CompletionUsage(
                promptTokens: 200,
                completionTokens: 100,
                totalTokens: 300,
                completionTokensDetails: CompletionTokensDetails(
                  reasoningTokens: 40,
                ),
                promptTokensDetails: PromptTokensDetails(
                  cachedTokens: 50,
                ),
              ),
            ),
          ]),
        );

        final usage = await repository.sendMessage(
          conversationId: conversationId,
          message: 'Details',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
        );

        expect(usage, isNotNull);
        expect(usage!.inputTokens, 200);
        expect(usage.outputTokens, 100);
        expect(usage.thoughtsTokens, 40);
        expect(usage.cachedInputTokens, 50);
      });

      test('rethrows inference errors when orchestration requests it', () {
        _stubGenerateText(mockOllamaRepo).thenAnswer(
          (_) => Stream.error(StateError('provider unavailable')),
        );

        expect(
          () => repository.sendMessage(
            conversationId: conversationId,
            message: 'Run the wake',
            model: 'test-model',
            provider: provider,
            inferenceRepo: mockOllamaRepo,
            rethrowInferenceErrors: true,
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'provider unavailable',
            ),
          ),
        );
      });

      test(
        'clears the previous inference error before the next request',
        () async {
          var callCount = 0;
          _stubGenerateText(mockOllamaRepo).thenAnswer((_) {
            callCount++;
            if (callCount == 1) {
              return Stream.error(StateError('temporary provider error'));
            }
            return Stream.value(
              const CreateChatCompletionStreamResponse(
                id: 'recovered',
                choices: [
                  ChatCompletionStreamResponseChoice(
                    index: 0,
                    delta: ChatCompletionStreamResponseDelta(content: 'Done'),
                  ),
                ],
                object: 'chat.completion.chunk',
                created: 1710500000,
              ),
            );
          });

          await repository.sendMessage(
            conversationId: conversationId,
            message: 'First attempt',
            model: 'test-model',
            provider: provider,
            inferenceRepo: mockOllamaRepo,
          );
          final manager = repository.getConversation(conversationId)!;
          expect(manager.lastError, contains('temporary provider error'));

          await repository.sendMessage(
            conversationId: conversationId,
            message: 'Second attempt',
            model: 'test-model',
            provider: provider,
            inferenceRepo: mockOllamaRepo,
          );

          expect(manager.lastError, isNull);
          expect(manager.messages.last.content, 'Done');
        },
      );

      test(
        'does not rethrow tool-processing errors after successful inference',
        () async {
          _stubGenerateText(mockOllamaRepo).thenAnswer(
            (_) => Stream.value(
              const CreateChatCompletionStreamResponse(
                id: 'tool-response',
                choices: [
                  ChatCompletionStreamResponseChoice(
                    index: 0,
                    delta: ChatCompletionStreamResponseDelta(
                      toolCalls: [
                        ChatCompletionStreamMessageToolCallChunk(
                          index: 0,
                          id: 'tool-1',
                          type: ChatCompletionStreamMessageToolCallChunkType
                              .function,
                          function: ChatCompletionStreamMessageFunctionCall(
                            name: 'test_function',
                            arguments: '{}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                object: 'chat.completion.chunk',
                created: 1710500000,
                usage: CompletionUsage(
                  promptTokens: 30,
                  completionTokens: 10,
                  totalTokens: 40,
                ),
              ),
            ),
          );
          when(
            () => mockStrategy.processToolCalls(
              toolCalls: any(named: 'toolCalls'),
              manager: any(named: 'manager'),
            ),
          ).thenThrow(StateError('strategy failed'));

          final usage = await repository.sendMessage(
            conversationId: conversationId,
            message: 'Use the tool',
            model: 'test-model',
            provider: provider,
            inferenceRepo: mockOllamaRepo,
            strategy: mockStrategy,
            rethrowInferenceErrors: true,
          );

          expect(usage?.inputTokens, 30);
          expect(usage?.outputTokens, 10);
          expect(
            repository.getConversation(conversationId)!.lastError,
            contains('strategy failed'),
          );
        },
      );

      group('per-turn consumption recording', () {
        /// Stubs `generateTextWithMessages` with a single content chunk whose
        /// final response carries [usage], optionally writing [impact] into
        /// the `InferenceImpactCollector` that `sendMessage` passes down —
        /// mirroring how the Melious adapter reports cost/energy out of band.
        void stubTurnWithUsage({
          CompletionUsage? usage,
          MeliousCallImpact? impact,
        }) {
          _stubGenerateText(mockOllamaRepo).thenAnswer((invocation) {
            if (impact != null) {
              (invocation.namedArguments[#impactCollector]
                          as InferenceImpactCollector?)
                      ?.impact =
                  impact;
            }
            return Stream.fromIterable([
              CreateChatCompletionStreamResponse(
                id: 'resp',
                choices: const [
                  ChatCompletionStreamResponseChoice(
                    index: 0,
                    delta: ChatCompletionStreamResponseDelta(content: 'Hi'),
                  ),
                ],
                object: 'chat.completion.chunk',
                created: 1710500000,
                usage: usage,
              ),
            ]);
          });
        }

        /// Sends one message with the full set of consumption owner ids the
        /// agent workflows pass. [agentId] is required so each test states
        /// explicitly whether recording should be active.
        Future<InferenceUsage?> sendWithConsumption({
          required String? agentId,
        }) {
          return repository.sendMessage(
            conversationId: conversationId,
            message: 'Hello',
            model: 'test-model',
            provider: provider,
            inferenceRepo: mockOllamaRepo,
            consumptionAgentId: agentId,
            consumptionTaskId: 'task-1',
            consumptionCategoryId: 'cat-1',
            consumptionWakeRunKey: 'wake-1',
            consumptionThreadId: 'thread-1',
          );
        }

        test(
          'records an agentTurn event with owner ids, tokens, and impact',
          () async {
            final bench = _registerInteractionCapture();
            stubTurnWithUsage(
              usage: const CompletionUsage(
                promptTokens: 100,
                completionTokens: 40,
                totalTokens: 140,
                promptTokensDetails: PromptTokensDetails(cachedTokens: 25),
                completionTokensDetails: CompletionTokensDetails(
                  reasoningTokens: 15,
                ),
              ),
              impact: const MeliousCallImpact(
                costCredits: 0.5,
                energyKwh: 0.002,
                carbonGCo2: 1.5,
                waterLiters: 0.3,
                renewablePercent: 80,
                pue: 1.2,
                dataCenter: 'FI',
                providerId: 'upstream-x',
              ),
            );

            await withClock(
              Clock.fixed(DateTime(2024, 3, 15, 10, 30)),
              () => sendWithConsumption(agentId: 'agent-1'),
            );

            final event = _capturedEvents(bench).single;
            expect(event.responseType, AiConsumptionResponseType.agentTurn);
            // The wake run key doubles as the causal parent id.
            expect(event.parentId, 'wake-1');
            expect(event.agentId, 'agent-1');
            expect(event.taskId, 'task-1');
            expect(event.categoryId, 'cat-1');
            expect(event.wakeRunKey, 'wake-1');
            expect(event.threadId, 'thread-1');
            // turnIndex mirrors ConversationManager.turnCount (the number of
            // user messages), captured after the user message was added — so
            // the first turn records index 1.
            expect(event.turnIndex, 1);
            expect(event.providerModelId, 'test-model');
            expect(event.providerType, InferenceProviderType.ollama);
            expect(event.createdAt, DateTime(2024, 3, 15, 10, 30).toUtc());
            expect(event.durationMs, 0);
            expect(event.inputTokens, 100);
            expect(event.outputTokens, 40);
            expect(event.cachedInputTokens, 25);
            expect(event.thoughtsTokens, 15);
            expect(event.totalTokens, 140);
            expect(event.credits, 0.5);
            expect(event.energyKwh, 0.002);
            expect(event.carbonGCo2, 1.5);
            expect(event.waterLiters, 0.3);
            expect(event.renewablePercent, 80);
            expect(event.pue, 1.2);
            expect(event.dataCenter, 'FI');
            expect(event.upstreamProviderId, 'upstream-x');
            expect(
              event.responseDigest,
              sha256.convert(utf8.encode('Hi')).toString(),
            );
          },
        );

        test(
          'records executor and editor models as separate consumption events '
          'under one wake',
          () async {
            final bench = _registerInteractionCapture();
            _stubGenerateText(mockOllamaRepo).thenAnswer((invocation) {
              final model = invocation.namedArguments[#model] as String;
              final isEditor = model == 'qwen3.5-122b-a10b';
              (invocation.namedArguments[#impactCollector]
                      as InferenceImpactCollector?)
                  ?.impact = MeliousCallImpact(
                costCredits: isEditor ? 0.2 : 0.5,
                energyKwh: isEditor ? 0.001 : 0.003,
              );
              return Stream.fromIterable([
                CreateChatCompletionStreamResponse(
                  id: 'response-$model',
                  choices: const [
                    ChatCompletionStreamResponseChoice(
                      index: 0,
                      delta: ChatCompletionStreamResponseDelta(content: 'Hi'),
                    ),
                  ],
                  object: 'chat.completion.chunk',
                  created: 1710500000,
                  usage: CompletionUsage(
                    promptTokens: isEditor ? 40 : 100,
                    completionTokens: isEditor ? 10 : 20,
                    totalTokens: isEditor ? 50 : 120,
                  ),
                ),
              ]);
            });

            Future<void> send({
              required String conversationId,
              required String model,
            }) async {
              await repository.sendMessage(
                conversationId: conversationId,
                message: 'Run $model',
                model: model,
                provider: provider,
                inferenceRepo: mockOllamaRepo,
                consumptionAgentId: 'agent-1',
                consumptionTaskId: 'task-1',
                consumptionCategoryId: 'cat-1',
                consumptionWakeRunKey: 'wake-1',
                consumptionThreadId: 'thread-1',
              );
            }

            await send(
              conversationId: conversationId,
              model: 'mistral-small-4-119b-instruct',
            );
            final editorConversationId = repository.createConversation(
              systemMessage: 'Edit the report.',
            );
            await send(
              conversationId: editorConversationId,
              model: 'qwen3.5-122b-a10b',
            );

            final events = _capturedEvents(bench);
            expect(events, hasLength(2));
            expect(events.map((event) => event.id).toSet(), hasLength(2));
            expect(events.map((event) => event.wakeRunKey).toSet(), {'wake-1'});
            expect(events.map((event) => event.providerModelId), [
              'mistral-small-4-119b-instruct',
              'qwen3.5-122b-a10b',
            ]);
            expect(events.map((event) => event.credits), [0.5, 0.2]);
            expect(events.map((event) => event.energyKwh), [0.003, 0.001]);
          },
        );

        test(
          'increments turnIndex per turn and parents every turn on the '
          'wake run key',
          () async {
            final bench = _registerInteractionCapture();

            var callCount = 0;
            _stubGenerateText(mockOllamaRepo).thenAnswer((_) {
              callCount++;
              if (callCount == 1) {
                return Stream.fromIterable([
                  const CreateChatCompletionStreamResponse(
                    id: 'resp-1',
                    choices: [
                      ChatCompletionStreamResponseChoice(
                        index: 0,
                        delta: ChatCompletionStreamResponseDelta(
                          toolCalls: [
                            ChatCompletionStreamMessageToolCallChunk(
                              index: 0,
                              id: 'tool-1',
                              type: ChatCompletionStreamMessageToolCallChunkType
                                  .function,
                              function: ChatCompletionStreamMessageFunctionCall(
                                name: 'test_function',
                                arguments: '{}',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    object: 'chat.completion.chunk',
                    created: 1710500000,
                    usage: CompletionUsage(
                      promptTokens: 80,
                      completionTokens: 20,
                      totalTokens: 100,
                    ),
                  ),
                ]);
              }
              return Stream.fromIterable([
                const CreateChatCompletionStreamResponse(
                  id: 'resp-2',
                  choices: [
                    ChatCompletionStreamResponseChoice(
                      index: 0,
                      delta: ChatCompletionStreamResponseDelta(
                        content: 'Done',
                      ),
                    ),
                  ],
                  object: 'chat.completion.chunk',
                  created: 1710500000,
                  usage: CompletionUsage(
                    promptTokens: 120,
                    completionTokens: 30,
                    totalTokens: 150,
                  ),
                ),
              ]);
            });

            when(
              () => mockStrategy.processToolCalls(
                toolCalls: any(named: 'toolCalls'),
                manager: any(named: 'manager'),
              ),
            ).thenAnswer((_) async => ConversationAction.continueConversation);
            when(
              () => mockStrategy.getContinuationPrompt(any()),
            ).thenReturn('Continue');

            await repository.sendMessage(
              conversationId: conversationId,
              message: 'Multi-turn',
              model: 'test-model',
              provider: provider,
              inferenceRepo: mockOllamaRepo,
              strategy: mockStrategy,
              consumptionAgentId: 'agent-1',
              consumptionTaskId: 'task-1',
              consumptionCategoryId: 'cat-1',
              consumptionWakeRunKey: 'wake-1',
              consumptionThreadId: 'thread-1',
              tools: [
                const ChatCompletionTool(
                  type: ChatCompletionToolType.function,
                  function: FunctionObject(
                    name: 'test_function',
                    description: 'A test function',
                  ),
                ),
              ],
            );

            final events = _capturedEvents(bench);
            expect(events, hasLength(2));
            // turnIndex mirrors ConversationManager.turnCount (user-message
            // count at request time): 1 for the first turn, 2 after the
            // continuation prompt added a second user message.
            expect(events[0].turnIndex, 1);
            expect(events[0].inputTokens, 80);
            expect(events[0].outputTokens, 20);
            expect(events[1].turnIndex, 2);
            expect(events[1].inputTokens, 120);
            expect(events[1].outputTokens, 30);
            for (final event in events) {
              expect(event.responseType, AiConsumptionResponseType.agentTurn);
              expect(event.parentId, 'wake-1');
              expect(event.agentId, 'agent-1');
            }
          },
        );

        test(
          'records non-agent calls as text generation without an agent owner',
          () async {
            final bench = _registerInteractionCapture();
            stubTurnWithUsage(
              usage: const CompletionUsage(
                promptTokens: 10,
                completionTokens: 5,
                totalTokens: 15,
              ),
            );

            final usage = await sendWithConsumption(agentId: null);

            expect(usage, isNotNull);
            final event = _capturedEvents(bench).single;
            expect(
              event.responseType,
              AiConsumptionResponseType.textGeneration,
            );
            expect(event.agentId, isNull);
          },
        );

        test('terminalizes a failed non-agent stream exactly once', () async {
          final bench = _registerInteractionCapture();
          _stubGenerateText(mockOllamaRepo).thenAnswer(
            (_) => Stream.error(StateError('provider unavailable')),
          );

          final usage = await sendWithConsumption(agentId: null);

          expect(usage, isNull);
          verify(
            () => bench.service.prepareCompletion(
              attributionId: any(named: 'attributionId'),
              outputs: const [],
              status: AiWorkStatus.failed,
              errorCode: 'StateError',
            ),
          ).called(1);
          verify(() => bench.service.finalize(any())).called(1);
        });

        test(
          'completes normally when no interaction capture is registered',
          () async {
            AiInteractionCaptureTestBench.create().unregister();
            stubTurnWithUsage(
              usage: const CompletionUsage(
                promptTokens: 100,
                completionTokens: 40,
                totalTokens: 140,
              ),
            );

            final usage = await sendWithConsumption(agentId: 'agent-1');

            // The turn still completes and reports usage; the missing
            // capture is silently skipped.
            expect(usage, isNotNull);
            expect(usage!.inputTokens, 100);
            final manager = repository.getConversation(conversationId)!;
            expect(
              manager.messages.last.role,
              ChatCompletionMessageRole.assistant,
            );
          },
        );

        test(
          'returns usage when consumption recording fails',
          () async {
            final bench = _registerInteractionCapture();
            when(
              () => bench.service.recordInteraction(
                attributionId: any(named: 'attributionId'),
                event: any(named: 'event'),
              ),
            ).thenThrow(StateError('telemetry write failed'));
            stubTurnWithUsage(
              usage: const CompletionUsage(
                promptTokens: 100,
                completionTokens: 40,
                totalTokens: 140,
              ),
            );

            final usage = await repository.sendMessage(
              conversationId: conversationId,
              message: 'Hello',
              model: 'test-model',
              provider: provider,
              inferenceRepo: mockOllamaRepo,
              consumptionAgentId: 'agent-1',
              rethrowInferenceErrors: true,
            );

            expect(usage?.inputTokens, 100);
            expect(usage?.outputTokens, 40);
            expect(
              repository.getConversation(conversationId)!.lastError,
              isNull,
            );
          },
        );
      });
    });

    group('tool-call stream helpers', () {
      ChatCompletionStreamMessageToolCallChunk chunk({
        String? id,
        int? index,
        String? name,
        String? arguments,
      }) {
        return ChatCompletionStreamMessageToolCallChunk(
          id: id,
          index: index,
          type: ChatCompletionStreamMessageToolCallChunkType.function,
          function: ChatCompletionStreamMessageFunctionCall(
            name: name,
            arguments: arguments,
          ),
        );
      }

      test('isGeminiStyleToolCallDelta detects complete multi-call chunks', () {
        // Two complete calls, no ids/indices → Gemini style.
        expect(
          ConversationRepository.isGeminiStyleToolCallDelta([
            chunk(name: 'a', arguments: '{"x":1}'),
            chunk(name: 'b', arguments: '{"y":2}'),
          ]),
          isTrue,
        );
        // Single chunk is never Gemini style.
        expect(
          ConversationRepository.isGeminiStyleToolCallDelta([
            chunk(name: 'a', arguments: '{"x":1}'),
          ]),
          isFalse,
        );
        // Ids present → OpenAI streaming accumulation.
        expect(
          ConversationRepository.isGeminiStyleToolCallDelta([
            chunk(id: 't1', name: 'a', arguments: '{"x":1}'),
            chunk(id: 't2', name: 'b', arguments: '{"y":2}'),
          ]),
          isFalse,
        );
        // Empty arguments anywhere → not Gemini style.
        expect(
          ConversationRepository.isGeminiStyleToolCallDelta([
            chunk(name: 'a', arguments: '{"x":1}'),
            chunk(name: 'b', arguments: ''),
          ]),
          isFalse,
        );
      });

      test('appendGeminiToolCalls synthesizes turn-scoped unique ids', () {
        final toolCalls = <ChatCompletionMessageToolCall>[];
        ConversationRepository.appendGeminiToolCalls(
          toolCalls: toolCalls,
          chunks: [
            chunk(name: 'first', arguments: '{"a":1}'),
            chunk(name: 'second', arguments: '{"b":2}'),
          ],
          turn: 3,
        );

        expect(toolCalls, hasLength(2));
        expect(toolCalls[0].id, 'tool_turn3_0');
        expect(toolCalls[0].function.name, 'first');
        expect(toolCalls[0].function.arguments, '{"a":1}');
        expect(toolCalls[1].id, 'tool_turn3_1');
        expect(toolCalls[1].function.name, 'second');
        expect(toolCalls[1].function.arguments, '{"b":2}');
      });

      test(
        'accumulateOpenAiToolCallChunks stitches split arguments by id',
        () {
          final toolCalls = <ChatCompletionMessageToolCall>[];
          final buffers = <String, StringBuffer>{};

          ConversationRepository.accumulateOpenAiToolCallChunks(
            toolCalls: toolCalls,
            argumentBuffers: buffers,
            turn: 1,
            chunks: [
              chunk(id: 'tool-1', index: 0, name: 'fn', arguments: '{"arg'),
            ],
          );
          ConversationRepository.accumulateOpenAiToolCallChunks(
            toolCalls: toolCalls,
            argumentBuffers: buffers,
            turn: 1,
            chunks: [chunk(id: 'tool-1', index: 0, arguments: '": "value"}')],
          );

          expect(toolCalls, hasLength(1));
          expect(toolCalls.single.id, 'tool-1');
          expect(toolCalls.single.function.name, 'fn');
          expect(toolCalls.single.function.arguments, '{"arg": "value"}');
        },
      );

      test(
        'accumulateOpenAiToolCallChunks rebuilds the buffer from an existing '
        'tool call when no argument buffer exists for it yet',
        () {
          // A tool call can enter the list without a buffer (e.g. appended by
          // the Gemini path); a later OpenAI-style continuation must seed the
          // buffer from the already-accumulated arguments, not drop them.
          final toolCalls = <ChatCompletionMessageToolCall>[
            const ChatCompletionMessageToolCall(
              id: 'tool-pre',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'fn',
                arguments: '{"start":',
              ),
            ),
          ];
          final buffers = <String, StringBuffer>{};

          ConversationRepository.accumulateOpenAiToolCallChunks(
            toolCalls: toolCalls,
            argumentBuffers: buffers,
            turn: 1,
            chunks: [chunk(id: 'tool-pre', arguments: 'true}')],
          );

          expect(toolCalls.single.function.arguments, '{"start":true}');
          expect(buffers['tool-pre'].toString(), '{"start":true}');
        },
      );

      test(
        'accumulateOpenAiToolCallChunks matches by index when id is absent '
        'and synthesizes turn-scoped ids for new calls',
        () {
          final toolCalls = <ChatCompletionMessageToolCall>[];
          final buffers = <String, StringBuffer>{};

          // New call without id → synthesized from index.
          ConversationRepository.accumulateOpenAiToolCallChunks(
            toolCalls: toolCalls,
            argumentBuffers: buffers,
            turn: 1,
            chunks: [chunk(index: 0, name: 'fn', arguments: '{"k')],
          );
          expect(toolCalls.single.id, 'tool_turn1_0');

          // Continuation chunk carries only the index.
          ConversationRepository.accumulateOpenAiToolCallChunks(
            toolCalls: toolCalls,
            argumentBuffers: buffers,
            turn: 1,
            chunks: [chunk(index: 0, arguments: '":true}')],
          );
          expect(toolCalls.single.function.arguments, '{"k":true}');
        },
      );

      test(
        'accumulateOpenAiToolCallChunks starts a new call for a new id even '
        'when its index is taken',
        () {
          final toolCalls = <ChatCompletionMessageToolCall>[];
          final buffers = <String, StringBuffer>{};

          // A provider that numbers every call 0 but names each one.
          for (final (id, args) in [('a', '{"x":1}'), ('b', '{"y":2}')]) {
            ConversationRepository.accumulateOpenAiToolCallChunks(
              toolCalls: toolCalls,
              argumentBuffers: buffers,
              turn: 1,
              chunks: [
                chunk(id: id, index: 0, name: 'fn_$id', arguments: args),
              ],
            );
          }

          expect(
            toolCalls.map((c) => (c.id, c.function.name, c.function.arguments)),
            [('a', 'fn_a', '{"x":1}'), ('b', 'fn_b', '{"y":2}')],
          );
        },
      );

      test(
        'accumulateOpenAiToolCallChunks treats an empty id as none, so two '
        'calls share neither an id nor an argument buffer',
        () {
          final toolCalls = <ChatCompletionMessageToolCall>[];
          final buffers = <String, StringBuffer>{};

          ConversationRepository.accumulateOpenAiToolCallChunks(
            toolCalls: toolCalls,
            argumentBuffers: buffers,
            turn: 4,
            chunks: [
              chunk(id: '', index: 0, name: 'first', arguments: '{"a"'),
              chunk(id: '', index: 1, name: 'second', arguments: '{"b"'),
            ],
          );
          ConversationRepository.accumulateOpenAiToolCallChunks(
            toolCalls: toolCalls,
            argumentBuffers: buffers,
            turn: 4,
            chunks: [
              chunk(id: '', index: 0, arguments: ':1}'),
              chunk(id: '', index: 1, arguments: ':2}'),
            ],
          );

          expect(
            toolCalls.map((c) => (c.id, c.function.arguments)),
            [('tool_turn4_0', '{"a":1}'), ('tool_turn4_1', '{"b":2}')],
          );
        },
      );

      glados.Glados2<List<int>, bool>(
        glados.ListAnys(glados.any).listWithLengthInRange(
          1,
          5,
          glados.IntAnys(glados.any).intInRange(0, 3 * 40),
        ),
        glados.BoolAny(glados.any).bool,
        glados.ExploreConfig(numRuns: 150),
      ).test(
        'accumulateOpenAiToolCallChunks reassembles any calls streamed in '
        'fragments',
        (seeds, zeroIndices) {
          // seed % 3 picks the id the provider sends (one, none, empty);
          // seed ~/ 3 where the arguments split. A provider may number every
          // call 0 only when it names each one.
          final idKinds = [for (final seed in seeds) seed % 3];
          final numbersAllZero = zeroIndices && idKinds.every((k) => k == 0);
          final toolCalls = <ChatCompletionMessageToolCall>[];
          final buffers = <String, StringBuffer>{};
          final expected = <(String, String, String)>[];

          for (final (i, seed) in seeds.indexed) {
            final args = '{"call":$i,"pad":"${'x' * (seed ~/ 3)}"}';
            final split = (seed ~/ 3) % args.length;
            final id = switch (idKinds[i]) {
              0 => 'call-$i',
              1 => null,
              _ => '',
            };
            final index = numbersAllZero ? 0 : i;
            for (final fragment in [
              chunk(
                id: id,
                index: index,
                name: 'fn$i',
                arguments: args.substring(0, split),
              ),
              chunk(id: id, index: index, arguments: args.substring(split)),
            ]) {
              ConversationRepository.accumulateOpenAiToolCallChunks(
                toolCalls: toolCalls,
                argumentBuffers: buffers,
                turn: 7,
                chunks: [fragment],
              );
            }
            expected.add((
              idKinds[i] == 0 ? 'call-$i' : 'tool_turn7_$i',
              'fn$i',
              args,
            ));
          }

          expect(
            toolCalls.map(
              (c) => (c.id, c.function.name, c.function.arguments),
            ),
            expected,
            reason: 'seeds $seeds, all indices 0: $numbersAllZero',
          );
        },
        tags: 'glados',
      );
    });

    group('stripThinkBlocks — Glados properties', () {
      // Compose inputs from plain segments and think blocks; seed bit i
      // decides whether segment i is wrapped in a think block.
      glados.Glados2<List<int>, int>(
        glados.ListAnys(glados.any).listWithLengthInRange(
          0,
          6,
          glados.IntAnys(glados.any).intInRange(0, 1 << 16),
        ),
        glados.IntAnys(glados.any).intInRange(0, 1 << 6),
        glados.ExploreConfig(numRuns: 150),
      ).test(
        'output never contains think tags; null iff every segment is a '
        'think block',
        (seeds, mask) {
          final plainParts = <String>[];
          final buffer = StringBuffer();
          for (final (i, seed) in seeds.indexed) {
            final text = 'seg$seed';
            if ((mask >> i) & 1 == 1) {
              final tag = seed.isEven ? 'think' : 'thinking';
              buffer.write('<$tag>hidden $text</$tag> ');
            } else {
              plainParts.add(text);
              buffer.write('$text ');
            }
          }

          final result = stripThinkBlocks(buffer.toString());

          if (plainParts.isEmpty) {
            expect(result, isNull, reason: 'input: $buffer');
          } else {
            expect(result, isNotNull, reason: 'input: $buffer');
            expect(result, isNot(contains('<think')));
            expect(result, isNot(contains('</think')));
            expect(result, isNot(contains('hidden')));
            for (final part in plainParts) {
              expect(result, contains(part), reason: 'input: $buffer');
            }
          }

          // Null propagates.
          expect(stripThinkBlocks(null), isNull);
        },
        tags: 'glados',
      );
    });
  });

  group('per-turn tool exposure', () {
    late AiConfigInferenceProvider provider;

    setUp(() {
      provider = AiConfigInferenceProvider(
        id: 'test-provider',
        name: 'Test Provider',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inferenceProviderType: InferenceProviderType.ollama,
      );
    });

    test(
      'a strategy narrowing the turn changes what reaches the provider',
      () async {
        final conversationId = repository.createConversation(
          systemMessage: 'system',
        );

        const wide = ChatCompletionTool(
          type: ChatCompletionToolType.function,
          function: FunctionObject(name: 'wide_tool'),
        );
        const narrow = ChatCompletionTool(
          type: ChatCompletionToolType.function,
          function: FunctionObject(name: 'narrow_tool'),
        );

        when(
          () => mockStrategy.toolsForTurn(
            turnIndex: any(named: 'turnIndex'),
            manager: any(named: 'manager'),
          ),
        ).thenReturn([narrow]);
        when(() => mockStrategy.shouldContinue(any())).thenReturn(false);

        _stubGenerateText(mockOllamaRepo).thenAnswer(
          (_) => Stream.value(
            const CreateChatCompletionStreamResponse(
              id: 'r1',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(content: 'done'),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1710500000,
            ),
          ),
        );

        await repository.sendMessage(
          conversationId: conversationId,
          message: 'go',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
          strategy: mockStrategy,
          tools: [wide],
        );

        final captured =
            verify(
                  () => mockOllamaRepo.generateTextWithMessages(
                    messages: any(named: 'messages'),
                    model: any(named: 'model'),
                    provider: any(named: 'provider'),
                    tools: captureAny(named: 'tools'),
                    temperature: any(named: 'temperature'),
                    thoughtSignatures: any(named: 'thoughtSignatures'),
                    signatureCollector: any(named: 'signatureCollector'),
                    turnIndex: any(named: 'turnIndex'),
                    impactCollector: any(named: 'impactCollector'),
                    toolChoice: any(named: 'toolChoice'),
                  ),
                ).captured.single
                as List<ChatCompletionTool>?;

        // The list passed to sendMessage must NOT be what the provider saw.
        expect(
          captured?.map((tool) => tool.function.name),
          ['narrow_tool'],
          reason: 'the strategy owns the tool surface for the turn',
        );
      },
    );

    test('the first request is the opening turn, index zero', () async {
      // turnCount counts user messages and this turn's is already logged, so a
      // naive read gives 1 on the first request. TaskAgentStagedToolExposure
      // only treats 0 as the opening turn, so an off-by-one here silently
      // restores the full tool list and the staging never happens at all.
      final conversationId = repository.createConversation(
        systemMessage: 'system',
      );

      const wide = ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(name: 'wide_tool'),
      );

      final seenTurnIndexes = <int>[];
      when(
        () => mockStrategy.toolsForTurn(
          turnIndex: any(named: 'turnIndex'),
          manager: any(named: 'manager'),
        ),
      ).thenAnswer((invocation) {
        seenTurnIndexes.add(
          invocation.namedArguments[const Symbol('turnIndex')] as int,
        );
        return null;
      });
      when(() => mockStrategy.shouldContinue(any())).thenReturn(false);

      _stubGenerateText(mockOllamaRepo).thenAnswer(
        (_) => Stream.value(
          const CreateChatCompletionStreamResponse(
            id: 'r1',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(content: 'done'),
              ),
            ],
            object: 'chat.completion.chunk',
            created: 1710500000,
          ),
        ),
      );

      await repository.sendMessage(
        conversationId: conversationId,
        message: 'go',
        model: 'test-model',
        provider: provider,
        inferenceRepo: mockOllamaRepo,
        strategy: mockStrategy,
        tools: [wide],
      );

      expect(
        seenTurnIndexes,
        [0],
        reason: 'the opening request must be turn zero for the strategy',
      );
    });

    test(
      'a forced toolChoice keeps a constrained list constrained',
      () async {
        // The forced report-only retry pairs a one-tool list with a forced
        // toolChoice. A staging strategy widening it back would hand a provider
        // that ignores toolChoice a mutation tool during report recovery.
        final conversationId = repository.createConversation(
          systemMessage: 'system',
        );

        const reportOnly = ChatCompletionTool(
          type: ChatCompletionToolType.function,
          function: FunctionObject(name: 'update_report'),
        );
        const mutation = ChatCompletionTool(
          type: ChatCompletionToolType.function,
          function: FunctionObject(name: 'set_task_status'),
        );

        when(
          () => mockStrategy.toolsForTurn(
            turnIndex: any(named: 'turnIndex'),
            manager: any(named: 'manager'),
          ),
        ).thenReturn([reportOnly, mutation]);
        when(() => mockStrategy.shouldContinue(any())).thenReturn(false);

        _stubGenerateText(mockOllamaRepo).thenAnswer(
          (_) => Stream.value(
            const CreateChatCompletionStreamResponse(
              id: 'r1',
              choices: [
                ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(content: 'done'),
                ),
              ],
              object: 'chat.completion.chunk',
              created: 1710500000,
            ),
          ),
        );

        await repository.sendMessage(
          conversationId: conversationId,
          message: 'call update_report now',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
          strategy: mockStrategy,
          tools: [reportOnly],
          // What the forced report-only retry passes.
          toolChoice: const ChatCompletionToolChoiceOption.tool(
            ChatCompletionNamedToolChoice(
              type: ChatCompletionNamedToolChoiceType.function,
              function: ChatCompletionFunctionCallOption(name: 'update_report'),
            ),
          ),
        );

        final captured =
            verify(
                  () => mockOllamaRepo.generateTextWithMessages(
                    messages: any(named: 'messages'),
                    model: any(named: 'model'),
                    provider: any(named: 'provider'),
                    tools: captureAny(named: 'tools'),
                    temperature: any(named: 'temperature'),
                    thoughtSignatures: any(named: 'thoughtSignatures'),
                    signatureCollector: any(named: 'signatureCollector'),
                    turnIndex: any(named: 'turnIndex'),
                    impactCollector: any(named: 'impactCollector'),
                    toolChoice: any(named: 'toolChoice'),
                  ),
                ).captured.single
                as List<ChatCompletionTool>?;

        expect(
          captured?.map((tool) => tool.function.name),
          ['update_report'],
          reason: 'the strategy must not widen a deliberately constrained list',
        );
      },
    );

    test('no override leaves the caller list untouched', () async {
      final conversationId = repository.createConversation(
        systemMessage: 'system',
      );

      const wide = ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(name: 'wide_tool'),
      );

      // Unstubbed toolsForTurn returns null, which is the shipped behaviour.
      when(
        () => mockStrategy.toolsForTurn(
          turnIndex: any(named: 'turnIndex'),
          manager: any(named: 'manager'),
        ),
      ).thenReturn(null);
      when(() => mockStrategy.shouldContinue(any())).thenReturn(false);

      _stubGenerateText(mockOllamaRepo).thenAnswer(
        (_) => Stream.value(
          const CreateChatCompletionStreamResponse(
            id: 'r1',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(content: 'done'),
              ),
            ],
            object: 'chat.completion.chunk',
            created: 1710500000,
          ),
        ),
      );

      await repository.sendMessage(
        conversationId: conversationId,
        message: 'go',
        model: 'test-model',
        provider: provider,
        inferenceRepo: mockOllamaRepo,
        strategy: mockStrategy,
        tools: [wide],
      );

      final captured =
          verify(
                () => mockOllamaRepo.generateTextWithMessages(
                  messages: any(named: 'messages'),
                  model: any(named: 'model'),
                  provider: any(named: 'provider'),
                  tools: captureAny(named: 'tools'),
                  temperature: any(named: 'temperature'),
                  thoughtSignatures: any(named: 'thoughtSignatures'),
                  signatureCollector: any(named: 'signatureCollector'),
                  turnIndex: any(named: 'turnIndex'),
                  impactCollector: any(named: 'impactCollector'),
                  toolChoice: any(named: 'toolChoice'),
                ),
              ).captured.single
              as List<ChatCompletionTool>?;

      expect(captured?.map((tool) => tool.function.name), ['wide_tool']);
    });
  });

  group('the conversation loop (specs/tla/ConversationLoop.tla)', () {
    late AiConfigInferenceProvider provider;

    setUp(() {
      // The provider is auto-dispose: keep it alive while a test pumps the
      // event queue with sends in flight.
      final keepAlive = container.listen(
        conversationRepositoryProvider,
        (_, _) {},
      );
      addTearDown(keepAlive.close);
      provider = AiConfigInferenceProvider(
        id: 'test-provider',
        name: 'Test Provider',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inferenceProviderType: InferenceProviderType.ollama,
      );
    });

    test(
      'a wake calling nine tools a round stops at maxTurnsPerWake although '
      'its history is trimmed (BoundedRounds, Terminates)',
      () async {
        final run = await _runAdversarialWake(
          repository: repository,
          provider: provider,
          maxTurns: 10,
          callsPerRound: [9],
        );

        // The opening message is turn 1; each continuation is the next one.
        expect(run.requests, hasLength(9));
        expect(run.requests.last.length, lessThanOrEqualTo(100));
        expect(run.ids.toSet(), hasLength(run.ids.length));
      },
    );

    test(
      'synthesized tool-call ids never repeat across a trimmed 20-turn '
      'session (UniqueToolCallIds)',
      () async {
        final run = await _runAdversarialWake(
          repository: repository,
          provider: provider,
          maxTurns: 20,
          callsPerRound: [5],
        );

        expect(
          run.ids.toSet(),
          hasLength(run.ids.length),
          reason: run.ids.join(' '),
        );
        expect(
          run.requests.last[1].content,
          contains('truncated'),
          reason: 'seven messages a round outgrow the 100-message history',
        );
        expect(run.requests, hasLength(19));
        expect(run.ids.last, 'tool_turn19_4');
      },
    );

    glados.Glados2<List<int>, int>(
      glados.ListAnys(glados.any).listWithLengthInRange(
        1,
        4,
        glados.IntAnys(glados.any).intInRange(1, 15),
      ),
      glados.IntAnys(glados.any).intInRange(1, 21),
      glados.ExploreConfig(numRuns: 60),
    ).test(
      'any tool calls a round: the loop ends within maxTurns, ids are unique '
      'and every request is one a strict provider accepts',
      (callsPerRound, maxTurns) async {
        final run = await _runAdversarialWake(
          repository: repository,
          provider: provider,
          maxTurns: maxTurns,
          callsPerRound: callsPerRound,
        );
        final scenario = 'calls $callsPerRound, maxTurns $maxTurns';

        expect(run.requests, hasLength(maxTurns - 1), reason: scenario);
        expect(run.ids.toSet(), hasLength(run.ids.length), reason: scenario);
        for (final (i, request) in run.requests.indexed) {
          expect(
            _protocolFaults(request),
            isEmpty,
            reason: '$scenario, request ${i + 1}',
          );
        }
      },
      tags: 'glados',
    );

    test(
      'a message sent during a tool round waits until that send returns '
      '(Serialize)',
      () async {
        final conversationId = repository.createConversation(
          systemMessage: 'system',
        );
        final toolsRun = Completer<void>();
        final requests = <List<ChatCompletionMessage>>[];
        _stubGenerateText(mockOllamaRepo).thenAnswer((invocation) {
          requests.add(
            invocation.namedArguments[#messages] as List<ChatCompletionMessage>,
          );
          return Stream.value(
            requests.length == 1
                ? _idlessToolCallsResponse(2)
                : _contentResponse('done'),
          );
        });
        when(
          () => mockStrategy.processToolCalls(
            toolCalls: any(named: 'toolCalls'),
            manager: any(named: 'manager'),
          ),
        ).thenAnswer((invocation) async {
          await toolsRun.future;
          final manager =
              invocation.namedArguments[#manager] as ConversationManager;
          for (final call
              in invocation.namedArguments[#toolCalls]
                  as List<ChatCompletionMessageToolCall>) {
            manager.addToolResponse(toolCallId: call.id, response: 'ok');
          }
          return ConversationAction.wait;
        });

        Future<InferenceUsage?> send(String message) => repository.sendMessage(
          conversationId: conversationId,
          message: message,
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
          strategy: mockStrategy,
        );
        final first = send('first');
        final second = send('second');
        await pumpEventQueue();

        expect(
          requests,
          hasLength(1),
          reason: 'the second message is not sent while tools run',
        );
        expect(
          repository.getConversation(conversationId)!.messages.last.role,
          ChatCompletionMessageRole.assistant,
        );

        toolsRun.complete();
        await Future.wait([first, second]);

        expect(requests, hasLength(2));
        expect(_protocolFaults(requests.last), isEmpty);
        expect(
          repository
              .getConversation(conversationId)!
              .messages
              .map((m) => m.role),
          [
            ChatCompletionMessageRole.system,
            ChatCompletionMessageRole.user,
            ChatCompletionMessageRole.assistant,
            ChatCompletionMessageRole.tool,
            ChatCompletionMessageRole.tool,
            ChatCompletionMessageRole.user,
            ChatCompletionMessageRole.assistant,
          ],
        );
      },
    );

    test(
      'a strategy that throws mid-round leaves no call unanswered for the '
      'next message (EveryCallAnswered)',
      () async {
        final conversationId = repository.createConversation(
          systemMessage: 'system',
        );
        final requests = <List<ChatCompletionMessage>>[];
        _stubGenerateText(mockOllamaRepo).thenAnswer((invocation) {
          requests.add(
            invocation.namedArguments[#messages] as List<ChatCompletionMessage>,
          );
          return Stream.value(
            requests.length == 1
                ? _idlessToolCallsResponse(2)
                : _contentResponse('done'),
          );
        });
        when(
          () => mockStrategy.processToolCalls(
            toolCalls: any(named: 'toolCalls'),
            manager: any(named: 'manager'),
          ),
        ).thenAnswer((invocation) async {
          final calls =
              invocation.namedArguments[#toolCalls]
                  as List<ChatCompletionMessageToolCall>;
          (invocation.namedArguments[#manager] as ConversationManager)
              .addToolResponse(toolCallId: calls.first.id, response: 'ok');
          throw StateError('writing the action log failed');
        });

        Future<InferenceUsage?> send(String message) => repository.sendMessage(
          conversationId: conversationId,
          message: message,
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
          strategy: mockStrategy,
        );
        await send('first');
        final manager = repository.getConversation(conversationId)!;
        expect(manager.lastError, contains('writing the action log failed'));

        await send('the forced report retry');

        expect(requests, hasLength(2));
        expect(_protocolFaults(requests.last), isEmpty);
        expect(
          requests.last
              .map((m) => m.mapOrNull(tool: (tool) => tool.content))
              .nonNulls,
          ['ok', unansweredToolCallResult],
        );
      },
    );
  });
}
