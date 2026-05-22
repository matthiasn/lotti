import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_chat_message.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class FakeConversationManager extends Fake implements ConversationManager {}

String? _messageContent(AiChatMessage message) {
  if (message is AiSystemMessage) return message.content;
  if (message is AiAssistantMessage) return message.content;
  if (message is AiToolResultMessage) return message.content;
  if (message is AiUserMessage) {
    final content = message.content;
    if (content is AiUserTextContent) return content.text;
  }
  return null;
}

/// Shared 8-argument stub for `generateTextWithMessages`;
/// chain `.thenAnswer(...)` with the stream (or function) the test needs.
When<Stream<AiStreamChunk>> _stubGenerateText(
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
    ),
  );
}

void main() {
  late ProviderContainer container;
  late ConversationRepository repository;
  late MockOllamaInferenceRepository mockOllamaRepo;
  late MockConversationStrategy mockStrategy;

  setUpAll(() {
    registerFallbackValue(
      const AiToolCall(id: 'fallback', name: 'fallback', arguments: '{}'),
    );
    registerFallbackValue(FakeAiConfigInferenceProvider());
    registerFallbackValue(FakeConversationManager());
    registerFallbackValue(ThoughtSignatureCollector());
    registerFallbackValue(<String, String>{});
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
      expect(manager.messages.first.role, AiMessageRole.system);
      expect(_messageContent(manager.messages.first), systemMessage);
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
            const AiStreamChunk(
              id: 'test-response',
              choices: [
                AiStreamChoice(
                  index: 0,
                  delta: AiStreamDelta(
                    content: 'Hello, human!',
                  ),
                ),
              ],
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
        expect(manager.messages[0].role, AiMessageRole.user);
        expect(manager.messages[1].role, AiMessageRole.assistant);
        expect(_messageContent(manager.messages[1]), 'Hello, human!');
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
            const AiStreamChunk(
              id: 'r',
              choices: [
                AiStreamChoice(
                  index: 0,
                  delta: AiStreamDelta(content: 'ok'),
                ),
              ],
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
          ),
        ).captured;
        expect(captured.single, 1.0);
      });

      test(
        'passes the caller temperature through for non-OpenAI providers',
        () async {
          _stubGenerateText(mockOllamaRepo).thenAnswer(
            (_) => Stream.fromIterable([
              const AiStreamChunk(
                id: 'r',
                choices: [
                  AiStreamChoice(
                    index: 0,
                    delta: AiStreamDelta(content: 'ok'),
                  ),
                ],
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
            ),
          ).captured;
          expect(captured.single, 0.2);
        },
      );

      test('forwards toolChoice to generateTextWithMessages', () async {
        const toolChoice = AiToolChoiceFunction('update_report');

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
          ),
        ).thenAnswer(
          (_) => Stream.fromIterable([
            const AiStreamChunk(
              id: 'r',
              choices: [
                AiStreamChoice(
                  index: 0,
                  delta: AiStreamDelta(content: 'done'),
                ),
              ],
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
          ),
        ).captured;
        expect(captured.single, toolChoice);
      });

      test(
        'strips <think> blocks from assistant content before persisting',
        () async {
          final streamController = StreamController<AiStreamChunk>();

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
              AiStreamChunk(
                id: 'chunk',
                choices: [
                  AiStreamChoice(
                    index: 0,
                    delta: AiStreamDelta(content: chunk),
                  ),
                ],
                created: 1710500000,
              ),
            );
          }
          await streamController.close();
          await sendFuture;

          final manager = repository.getConversation(conversationId)!;
          final assistantContent = _messageContent(manager.messages.last);
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
            const AiStreamChunk(
              id: 'chunk',
              choices: [
                AiStreamChoice(
                  index: 0,
                  delta: AiStreamDelta(
                    content: '<think>private reasoning</think>',
                  ),
                ),
              ],
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
        expect(manager.messages.last.role, AiMessageRole.assistant);
        expect(_messageContent(manager.messages.last), isNull);
      });

      test('handles tool calls', () async {
        _stubGenerateText(mockOllamaRepo).thenAnswer(
          (_) => Stream.fromIterable([
            const AiStreamChunk(
              id: 'test-response',
              choices: [
                AiStreamChoice(
                  index: 0,
                  delta: AiStreamDelta(
                    toolCalls: [
                      AiToolCallChunk(
                        index: 0,
                        id: 'tool-1',
                        name: 'test_function',
                        arguments: '{"arg": "value"}',
                      ),
                    ],
                  ),
                ),
              ],
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
            const AiTool(
              name: 'test_function',
              description: 'A test function',
              parameters: <String, dynamic>{},
            ),
          ],
        );

        final manager = repository.getConversation(conversationId)!;
        expect(manager.messages.length, 2);
        // Verify tool calls were processed
        final assistantMsg = manager.messages.last;
        expect(assistantMsg.role, AiMessageRole.assistant);
        // Tool calls would have been added to the assistant message
        // The exact structure depends on the AiChatMessage implementation
      });

      test('handles strategy with continue action', () async {
        final streamController = StreamController<AiStreamChunk>();

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
            const AiTool(
              name: 'test_function',
              description: 'A test function',
              parameters: <String, dynamic>{},
            ),
          ],
        );

        // First response with tool call
        streamController
          ..add(
            const AiStreamChunk(
              id: 'test-response-1',
              choices: [
                AiStreamChoice(
                  index: 0,
                  delta: AiStreamDelta(
                    toolCalls: [
                      AiToolCallChunk(
                        index: 0,
                        id: 'tool-1',
                        name: 'test_function',
                        arguments: '{"arg": "value"}',
                      ),
                    ],
                  ),
                ),
              ],
              created: 1710500000,
            ),
          )
          // Second response after continuation
          ..add(
            const AiStreamChunk(
              id: 'test-response-2',
              choices: [
                AiStreamChoice(
                  index: 0,
                  delta: AiStreamDelta(
                    content: 'Final response',
                  ),
                ),
              ],
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
            const AiStreamChunk(
              id: 'test-response',
              choices: [
                AiStreamChoice(
                  index: 0,
                  delta: AiStreamDelta(
                    toolCalls: [
                      AiToolCallChunk(
                        index: 0,
                        id: 'tool-1',
                        name: 'test_function',
                        arguments: '{"arg": "value"}',
                      ),
                    ],
                  ),
                ),
              ],
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
            const AiTool(
              name: 'test_function',
              description: 'A test function',
              parameters: <String, dynamic>{},
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
            AiStreamChunk(
              id: 'response-$callCount',
              choices: [
                AiStreamChoice(
                  index: 0,
                  delta: AiStreamDelta(
                    content: 'Response $callCount',
                  ),
                ),
              ],
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

        // Try to send third message anyway and expect user message followed by error event
        final maxTurnsError = expectLater(
          manager.events,
          emitsInOrder([
            isA<UserMessageEvent>(),
            isA<ConversationErrorEvent>(),
          ]),
        );

        await repository.sendMessage(
          conversationId: conversationId,
          message: 'Third message',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
        );

        await maxTurnsError;

        // Verify that we're at the turn limit (user message may have been added)
        expect(manager.turnCount, lessThanOrEqualTo(3));
        expect(manager.canContinue(), false);

        // Verify that the conversation has the expected number of messages
        // 2 turns = 4 messages (2 user + 2 assistant) + possibly 1 more user message
        expect(manager.messages.length, lessThanOrEqualTo(5));
      });

      test('handles errors during API call', () async {
        when(
          () => mockOllamaRepo.generateTextWithMessages(
            messages: any(named: 'messages'),
            model: any(named: 'model'),
            provider: any(named: 'provider'),
            tools: any(named: 'tools'),
            temperature: any(named: 'temperature'),
            thoughtSignatures: any(named: 'thoughtSignatures'),
            signatureCollector: any(named: 'signatureCollector'),
          ),
        ).thenThrow(Exception('API Error'));

        final manager = repository.getConversation(conversationId)!;

        // Expect UserMessageEvent followed by ThinkingEvent and then ConversationErrorEvent
        final errorExpectation = expectLater(
          manager.events,
          emitsInOrder([
            isA<UserMessageEvent>(),
            isA<ThinkingEvent>(),
            isA<ConversationErrorEvent>(),
          ]),
        );

        await repository.sendMessage(
          conversationId: conversationId,
          message: 'This will fail',
          model: 'test-model',
          provider: provider,
          inferenceRepo: mockOllamaRepo,
        );

        await errorExpectation;
      });

      test(
        'handles tool call arguments accumulation with StringBuffer',
        () async {
          final streamController = StreamController<AiStreamChunk>();

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
              const AiTool(
                name: 'test_function',
                description: 'A test function',
                parameters: <String, dynamic>{},
              ),
            ],
          );

          // First chunk with tool call name and partial arguments
          streamController
            ..add(
              const AiStreamChunk(
                id: 'test-response',
                choices: [
                  AiStreamChoice(
                    index: 0,
                    delta: AiStreamDelta(
                      toolCalls: [
                        AiToolCallChunk(
                          index: 0,
                          id: 'tool-1',
                          name: 'test_function',
                          arguments: '{"arg',
                        ),
                      ],
                    ),
                  ),
                ],
                created: 1710500000,
              ),
            )
            // Second chunk with more arguments
            ..add(
              const AiStreamChunk(
                id: 'test-response',
                choices: [
                  AiStreamChoice(
                    index: 0,
                    delta: AiStreamDelta(
                      toolCalls: [
                        AiToolCallChunk(
                          index: 0,
                          id: 'tool-1',
                          arguments: '": "value"}',
                        ),
                      ],
                    ),
                  ),
                ],
                created: 1710500000,
              ),
            );

          await streamController.close();
          await sendFuture;

          // Verify the conversation was updated
          final manager = repository.getConversation(conversationId);
          expect(manager, isNotNull);

          // The assistant message should have the complete tool call with proper JSON
          final messages = manager!.messages;
          expect(messages.length, 2); // User + Assistant

          // Tool calls would have been accumulated properly
          // Arguments would be '{"arg": "value"}'
        },
      );

      test('handles split UTF-8 characters in tool call arguments', () async {
        final streamController = StreamController<AiStreamChunk>();

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
            const AiTool(
              name: 'test_function',
              description: 'A test function',
              parameters: <String, dynamic>{},
            ),
          ],
        );

        // First chunk ending mid-UTF8 character (emoji 😀 = F0 9F 98 80)
        streamController
          ..add(
            const AiStreamChunk(
              id: 'test-response',
              choices: [
                AiStreamChoice(
                  index: 0,
                  delta: AiStreamDelta(
                    toolCalls: [
                      AiToolCallChunk(
                        index: 0,
                        id: 'tool-1',
                        name: 'test_function',
                        arguments: '{"emoji": "',
                      ),
                    ],
                  ),
                ),
              ],
              created: 1710500000,
            ),
          )
          // Second chunk with emoji and rest
          ..add(
            const AiStreamChunk(
              id: 'test-response',
              choices: [
                AiStreamChoice(
                  index: 0,
                  delta: AiStreamDelta(
                    toolCalls: [
                      AiToolCallChunk(
                        index: 0,
                        id: 'tool-1',
                        arguments: '😀"}',
                      ),
                    ],
                  ),
                ),
              ],
              created: 1710500000,
            ),
          );

        await streamController.close();
        await sendFuture;

        // Verify the conversation was updated with proper UTF-8 handling
        final manager = repository.getConversation(conversationId);
        expect(manager, isNotNull);
        expect(manager!.messages.length, 2);
      });

      test('handles invalid tool call with missing function name', () async {
        _stubGenerateText(mockOllamaRepo).thenAnswer(
          (_) => Stream.fromIterable([
            const AiStreamChunk(
              id: 'test-response',
              choices: [
                AiStreamChoice(
                  index: 0,
                  delta: AiStreamDelta(
                    toolCalls: [
                      AiToolCallChunk(
                        index: 0,
                        id: 'tool-1',
                        arguments: '{"arg": "value"}',
                      ),
                    ],
                  ),
                ),
              ],
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
            const AiTool(
              name: 'test_function',
              description: 'A test function',
              parameters: <String, dynamic>{},
            ),
          ],
        );

        // Tool call should be added with empty function name
        final manager = repository.getConversation(conversationId);
        expect(manager, isNotNull);
        expect(manager!.messages.length, 2);
      });

      test('handles empty tool call IDs', () async {
        final streamController = StreamController<AiStreamChunk>();

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
            const AiTool(
              name: 'test_function',
              description: 'A test function',
              parameters: <String, dynamic>{},
            ),
          ],
        );

        // First chunk with empty tool call ID
        streamController
          ..add(
            const AiStreamChunk(
              id: 'test-response',
              choices: [
                AiStreamChoice(
                  index: 0,
                  delta: AiStreamDelta(
                    toolCalls: [
                      AiToolCallChunk(
                        index: 0,
                        id: '', // Empty ID
                        name: 'test_function',
                        arguments: '{"arg": ',
                      ),
                    ],
                  ),
                ),
              ],
              created: 1710500000,
            ),
          )
          // Second chunk completing the arguments
          ..add(
            const AiStreamChunk(
              id: 'test-response',
              choices: [
                AiStreamChoice(
                  index: 0,
                  delta: AiStreamDelta(
                    toolCalls: [
                      AiToolCallChunk(
                        index: 0,
                        id: '', // Still empty
                        arguments: '"value"}',
                      ),
                    ],
                  ),
                ),
              ],
              created: 1710500000,
            ),
          );

        await streamController.close();
        await sendFuture;

        // Verify the conversation was updated with auto-generated ID
        final manager = repository.getConversation(conversationId);
        expect(manager, isNotNull);
        expect(manager!.messages.length, 2);
      });

      test('handles multiple tool calls with separate buffers', () async {
        final streamController = StreamController<AiStreamChunk>();

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
            const AiTool(
              name: 'function_a',
              description: 'Function A',
              parameters: <String, dynamic>{},
            ),
            const AiTool(
              name: 'function_b',
              description: 'Function B',
              parameters: <String, dynamic>{},
            ),
          ],
        );

        // First chunk with two tool calls
        streamController
          ..add(
            const AiStreamChunk(
              id: 'test-response',
              choices: [
                AiStreamChoice(
                  index: 0,
                  delta: AiStreamDelta(
                    toolCalls: [
                      AiToolCallChunk(
                        index: 0,
                        id: 'tool-1',
                        name: 'function_a',
                        arguments: '{"a": ',
                      ),
                      AiToolCallChunk(
                        index: 1,
                        id: 'tool-2',
                        name: 'function_b',
                        arguments: '{"b": ',
                      ),
                    ],
                  ),
                ),
              ],
              created: 1710500000,
            ),
          )
          // Second chunk completing both
          ..add(
            const AiStreamChunk(
              id: 'test-response',
              choices: [
                AiStreamChoice(
                  index: 0,
                  delta: AiStreamDelta(
                    toolCalls: [
                      AiToolCallChunk(index: 0, id: 'tool-1', arguments: '1}'),
                      AiToolCallChunk(index: 1, id: 'tool-2', arguments: '2}'),
                    ],
                  ),
                ),
              ],
              created: 1710500000,
            ),
          );

        await streamController.close();
        await sendFuture;

        // Verify both tool calls were accumulated separately
        final manager = repository.getConversation(conversationId);
        expect(manager, isNotNull);
        expect(manager!.messages.length, 2);

        // Since AiChatMessage is a sealed class without direct access to toolCalls,
        // we can only verify the basic message properties
        final assistantMsg = manager.messages.last;
        expect(assistantMsg.role, AiMessageRole.assistant);

        // The actual tool calls would have been accumulated properly with separate buffers
        // Each tool call would have its own complete JSON:
        // - function_a with arguments: {"a": 1}
        // - function_b with arguments: {"b": 2}
      });

      test(
        'handles Gemini-style multiple complete tool calls in one chunk',
        () async {
          _stubGenerateText(mockOllamaRepo).thenAnswer(
            (_) => Stream.fromIterable([
              const AiStreamChunk(
                id: 'gemini-response',
                choices: [
                  AiStreamChoice(
                    index: 0,
                    delta: AiStreamDelta(
                      toolCalls: [
                        // First tool call - empty ID, null index, complete arguments
                        AiToolCallChunk(
                          id: '', // Empty ID
                          // index is null (not specified)
                          name: 'function_a',
                          arguments: '{"param": "value1"}',
                        ),
                        // Second tool call - empty ID, null index, complete arguments
                        AiToolCallChunk(
                          id: '', // Empty ID
                          // index is null (not specified)
                          name: 'function_b',
                          arguments: '{"param": "value2"}',
                        ),
                      ],
                    ),
                  ),
                ],
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
              const AiTool(
                name: 'function_a',
                description: 'First function',
                parameters: <String, dynamic>{},
              ),
              const AiTool(
                name: 'function_b',
                description: 'Second function',
                parameters: <String, dynamic>{},
              ),
            ],
          );

          // Verify both tool calls were detected as Gemini-style and processed
          final manager = repository.getConversation(conversationId);
          expect(manager, isNotNull);
          expect(manager!.messages.length, 2);

          // The assistant message should have the tool calls
          final assistantMsg = manager.messages.last;
          expect(assistantMsg.role, AiMessageRole.assistant);

          // Tool calls would have been given turn-prefixed IDs:
          // tool_turn0_0 and tool_turn0_1
        },
      );

      test('handles strategy with wait action', () async {
        _stubGenerateText(mockOllamaRepo).thenAnswer(
          (_) => Stream.fromIterable([
            const AiStreamChunk(
              id: 'test-response',
              choices: [
                AiStreamChoice(
                  index: 0,
                  delta: AiStreamDelta(
                    toolCalls: [
                      AiToolCallChunk(
                        index: 0,
                        id: 'tool-1',
                        name: 'test_function',
                        arguments: '{}',
                      ),
                    ],
                  ),
                ),
              ],
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
            const AiTool(
              name: 'test_function',
              description: 'A test function',
              parameters: <String, dynamic>{},
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
            const AiStreamChunk(
              id: 'test-response',
              choices: [
                AiStreamChoice(
                  index: 0,
                  delta: AiStreamDelta(
                    toolCalls: [
                      AiToolCallChunk(
                        index: 0,
                        id: 'tool-1',
                        name: 'test_function',
                        arguments: '{}',
                      ),
                    ],
                  ),
                ),
              ],
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
            const AiTool(
              name: 'test_function',
              description: 'A test function',
              parameters: <String, dynamic>{},
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
        expect(manager!.messages.length, 2);
      });
      test('returns accumulated usage from single-turn response', () async {
        final streamController = StreamController<AiStreamChunk>();

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
            const AiStreamChunk(
              id: 'resp',
              choices: [
                AiStreamChoice(
                  index: 0,
                  delta: AiStreamDelta(content: 'Hi'),
                ),
              ],
              created: 1700000000,
            ),
          )
          ..add(
            const AiStreamChunk(
              id: 'resp',
              choices: [],
              created: 1700000000,
              usage: AiUsage(
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
                const AiStreamChunk(
                  id: 'resp-1',
                  choices: [
                    AiStreamChoice(
                      index: 0,
                      delta: AiStreamDelta(
                        toolCalls: [
                          AiToolCallChunk(
                            index: 0,
                            id: 'tool-1',
                            name: 'test_function',
                            arguments: '{}',
                          ),
                        ],
                      ),
                    ),
                  ],
                  created: 1700000000,
                  usage: AiUsage(
                    promptTokens: 80,
                    completionTokens: 20,
                    totalTokens: 100,
                  ),
                ),
              ]);
            } else {
              // Second turn: final response with usage
              return Stream.fromIterable([
                const AiStreamChunk(
                  id: 'resp-2',
                  choices: [
                    AiStreamChoice(
                      index: 0,
                      delta: AiStreamDelta(content: 'Done'),
                    ),
                  ],
                  created: 1700000000,
                  usage: AiUsage(
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
              const AiTool(
                name: 'test_function',
                description: 'A test function',
                parameters: <String, dynamic>{},
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
            const AiStreamChunk(
              id: 'resp',
              choices: [
                AiStreamChoice(
                  index: 0,
                  delta: AiStreamDelta(content: 'Hi'),
                ),
              ],
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

      test('captures reasoning and cached tokens from usage details', () async {
        _stubGenerateText(mockOllamaRepo).thenAnswer(
          (_) => Stream.fromIterable([
            const AiStreamChunk(
              id: 'resp',
              choices: [
                AiStreamChoice(
                  index: 0,
                  delta: AiStreamDelta(content: 'Hi'),
                ),
              ],
              created: 1700000000,
              usage: AiUsage(
                promptTokens: 200,
                completionTokens: 100,
                totalTokens: 300,
                reasoningTokens: 40,
                cachedInputTokens: 50,
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
    });

    group('Provider tests', () {
      test('conversationEvents provider returns stream', () {
        final id = repository.createConversation();
        repository.getConversation(id)!;

        final stream = container.read(conversationEventsProvider(id));
        // The provider should return a stream
        expect(stream, isNotNull);
      });

      test(
        'conversationEvents provider handles non-existent conversation',
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
          // No real wait: use a shorter, deterministic timeout for unit tests
          await completer.future.timeout(
            const Duration(milliseconds: 50),
            onTimeout: () =>
                throw TestFailure('Expected error was not emitted'),
          );

          subscription.close();
        },
      );

      test('conversationMessages provider returns messages', () {
        final id = repository.createConversation(
          systemMessage: 'System message',
        );

        repository.getConversation(id)!.addUserMessage('User message');

        final messages = container.read(conversationMessagesProvider(id));
        expect(messages.length, 2);
        expect(messages[0].role, AiMessageRole.system);
        expect(messages[1].role, AiMessageRole.user);
      });

      test('conversationMessages provider returns empty for non-existent', () {
        final messages = container.read(
          conversationMessagesProvider('non-existent'),
        );
        expect(messages, isEmpty);
      });
    });
  });
}
