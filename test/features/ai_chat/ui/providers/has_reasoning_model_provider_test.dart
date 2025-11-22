import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai_chat/ui/providers/chat_model_providers.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

void main() {
  group('hasReasoningModelForCategoryProvider', () {
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

    tearDown(() => container.dispose());

    test('returns true when any eligible model is reasoning-capable', () async {
      final provider = AiConfigInferenceProvider(
        id: 'prov',
        name: 'P',
        baseUrl: 'https://',
        apiKey: 'k',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.openAi,
      );
      final reasoning = AiConfigModel(
        id: 'm1',
        name: 'Reasoner',
        providerModelId: 'r',
        inferenceProviderId: provider.id,
        createdAt: DateTime(2024),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: true,
        supportsFunctionCalling: true,
      );

      when(() => mockRepo.getConfigsByType(AiConfigType.model))
          .thenAnswer((_) async => [reasoning]);
      when(() => mockRepo.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => [provider]);

      final result = await container.read(
        hasReasoningModelForCategoryProvider(categoryId: 'cat').future,
      );
      expect(result, isTrue);
    });

    test('returns false when no reasoning-capable eligible models', () async {
      final provider = AiConfigInferenceProvider(
        id: 'prov',
        name: 'P',
        baseUrl: 'https://',
        apiKey: 'k',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.openAi,
      );
      final notReasoning = AiConfigModel(
        id: 'm1',
        name: 'Plain',
        providerModelId: 'p',
        inferenceProviderId: provider.id,
        createdAt: DateTime(2024),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
        supportsFunctionCalling: true,
      );

      when(() => mockRepo.getConfigsByType(AiConfigType.model))
          .thenAnswer((_) async => [notReasoning]);
      when(() => mockRepo.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => [provider]);

      final result = await container.read(
        hasReasoningModelForCategoryProvider(categoryId: 'cat').future,
      );
      expect(result, isFalse);
    });
  });
}
