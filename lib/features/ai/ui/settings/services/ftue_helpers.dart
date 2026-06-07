part of 'provider_prompt_setup_service.dart';

/// Shared model-row reconciler used by every per-provider FTUE helper.
///
/// For each preset (known, providerModelId) entry:
/// - if the user unticked the row, skip it entirely (no save, no count);
/// - if a usable row already exists with that providerModelId,
///   mark it `verified`;
/// - otherwise create a fresh row, save it, and mark it `created`.
Future<_FtueModelTally> _ensureModelsExist({
  required AiConfigRepository repository,
  required String providerId,
  required InferenceProviderType providerType,
  required List<({KnownModel known, String id})> modelConfigs,
  Set<String> excludedProviderModelIds = const {},
}) async {
  final allModels = await repository.getConfigsByType(AiConfigType.model);
  final existingModels = allModels.whereType<AiConfigModel>().toList(
    growable: false,
  );
  final allProviders = await repository.getConfigsByType(
    AiConfigType.inferenceProvider,
  );
  final providersById = {
    for (final provider in allProviders.whereType<AiConfigInferenceProvider>())
      provider.id: provider,
  };

  final created = <AiConfigModel>[];
  final verified = <AiConfigModel>[];
  const uuid = Uuid();

  for (final config in modelConfigs) {
    if (excludedProviderModelIds.contains(config.id)) {
      continue;
    }

    final existing = findConfiguredKnownModel(
      config.id,
      providerId: providerId,
      providerType: providerType,
      existingModels: existingModels,
      providersById: providersById,
    );

    if (existing != null) {
      verified.add(existing);
    } else {
      final model = config.known.toAiConfigModel(
        id: uuid.v4(),
        inferenceProviderId: providerId,
      );
      await repository.saveConfig(model);
      created.add(model);
    }
  }

  return (created: created, verified: verified);
}

/// Finds an already-configured model matching [providerModelId]: either a
/// model bound directly to [providerId], or one bound to another *usable*
/// provider of the same [providerType] (so FTUE setup verifies instead of
/// seeding a duplicate row).
@visibleForTesting
AiConfigModel? findConfiguredKnownModel(
  String providerModelId, {
  required String providerId,
  required InferenceProviderType providerType,
  required List<AiConfigModel> existingModels,
  required Map<String, AiConfigInferenceProvider> providersById,
}) {
  for (final model in existingModels) {
    if (model.providerModelId != providerModelId) {
      continue;
    }

    if (model.inferenceProviderId == providerId) {
      return model;
    }

    final provider = providersById[model.inferenceProviderId];
    if (provider == null || provider.inferenceProviderType != providerType) {
      continue;
    }

    if (provider.isUsable) {
      return model;
    }
  }

  return null;
}

/// Shared "create or reuse the FTUE test category" helper. Looks up an
/// existing (non-deleted) category by exact name; otherwise creates a
/// fresh one with the given color and the optional default profile +
/// agent template bindings.
Future<(CategoryDefinition?, bool)> _createOrReuseCategory({
  required CategoryRepository categoryRepository,
  required String categoryName,
  required String categoryColor,
  String? defaultProfileId,
  String? defaultTemplateId,
}) async {
  final allCategories = await categoryRepository.getAllCategories();
  final existingCategory = allCategories
      .where((c) => c.name == categoryName && c.deletedAt == null)
      .firstOrNull;

  if (existingCategory != null) {
    return (existingCategory, false);
  }

  final category = await categoryRepository.createCategory(
    name: categoryName,
    color: categoryColor,
    defaultProfileId: defaultProfileId,
    defaultTemplateId: defaultTemplateId,
  );

  return (category, true);
}
