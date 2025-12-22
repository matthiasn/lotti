import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';

void main() {
  group('GeminiThinkingConfig', () {
    group('constructor', () {
      test('creates with required thinkingBudget', () {
        const config = GeminiThinkingConfig(thinkingBudget: 1024);

        expect(config.thinkingBudget, 1024);
        expect(config.includeThoughts, isFalse);
      });

      test('creates with includeThoughts true', () {
        const config = GeminiThinkingConfig(
          thinkingBudget: 2048,
          includeThoughts: true,
        );

        expect(config.thinkingBudget, 2048);
        expect(config.includeThoughts, isTrue);
      });

      test('creates with zero budget (disabled)', () {
        // ignore: use_named_constants, intentionally testing constructor
        const config = GeminiThinkingConfig(thinkingBudget: 0);

        expect(config.thinkingBudget, 0);
      });

      test('creates with negative budget (auto)', () {
        // ignore: use_named_constants, intentionally testing constructor
        const config = GeminiThinkingConfig(thinkingBudget: -1);

        expect(config.thinkingBudget, -1);
      });

      test('creates with max budget', () {
        const config = GeminiThinkingConfig(thinkingBudget: 24576);

        expect(config.thinkingBudget, 24576);
      });
    });

    group('presets', () {
      test('auto preset has budget -1 and includeThoughts false', () {
        expect(GeminiThinkingConfig.auto.thinkingBudget, -1);
        expect(GeminiThinkingConfig.auto.includeThoughts, isFalse);
      });

      test('disabled preset has budget 0 and includeThoughts false', () {
        expect(GeminiThinkingConfig.disabled.thinkingBudget, 0);
        expect(GeminiThinkingConfig.disabled.includeThoughts, isFalse);
      });

      test('standard preset has budget 8192 and includeThoughts false', () {
        expect(GeminiThinkingConfig.standard.thinkingBudget, 8192);
        expect(GeminiThinkingConfig.standard.includeThoughts, isFalse);
      });

      test('intensive preset has budget 16384 and includeThoughts false', () {
        expect(GeminiThinkingConfig.intensive.thinkingBudget, 16384);
        expect(GeminiThinkingConfig.intensive.includeThoughts, isFalse);
      });

      test('presets are const', () {
        // These compile-time const checks verify the presets are constant
        const auto = GeminiThinkingConfig.auto;
        const disabled = GeminiThinkingConfig.disabled;
        const standard = GeminiThinkingConfig.standard;
        const intensive = GeminiThinkingConfig.intensive;

        expect(auto, isNotNull);
        expect(disabled, isNotNull);
        expect(standard, isNotNull);
        expect(intensive, isNotNull);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        const config = GeminiThinkingConfig(
          thinkingBudget: 4096,
          includeThoughts: true,
        );

        final json = config.toJson();

        expect(json, {
          'thinkingBudget': 4096,
          'includeThoughts': true,
        });
      });

      test('serializes with default includeThoughts', () {
        const config = GeminiThinkingConfig(thinkingBudget: 1024);

        final json = config.toJson();

        expect(json, {
          'thinkingBudget': 1024,
          'includeThoughts': false,
        });
      });

      test('serializes auto preset', () {
        final json = GeminiThinkingConfig.auto.toJson();

        expect(json, {
          'thinkingBudget': -1,
          'includeThoughts': false,
        });
      });

      test('serializes disabled preset', () {
        final json = GeminiThinkingConfig.disabled.toJson();

        expect(json, {
          'thinkingBudget': 0,
          'includeThoughts': false,
        });
      });

      test('serializes standard preset', () {
        final json = GeminiThinkingConfig.standard.toJson();

        expect(json, {
          'thinkingBudget': 8192,
          'includeThoughts': false,
        });
      });

      test('serializes intensive preset', () {
        final json = GeminiThinkingConfig.intensive.toJson();

        expect(json, {
          'thinkingBudget': 16384,
          'includeThoughts': false,
        });
      });
    });

    group('thinking capability check', () {
      test('budget != 0 indicates thinking is enabled', () {
        // This tests the pattern used in cloud_inference_repository.dart
        expect(GeminiThinkingConfig.auto.thinkingBudget != 0, isTrue);
        expect(GeminiThinkingConfig.standard.thinkingBudget != 0, isTrue);
        expect(GeminiThinkingConfig.intensive.thinkingBudget != 0, isTrue);
        expect(GeminiThinkingConfig.disabled.thinkingBudget != 0, isFalse);
      });

      test('custom budgets indicate thinking capability correctly', () {
        const enabled = GeminiThinkingConfig(thinkingBudget: 1);
        // ignore: use_named_constants, intentionally testing constructor
        const disabledConfig = GeminiThinkingConfig(thinkingBudget: 0);

        expect(enabled.thinkingBudget != 0, isTrue);
        expect(disabledConfig.thinkingBudget != 0, isFalse);
      });
    });
  });
}
