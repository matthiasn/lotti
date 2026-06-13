import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/model/ai_config.dart';

import '../test_utils.dart';

enum GeneratedModelLookupShape {
  empty,
  nonMatchingOnly,
  matchingFirst,
  matchingSecond,
  duplicateMatches,
}

enum GeneratedProviderLookupShape {
  missing,
  wrongType,
  cloudWithKey,
  cloudEmptyKey,
  cloudWhitespaceKey,
  localEmptyKey,
}

class GeneratedProviderResolutionScenario {
  const GeneratedProviderResolutionScenario({
    required this.modelShape,
    required this.providerShape,
  });

  static const modelId = 'generated-model';

  final GeneratedModelLookupShape modelShape;
  final GeneratedProviderLookupShape providerShape;

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
      GeneratedModelLookupShape.empty => <AiConfig>[],
      GeneratedModelLookupShape.nonMatchingOnly => [
        nonMatchingModel,
        testInferenceProvider(id: 'not-a-model'),
      ],
      GeneratedModelLookupShape.matchingFirst => [
        firstMatchingModel,
        nonMatchingModel,
      ],
      GeneratedModelLookupShape.matchingSecond => [
        nonMatchingModel,
        firstMatchingModel,
      ],
      GeneratedModelLookupShape.duplicateMatches => [
        firstMatchingModel,
        secondMatchingModel,
      ],
    };
  }

  List<String> get matchingProviderIds {
    return switch (modelShape) {
      GeneratedModelLookupShape.empty ||
      GeneratedModelLookupShape.nonMatchingOnly => const <String>[],
      GeneratedModelLookupShape.matchingFirst ||
      GeneratedModelLookupShape.matchingSecond => const ['provider-first'],
      GeneratedModelLookupShape.duplicateMatches => const [
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
        (providerShape == GeneratedProviderLookupShape.cloudWithKey ||
            providerShape == GeneratedProviderLookupShape.localEmptyKey);
  }

  AiConfig? providerFor(String providerId) {
    return switch (providerShape) {
      GeneratedProviderLookupShape.missing => null,
      GeneratedProviderLookupShape.wrongType => testAiModel(
        id: providerId,
        providerModelId: 'wrong-type',
        inferenceProviderId: 'provider-other',
      ),
      GeneratedProviderLookupShape.cloudWithKey => testInferenceProvider(
        id: providerId,
        apiKey: 'generated-key',
      ),
      GeneratedProviderLookupShape.cloudEmptyKey => testInferenceProvider(
        id: providerId,
        apiKey: '',
      ),
      GeneratedProviderLookupShape.cloudWhitespaceKey => testInferenceProvider(
        id: providerId,
        apiKey: '   ',
      ),
      GeneratedProviderLookupShape.localEmptyKey => testLocalInferenceProvider(
        id: providerId,
      ),
    };
  }

  @override
  String toString() {
    return 'GeneratedProviderResolutionScenario('
        'modelShape: $modelShape, providerShape: $providerShape)';
  }
}

extension AnyGeneratedProviderResolutionScenario on glados.Any {
  glados.Generator<GeneratedModelLookupShape> get modelLookupShape =>
      glados.AnyUtils(this).choose(GeneratedModelLookupShape.values);

  glados.Generator<GeneratedProviderLookupShape> get providerLookupShape =>
      glados.AnyUtils(this).choose(GeneratedProviderLookupShape.values);

  glados.Generator<GeneratedProviderResolutionScenario>
  get providerResolutionScenario => glados.CombinableAny(this).combine2(
    modelLookupShape,
    providerLookupShape,
    (
      GeneratedModelLookupShape modelShape,
      GeneratedProviderLookupShape providerShape,
    ) => GeneratedProviderResolutionScenario(
      modelShape: modelShape,
      providerShape: providerShape,
    ),
  );
}
