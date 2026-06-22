part of 'provider_prompt_setup_service.dart';

/// Result of the Gemini FTUE setup process.
class GeminiFtueResult extends AiFtueResult {
  const GeminiFtueResult({
    required super.modelsCreated,
    required super.modelsVerified,
    required super.categoryCreated,
    super.categoryReused,
    super.categoryName,
    super.errors,
  });
}

/// Extension to add Gemini FTUE functionality to ProviderPromptSetupService.
extension GeminiFtueSetup on ProviderPromptSetupService {
  /// Performs comprehensive FTUE setup for Gemini providers.
  ///
  /// This creates:
  /// 1. Three models (Flash, Pro, Nano Banana Pro) if they don't exist
  /// 2. A test category with auto-selection configured
  ///
  /// Any `providerModelId` in [excludedProviderModelIds] is skipped — it
  /// is neither created nor verified. The caller (the preview modal)
  /// uses this to honor user-unticked rows without a post-hoc delete.
  Future<GeminiFtueResult?> performGeminiFtueSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
    Set<String> excludedProviderModelIds = const {},
    bool createDefaultCategory = true,
  }) async {
    if (provider.inferenceProviderType != InferenceProviderType.gemini) {
      return null;
    }

    final repository = ref.read(aiConfigRepositoryProvider);
    final categoryRepository = ref.read(categoryRepositoryProvider);

    final knownModels = getFtueKnownModels();
    // coverage:ignore-start
    // Defensive: `getFtueKnownModels()` only returns null if the
    // canonical `geminiModels` const table is missing the FTUE model
    // ids — unreachable in production, kept as a hard guard so a stale
    // checkout fails loudly instead of seeding a broken config.
    if (knownModels == null) {
      return GeminiFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
        errors: [
          context.messages.aiSetupResultKnownModelsMissing(
            aiProviderDisplayName(
              type: InferenceProviderType.gemini,
              messages: context.messages,
            ),
          ),
        ],
      );
    }
    // coverage:ignore-end

    final modelResult = await _ensureModelsExist(
      repository: repository,
      providerId: provider.id,
      providerType: provider.inferenceProviderType,
      modelConfigs: [
        (known: knownModels.flash, id: ftueFlashModelId),
        (known: knownModels.pro, id: ftueProModelId),
        (known: knownModels.image, id: ftueImageModelId),
      ],
      excludedProviderModelIds: excludedProviderModelIds,
    );

    CategoryDefinition? category;
    var categoryWasCreated = false;
    if (createDefaultCategory) {
      (category, categoryWasCreated) = await _createOrReuseCategory(
        categoryRepository: categoryRepository,
        categoryName: ftueGeminiCategoryName,
        categoryColor: ftueGeminiCategoryColor,
        defaultProfileId: profileGeminiFlashId,
        defaultTemplateId: lauraTemplateId,
      );
    }

    return GeminiFtueResult(
      modelsCreated: modelResult.created.length,
      modelsVerified: modelResult.verified.length,
      categoryCreated: categoryWasCreated,
      categoryReused: !categoryWasCreated && category != null,
      categoryName: category?.name,
    );
  }
}
