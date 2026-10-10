import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_rules.dart';

void main() {
  final created = DateTime(2024, 3, 15, 12);

  AiConfigInferenceProvider provider({
    String id = 'provider-1',
    String apiKey = '',
    String baseUrl = 'https://api.example.com',
    InferenceProviderType type = InferenceProviderType.genericOpenAi,
    bool apiKeyCleared = false,
    DateTime? deletedAt,
  }) =>
      AiConfig.inferenceProvider(
            id: id,
            baseUrl: baseUrl,
            apiKey: apiKey,
            name: 'Provider',
            createdAt: created,
            inferenceProviderType: type,
            apiKeyCleared: apiKeyCleared,
            deletedAt: deletedAt,
          )
          as AiConfigInferenceProvider;

  AiConfig model({String providerId = 'provider-1'}) => AiConfig.model(
    id: 'model-1',
    name: 'Model',
    providerModelId: 'vendor/model',
    inferenceProviderId: providerId,
    createdAt: created,
    inputModalities: const [Modality.text],
    outputModalities: const [Modality.text],
    isReasoningModel: false,
  );

  group('aiConfigTypeOf', () {
    test('files each kind of configuration under its own type', () {
      expect(aiConfigTypeOf(provider()), AiConfigType.inferenceProvider);
      expect(aiConfigTypeOf(model()), AiConfigType.model);
    });
  });

  group('withKeptApiKey', () {
    final held = provider(apiKey: 'held-key');

    test('a keyless version of the same endpoint keeps the key held here', () {
      final kept = withKeptApiKey(provider(), held);

      expect((kept as AiConfigInferenceProvider).apiKey, 'held-key');
    });

    test(
      'the endpoint compares without trailing slash, space or host case',
      () {
        final kept = withKeptApiKey(
          provider(baseUrl: ' HTTPS://API.example.com// '),
          held,
        );

        expect((kept as AiConfigInferenceProvider).apiKey, 'held-key');
      },
    );

    test('a key cleared on purpose is not put back', () {
      final incoming = provider(apiKeyCleared: true);

      expect(withKeptApiKey(incoming, held), same(incoming));
    });

    test('a version pointing elsewhere does not take the held key', () {
      final elsewhere = provider(baseUrl: 'https://collector.example.net');
      final otherKind = provider(type: InferenceProviderType.anthropic);

      expect(withKeptApiKey(elsewhere, held), same(elsewhere));
      expect(withKeptApiKey(otherKind, held), same(otherKind));
    });

    test('a deletion, a keyed version or no held key is left as it came', () {
      final deletion = provider(deletedAt: created);
      final keyed = provider(apiKey: 'their-key');
      final incoming = provider();

      expect(withKeptApiKey(deletion, held), same(deletion));
      expect(withKeptApiKey(keyed, held), same(keyed));
      expect(withKeptApiKey(incoming, provider()), same(incoming));
      expect(withKeptApiKey(incoming, null), same(incoming));
    });
  });

  group('isOrphanedModel', () {
    test('a model under a tombstoned provider is an orphan', () {
      expect(
        isOrphanedModel(model(), [provider(deletedAt: created)], const {}),
        isTrue,
      );
    });

    test('a model under a live provider is not', () {
      expect(isOrphanedModel(model(), [provider()], const {}), isFalse);
    });

    test('a provider held only as a hard deletion orphans its models', () {
      expect(isOrphanedModel(model(), const [], {'provider-1'}), isTrue);
    });

    test('a provider never seen here is no deletion', () {
      expect(isOrphanedModel(model(), const [], const {}), isFalse);
    });

    test('only models can be orphans', () {
      expect(
        isOrphanedModel(provider(), [provider(deletedAt: created)], const {}),
        isFalse,
      );
    });
  });
}
