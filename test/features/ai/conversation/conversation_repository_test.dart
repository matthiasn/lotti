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

class FakeChatCompletionMessage extends Fake
    implements ChatCompletionMessage {}

class FakeChatCompletionMessageToolCall extends Fake
    implements ChatCompletionMessageToolCall {}

class FakeAiConfigInferenceProvider extends Fake
    implements AiConfigInferenceProvider {}

void main() {
  late ProviderContainer container;
  late ConversationRepository repository;
  late MockOllamaInferenceRepository mockOllamaRepo;
  late MockConversationStrategy mockStrategy;

  setUpAll(() {
    registerFallbackValue(FakeChatCompletionMessage());
    registerFallbackValue(FakeChatCompletionMessageToolCall());
    registerFallbackValue(FakeAiConfigInferenceProvider());
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
            ollamaRepo: mockOllamaRepo,
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
          ollamaRepo: mockOllamaRepo,
        );

        // Emit response
        streamController.add(
          CreateChatCompletionStreamResponse(
            id: 'test-response',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: const ChatCompletionStreamResponseDelta(
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
          ollamaRepo: mockOllamaRepo,
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
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  toolCalls: [
                    ChatCompletionStreamMessageToolCallChunk(
                      index: 0,
                      id: 'tool-1',
                      type: ChatCompletionMessageToolCallType.function,
                      function: const ChatCompletionStreamMessageFunctionCallChunk(
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
        expect(manager.messages[1].toolCalls, isNotNull);
        expect(manager.messages[1].toolCalls!.length, 1);
        expect(manager.messages[1].toolCalls![0].function.name, 'test_function');
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
          ollamaRepo: mockOllamaRepo,
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
        streamController.add(
          CreateChatCompletionStreamResponse(
            id: 'test-response-1',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  toolCalls: [
                    ChatCompletionStreamMessageToolCallChunk(
                      index: 0,
                      id: 'tool-1',
                      type: ChatCompletionMessageToolCallType.function,
                      function: const ChatCompletionStreamMessageFunctionCallChunk(
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

        // Second response after continuation
        streamController.add(
          CreateChatCompletionStreamResponse(
            id: 'test-response-2',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: const ChatCompletionStreamResponseDelta(
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
          ollamaRepo: mockOllamaRepo,
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
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  toolCalls: [
                    ChatCompletionStreamMessageToolCallChunk(
                      index: 0,
                      id: 'tool-1',
                      type: ChatCompletionMessageToolCallType.function,
                      function: const ChatCompletionStreamMessageFunctionCallChunk(
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

        final streamController =
            StreamController<CreateChatCompletionStreamResponse>();

        when(() => mockOllamaRepo.generateTextWithMessages(
              messages: any(named: 'messages'),
              model: any(named: 'model'),
              provider: any(named: 'provider'),
              tools: any(named: 'tools'),
              temperature: any(named: 'temperature'),
            )).thenAnswer((_) => streamController.stream);

        // First message
        var sendFuture = repository.sendMessage(
          conversationId: conversationId,
          message: 'First message',
          model: 'test-model',
          provider: provider,
          ollamaRepo: mockOllamaRepo,
        );

        streamController.add(
          CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: const ChatCompletionStreamResponseDelta(
                  content: 'First response',
                ),
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );
        await sendFuture;

        // Second message - should still work
        sendFuture = repository.sendMessage(
          conversationId: conversationId,
          message: 'Second message',
          model: 'test-model',
          provider: provider,
          ollamaRepo: mockOllamaRepo,
        );

        streamController.add(
          CreateChatCompletionStreamResponse(
            id: 'response-2',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: const ChatCompletionStreamResponseDelta(
                  content: 'Second response',
                ),
              ),
            ],
            object: 'chat.completion.chunk',
            created: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );
        await sendFuture;

        // Third message - should hit limit
        await repository.sendMessage(
          conversationId: conversationId,
          message: 'Third message',
          model: 'test-model',
          provider: provider,
          ollamaRepo: mockOllamaRepo,
        );

        final manager = repository.getConversation(conversationId)!;
        // Should have 5 messages: 3 user + 2 assistant
        expect(manager.messages.length, 5);
        expect(manager.turnCount, 3);
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
          ollamaRepo: mockOllamaRepo,
        );

        // Wait for event processing
        await Future.delayed(Duration.zero);

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
          ollamaRepo: mockOllamaRepo,
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
        streamController.add(
          CreateChatCompletionStreamResponse(
            id: 'test-response',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  toolCalls: [
                    ChatCompletionStreamMessageToolCallChunk(
                      index: 0,
                      id: 'tool-1',
                      type: ChatCompletionMessageToolCallType.function,
                      function: const ChatCompletionStreamMessageFunctionCallChunk(
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
        );

        // Second chunk with more arguments
        streamController.add(
          CreateChatCompletionStreamResponse(
            id: 'test-response',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  toolCalls: [
                    ChatCompletionStreamMessageToolCallChunk(
                      index: 0,
                      id: 'tool-1',
                      type: ChatCompletionMessageToolCallType.function,
                      function: const ChatCompletionStreamMessageFunctionCallChunk(
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

        final manager = repository.getConversation(conversationId)!;
        expect(manager.messages[1].toolCalls, isNotNull);
        expect(manager.messages[1].toolCalls!.length, 1);
        expect(
          manager.messages[1].toolCalls![0].function.arguments,
          '{"arg": "value"}',
        );
      });
    });

    group('Provider tests', () {
      test('conversationEvents provider returns stream', () {
        final id = repository.createConversation();
        final manager = repository.getConversation(id)!;

        final stream = container.read(conversationEventsProvider(id));
        expect(stream, isA<Stream<ConversationEvent>>());

        // Test event emission
        final events = <ConversationEvent>[];
        stream.listen(events.add);

        manager.addUserMessage('Test message');

        // Allow event processing
        expect(events, isNotEmpty);
      });

      test('conversationEvents provider handles non-existent conversation', () {
        final stream = container.read(conversationEventsProvider('non-existent'));

        expect(
          stream,
          emitsError(contains('not found')),
        );
      });

      test('conversationMessages provider returns messages', () {
        final id = repository.createConversation(
          systemMessage: 'System message',
        );
        final manager = repository.getConversation(id)!;
        manager.addUserMessage('User message');

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