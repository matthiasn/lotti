part of 'provider_prompt_setup_service.dart';

// =============================================================================
// Alibaba FTUE (First Time User Experience) Setup
// =============================================================================

/// Result of the Alibaba FTUE setup process.
class AlibabaFtueResult extends AiFtueResult {
  const AlibabaFtueResult({
    required super.modelsCreated,
    required super.modelsVerified,
    required super.categoryCreated,
    super.categoryReused,
    super.categoryName,
    super.errors,
  });
}

/// Extension to add Alibaba FTUE functionality to ProviderPromptSetupService.
extension AlibabaFtueSetup on ProviderPromptSetupService {
  /// Performs comprehensive FTUE setup for Alibaba providers.
  ///
  /// This creates:
  /// 1. Five models (Flash/Qwen Flash, Reasoning/Qwen 3.5 Plus,
  ///    Audio/Qwen3 Omni Flash, Vision/Qwen3 VL Flash, Image/Wan 2.6)
  /// 2. A test category bound to the seeded Chinese AI Profile
  ///
  /// The Chinese AI Profile (inference profile) is automatically created
  /// by ProfileSeedingService on app startup and links to these models.
  Future<AlibabaFtueResult?> performAlibabaFtueSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
    Set<String> excludedProviderModelIds = const {},
  }) async {
    if (provider.inferenceProviderType != InferenceProviderType.alibaba) {
      return null;
    }

    final repository = ref.read(aiConfigRepositoryProvider);
    final categoryRepository = ref.read(categoryRepositoryProvider);

    final knownModels = getAlibabaFtueKnownModels();
    // coverage:ignore-start
    // Defensive guard against a stale const lookup table — see the
    // matching note on the Gemini helper above.
    if (knownModels == null) {
      return AlibabaFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        categoryCreated: false,
        errors: [
          context.messages.aiSetupResultKnownModelsMissing(
            aiProviderDisplayName(
              type: InferenceProviderType.alibaba,
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
        (known: knownModels.flash, id: ftueAlibabaFlashModelId),
        (known: knownModels.reasoning, id: ftueAlibabaReasoningModelId),
        (known: knownModels.audio, id: ftueAlibabaAudioModelId),
        (known: knownModels.vision, id: ftueAlibabaVisionModelId),
        (known: knownModels.image, id: ftueAlibabaImageModelId),
      ],
      excludedProviderModelIds: excludedProviderModelIds,
    );

    final (category, categoryWasCreated) = await _createOrReuseCategory(
      categoryRepository: categoryRepository,
      categoryName: ftueAlibabaCategoryName,
      categoryColor: ftueAlibabaCategoryColor,
      defaultProfileId: profileAlibabaId,
    );

    return AlibabaFtueResult(
      modelsCreated: modelResult.created.length,
      modelsVerified: modelResult.verified.length,
      categoryCreated: categoryWasCreated,
      categoryReused: !categoryWasCreated && category != null,
      categoryName: category?.name,
    );
  }
}
