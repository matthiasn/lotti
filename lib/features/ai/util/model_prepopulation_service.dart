/// Service for pre-populating known models when creating inference providers.
///
/// This service automatically creates model configurations for known models
/// when a new inference provider is created. It checks if models with the
/// same IDs already exist to avoid duplicates.
library;

import 'dart:developer' as developer;

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

  /// Backfills newly added known models for all existing inference providers.
  ///
  /// This ensures that when new models are added to `knownModelsByProvider`,
  /// existing users get them without having to re-create their providers.
  /// Safe to call on every startup — skips models that already exist.
  Future<void> backfillNewModels() async {
    final allConfigs = await _repository.getConfigsByType(
      AiConfigType.inferenceProvider,
    );
    final providers = allConfigs.whereType<AiConfigInferenceProvider>();

    var totalCreated = 0;
    for (final provider in providers) {
      totalCreated += await prepopulateModelsForProvider(provider);
    }

    if (totalCreated > 0) {
      developer.log(
        'Backfilled $totalCreated new known models for existing providers',
        name: 'ModelPrepopulationService',
      );
    }
  }

  /// Removes auto-generated model configs whose `providerModelId` is no
  /// longer in [knownModelsByProvider].
  ///
  /// Only deletes models whose ID matches the deterministic
  /// [generateModelId] pattern, so user-created models are never touched.
  /// Safe to call on every startup.
  Future<void> removeStaleKnownModels() async {
    final allProviders = await _repository.getConfigsByType(
      AiConfigType.inferenceProvider,
    );
    final providers = allProviders
        .whereType<AiConfigInferenceProvider>()
        .toList();
    if (providers.isEmpty) return;

    final allModels = await _repository.getConfigsByType(AiConfigType.model);
    final existingModels = allModels.whereType<AiConfigModel>().toList();

    var totalRemoved = 0;

    for (final provider in providers) {
      final knownModels =
          knownModelsByProvider[provider.inferenceProviderType] ?? [];
      final validIds = knownModels
          .map((m) => generateModelId(provider.id, m.providerModelId))
          .toSet();

      for (final model in existingModels) {
        if (model.inferenceProviderId != provider.id) continue;

        // Only remove if the ID was auto-generated (matches the pattern)
        // and the providerModelId is no longer known.
        final expectedId = generateModelId(provider.id, model.providerModelId);
        if (model.id == expectedId && !validIds.contains(model.id)) {
          await _repository.deleteConfig(model.id);
          totalRemoved++;
        }
      }
    }

    if (totalRemoved > 0) {
      developer.log(
        'Removed $totalRemoved stale known models',
        name: 'ModelPrepopulationService',
      );
    }
  }
}
