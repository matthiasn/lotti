part of 'provider_prompt_setup_service.dart';

// =============================================================================
// Ollama FTUE (First Time User Experience) Setup
// =============================================================================

/// Result of the Ollama FTUE setup process.
///
/// Unlike the cloud providers, Ollama serves whatever models the user has
/// pulled locally — there is no canonical set we can pre-create. PR-1 only
/// installs the test category and the seeded `Local (Ollama)` profile; the
/// new connect modal (PR-2) will hit `/api/tags` to enumerate the user's
/// installed models and create rows for the ones they pick.
class OllamaFtueResult extends AiFtueResult {
  const OllamaFtueResult({
    required super.categoryCreated,
    super.categoryReused,
    super.categoryName,
    super.errors,
  }) : super(modelsCreated: 0, modelsVerified: 0);
}

/// Extension to add Ollama FTUE functionality to ProviderPromptSetupService.
extension OllamaFtueSetup on ProviderPromptSetupService {
  /// Performs FTUE setup for Ollama providers.
  ///
  /// Creates the shared FTUE test category bound to the seeded
  /// `Local (Ollama)` profile. No models are created at this stage —
  /// users pull whatever they want locally and the connect modal (PR-2)
  /// will enumerate them via `/api/tags`.
  ///
  /// The [excludedProviderModelIds] parameter is unused (Ollama has no
  /// preset to exclude from) but kept for signature symmetry with the
  /// other per-provider helpers — `runFtueSetupForType` dispatches by
  /// type and passes the same set to every arm.
  Future<OllamaFtueResult?> performOllamaFtueSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
    Set<String> excludedProviderModelIds = const {},
    bool createDefaultCategory = true,
  }) async {
    if (provider.inferenceProviderType != InferenceProviderType.ollama) {
      return null;
    }

    final categoryRepository = ref.read(categoryRepositoryProvider);

    CategoryDefinition? category;
    var categoryWasCreated = false;
    if (createDefaultCategory) {
      (category, categoryWasCreated) = await _createOrReuseCategory(
        categoryRepository: categoryRepository,
        categoryName: ftueOllamaCategoryName,
        categoryColor: ftueOllamaCategoryColor,
        defaultProfileId: profileLocalId,
      );
    }

    return OllamaFtueResult(
      categoryCreated: categoryWasCreated,
      categoryReused: !categoryWasCreated && category != null,
      categoryName: category?.name,
    );
  }
}
