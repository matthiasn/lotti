part of 'provider_prompt_setup_service.dart';

// =============================================================================
// OpenAI FTUE (First Time User Experience) Setup
// =============================================================================

/// Result of the OpenAI FTUE setup process.
class OpenAiFtueResult extends AiFtueResult {
  const OpenAiFtueResult({
    required super.modelsCreated,
    required super.modelsVerified,
    required super.categoryCreated,
    super.categoryReused,
    super.categoryName,
    super.errors,
  });
}

/// Extension to add OpenAI FTUE functionality to ProviderPromptSetupService.
extension OpenAiFtueSetup on ProviderPromptSetupService {
  /// Performs comprehensive FTUE setup for OpenAI providers.
  ///
  /// This creates:
  /// 1. Four models (Flash/GPT-5 Nano, Reasoning/GPT-5.2, Audio/GPT-4o
  ///    Transcribe, Image/GPT Image 1.5)
  /// 2. A test category with auto-selection configured
  Future<OpenAiFtueResult?> performOpenAiFtueSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
    Set<String> excludedProviderModelIds = const {},
    bool createDefaultCategory = true,
  }) async {
    if (provider.inferenceProviderType != InferenceProviderType.openAi) {
      return null;
    }

    final repository = ref.read(aiConfigRepositoryProvider);
    final categoryRepository = ref.read(categoryRepositoryProvider);

    final knownModels = getOpenAiFtueKnownModels();
    // coverage:ignore-start
    // Defensive guard against a stale const lookup table — see the
    // matching note on the Gemini helper above.
    if (knownModels == null) {
      return OpenAiFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
        errors: [
          context.messages.aiSetupResultKnownModelsMissing(
            aiProviderDisplayName(
              type: InferenceProviderType.openAi,
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
        (known: knownModels.flash, id: ftueOpenAiFlashModelId),
        (known: knownModels.reasoning, id: ftueOpenAiReasoningModelId),
        (known: knownModels.audio, id: ftueOpenAiAudioModelId),
        (known: knownModels.image, id: ftueOpenAiImageModelId),
      ],
      excludedProviderModelIds: excludedProviderModelIds,
    );

    CategoryDefinition? category;
    var categoryWasCreated = false;
    if (createDefaultCategory) {
      (category, categoryWasCreated) = await _createOrReuseCategory(
        categoryRepository: categoryRepository,
        categoryName: ftueOpenAiCategoryName,
        categoryColor: ftueOpenAiCategoryColor,
      );
    }

    return OpenAiFtueResult(
      modelsCreated: modelResult.created.length,
      modelsVerified: modelResult.verified.length,
      categoryCreated: categoryWasCreated,
      categoryReused: !categoryWasCreated && category != null,
      categoryName: category?.name,
    );
  }
}
