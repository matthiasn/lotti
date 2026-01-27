import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

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

    /// Selected response types for filtering prompts (only used on Prompts tab)
    @Default({}) Set<AiResponseType> selectedResponseTypes,

    /// Currently active tab
    @Default(AiSettingsTab.providers) AiSettingsTab activeTab,

    /// Whether selection mode is active (only used on Prompts tab)
    @Default(false) bool selectionMode,

    /// Selected prompt IDs for bulk operations (only used on Prompts tab)
    @Default({}) Set<String> selectedPromptIds,
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
  /// Determines if model-specific filters are active
  bool get hasModelFilters =>
      selectedProviders.isNotEmpty ||
      selectedCapabilities.isNotEmpty ||
      reasoningFilter;

  /// Determines if prompt-specific filters are active
  bool get hasPromptFilters =>
      selectedProviders.isNotEmpty || selectedResponseTypes.isNotEmpty;

  /// Determines if any filters are active for the current tab
  bool get hasActiveFilters {
    switch (activeTab) {
      case AiSettingsTab.providers:
        return false;
      case AiSettingsTab.models:
        return hasModelFilters;
      case AiSettingsTab.prompts:
        return hasPromptFilters;
    }
  }

  /// Resets only model-specific filters (preserves search query)
  AiSettingsFilterState resetModelFilters() => copyWith(
        selectedProviders: const {},
        selectedCapabilities: const {},
        reasoningFilter: false,
      );

  /// Resets only prompt-specific filters (preserves search query)
  AiSettingsFilterState resetPromptFilters() => copyWith(
        selectedProviders: const {},
        selectedResponseTypes: const {},
      );

  /// Resets filters for the current active tab
  AiSettingsFilterState resetCurrentTabFilters() {
    switch (activeTab) {
      case AiSettingsTab.providers:
        return this;
      case AiSettingsTab.models:
        return resetModelFilters();
      case AiSettingsTab.prompts:
        return resetPromptFilters();
    }
  }

  /// Whether any prompts are selected
  bool get hasSelectedPrompts => selectedPromptIds.isNotEmpty;

  /// Number of selected prompts
  int get selectedPromptCount => selectedPromptIds.length;

  /// Toggles selection for a specific prompt
  AiSettingsFilterState togglePromptSelection(String promptId) {
    final newSelection = Set<String>.from(selectedPromptIds);
    if (newSelection.contains(promptId)) {
      newSelection.remove(promptId);
    } else {
      newSelection.add(promptId);
    }
    return copyWith(selectedPromptIds: newSelection);
  }

  /// Selects all prompts from the given list
  AiSettingsFilterState selectAllPrompts(List<String> promptIds) {
    return copyWith(selectedPromptIds: Set<String>.from(promptIds));
  }

  /// Clears all selected prompts
  AiSettingsFilterState clearSelection() {
    return copyWith(selectedPromptIds: const {});
  }

  /// Exits selection mode and clears selection
  AiSettingsFilterState exitSelectionMode() {
    return copyWith(
      selectionMode: false,
      selectedPromptIds: const {},
    );
  }
}

/// Extension to add localized display names for AiSettingsTab
extension AiSettingsTabX on AiSettingsTab {
  /// Returns the localized display name for the tab
  String getLocalizedDisplayName(BuildContext context) {
    switch (this) {
      case AiSettingsTab.providers:
        return context.messages.aiSettingsTabProviders;
      case AiSettingsTab.models:
        return context.messages.aiSettingsTabModels;
      case AiSettingsTab.prompts:
        return context.messages.aiSettingsTabPrompts;
    }
  }
}
