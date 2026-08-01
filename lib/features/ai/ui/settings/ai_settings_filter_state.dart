import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/ai/model/ai_config.dart';

part 'ai_settings_filter_state.freezed.dart';

/// Represents the complete filter state for AI Settings page
///
/// This model encapsulates all filtering criteria that can be applied
/// to AI configurations across providers and models.
@freezed
abstract class AiSettingsFilterState with _$AiSettingsFilterState {
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
  profiles,
}

/// Extension to add filtering capabilities to AiSettingsFilterState
extension AiSettingsFilterStateX on AiSettingsFilterState {
  /// Determines if model-specific filters are active
  bool get hasModelFilters =>
      selectedProviders.isNotEmpty ||
      selectedCapabilities.isNotEmpty ||
      reasoningFilter;

  /// Determines if any filters are active for the current tab
  bool get hasActiveFilters {
    switch (activeTab) {
      case AiSettingsTab.providers:
      case AiSettingsTab.profiles:
        return false;
      case AiSettingsTab.models:
        return hasModelFilters;
    }
  }

  /// Resets only model-specific filters (preserves search query)
  AiSettingsFilterState resetModelFilters() => copyWith(
    selectedProviders: const {},
    selectedCapabilities: const {},
    reasoningFilter: false,
  );

  /// Resets filters for the current active tab
  AiSettingsFilterState resetCurrentTabFilters() {
    switch (activeTab) {
      case AiSettingsTab.providers:
      case AiSettingsTab.profiles:
        return this;
      case AiSettingsTab.models:
        return resetModelFilters();
    }
  }
}
