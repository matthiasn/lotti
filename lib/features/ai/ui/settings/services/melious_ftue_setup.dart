part of 'provider_prompt_setup_service.dart';

// =============================================================================
// Melious FTUE (First Time User Experience) Setup
// =============================================================================

/// Result of the Melious FTUE setup process.
class MeliousFtueResult extends AiFtueResult {
  const MeliousFtueResult({
    required super.modelsCreated,
    required super.modelsVerified,
    required super.categoryCreated,
    super.categoryReused,
    super.categoryName,
    super.errors,
  });
}

/// Extension to add Melious FTUE functionality to ProviderPromptSetupService.
extension MeliousFtueSetup on ProviderPromptSetupService {
  /// Performs FTUE setup for Melious providers.
  ///
  /// This verifies or creates the default thinking, advanced thinking, and
  /// Whisper transcription models, then creates the Melious test category
  /// bound to the default Melious profile.
  Future<MeliousFtueResult?> performMeliousFtueSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
    Set<String> excludedProviderModelIds = const {},
    bool createDefaultCategory = true,
  }) async {
    if (provider.inferenceProviderType != InferenceProviderType.melious) {
      return null;
    }

    final repository = ref.read(aiConfigRepositoryProvider);
    final categoryRepository = ref.read(categoryRepositoryProvider);

    final knownModels = getMeliousFtueKnownModels();
    // coverage:ignore-start
    // Defensive guard against a stale const lookup table.
    if (knownModels == null) {
      return MeliousFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
        errors: [
          context.messages.aiSetupResultKnownModelsMissing(
            aiProviderDisplayName(
              type: InferenceProviderType.melious,
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
        (known: knownModels.thinking, id: ftueMeliousThinkingModelId),
        (
          known: knownModels.advancedThinking,
          id: ftueMeliousAdvancedThinkingModelId,
        ),
        (known: knownModels.whisper, id: ftueMeliousWhisperModelId),
        (known: knownModels.whisperTurbo, id: ftueMeliousWhisperTurboModelId),
      ],
      excludedProviderModelIds: excludedProviderModelIds,
    );

    CategoryDefinition? category;
    var categoryWasCreated = false;
    if (createDefaultCategory) {
      (category, categoryWasCreated) = await _createOrReuseCategory(
        categoryRepository: categoryRepository,
        categoryName: ftueMeliousCategoryName,
        categoryColor: ftueMeliousCategoryColor,
        defaultProfileId: profileMeliousId,
      );
    }

    return MeliousFtueResult(
      modelsCreated: modelResult.created.length,
      modelsVerified: modelResult.verified.length,
      categoryCreated: categoryWasCreated,
      categoryReused: !categoryWasCreated && category != null,
      categoryName: category?.name,
    );
  }
}
