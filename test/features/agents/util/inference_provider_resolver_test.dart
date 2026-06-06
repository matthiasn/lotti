import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/util/inference_provider_resolver.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';

enum _GeneratedModelLookupShape {
  empty,
  nonMatchingOnly,
  matchingFirst,
  matchingSecond,
  duplicateMatches,
}

enum _GeneratedProviderLookupShape {
  missing,
  wrongType,
  cloudWithKey,
  cloudEmptyKey,
  cloudWhitespaceKey,
  localEmptyKey,
}

class _GeneratedProviderResolutionScenario {
  const _GeneratedProviderResolutionScenario({
    required this.modelShape,
    required this.providerShape,
  });

  static const modelId = 'generated-model';

  final _GeneratedModelLookupShape modelShape;
  final _GeneratedProviderLookupShape providerShape;

  List<AiConfig> get models {
    final nonMatchingModel = testAiModel(
      id: 'non-matching-model',
      providerModelId: 'other-model',
      inferenceProviderId: 'provider-other',
    );
    final firstMatchingModel = testAiModel(
      id: 'first-matching-model',
      providerModelId: modelId,
      inferenceProviderId: 'provider-first',
    );
    final secondMatchingModel = testAiModel(
      id: 'second-matching-model',
      providerModelId: modelId,
      inferenceProviderId: 'provider-second',
    );

    return switch (modelShape) {
      _GeneratedModelLookupShape.empty => <AiConfig>[],
      _GeneratedModelLookupShape.nonMatchingOnly => [
        nonMatchingModel,
        testInferenceProvider(id: 'not-a-model'),
      ],
      _GeneratedModelLookupShape.matchingFirst => [
        firstMatchingModel,
        nonMatchingModel,
      ],
      _GeneratedModelLookupShape.matchingSecond => [
        nonMatchingModel,
        firstMatchingModel,
      ],
      _GeneratedModelLookupShape.duplicateMatches => [
        firstMatchingModel,
        secondMatchingModel,
      ],
    };
  }

  List<String> get matchingProviderIds {
    return switch (modelShape) {
      _GeneratedModelLookupShape.empty ||
      _GeneratedModelLookupShape.nonMatchingOnly => const <String>[],
      _GeneratedModelLookupShape.matchingFirst ||
      _GeneratedModelLookupShape.matchingSecond => const ['provider-first'],
      _GeneratedModelLookupShape.duplicateMatches => const [
        'provider-first',
        'provider-second',
      ],
    };
  }

  String? get expectedProviderId =>
      resolvesProvider ? matchingProviderIds.first : null;

  bool get hasMatchingModel => matchingProviderIds.isNotEmpty;

  List<String> get expectedLookupProviderIds {
    if (!hasMatchingModel) return const <String>[];
    return resolvesProvider
        ? matchingProviderIds.take(1).toList(growable: false)
        : matchingProviderIds;
  }

  bool get resolvesProvider {
    return hasMatchingModel &&
        (providerShape == _GeneratedProviderLookupShape.cloudWithKey ||
            providerShape == _GeneratedProviderLookupShape.localEmptyKey);
  }

  AiConfig? providerFor(String providerId) {
    return switch (providerShape) {
      _GeneratedProviderLookupShape.missing => null,
      _GeneratedProviderLookupShape.wrongType => testAiModel(
        id: providerId,
        providerModelId: 'wrong-type',
        inferenceProviderId: 'provider-other',
      ),
      _GeneratedProviderLookupShape.cloudWithKey => testInferenceProvider(
        id: providerId,
        apiKey: 'generated-key',
      ),
      _GeneratedProviderLookupShape.cloudEmptyKey => testInferenceProvider(
        id: providerId,
        apiKey: '',
      ),
      _GeneratedProviderLookupShape.cloudWhitespaceKey => testInferenceProvider(
        id: providerId,
        apiKey: '   ',
      ),
      _GeneratedProviderLookupShape.localEmptyKey => testLocalInferenceProvider(
        id: providerId,
      ),
    };
  }

  @override
  String toString() {
    return '_GeneratedProviderResolutionScenario('
        'modelShape: $modelShape, providerShape: $providerShape)';
  }
}

extension _AnyGeneratedProviderResolutionScenario on glados.Any {
  glados.Generator<_GeneratedModelLookupShape> get modelLookupShape =>
      glados.AnyUtils(this).choose(_GeneratedModelLookupShape.values);

  glados.Generator<_GeneratedProviderLookupShape> get providerLookupShape =>
      glados.AnyUtils(this).choose(_GeneratedProviderLookupShape.values);

  glados.Generator<_GeneratedProviderResolutionScenario>
  get providerResolutionScenario => glados.CombinableAny(this).combine2(
    modelLookupShape,
    providerLookupShape,
    (
      _GeneratedModelLookupShape modelShape,
      _GeneratedProviderLookupShape providerShape,
    ) => _GeneratedProviderResolutionScenario(
      modelShape: modelShape,
      providerShape: providerShape,
    ),
  );
}

void main() {
  late MockAiConfigRepository mockAiConfig;

  setUpAll(() {
    registerFallbackValue(AiConfigType.model);
  });

  setUp(() {
    mockAiConfig = MockAiConfigRepository();
  });

  void stubResolution({String apiKey = 'test-key'}) {
    when(
      () => mockAiConfig.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => [testAiModel()]);
    when(
      () => mockAiConfig.getConfigById('provider-1'),
    ).thenAnswer((_) async => testInferenceProvider(apiKey: apiKey));
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
      when(
        () => mockAiConfig.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => []);

      final provider = await resolveInferenceProvider(
        modelId: 'models/nonexistent',
        aiConfigRepository: mockAiConfig,
      );

      expect(provider, isNull);
    });

    test('returns null when provider is not an inference provider', () async {
      when(
        () => mockAiConfig.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => [testAiModel()]);
      // Return a model config instead of an inference provider.
      when(
        () => mockAiConfig.getConfigById('provider-1'),
      ).thenAnswer((_) async => testAiModel());

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
      when(() => mockAiConfig.getConfigsByType(AiConfigType.model)).thenAnswer(
        (_) async => [
          testAiModel(inferenceProviderId: 'provider-local'),
        ],
      );
      when(
        () => mockAiConfig.getConfigById('provider-local'),
      ).thenAnswer((_) async => testLocalInferenceProvider());

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

      when(
        () => mockAiConfig.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => [model1, model2]);
      when(
        () => mockAiConfig.getConfigById('provider-a'),
      ).thenAnswer((_) async => testInferenceProvider(id: 'provider-a'));

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

        when(
          () => mockAiConfig.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [staleModel, validModel]);
        when(
          () => mockAiConfig.getConfigById('deleted-gemini-provider'),
        ).thenAnswer((_) async => null);
        when(
          () => mockAiConfig.getConfigById('valid-gemini-provider'),
        ).thenAnswer(
          (_) async => testInferenceProvider(id: 'valid-gemini-provider'),
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

        when(
          () => mockAiConfig.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [noKeyModel, validModel]);
        when(
          () => mockAiConfig.getConfigById('gemini-no-key-provider'),
        ).thenAnswer(
          (_) async => testInferenceProvider(
            id: 'gemini-no-key-provider',
            apiKey: ' ',
          ),
        );
        when(
          () => mockAiConfig.getConfigById('gemini-valid-provider'),
        ).thenAnswer(
          (_) async => testInferenceProvider(id: 'gemini-valid-provider'),
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
        final openAiProvider = AiConfig.inferenceProvider(
          id: 'openai-provider',
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'openai-key',
          name: 'OpenAI',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.openAi,
        );

        when(
          () => mockAiConfig.getConfigsByType(AiConfigType.model),
        ).thenAnswer(
          (_) async => [wrongProviderTypeModel, geminiModel],
        );
        when(
          () => mockAiConfig.getConfigById('openai-provider'),
        ).thenAnswer((_) async => openAiProvider);
        when(
          () => mockAiConfig.getConfigById('gemini-provider'),
        ).thenAnswer(
          (_) async => testInferenceProvider(id: 'gemini-provider'),
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
        modelId: _GeneratedProviderResolutionScenario.modelId,
        aiConfigRepository: generatedRepository,
        logTag: 'GeneratedProviderResolutionTest',
      );

      if (scenario.resolvesProvider) {
        expect(provider, isNotNull, reason: '$scenario');
        expect(provider!.id, scenario.expectedProviderId);
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
      when(
        () => mockAiConfig.getConfigById('config-row-1'),
      ).thenAnswer((_) async => model);
      when(
        () => mockAiConfig.getConfigById('provider-1'),
      ).thenAnswer((_) async => testInferenceProvider());

      final resolved = await resolveInferenceProviderForModelConfigId(
        modelConfigId: 'config-row-1',
        aiConfigRepository: mockAiConfig,
      );

      expect(resolved, isNotNull);
      expect(resolved!.model.id, 'config-row-1');
      expect(resolved.provider.id, 'provider-1');
    });

    test('returns null when the config id does not exist', () async {
      when(
        () => mockAiConfig.getConfigById('missing'),
      ).thenAnswer((_) async => null);

      final resolved = await resolveInferenceProviderForModelConfigId(
        modelConfigId: 'missing',
        aiConfigRepository: mockAiConfig,
      );

      expect(resolved, isNull);
    });

    test('returns null when the config id is not a model', () async {
      when(
        () => mockAiConfig.getConfigById('provider-as-model'),
      ).thenAnswer((_) async => testInferenceProvider(id: 'provider-as-model'));

      final resolved = await resolveInferenceProviderForModelConfigId(
        modelConfigId: 'provider-as-model',
        aiConfigRepository: mockAiConfig,
      );

      expect(resolved, isNull);
    });

    test('returns null when the parent provider is missing', () async {
      when(
        () => mockAiConfig.getConfigById('config-row-1'),
      ).thenAnswer((_) async => testAiModel(id: 'config-row-1'));
      when(
        () => mockAiConfig.getConfigById('provider-1'),
      ).thenAnswer((_) async => null);

      final resolved = await resolveInferenceProviderForModelConfigId(
        modelConfigId: 'config-row-1',
        aiConfigRepository: mockAiConfig,
      );

      expect(resolved, isNull);
    });

    test(
      'returns null when the parent provider has no API key',
      () async {
        when(
          () => mockAiConfig.getConfigById('config-row-1'),
        ).thenAnswer((_) async => testAiModel(id: 'config-row-1'));
        when(
          () => mockAiConfig.getConfigById('provider-1'),
        ).thenAnswer((_) async => testInferenceProvider(apiKey: ''));

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
      when(
        () => mockAiConfig.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => [rowA, rowB]);
      when(
        () => mockAiConfig.getConfigById('provider-1'),
      ).thenAnswer((_) async => testInferenceProvider());

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
        when(
          () => mockAiConfig.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [testAiModel()]);
        when(
          () => mockAiConfig.getConfigById('provider-1'),
        ).thenAnswer((_) async => testInferenceProvider());

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
        when(
          () => mockAiConfig.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [testAiModel()]);
        when(
          () => mockAiConfig.getConfigById('provider-1'),
        ).thenAnswer((_) async => testInferenceProvider(apiKey: ''));

        final resolved = await resolveInferenceProviderForProfileSlot(
          modelId: 'model-1',
          aiConfigRepository: mockAiConfig,
        );

        expect(resolved, isNull);
      },
    );
  });
}
