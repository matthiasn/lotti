/// Service for pre-populating known models when creating inference providers.
///
/// This service automatically creates model configurations for known models
/// when a new inference provider is created. It checks if models with the
/// same provider-native model IDs already exist to avoid duplicates.
library;

import 'dart:developer' as developer;

import 'package:lotti/features/ai/constants/provider_config.dart';
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
  /// 3. Checks if usable rows with those provider-native model IDs exist
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

    // Get existing models to check for duplicates by provider model identity,
    // not just by row ID. FTUE uses UUID model IDs while this service uses
    // deterministic IDs, and synced duplicate providers can otherwise seed
    // multiple rows for the same providerModelId.
    // Includes soft-deleted rows on purpose: a model the user deleted must
    // read as already configured here, or the backfill recreates it. But only
    // *this* provider's deletions count — a row the user deleted under
    // provider A must not stop the same known model being created for a newly
    // added provider B of the same type.
    final existingConfigs = await _repository.getConfigsByType(
      AiConfigType.model,
      includeDeleted: true,
    );
    final existingModels = existingConfigs
        .whereType<AiConfigModel>()
        .where(
          (model) =>
              model.deletedAt == null ||
              model.inferenceProviderId == provider.id,
        )
        .toList(growable: false);
    final providerConfigs = await _repository.getConfigsByType(
      AiConfigType.inferenceProvider,
    );
    final providersById = {
      for (final provider
          in providerConfigs.whereType<AiConfigInferenceProvider>())
        provider.id: provider,
    };

    var modelsCreated = 0;

    // Create models that don't exist yet
    for (final knownModel in knownModels) {
      final modelId = generateModelId(
        provider.id,
        knownModel.providerModelId,
      );

      // Skip if this provider already has the model, or if a usable provider
      // of the same type already owns the providerModelId. Ignore orphaned
      // rows whose provider no longer exists so a valid provider can repair
      // stale synced state by creating a fresh model row.
      if (_hasConfiguredKnownModel(
        knownModel.providerModelId,
        provider: provider,
        existingModels: existingModels,
        providersById: providersById,
      )) {
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

  static bool _hasConfiguredKnownModel(
    String providerModelId, {
    required AiConfigInferenceProvider provider,
    required List<AiConfigModel> existingModels,
    required Map<String, AiConfigInferenceProvider> providersById,
  }) {
    for (final model in existingModels) {
      if (model.providerModelId != providerModelId) {
        continue;
      }

      if (model.inferenceProviderId == provider.id) {
        return true;
      }

      final existingProvider = providersById[model.inferenceProviderId];
      if (existingProvider == null ||
          existingProvider.inferenceProviderType !=
              provider.inferenceProviderType) {
        continue;
      }

      if (existingProvider.isUsable) {
        return true;
      }
    }

    return false;
  }

  /// Backfills newly added known models for all existing inference providers.
  ///
  /// This ensures that when new models are added to `knownModelsByProvider`,
  /// existing users get them without having to re-create their providers.
  /// Safe to call on every startup — skips models that already exist.
  /// Provider-native model ids that were renamed under the user's feet.
  ///
  /// Keyed old -> new, scoped to the provider type that owns them. A rename
  /// only belongs here when the OLD id is unservable: rewriting a row that
  /// still works would silently move a user off a model they chose.
  static const renamedProviderModelIds =
      <InferenceProviderType, Map<String, String>>{
        // `deepseek-v4-flash` has been in the curated catalog since the
        // Melious provider landed, and the provider does not serve it — every
        // request returns "The model provider encountered an error", while the
        // dated snapshot answers normally. Both are listed by /v1/models.
        InferenceProviderType.melious: {
          'deepseek-v4-flash': meliousDeepseekV4FlashModelId,
        },
      };

  /// Rewrites rows whose provider-native id was renamed, in place.
  ///
  /// In place matters. Profile slots and direct-model overrides store the
  /// `AiConfigModel.id`, so editing the row's `providerModelId` repairs every
  /// reference at once; creating a new row instead would leave each of those
  /// references pointing at the dead id — which is what changing the catalog
  /// constant alone does, and it looks fixed while being worse, since the
  /// backfill then also adds a working row nobody points at.
  ///
  /// Runs before [backfillNewModels] so the repaired row already owns the new
  /// id when the backfill checks whether it needs creating.
  ///
  /// Returns the number of rows rewritten.
  Future<int> migrateRenamedModelIds() async {
    final providerConfigs = await _repository.getConfigsByType(
      AiConfigType.inferenceProvider,
    );
    final typeByProviderId = {
      for (final provider
          in providerConfigs.whereType<AiConfigInferenceProvider>())
        provider.id: provider.inferenceProviderType,
    };
    // Soft-deleted rows included: a deleted row still carries the dead id, and
    // leaving it renames nothing while a later undelete would resurrect it.
    final models = (await _repository.getConfigsByType(
      AiConfigType.model,
      includeDeleted: true,
    )).whereType<AiConfigModel>();

    var migrated = 0;
    for (final model in models) {
      final renames =
          renamedProviderModelIds[typeByProviderId[model.inferenceProviderId]];
      final replacement = renames?[model.providerModelId];
      if (replacement == null) continue;
      await _repository.saveConfig(
        model.copyWith(providerModelId: replacement),
      );
      migrated++;
    }

    if (migrated > 0) {
      developer.log(
        'Rewrote $migrated model row(s) onto renamed provider model ids',
        name: 'ModelPrepopulationService',
      );
    }
    return migrated;
  }

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
}
