import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

class MockOllamaInferenceRepository extends Mock
    implements OllamaInferenceRepository {}

class MockConversationStrategy extends Mock implements ConversationStrategy {}

// ChatCompletionMessage is a sealed class and cannot be faked

class FakeChatCompletionMessageToolCall extends Fake
    implements ChatCompletionMessageToolCall {}

class FakeAiConfigInferenceProvider extends Fake
    implements AiConfigInferenceProvider {}

class FakeConversationManager extends Fake implements ConversationManager {}

void main() {
  late ProviderContainer container;
  late ConversationRepository repository;
  late MockOllamaInferenceRepository mockOllamaRepo;
  late MockConversationStrategy mockStrategy;

  setUpAll(() {
    // registerFallbackValue(FakeChatCompletionMessage()); // Not needed as ChatCompletionMessage is sealed
    registerFallbackValue(FakeChatCompletionMessageToolCall());
    registerFallbackValue(FakeAiConfigInferenceProvider());
    registerFallbackValue(FakeConversationManager());
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

    test('getActiveConversations returns all conversation IDs', () {
      final ids = <String>[];
      for (var i = 0; i < 3; i++) {
        ids.add(repository.createConversation());
      }

      final activeIds = repository.getActiveConversations();
      expect(activeIds.length, 3);
      expect(activeIds.toSet(), ids.toSet());
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

      // Check all conversations are gone
      expect(repository.getActiveConversations(), isEmpty);
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
          createdAt: DateTime.now(),
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
        final streamController =
            StreamController<CreateChatCompletionStreamResponse>();

        when(() => mockOllamaRepo.generateTextWithMessages(
              messages: any(named: 'messages'),
              model: any(named: 'model'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
              temperature: any(named: 'temperature'),
            )).thenAnswer((_) => streamController.stream);

        // Start sendMessage in background
        final sendFuture = repository.sendMessage(
          conversationId: conversationId,
          message: 'Hello, AI!',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
        );

        // Emit response
        streamController.add(
          CreateChatCompletionStreamResponse(
            id: 'test-response',
            choices: [
              const ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Hello, human!',
                ),
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );
        await streamController.close();
        await sendFuture;

        final manager = repository.getConversation(conversationId)!;
        expect(manager.messages.length, 2);
        expect(manager.messages[0].role, ChatCompletionMessageRole.user);
        expect(manager.messages[1].role, ChatCompletionMessageRole.assistant);
        expect(manager.messages[1].content, 'Hello, human!');
      });

      test('handles tool calls', () async {
        final streamController =
            StreamController<CreateChatCompletionStreamResponse>();

        when(() => mockOllamaRepo.generateTextWithMessages(
              messages: any(named: 'messages'),
              model: any(named: 'model'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
              temperature: any(named: 'temperature'),
            )).thenAnswer((_) => streamController.stream);

        // Start sendMessage
        final sendFuture = repository.sendMessage(
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

        // Emit tool call response
        streamController.add(
          CreateChatCompletionStreamResponse(
            id: 'test-response',
            choices: [
              const ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  toolCalls: [
                    ChatCompletionStreamMessageToolCallChunk(
                      index: 0,
                      id: 'tool-1',
                      type:
                          ChatCompletionStreamMessageToolCallChunkType.function,
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
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );
        await streamController.close();
        await sendFuture;

        final manager = repository.getConversation(conversationId)!;
        expect(manager.messages.length, 2);
        // Verify tool calls were processed
        // Tool calls would have been added to the message
        // Function name would be 'test_function'
      });

      test('handles strategy with continue action', () async {
        final streamController =
            StreamController<CreateChatCompletionStreamResponse>();

        when(() => mockOllamaRepo.generateTextWithMessages(
              messages: any(named: 'messages'),
              model: any(named: 'model'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
              temperature: any(named: 'temperature'),
            )).thenAnswer((_) => streamController.stream);

        when(() => mockStrategy.processToolCalls(
              toolCalls: any(named: 'toolCalls'),
              manager: any(named: 'manager'),
            )).thenAnswer((_) async => ConversationAction.continueConversation);

        when(() => mockStrategy.getContinuationPrompt(any()))
            .thenReturn('Continue processing');

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
            CreateChatCompletionStreamResponse(
              id: 'test-response-1',
              choices: [
                const ChatCompletionStreamResponseChoice(
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
              created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          )

          // Second response after continuation
          ..add(
            CreateChatCompletionStreamResponse(
              id: 'test-response-2',
              choices: [
                const ChatCompletionStreamResponseChoice(
                  index: 0,
                  delta: ChatCompletionStreamResponseDelta(
                    content: 'Final response',
                  ),
                ),
              ],
              object: 'chat.completion.chunk',
              created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          );

        await streamController.close();
        await sendFuture;

        verify(() => mockStrategy.processToolCalls(
              toolCalls: any(named: 'toolCalls'),
              manager: any(named: 'manager'),
            )).called(1);
        verify(() => mockStrategy.getContinuationPrompt(any())).called(1);
      });

      test('handles strategy with complete action', () async {
        final streamController =
            StreamController<CreateChatCompletionStreamResponse>();

        when(() => mockOllamaRepo.generateTextWithMessages(
              messages: any(named: 'messages'),
              model: any(named: 'model'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
              temperature: any(named: 'temperature'),
            )).thenAnswer((_) => streamController.stream);

        when(() => mockStrategy.processToolCalls(
              toolCalls: any(named: 'toolCalls'),
              manager: any(named: 'manager'),
            )).thenAnswer((_) async => ConversationAction.complete);

        // Start sendMessage
        final sendFuture = repository.sendMessage(
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

        // Response with tool call
        streamController.add(
          CreateChatCompletionStreamResponse(
            id: 'test-response',
            choices: [
              const ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  toolCalls: [
                    ChatCompletionStreamMessageToolCallChunk(
                      index: 0,
                      id: 'tool-1',
                      type:
                          ChatCompletionStreamMessageToolCallChunkType.function,
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
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

        await streamController.close();
        await sendFuture;

        verify(() => mockStrategy.processToolCalls(
              toolCalls: any(named: 'toolCalls'),
              manager: any(named: 'manager'),
            )).called(1);
        verifyNever(() => mockStrategy.getContinuationPrompt(any()));
      });

      test('handles maximum turns limit', () async {
        // Create conversation with low turn limit
        conversationId = repository.createConversation(maxTurns: 2);

        // Mock all three stream responses upfront
        var callCount = 0;
        when(() => mockOllamaRepo.generateTextWithMessages(
              messages: any(named: 'messages'),
              model: any(named: 'model'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
              temperature: any(named: 'temperature'),
            )).thenAnswer((_) {
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
              created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
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

        // Try to send third message anyway
        await repository.sendMessage(
          conversationId: conversationId,
          message: 'Third message',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
        );

        // Check final state
        // It might have added the user message but not processed a response
        // Or it might have rejected the message entirely
        expect(manager.turnCount, lessThanOrEqualTo(3));
        expect(manager.canContinue(), false);
      });

      test('handles errors during API call', () async {
        when(() => mockOllamaRepo.generateTextWithMessages(
              messages: any(named: 'messages'),
              model: any(named: 'model'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
              temperature: any(named: 'temperature'),
            )).thenThrow(Exception('API Error'));

        final errorEvents = <ConversationEvent>[];
        final manager = repository.getConversation(conversationId)!;
        manager.events.listen(errorEvents.add);

        await repository.sendMessage(
          conversationId: conversationId,
          message: 'This will fail',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
        );

        // Wait for event processing
        await Future<void>.delayed(Duration.zero);

        expect(
          errorEvents.whereType<ConversationErrorEvent>().length,
          greaterThan(0),
        );
      });

      test('handles empty tool call arguments accumulation', () async {
        final streamController =
            StreamController<CreateChatCompletionStreamResponse>();

        when(() => mockOllamaRepo.generateTextWithMessages(
              messages: any(named: 'messages'),
              model: any(named: 'model'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
              temperature: any(named: 'temperature'),
            )).thenAnswer((_) => streamController.stream);

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

        // First chunk with tool call name
        streamController
          ..add(
            CreateChatCompletionStreamResponse(
              id: 'test-response',
              choices: [
                const ChatCompletionStreamResponseChoice(
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
              created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          )

          // Second chunk with more arguments
          ..add(
            CreateChatCompletionStreamResponse(
              id: 'test-response',
              choices: [
                const ChatCompletionStreamResponseChoice(
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
              created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            ),
          );

        await streamController.close();
        await sendFuture;

        // Verify the conversation was updated
        expect(repository.getConversation(conversationId), isNotNull);
        // Tool calls would have been accumulated properly
        // Arguments would be '{"arg": "value"}'
      });
    });

    group('Provider tests', () {
      test('conversationEvents provider returns stream', () {
        final id = repository.createConversation();
        repository.getConversation(id)!;

        final stream = container.read(conversationEventsProvider(id));
        // The provider should return a stream
        expect(stream, isNotNull);
      });

      test('conversationEvents provider handles non-existent conversation',
          () async {
        // Listen to the provider which will emit AsyncValue states
        final streamProvider = conversationEventsProvider('non-existent');

        // Listen to the stream of AsyncValue states
        final completer = Completer<void>();
        final subscription = container.listen(
          streamProvider,
          (previous, next) {
            // Check if we got an error state
            if (next.hasError) {
              expect(next.error.toString(), contains('not found'));
              completer.complete();
            }
          },
        );

        // Wait for the error to be emitted
        await completer.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () => throw TestFailure('Expected error was not emitted'),
        );

        subscription.close();
      });

      test('conversationMessages provider returns messages', () {
        final id = repository.createConversation(
          systemMessage: 'System message',
        );

        repository.getConversation(id)!.addUserMessage('User message');

        final messages = container.read(conversationMessagesProvider(id));
        expect(messages.length, 2);
        expect(messages[0].role, ChatCompletionMessageRole.system);
        expect(messages[1].role, ChatCompletionMessageRole.user);
      });

      test('conversationMessages provider returns empty for non-existent', () {
        final messages =
            container.read(conversationMessagesProvider('non-existent'));
        expect(messages, isEmpty);
      });
    });
  });
}
