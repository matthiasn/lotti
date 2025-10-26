import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/utils/platform.dart';

/// Helper class to filter AI prompts based on platform capabilities
class PromptCapabilityFilter {
  PromptCapabilityFilter(this.ref);

  final Ref ref;

  /// Check if a prompt is available on the current platform
  ///
  /// Returns false for prompts using local-only models (Whisper, Ollama, Gemini 3N)
  /// when running on mobile platforms
  Future<bool> isPromptAvailableOnPlatform(AiConfigPrompt prompt) async {
    // Desktop supports all models
    if (isDesktop) {
      return true;
    }

    // On mobile, check if the prompt uses local-only models
    final model = await ref
        .read(aiConfigRepositoryProvider)
        .getConfigById(prompt.defaultModelId);

    if (model == null || model is! AiConfigModel) {
      return false;
    }

    // Get the inference provider for this model
    final provider = await ref
        .read(aiConfigRepositoryProvider)
        .getConfigById(model.inferenceProviderId);

    if (provider == null || provider is! AiConfigInferenceProvider) {
      return false;
    }

    // Check if this is a local-only provider type
    return !_isLocalOnlyProvider(provider.inferenceProviderType);
  }

  /// Check if an inference provider type is local-only
  bool _isLocalOnlyProvider(InferenceProviderType providerType) {
    return providerType == InferenceProviderType.whisper ||
        providerType == InferenceProviderType.ollama ||
        providerType == InferenceProviderType.gemma3n;
  }

  /// Filter a list of prompts to only include those available on current platform
  Future<List<AiConfigPrompt>> filterPromptsByPlatform(
    List<AiConfigPrompt> prompts,
  ) async {
    final availablePrompts = <AiConfigPrompt>[];

    for (final prompt in prompts) {
      if (await isPromptAvailableOnPlatform(prompt)) {
        availablePrompts.add(prompt);
      }
    }

    return availablePrompts;
  }

  /// Get the first available prompt from a list of prompt IDs
  ///
  /// This is useful for finding a fallback when the default prompt
  /// is not available on the current platform
  Future<AiConfigPrompt?> getFirstAvailablePrompt(
    List<String> promptIds,
  ) async {
    for (final promptId in promptIds) {
      final config =
          await ref.read(aiConfigRepositoryProvider).getConfigById(promptId);

      if (config is AiConfigPrompt &&
          await isPromptAvailableOnPlatform(config)) {
        return config;
      }
    }

    return null;
  }
}

/// Provider for the prompt capability filter
final promptCapabilityFilterProvider = Provider<PromptCapabilityFilter>((ref) {
  return PromptCapabilityFilter(ref);
});
