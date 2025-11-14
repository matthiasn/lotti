import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/functions/checklist_tool_selector.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

void main() {
  AiConfigInferenceProvider makeProvider(InferenceProviderType type) =>
      AiConfigInferenceProvider(
        id: 'prov-${type.name}',
        baseUrl: 'http://localhost',
        apiKey: '',
        name: type.name,
        // ignore: avoid_redundant_argument_values
        createdAt: DateTime(2025, 1, 1),
        inferenceProviderType: type,
      );

  AiConfigModel makeModel(String providerModelId) => AiConfigModel(
        id: 'model-$providerModelId',
        name: providerModelId,
        providerModelId: providerModelId,
        inferenceProviderId: 'prov',
        // ignore: avoid_redundant_argument_values
        createdAt: DateTime(2025, 1, 1),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
        supportsFunctionCalling: true,
      );

  group('getChecklistToolsForProvider', () {
    test('returns checklist tools universally (array-only batch)', () {
      final provider = makeProvider(InferenceProviderType.ollama);
      final model = makeModel('gpt-oss:20b');
      final tools =
          getChecklistToolsForProvider(provider: provider, model: model);
      final names = tools.map((t) => t.function.name).toList();
      expect(names, contains('suggest_checklist_completion'));
      expect(names, contains('add_multiple_checklist_items'));
      expect(names, contains('complete_checklist_items'));
      expect(names.length, 3);
    });

    test('returns same checklist tools for all providers', () {
      final nonOllamaProviders = [
        InferenceProviderType.openAi,
        InferenceProviderType.anthropic,
        InferenceProviderType.gemini,
        InferenceProviderType.gemma3n,
        InferenceProviderType.genericOpenAi,
        InferenceProviderType.openRouter,
        InferenceProviderType.nebiusAiStudio,
        InferenceProviderType.whisper,
      ];

      for (final type in nonOllamaProviders) {
        final provider = makeProvider(type);
        final model = makeModel('any:model');
        final tools =
            getChecklistToolsForProvider(provider: provider, model: model);
        final names = tools.map((t) => t.function.name).toList();
        expect(names, contains('suggest_checklist_completion'));
        expect(names, contains('add_multiple_checklist_items'));
        expect(names, contains('complete_checklist_items'));
        expect(names.length, 3);
      }
    });
  });
}
