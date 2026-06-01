import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_provider_form_state.dart';

void main() {
  group('ApiKeyName validator', () {
    for (final testCase in <({String value, ProviderFormError? error})>[
      (value: '', error: ProviderFormError.tooShort),
      (value: 'ab', error: ProviderFormError.tooShort),
      (value: 'abc', error: null),
      (value: 'a longer name', error: null),
    ]) {
      test('"${testCase.value}" -> ${testCase.error}', () {
        expect(
          ApiKeyName.dirty(testCase.value).error,
          testCase.error,
        );
      });
    }
  });

  group('ApiKeyValue validator', () {
    for (final testCase
        in <
          ({
            String value,
            InferenceProviderType? type,
            ProviderFormError? error,
          })
        >[
          // Local providers never require a key.
          (value: '', type: InferenceProviderType.ollama, error: null),
          (value: '', type: InferenceProviderType.whisper, error: null),
          // Remote providers require a non-empty key.
          (
            value: '',
            type: InferenceProviderType.genericOpenAi,
            error: ProviderFormError.empty,
          ),
          (value: '', type: null, error: ProviderFormError.empty),
          (
            value: 'sk-123',
            type: InferenceProviderType.genericOpenAi,
            error: null,
          ),
          (value: 'sk-123', type: InferenceProviderType.ollama, error: null),
        ]) {
      test('"${testCase.value}" (${testCase.type}) -> ${testCase.error}', () {
        expect(
          ApiKeyValue.dirty(testCase.value, testCase.type).error,
          testCase.error,
        );
      });
    }
  });

  group('BaseUrl validator', () {
    for (final testCase in <({String value, ProviderFormError? error})>[
      (value: '', error: null),
      (value: 'https://api.example.com', error: null),
      (value: 'http://localhost:11434', error: null),
      // Non-http scheme.
      (value: 'ftp://example.com', error: ProviderFormError.invalidUrl),
      // Relative (not absolute).
      (value: 'example.com/path', error: ProviderFormError.invalidUrl),
      // Unparseable (space) -> caught and treated as invalid.
      (value: 'not a url', error: ProviderFormError.invalidUrl),
    ]) {
      test('"${testCase.value}" -> ${testCase.error}', () {
        expect(BaseUrl.dirty(testCase.value).error, testCase.error);
      });
    }
  });

  group('DescriptionValue validator', () {
    test('accepts any value', () {
      expect(const DescriptionValue.dirty('anything').error, isNull);
      expect(const DescriptionValue.pure().error, isNull);
    });
  });

  group('InferenceProviderFormState', () {
    test('is valid only when every input validates', () {
      final invalid = InferenceProviderFormState(
        name: const ApiKeyName.dirty('ok'), // too short
        apiKey: const ApiKeyValue.dirty(
          '',
          InferenceProviderType.genericOpenAi,
        ),
      );
      expect(invalid.isValid, isFalse);

      final valid = InferenceProviderFormState(
        name: const ApiKeyName.dirty('valid name'),
        apiKey: const ApiKeyValue.dirty(
          'sk-123',
          InferenceProviderType.genericOpenAi,
        ),
        baseUrl: const BaseUrl.dirty('https://api.example.com'),
      );
      expect(valid.isValid, isTrue);
      expect(valid.inputs, hasLength(4));
    });

    test('copyWith overrides only the provided fields', () {
      final original = InferenceProviderFormState(
        id: 'id-1',
        name: const ApiKeyName.dirty('original'),
        lastUpdated: DateTime(2024, 3, 15),
      );

      final updated = original.copyWith(
        name: const ApiKeyName.dirty('changed'),
        isSubmitting: true,
        inferenceProviderType: InferenceProviderType.ollama,
      );

      expect(updated.id, 'id-1'); // preserved
      expect(updated.name.value, 'changed');
      expect(updated.isSubmitting, isTrue);
      expect(updated.inferenceProviderType, InferenceProviderType.ollama);
      // Untouched fields keep their previous values.
      expect(updated.apiKey, same(original.apiKey));
      expect(updated.baseUrl, same(original.baseUrl));
    });

    test('toAiConfig maps form values onto an inferenceProvider config', () {
      final state = InferenceProviderFormState(
        id: 'config-7',
        name: const ApiKeyName.dirty('My Provider'),
        apiKey: const ApiKeyValue.dirty('sk-xyz'),
        baseUrl: const BaseUrl.dirty('https://api.example.com'),
        description: const DescriptionValue.dirty('a provider'),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      final config = state.toAiConfig();

      expect(config, isA<AiConfigInferenceProvider>());
      final provider = config as AiConfigInferenceProvider;
      expect(provider.id, 'config-7');
      expect(provider.name, 'My Provider');
      expect(provider.apiKey, 'sk-xyz');
      expect(provider.baseUrl, 'https://api.example.com');
      expect(provider.description, 'a provider');
      expect(
        provider.inferenceProviderType,
        InferenceProviderType.gemini,
      );
    });

    test('toAiConfig generates an id when the form has none', () {
      final config =
          InferenceProviderFormState(
                name: const ApiKeyName.dirty('No Id'),
                apiKey: const ApiKeyValue.dirty('sk'),
              ).toAiConfig()
              as AiConfigInferenceProvider;
      expect(config.id, isNotEmpty);
    });
  });
}
