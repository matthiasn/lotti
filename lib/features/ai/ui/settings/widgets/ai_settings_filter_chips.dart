import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_chip_constants.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_filter_chips_row.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Widget that displays filter chips for AI model filtering
///
/// This widget provides provider, capability, and reasoning filters
/// specifically for the Models tab in AI Settings.
///
/// **Features:**
/// - Provider filter chips (dynamically loaded)
/// - Capability filter chips (Vision, Audio)
/// - Reasoning filter toggle
/// - Proper spacing and typography
///
/// **Usage:**
/// ```dart
/// AiSettingsFilterChips(
///   filterState: currentFilterState,
///   onFilterChanged: (newState) => updateFilters(newState),
/// )
/// ```
class AiSettingsFilterChips extends ConsumerWidget {
  const AiSettingsFilterChips({
    required this.filterState,
    required this.onFilterChanged,
    this.onDeleteSelected,
    super.key,
  });

  /// Current filter state
  final AiSettingsFilterState filterState;

  /// Callback when filter state changes
  final ValueChanged<AiSettingsFilterState> onFilterChanged;

  /// Callback when delete selected button is pressed (only used on Prompts tab)
  final VoidCallback? onDeleteSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provider Filter (shown on both Models and Prompts tabs)
            _buildProviderFilter(context, ref),

            // Capability Filters (only shown on Models tab)
            if (filterState.activeTab == AiSettingsTab.models)
              _buildCapabilityFilters(context),

            // Response Type Filters (only shown on Prompts tab)
            if (filterState.activeTab == AiSettingsTab.prompts)
              _buildResponseTypeFilters(context),
          ],
        ),
      ),
    );
  }

  /// Builds the provider filter section
  Widget _buildProviderFilter(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: ProviderChipConstants.chipSpacing,
      ),
      child: Wrap(
        spacing: ProviderChipConstants.chipSpacing,
        runSpacing: ProviderChipConstants.chipSpacing,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Provider chips row (this returns a Wrap internally)
          ProviderFilterChipsRow(
            selectedProviderIds: filterState.selectedProviders,
            onChanged: (newProviders) {
              onFilterChanged(filterState.copyWith(
                selectedProviders: newProviders,
              ));
            },
            useStyledChips: true,
          ),

          // Clear filters button - shown when there are active filters
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return ScaleTransition(
                scale: animation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: filterState.hasActiveFilters
                ? ActionChip(
                    key: const ValueKey('clear_button'),
                    avatar: Icon(
                      Icons.clear,
                      size: 14,
                      color: context.colorScheme.error.withValues(alpha: 0.7),
                    ),
                    label: Text(
                      context.messages.aiSettingsClearFiltersButton,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: context.colorScheme.error.withValues(alpha: 0.8),
                      ),
                    ),
                    onPressed: () {
                      onFilterChanged(filterState.resetCurrentTabFilters());
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: Colors.transparent,
                    side: BorderSide(
                      color: context.colorScheme.error.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.filterChipPaddingHorizontal,
                      vertical: AppTheme.filterChipPaddingVertical,
                    ),
                    tooltip: context.messages.aiSettingsClearAllFiltersTooltip,
                  )
                : const SizedBox.shrink(key: ValueKey('no_clear_button')),
          ),

          // Selection toggle - only on Prompts tab
          if (filterState.activeTab == AiSettingsTab.prompts)
            _buildSelectionToggle(context),
        ],
      ),
    );
  }

  /// Builds just the selection mode toggle chip
  Widget _buildSelectionToggle(BuildContext context) {
    return FilterChip(
      avatar: Icon(
        filterState.selectionMode
            ? Icons.check_box
            : Icons.check_box_outline_blank,
        size: 16,
        color: filterState.selectionMode
            ? context.colorScheme.primary
            : context.colorScheme.onSurfaceVariant
                .withValues(alpha: AppTheme.alphaFilterChipTextUnselected),
      ),
      label: Text(context.messages.aiSettingsSelectLabel),
      selected: filterState.selectionMode,
      onSelected: (selected) {
        onFilterChanged(filterState.copyWith(
          selectionMode: selected,
          selectedPromptIds:
              selected ? filterState.selectedPromptIds : const {},
        ));
      },
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: context.colorScheme.surfaceContainerHigh
          .withValues(alpha: AppTheme.alphaFilterChipBackground),
      selectedColor: context.colorScheme.primaryContainer
          .withValues(alpha: AppTheme.alphaFilterChipSelected),
      checkmarkColor: Colors.transparent,
      showCheckmark: false,
      side: BorderSide(
        color: filterState.selectionMode
            ? context.colorScheme.primary
                .withValues(alpha: AppTheme.alphaFilterChipBorderSelected)
            : context.colorScheme.primaryContainer
                .withValues(alpha: AppTheme.alphaFilterChipBorderUnselected),
      ),
      labelStyle: TextStyle(
        fontSize: AppTheme.filterChipFontSize,
        fontWeight: FontWeight.w600,
        letterSpacing: AppTheme.filterChipLetterSpacing,
        color: filterState.selectionMode
            ? context.colorScheme.onPrimaryContainer
            : context.colorScheme.onSurfaceVariant
                .withValues(alpha: AppTheme.alphaFilterChipTextUnselected),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.filterChipPaddingHorizontal,
        vertical: AppTheme.filterChipPaddingVertical,
      ),
      tooltip: context.messages.aiSettingsSelectModeTooltip,
    );
  }

  /// Builds the capability filters section
  Widget _buildCapabilityFilters(BuildContext context) {
    final capabilities = [
      (
        Modality.text,
        Icons.text_fields,
        context.messages.aiSettingsModalityText
      ),
      (
        Modality.image,
        Icons.visibility,
        context.messages.aiSettingsModalityVision
      ),
      (Modality.audio, Icons.hearing, context.messages.aiSettingsModalityAudio),
    ];

    return Wrap(
      spacing: AppTheme.filterChipSpacing,
      runSpacing: AppTheme.filterChipSpacing,
      children: [
        ...capabilities.map((capability) {
          final (modality, icon, label) = capability;
          final isSelected =
              filterState.selectedCapabilities.contains(modality);
          return FilterChip(
            avatar: Icon(icon, size: AppTheme.filterChipIconSize),
            label: Text(label),
            selected: isSelected,
            onSelected: (selected) {
              final newCapabilities =
                  Set<Modality>.from(filterState.selectedCapabilities);
              if (selected) {
                newCapabilities.add(modality);
              } else {
                newCapabilities.remove(modality);
              }
              onFilterChanged(filterState.copyWith(
                selectedCapabilities: newCapabilities,
              ));
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: context.colorScheme.surfaceContainerHigh
                .withValues(alpha: AppTheme.alphaFilterChipBackground),
            selectedColor: context.colorScheme.primaryContainer
                .withValues(alpha: AppTheme.alphaFilterChipSelected),
            checkmarkColor: context.colorScheme.onPrimaryContainer,
            side: BorderSide(
              color: isSelected
                  ? context.colorScheme.primary
                      .withValues(alpha: AppTheme.alphaFilterChipBorderSelected)
                  : context.colorScheme.primaryContainer.withValues(
                      alpha: AppTheme.alphaFilterChipBorderUnselected),
            ),
            labelStyle: TextStyle(
              fontSize: AppTheme.filterChipFontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: AppTheme.filterChipLetterSpacing,
              color: isSelected
                  ? context.colorScheme.onPrimaryContainer
                  : context.colorScheme.onSurfaceVariant.withValues(
                      alpha: AppTheme.alphaFilterChipTextUnselected),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.filterChipPaddingHorizontal,
              vertical: AppTheme.filterChipPaddingVertical,
            ),
            tooltip:
                context.messages.aiSettingsFilterByCapabilityTooltip(label),
          );
        }),

        // Reasoning filter
        FilterChip(
          avatar: const Icon(
            Icons.psychology,
            size: AppTheme.filterChipIconSize,
          ),
          label: Text(context.messages.aiSettingsReasoningLabel),
          selected: filterState.reasoningFilter,
          onSelected: (selected) {
            onFilterChanged(filterState.copyWith(
              reasoningFilter: selected,
            ));
          },
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: context.colorScheme.surfaceContainerHigh
              .withValues(alpha: AppTheme.alphaFilterChipBackground),
          selectedColor: context.colorScheme.primaryContainer
              .withValues(alpha: AppTheme.alphaFilterChipSelected),
          checkmarkColor: context.colorScheme.onPrimaryContainer,
          side: BorderSide(
            color: filterState.reasoningFilter
                ? context.colorScheme.primary
                    .withValues(alpha: AppTheme.alphaFilterChipBorderSelected)
                : context.colorScheme.primaryContainer.withValues(
                    alpha: AppTheme.alphaFilterChipBorderUnselected),
          ),
          labelStyle: TextStyle(
            fontSize: AppTheme.filterChipFontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: AppTheme.filterChipLetterSpacing,
            color: filterState.reasoningFilter
                ? context.colorScheme.onPrimaryContainer
                : context.colorScheme.onSurfaceVariant
                    .withValues(alpha: AppTheme.alphaFilterChipTextUnselected),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.filterChipPaddingHorizontal,
            vertical: AppTheme.filterChipPaddingVertical,
          ),
          tooltip: context.messages.aiSettingsFilterByReasoningTooltip,
        ),
      ],
    );
  }

  /// Builds the response type filters section for Prompts tab
  Widget _buildResponseTypeFilters(BuildContext context) {
    return Wrap(
      spacing: AppTheme.filterChipSpacing,
      runSpacing: AppTheme.filterChipSpacing,
      children: [
        ...AiResponseType.values.map((responseType) {
          final isSelected =
              filterState.selectedResponseTypes.contains(responseType);
          return FilterChip(
            avatar: Icon(responseType.icon, size: AppTheme.filterChipIconSize),
            label: Text(responseType.localizedName(context)),
            selected: isSelected,
            onSelected: (selected) {
              final newResponseTypes =
                  Set<AiResponseType>.from(filterState.selectedResponseTypes);
              if (selected) {
                newResponseTypes.add(responseType);
              } else {
                newResponseTypes.remove(responseType);
              }
              onFilterChanged(filterState.copyWith(
                selectedResponseTypes: newResponseTypes,
              ));
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: context.colorScheme.surfaceContainerHigh
                .withValues(alpha: AppTheme.alphaFilterChipBackground),
            selectedColor: context.colorScheme.primaryContainer
                .withValues(alpha: AppTheme.alphaFilterChipSelected),
            checkmarkColor: context.colorScheme.onPrimaryContainer,
            side: BorderSide(
              color: isSelected
                  ? context.colorScheme.primary
                      .withValues(alpha: AppTheme.alphaFilterChipBorderSelected)
                  : context.colorScheme.primaryContainer.withValues(
                      alpha: AppTheme.alphaFilterChipBorderUnselected),
            ),
            labelStyle: TextStyle(
              fontSize: AppTheme.filterChipFontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: AppTheme.filterChipLetterSpacing,
              color: isSelected
                  ? context.colorScheme.onPrimaryContainer
                  : context.colorScheme.onSurfaceVariant.withValues(
                      alpha: AppTheme.alphaFilterChipTextUnselected),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.filterChipPaddingHorizontal,
              vertical: AppTheme.filterChipPaddingVertical,
            ),
            tooltip: context.messages.aiSettingsFilterByResponseTypeTooltip(
              responseType.localizedName(context),
            ),
          );
        }),

        // Delete button - only shown when items are selected
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: animation,
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
          child: filterState.hasSelectedPrompts && onDeleteSelected != null
              ? ActionChip(
                  key: const ValueKey('delete_button'),
                  avatar: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: context.colorScheme.error,
                  ),
                  label: Text(
                    context.messages.aiSettingsDeleteSelectedLabel(
                      filterState.selectedPromptCount,
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.colorScheme.error,
                    ),
                  ),
                  onPressed: onDeleteSelected,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor:
                      context.colorScheme.errorContainer.withValues(alpha: 0.3),
                  side: BorderSide(
                    color: context.colorScheme.error.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.filterChipPaddingHorizontal,
                    vertical: AppTheme.filterChipPaddingVertical,
                  ),
                  tooltip: context.messages.aiSettingsDeleteSelectedTooltip,
                )
              : const SizedBox.shrink(key: ValueKey('no_delete_button')),
        ),
      ],
    );
  }
}
