import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    show aiConfigRepositoryProvider;
import 'package:lotti/features/ai/ui/settings/services/ftue_trigger_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';

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
        )
        as AiConfigInferenceProvider;
  }

  group('FtueTriggerService', () {
    group('isFtueSupported', () {
      // Exhaustive over the enum: any newly added provider type must be
      // classified here explicitly.
      const supported = {
        InferenceProviderType.gemini,
        InferenceProviderType.openAi,
        InferenceProviderType.mistral,
        InferenceProviderType.alibaba,
        InferenceProviderType.ollama,
        InferenceProviderType.anthropic,
      };

      test('classifies every provider type', () {
        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        for (final type in InferenceProviderType.values) {
          expect(
            service.isFtueSupported(type),
            supported.contains(type),
            reason: '$type',
          );
        }
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
          when(
            () =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
          ).thenAnswer((_) async => [provider]);

          final container = createContainer();
          final service = container.read(ftueTriggerServiceProvider.notifier);

          final result = await service.shouldTriggerFtue(provider);

          expect(result, equals(FtueTriggerResult.shouldShowFtue));
        },
      );

      test(
        'returns shouldShowFtue when OpenAI provider is first of its type (count == 1)',
        () async {
          final provider = createProvider(
            id: 'openai-1',
            type: InferenceProviderType.openAi,
          );

          when(
            () =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
          ).thenAnswer((_) async => [provider]);

          final container = createContainer();
          final service = container.read(ftueTriggerServiceProvider.notifier);

          final result = await service.shouldTriggerFtue(provider);

          expect(result, equals(FtueTriggerResult.shouldShowFtue));
        },
      );

      test(
        'returns shouldShowFtue when Mistral provider is first of its type (count == 1)',
        () async {
          final provider = createProvider(
            id: 'mistral-1',
            type: InferenceProviderType.mistral,
          );

          when(
            () =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
          ).thenAnswer((_) async => [provider]);

          final container = createContainer();
          final service = container.read(ftueTriggerServiceProvider.notifier);

          final result = await service.shouldTriggerFtue(provider);

          expect(result, equals(FtueTriggerResult.shouldShowFtue));
        },
      );

      test(
        'returns shouldShowFtue when Alibaba provider is first of its type (count == 1)',
        () async {
          final provider = createProvider(
            id: 'alibaba-1',
            type: InferenceProviderType.alibaba,
          );

          when(
            () =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
          ).thenAnswer((_) async => [provider]);

          final container = createContainer();
          final service = container.read(ftueTriggerServiceProvider.notifier);

          final result = await service.shouldTriggerFtue(provider);

          expect(result, equals(FtueTriggerResult.shouldShowFtue));
        },
      );

      test(
        'returns skipNotFirstProvider when Alibaba provider is second of its type',
        () async {
          final alibaba1 = createProvider(
            id: 'alibaba-1',
            type: InferenceProviderType.alibaba,
          );
          final alibaba2 = createProvider(
            id: 'alibaba-2',
            type: InferenceProviderType.alibaba,
          );

          when(
            () =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
          ).thenAnswer((_) async => [alibaba1, alibaba2]);

          final container = createContainer();
          final service = container.read(ftueTriggerServiceProvider.notifier);

          final result = await service.shouldTriggerFtue(alibaba2);

          expect(result, equals(FtueTriggerResult.skipNotFirstProvider));
        },
      );

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
          when(
            () =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
          ).thenAnswer((_) async => [existingGemini, newMistral]);

          final container = createContainer();
          final service = container.read(ftueTriggerServiceProvider.notifier);

          final result = await service.shouldTriggerFtue(newMistral);

          expect(result, equals(FtueTriggerResult.shouldShowFtue));
        },
      );

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
          when(
            () =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
          ).thenAnswer((_) async => [existingGemini, newGemini]);

          final container = createContainer();
          final service = container.read(ftueTriggerServiceProvider.notifier);

          final result = await service.shouldTriggerFtue(newGemini);

          expect(result, equals(FtueTriggerResult.skipNotFirstProvider));
        },
      );

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

          when(
            () =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
          ).thenAnswer((_) async => [openai1, openai2, openai3]);

          final container = createContainer();
          final service = container.read(ftueTriggerServiceProvider.notifier);

          final result = await service.shouldTriggerFtue(openai3);

          expect(result, equals(FtueTriggerResult.skipNotFirstProvider));
        },
      );

      test(
        'returns shouldShowFtue when Ollama provider is first of its type',
        () async {
          final provider = createProvider(
            id: 'ollama-1',
            type: InferenceProviderType.ollama,
          );

          when(
            () =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
          ).thenAnswer((_) async => [provider]);

          final container = createContainer();
          final service = container.read(ftueTriggerServiceProvider.notifier);

          final result = await service.shouldTriggerFtue(provider);

          expect(result, equals(FtueTriggerResult.shouldShowFtue));
        },
      );

      test(
        'returns shouldShowFtue when Anthropic provider is first of its type',
        () async {
          final provider = createProvider(
            id: 'anthropic-1',
            type: InferenceProviderType.anthropic,
          );

          when(
            () =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
          ).thenAnswer((_) async => [provider]);

          final container = createContainer();
          final service = container.read(ftueTriggerServiceProvider.notifier);

          final result = await service.shouldTriggerFtue(provider);

          expect(result, equals(FtueTriggerResult.shouldShowFtue));
        },
      );

      test(
        'returns skipUnsupportedProvider for genericOpenAi provider',
        () async {
          final provider = createProvider(
            id: 'generic-1',
            type: InferenceProviderType.genericOpenAi,
          );

          when(
            () =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
          ).thenAnswer((_) async => [provider]);

          final container = createContainer();
          final service = container.read(ftueTriggerServiceProvider.notifier);

          final result = await service.shouldTriggerFtue(provider);

          expect(result, equals(FtueTriggerResult.skipUnsupportedProvider));
        },
      );

      test('returns skipUnsupportedProvider for Whisper provider', () async {
        final provider = createProvider(
          id: 'whisper-1',
          type: InferenceProviderType.whisper,
        );

        when(
          () => mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
        ).thenAnswer((_) async => [provider]);

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

        when(
          () => mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
        ).thenAnswer((_) async => [provider]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final result = await service.shouldTriggerFtue(provider);

        expect(result, equals(FtueTriggerResult.skipUnsupportedProvider));
      });

      test(
        'returns skipUnsupportedProvider for NebiusAiStudio provider',
        () async {
          final provider = createProvider(
            id: 'nebius-1',
            type: InferenceProviderType.nebiusAiStudio,
          );

          when(
            () =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
          ).thenAnswer((_) async => [provider]);

          final container = createContainer();
          final service = container.read(ftueTriggerServiceProvider.notifier);

          final result = await service.shouldTriggerFtue(provider);

          expect(result, equals(FtueTriggerResult.skipUnsupportedProvider));
        },
      );

      test('returns skipUnsupportedProvider for OpenRouter provider', () async {
        final provider = createProvider(
          id: 'openrouter-1',
          type: InferenceProviderType.openRouter,
        );

        when(
          () => mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
        ).thenAnswer((_) async => [provider]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final result = await service.shouldTriggerFtue(provider);

        expect(result, equals(FtueTriggerResult.skipUnsupportedProvider));
      });
    });

    group('getProviderCountByType', () {
      test('returns 0 when no providers exist', () async {
        when(
          () => mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
        ).thenAnswer((_) async => []);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final count = await service.getProviderCountByType(
          InferenceProviderType.gemini,
        );

        expect(count, equals(0));
      });

      test('returns 0 when only other provider types exist', () async {
        final openAiProvider = createProvider(
          id: 'openai-1',
          type: InferenceProviderType.openAi,
        );

        when(
          () => mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
        ).thenAnswer((_) async => [openAiProvider]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final count = await service.getProviderCountByType(
          InferenceProviderType.gemini,
        );

        expect(count, equals(0));
      });

      test('returns 1 when one provider of the type exists', () async {
        final geminiProvider = createProvider(
          id: 'gemini-1',
          type: InferenceProviderType.gemini,
        );

        when(
          () => mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
        ).thenAnswer((_) async => [geminiProvider]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final count = await service.getProviderCountByType(
          InferenceProviderType.gemini,
        );

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

        when(
          () => mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
        ).thenAnswer((_) async => [gemini1, gemini2, openAi, mistral]);

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
        when(
          () => mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
        ).thenAnswer((_) async => []);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final isFirst = await service.isFirstProviderOfType(
          InferenceProviderType.gemini,
        );

        expect(isFirst, isTrue);
      });

      test('returns true when only other provider types exist', () async {
        final openAiProvider = createProvider(
          id: 'openai-1',
          type: InferenceProviderType.openAi,
        );

        when(
          () => mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
        ).thenAnswer((_) async => [openAiProvider]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final isFirst = await service.isFirstProviderOfType(
          InferenceProviderType.gemini,
        );

        expect(isFirst, isTrue);
      });

      test(
        'returns false when a provider of the type already exists',
        () async {
          final geminiProvider = createProvider(
            id: 'gemini-1',
            type: InferenceProviderType.gemini,
          );

          when(
            () =>
                mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
          ).thenAnswer((_) async => [geminiProvider]);

          final container = createContainer();
          final service = container.read(ftueTriggerServiceProvider.notifier);

          final isFirst = await service.isFirstProviderOfType(
            InferenceProviderType.gemini,
          );

          expect(isFirst, isFalse);
        },
      );

      test('returns false when multiple providers of the type exist', () async {
        final gemini1 = createProvider(
          id: 'gemini-1',
          type: InferenceProviderType.gemini,
        );
        final gemini2 = createProvider(
          id: 'gemini-2',
          type: InferenceProviderType.gemini,
        );

        when(
          () => mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
        ).thenAnswer((_) async => [gemini1, gemini2]);

        final container = createContainer();
        final service = container.read(ftueTriggerServiceProvider.notifier);

        final isFirst = await service.isFirstProviderOfType(
          InferenceProviderType.gemini,
        );

        expect(isFirst, isFalse);
      });
    });

    group('ftueSupportedProviderTypes constant', () {
      test('contains exactly 6 supported provider types', () {
        expect(ftueSupportedProviderTypes.length, equals(6));
      });

      test(
        'contains Alibaba, Anthropic, Gemini, Mistral, Ollama, and OpenAI',
        () {
          for (final type in const [
            InferenceProviderType.alibaba,
            InferenceProviderType.anthropic,
            InferenceProviderType.gemini,
            InferenceProviderType.mistral,
            InferenceProviderType.ollama,
            InferenceProviderType.openAi,
          ]) {
            expect(ftueSupportedProviderTypes, contains(type));
          }
        },
      );

      test('does not contain unsupported types', () {
        for (final type in const [
          InferenceProviderType.genericOpenAi,
          InferenceProviderType.melious,
          InferenceProviderType.mlxAudio,
          InferenceProviderType.omlx,
          InferenceProviderType.whisper,
          InferenceProviderType.voxtral,
          InferenceProviderType.nebiusAiStudio,
          InferenceProviderType.openRouter,
        ]) {
          expect(ftueSupportedProviderTypes, isNot(contains(type)));
        }
      });
    });

    group('FtueProviderTypeExtension.ftueDisplayName', () {
      // Exhaustive over the enum: unsupported types map to null.
      const displayNames = {
        InferenceProviderType.gemini: 'Gemini',
        InferenceProviderType.openAi: 'OpenAI',
        InferenceProviderType.mistral: 'Mistral',
        InferenceProviderType.alibaba: 'Alibaba Cloud (Qwen)',
        InferenceProviderType.ollama: 'Ollama (local)',
        InferenceProviderType.anthropic: 'Anthropic',
      };

      test('maps every provider type to its display name or null', () {
        for (final type in InferenceProviderType.values) {
          expect(
            type.ftueDisplayName,
            displayNames[type],
            reason: '$type',
          );
        }
      });
    });
  });
}
