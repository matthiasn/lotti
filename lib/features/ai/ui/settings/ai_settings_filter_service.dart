import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';

/// Service responsible for filtering AI configurations based on user criteria
///
/// This service encapsulates all filtering logic and provides a clean interface
/// for applying various filters to different types of AI configurations.
///
/// **Design Principles:**
/// - Pure functions: No side effects, same input always produces same output
/// - Type-safe: Uses generics and sealed classes for compile-time safety
/// - Testable: All methods can be unit tested in isolation
/// - Single responsibility: Only handles filtering, no UI or state management
///
/// **Usage:**
/// ```dart
/// final service = AiSettingsFilterService();
/// final filterState = AiSettingsFilterState(searchQuery: 'claude');
///
/// final filteredProviders = service.filterProviders(providers, filterState);
/// final filteredModels = service.filterModels(models, filterState);
/// ```
class AiSettingsFilterService {
  const AiSettingsFilterService();

  /// Filters inference providers based on the current filter state
  ///
  /// **Filters Applied:**
  /// - Text search: Matches against provider name and description
  ///
  /// **Parameters:**
  /// - [providers]: List of inference providers to filter
  /// - [filterState]: Current filter criteria
  ///
  /// **Returns:** Filtered list of inference providers
  List<AiConfigInferenceProvider> filterProviders(
    List<AiConfigInferenceProvider> providers,
    AiSettingsFilterState filterState,
  ) {
    return providers.where((provider) {
      return _matchesTextSearch(
        text: filterState.searchQuery,
        searchableFields: [
          provider.name,
          provider.description ?? '',
        ],
      );
    }).toList();
  }

  /// Filters AI models based on the current filter state
  ///
  /// **Filters Applied:**
  /// - Text search: Matches against model name and description
  /// - Provider filter: Only shows models from selected providers
  /// - Capability filter: Only shows models with selected capabilities
  /// - Reasoning filter: Only shows reasoning-capable models
  ///
  /// **Parameters:**
  /// - [models]: List of AI models to filter
  /// - [filterState]: Current filter criteria
  ///
  /// **Returns:** Filtered list of AI models
  List<AiConfigModel> filterModels(
    List<AiConfigModel> models,
    AiSettingsFilterState filterState,
  ) {
    return models.where((model) {
      // Text search filter
      if (!_matchesTextSearch(
        text: filterState.searchQuery,
        searchableFields: [
          model.name,
          model.description ?? '',
        ],
      )) {
        return false;
      }

      // Provider filter - only apply if providers are selected
      if (filterState.selectedProviders.isNotEmpty) {
        if (!filterState.selectedProviders
            .contains(model.inferenceProviderId)) {
          return false;
        }
      }

      // Capability filter - model must have ALL selected capabilities
      if (filterState.selectedCapabilities.isNotEmpty) {
        if (!filterState.selectedCapabilities.every(
          (capability) => model.inputModalities.contains(capability),
        )) {
          return false;
        }
      }

      // Reasoning filter - only apply if reasoning filter is enabled
      if (filterState.reasoningFilter && !model.isReasoningModel) {
        return false;
      }

      return true;
    }).toList();
  }

  /// Filters AI prompts based on the current filter state
  ///
  /// **Filters Applied:**
  /// - Text search: Matches against prompt name and description
  /// - Provider filter: Only shows prompts whose models belong to selected providers.
  ///   Requires [allModels] to be provided.
  ///
  /// **Parameters:**
  /// - [prompts]: List of AI prompts to filter
  /// - [filterState]: Current filter criteria
  /// - [allModels]: Optional list of all models, required for provider filtering.
  ///
  /// **Returns:** Filtered list of AI prompts
  List<AiConfigPrompt> filterPrompts(
    List<AiConfigPrompt> prompts,
    AiSettingsFilterState filterState, {
    List<AiConfigModel>? allModels,
  }) {
    // For efficiency, create a lookup map of modelId -> providerId
    final modelIdToProviderIdMap = filterState.selectedProviders.isNotEmpty &&
            allModels != null
        ? {for (final model in allModels) model.id: model.inferenceProviderId}
        : null;

    return prompts.where((prompt) {
      // Text search filter
      if (!_matchesTextSearch(
        text: filterState.searchQuery,
        searchableFields: [
          prompt.name,
          prompt.description ?? '',
        ],
      )) {
        return false;
      }

      // Provider filter - only apply if providers are selected and models are provided
      if (modelIdToProviderIdMap != null) {
        // Check if ANY of the prompt's models belong to the selected providers
        final hasMatchingModel = prompt.modelIds.any((modelId) {
          final providerId = modelIdToProviderIdMap[modelId];
          return providerId != null &&
              filterState.selectedProviders.contains(providerId);
        });

        if (!hasMatchingModel) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Helper method to check if searchable fields match the search query
  ///
  /// **Search Logic:**
  /// - Case-insensitive matching
  /// - Matches if any field contains the search text
  /// - Empty search query matches everything
  ///
  /// **Parameters:**
  /// - [text]: The search query text
  /// - [searchableFields]: List of fields to search within
  ///
  /// **Returns:** True if any field matches the search query
  bool _matchesTextSearch({
    required String text,
    required List<String> searchableFields,
  }) {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return true;

    final searchLower = trimmedText.toLowerCase();
    return searchableFields.any(
      (field) => field.toLowerCase().contains(searchLower),
    );
  }
}
