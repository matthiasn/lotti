import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai_chat/repository/chat_message_processor.dart';
import 'package:lotti/features/ai_chat/repository/task_summary_repository.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockCloudInferenceRepository extends Mock
    implements CloudInferenceRepository {}

class MockTaskSummaryRepository extends Mock implements TaskSummaryRepository {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  group('accumulateToolCalls', () {
    late ChatMessageProcessor processor;
    late MockLoggingService logging;

    setUp(() {
      processor = ChatMessageProcessor(
        aiConfigRepository: MockAiConfigRepository(),
        cloudInferenceRepository: MockCloudInferenceRepository(),
        taskSummaryRepository: MockTaskSummaryRepository(),
        loggingService: logging = MockLoggingService(),
      );
    });

    test('uses index-based id when id is missing', () {
      final toolCalls = <ChatCompletionMessageToolCall>[];
      final buffers = <String, StringBuffer>{};

      const delta = ChatCompletionStreamMessageToolCallChunk(
        index: 1,
        // id: null,
        function: ChatCompletionStreamMessageFunctionCall(
          name: 'get_task_summaries',
          arguments: '{"limit":10}',
        ),
      );

      processor.accumulateToolCalls(toolCalls, [delta], buffers);

      expect(toolCalls.length, 1);
      expect(toolCalls.first.id, 'tool_1');
      expect(toolCalls.first.function.name, 'get_task_summaries');
      expect(toolCalls.first.function.arguments, '{"limit":10}');
    });

    test('appends arguments across multiple deltas for same id', () {
      final toolCalls = <ChatCompletionMessageToolCall>[];
      final buffers = <String, StringBuffer>{};

      const d1 = ChatCompletionStreamMessageToolCallChunk(
        index: 0,
        id: 'x',
        function: ChatCompletionStreamMessageFunctionCall(
          name: 'get_task_summaries',
          arguments: '{"start":"2024-01-01',
        ),
      );
      const d2 = ChatCompletionStreamMessageToolCallChunk(
        index: 0,
        id: 'x',
        function: ChatCompletionStreamMessageFunctionCall(
          name: 'get_task_summaries',
          arguments: 'T00:00:00Z"}',
        ),
      );

      processor
        ..accumulateToolCalls(toolCalls, [d1], buffers)
        ..accumulateToolCalls(toolCalls, [d2], buffers);

      expect(toolCalls.length, 1);
      expect(toolCalls.first.id, 'x');
      expect(toolCalls.first.function.arguments,
          '{"start":"2024-01-01T00:00:00Z"}');
    });

    test('skips malformed delta with no id and no index and logs event', () {
      final toolCalls = <ChatCompletionMessageToolCall>[];
      final buffers = <String, StringBuffer>{};

      const malformed = ChatCompletionStreamMessageToolCallChunk(
        // id: null,
        // index: null,
        function: ChatCompletionStreamMessageFunctionCall(
          name: 'get_task_summaries',
          arguments: '{}',
        ),
      );

      processor.accumulateToolCalls(toolCalls, [malformed], buffers);
      expect(toolCalls, isEmpty);

      verify(() => logging.captureEvent(
            any<dynamic>(),
            domain: 'ChatMessageProcessor',
            subDomain: 'accumulateToolCalls',
          )).called(1);
    });
  });
}
