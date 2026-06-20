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
            InferenceProviderType.omlx,
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

      test('should have correct URL for openRouter', () {
        expect(
          ProviderConfig.defaultBaseUrls[InferenceProviderType.openRouter],
          equals('https://openrouter.ai/api/v1'),
        );
      });

      test('should have correct URL for oMLX', () {
        expect(
          ProviderConfig.defaultBaseUrls[InferenceProviderType.omlx],
          equals('http://127.0.0.1:8003/v1'),
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
            InferenceProviderType.omlx,
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

      test('should have correct name for openRouter', () {
        expect(
          ProviderConfig.defaultNames[InferenceProviderType.openRouter],
          equals('OpenRouter'),
        );
      });

      test('should have correct name for oMLX', () {
        expect(
          ProviderConfig.defaultNames[InferenceProviderType.omlx],
          equals('oMLX (local)'),
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
        // oMLX is local but OpenAI-compatible deployments can be key-protected.
        expect(
          ProviderConfig.noApiKeyRequired,
          isNot(contains(InferenceProviderType.omlx)),
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
    });

    group('requiresApiKey', () {
      test('returns false for every keyless provider type', () {
        for (final type in ProviderConfig.noApiKeyRequired) {
          expect(
            ProviderConfig.requiresApiKey(type),
            isFalse,
            reason: '$type is in noApiKeyRequired and must not require a key',
          );
        }
      });

      test('returns true for every other provider type', () {
        for (final type in InferenceProviderType.values) {
          if (!ProviderConfig.noApiKeyRequired.contains(type)) {
            expect(
              ProviderConfig.requiresApiKey(type),
              isTrue,
              reason: '$type is not keyless and must require a key',
            );
          }
        }
      });
    });

    group('usesBaseUrl', () {
      test('returns false only for mlxAudio', () {
        expect(
          ProviderConfig.usesBaseUrl(InferenceProviderType.mlxAudio),
          isFalse,
        );
        for (final type in InferenceProviderType.values) {
          if (type != InferenceProviderType.mlxAudio) {
            expect(
              ProviderConfig.usesBaseUrl(type),
              isTrue,
              reason: '$type talks to an HTTP base URL and must use one',
            );
          }
        }
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
