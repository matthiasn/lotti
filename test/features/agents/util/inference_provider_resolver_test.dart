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

  String? get expectedProviderId {
    return switch (modelShape) {
      _GeneratedModelLookupShape.empty ||
      _GeneratedModelLookupShape.nonMatchingOnly => null,
      _GeneratedModelLookupShape.matchingFirst ||
      _GeneratedModelLookupShape.matchingSecond ||
      _GeneratedModelLookupShape.duplicateMatches => 'provider-first',
    };
  }

  bool get hasMatchingModel => expectedProviderId != null;

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
        verify(
          () => generatedRepository.getConfigById(
            scenario.expectedProviderId!,
          ),
        ).called(1);
      } else {
        verifyNever(() => generatedRepository.getConfigById(any()));
      }
    });
  });
}
