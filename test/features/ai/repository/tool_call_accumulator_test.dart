import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/repository/tool_call_accumulator.dart';
import 'package:openai_dart/openai_dart.dart';

void main() {
  group('ToolCallAccumulator', () {
    late ToolCallAccumulator accumulator;

    setUp(() {
      accumulator = ToolCallAccumulator();
    });

    group('processChunk', () {
      test('handles null delta', () {
        accumulator.processChunk(null);
        expect(accumulator.hasToolCalls, isFalse);
        expect(accumulator.count, 0);
      });

      test('handles delta without tool calls', () {
        const delta = ChatCompletionStreamResponseDelta(
          content: 'Hello',
        );
        accumulator.processChunk(delta);
        expect(accumulator.hasToolCalls, isFalse);
      });

      test('accumulates single complete tool call', () {
        const delta = ChatCompletionStreamResponseDelta(
          toolCalls: [
            ChatCompletionStreamMessageToolCallChunk(
              index: 0,
              id: 'call_123',
              type: ChatCompletionStreamMessageToolCallChunkType.function,
              function: ChatCompletionStreamMessageFunctionCall(
                name: 'test_function',
                arguments: '{"key": "value"}',
              ),
            ),
          ],
        );

        accumulator.processChunk(delta);
        expect(accumulator.hasToolCalls, isTrue);
        expect(accumulator.count, 1);

        final toolCalls = accumulator.toToolCalls();
        expect(toolCalls.length, 1);
        expect(toolCalls.first.function.name, 'test_function');
        expect(toolCalls.first.function.arguments, '{"key": "value"}');
      });

      test('accumulates multiple complete tool calls in single chunk', () {
        const delta = ChatCompletionStreamResponseDelta(
          toolCalls: [
            ChatCompletionStreamMessageToolCallChunk(
              index: 0,
              function: ChatCompletionStreamMessageFunctionCall(
                name: 'function_one',
                arguments: '{"a": 1}',
              ),
            ),
            ChatCompletionStreamMessageToolCallChunk(
              index: 0,
              function: ChatCompletionStreamMessageFunctionCall(
                name: 'function_two',
                arguments: '{"b": 2}',
              ),
            ),
          ],
        );

        accumulator.processChunk(delta);
        expect(accumulator.count, 2);

        final toolCalls = accumulator.toToolCalls();
        expect(toolCalls.length, 2);
        expect(toolCalls[0].function.name, 'function_one');
        expect(toolCalls[1].function.name, 'function_two');
      });

      test('accumulates streamed tool call chunks by ID', () {
        // First chunk - starts the tool call
        const chunk1 = ChatCompletionStreamResponseDelta(
          toolCalls: [
            ChatCompletionStreamMessageToolCallChunk(
              index: 0,
              id: 'call_abc',
              type: ChatCompletionStreamMessageToolCallChunkType.function,
              function: ChatCompletionStreamMessageFunctionCall(
                name: 'my_function',
                arguments: '{"par',
              ),
            ),
          ],
        );

        // Second chunk - continues arguments (no ID, uses index)
        const chunk2 = ChatCompletionStreamResponseDelta(
          toolCalls: [
            ChatCompletionStreamMessageToolCallChunk(
              index: 0,
              function: ChatCompletionStreamMessageFunctionCall(
                arguments: 'am": "val',
              ),
            ),
          ],
        );

        // Third chunk - finishes arguments
        const chunk3 = ChatCompletionStreamResponseDelta(
          toolCalls: [
            ChatCompletionStreamMessageToolCallChunk(
              index: 0,
              function: ChatCompletionStreamMessageFunctionCall(
                arguments: 'ue"}',
              ),
            ),
          ],
        );

        accumulator
          ..processChunk(chunk1)
          ..processChunk(chunk2)
          ..processChunk(chunk3);

        expect(accumulator.count, 1);

        final toolCalls = accumulator.toToolCalls();
        expect(toolCalls.length, 1);
        expect(toolCalls.first.function.name, 'my_function');
        expect(toolCalls.first.function.arguments, '{"param": "value"}');
      });

      test('accumulates multiple parallel tool calls', () {
        // First tool call starts
        const chunk1 = ChatCompletionStreamResponseDelta(
          toolCalls: [
            ChatCompletionStreamMessageToolCallChunk(
              index: 0,
              id: 'call_1',
              function: ChatCompletionStreamMessageFunctionCall(
                name: 'func_a',
                arguments: '{"x": ',
              ),
            ),
          ],
        );

        // Second tool call starts
        const chunk2 = ChatCompletionStreamResponseDelta(
          toolCalls: [
            ChatCompletionStreamMessageToolCallChunk(
              index: 1,
              id: 'call_2',
              function: ChatCompletionStreamMessageFunctionCall(
                name: 'func_b',
                arguments: '{"y": ',
              ),
            ),
          ],
        );

        // First tool call continues
        const chunk3 = ChatCompletionStreamResponseDelta(
          toolCalls: [
            ChatCompletionStreamMessageToolCallChunk(
              index: 0,
              function: ChatCompletionStreamMessageFunctionCall(
                arguments: '1}',
              ),
            ),
          ],
        );

        // Second tool call continues
        const chunk4 = ChatCompletionStreamResponseDelta(
          toolCalls: [
            ChatCompletionStreamMessageToolCallChunk(
              index: 1,
              function: ChatCompletionStreamMessageFunctionCall(
                arguments: '2}',
              ),
            ),
          ],
        );

        accumulator
          ..processChunk(chunk1)
          ..processChunk(chunk2)
          ..processChunk(chunk3)
          ..processChunk(chunk4);

        expect(accumulator.count, 2);

        final toolCalls = accumulator.toToolCalls();
        expect(toolCalls.length, 2);

        final funcA =
            toolCalls.firstWhere((tc) => tc.function.name == 'func_a');
        final funcB =
            toolCalls.firstWhere((tc) => tc.function.name == 'func_b');

        expect(funcA.function.arguments, '{"x": 1}');
        expect(funcB.function.arguments, '{"y": 2}');
      });
    });

    group('toToolCalls', () {
      test('returns empty list when no tool calls accumulated', () {
        final toolCalls = accumulator.toToolCalls();
        expect(toolCalls, isEmpty);
      });

      test('skips tool calls with empty arguments', () {
        const delta = ChatCompletionStreamResponseDelta(
          toolCalls: [
            ChatCompletionStreamMessageToolCallChunk(
              index: 0,
              id: 'call_empty',
              function: ChatCompletionStreamMessageFunctionCall(
                name: 'empty_func',
                arguments: '',
              ),
            ),
            ChatCompletionStreamMessageToolCallChunk(
              index: 1,
              id: 'call_valid',
              function: ChatCompletionStreamMessageFunctionCall(
                name: 'valid_func',
                arguments: '{"valid": true}',
              ),
            ),
          ],
        );

        accumulator.processChunk(delta);
        expect(accumulator.count, 2); // Both are accumulated

        final toolCalls = accumulator.toToolCalls();
        expect(toolCalls.length, 1); // But only valid one is returned
        expect(toolCalls.first.function.name, 'valid_func');
      });

      test('generates unique IDs for tool calls without IDs', () {
        const delta = ChatCompletionStreamResponseDelta(
          toolCalls: [
            ChatCompletionStreamMessageToolCallChunk(
              index: 0,
              function: ChatCompletionStreamMessageFunctionCall(
                name: 'func_1',
                arguments: '{"a": 1}',
              ),
            ),
            ChatCompletionStreamMessageToolCallChunk(
              index: 0,
              function: ChatCompletionStreamMessageFunctionCall(
                name: 'func_2',
                arguments: '{"b": 2}',
              ),
            ),
          ],
        );

        accumulator.processChunk(delta);
        final toolCalls = accumulator.toToolCalls();

        expect(toolCalls.length, 2);
        expect(toolCalls[0].id, isNot(equals(toolCalls[1].id)));
        expect(toolCalls[0].id, startsWith('tool_'));
        expect(toolCalls[1].id, startsWith('tool_'));
      });

      test('sets function type on all tool calls', () {
        const delta = ChatCompletionStreamResponseDelta(
          toolCalls: [
            ChatCompletionStreamMessageToolCallChunk(
              index: 0,
              id: 'call_1',
              function: ChatCompletionStreamMessageFunctionCall(
                name: 'test_func',
                arguments: '{}',
              ),
            ),
          ],
        );

        accumulator.processChunk(delta);
        final toolCalls = accumulator.toToolCalls();

        expect(
            toolCalls.first.type, ChatCompletionMessageToolCallType.function);
      });
    });

    group('hasToolCalls', () {
      test('returns false initially', () {
        expect(accumulator.hasToolCalls, isFalse);
      });

      test('returns true after processing tool calls', () {
        const delta = ChatCompletionStreamResponseDelta(
          toolCalls: [
            ChatCompletionStreamMessageToolCallChunk(
              index: 0,
              id: 'call_1',
              function: ChatCompletionStreamMessageFunctionCall(
                name: 'func',
                arguments: '{}',
              ),
            ),
          ],
        );

        accumulator.processChunk(delta);
        expect(accumulator.hasToolCalls, isTrue);
      });
    });

    group('count', () {
      test('returns 0 initially', () {
        expect(accumulator.count, 0);
      });

      test('returns correct count after processing', () {
        const delta = ChatCompletionStreamResponseDelta(
          toolCalls: [
            ChatCompletionStreamMessageToolCallChunk(
              index: 0,
              id: 'call_1',
              function: ChatCompletionStreamMessageFunctionCall(
                name: 'func1',
                arguments: '{}',
              ),
            ),
            ChatCompletionStreamMessageToolCallChunk(
              index: 1,
              id: 'call_2',
              function: ChatCompletionStreamMessageFunctionCall(
                name: 'func2',
                arguments: '{}',
              ),
            ),
          ],
        );

        accumulator.processChunk(delta);
        expect(accumulator.count, 2);
      });
    });
  });
}
