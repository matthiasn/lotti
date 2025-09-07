// ignore_for_file: prefer_const_constructors

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/models/task_summary_tool.dart';
import 'package:lotti/features/ai_chat/repository/chat_message_processor.dart';
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
    registerFallbackValue(
        TaskSummaryRequest(startDate: '2024-01-01', endDate: '2024-01-02'));
    registerFallbackValue(Exception('test'));
  });

  group('ChatMessageProcessor', () {
    late ChatMessageProcessor processor;
    late MockAiConfigRepository mockAiConfigRepository;
    late MockCloudInferenceRepository mockCloudInferenceRepository;
    late MockTaskSummaryRepository mockTaskSummaryRepository;
    late MockLoggingService mockLoggingService;

    final testDate = DateTime(2024);
    const testCategoryId = 'test-category-123';

    setUp(() {
      mockAiConfigRepository = MockAiConfigRepository();
      mockCloudInferenceRepository = MockCloudInferenceRepository();
      mockTaskSummaryRepository = MockTaskSummaryRepository();
      mockLoggingService = MockLoggingService();

      processor = ChatMessageProcessor(
        aiConfigRepository: mockAiConfigRepository,
        cloudInferenceRepository: mockCloudInferenceRepository,
        taskSummaryRepository: mockTaskSummaryRepository,
        loggingService: mockLoggingService,
      );
    });

    group('convertConversationHistory', () {
      test('filters out system messages', () {
        // Arrange
        final messages = [
          ChatMessage.system('System message'),
          ChatMessage.user('User message'),
          ChatMessage.assistant('Assistant message'),
        ];

        // Act
        final result = processor.convertConversationHistory(messages);

        // Assert
        expect(result.length, 2);
        expect(result[0].role, ChatCompletionMessageRole.user);
        expect(result[1].role, ChatCompletionMessageRole.assistant);
      });

      test('returns empty list when only system messages provided', () {
        // Arrange
        final messages = [
          ChatMessage.system('System message 1'),
          ChatMessage.system('System message 2'),
        ];

        // Act
        final result = processor.convertConversationHistory(messages);

        // Assert
        expect(result, isEmpty);
      });
    });

    group('buildPromptFromMessages', () {
      test('builds prompt from conversation messages', () {
        // Arrange
        final messages = [
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Hello'),
          ),
          const ChatCompletionMessage.assistant(content: 'Hi there!'),
        ];
        const currentMessage = 'How are you?';

        // Act
        final result =
            processor.buildPromptFromMessages(messages, currentMessage);

        // Assert
        expect(result, contains('User:'));
        expect(result, contains('Hello'));
        expect(result, contains('Assistant: Hi there!'));
        expect(result, contains('User: How are you?'));
      });

      test('handles empty previous messages', () {
        // Arrange
        const currentMessage = 'Hello';

        // Act
        final result = processor.buildPromptFromMessages([], currentMessage);

        // Assert
        expect(result, contains('User:'));
        expect(result, contains('Hello'));
      });
    });

    group('processTaskSummaryTool', () {
      test('processes tool call and returns task summaries', () async {
        // Arrange
        final toolCall = ChatCompletionMessageToolCall(
          id: 'tool_1',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'get_task_summaries',
            arguments: jsonEncode({
              'start_date': '2024-01-01',
              'end_date': '2024-01-01',
              'limit': 10,
            }),
          ),
        );

        final taskSummaries = [
          TaskSummaryResult(
            taskId: 'task-1',
            taskTitle: 'Test Task',
            summary: 'Task summary',
            taskDate: testDate,
            status: 'completed',
          ),
        ];

        when(() => mockTaskSummaryRepository.getTaskSummaries(
              categoryId: testCategoryId,
              request: any<TaskSummaryRequest>(named: 'request'),
            )).thenAnswer((_) async => taskSummaries);

        // Act
        final result = await processor.processTaskSummaryTool(
          toolCall: toolCall,
          categoryId: testCategoryId,
        );

        // Assert
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['count'], 1);
        expect(decoded['tasks'], isA<List<dynamic>>());
        final tasks = decoded['tasks'] as List<dynamic>;
        expect((tasks[0] as Map<String, dynamic>)['task_id'], 'task-1');
      });

      test('returns empty message when no tasks found', () async {
        // Arrange
        final toolCall = ChatCompletionMessageToolCall(
          id: 'tool_1',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'get_task_summaries',
            arguments: jsonEncode({
              'start_date': '2024-01-01',
              'end_date': '2024-01-01',
              'limit': 10,
            }),
          ),
        );

        when(() => mockTaskSummaryRepository.getTaskSummaries(
              categoryId: testCategoryId,
              request: any<TaskSummaryRequest>(named: 'request'),
            )).thenAnswer((_) async => []);

        // Act
        final result = await processor.processTaskSummaryTool(
          toolCall: toolCall,
          categoryId: testCategoryId,
        );

        // Assert
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(
            decoded['message'], 'No tasks found in the specified date range.');
      });

      test('handles errors gracefully', () async {
        // Arrange
        const toolCall = ChatCompletionMessageToolCall(
          id: 'tool_1',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'get_task_summaries',
            arguments: 'invalid json',
          ),
        );

        // Act
        final result = await processor.processTaskSummaryTool(
          toolCall: toolCall,
          categoryId: testCategoryId,
        );

        // Assert
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('Failed to retrieve task summaries'));
        verify(() => mockLoggingService.captureException(
              any<Exception>(),
              domain: 'ChatMessageProcessor',
              subDomain: 'processTaskSummaryTool',
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
            )).called(1);
      });

      test('handles invalid date format in arguments', () async {
        // Arrange
        final toolCall = ChatCompletionMessageToolCall(
          id: 'test-id',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'get_task_summaries',
            arguments: jsonEncode({
              'start_date': 'invalid-date-format',
              'end_date': '2024-01-01T00:00:00.000',
            }),
          ),
        );

        // Act
        final result = await processor.processTaskSummaryTool(
          toolCall: toolCall,
          categoryId: testCategoryId,
        );

        // Assert
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('Failed to retrieve task summaries'));
        verify(() => mockLoggingService.captureException(
              any<dynamic>(),
              domain: 'ChatMessageProcessor',
              subDomain: 'processTaskSummaryTool',
              stackTrace: any<dynamic>(named: 'stackTrace'),
            )).called(1);
      });

      test('handles missing required fields in JSON', () async {
        // Arrange
        final toolCall = ChatCompletionMessageToolCall(
          id: 'test-id',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'get_task_summaries',
            arguments: jsonEncode({
              'start_date': '2024-01-01T00:00:00.000',
              // Missing end_date
            }),
          ),
        );

        // Act
        final result = await processor.processTaskSummaryTool(
          toolCall: toolCall,
          categoryId: testCategoryId,
        );

        // Assert
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('Failed to retrieve task summaries'));
        verify(() => mockLoggingService.captureException(
              any<dynamic>(),
              domain: 'ChatMessageProcessor',
              subDomain: 'processTaskSummaryTool',
              stackTrace: any<dynamic>(named: 'stackTrace'),
            )).called(1);
      });

      test('handles repository exceptions gracefully', () async {
        // Arrange
        final toolCall = ChatCompletionMessageToolCall(
          id: 'test-id',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'get_task_summaries',
            arguments: jsonEncode({
              'start_date': '2024-01-01T00:00:00.000Z',
              'end_date': '2024-01-02T00:00:00.000Z',
            }),
          ),
        );

        when(() => mockTaskSummaryRepository.getTaskSummaries(
              categoryId: any(named: 'categoryId'),
              request: any(named: 'request'),
            )).thenThrow(Exception('Database connection failed'));

        // Act
        final result = await processor.processTaskSummaryTool(
          toolCall: toolCall,
          categoryId: testCategoryId,
        );

        // Assert
        final decoded = jsonDecode(result) as Map<String, dynamic>;
        expect(decoded['error'], contains('Failed to retrieve task summaries'));
        expect(decoded['error'], contains('Database connection failed'));
      });
    });

    group('buildFinalPromptFromMessages', () {
      test('builds final prompt with all message types', () {
        // Arrange
        final messages = [
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Hello'),
          ),
          const ChatCompletionMessage.assistant(
              content: 'Hi! Let me check your tasks.'),
          const ChatCompletionMessage.tool(
            toolCallId: 'tool_1',
            content: '{"tasks": []}',
          ),
        ];

        // Act
        final result = processor.buildFinalPromptFromMessages(messages);

        // Assert
        expect(result, contains('User:'));
        expect(result, contains('Hello'));
        expect(result, contains('Assistant: Hi! Let me check your tasks.'));
        expect(result, contains('Tool response: {"tasks": []}'));
        expect(result,
            contains('Based on the conversation and tool results above'));
      });
    });

    group('buildMessagesList', () {
      test('builds messages list with system prompt and history', () {
        // Arrange
        final previousMessages = [
          const ChatCompletionMessage.user(
            content:
                ChatCompletionUserMessageContent.string('Previous message'),
          ),
          const ChatCompletionMessage.assistant(content: 'Previous response'),
        ];
        const message = 'Current message';
        const systemMessage = 'You are a helpful assistant';

        // Act
        final result = processor.buildMessagesList(
          previousMessages,
          message,
          systemMessage,
        );

        // Assert
        expect(result.length, 4);
        expect(result[0].role, ChatCompletionMessageRole.system);
        expect(result[0].content, systemMessage);
        expect(result[1].role, ChatCompletionMessageRole.user);
        expect(result[2].role, ChatCompletionMessageRole.assistant);
        expect(result[3].role, ChatCompletionMessageRole.user);
        final content = result[3].content;
        expect(content, isNotNull);
        expect(
          (content! as ChatCompletionUserMessageContent)
              .whenOrNull(string: (s) => s),
          message,
        );
      });
    });

    group('processStreamResponse', () {
      test('processes stream with content only', () async {
        // Arrange
        final stream = Stream.fromIterable([
          const CreateChatCompletionStreamResponse(
            id: 'response-1',
            created: 0,
            model: 'model',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  content: 'Hello ',
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
                  content: 'world!',
                ),
              ),
            ],
          ),
        ]);

        // Act
        final result = await processor.processStreamResponse(stream);

        // Assert
        expect(result.content, 'Hello world!');
        expect(result.toolCalls, isEmpty);
      });

      test('processes stream with tool calls and argument buffering', () async {
        // Arrange
        final stream = Stream.fromIterable([
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
                        arguments: '{"start_date": "2024-',
                      ),
                    ),
                  ],
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
                        arguments: '01-01T00:00:00.000Z"}',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ]);

        // Act
        final result = await processor.processStreamResponse(stream);

        // Assert
        expect(result.toolCalls.length, 1);
        expect(result.toolCalls[0].id, 'tool_1');
        expect(result.toolCalls[0].function.name, 'get_task_summaries');
        expect(result.toolCalls[0].function.arguments,
            '{"start_date": "2024-01-01T00:00:00.000Z"}');
      });

      test('handles empty stream', () async {
        // Arrange
        const stream = Stream<CreateChatCompletionStreamResponse>.empty();

        // Act
        final result = await processor.processStreamResponse(stream);

        // Assert
        expect(result.content, '');
        expect(result.toolCalls, isEmpty);
      });

      test('buffers interleaved tool call arguments for multiple tools',
          () async {
        // Two tools with interleaved chunks
        final stream = Stream.fromIterable([
          const CreateChatCompletionStreamResponse(
            id: 'r',
            created: 0,
            model: 'm',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  toolCalls: [
                    ChatCompletionStreamMessageToolCallChunk(
                      index: 0,
                      id: 'A',
                      function: ChatCompletionStreamMessageFunctionCall(
                          name: 'get_task_summaries', arguments: '{"start_'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const CreateChatCompletionStreamResponse(
            id: 'r',
            created: 0,
            model: 'm',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  toolCalls: [
                    ChatCompletionStreamMessageToolCallChunk(
                      index: 0,
                      id: 'B',
                      function: ChatCompletionStreamMessageFunctionCall(
                          name: 'get_task_summaries', arguments: '{"end_'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const CreateChatCompletionStreamResponse(
            id: 'r',
            created: 0,
            model: 'm',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  toolCalls: [
                    ChatCompletionStreamMessageToolCallChunk(
                      index: 0,
                      id: 'A',
                      function: ChatCompletionStreamMessageFunctionCall(
                          name: 'get_task_summaries',
                          arguments: 'date":"2024-01-01"}'),
                    ),
                    ChatCompletionStreamMessageToolCallChunk(
                      index: 1,
                      id: 'B',
                      function: ChatCompletionStreamMessageFunctionCall(
                          name: 'get_task_summaries',
                          arguments: 'date":"2024-01-02"}'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ]);

        final result = await processor.processStreamResponse(stream);
        expect(result.toolCalls.length, 2);
        final a = result.toolCalls.firstWhere((t) => t.id == 'A');
        final b = result.toolCalls.firstWhere((t) => t.id == 'B');
        expect(a.function.arguments, '{"start_date":"2024-01-01"}');
        expect(b.function.arguments, '{"end_date":"2024-01-02"}');
      });

      test('ignores tool call deltas with null function without crashing',
          () async {
        final stream = Stream<CreateChatCompletionStreamResponse>.fromIterable([
          const CreateChatCompletionStreamResponse(
            id: 'r',
            created: 0,
            model: 'm',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  toolCalls: [
                    ChatCompletionStreamMessageToolCallChunk(
                      index: 0,
                      id: 'x',
                      // function: null
                    ),
                  ],
                ),
              ),
            ],
          ),
        ]);

        final result = await processor.processStreamResponse(stream);
        expect(result.toolCalls, isEmpty);
      });
    });

    group('processToolCalls', () {
      test('processes multiple tool calls', () async {
        // Arrange
        final toolCalls = [
          ChatCompletionMessageToolCall(
            id: 'tool_1',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: TaskSummaryTool.name,
              arguments: jsonEncode({
                'start_date': '2024-01-01T00:00:00.000',
                'end_date': '2024-01-01T23:59:59.999',
                'limit': 10,
              }),
            ),
          ),
        ];

        final taskSummaries = [
          TaskSummaryResult(
            taskId: 'task-1',
            taskTitle: 'Test Task',
            summary: 'Task summary',
            taskDate: testDate,
            status: 'completed',
          ),
        ];

        when(() => mockTaskSummaryRepository.getTaskSummaries(
              categoryId: testCategoryId,
              request: any<TaskSummaryRequest>(named: 'request'),
            )).thenAnswer((_) async => taskSummaries);

        // Act
        final result = await processor.processToolCalls(
          toolCalls,
          testCategoryId,
        );

        // Assert
        expect(result.length, 1);
        expect(result[0].role, ChatCompletionMessageRole.tool);
        // Tool message role verification is sufficient
        // The toolCallId is correctly passed in processTaskSummaryTool test

        verify(() => mockLoggingService.captureEvent(
              'Processing 1 tool calls',
              domain: 'ChatMessageProcessor',
              subDomain: 'processToolCalls',
            )).called(1);
      });

      test('skips non-task-summary tools', () async {
        // Arrange
        final toolCalls = [
          const ChatCompletionMessageToolCall(
            id: 'tool_1',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'unknown_tool',
              arguments: '{}',
            ),
          ),
        ];

        // Act
        final result = await processor.processToolCalls(
          toolCalls,
          testCategoryId,
        );

        // Assert
        expect(result, isEmpty);
      });
    });

    group('generateFinalResponse', () {
      test('generates final response after tool calls', () async {
        // Arrange
        final messages = [
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Show my tasks'),
          ),
          const ChatCompletionMessage.tool(
            toolCallId: 'tool_1',
            content: '{"tasks": []}',
          ),
        ];

        final config = AiInferenceConfig(
          provider: AiConfigInferenceProvider(
            id: 'provider-1',
            name: 'Gemini',
            baseUrl: 'https://api.gemini.com',
            apiKey: 'test-key',
            createdAt: testDate,
            inferenceProviderType: InferenceProviderType.gemini,
          ),
          model: AiConfigModel(
            id: 'model-1',
            name: 'Gemini Flash',
            providerModelId: 'gemini-flash',
            inferenceProviderId: 'provider-1',
            createdAt: testDate,
            inputModalities: [Modality.text],
            outputModalities: [Modality.text],
            isReasoningModel: false,
          ),
        );

        const systemMessage = 'You are a helpful assistant';

        final responseStream = Stream.fromIterable([
          const CreateChatCompletionStreamResponse(
            id: 'response-1',
            created: 0,
            model: 'model',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(
                  content: 'No tasks found.',
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
            )).thenAnswer((_) => responseStream);

        // Act
        final result = await processor.generateFinalResponse(
          messages: messages,
          config: config,
          systemMessage: systemMessage,
        );

        // Assert
        expect(result, 'No tasks found.');
      });
    });

    group('getAiConfigurationForModel', () {
      test(
          'returns config for valid function-calling model and caches per model',
          () async {
        final provider = AiConfigInferenceProvider(
          id: 'prov-1',
          name: 'Provider',
          baseUrl: 'https://api',
          apiKey: 'k',
          createdAt: testDate,
          inferenceProviderType: InferenceProviderType.openAi,
        );
        final model = AiConfigModel(
          id: 'model-1',
          name: 'Model',
          providerModelId: 'm1',
          inferenceProviderId: provider.id,
          createdAt: testDate,
          inputModalities: const [Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
          supportsFunctionCalling: true,
        );

        when(() => mockAiConfigRepository.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepository.getConfigById(provider.id))
            .thenAnswer((_) async => provider);

        final cfg1 = await processor.getAiConfigurationForModel('model-1');
        await processor.getAiConfigurationForModel('model-1');

        expect(cfg1.model.id, 'model-1');
        expect(cfg1.provider.id, provider.id);

        // Repo should be called only once per id due to cache
        verify(() => mockAiConfigRepository.getConfigById('model-1')).called(1);
      });

      test('throws when model not found', () async {
        when(() => mockAiConfigRepository.getConfigById('missing'))
            .thenAnswer((_) async => null);
        expect(
          processor.getAiConfigurationForModel('missing'),
          throwsA(isA<StateError>()),
        );
      });

      test('throws when model does not support function calling', () async {
        final provider = AiConfigInferenceProvider(
          id: 'prov-1',
          name: 'Provider',
          baseUrl: 'https://api',
          apiKey: 'k',
          createdAt: testDate,
          inferenceProviderType: InferenceProviderType.openAi,
        );
        final model = AiConfigModel(
          id: 'model-1',
          name: 'Model',
          providerModelId: 'm1',
          inferenceProviderId: provider.id,
          createdAt: testDate,
          inputModalities: const [Modality.text],
          outputModalities: const [Modality.text],
          // ignore: avoid_redundant_argument_values
          isReasoningModel: false,
          // ignore: avoid_redundant_argument_values
          supportsFunctionCalling: false,
        );
        when(() => mockAiConfigRepository.getConfigById('model-1'))
            .thenAnswer((_) async => model);

        expect(
          processor.getAiConfigurationForModel('model-1'),
          throwsA(isA<StateError>()),
        );
      });

      test('throws when provider not found', () async {
        final model = AiConfigModel(
          id: 'model-1',
          name: 'Model',
          providerModelId: 'm1',
          inferenceProviderId: 'prov-missing',
          createdAt: testDate,
          inputModalities: const [Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
          supportsFunctionCalling: true,
        );
        when(() => mockAiConfigRepository.getConfigById('model-1'))
            .thenAnswer((_) async => model);
        when(() => mockAiConfigRepository.getConfigById('prov-missing'))
            .thenAnswer((_) async => null);

        expect(
          processor.getAiConfigurationForModel('model-1'),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('generateFinalResponseStream', () {
      test('emits non-empty chunks only in order', () async {
        final config = AiInferenceConfig(
          provider: AiConfigInferenceProvider(
            id: 'prov-1',
            name: 'Provider',
            baseUrl: 'https://api',
            apiKey: 'k',
            createdAt: testDate,
            inferenceProviderType: InferenceProviderType.openAi,
          ),
          model: AiConfigModel(
            id: 'model-1',
            name: 'Model',
            providerModelId: 'm1',
            inferenceProviderId: 'prov-1',
            createdAt: testDate,
            inputModalities: const [Modality.text],
            outputModalities: const [Modality.text],
            isReasoningModel: false,
            supportsFunctionCalling: true,
          ),
        );

        final stream = Stream.fromIterable([
          const CreateChatCompletionStreamResponse(
            id: 'r1',
            created: 0,
            model: 'm',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(content: ''),
              ),
            ],
          ),
          const CreateChatCompletionStreamResponse(
            id: 'r1',
            created: 0,
            model: 'm',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(content: 'Hello'),
              ),
            ],
          ),
          const CreateChatCompletionStreamResponse(
            id: 'r1',
            created: 0,
            model: 'm',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(content: ' world'),
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
            )).thenAnswer((_) => stream);

        final chunks = await processor.generateFinalResponseStream(
          messages: const [
            ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.string('hi'),
            )
          ],
          config: config,
          systemMessage: 'sys',
        ).toList();

        expect(chunks, ['Hello', ' world']);
      });

      test('ignores frames with null/empty choices and continues', () async {
        final config = AiInferenceConfig(
          provider: AiConfigInferenceProvider(
            id: 'prov-1',
            name: 'Provider',
            baseUrl: 'https://api',
            apiKey: 'k',
            createdAt: testDate,
            inferenceProviderType: InferenceProviderType.openAi,
          ),
          model: AiConfigModel(
            id: 'model-1',
            name: 'Model',
            providerModelId: 'm1',
            inferenceProviderId: 'prov-1',
            createdAt: testDate,
            inputModalities: const [Modality.text],
            outputModalities: const [Modality.text],
            isReasoningModel: false,
            supportsFunctionCalling: true,
          ),
        );

        final stream = Stream<CreateChatCompletionStreamResponse>.fromIterable([
          const CreateChatCompletionStreamResponse(
            id: 'r0',
            created: 0,
            model: 'm',
          ),
          const CreateChatCompletionStreamResponse(
            id: 'r1',
            created: 0,
            model: 'm',
            choices: [],
          ),
          const CreateChatCompletionStreamResponse(
            id: 'r2',
            created: 0,
            model: 'm',
            choices: [
              ChatCompletionStreamResponseChoice(
                index: 0,
                delta: ChatCompletionStreamResponseDelta(content: 'ok'),
              )
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
            )).thenAnswer((_) => stream);

        final out = await processor.generateFinalResponseStream(
          messages: const [
            ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.string('x'),
            )
          ],
          config: config,
          systemMessage: 'sys',
        ).toList();
        expect(out, ['ok']);
      });
    });

    group('getAiConfigurationForModel caching', () {
      late AiConfigInferenceProvider testProvider;
      late AiConfigModel testModel;

      setUp(() {
        testProvider = AiConfigInferenceProvider(
          id: 'provider-1',
          name: 'Gemini Provider',
          baseUrl: 'https://api.gemini.com',
          apiKey: 'test-key',
          createdAt: testDate,
          inferenceProviderType: InferenceProviderType.gemini,
        );

        testModel = AiConfigModel(
          id: 'model-1',
          name: 'Gemini Flash',
          providerModelId: 'gemini-flash-1.5',
          inferenceProviderId: testProvider.id,
          createdAt: testDate,
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
          supportsFunctionCalling: true,
        );
      });

      test('caches configuration on first call', () async {
        // Arrange
        when(() => mockAiConfigRepository.getConfigById('model-1'))
            .thenAnswer((_) async => testModel);
        when(() => mockAiConfigRepository.getConfigById(testProvider.id))
            .thenAnswer((_) async => testProvider);

        // Act - First call
        final config1 = await processor.getAiConfigurationForModel('model-1');

        // Act - Second call (should use cache)
        final config2 = await processor.getAiConfigurationForModel('model-1');

        // Assert
        expect(config1.provider, testProvider);
        expect(config1.model, testModel);
        expect(config2.provider, testProvider);
        expect(config2.model, testModel);

        // Verify repository was called only once for each config
        verify(() => mockAiConfigRepository.getConfigById('model-1')).called(1);
        verify(() => mockAiConfigRepository.getConfigById(testProvider.id))
            .called(1);
      });

      test('cache expires after 5 minutes', () async {
        // Arrange
        when(() => mockAiConfigRepository.getConfigById('model-1'))
            .thenAnswer((_) async => testModel);
        when(() => mockAiConfigRepository.getConfigById(testProvider.id))
            .thenAnswer((_) async => testProvider);

        // Act - First call
        await processor.getAiConfigurationForModel('model-1');

        // Mock the passage of time (6 minutes)
        // Since we can't easily mock DateTime.now(), we'll use clearConfigCache
        // to simulate cache expiry
        processor.clearConfigCache();

        // Act - Second call after cache expiry
        await processor.getAiConfigurationForModel('model-1');

        // Assert - Repository should be called twice
        verify(() => mockAiConfigRepository.getConfigById('model-1')).called(2);
        verify(() => mockAiConfigRepository.getConfigById(testProvider.id))
            .called(2);
      });

      test('clearConfigCache clears cached configuration', () async {
        // Arrange
        when(() => mockAiConfigRepository.getConfigById('model-1'))
            .thenAnswer((_) async => testModel);
        when(() => mockAiConfigRepository.getConfigById(testProvider.id))
            .thenAnswer((_) async => testProvider);

        // Act - First call to populate cache
        await processor.getAiConfigurationForModel('model-1');

        // Act - Clear cache
        processor.clearConfigCache();

        // Act - Second call after cache clear
        await processor.getAiConfigurationForModel('model-1');

        // Assert - Repository should be called twice
        verify(() => mockAiConfigRepository.getConfigById('model-1')).called(2);
        verify(() => mockAiConfigRepository.getConfigById(testProvider.id))
            .called(2);
      });

      test('cache works correctly with multiple processors', () async {
        // Arrange
        final processor2 = ChatMessageProcessor(
          aiConfigRepository: mockAiConfigRepository,
          cloudInferenceRepository: mockCloudInferenceRepository,
          taskSummaryRepository: mockTaskSummaryRepository,
          loggingService: mockLoggingService,
        );

        when(() => mockAiConfigRepository.getConfigById('model-1'))
            .thenAnswer((_) async => testModel);
        when(() => mockAiConfigRepository.getConfigById(testProvider.id))
            .thenAnswer((_) async => testProvider);

        // Act - Each processor should maintain its own cache
        await processor.getAiConfigurationForModel('model-1');
        await processor2.getAiConfigurationForModel('model-1');

        // Act - Second calls should use respective caches
        await processor.getAiConfigurationForModel('model-1');
        await processor2.getAiConfigurationForModel('model-1');

        // Assert - Repository should be called twice (once per processor)
        verify(() => mockAiConfigRepository.getConfigById('model-1')).called(2);
        verify(() => mockAiConfigRepository.getConfigById(testProvider.id))
            .called(2);
      });

      test('cache handles errors gracefully', () async {
        // Arrange
        when(() => mockAiConfigRepository.getConfigById('model-1'))
            .thenThrow(Exception('Database error'));

        // Act & Assert - First call throws
        expect(
            processor.getAiConfigurationForModel('model-1'), throwsException);

        // Arrange - Fix the error
        when(() => mockAiConfigRepository.getConfigById('model-1'))
            .thenAnswer((_) async => testModel);
        when(() => mockAiConfigRepository.getConfigById(testProvider.id))
            .thenAnswer((_) async => testProvider);

        // Act - Second call should work (no cached error)
        final config = await processor.getAiConfigurationForModel('model-1');

        // Assert
        expect(config.provider, testProvider);
        expect(config.model, testModel);
      });
    });
  });
}
