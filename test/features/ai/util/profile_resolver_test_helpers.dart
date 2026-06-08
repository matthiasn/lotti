import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';

import '../../agents/test_utils.dart';

enum GeneratedProviderResolutionShape {
  cloudWithKey,
  localWithoutKey,
  missingModel,
  missingProvider,
  cloudWithoutKey,
}

class GeneratedProfileSlotScenario {
  const GeneratedProfileSlotScenario({
    required this.thinkingShape,
    required this.optionalMask,
    required this.resolvableOptionalMask,
  });

  final GeneratedProviderResolutionShape thinkingShape;
  final int optionalMask;
  final int resolvableOptionalMask;

  bool get thinkingResolves =>
      thinkingShape == GeneratedProviderResolutionShape.cloudWithKey ||
      thinkingShape == GeneratedProviderResolutionShape.localWithoutKey;

  bool get hasHighEnd => optionalMask & 1 != 0;
  bool get hasVision => optionalMask & 2 != 0;
  bool get hasTranscription => optionalMask & 4 != 0;
  bool get hasImageGeneration => optionalMask & 8 != 0;

  bool get highEndResolves => hasHighEnd && resolvableOptionalMask & 1 != 0;
  bool get visionResolves => hasVision && resolvableOptionalMask & 2 != 0;
  bool get transcriptionResolves =>
      hasTranscription && resolvableOptionalMask & 4 != 0;
  bool get imageGenerationResolves =>
      hasImageGeneration && resolvableOptionalMask & 8 != 0;

  AiConfigInferenceProfile profile() {
    return testInferenceProfile(
      id: 'generated-profile',
      thinkingModelId: 'generated-thinking',
      thinkingHighEndModelId: hasHighEnd ? 'generated-high-end' : null,
      imageRecognitionModelId: hasVision ? 'generated-vision' : null,
      transcriptionModelId: hasTranscription ? 'generated-transcription' : null,
      imageGenerationModelId: hasImageGeneration
          ? 'generated-image-generation'
          : null,
      skillAssignments: const [
        SkillAssignment(skillId: 'generated-skill', automate: true),
      ],
    );
  }

  List<AiConfig> models() {
    final models = <AiConfig>[];
    if (thinkingShape != GeneratedProviderResolutionShape.missingModel) {
      models.add(
        testAiModel(
          id: 'model-thinking',
          providerModelId: 'generated-thinking',
          inferenceProviderId: 'provider-thinking',
        ),
      );
    }
    if (highEndResolves) {
      models.add(_model('model-high-end', 'generated-high-end'));
    }
    if (visionResolves) {
      models.add(_model('model-vision', 'generated-vision'));
    }
    if (transcriptionResolves) {
      models.add(_model('model-transcription', 'generated-transcription'));
    }
    if (imageGenerationResolves) {
      models.add(
        _model('model-image-generation', 'generated-image-generation'),
      );
    }
    return models;
  }

  AiConfigModel _model(String id, String providerModelId) {
    return testAiModel(
      id: id,
      providerModelId: providerModelId,
      inferenceProviderId: 'provider-$id',
    );
  }

  AiConfig? configById(String id) {
    if (id == 'generated-profile') return profile();
    if (id == 'provider-thinking') {
      return switch (thinkingShape) {
        GeneratedProviderResolutionShape.cloudWithKey => testInferenceProvider(
          id: id,
          apiKey: 'key',
        ),
        GeneratedProviderResolutionShape.localWithoutKey =>
          testLocalInferenceProvider(id: id),
        GeneratedProviderResolutionShape.cloudWithoutKey =>
          testInferenceProvider(id: id, apiKey: ''),
        GeneratedProviderResolutionShape.missingProvider => null,
        GeneratedProviderResolutionShape.missingModel => throw StateError(
          'Provider should not be resolved without model',
        ),
      };
    }
    if (id.startsWith('provider-model-')) {
      return testInferenceProvider(id: id, apiKey: 'key');
    }
    return null;
  }

  @override
  String toString() {
    return 'GeneratedProfileSlotScenario('
        'thinkingShape: $thinkingShape, '
        'optionalMask: $optionalMask, '
        'resolvableOptionalMask: $resolvableOptionalMask)';
  }
}

extension AnyGeneratedProfileSlotScenario on glados.Any {
  glados.Generator<GeneratedProviderResolutionShape>
  get providerResolutionShape =>
      glados.AnyUtils(this).choose(GeneratedProviderResolutionShape.values);

  glados.Generator<GeneratedProfileSlotScenario> get profileSlotScenario =>
      glados.CombinableAny(this).combine3(
        providerResolutionShape,
        glados.IntAnys(this).intInRange(0, 15),
        glados.IntAnys(this).intInRange(0, 15),
        (
          GeneratedProviderResolutionShape thinkingShape,
          int optionalMask,
          int resolvableOptionalMask,
        ) => GeneratedProfileSlotScenario(
          thinkingShape: thinkingShape,
          optionalMask: optionalMask,
          resolvableOptionalMask: resolvableOptionalMask,
        ),
      );
}
