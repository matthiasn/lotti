import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';
import 'package:lotti/features/ai/util/gemini_config.dart';

enum _GeneratedDefaultThinkingModelKind {
  gemini31ProWithPrefix,
  gemini31ProWithoutPrefix,
  gemini3LegacyWithPrefix,
  gemini3LegacyWithoutPrefix,
  gemini25FlashWithPrefix,
  gemini25FlashWithoutPrefix,
  gemini25FlashLiteWithPrefix,
  gemini25FlashLiteWithoutPrefix,
  gemini25ProWithPrefix,
  gemini25ProWithoutPrefix,
  gemini20FlashWithPrefix,
  gemini20FlashWithoutPrefix,
  unknown,
  empty,
  uppercaseGemini3,
}

String _generatedDefaultThinkingModelId(
  _GeneratedDefaultThinkingModelKind kind,
) {
  return switch (kind) {
    _GeneratedDefaultThinkingModelKind.gemini31ProWithPrefix =>
      'models/gemini-3.1-pro-preview',
    _GeneratedDefaultThinkingModelKind.gemini31ProWithoutPrefix =>
      'gemini-3.1-pro-preview',
    _GeneratedDefaultThinkingModelKind.gemini3LegacyWithPrefix =>
      'models/gemini-3-pro-preview',
    _GeneratedDefaultThinkingModelKind.gemini3LegacyWithoutPrefix =>
      'gemini-3-pro-preview',
    _GeneratedDefaultThinkingModelKind.gemini25FlashWithPrefix =>
      'models/gemini-2.5-flash',
    _GeneratedDefaultThinkingModelKind.gemini25FlashWithoutPrefix =>
      'gemini-2.5-flash',
    _GeneratedDefaultThinkingModelKind.gemini25FlashLiteWithPrefix =>
      'models/gemini-2.5-flash-lite',
    _GeneratedDefaultThinkingModelKind.gemini25FlashLiteWithoutPrefix =>
      'gemini-2.5-flash-lite',
    _GeneratedDefaultThinkingModelKind.gemini25ProWithPrefix =>
      'models/gemini-2.5-pro',
    _GeneratedDefaultThinkingModelKind.gemini25ProWithoutPrefix =>
      'gemini-2.5-pro',
    _GeneratedDefaultThinkingModelKind.gemini20FlashWithPrefix =>
      'models/gemini-2.0-flash',
    _GeneratedDefaultThinkingModelKind.gemini20FlashWithoutPrefix =>
      'gemini-2.0-flash',
    _GeneratedDefaultThinkingModelKind.unknown => 'models/gemini-unknown',
    _GeneratedDefaultThinkingModelKind.empty => '',
    _GeneratedDefaultThinkingModelKind.uppercaseGemini3 =>
      'GEMINI-3-PRO-PREVIEW',
  };
}

GeminiThinkingConfig _expectedDefaultThinkingConfig(
  _GeneratedDefaultThinkingModelKind kind,
) {
  return switch (kind) {
    _GeneratedDefaultThinkingModelKind.gemini31ProWithPrefix ||
    _GeneratedDefaultThinkingModelKind.gemini31ProWithoutPrefix ||
    _GeneratedDefaultThinkingModelKind.gemini3LegacyWithPrefix ||
    _GeneratedDefaultThinkingModelKind.gemini3LegacyWithoutPrefix =>
      const GeminiThinkingConfig(thinkingBudget: 4096),
    _GeneratedDefaultThinkingModelKind.gemini25FlashWithPrefix ||
    _GeneratedDefaultThinkingModelKind.gemini25FlashWithoutPrefix =>
      GeminiThinkingConfig.standard,
    _GeneratedDefaultThinkingModelKind.gemini25FlashLiteWithPrefix ||
    _GeneratedDefaultThinkingModelKind.gemini25FlashLiteWithoutPrefix =>
      const GeminiThinkingConfig(thinkingBudget: 4096),
    _GeneratedDefaultThinkingModelKind.gemini25ProWithPrefix ||
    _GeneratedDefaultThinkingModelKind.gemini25ProWithoutPrefix =>
      GeminiThinkingConfig.auto,
    _GeneratedDefaultThinkingModelKind.gemini20FlashWithPrefix ||
    _GeneratedDefaultThinkingModelKind.gemini20FlashWithoutPrefix =>
      GeminiThinkingConfig.disabled,
    _GeneratedDefaultThinkingModelKind.unknown ||
    _GeneratedDefaultThinkingModelKind.empty ||
    _GeneratedDefaultThinkingModelKind.uppercaseGemini3 =>
      GeminiThinkingConfig.auto,
  };
}

extension _AnyGeneratedDefaultThinkingConfig on glados.Any {
  glados.Generator<_GeneratedDefaultThinkingModelKind>
  get defaultThinkingModelKind =>
      glados.AnyUtils(this).choose(_GeneratedDefaultThinkingModelKind.values);
}

void main() {
  group('getDefaultThinkingConfig', () {
    group('Gemini 3 Pro Preview', () {
      test(
        'returns medium-budget config for models/gemini-3.1-pro-preview',
        () {
          final config = getDefaultThinkingConfig(
            'models/gemini-3.1-pro-preview',
          );
          // Budget 4096 maps to thinkingLevel: MEDIUM for Gemini 3.x.
          expect(config.thinkingBudget, 4096);
        },
      );

      test('returns medium-budget config for gemini-3.1-pro-preview', () {
        final config = getDefaultThinkingConfig('gemini-3.1-pro-preview');
        expect(config.thinkingBudget, 4096);
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

    group('Gemini 3 Pro Preview (old model ID fallback)', () {
      test('returns medium-budget config for models/gemini-3-pro-preview', () {
        final config = getDefaultThinkingConfig('models/gemini-3-pro-preview');
        expect(config.thinkingBudget, 4096);
      });

      test('returns medium-budget config for gemini-3-pro-preview', () {
        final config = getDefaultThinkingConfig('gemini-3-pro-preview');
        expect(config.thinkingBudget, 4096);
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
      test('Gemini 3 Pro uses medium reasoning level', () {
        final config = getDefaultThinkingConfig('gemini-3.1-pro-preview');
        // Budget 4096 → thinkingLevel: MEDIUM for Gemini 3.x
        expect(config.thinkingBudget, 4096);
      });

      test('all known models return valid configs', () {
        final modelIds = [
          'models/gemini-3.1-pro-preview',
          'gemini-3.1-pro-preview',
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
          expect(
            config,
            isA<GeminiThinkingConfig>(),
            reason: 'Model $modelId should return a valid config',
          );
        }
      });
    });

    group('Model ID formats', () {
      test('handles models with "models/" prefix consistently', () {
        final withPrefix = getDefaultThinkingConfig(
          'models/gemini-3.1-pro-preview',
        );
        final withoutPrefix = getDefaultThinkingConfig(
          'gemini-3.1-pro-preview',
        );
        expect(withPrefix.thinkingBudget, withoutPrefix.thinkingBudget);
      });

      test('handles case sensitivity correctly', () {
        // Model IDs should be case-sensitive (lowercase expected)
        final lowercase = getDefaultThinkingConfig('gemini-3.1-pro-preview');
        final uppercase = getDefaultThinkingConfig('GEMINI-3-PRO-PREVIEW');

        // Lowercase matches Gemini 3.x → budget 4096
        expect(lowercase.thinkingBudget, 4096);
        // Uppercase falls through to default (auto)
        expect(uppercase, equals(GeminiThinkingConfig.auto));
      });

      glados.Glados(
        glados.any.defaultThinkingModelKind,
        glados.ExploreConfig(numRuns: 120),
      ).test('matches generated default thinking config model mappings', (
        kind,
      ) {
        final config = getDefaultThinkingConfig(
          _generatedDefaultThinkingModelId(kind),
        );
        final expected = _expectedDefaultThinkingConfig(kind);

        expect(config.thinkingBudget, expected.thinkingBudget);
        expect(config.includeThoughts, expected.includeThoughts);
      }, tags: 'glados');
    });
  });
}
