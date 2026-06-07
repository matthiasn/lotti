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
    super.categoryReused,
    super.categoryName,
    super.errors,
  });
}

/// Extension to add Mistral FTUE functionality to ProviderPromptSetupService.
extension MistralFtueSetup on ProviderPromptSetupService {
  /// Performs comprehensive FTUE setup for Mistral providers.
  ///
  /// This creates:
  /// 1. Three models (Fast/Mistral Small, Reasoning/Magistral Medium,
  ///    Audio/Voxtral Mini)
  /// 2. A test category with auto-selection configured
  Future<MistralFtueResult?> performMistralFtueSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
    Set<String> excludedProviderModelIds = const {},
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
        (known: knownModels.flash, id: ftueMistralFlashModelId),
        (known: knownModels.reasoning, id: ftueMistralReasoningModelId),
        (known: knownModels.audio, id: ftueMistralAudioModelId),
      ],
      excludedProviderModelIds: excludedProviderModelIds,
    );

    final (category, categoryWasCreated) = await _createOrReuseCategory(
      categoryRepository: categoryRepository,
      categoryName: ftueMistralCategoryName,
      categoryColor: ftueMistralCategoryColor,
    );

    return MistralFtueResult(
      modelsCreated: modelResult.created.length,
      modelsVerified: modelResult.verified.length,
      categoryCreated: categoryWasCreated,
      categoryReused: !categoryWasCreated && category != null,
      categoryName: category?.name,
    );
  }
}
