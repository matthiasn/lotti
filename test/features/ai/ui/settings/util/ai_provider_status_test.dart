import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/util/ai_provider_status.dart';

void main() {
  AiConfigInferenceProvider provider({
    required InferenceProviderType type,
    String apiKey = '',
    String baseUrl = 'http://localhost:11434',
  }) {
    return AiConfig.inferenceProvider(
          id: 'p-1',
          name: 'Provider',
          inferenceProviderType: type,
          apiKey: apiKey,
          baseUrl: baseUrl,
          createdAt: DateTime(2024, 3, 15),
        )
        as AiConfigInferenceProvider;
  }

  group('aiProviderCardStatusFor', () {
    test('cloud provider without key reads invalidKey, with key connected', () {
      // Exhaustive over all cloud (key-requiring) provider types.
      for (final type in InferenceProviderType.values) {
        if (ProviderConfig.noApiKeyRequired.contains(type)) continue;

        expect(
          aiProviderCardStatusFor(
            provider: provider(type: type),
            modelCount: 3,
          ),
          AiProviderCardStatus.invalidKey,
          reason: '$type empty key',
        );
        // Whitespace-only keys are still blank.
        expect(
          aiProviderCardStatusFor(
            provider: provider(type: type, apiKey: '   '),
            modelCount: 3,
          ),
          AiProviderCardStatus.invalidKey,
          reason: '$type blank key',
        );
        expect(
          aiProviderCardStatusFor(
            provider: provider(type: type, apiKey: 'sk-123'),
            modelCount: 0,
          ),
          AiProviderCardStatus.connected,
          reason: '$type with key',
        );
      }
    });

    test('local provider needs a base URL and at least one model', () {
      // Exhaustive over all local (no-key) provider types.
      for (final type in ProviderConfig.noApiKeyRequired) {
        final usesBaseUrl = ProviderConfig.usesBaseUrl(type);

        // Models present + base URL present -> connected (key irrelevant).
        expect(
          aiProviderCardStatusFor(
            provider: provider(type: type),
            modelCount: 2,
          ),
          AiProviderCardStatus.connected,
          reason: '$type with models',
        );

        // No model rows -> offline regardless of base URL.
        expect(
          aiProviderCardStatusFor(
            provider: provider(type: type),
            modelCount: 0,
          ),
          AiProviderCardStatus.offline,
          reason: '$type no models',
        );

        // Blank base URL -> offline, but only for types that use one.
        expect(
          aiProviderCardStatusFor(
            provider: provider(type: type, baseUrl: '  '),
            modelCount: 2,
          ),
          usesBaseUrl
              ? AiProviderCardStatus.offline
              : AiProviderCardStatus.connected,
          reason: '$type blank baseUrl',
        );

        // Local providers never read invalidKey, even with a key set.
        expect(
          aiProviderCardStatusFor(
            provider: provider(type: type, apiKey: 'ignored'),
            modelCount: 0,
          ),
          AiProviderCardStatus.offline,
          reason: '$type never invalidKey',
        );
      }
    });
  });
}
