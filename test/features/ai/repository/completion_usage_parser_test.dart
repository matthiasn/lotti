import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/repository/completion_usage_parser.dart';

void main() {
  group('parseCompletionUsage', () {
    test('parses token usage without casting map keys', () {
      final ignoredKey = Object();

      final usage = parseCompletionUsage({
        ignoredKey: 'ignored',
        'prompt_tokens': 12,
        'completion_tokens': '8',
        'prompt_tokens_details': {
          ignoredKey: 'ignored',
          'cached_tokens': '3',
        },
        'completion_tokens_details': {
          ignoredKey: 'ignored',
          'reasoning_tokens': 5,
        },
      });

      expect(usage, isNotNull);
      expect(usage!.promptTokens, 12);
      expect(usage.completionTokens, 8);
      expect(usage.totalTokens, 20);
      expect(usage.promptTokensDetails?.cachedTokens, 3);
      expect(usage.completionTokensDetails?.reasoningTokens, 5);
    });

    test('uses camelCase and input/output token aliases', () {
      final usage = parseCompletionUsage({
        'input_tokens': 4,
        'output_tokens': 6,
        'promptTokensDetails': {'cachedTokens': 2},
        'outputTokensDetails': {'reasoningTokens': 1},
      });

      expect(usage, isNotNull);
      expect(usage!.promptTokens, 4);
      expect(usage.completionTokens, 6);
      expect(usage.totalTokens, 10);
      expect(usage.promptTokensDetails?.cachedTokens, 2);
      expect(usage.completionTokensDetails?.reasoningTokens, 1);
    });

    test('ignores non-token usage payloads', () {
      expect(parseCompletionUsage({'duration': 1.25}), isNull);
      expect(parseCompletionUsage('not a map'), isNull);
    });
  });
}
