import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

part 'ai_settings_filter_state.freezed.dart';

/// Represents the complete filter state for AI Settings page
///
/// This model encapsulates all filtering criteria that can be applied
/// to AI configurations across providers, models, and prompts.
///
/// **Usage:**
/// ```dart
/// // Create initial state
/// final state = AiSettingsFilterState.initial();
///
/// // Update search query
/// final newState = state.copyWith(searchQuery: 'anthropic');
///
/// // Add capability filter
/// final filtered = state.copyWith(
///   selectedCapabilities: {...state.selectedCapabilities, Modality.image}
/// );
/// ```
@freezed
class AiSettingsFilterState with _$AiSettingsFilterState {
  const factory AiSettingsFilterState({
    /// Text query for searching across all AI configuration names and descriptions
    @Default('') String searchQuery,

    /// Selected provider IDs for filtering models (only used on Models tab)
    @Default({}) Set<String> selectedProviders,

    /// Selected capabilities for filtering models (only used on Models tab)
    @Default({}) Set<Modality> selectedCapabilities,

    /// Whether to show only reasoning-capable models (only used on Models tab)
    @Default(false) bool reasoningFilter,

    /// Currently active tab
    @Default(AiSettingsTab.providers) AiSettingsTab activeTab,
  }) = _AiSettingsFilterState;

  /// Creates initial filter state
  factory AiSettingsFilterState.initial() => const AiSettingsFilterState();
}

/// Enum representing the available tabs in AI Settings
enum AiSettingsTab {
  providers,
  models,
  prompts;

  /// Human-readable display name for the tab
  String get displayName {
    switch (this) {
      case AiSettingsTab.providers:
        return 'Providers';
      case AiSettingsTab.models:
        return 'Models';
      case AiSettingsTab.prompts:
        return 'Prompts';
    }
  }
}

/// Extension to add filtering capabilities to AiSettingsFilterState
extension AiSettingsFilterStateX on AiSettingsFilterState {
  /// Determines if any filters are currently active
  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      selectedProviders.isNotEmpty ||
      selectedCapabilities.isNotEmpty ||
      reasoningFilter;

  /// Determines if model-specific filters are active
  bool get hasModelFilters =>
      selectedProviders.isNotEmpty ||
      selectedCapabilities.isNotEmpty ||
      reasoningFilter;

  /// Resets all filters to their default values
  AiSettingsFilterState resetFilters() => copyWith(
        searchQuery: '',
        selectedProviders: const {},
        selectedCapabilities: const {},
        reasoningFilter: false,
      );

  /// Resets only model-specific filters (preserves search query)
  AiSettingsFilterState resetModelFilters() => copyWith(
        selectedProviders: const {},
        selectedCapabilities: const {},
        reasoningFilter: false,
      );
}
