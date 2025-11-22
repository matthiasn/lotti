import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai_chat/ui/providers/chat_model_providers.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

void main() {
  group('eligibleChatModelsForCategoryProvider', () {
    late MockAiConfigRepository mockRepo;
    late ProviderContainer container;

    setUp(() {
      mockRepo = MockAiConfigRepository();
      container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('filters to function-calling + text models and sorts by provider/name',
        () async {
      final geminiProvider = AiConfigInferenceProvider(
        id: 'prov-g',
        name: 'Gemini Provider',
        baseUrl: 'https://gemini',
        apiKey: 'k',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.gemini,
      );
      final openaiProvider = AiConfigInferenceProvider(
        id: 'prov-o',
        name: 'OpenAI Provider',
        baseUrl: 'https://openai',
        apiKey: 'k',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.openAi,
      );

      final eligible1 = AiConfigModel(
        id: 'm1',
        name: 'Alpha',
        providerModelId: 'alpha',
        inferenceProviderId: openaiProvider.id,
        createdAt: DateTime(2024),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
        supportsFunctionCalling: true,
      );
      final eligible2 = AiConfigModel(
        id: 'm2',
        name: 'Beta',
        providerModelId: 'beta',
        inferenceProviderId: geminiProvider.id,
        createdAt: DateTime(2024),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: true,
        supportsFunctionCalling: true,
      );
      final ineligibleNoFunc = AiConfigModel(
        id: 'm3',
        name: 'NoFunc',
        providerModelId: 'nofunc',
        inferenceProviderId: geminiProvider.id,
        createdAt: DateTime(2024),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
        // ignore: avoid_redundant_argument_values
        supportsFunctionCalling: false,
      );
      final ineligibleNoText = AiConfigModel(
        id: 'm4',
        name: 'NoText',
        providerModelId: 'notext',
        inferenceProviderId: openaiProvider.id,
        createdAt: DateTime(2024),
        inputModalities: const [Modality.image],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
        supportsFunctionCalling: true,
      );

      when(() => mockRepo.getConfigsByType(AiConfigType.model)).thenAnswer(
          (_) async =>
              [eligible2, eligible1, ineligibleNoFunc, ineligibleNoText]);
      when(() => mockRepo.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => [geminiProvider, openaiProvider]);

      final result = await container.read(
          eligibleChatModelsForCategoryProvider(categoryId: 'cat').future);

      // Should keep only eligible1 and eligible2
      expect(result.map((m) => m.id), ['m2', 'm1']);
      // Sorted by provider name then model name: Gemini Provider/Beta then OpenAI Provider/Alpha
      expect(result.first.name, 'Beta');
      expect(result.last.name, 'Alpha');
    });
  });
}
