import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/gemini_thinking_config.dart';

enum _GeneratedThinkingBudgetKind {
  belowAuto,
  auto,
  disabled,
  minimal,
  lowBoundary,
  mediumBoundary,
  highBoundary,
  maxDocumented,
}

enum _GeneratedGeminiThinkingModelKind {
  nullModel,
  gemini3WithPrefix,
  gemini3WithoutPrefix,
  gemini3LegacyWithPrefix,
  gemini25,
  gemini20,
  uppercaseGemini3,
  unknown,
}

int _generatedThinkingBudget(_GeneratedThinkingBudgetKind kind) {
  return switch (kind) {
    _GeneratedThinkingBudgetKind.belowAuto => -2,
    _GeneratedThinkingBudgetKind.auto => -1,
    _GeneratedThinkingBudgetKind.disabled => 0,
    _GeneratedThinkingBudgetKind.minimal => 1,
    _GeneratedThinkingBudgetKind.lowBoundary => 4095,
    _GeneratedThinkingBudgetKind.mediumBoundary => 4096,
    _GeneratedThinkingBudgetKind.highBoundary => 8192,
    _GeneratedThinkingBudgetKind.maxDocumented => 24576,
  };
}

String? _generatedThinkingModelId(_GeneratedGeminiThinkingModelKind kind) {
  return switch (kind) {
    _GeneratedGeminiThinkingModelKind.nullModel => null,
    _GeneratedGeminiThinkingModelKind.gemini3WithPrefix =>
      'models/gemini-3.1-pro-preview',
    _GeneratedGeminiThinkingModelKind.gemini3WithoutPrefix =>
      'gemini-3.1-pro-preview',
    _GeneratedGeminiThinkingModelKind.gemini3LegacyWithPrefix =>
      'models/gemini-3-pro-preview',
    _GeneratedGeminiThinkingModelKind.gemini25 => 'models/gemini-2.5-pro',
    _GeneratedGeminiThinkingModelKind.gemini20 => 'gemini-2.0-flash',
    _GeneratedGeminiThinkingModelKind.uppercaseGemini3 =>
      'GEMINI-3.1-PRO-PREVIEW',
    _GeneratedGeminiThinkingModelKind.unknown => 'models/custom-model',
  };
}

String _generatedThinkingLevel(int budget) {
  if (budget == -1) return 'high';
  if (budget == 0) return 'minimal';
  if (budget < 4096) return 'low';
  if (budget < 8192) return 'medium';
  return 'high';
}

class _GeneratedGeminiThinkingScenario {
  const _GeneratedGeminiThinkingScenario({
    required this.budgetKind,
    required this.modelKind,
    required this.includeThoughts,
  });

  final _GeneratedThinkingBudgetKind budgetKind;
  final _GeneratedGeminiThinkingModelKind modelKind;
  final bool includeThoughts;

  int get budget => _generatedThinkingBudget(budgetKind);

  String? get modelId => _generatedThinkingModelId(modelKind);

  bool get isGemini3Model =>
      modelId != null && GeminiThinkingConfig.isGemini3(modelId!);

  Map<String, dynamic> get expectedJson {
    if (isGemini3Model) {
      return {
        'thinkingLevel': _generatedThinkingLevel(budget),
        'includeThoughts': includeThoughts,
      };
    }

    return {
      'thinkingBudget': budget,
      'includeThoughts': includeThoughts,
    };
  }

  @override
  String toString() {
    return '_GeneratedGeminiThinkingScenario('
        'budgetKind: $budgetKind, modelKind: $modelKind, '
        'includeThoughts: $includeThoughts)';
  }
}

extension _AnyGeneratedGeminiThinkingScenario on glados.Any {
  glados.Generator<_GeneratedThinkingBudgetKind> get thinkingBudgetKind =>
      glados.AnyUtils(this).choose(_GeneratedThinkingBudgetKind.values);

  glados.Generator<_GeneratedGeminiThinkingModelKind> get thinkingModelKind =>
      glados.AnyUtils(this).choose(_GeneratedGeminiThinkingModelKind.values);

  glados.Generator<_GeneratedGeminiThinkingScenario>
  get geminiThinkingScenario => glados.CombinableAny(this).combine3(
    thinkingBudgetKind,
    thinkingModelKind,
    glados.any.bool,
    (
      _GeneratedThinkingBudgetKind budgetKind,
      _GeneratedGeminiThinkingModelKind modelKind,
      bool includeThoughts,
    ) => _GeneratedGeminiThinkingScenario(
      budgetKind: budgetKind,
      modelKind: modelKind,
      includeThoughts: includeThoughts,
    ),
  );
}

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

      test('mode presets carry API modes and fallback budgets', () {
        expect(
          GeminiThinkingConfig.minimal.thinkingMode,
          GeminiThinkingMode.minimal,
        );
        expect(GeminiThinkingConfig.minimal.thinkingBudget, 0);
        expect(GeminiThinkingConfig.low.thinkingMode, GeminiThinkingMode.low);
        expect(GeminiThinkingConfig.low.thinkingBudget, 1024);
        expect(
          GeminiThinkingConfig.medium.thinkingMode,
          GeminiThinkingMode.medium,
        );
        expect(GeminiThinkingConfig.medium.thinkingBudget, 4096);
        expect(GeminiThinkingConfig.high.thinkingMode, GeminiThinkingMode.high);
        expect(GeminiThinkingConfig.high.thinkingBudget, -1);
      });

      test('presets are const', () {
        // These compile-time const checks verify the presets are constant
        const auto = GeminiThinkingConfig.auto;
        const disabled = GeminiThinkingConfig.disabled;
        const standard = GeminiThinkingConfig.standard;

        expect(auto, isNotNull);
        expect(disabled, isNotNull);
        expect(standard, isNotNull);
      });
    });

    group('fromMode', () {
      test('maps each model-setting mode to the expected config', () {
        final cases = <GeminiThinkingMode, (int, String)>{
          GeminiThinkingMode.minimal: (0, 'minimal'),
          GeminiThinkingMode.low: (1024, 'low'),
          GeminiThinkingMode.medium: (4096, 'medium'),
          GeminiThinkingMode.high: (-1, 'high'),
        };

        for (final entry in cases.entries) {
          final config = GeminiThinkingConfig.fromMode(
            entry.key,
            includeThoughts: entry.key != GeminiThinkingMode.minimal,
          );

          expect(config.thinkingMode, entry.key);
          expect(config.thinkingBudget, entry.value.$1);
          expect(
            config.toJson(modelId: 'gemini-3.1-pro-preview'),
            {
              'thinkingLevel': entry.value.$2,
              'includeThoughts': entry.key != GeminiThinkingMode.minimal,
            },
          );
        }
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
    });

    group('isGemini3', () {
      test('matches Gemini 3.x model IDs with models/ prefix', () {
        expect(
          GeminiThinkingConfig.isGemini3('models/gemini-3.1-pro-preview'),
          isTrue,
        );
        expect(
          GeminiThinkingConfig.isGemini3('models/gemini-3-pro-preview'),
          isTrue,
        );
      });

      test('matches Gemini 3.x model IDs without prefix', () {
        expect(
          GeminiThinkingConfig.isGemini3('gemini-3.1-pro-preview'),
          isTrue,
        );
        expect(GeminiThinkingConfig.isGemini3('gemini-3-pro-preview'), isTrue);
      });

      test('does not match Gemini 2.x model IDs', () {
        expect(
          GeminiThinkingConfig.isGemini3('models/gemini-2.5-pro'),
          isFalse,
        );
        expect(GeminiThinkingConfig.isGemini3('gemini-2.5-flash'), isFalse);
        expect(
          GeminiThinkingConfig.isGemini3('models/gemini-2.0-flash'),
          isFalse,
        );
      });
    });

    group('toJson with Gemini 3.x modelId', () {
      test('emits thinkingLevel for Gemini 3.x model', () {
        final json = GeminiThinkingConfig.auto.toJson(
          modelId: 'models/gemini-3.1-pro-preview',
        );

        expect(json.containsKey('thinkingLevel'), isTrue);
        expect(json.containsKey('thinkingBudget'), isFalse);
        expect(json['thinkingLevel'], 'high');
        expect(json['includeThoughts'], isFalse);
      });

      test('emits thinkingBudget for non-Gemini-3 model', () {
        final json = GeminiThinkingConfig.auto.toJson(
          modelId: 'models/custom-model',
        );

        expect(json.containsKey('thinkingBudget'), isTrue);
        expect(json.containsKey('thinkingLevel'), isFalse);
        expect(json['thinkingBudget'], -1);
      });

      test('emits thinkingBudget when modelId is null', () {
        final json = GeminiThinkingConfig.auto.toJson();

        expect(json.containsKey('thinkingBudget'), isTrue);
        expect(json.containsKey('thinkingLevel'), isFalse);
      });

      test('maps auto preset to high for Gemini 3', () {
        final json = GeminiThinkingConfig.auto.toJson(
          modelId: 'gemini-3.1-pro-preview',
        );
        expect(json['thinkingLevel'], 'high');
      });

      test('maps disabled preset to minimal for Gemini 3', () {
        final json = GeminiThinkingConfig.disabled.toJson(
          modelId: 'gemini-3.1-pro-preview',
        );
        expect(json['thinkingLevel'], 'minimal');
      });

      test('maps standard preset (8192) to high for Gemini 3', () {
        final json = GeminiThinkingConfig.standard.toJson(
          modelId: 'gemini-3.1-pro-preview',
        );
        expect(json['thinkingLevel'], 'high');
      });

      test('maps budget 4096 to medium for Gemini 3', () {
        const config = GeminiThinkingConfig(thinkingBudget: 4096);
        final json = config.toJson(modelId: 'gemini-3-pro-preview');
        expect(json['thinkingLevel'], 'medium');
      });

      test('maps budget 2048 to low for Gemini 3', () {
        const config = GeminiThinkingConfig(thinkingBudget: 2048);
        final json = config.toJson(modelId: 'gemini-3-pro-preview');
        expect(json['thinkingLevel'], 'low');
      });

      test('maps large budget (>= 8192) to high for Gemini 3', () {
        const config = GeminiThinkingConfig(thinkingBudget: 16384);
        final json = config.toJson(modelId: 'gemini-3.1-pro-preview');
        expect(json['thinkingLevel'], 'high');
      });

      glados.Glados(
        glados.any.geminiThinkingScenario,
        glados.ExploreConfig(numRuns: 160),
      ).test(
        'matches generated model and budget serialization semantics',
        (
          scenario,
        ) {
          final config = GeminiThinkingConfig(
            thinkingBudget: scenario.budget,
            includeThoughts: scenario.includeThoughts,
          );

          expect(
            config.toJson(modelId: scenario.modelId),
            scenario.expectedJson,
            reason: '$scenario',
          );
        },
        tags: 'glados',
      );
    });

    group('thinking capability check', () {
      test('budget != 0 indicates thinking is enabled', () {
        // This tests the pattern used in cloud_inference_repository.dart
        expect(GeminiThinkingConfig.auto.thinkingBudget != 0, isTrue);
        expect(GeminiThinkingConfig.standard.thinkingBudget != 0, isTrue);
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
