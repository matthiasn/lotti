import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_chat_message.dart';
import 'package:lotti/features/ai_chat/repository/chat_message_processor.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  group('accumulateToolCalls', () {
    late ChatMessageProcessor processor;
    late MockDomainLogger logging;

    setUp(() {
      processor = ChatMessageProcessor(
        aiConfigRepository: MockAiConfigRepository(),
        cloudInferenceRepository: MockCloudInferenceRepository(),
        taskSummaryRepository: MockTaskSummaryRepository(),
        loggingService: logging = MockDomainLogger(),
      );
    });

    test('uses index-based id when id is missing', () {
      final toolCalls = <AiToolCall>[];
      final buffers = <String, StringBuffer>{};

      const delta = AiToolCallChunk(
        index: 1,
        // id: null,
        name: 'get_task_summaries',
        arguments: '{"limit":10}',
      );

      processor.accumulateToolCalls(toolCalls, [delta], buffers);

      expect(toolCalls.length, 1);
      expect(toolCalls.first.id, 'tool_1');
      expect(toolCalls.first.name, 'get_task_summaries');
      expect(toolCalls.first.arguments, '{"limit":10}');
    });

    test('appends arguments across multiple deltas for same id', () {
      final toolCalls = <AiToolCall>[];
      final buffers = <String, StringBuffer>{};

      const d1 = AiToolCallChunk(
        index: 0,
        id: 'x',
        name: 'get_task_summaries',
        arguments: '{"start":"2024-01-01',
      );
      const d2 = AiToolCallChunk(
        index: 0,
        id: 'x',
        name: 'get_task_summaries',
        arguments: 'T00:00:00Z"}',
      );

      processor
        ..accumulateToolCalls(toolCalls, [d1], buffers)
        ..accumulateToolCalls(toolCalls, [d2], buffers);

      expect(toolCalls.length, 1);
      expect(toolCalls.first.id, 'x');
      expect(
        toolCalls.first.arguments,
        '{"start":"2024-01-01T00:00:00Z"}',
      );
    });

    test('skips malformed delta with no id and no index and logs event', () {
      final toolCalls = <AiToolCall>[];
      final buffers = <String, StringBuffer>{};

      const malformed = AiToolCallChunk(
        // id: null,
        // index: null,
        name: 'get_task_summaries',
        arguments: '{}',
      );

      processor.accumulateToolCalls(toolCalls, [malformed], buffers);
      expect(toolCalls, isEmpty);

      verify(
        () => logging.log(
          LogDomain.chat,
          any<String>(),
          subDomain: 'accumulateToolCalls',
        ),
      ).called(1);
    });

    test(
      'replaces arguments if both existing and incoming are complete JSON',
      () {
        final toolCalls = <AiToolCall>[];
        final buffers = <String, StringBuffer>{};

        // First delta provides a complete JSON object
        const d1 = AiToolCallChunk(
          index: 0,
          id: 'rep',
          name: 'get_task_summaries',
          arguments: '{"a":1}',
        );

        // Second delta resends full args (also complete JSON) — should replace
        const d2 = AiToolCallChunk(
          index: 0,
          id: 'rep',
          name: 'get_task_summaries',
          arguments: '{"a":2}',
        );

        processor
          ..accumulateToolCalls(toolCalls, [d1], buffers)
          ..accumulateToolCalls(toolCalls, [d2], buffers);

        expect(toolCalls.length, 1);
        expect(toolCalls.first.id, 'rep');
        expect(toolCalls.first.arguments, '{"a":2}');
      },
    );
  });
}
