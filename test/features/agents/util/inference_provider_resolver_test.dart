import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/util/inference_provider_resolver.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';
import 'inference_provider_resolver_test_helpers.dart';

void main() {
  late MockAiConfigRepository mockAiConfig;

  // No registerFallbackValue is needed here: getConfigsByType is always called
  // and verified with a concrete AiConfigType.model (never any()), and the only
  // any() matcher is getConfigById(any()) whose argument is a built-in String.

  setUp(() {
    mockAiConfig = MockAiConfigRepository();
  });

  // Stubs the model-type lookup with [models].
  void stubModels(List<AiConfig> models) {
    when(
      () => mockAiConfig.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => models);
  }

  // Stubs a single getConfigById lookup for [id] to return [config].
  void stubProvider(String id, AiConfig? config) {
    when(
      () => mockAiConfig.getConfigById(id),
    ).thenAnswer((_) async => config);
  }

  void stubResolution({String apiKey = 'test-key'}) {
    stubModels([testAiModel()]);
    stubProvider('provider-1', testInferenceProvider(apiKey: apiKey));
  }

  group('resolveInferenceProvider', () {
    test('returns provider when model and provider are configured', () async {
      stubResolution();

      final provider = await resolveInferenceProvider(
        modelId: 'models/gemini-3-flash-preview',
        aiConfigRepository: mockAiConfig,
      );

      expect(provider, isNotNull);
      expect(provider!.apiKey, 'test-key');
    });

    test('returns null when model is not found', () async {
      stubModels([]);

      final provider = await resolveInferenceProvider(
        modelId: 'models/nonexistent',
        aiConfigRepository: mockAiConfig,
      );

      expect(provider, isNull);
    });

    test('returns null when provider is not an inference provider', () async {
      stubModels([testAiModel()]);
      // Return a model config instead of an inference provider.
      stubProvider('provider-1', testAiModel());

      final provider = await resolveInferenceProvider(
        modelId: 'models/gemini-3-flash-preview',
        aiConfigRepository: mockAiConfig,
      );

      expect(provider, isNull);
    });

    test('returns null when cloud provider has empty API key', () async {
      stubResolution(apiKey: '');

      final provider = await resolveInferenceProvider(
        modelId: 'models/gemini-3-flash-preview',
        aiConfigRepository: mockAiConfig,
      );

      expect(provider, isNull);
    });

    test(
      'returns null when cloud provider has whitespace-only API key',
      () async {
        stubResolution(apiKey: '   ');

        final provider = await resolveInferenceProvider(
          modelId: 'models/gemini-3-flash-preview',
          aiConfigRepository: mockAiConfig,
        );

        expect(provider, isNull);
      },
    );

    test('returns provider for local provider with empty API key', () async {
      stubModels([testAiModel(inferenceProviderId: 'provider-local')]);
      stubProvider('provider-local', testLocalInferenceProvider());

      final provider = await resolveInferenceProvider(
        modelId: 'models/gemini-3-flash-preview',
        aiConfigRepository: mockAiConfig,
      );

      expect(provider, isNotNull);
      expect(provider!.inferenceProviderType, InferenceProviderType.ollama);
    });

    test('accepts custom logTag', () async {
      stubResolution();

      final provider = await resolveInferenceProvider(
        modelId: 'models/gemini-3-flash-preview',
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

      stubModels([model1, model2]);
      stubProvider('provider-a', testInferenceProvider(id: 'provider-a'));

      final provider = await resolveInferenceProvider(
        modelId: 'models/gemini-3-flash-preview',
        aiConfigRepository: mockAiConfig,
      );

      expect(provider, isNotNull);
      verify(() => mockAiConfig.getConfigById('provider-a')).called(1);
      verifyNever(() => mockAiConfig.getConfigById('provider-b'));
    });

    test(
      'skips stale duplicate model rows and returns later usable provider',
      () async {
        final staleModel = testAiModel(
          id: 'stale-gemini-model',
          inferenceProviderId: 'deleted-gemini-provider',
        );
        final validModel = testAiModel(
          id: 'valid-gemini-model',
          inferenceProviderId: 'valid-gemini-provider',
        );

        stubModels([staleModel, validModel]);
        stubProvider('deleted-gemini-provider', null);
        stubProvider(
          'valid-gemini-provider',
          testInferenceProvider(id: 'valid-gemini-provider'),
        );

        final provider = await resolveInferenceProvider(
          modelId: 'models/gemini-3-flash-preview',
          aiConfigRepository: mockAiConfig,
        );

        expect(provider, isNotNull);
        expect(provider!.id, 'valid-gemini-provider');
        verify(
          () => mockAiConfig.getConfigById('deleted-gemini-provider'),
        ).called(1);
        verify(
          () => mockAiConfig.getConfigById('valid-gemini-provider'),
        ).called(1);
      },
    );

    test(
      'resolveInferenceProviderWithModel returns the matched model row and '
      'its provider as one record',
      () async {
        final model = testAiModel(
          id: 'record-model-row',
          inferenceProviderId: 'record-provider',
        );
        stubModels([model]);
        stubProvider(
          'record-provider',
          testInferenceProvider(id: 'record-provider'),
        );

        final resolved = await resolveInferenceProviderWithModel(
          modelId: 'models/gemini-3-flash-preview',
          aiConfigRepository: mockAiConfig,
        );

        expect(resolved, isNotNull);
        expect(resolved!.model.id, 'record-model-row');
        expect(resolved.provider.id, 'record-provider');
      },
    );

    test(
      'falls back to a usable provider of the wrong type when no provider '
      'matches the known model type',
      () async {
        // gemini-3-flash-preview has known Gemini provider types; configure
        // only a usable provider of a different type so every iteration
        // takes the wrong-type branch and the fallback wins.
        final model = testAiModel(
          id: 'fallback-model-row',
          inferenceProviderId: 'mismatched-provider',
        );
        stubModels([model]);
        stubProvider(
          'mismatched-provider',
          testInferenceProvider(
            id: 'mismatched-provider',
            inferenceProviderType: InferenceProviderType.openAi,
          ),
        );

        final resolved = await resolveInferenceProviderWithModel(
          modelId: 'models/gemini-3-flash-preview',
          aiConfigRepository: mockAiConfig,
        );

        // The usableFallback branch returns the mismatched-but-usable row.
        expect(resolved, isNotNull);
        expect(resolved!.provider.id, 'mismatched-provider');
        expect(resolved.model.id, 'fallback-model-row');
      },
    );

    test(
      'continues past unusable duplicate providers before resolving',
      () async {
        final noKeyModel = testAiModel(
          id: 'gemini-no-key-model',
          inferenceProviderId: 'gemini-no-key-provider',
        );
        final validModel = testAiModel(
          id: 'gemini-valid-model',
          inferenceProviderId: 'gemini-valid-provider',
        );

        stubModels([noKeyModel, validModel]);
        stubProvider(
          'gemini-no-key-provider',
          testInferenceProvider(id: 'gemini-no-key-provider', apiKey: ' '),
        );
        stubProvider(
          'gemini-valid-provider',
          testInferenceProvider(id: 'gemini-valid-provider'),
        );

        final provider = await resolveInferenceProvider(
          modelId: 'models/gemini-3-flash-preview',
          aiConfigRepository: mockAiConfig,
        );

        expect(provider, isNotNull);
        expect(provider!.id, 'gemini-valid-provider');
        verify(
          () => mockAiConfig.getConfigById('gemini-no-key-provider'),
        ).called(1);
        verify(
          () => mockAiConfig.getConfigById('gemini-valid-provider'),
        ).called(1);
      },
    );

    test(
      'prefers the usable provider whose type owns the known providerModelId',
      () async {
        final wrongProviderTypeModel = testAiModel(
          id: 'wrong-provider-type-model',
          inferenceProviderId: 'openai-provider',
        );
        final geminiModel = testAiModel(
          id: 'gemini-model',
          inferenceProviderId: 'gemini-provider',
        );
        final openAiProvider = testInferenceProvider(
          id: 'openai-provider',
          apiKey: 'openai-key',
          inferenceProviderType: InferenceProviderType.openAi,
        );

        stubModels([wrongProviderTypeModel, geminiModel]);
        stubProvider('openai-provider', openAiProvider);
        stubProvider(
          'gemini-provider',
          testInferenceProvider(id: 'gemini-provider'),
        );

        final provider = await resolveInferenceProvider(
          modelId: 'models/gemini-3-flash-preview',
          aiConfigRepository: mockAiConfig,
        );

        expect(provider, isNotNull);
        expect(provider!.id, 'gemini-provider');
        verify(() => mockAiConfig.getConfigById('openai-provider')).called(1);
        verify(() => mockAiConfig.getConfigById('gemini-provider')).called(1);
      },
    );

    glados.Glados(
      glados.any.providerResolutionScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test('matches generated model and provider resolution semantics', (
      scenario,
    ) async {
      final generatedRepository = MockAiConfigRepository();

      when(
        () => generatedRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => scenario.models);
      when(
        () => generatedRepository.getConfigById(any()),
      ).thenAnswer((invocation) async {
        final providerId = invocation.positionalArguments.single as String;
        return scenario.providerFor(providerId);
      });

      final provider = await resolveInferenceProvider(
        modelId: GeneratedProviderResolutionScenario.modelId,
        aiConfigRepository: generatedRepository,
        logTag: 'GeneratedProviderResolutionTest',
      );

      if (scenario.resolvesProvider) {
        expect(provider, isNotNull, reason: '$scenario');
        expect(provider!.id, scenario.expectedProviderId);
        // The resolved record carries the provider's real fields through.
        if (scenario.providerShape ==
            GeneratedProviderLookupShape.cloudWithKey) {
          expect(provider.apiKey, 'generated-key', reason: '$scenario');
        }
      } else {
        expect(provider, isNull, reason: '$scenario');
      }

      verify(
        () => generatedRepository.getConfigsByType(AiConfigType.model),
      ).called(1);
      if (scenario.hasMatchingModel) {
        for (final providerId in scenario.expectedLookupProviderIds) {
          verify(
            () => generatedRepository.getConfigById(providerId),
          ).called(1);
        }
      } else {
        verifyNever(() => generatedRepository.getConfigById(any()));
      }
    }, tags: 'glados');
  });

  group('resolveInferenceProviderForModelConfigId', () {
    test('resolves the model row and its usable provider', () async {
      final model = testAiModel(id: 'config-row-1');
      stubProvider('config-row-1', model);
      stubProvider('provider-1', testInferenceProvider());

      final resolved = await resolveInferenceProviderForModelConfigId(
        modelConfigId: 'config-row-1',
        aiConfigRepository: mockAiConfig,
      );

      expect(resolved, isNotNull);
      expect(resolved!.model.id, 'config-row-1');
      expect(resolved.provider.id, 'provider-1');
    });

    test('returns null when the config id does not exist', () async {
      stubProvider('missing', null);

      final resolved = await resolveInferenceProviderForModelConfigId(
        modelConfigId: 'missing',
        aiConfigRepository: mockAiConfig,
      );

      expect(resolved, isNull);
    });

    test('returns null when the config id is not a model', () async {
      stubProvider(
        'provider-as-model',
        testInferenceProvider(id: 'provider-as-model'),
      );

      final resolved = await resolveInferenceProviderForModelConfigId(
        modelConfigId: 'provider-as-model',
        aiConfigRepository: mockAiConfig,
      );

      expect(resolved, isNull);
    });

    test('returns null when the parent provider is missing', () async {
      stubProvider('config-row-1', testAiModel(id: 'config-row-1'));
      stubProvider('provider-1', null);

      final resolved = await resolveInferenceProviderForModelConfigId(
        modelConfigId: 'config-row-1',
        aiConfigRepository: mockAiConfig,
      );

      expect(resolved, isNull);
    });

    test(
      'returns null when the parent provider has no API key',
      () async {
        stubProvider('config-row-1', testAiModel(id: 'config-row-1'));
        stubProvider('provider-1', testInferenceProvider(apiKey: ''));

        final resolved = await resolveInferenceProviderForModelConfigId(
          modelConfigId: 'config-row-1',
          aiConfigRepository: mockAiConfig,
        );

        expect(resolved, isNull);
      },
    );
  });

  group('resolveInferenceProviderForProfileSlot', () {
    test('prefers an exact AiConfigModel.id match', () async {
      // Two rows share the providerModelId; the slot stores the row id of
      // the second one, which must win over the wire-level fallback.
      final rowA = testAiModel(id: 'row-a', inferenceProviderId: 'provider-a');
      final rowB = testAiModel(id: 'row-b');
      stubModels([rowA, rowB]);
      stubProvider('provider-1', testInferenceProvider());

      final resolved = await resolveInferenceProviderForProfileSlot(
        modelId: 'row-b',
        aiConfigRepository: mockAiConfig,
      );

      expect(resolved, isNotNull);
      expect(resolved!.model.id, 'row-b');
      expect(resolved.provider.id, 'provider-1');
      // The exact-id path never falls through to the legacy candidate walk.
      verifyNever(() => mockAiConfig.getConfigById('provider-a'));
    });

    test(
      'falls back to the legacy providerModelId lookup for old slots',
      () async {
        stubModels([testAiModel()]);
        stubProvider('provider-1', testInferenceProvider());

        final resolved = await resolveInferenceProviderForProfileSlot(
          modelId: 'models/gemini-3-flash-preview',
          aiConfigRepository: mockAiConfig,
        );

        expect(resolved, isNotNull);
        expect(resolved!.model.id, 'model-1');
      },
    );

    test(
      'returns null when an exact-id match has an unusable provider',
      () async {
        stubModels([testAiModel()]);
        stubProvider('provider-1', testInferenceProvider(apiKey: ''));

        final resolved = await resolveInferenceProviderForProfileSlot(
          modelId: 'model-1',
          aiConfigRepository: mockAiConfig,
        );

        expect(resolved, isNull);
      },
    );
  });
}
