import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/ui/settings/services/ftue_trigger_service.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

void main() {
  late MockAiConfigRepository mockRepository;

  setUp(() {
    mockRepository = MockAiConfigRepository();
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  AiConfigInferenceProvider createProvider({
    required String id,
    required InferenceProviderType type,
    String name = 'Test Provider',
  }) {
    return AiConfig.inferenceProvider(
      id: id,
      name: name,
      baseUrl: 'https://api.test.com',
      apiKey: 'test-key',
      createdAt: DateTime(2024),
      inferenceProviderType: type,
    ) as AiConfigInferenceProvider;
  }

  group('FtueTriggerService', () {
    group('isFtueSupported', () {
      test('returns true for Gemini provider type', () {
        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        expect(service.isFtueSupported(InferenceProviderType.gemini), isTrue);
      });

      test('returns true for OpenAI provider type', () {
        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        expect(service.isFtueSupported(InferenceProviderType.openAi), isTrue);
      });

      test('returns true for Mistral provider type', () {
        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        expect(service.isFtueSupported(InferenceProviderType.mistral), isTrue);
      });

      test('returns false for Ollama provider type', () {
        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        expect(service.isFtueSupported(InferenceProviderType.ollama), isFalse);
      });

      test('returns false for Anthropic provider type', () {
        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        expect(
            service.isFtueSupported(InferenceProviderType.anthropic), isFalse);
      });

      test('returns false for genericOpenAi provider type', () {
        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        expect(service.isFtueSupported(InferenceProviderType.genericOpenAi),
            isFalse);
      });

      test('returns false for Whisper provider type', () {
        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        expect(service.isFtueSupported(InferenceProviderType.whisper), isFalse);
      });

      test('returns false for Voxtral provider type', () {
        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        expect(service.isFtueSupported(InferenceProviderType.voxtral), isFalse);
      });

      test('returns false for NebiusAiStudio provider type', () {
        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        expect(service.isFtueSupported(InferenceProviderType.nebiusAiStudio),
            isFalse);
      });

      test('returns false for OpenRouter provider type', () {
        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        expect(
            service.isFtueSupported(InferenceProviderType.openRouter), isFalse);
      });
    });

    group('shouldTriggerFtue', () {
      test(
          'returns shouldShowFtue when Gemini provider is first of its type (count == 1)',
          () async {
        final provider = createProvider(
          id: 'gemini-1',
          type: InferenceProviderType.gemini,
        );

        // After saving, there's exactly 1 Gemini provider
        when(() =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [provider]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final result = await service.shouldTriggerFtue(provider);

        expect(result, equals(FtueTriggerResult.shouldShowFtue));
      });

      test(
          'returns shouldShowFtue when OpenAI provider is first of its type (count == 1)',
          () async {
        final provider = createProvider(
          id: 'openai-1',
          type: InferenceProviderType.openAi,
        );

        when(() =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [provider]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final result = await service.shouldTriggerFtue(provider);

        expect(result, equals(FtueTriggerResult.shouldShowFtue));
      });

      test(
          'returns shouldShowFtue when Mistral provider is first of its type (count == 1)',
          () async {
        final provider = createProvider(
          id: 'mistral-1',
          type: InferenceProviderType.mistral,
        );

        when(() =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [provider]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final result = await service.shouldTriggerFtue(provider);

        expect(result, equals(FtueTriggerResult.shouldShowFtue));
      });

      test(
          'returns shouldShowFtue when adding first Mistral provider but Gemini already exists',
          () async {
        final existingGemini = createProvider(
          id: 'gemini-1',
          type: InferenceProviderType.gemini,
        );
        final newMistral = createProvider(
          id: 'mistral-1',
          type: InferenceProviderType.mistral,
        );

        // Both providers exist, but only 1 Mistral
        when(() =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [existingGemini, newMistral]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final result = await service.shouldTriggerFtue(newMistral);

        expect(result, equals(FtueTriggerResult.shouldShowFtue));
      });

      test(
          'returns skipNotFirstProvider when Gemini provider is second of its type (count == 2)',
          () async {
        final existingGemini = createProvider(
          id: 'gemini-1',
          type: InferenceProviderType.gemini,
        );
        final newGemini = createProvider(
          id: 'gemini-2',
          type: InferenceProviderType.gemini,
        );

        // Both Gemini providers exist
        when(() =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [existingGemini, newGemini]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final result = await service.shouldTriggerFtue(newGemini);

        expect(result, equals(FtueTriggerResult.skipNotFirstProvider));
      });

      test(
          'returns skipNotFirstProvider when OpenAI provider is third of its type (count == 3)',
          () async {
        final openai1 = createProvider(
          id: 'openai-1',
          type: InferenceProviderType.openAi,
        );
        final openai2 = createProvider(
          id: 'openai-2',
          type: InferenceProviderType.openAi,
        );
        final openai3 = createProvider(
          id: 'openai-3',
          type: InferenceProviderType.openAi,
        );

        when(() =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [openai1, openai2, openai3]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final result = await service.shouldTriggerFtue(openai3);

        expect(result, equals(FtueTriggerResult.skipNotFirstProvider));
      });

      test('returns skipUnsupportedProvider for Ollama provider', () async {
        final provider = createProvider(
          id: 'ollama-1',
          type: InferenceProviderType.ollama,
        );

        // Even if it's the only one, unsupported provider types skip FTUE
        when(() =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [provider]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final result = await service.shouldTriggerFtue(provider);

        expect(result, equals(FtueTriggerResult.skipUnsupportedProvider));
      });

      test('returns skipUnsupportedProvider for Anthropic provider', () async {
        final provider = createProvider(
          id: 'anthropic-1',
          type: InferenceProviderType.anthropic,
        );

        when(() =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [provider]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final result = await service.shouldTriggerFtue(provider);

        expect(result, equals(FtueTriggerResult.skipUnsupportedProvider));
      });

      test('returns skipUnsupportedProvider for genericOpenAi provider',
          () async {
        final provider = createProvider(
          id: 'generic-1',
          type: InferenceProviderType.genericOpenAi,
        );

        when(() =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [provider]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final result = await service.shouldTriggerFtue(provider);

        expect(result, equals(FtueTriggerResult.skipUnsupportedProvider));
      });

      test('returns skipUnsupportedProvider for Whisper provider', () async {
        final provider = createProvider(
          id: 'whisper-1',
          type: InferenceProviderType.whisper,
        );

        when(() =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [provider]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final result = await service.shouldTriggerFtue(provider);

        expect(result, equals(FtueTriggerResult.skipUnsupportedProvider));
      });

      test('returns skipUnsupportedProvider for Voxtral provider', () async {
        final provider = createProvider(
          id: 'voxtral-1',
          type: InferenceProviderType.voxtral,
        );

        when(() =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [provider]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final result = await service.shouldTriggerFtue(provider);

        expect(result, equals(FtueTriggerResult.skipUnsupportedProvider));
      });

      test('returns skipUnsupportedProvider for NebiusAiStudio provider',
          () async {
        final provider = createProvider(
          id: 'nebius-1',
          type: InferenceProviderType.nebiusAiStudio,
        );

        when(() =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [provider]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final result = await service.shouldTriggerFtue(provider);

        expect(result, equals(FtueTriggerResult.skipUnsupportedProvider));
      });

      test('returns skipUnsupportedProvider for OpenRouter provider', () async {
        final provider = createProvider(
          id: 'openrouter-1',
          type: InferenceProviderType.openRouter,
        );

        when(() =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [provider]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final result = await service.shouldTriggerFtue(provider);

        expect(result, equals(FtueTriggerResult.skipUnsupportedProvider));
      });
    });

    group('getProviderCountByType', () {
      test('returns 0 when no providers exist', () async {
        when(() =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => []);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final count =
            await service.getProviderCountByType(InferenceProviderType.gemini);

        expect(count, equals(0));
      });

      test('returns 0 when only other provider types exist', () async {
        final openAiProvider = createProvider(
          id: 'openai-1',
          type: InferenceProviderType.openAi,
        );

        when(() =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [openAiProvider]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final count =
            await service.getProviderCountByType(InferenceProviderType.gemini);

        expect(count, equals(0));
      });

      test('returns 1 when one provider of the type exists', () async {
        final geminiProvider = createProvider(
          id: 'gemini-1',
          type: InferenceProviderType.gemini,
        );

        when(() =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [geminiProvider]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final count =
            await service.getProviderCountByType(InferenceProviderType.gemini);

        expect(count, equals(1));
      });

      test('returns correct count when multiple providers exist', () async {
        final gemini1 = createProvider(
          id: 'gemini-1',
          type: InferenceProviderType.gemini,
        );
        final gemini2 = createProvider(
          id: 'gemini-2',
          type: InferenceProviderType.gemini,
        );
        final openAi = createProvider(
          id: 'openai-1',
          type: InferenceProviderType.openAi,
        );
        final mistral = createProvider(
          id: 'mistral-1',
          type: InferenceProviderType.mistral,
        );

        when(() =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [gemini1, gemini2, openAi, mistral]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        expect(
          await service.getProviderCountByType(InferenceProviderType.gemini),
          equals(2),
        );
        expect(
          await service.getProviderCountByType(InferenceProviderType.openAi),
          equals(1),
        );
        expect(
          await service.getProviderCountByType(InferenceProviderType.mistral),
          equals(1),
        );
        expect(
          await service.getProviderCountByType(InferenceProviderType.ollama),
          equals(0),
        );
      });
    });

    group('isFirstProviderOfType', () {
      test('returns true when no providers of the type exist', () async {
        when(() =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => []);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final isFirst =
            await service.isFirstProviderOfType(InferenceProviderType.gemini);

        expect(isFirst, isTrue);
      });

      test('returns true when only other provider types exist', () async {
        final openAiProvider = createProvider(
          id: 'openai-1',
          type: InferenceProviderType.openAi,
        );

        when(() =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [openAiProvider]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final isFirst =
            await service.isFirstProviderOfType(InferenceProviderType.gemini);

        expect(isFirst, isTrue);
      });

      test('returns false when a provider of the type already exists',
          () async {
        final geminiProvider = createProvider(
          id: 'gemini-1',
          type: InferenceProviderType.gemini,
        );

        when(() =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [geminiProvider]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final isFirst =
            await service.isFirstProviderOfType(InferenceProviderType.gemini);

        expect(isFirst, isFalse);
      });

      test('returns false when multiple providers of the type exist', () async {
        final gemini1 = createProvider(
          id: 'gemini-1',
          type: InferenceProviderType.gemini,
        );
        final gemini2 = createProvider(
          id: 'gemini-2',
          type: InferenceProviderType.gemini,
        );

        when(() =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => [gemini1, gemini2]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final isFirst =
            await service.isFirstProviderOfType(InferenceProviderType.gemini);

        expect(isFirst, isFalse);
      });
    });

    group('ftueSupportedProviderTypes constant', () {
      test('contains exactly 3 supported provider types', () {
        expect(ftueSupportedProviderTypes.length, equals(3));
      });

      test('contains Gemini, OpenAI, and Mistral', () {
        expect(
            ftueSupportedProviderTypes, contains(InferenceProviderType.gemini));
        expect(
            ftueSupportedProviderTypes, contains(InferenceProviderType.openAi));
        expect(ftueSupportedProviderTypes,
            contains(InferenceProviderType.mistral));
      });

      test('does not contain unsupported types', () {
        expect(ftueSupportedProviderTypes,
            isNot(contains(InferenceProviderType.ollama)));
        expect(ftueSupportedProviderTypes,
            isNot(contains(InferenceProviderType.anthropic)));
        expect(ftueSupportedProviderTypes,
            isNot(contains(InferenceProviderType.genericOpenAi)));
        expect(ftueSupportedProviderTypes,
            isNot(contains(InferenceProviderType.whisper)));
        expect(ftueSupportedProviderTypes,
            isNot(contains(InferenceProviderType.voxtral)));
        expect(ftueSupportedProviderTypes,
            isNot(contains(InferenceProviderType.nebiusAiStudio)));
        expect(ftueSupportedProviderTypes,
            isNot(contains(InferenceProviderType.openRouter)));
      });
    });

    group('FtueProviderTypeExtension.ftueDisplayName', () {
      test('returns Gemini for gemini provider type', () {
        expect(InferenceProviderType.gemini.ftueDisplayName, equals('Gemini'));
      });

      test('returns OpenAI for openAi provider type', () {
        expect(InferenceProviderType.openAi.ftueDisplayName, equals('OpenAI'));
      });

      test('returns Mistral for mistral provider type', () {
        expect(
            InferenceProviderType.mistral.ftueDisplayName, equals('Mistral'));
      });

      test('returns null for ollama provider type', () {
        expect(InferenceProviderType.ollama.ftueDisplayName, isNull);
      });

      test('returns null for anthropic provider type', () {
        expect(InferenceProviderType.anthropic.ftueDisplayName, isNull);
      });

      test('returns null for genericOpenAi provider type', () {
        expect(InferenceProviderType.genericOpenAi.ftueDisplayName, isNull);
      });

      test('returns null for whisper provider type', () {
        expect(InferenceProviderType.whisper.ftueDisplayName, isNull);
      });

      test('returns null for voxtral provider type', () {
        expect(InferenceProviderType.voxtral.ftueDisplayName, isNull);
      });

      test('returns null for nebiusAiStudio provider type', () {
        expect(InferenceProviderType.nebiusAiStudio.ftueDisplayName, isNull);
      });

      test('returns null for openRouter provider type', () {
        expect(InferenceProviderType.openRouter.ftueDisplayName, isNull);
      });
    });
  });
}
