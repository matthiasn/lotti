import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/known_models.dart';


enum GeneratedExistingKnownModelsShape {
  none,
  first,
  alternating,
  all,
}

class GeneratedPrepopulationScenario {
  const GeneratedPrepopulationScenario({
    required this.providerType,
    required this.existingShape,
  });

  final InferenceProviderType providerType;
  final GeneratedExistingKnownModelsShape existingShape;

  String get providerId => 'generated-${providerType.name}-provider';

  List<KnownModel> get knownModels =>
      knownModelsByProvider[providerType] ?? const [];

  Set<int> get existingKnownModelIndexes {
    return switch (existingShape) {
      GeneratedExistingKnownModelsShape.none => const <int>{},
      GeneratedExistingKnownModelsShape.first =>
        knownModels.isEmpty ? const <int>{} : const <int>{0},
      GeneratedExistingKnownModelsShape.alternating => {
        for (var i = 0; i < knownModels.length; i++)
          if (i.isEven) i,
      },
      GeneratedExistingKnownModelsShape.all => {
        for (var i = 0; i < knownModels.length; i++) i,
      },
    };
  }

  List<AiConfig> get existingConfigs {
    return [
      for (final index in existingKnownModelIndexes)
        AiConfig.model(
          id: generateModelId(providerId, knownModels[index].providerModelId),
          name: 'Existing ${knownModels[index].name}',
          providerModelId: knownModels[index].providerModelId,
          inferenceProviderId: providerId,
          createdAt: DateTime(2026, 3, 15),
          inputModalities: const [Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        ),
      AiConfig.inferenceProvider(
        id: 'not-a-model',
        baseUrl: 'https://generated.example.com',
        apiKey: 'key',
        name: 'Not a model',
        createdAt: DateTime(2026, 3, 15),
        inferenceProviderType: InferenceProviderType.openAi,
      ),
    ];
  }

  List<KnownModel> get modelsToCreate => [
    for (var i = 0; i < knownModels.length; i++)
      if (!existingKnownModelIndexes.contains(i)) knownModels[i],
  ];

  List<String> get expectedCreatedIds => [
    for (final model in modelsToCreate)
      generateModelId(providerId, model.providerModelId),
  ];

  AiConfigInferenceProvider get provider =>
      AiConfig.inferenceProvider(
            id: providerId,
            baseUrl: 'https://generated.example.com',
            apiKey: 'key',
            name: 'Generated ${providerType.name}',
            createdAt: DateTime(2026, 3, 15),
            inferenceProviderType: providerType,
          )
          as AiConfigInferenceProvider;

  @override
  String toString() {
    return 'GeneratedPrepopulationScenario('
        'providerType: $providerType, existingShape: $existingShape)';
  }
}

extension AnyGeneratedPrepopulationScenario on glados.Any {
  glados.Generator<InferenceProviderType> get inferenceProviderType =>
      glados.AnyUtils(this).choose(InferenceProviderType.values);

  glados.Generator<GeneratedExistingKnownModelsShape>
  get existingKnownModelsShape =>
      glados.AnyUtils(this).choose(GeneratedExistingKnownModelsShape.values);

  glados.Generator<GeneratedPrepopulationScenario> get prepopulationScenario =>
      glados.CombinableAny(this).combine2(
        inferenceProviderType,
        existingKnownModelsShape,
        (
          InferenceProviderType providerType,
          GeneratedExistingKnownModelsShape existingShape,
        ) => GeneratedPrepopulationScenario(
          providerType: providerType,
          existingShape: existingShape,
        ),
      );
}
