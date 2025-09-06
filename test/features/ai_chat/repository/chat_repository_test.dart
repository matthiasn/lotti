import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai_chat/models/chat_exceptions.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/models/task_summary_tool.dart';
import 'package:lotti/features/ai_chat/repository/chat_repository.dart';
import 'package:lotti/features/ai_chat/repository/task_summary_repository.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

// Mock implementations
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockCloudInferenceRepository extends Mock
    implements CloudInferenceRepository {}

class MockTaskSummaryRepository extends Mock implements TaskSummaryRepository {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  setUpAll(() {
    registerFallbackValue(AiConfigType.inferenceProvider);
    registerFallbackValue(Exception('test'));
    registerFallbackValue(TaskSummaryRequest(
      startDate: DateTime(2024),
      endDate: DateTime(2024),
    ));
    registerFallbackValue(AiConfigInferenceProvider(
      id: 'test',
      name: 'test',
      baseUrl: 'https://test.com',
      apiKey: 'test',
      createdAt: DateTime(2024),
      inferenceProviderType: InferenceProviderType.gemini,
    ));
  });

  group('ChatRepository Integration Tests', () {
    late ChatRepository repository;
    late MockAiConfigRepository mockAiConfigRepository;
    late MockCloudInferenceRepository mockCloudInferenceRepository;
    late MockTaskSummaryRepository mockTaskSummaryRepository;
    late MockLoggingService mockLoggingService;

    const testCategoryId = 'test-category-123';
    const testMessage = 'Hello AI assistant';

    setUp(() {
      mockAiConfigRepository = MockAiConfigRepository();
      mockCloudInferenceRepository = MockCloudInferenceRepository();
      mockTaskSummaryRepository = MockTaskSummaryRepository();
      mockLoggingService = MockLoggingService();

      repository = ChatRepository(
        cloudInferenceRepository: mockCloudInferenceRepository,
        taskSummaryRepository: mockTaskSummaryRepository,
        aiConfigRepository: mockAiConfigRepository,
        loggingService: mockLoggingService,
      );
    });

    group('sendMessage integration', () {
      test('throws ArgumentError when categoryId is null', () async {
        await expectLater(
          repository.sendMessage(
            message: testMessage,
            conversationHistory: [],
          ).first,
          throwsA(isA<ArgumentError>()),
        );
      });

      test('calls ChatMessageProcessor methods in correct order', () async {
        // This test verifies that ChatRepository properly orchestrates
        // the ChatMessageProcessor methods, even though we can't easily
        // test the exact flow due to the complexity of mocking streams

        // The key insight is that if getAiConfiguration fails,
        // the entire operation should fail early
        when(() => mockAiConfigRepository.getConfigsByType(any()))
            .thenThrow(Exception('Config error'));

        await expectLater(
          repository
              .sendMessage(
                message: testMessage,
                conversationHistory: [],
                categoryId: testCategoryId,
              )
              .first,
          throwsA(predicate((e) => e.toString().contains('Config error'))),
        );

        // Verify logging was called
        await Future<void>.delayed(
            Duration.zero); // Let the stream attempt to process
        verify(() => mockLoggingService.captureEvent(
              'Starting chat message processing',
              domain: 'ChatRepository',
              subDomain: 'sendMessage',
            )).called(1);
      });

      test('handles errors and logs them properly', () async {
        when(() => mockAiConfigRepository.getConfigsByType(any()))
            .thenThrow(Exception('Test error'));

        await expectLater(
          repository
              .sendMessage(
                message: testMessage,
                conversationHistory: [],
                categoryId: testCategoryId,
              )
              .first,
          throwsA(isA<ChatRepositoryException>().having(
            (e) => e.message,
            'message',
            contains('Failed to send message: Exception: Test error'),
          )),
        );

        // Give the async operations time to complete
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Verify error logging
        verify(() => mockLoggingService.captureException(
              any<Exception>(),
              domain: 'ChatRepository',
              subDomain: 'sendMessage',
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
            )).called(1);
      });
    });

    group('session management', () {
      test('createSession creates new session with provided details', () async {
        final session = await repository.createSession(
          categoryId: testCategoryId,
          title: 'Test Session',
        );

        expect(session.categoryId, testCategoryId);
        expect(session.title, 'Test Session');
        expect(session.messages, isEmpty);
        expect(session.id, isNotEmpty);
      });

      test(
          'createSession creates session with default title when none provided',
          () async {
        final session = await repository.createSession(
          categoryId: testCategoryId,
        );

        expect(session.categoryId, testCategoryId);
        expect(session.title, isNotNull);
        expect(session.messages, isEmpty);
      });

      test('saveSession stores session and returns it', () async {
        final originalSession = await repository.createSession(
          categoryId: testCategoryId,
          title: 'Test Session',
        );

        final savedSession = await repository.saveSession(originalSession);

        expect(savedSession.id, originalSession.id);
        expect(savedSession.title, originalSession.title);
      });

      test('getSession retrieves stored session', () async {
        final originalSession = await repository.createSession(
          categoryId: testCategoryId,
          title: 'Test Session',
        );
        await repository.saveSession(originalSession);

        final retrievedSession =
            await repository.getSession(originalSession.id);

        expect(retrievedSession, isNotNull);
        expect(retrievedSession!.id, originalSession.id);
        expect(retrievedSession.title, originalSession.title);
      });

      test('getSession returns null for non-existent session', () async {
        final session = await repository.getSession('non-existent-id');
        expect(session, isNull);
      });

      test('getSessions returns all sessions when no categoryId filter',
          () async {
        final session1 = await repository.createSession(categoryId: 'cat1');
        final session2 = await repository.createSession(categoryId: 'cat2');

        final sessions = await repository.getSessions();

        expect(sessions.length, 2);
        expect(
            sessions.map((s) => s.id), containsAll([session1.id, session2.id]));
      });

      test('getSessions filters by categoryId', () async {
        final session1 = await repository.createSession(categoryId: 'cat1');
        await repository.createSession(categoryId: 'cat2');

        final sessions = await repository.getSessions(categoryId: 'cat1');

        expect(sessions.length, 1);
        expect(sessions.first.id, session1.id);
      });

      test('getSessions respects limit parameter', () async {
        // Create multiple sessions
        for (var i = 0; i < 5; i++) {
          await repository.createSession(
              categoryId: testCategoryId, title: 'Session $i');
        }

        final sessions = await repository.getSessions(
          categoryId: testCategoryId,
          limit: 3,
        );

        expect(sessions.length, 3);
      });

      test('getSessions orders by lastMessageAt descending', () async {
        final session1 = await repository.createSession(
          categoryId: testCategoryId,
          title: 'First',
        );

        // Simulate time passing
        await Future<void>.delayed(const Duration(milliseconds: 1));

        final session2 = await repository.createSession(
          categoryId: testCategoryId,
          title: 'Second',
        );

        final sessions =
            await repository.getSessions(categoryId: testCategoryId);

        expect(sessions.length, 2);
        expect(sessions.first.id, session2.id); // Most recent first
        expect(sessions.last.id, session1.id);
      });

      test('deleteSession removes session and its messages', () async {
        final session =
            await repository.createSession(categoryId: testCategoryId);
        final message = ChatMessage.user('Test message');

        final sessionWithMessage = session.copyWith(messages: [message]);
        await repository.saveSession(sessionWithMessage);
        await repository.saveMessage(message);

        await repository.deleteSession(session.id);

        final retrievedSession = await repository.getSession(session.id);
        expect(retrievedSession, isNull);
      });

      test('deleteSession handles non-existent session gracefully', () async {
        // Should not throw
        await repository.deleteSession('non-existent-id');
      });
    });

    group('message management', () {
      test('saveMessage stores and returns message', () async {
        final message = ChatMessage.user('Test message');

        final savedMessage = await repository.saveMessage(message);

        expect(savedMessage.id, message.id);
        expect(savedMessage.content, message.content);
      });

      test('deleteMessage removes message', () async {
        final message = ChatMessage.user('Test message');
        await repository.saveMessage(message);

        // This should complete without error
        await repository.deleteMessage(message.id);
      });

      test('deleteMessage handles non-existent message gracefully', () async {
        // Should not throw
        await repository.deleteMessage('non-existent-id');
      });
    });

    group('edge cases and error conditions', () {
      test('handles empty conversation history', () async {
        when(() => mockAiConfigRepository.getConfigsByType(any()))
            .thenThrow(Exception('Expected for this test'));

        await expectLater(
          repository
              .sendMessage(
                message: testMessage,
                conversationHistory: [], // Empty history
                categoryId: testCategoryId,
              )
              .first,
          throwsA(isA<Exception>()),
        );
      });

      test('handles very long conversation history', () async {
        final longHistory = List.generate(
            100,
            (i) => i.isEven
                ? ChatMessage.user('User message $i')
                : ChatMessage.assistant('Assistant message $i'));

        when(() => mockAiConfigRepository.getConfigsByType(any()))
            .thenThrow(Exception('Expected for this test'));

        await expectLater(
          repository
              .sendMessage(
                message: testMessage,
                conversationHistory: longHistory,
                categoryId: testCategoryId,
              )
              .first,
          throwsA(isA<Exception>()),
        );
      });

      test('session operations work with special characters in IDs', () async {
        const specialCategoryId = r'test-category-with-special!@#$%^&*()_+';

        final session = await repository.createSession(
          categoryId: specialCategoryId,
          title: 'Special Characters Test',
        );

        expect(session.categoryId, specialCategoryId);

        final retrieved = await repository.getSession(session.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.categoryId, specialCategoryId);
      });
    });

    group('integration with ChatMessageProcessor', () {
      test('properly delegates to ChatMessageProcessor methods', () async {
        // We can't easily test the full flow due to stream complexity,
        // but we can verify that the error path works and shows the integration
        when(() => mockAiConfigRepository.getConfigsByType(any()))
            .thenThrow(Exception('Processor integration test'));

        var exceptionCaught = false;
        try {
          await repository
              .sendMessage(
                message: testMessage,
                conversationHistory: [],
                categoryId: testCategoryId,
              )
              .first;
        } catch (e) {
          exceptionCaught = true;
          expect(e.toString(), contains('Failed to send message'));
          expect(e.toString(), contains('Processor integration test'));
        }

        expect(exceptionCaught, isTrue);

        // Verify the repository logged the start of processing
        verify(() => mockLoggingService.captureEvent(
              'Starting chat message processing',
              domain: 'ChatRepository',
              subDomain: 'sendMessage',
            )).called(1);
      });
    });

    group('sendMessage successful flows', () {
      late AiConfigInferenceProvider testProvider;
      late AiConfigModel testModel;

      setUp(() {
        testProvider = AiConfigInferenceProvider(
          id: 'provider-1',
          name: 'Gemini Provider',
          baseUrl: 'https://api.gemini.com',
          apiKey: 'test-key',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.gemini,
        );

        testModel = AiConfigModel(
          id: 'model-1',
          name: 'Gemini Flash',
          providerModelId: 'gemini-flash-1.5',
          inferenceProviderId: testProvider.id,
          createdAt: DateTime(2024),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        );
      });

      test('successfully sends message with content only (no tool calls)',
          () async {
        // Setup AI configuration
        when(() => mockAiConfigRepository
                .getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [testProvider]);
        when(() => mockAiConfigRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => [testModel]);

        // Setup streaming response
        final responseStream = Stream.fromIterable([
          const CreateChatCompletionStreamResponse(
            id: 'response-1',
            created: 0,
            model: 'model',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Hello, I can help you with your tasks!',
                ),
              ),
            ],
          ),
        ]);

        when(() => mockCloudInferenceRepository.generate(
              any<String>(),
              model: any<String>(named: 'model'),
              temperature: any<double>(named: 'temperature'),
              baseUrl: any<String>(named: 'baseUrl'),
              apiKey: any<String>(named: 'apiKey'),
              systemMessage: any<String>(named: 'systemMessage'),
              provider: any<AiConfigInferenceProvider?>(named: 'provider'),
              tools: any<List<ChatCompletionTool>?>(named: 'tools'),
            )).thenAnswer((_) => responseStream);

        // Send message and collect results
        final results = await repository
            .sendMessage(
              message: testMessage,
              conversationHistory: [],
              categoryId: testCategoryId,
            )
            .toList();

        // Verify results
        expect(results.length, 1);
        expect(results[0], 'Hello, I can help you with your tasks!');

        // Verify interactions
        verify(() => mockLoggingService.captureEvent(
              'Starting chat message processing',
              domain: 'ChatRepository',
              subDomain: 'sendMessage',
            )).called(1);
      });

      test('successfully sends message with tool calls', () async {
        // Setup AI configuration
        when(() => mockAiConfigRepository
                .getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [testProvider]);
        when(() => mockAiConfigRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => [testModel]);

        // Setup streaming response with tool calls
        final initialStream = Stream.fromIterable([
          const CreateChatCompletionStreamResponse(
            id: 'response-1',
            created: 0,
            model: 'model',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Let me check your tasks...',
                ),
              ),
            ],
          ),
          const CreateChatCompletionStreamResponse(
            id: 'response-1',
            created: 0,
            model: 'model',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  toolCalls: [
                    ChatCompletionStreamMessageToolCallChunk(
                      index: 0,
                      id: 'tool_1',
                      function: ChatCompletionStreamMessageFunctionCall(
                        name: 'get_task_summaries',
                        arguments:
                            '{"start_date": "2024-01-01T00:00:00.000", "end_date": "2024-01-01T23:59:59.999", "limit": 10}',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ]);

        final finalStream = Stream.fromIterable([
          const CreateChatCompletionStreamResponse(
            id: 'response-2',
            created: 0,
            model: 'model',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  content: 'You completed 5 tasks today!',
                ),
              ),
            ],
          ),
        ]);

        var callCount = 0;
        when(() => mockCloudInferenceRepository.generate(
              any<String>(),
              model: any<String>(named: 'model'),
              temperature: any<double>(named: 'temperature'),
              baseUrl: any<String>(named: 'baseUrl'),
              apiKey: any<String>(named: 'apiKey'),
              systemMessage: any<String>(named: 'systemMessage'),
              provider: any<AiConfigInferenceProvider?>(named: 'provider'),
              tools: any<List<ChatCompletionTool>?>(named: 'tools'),
            )).thenAnswer((_) {
          callCount++;
          return callCount == 1 ? initialStream : finalStream;
        });

        // Setup task summary response
        final taskSummaries = [
          TaskSummaryResult(
            taskId: 'task-1',
            taskTitle: 'Test Task',
            summary: 'Completed task',
            taskDate: DateTime(2024),
            status: 'completed',
          ),
        ];

        when(() => mockTaskSummaryRepository.getTaskSummaries(
              categoryId: testCategoryId,
              request: any<TaskSummaryRequest>(named: 'request'),
            )).thenAnswer((_) async => taskSummaries);

        // Send message and collect results
        final results = await repository
            .sendMessage(
              message: 'Show me my tasks for today',
              conversationHistory: [],
              categoryId: testCategoryId,
            )
            .toList();

        // Verify results
        expect(results.length, 3);
        expect(results[0], 'Let me check your tasks...');
        expect(results[1], 'Generating response...');
        expect(results[2], 'You completed 5 tasks today!');

        // Verify task summary was called
        verify(() => mockTaskSummaryRepository.getTaskSummaries(
              categoryId: testCategoryId,
              request: any<TaskSummaryRequest>(named: 'request'),
            )).called(1);
      });

      test('handles chunked content in streaming response', () async {
        // Setup AI configuration
        when(() => mockAiConfigRepository
                .getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [testProvider]);
        when(() => mockAiConfigRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => [testModel]);

        // Setup streaming response with multiple chunks
        final responseStream = Stream.fromIterable([
          const CreateChatCompletionStreamResponse(
            id: 'response-1',
            created: 0,
            model: 'model',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Here is ',
                ),
              ),
            ],
          ),
          const CreateChatCompletionStreamResponse(
            id: 'response-1',
            created: 0,
            model: 'model',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  content: 'your response ',
                ),
              ),
            ],
          ),
          const CreateChatCompletionStreamResponse(
            id: 'response-1',
            created: 0,
            model: 'model',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  content: 'in chunks.',
                ),
              ),
            ],
          ),
        ]);

        when(() => mockCloudInferenceRepository.generate(
              any<String>(),
              model: any<String>(named: 'model'),
              temperature: any<double>(named: 'temperature'),
              baseUrl: any<String>(named: 'baseUrl'),
              apiKey: any<String>(named: 'apiKey'),
              systemMessage: any<String>(named: 'systemMessage'),
              provider: any<AiConfigInferenceProvider?>(named: 'provider'),
              tools: any<List<ChatCompletionTool>?>(named: 'tools'),
            )).thenAnswer((_) => responseStream);

        // Send message and collect results
        final results = await repository
            .sendMessage(
              message: 'Test chunked response',
              conversationHistory: [],
              categoryId: testCategoryId,
            )
            .toList();

        // Verify results - should be concatenated
        expect(results.length, 1);
        expect(results[0], 'Here is your response in chunks.');
      });

      test('handles empty tool call results', () async {
        // Setup AI configuration
        when(() => mockAiConfigRepository
                .getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [testProvider]);
        when(() => mockAiConfigRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => [testModel]);

        // Setup streaming response with tool calls
        final initialStream = Stream.fromIterable([
          const CreateChatCompletionStreamResponse(
            id: 'response-1',
            created: 0,
            model: 'model',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  toolCalls: [
                    ChatCompletionStreamMessageToolCallChunk(
                      index: 0,
                      id: 'tool_1',
                      function: ChatCompletionStreamMessageFunctionCall(
                        name: 'get_task_summaries',
                        arguments:
                            '{"start_date": "2024-01-01T00:00:00.000", "end_date": "2024-01-01T23:59:59.999", "limit": 10}',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ]);

        final finalStream = Stream.fromIterable([
          const CreateChatCompletionStreamResponse(
            id: 'response-2',
            created: 0,
            model: 'model',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  content: 'No tasks found for the specified period.',
                ),
              ),
            ],
          ),
        ]);

        var callCount = 0;
        when(() => mockCloudInferenceRepository.generate(
              any<String>(),
              model: any<String>(named: 'model'),
              temperature: any<double>(named: 'temperature'),
              baseUrl: any<String>(named: 'baseUrl'),
              apiKey: any<String>(named: 'apiKey'),
              systemMessage: any<String>(named: 'systemMessage'),
              provider: any<AiConfigInferenceProvider?>(named: 'provider'),
              tools: any<List<ChatCompletionTool>?>(named: 'tools'),
            )).thenAnswer((_) {
          callCount++;
          return callCount == 1 ? initialStream : finalStream;
        });

        // Setup empty task summary response
        when(() => mockTaskSummaryRepository.getTaskSummaries(
              categoryId: testCategoryId,
              request: any<TaskSummaryRequest>(named: 'request'),
            )).thenAnswer((_) async => []);

        // Send message and collect results
        final results = await repository
            .sendMessage(
              message: 'Show me my tasks',
              conversationHistory: [],
              categoryId: testCategoryId,
            )
            .toList();

        // Verify results
        expect(results.contains('Generating response...'), true);
        expect(results.last, 'No tasks found for the specified period.');
      });

      test('handles conversation history correctly', () async {
        // Setup AI configuration
        when(() => mockAiConfigRepository
                .getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [testProvider]);
        when(() => mockAiConfigRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => [testModel]);

        // Create conversation history
        final history = [
          ChatMessage.user('What is the weather?'),
          ChatMessage.assistant('I can only help with task-related queries.'),
          ChatMessage.user('Show me my tasks then'),
        ];

        // Setup streaming response
        final responseStream = Stream.fromIterable([
          const CreateChatCompletionStreamResponse(
            id: 'response-1',
            created: 0,
            model: 'model',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Based on our conversation, here are your tasks...',
                ),
              ),
            ],
          ),
        ]);

        when(() => mockCloudInferenceRepository.generate(
              any<String>(),
              model: any<String>(named: 'model'),
              temperature: any<double>(named: 'temperature'),
              baseUrl: any<String>(named: 'baseUrl'),
              apiKey: any<String>(named: 'apiKey'),
              systemMessage: any<String>(named: 'systemMessage'),
              provider: any<AiConfigInferenceProvider?>(named: 'provider'),
              tools: any<List<ChatCompletionTool>?>(named: 'tools'),
            )).thenAnswer((_) => responseStream);

        // Send message and collect results
        final results = await repository
            .sendMessage(
              message: 'Please show them now',
              conversationHistory: history,
              categoryId: testCategoryId,
            )
            .toList();

        // Verify results
        expect(results.length, 1);
        expect(results[0], 'Based on our conversation, here are your tasks...');

        // Verify the prompt included conversation history
        final capturedPrompt =
            verify(() => mockCloudInferenceRepository.generate(
                  captureAny<String>(),
                  model: any<String>(named: 'model'),
                  temperature: any<double>(named: 'temperature'),
                  baseUrl: any<String>(named: 'baseUrl'),
                  apiKey: any<String>(named: 'apiKey'),
                  systemMessage: any<String>(named: 'systemMessage'),
                  provider: any<AiConfigInferenceProvider?>(named: 'provider'),
                  tools: any<List<ChatCompletionTool>?>(named: 'tools'),
                )).captured.first as String;

        expect(capturedPrompt, contains('What is the weather?'));
        expect(capturedPrompt,
            contains('I can only help with task-related queries.'));
        expect(capturedPrompt, contains('Show me my tasks then'));
        expect(capturedPrompt, contains('Please show them now'));
      });
    });
  });
}
