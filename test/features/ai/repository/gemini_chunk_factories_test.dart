import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/repository/gemini_chunk_factories.dart';

void main() {
  group('chunk factories', () {
    test('createThinkingChunk wraps the thinking text in think tags', () {
      final chunk = createThinkingChunk(
        id: 'id-1',
        created: 123,
        model: 'gemini-test',
        thinking: 'pondering',
      );

      expect(chunk.id, 'id-1');
      expect(chunk.created, 123);
      expect(chunk.model, 'gemini-test');
      expect(
        chunk.choices!.single.delta?.content,
        '<think>\npondering\n</think>\n',
      );
    });

    test('createTextChunk carries the visible text verbatim', () {
      final chunk = createTextChunk(
        id: 'id-2',
        created: 456,
        model: 'gemini-test',
        text: 'visible',
      );

      expect(chunk.choices!.single.delta?.content, 'visible');
    });

    test('createToolCallChunk emits one tool call with the given identity', () {
      final chunk = createToolCallChunk(
        id: 'id-3',
        created: 789,
        model: 'gemini-test',
        index: 2,
        toolCallId: 'tool_turn0_2',
        name: 'set_title',
        arguments: '{"title":"A"}',
      );

      final call = chunk.choices!.single.delta!.toolCalls!.single;
      expect(call.index, 2);
      expect(call.id, 'tool_turn0_2');
      expect(call.function?.name, 'set_title');
      expect(call.function?.arguments, '{"title":"A"}');
    });

    test('createUsageChunk totals tokens and forwards reasoning tokens', () {
      final chunk = createUsageChunk(
        id: 'id-4',
        created: 1,
        model: 'gemini-test',
        promptTokens: 10,
        completionTokens: 5,
        thoughtsTokens: 7,
      );

      expect(chunk.choices, isEmpty);
      expect(chunk.usage?.promptTokens, 10);
      expect(chunk.usage?.completionTokens, 5);
      expect(chunk.usage?.totalTokens, 15);
      expect(chunk.usage?.completionTokensDetails?.reasoningTokens, 7);
    });

    test('createUsageChunk omits reasoning details without thought tokens', () {
      final chunk = createUsageChunk(
        id: 'id-5',
        created: 1,
        model: 'gemini-test',
        promptTokens: 3,
      );

      expect(chunk.usage?.totalTokens, 3);
      expect(chunk.usage?.completionTokensDetails, isNull);
    });
  });

  group('captureSignatureIfPresent', () {
    test('adds a part-level signature to the collector', () {
      final collector = ThoughtSignatureCollector();

      captureSignatureIfPresent(
        part: <String, dynamic>{
          'functionCall': {'name': 'f', 'args': <String, dynamic>{}},
          'thoughtSignature': 'sig-9',
        },
        toolCallId: 'tool_turn0_0',
        functionName: 'f',
        toolCallIndex: 0,
        signatureCollector: collector,
      );

      expect(collector.signatures, {'tool_turn0_0': 'sig-9'});
    });

    test('leaves the collector untouched when no signature is present', () {
      final collector = ThoughtSignatureCollector();

      captureSignatureIfPresent(
        part: <String, dynamic>{
          'functionCall': {'name': 'f', 'args': <String, dynamic>{}},
        },
        toolCallId: 'tool_turn0_0',
        functionName: 'f',
        toolCallIndex: 0,
        signatureCollector: collector,
      );

      expect(collector.signatures, isEmpty);
    });
  });
}
