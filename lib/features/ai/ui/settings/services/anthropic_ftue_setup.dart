part of 'provider_prompt_setup_service.dart';

// =============================================================================
// Anthropic FTUE (First Time User Experience) Setup
// =============================================================================

/// Result of the Anthropic FTUE setup process.
class AnthropicFtueResult extends AiFtueResult {
  const AnthropicFtueResult({
    required super.modelsCreated,
    required super.modelsVerified,
    required super.categoryCreated,
    super.categoryReused,
    super.categoryName,
    super.errors,
  });
}

/// Extension to add Anthropic FTUE functionality to ProviderPromptSetupService.
extension AnthropicFtueSetup on ProviderPromptSetupService {
  /// Performs comprehensive FTUE setup for Anthropic providers.
  ///
  /// Creates a reasoning model (Claude Sonnet 4) and a fast model
  /// (Claude Haiku 3.5) along with the shared FTUE test category.
  /// Anthropic ships no native transcription or image-generation models,
  /// so those skill slots remain unbound on the seeded profile.
  Future<AnthropicFtueResult?> performAnthropicFtueSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
    Set<String> excludedProviderModelIds = const {},
    bool createDefaultCategory = true,
  }) async {
    if (provider.inferenceProviderType != InferenceProviderType.anthropic) {
      return null;
    }

    final repository = ref.read(aiConfigRepositoryProvider);
    final categoryRepository = ref.read(categoryRepositoryProvider);

    final knownModels = getAnthropicFtueKnownModels();
    // coverage:ignore-start
    // Defensive guard against a stale const lookup table — see the
    // matching note on the Gemini helper above.
    if (knownModels == null) {
      return AnthropicFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
        errors: [
          context.messages.aiSetupResultKnownModelsMissing(
            aiProviderDisplayName(
              type: InferenceProviderType.anthropic,
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
        (known: knownModels.reasoning, id: ftueAnthropicReasoningModelId),
        (known: knownModels.flash, id: ftueAnthropicFlashModelId),
      ],
      excludedProviderModelIds: excludedProviderModelIds,
    );

    CategoryDefinition? category;
    var categoryWasCreated = false;
    if (createDefaultCategory) {
      (category, categoryWasCreated) = await _createOrReuseCategory(
        categoryRepository: categoryRepository,
        categoryName: ftueAnthropicCategoryName,
        categoryColor: ftueAnthropicCategoryColor,
        defaultProfileId: profileAnthropicId,
      );
    }

    return AnthropicFtueResult(
      modelsCreated: modelResult.created.length,
      modelsVerified: modelResult.verified.length,
      categoryCreated: categoryWasCreated,
      categoryReused: !categoryWasCreated && category != null,
      categoryName: category?.name,
    );
  }
}
