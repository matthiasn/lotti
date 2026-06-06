import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

void main() {
  group('ProviderConfig', () {
    group('defaultBaseUrls', () {
      test('should contain all provider types', () {
        expect(
          ProviderConfig.defaultBaseUrls.keys.toSet(),
          containsAll([
            InferenceProviderType.alibaba,
            InferenceProviderType.gemini,
            InferenceProviderType.genericOpenAi,
            InferenceProviderType.mistral,
            InferenceProviderType.mlxAudio,
            InferenceProviderType.nebiusAiStudio,
            InferenceProviderType.ollama,
            InferenceProviderType.openAi,
            InferenceProviderType.anthropic,
            InferenceProviderType.openRouter,
            InferenceProviderType.whisper,
            InferenceProviderType.voxtral,
          ]),
        );
      });

      test('should have valid URLs', () {
        for (final entry in ProviderConfig.defaultBaseUrls.entries) {
          if (ProviderConfig.usesBaseUrl(entry.key)) {
            expect(
              entry.value,
              isNotEmpty,
              reason: '${entry.key} should have a non-empty URL',
            );
          } else {
            expect(
              entry.value,
              isEmpty,
              reason: '${entry.key} is embedded and should not use Base URL',
            );
          }
        }
      });

      test('should have correct URL for alibaba', () {
        expect(
          ProviderConfig.defaultBaseUrls[InferenceProviderType.alibaba],
          equals('https://dashscope-intl.aliyuncs.com/compatible-mode/v1'),
        );
      });

      test('should have correct URL for genericOpenAi', () {
        expect(
          ProviderConfig.defaultBaseUrls[InferenceProviderType.genericOpenAi],
          equals('http://localhost:8002/v1'),
        );
      });
    });

    group('defaultNames', () {
      test('should contain all provider types', () {
        expect(
          ProviderConfig.defaultNames.keys.toSet(),
          containsAll([
            InferenceProviderType.alibaba,
            InferenceProviderType.gemini,
            InferenceProviderType.genericOpenAi,
            InferenceProviderType.mistral,
            InferenceProviderType.mlxAudio,
            InferenceProviderType.nebiusAiStudio,
            InferenceProviderType.ollama,
            InferenceProviderType.openAi,
            InferenceProviderType.anthropic,
            InferenceProviderType.openRouter,
            InferenceProviderType.whisper,
            InferenceProviderType.voxtral,
          ]),
        );
      });

      test('should have non-empty names', () {
        for (final entry in ProviderConfig.defaultNames.entries) {
          expect(
            entry.value,
            isNotEmpty,
            reason: '${entry.key} should have a non-empty name',
          );
        }
      });

      test('should have correct name for alibaba', () {
        expect(
          ProviderConfig.defaultNames[InferenceProviderType.alibaba],
          equals('Alibaba Cloud (Qwen)'),
        );
      });

      test('should have correct name for genericOpenAi', () {
        expect(
          ProviderConfig.defaultNames[InferenceProviderType.genericOpenAi],
          equals('AI Proxy (local)'),
        );
      });
    });

    group('noApiKeyRequired', () {
      test('should include local providers', () {
        expect(
          ProviderConfig.noApiKeyRequired,
          containsAll([
            InferenceProviderType.ollama,
            InferenceProviderType.mlxAudio,
            InferenceProviderType.whisper,
            InferenceProviderType.voxtral,
          ]),
        );
      });

      test('should not include cloud providers or genericOpenAi', () {
        expect(
          ProviderConfig.noApiKeyRequired,
          isNot(contains(InferenceProviderType.alibaba)),
        );
        expect(
          ProviderConfig.noApiKeyRequired,
          isNot(contains(InferenceProviderType.gemini)),
        );
        expect(
          ProviderConfig.noApiKeyRequired,
          isNot(contains(InferenceProviderType.openAi)),
        );
        expect(
          ProviderConfig.noApiKeyRequired,
          isNot(contains(InferenceProviderType.anthropic)),
        );
        // genericOpenAi (OpenAI Compatible) requires API key for authentication
        expect(
          ProviderConfig.noApiKeyRequired,
          isNot(contains(InferenceProviderType.genericOpenAi)),
        );
      });

      test('genericOpenAi should require API key', () {
        expect(
          ProviderConfig.noApiKeyRequired.contains(
            InferenceProviderType.genericOpenAi,
          ),
          isFalse,
        );
      });
    });

    group('getDefaultBaseUrl', () {
      test('should return correct URL for existing provider', () {
        expect(
          ProviderConfig.getDefaultBaseUrl(InferenceProviderType.genericOpenAi),
          equals('http://localhost:8002/v1'),
        );
        expect(
          ProviderConfig.getDefaultBaseUrl(InferenceProviderType.gemini),
          equals('https://generativelanguage.googleapis.com/v1beta/openai'),
        );
      });

      test('should return empty string for unknown provider', () {
        // This tests the null-safety fallback behavior
        // We can't create an invalid enum value, so we test the default behavior
        expect(
          ProviderConfig.defaultBaseUrls[null] ?? '',
          equals(''),
        );
      });
    });

    group('getDefaultName', () {
      test('should return correct name for existing provider', () {
        expect(
          ProviderConfig.getDefaultName(InferenceProviderType.genericOpenAi),
          equals('AI Proxy (local)'),
        );
        expect(
          ProviderConfig.getDefaultName(InferenceProviderType.gemini),
          equals('Gemini'),
        );
      });

      test('should return empty string for unknown provider', () {
        expect(
          ProviderConfig.defaultNames[null] ?? '',
          equals(''),
        );
      });
    });

    group('requiresApiKey', () {
      test('should return false for local providers', () {
        expect(
          ProviderConfig.requiresApiKey(InferenceProviderType.ollama),
          isFalse,
        );
        expect(
          ProviderConfig.requiresApiKey(InferenceProviderType.voxtral),
          isFalse,
        );
        expect(
          ProviderConfig.requiresApiKey(InferenceProviderType.whisper),
          isFalse,
        );
        expect(
          ProviderConfig.requiresApiKey(InferenceProviderType.mlxAudio),
          isFalse,
        );
      });

      test('should return true for cloud providers and genericOpenAi', () {
        expect(
          ProviderConfig.requiresApiKey(InferenceProviderType.alibaba),
          isTrue,
        );
        expect(
          ProviderConfig.requiresApiKey(InferenceProviderType.gemini),
          isTrue,
        );
        expect(
          ProviderConfig.requiresApiKey(InferenceProviderType.openAi),
          isTrue,
        );
        expect(
          ProviderConfig.requiresApiKey(InferenceProviderType.anthropic),
          isTrue,
        );
        // genericOpenAi (OpenAI Compatible) requires API key for authentication
        expect(
          ProviderConfig.requiresApiKey(InferenceProviderType.genericOpenAi),
          isTrue,
        );
      });
    });
  });

  group('AiConfigInferenceProviderUsability.isUsable', () {
    AiConfigInferenceProvider provider({
      required InferenceProviderType type,
      required String apiKey,
      required String baseUrl,
    }) =>
        AiConfig.inferenceProvider(
              id: 'p-1',
              name: 'Provider',
              apiKey: apiKey,
              baseUrl: baseUrl,
              createdAt: DateTime(2024, 3, 15),
              inferenceProviderType: type,
            )
            as AiConfigInferenceProvider;

    test('a non-empty API key makes any provider usable', () {
      expect(
        provider(
          type: InferenceProviderType.genericOpenAi,
          apiKey: 'sk-123',
          baseUrl: '',
        ).isUsable,
        isTrue,
      );
    });

    test('a keyless local provider needs its base URL set', () {
      expect(
        provider(
          type: InferenceProviderType.ollama,
          apiKey: '',
          baseUrl: 'http://localhost:11434',
        ).isUsable,
        isTrue,
      );
      // Cleared base URL -> cannot connect -> not usable.
      expect(
        provider(
          type: InferenceProviderType.ollama,
          apiKey: '  ',
          baseUrl: '   ',
        ).isUsable,
        isFalse,
      );
    });

    test('mlxAudio needs neither key nor base URL', () {
      expect(
        provider(
          type: InferenceProviderType.mlxAudio,
          apiKey: '',
          baseUrl: '',
        ).isUsable,
        isTrue,
      );
    });

    test('a key-requiring provider without a key is unusable', () {
      expect(
        provider(
          type: InferenceProviderType.genericOpenAi,
          apiKey: '   ',
          baseUrl: 'https://api.example.com/v1',
        ).isUsable,
        isFalse,
      );
    });
  });
}
