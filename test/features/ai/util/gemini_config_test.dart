import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/util/gemini_config.dart';

void main() {
  group('getDefaultThinkingConfig', () {
    group('Gemini 3 Pro Preview', () {
      test('returns auto config for models/gemini-3-pro-preview', () {
        final config = getDefaultThinkingConfig('models/gemini-3-pro-preview');
        expect(config, equals(GeminiThinkingConfig.auto));
      });

      test('returns auto config for gemini-3-pro-preview', () {
        final config = getDefaultThinkingConfig('gemini-3-pro-preview');
        expect(config, equals(GeminiThinkingConfig.auto));
      });
    });

    group('Gemini 2.5 Flash', () {
      test('returns standard config for models/gemini-2.5-flash', () {
        final config = getDefaultThinkingConfig('models/gemini-2.5-flash');
        expect(config, equals(GeminiThinkingConfig.standard));
      });

      test('returns standard config for gemini-2.5-flash', () {
        final config = getDefaultThinkingConfig('gemini-2.5-flash');
        expect(config, equals(GeminiThinkingConfig.standard));
      });
    });

    group('Gemini 2.5 Flash Lite', () {
      test('returns custom config for models/gemini-2.5-flash-lite', () {
        final config = getDefaultThinkingConfig('models/gemini-2.5-flash-lite');
        expect(config.thinkingBudget, equals(4096));
      });

      test('returns custom config for gemini-2.5-flash-lite', () {
        final config = getDefaultThinkingConfig('gemini-2.5-flash-lite');
        expect(config.thinkingBudget, equals(4096));
      });
    });

    group('Gemini 2.5 Pro', () {
      test('returns auto config for models/gemini-2.5-pro', () {
        final config = getDefaultThinkingConfig('models/gemini-2.5-pro');
        expect(config, equals(GeminiThinkingConfig.auto));
      });

      test('returns auto config for gemini-2.5-pro', () {
        final config = getDefaultThinkingConfig('gemini-2.5-pro');
        expect(config, equals(GeminiThinkingConfig.auto));
      });
    });

    group('Gemini 2.0 Flash', () {
      test('returns disabled config for models/gemini-2.0-flash', () {
        final config = getDefaultThinkingConfig('models/gemini-2.0-flash');
        expect(config, equals(GeminiThinkingConfig.disabled));
      });

      test('returns disabled config for gemini-2.0-flash', () {
        final config = getDefaultThinkingConfig('gemini-2.0-flash');
        expect(config, equals(GeminiThinkingConfig.disabled));
      });
    });

    group('Unknown models', () {
      test('returns auto config for unknown model IDs', () {
        final config = getDefaultThinkingConfig('models/gemini-unknown');
        expect(config, equals(GeminiThinkingConfig.auto));
      });

      test('returns auto config for future models', () {
        final config = getDefaultThinkingConfig('gemini-4.0-ultra');
        expect(config, equals(GeminiThinkingConfig.auto));
      });

      test('returns auto config for empty string', () {
        final config = getDefaultThinkingConfig('');
        expect(config, equals(GeminiThinkingConfig.auto));
      });
    });

    group('Configuration properties', () {
      test('Gemini 3 Pro uses advanced reasoning capabilities', () {
        final config = getDefaultThinkingConfig('gemini-3-pro-preview');
        // Verify it uses auto config which enables thinking
        expect(config, equals(GeminiThinkingConfig.auto));
      });

      test('all known models return valid configs', () {
        final modelIds = [
          'models/gemini-3-pro-preview',
          'gemini-3-pro-preview',
          'models/gemini-2.5-pro',
          'gemini-2.5-pro',
          'models/gemini-2.5-flash',
          'gemini-2.5-flash',
          'models/gemini-2.5-flash-lite',
          'gemini-2.5-flash-lite',
          'models/gemini-2.0-flash',
          'gemini-2.0-flash',
        ];

        for (final modelId in modelIds) {
          final config = getDefaultThinkingConfig(modelId);
          expect(config, isA<GeminiThinkingConfig>(),
              reason: 'Model $modelId should return a valid config');
        }
      });
    });

    group('Model ID formats', () {
      test('handles models with "models/" prefix consistently', () {
        final withPrefix =
            getDefaultThinkingConfig('models/gemini-3-pro-preview');
        final withoutPrefix = getDefaultThinkingConfig('gemini-3-pro-preview');
        expect(withPrefix, equals(withoutPrefix));
      });

      test('handles case sensitivity correctly', () {
        // Model IDs should be case-sensitive (lowercase expected)
        final lowercase = getDefaultThinkingConfig('gemini-3-pro-preview');
        final uppercase = getDefaultThinkingConfig('GEMINI-3-PRO-PREVIEW');

        // Uppercase falls through to default (auto)
        expect(lowercase, equals(GeminiThinkingConfig.auto));
        expect(uppercase, equals(GeminiThinkingConfig.auto));
      });
    });
  });
}
