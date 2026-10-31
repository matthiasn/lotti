part of 'provider_prompt_setup_service.dart';

// =============================================================================
// Mistral FTUE (First Time User Experience) Setup
// =============================================================================

/// Result of the Mistral FTUE setup process.
class MistralFtueResult extends AiFtueResult {
  const MistralFtueResult({
    required super.modelsCreated,
    required super.modelsVerified,
    required super.categoryCreated,
    super.categoryName,
    super.errors,
  });
}

/// Extension to add Mistral FTUE functionality to ProviderPromptSetupService.
extension MistralFtueSetup on ProviderPromptSetupService {
  /// Performs comprehensive FTUE setup for Mistral providers.
  ///
  /// This creates:
  /// 1. Four models (thinking and vision/DeepSeek V4.1 Flash, high-end
  ///    thinking/Mistral Large 4, transcription/Voxtral Mini Transcribe 3,
  ///    read aloud/Voxtral TTS 3)
  /// 2. A test category with auto-selection configured
  Future<MistralFtueResult?> performMistralFtueSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
    Set<String> excludedProviderModelIds = const {},
    bool createDefaultCategory = true,
  }) async {
    if (provider.inferenceProviderType != InferenceProviderType.mistral) {
      return null;
    }

    final repository = ref.read(aiConfigRepositoryProvider);
    final categoryRepository = ref.read(categoryRepositoryProvider);

    final knownModels = getMistralFtueKnownModels();
    // coverage:ignore-start
    // Defensive guard against a stale const lookup table — see the
    // matching note on the Gemini helper above.
    if (knownModels == null) {
      return MistralFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
        errors: [
          context.messages.aiSetupResultKnownModelsMissing(
            aiProviderDisplayName(
              type: InferenceProviderType.mistral,
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
        (known: knownModels.thinking, id: ftueMistralThinkingModelId),
        (
          known: knownModels.highEndThinking,
          id: ftueMistralHighEndThinkingModelId,
        ),
        (
          known: knownModels.transcription,
          id: ftueMistralTranscriptionModelId,
        ),
        (known: knownModels.speech, id: ftueMistralSpeechModelId),
      ],
      excludedProviderModelIds: excludedProviderModelIds,
    );

    CategoryDefinition? category;
    var categoryWasCreated = false;
    if (createDefaultCategory) {
      (category, categoryWasCreated) = await _createOrReuseCategory(
        categoryRepository: categoryRepository,
        categoryName: ftueMistralCategoryName,
        categoryColor: ftueMistralCategoryColor,
      );
    }

    return MistralFtueResult(
      modelsCreated: modelResult.created.length,
      modelsVerified: modelResult.verified.length,
      categoryCreated: categoryWasCreated,
      categoryName: category?.name,
    );
  }
}
