import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/repository/gemini_payload_processing.dart';

void main() {
  Map<String, dynamic> payload({List<Map<String, dynamic>>? parts}) {
    return <String, dynamic>{
      'candidates': [
        {
          'content': {'parts': parts ?? <Map<String, dynamic>>[]},
        },
      ],
    };
  }

  group('processGeminiPayload', () {
    test('separates thinking from visible text when thoughts are included', () {
      final result = processGeminiPayload(
        payload(
          parts: [
            {'thought': true, 'text': 'pondering'},
            {'text': 'visible answer'},
          ],
        ),
        includeThoughts: true,
      );

      expect(result.thinking, 'pondering');
      expect(result.visible, 'visible answer');
      expect(result.toolChunks, isEmpty);
      expect(result.usage, isNull);
    });

    // Note: current behavior routes thought text into the VISIBLE buffer
    // when thoughts are excluded (the else-if catches it) — it is not
    // dropped. Documented here as-is; flagged as a possible latent bug.
    test('routes thought text into visible output when includeThoughts is '
        'false', () {
      final result = processGeminiPayload(
        payload(
          parts: [
            {'thought': true, 'text': 'pondering'},
            {'text': 'visible answer'},
          ],
        ),
        includeThoughts: false,
      );

      expect(result.thinking, isEmpty);
      expect(result.visible, 'ponderingvisible answer');
    });

    test('extracts tool calls with turn-prefixed ids and captures '
        'part-level thought signatures', () {
      final result = processGeminiPayload(
        payload(
          parts: [
            {
              'functionCall': {
                'name': 'set_title',
                'args': {'title': 'A'},
              },
              'thoughtSignature': 'sig-1',
            },
            {
              'functionCall': {
                'name': 'set_note',
                'args': {'note': 'B'},
              },
            },
          ],
        ),
        includeThoughts: true,
        turnIndex: 3,
      );

      expect(result.toolChunks, hasLength(2));
      expect(result.toolChunks.first.id, 'tool_turn3_0');
      expect(result.toolChunks.first.function?.name, 'set_title');
      expect(result.toolChunks.first.function?.arguments, '{"title":"A"}');
      expect(result.toolChunks.last.id, 'tool_turn3_1');
      // Only the first call carried a signature.
      expect(result.signatures, {'tool_turn3_0': 'sig-1'});
    });

    test('parses usage metadata including reasoning tokens', () {
      final decoded =
          payload(
              parts: [
                {'text': 'hi'},
              ],
            )
            ..['usageMetadata'] = {
              'promptTokenCount': 10,
              'candidatesTokenCount': 5,
              'thoughtsTokenCount': 7,
            };

      final result = processGeminiPayload(decoded, includeThoughts: true);

      expect(result.usage?.promptTokens, 10);
      expect(result.usage?.completionTokens, 5);
      expect(result.usage?.totalTokens, 15);
      expect(result.usage?.completionTokensDetails?.reasoningTokens, 7);
    });

    test('returns empty result for malformed payloads', () {
      final result = processGeminiPayload(
        <String, dynamic>{'candidates': 'not-a-list'},
        includeThoughts: true,
      );

      expect(result.thinking, isEmpty);
      expect(result.visible, isEmpty);
      expect(result.toolChunks, isEmpty);
      expect(result.signatures, isEmpty);
      expect(result.usage, isNull);
    });
  });
}
