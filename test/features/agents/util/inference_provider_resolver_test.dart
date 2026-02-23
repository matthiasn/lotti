import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/util/inference_provider_resolver.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  late MockAiConfigRepository mockAiConfig;

  setUpAll(() {
    registerFallbackValue(AiConfigType.model);
  });

  setUp(() {
    mockAiConfig = MockAiConfigRepository();
  });

  void stubResolution({String apiKey = 'test-key'}) {
    when(() => mockAiConfig.getConfigsByType(AiConfigType.model))
        .thenAnswer((_) async => [testAiModel()]);
    when(() => mockAiConfig.getConfigById('provider-1'))
        .thenAnswer((_) async => testInferenceProvider(apiKey: apiKey));
  }

  group('resolveInferenceProvider', () {
    test('returns provider when model and provider are configured', () async {
      stubResolution();

      final provider = await resolveInferenceProvider(
        modelId: 'models/gemini-3.1-pro-preview',
        aiConfigRepository: mockAiConfig,
      );

      expect(provider, isNotNull);
      expect(provider!.apiKey, 'test-key');
    });

    test('returns null when model is not found', () async {
      when(() => mockAiConfig.getConfigsByType(AiConfigType.model))
          .thenAnswer((_) async => []);

      final provider = await resolveInferenceProvider(
        modelId: 'models/nonexistent',
        aiConfigRepository: mockAiConfig,
      );

      expect(provider, isNull);
    });

    test('returns null when provider is not an inference provider', () async {
      when(() => mockAiConfig.getConfigsByType(AiConfigType.model))
          .thenAnswer((_) async => [testAiModel()]);
      // Return a model config instead of an inference provider.
      when(() => mockAiConfig.getConfigById('provider-1'))
          .thenAnswer((_) async => testAiModel());

      final provider = await resolveInferenceProvider(
        modelId: 'models/gemini-3.1-pro-preview',
        aiConfigRepository: mockAiConfig,
      );

      expect(provider, isNull);
    });

    test('returns null when provider has empty API key', () async {
      stubResolution(apiKey: '');

      final provider = await resolveInferenceProvider(
        modelId: 'models/gemini-3.1-pro-preview',
        aiConfigRepository: mockAiConfig,
      );

      expect(provider, isNull);
    });

    test('accepts custom logTag', () async {
      stubResolution();

      final provider = await resolveInferenceProvider(
        modelId: 'models/gemini-3.1-pro-preview',
        aiConfigRepository: mockAiConfig,
        logTag: 'CustomTag',
      );

      expect(provider, isNotNull);
    });

    test('returns first matching model when multiple exist', () async {
      final model1 = testAiModel(
        id: 'model-a',
        inferenceProviderId: 'provider-a',
      );
      final model2 = testAiModel(
        id: 'model-b',
        inferenceProviderId: 'provider-b',
      );

      when(() => mockAiConfig.getConfigsByType(AiConfigType.model))
          .thenAnswer((_) async => [model1, model2]);
      when(() => mockAiConfig.getConfigById('provider-a'))
          .thenAnswer((_) async => testInferenceProvider(id: 'provider-a'));

      final provider = await resolveInferenceProvider(
        modelId: 'models/gemini-3.1-pro-preview',
        aiConfigRepository: mockAiConfig,
      );

      expect(provider, isNotNull);
      verify(() => mockAiConfig.getConfigById('provider-a')).called(1);
      verifyNever(() => mockAiConfig.getConfigById('provider-b'));
    });
  });
}
