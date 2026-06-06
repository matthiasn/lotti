import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai_chat/ui/providers/chat_model_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

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

    test(
      'filters to function-calling + text models and sorts by provider/name',
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
          (_) async => [
            eligible2,
            eligible1,
            ineligibleNoFunc,
            ineligibleNoText,
          ],
        );
        when(
          () => mockRepo.getConfigsByType(AiConfigType.inferenceProvider),
        ).thenAnswer((_) async => [geminiProvider, openaiProvider]);

        final result = await container.read(
          eligibleChatModelsForCategoryProvider('cat').future,
        );

        // Should keep only eligible1 and eligible2
        expect(result.map((m) => m.id), ['m2', 'm1']);
        // Sorted by provider name then model name: Gemini Provider/Beta then OpenAI Provider/Alpha
        expect(result.first.name, 'Beta');
        expect(result.last.name, 'Alpha');
      },
    );

    AiConfigModel model({
      required String id,
      required String name,
      String providerId = 'prov-x',
      bool supportsFunctionCalling = true,
      List<Modality> input = const [Modality.text],
    }) => AiConfigModel(
      id: id,
      name: name,
      providerModelId: id,
      inferenceProviderId: providerId,
      createdAt: DateTime(2024),
      inputModalities: input,
      outputModalities: const [Modality.text],
      isReasoningModel: false,
      supportsFunctionCalling: supportsFunctionCalling,
    );

    void stubConfigs({
      List<AiConfig> models = const [],
      List<AiConfig> providers = const [],
    }) {
      when(
        () => mockRepo.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => models);
      when(
        () => mockRepo.getConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) async => providers);
    }

    test('returns an empty list when no models are configured', () async {
      stubConfigs();

      final result = await container.read(
        eligibleChatModelsForCategoryProvider('cat').future,
      );

      expect(result, isEmpty);
    });

    test('returns an empty list when every model is ineligible', () async {
      stubConfigs(
        models: [
          model(id: 'm1', name: 'NoFunc', supportsFunctionCalling: false),
          model(id: 'm2', name: 'NoText', input: const [Modality.image]),
        ],
      );

      final result = await container.read(
        eligibleChatModelsForCategoryProvider('cat').future,
      );

      expect(result, isEmpty);
    });

    test('a single eligible model is returned as-is', () async {
      stubConfigs(
        models: [model(id: 'm1', name: 'Solo')],
      );

      final result = await container.read(
        eligibleChatModelsForCategoryProvider('cat').future,
      );

      expect(result.map((m) => m.id), ['m1']);
    });

    test(
      'a provider-lookup miss sorts under the empty provider name',
      () async {
        final knownProvider = AiConfigInferenceProvider(
          id: 'prov-known',
          name: 'Known Provider',
          baseUrl: 'https://known',
          apiKey: 'k',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.openAi,
        );
        stubConfigs(
          models: [
            model(id: 'm-known', name: 'Known', providerId: knownProvider.id),
            model(id: 'm-orphan', name: 'Orphan', providerId: 'prov-missing'),
          ],
          providers: [knownProvider],
        );

        final result = await container.read(
          eligibleChatModelsForCategoryProvider('cat').future,
        );

        // The orphan's provider name falls back to '' which sorts first.
        expect(result.map((m) => m.id), ['m-orphan', 'm-known']);
      },
    );
  });
}
