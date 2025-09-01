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
        TaskSummaryRequest(startDate: DateTime.now(), endDate: DateTime.now()));
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

    group('getAiConfiguration', () {
      test('returns valid configuration when provider and model exist',
          () async {
        // Arrange
        final provider = AiConfigInferenceProvider(
          id: 'provider-1',
          name: 'Gemini Provider',
          baseUrl: 'https://api.gemini.com',
          apiKey: 'test-key',
          createdAt: testDate,
          inferenceProviderType: InferenceProviderType.gemini,
        );

        final model = AiConfigModel(
          id: 'model-1',
          name: 'Gemini Flash',
          providerModelId: 'gemini-flash-1.5',
          inferenceProviderId: provider.id,
          createdAt: testDate,
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        );

        when(() => mockAiConfigRepository
                .getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [provider]);
        when(() => mockAiConfigRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => [model]);

        // Act
        final config = await processor.getAiConfiguration();

        // Assert
        expect(config.provider, provider);
        expect(config.model, model);
      });

      test('throws StateError when Gemini provider not found', () async {
        // Arrange
        when(() => mockAiConfigRepository.getConfigsByType(
            AiConfigType.inferenceProvider)).thenAnswer((_) async => []);

        // Act & Assert
        expect(
          processor.getAiConfiguration(),
          throwsA(predicate((e) =>
              e is StateError &&
              e.message == 'Gemini provider not configured')),
        );
      });
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
              'start_date': '2024-01-01T00:00:00.000',
              'end_date': '2024-01-01T23:59:59.999',
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
              'start_date': '2024-01-01T00:00:00.000',
              'end_date': '2024-01-01T23:59:59.999',
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
  });
}
