/// Service for pre-populating known models when creating inference providers.
///
/// This service automatically creates model configurations for known models
/// when a new inference provider is created. It checks if models with the
/// same IDs already exist to avoid duplicates.
library;

import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/get_it.dart';

/// Service that handles automatic population of known models
/// for newly created inference providers.
class ModelPrepopulationService {
  ModelPrepopulationService({
    AiConfigRepository? repository,
  }) : _repository = repository ?? getIt<AiConfigRepository>();

  final AiConfigRepository _repository;

  /// Pre-populates known models for a given inference provider.
  ///
  /// This method:
  /// 1. Looks up known models for the provider type
  /// 2. Generates unique IDs for each model
  /// 3. Checks if models with those IDs already exist
  /// 4. Creates only the models that don't exist yet
  ///
  /// Returns the number of models that were created.
  Future<int> prepopulateModelsForProvider(
    AiConfigInferenceProvider provider,
  ) async {
    // Get known models for this provider type
    final knownModels = knownModelsByProvider[provider.inferenceProviderType];
    if (knownModels == null || knownModels.isEmpty) {
      return 0;
    }

    // Get existing models to check for duplicates
    final existingConfigs = await _repository.getConfigsByType(
      AiConfigType.model,
    );
    final existingModelIds = existingConfigs
        .whereType<AiConfigModel>()
        .map((model) => model.id)
        .toSet();

    var modelsCreated = 0;

    // Create models that don't exist yet
    for (final knownModel in knownModels) {
      final modelId = generateModelId(
        provider.id,
        knownModel.providerModelId,
      );

      // Skip if model already exists
      if (existingModelIds.contains(modelId)) {
        continue;
      }

      // Create the new model
      final newModel = knownModel.toAiConfigModel(
        id: modelId,
        inferenceProviderId: provider.id,
      );

      await _repository.saveConfig(newModel);
      modelsCreated++;
    }

    return modelsCreated;
  }

  /// Checks if any known models are missing for a provider and creates them.
  ///
  /// This is useful for updating existing providers with new models
  /// that may have been added to the known models list.
  Future<int> ensureModelsForProvider(String providerId) async {
    // Get the provider configuration
    final providerConfig = await _repository.getConfigById(providerId);
    if (providerConfig == null ||
        providerConfig is! AiConfigInferenceProvider) {
      return 0;
    }

    return prepopulateModelsForProvider(providerConfig);
  }

  /// Gets a list of model IDs that would be created for a provider type.
  ///
  /// This is useful for testing or preview purposes.
  List<String> getModelIdsForProviderType(
    String providerId,
    InferenceProviderType providerType,
  ) {
    final knownModels = knownModelsByProvider[providerType];
    if (knownModels == null) return [];

    return knownModels
        .map((model) => generateModelId(providerId, model.providerModelId))
        .toList();
  }
}
