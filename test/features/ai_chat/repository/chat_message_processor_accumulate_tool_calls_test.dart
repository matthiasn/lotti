import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai_chat/repository/chat_message_processor.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

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
      expect(
        toolCalls.first.function.arguments,
        '{"start":"2024-01-01T00:00:00Z"}',
      );
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
        final toolCalls = <ChatCompletionMessageToolCall>[];
        final buffers = <String, StringBuffer>{};

        // First delta provides a complete JSON object
        const d1 = ChatCompletionStreamMessageToolCallChunk(
          index: 0,
          id: 'rep',
          function: ChatCompletionStreamMessageFunctionCall(
            name: 'get_task_summaries',
            arguments: '{"a":1}',
          ),
        );

        // Second delta resends full args (also complete JSON) — should replace
        const d2 = ChatCompletionStreamMessageToolCallChunk(
          index: 0,
          id: 'rep',
          function: ChatCompletionStreamMessageFunctionCall(
            name: 'get_task_summaries',
            arguments: '{"a":2}',
          ),
        );

        processor
          ..accumulateToolCalls(toolCalls, [d1], buffers)
          ..accumulateToolCalls(toolCalls, [d2], buffers);

        expect(toolCalls.length, 1);
        expect(toolCalls.first.id, 'rep');
        expect(toolCalls.first.function.arguments, '{"a":2}');
      },
    );
  });

  group('accumulateToolCalls — Glados interleaving property', () {
    glados.Glados<List<int>>(
      glados.ListAnys(
        glados.any,
      ).listWithLengthInRange(
        1,
        16,
        glados.IntAnys(glados.any).intInRange(0, 1 << 10),
      ),
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'one entry per unique effective id; arguments equal the in-order '
      "concatenation of that id's chunks",
      (seeds) {
        final processor = ChatMessageProcessor(
          aiConfigRepository: MockAiConfigRepository(),
          cloudInferenceRepository: MockCloudInferenceRepository(),
          taskSummaryRepository: MockTaskSummaryRepository(),
          loggingService: MockDomainLogger(),
        );
        final toolCalls = <ChatCompletionMessageToolCall>[];
        final buffers = <String, StringBuffer>{};

        // Each seed becomes one delta: 3 possible tool indices interleaved
        // arbitrarily; fragments are never complete JSON, so the
        // replace-on-complete-JSON guard cannot kick in and pure
        // concatenation is the expected semantics.
        final expected = <String, StringBuffer>{};
        for (final (i, seed) in seeds.indexed) {
          final index = seed % 3;
          final id = 'tool_$index';
          final fragment = 'frag$i{';
          (expected[id] ??= StringBuffer()).write(fragment);

          processor.accumulateToolCalls(
            toolCalls,
            [
              ChatCompletionStreamMessageToolCallChunk(
                index: index,
                function: ChatCompletionStreamMessageFunctionCall(
                  name: 'fn_$index',
                  arguments: fragment,
                ),
              ),
            ],
            buffers,
          );
        }

        expect(
          toolCalls.map((tc) => tc.id).toSet(),
          expected.keys.toSet(),
          reason: 'one entry per unique effective id (seeds=$seeds)',
        );
        expect(toolCalls.length, expected.length);
        for (final call in toolCalls) {
          expect(
            call.function.arguments,
            expected[call.id]!.toString(),
            reason: 'accumulated args for ${call.id} (seeds=$seeds)',
          );
          expect(call.function.name, 'fn_${call.id.split('_').last}');
        }
      },
      tags: 'glados',
    );
  });
}
