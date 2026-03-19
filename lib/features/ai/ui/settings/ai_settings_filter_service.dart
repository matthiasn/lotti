import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';

/// Service responsible for filtering AI configurations based on user criteria
///
/// This service encapsulates all filtering logic and provides a clean interface
/// for applying various filters to different types of AI configurations.
class AiSettingsFilterService {
  const AiSettingsFilterService();

  /// Filters inference providers based on the current filter state
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
        if (!filterState.selectedProviders.contains(
          model.inferenceProviderId,
        )) {
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

  /// Helper method to check if searchable fields match the search query
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
