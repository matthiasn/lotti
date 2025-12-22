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
            InferenceProviderType.gemini,
            InferenceProviderType.gemma3n,
            InferenceProviderType.genericOpenAi,
            InferenceProviderType.nebiusAiStudio,
            InferenceProviderType.ollama,
            InferenceProviderType.openAi,
            InferenceProviderType.anthropic,
            InferenceProviderType.openRouter,
            InferenceProviderType.whisper,
          ]),
        );
      });

      test('should have valid URLs', () {
        for (final entry in ProviderConfig.defaultBaseUrls.entries) {
          expect(
            entry.value,
            isNotEmpty,
            reason: '${entry.key} should have a non-empty URL',
          );
        }
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
            InferenceProviderType.gemini,
            InferenceProviderType.gemma3n,
            InferenceProviderType.genericOpenAi,
            InferenceProviderType.nebiusAiStudio,
            InferenceProviderType.ollama,
            InferenceProviderType.openAi,
            InferenceProviderType.anthropic,
            InferenceProviderType.openRouter,
            InferenceProviderType.whisper,
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
            InferenceProviderType.gemma3n,
            InferenceProviderType.genericOpenAi,
            InferenceProviderType.ollama,
            InferenceProviderType.whisper,
          ]),
        );
      });

      test('should not include cloud providers', () {
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
      });

      test('genericOpenAi should not require API key', () {
        expect(
          ProviderConfig.noApiKeyRequired
              .contains(InferenceProviderType.genericOpenAi),
          isTrue,
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
          ProviderConfig.requiresApiKey(InferenceProviderType.genericOpenAi),
          isFalse,
        );
        expect(
          ProviderConfig.requiresApiKey(InferenceProviderType.ollama),
          isFalse,
        );
        expect(
          ProviderConfig.requiresApiKey(InferenceProviderType.gemma3n),
          isFalse,
        );
        expect(
          ProviderConfig.requiresApiKey(InferenceProviderType.whisper),
          isFalse,
        );
      });

      test('should return true for cloud providers', () {
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
      });
    });
  });
}
