import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_chip_constants.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_filter_chips_row.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Widget that displays filter chips for AI model filtering
///
/// This widget provides provider, capability, and reasoning filters
/// specifically for the Models tab in AI Settings.
class AiSettingsFilterChips extends ConsumerWidget {
  const AiSettingsFilterChips({
    required this.filterState,
    required this.onFilterChanged,
    super.key,
  });

  /// Current filter state
  final AiSettingsFilterState filterState;

  /// Callback when filter state changes
  final ValueChanged<AiSettingsFilterState> onFilterChanged;

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
            // Provider Filter
            _buildProviderFilter(context, ref),

            // Capability Filters (only shown on Models tab)
            if (filterState.activeTab == AiSettingsTab.models)
              _buildCapabilityFilters(context),
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
              onFilterChanged(
                filterState.copyWith(
                  selectedProviders: newProviders,
                ),
              );
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
        ],
      ),
    );
  }

  /// Builds the capability filters section
  Widget _buildCapabilityFilters(BuildContext context) {
    final capabilities = [
      (
        Modality.text,
        Icons.text_fields,
        context.messages.aiSettingsModalityText,
      ),
      (
        Modality.image,
        Icons.visibility,
        context.messages.aiSettingsModalityVision,
      ),
      (Modality.audio, Icons.hearing, context.messages.aiSettingsModalityAudio),
    ];

    return Wrap(
      spacing: AppTheme.filterChipSpacing,
      runSpacing: AppTheme.filterChipSpacing,
      children: [
        ...capabilities.map((capability) {
          final (modality, icon, label) = capability;
          final isSelected = filterState.selectedCapabilities.contains(
            modality,
          );
          return FilterChip(
            avatar: Icon(icon, size: AppTheme.filterChipIconSize),
            label: Text(label),
            selected: isSelected,
            onSelected: (selected) {
              final newCapabilities = Set<Modality>.from(
                filterState.selectedCapabilities,
              );
              if (selected) {
                newCapabilities.add(modality);
              } else {
                newCapabilities.remove(modality);
              }
              onFilterChanged(
                filterState.copyWith(
                  selectedCapabilities: newCapabilities,
                ),
              );
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: context.colorScheme.surfaceContainerHigh
                .withValues(alpha: AppTheme.alphaFilterChipBackground),
            selectedColor: context.colorScheme.primaryContainer.withValues(
              alpha: AppTheme.alphaFilterChipSelected,
            ),
            checkmarkColor: context.colorScheme.onPrimaryContainer,
            side: BorderSide(
              color: isSelected
                  ? context.colorScheme.primary.withValues(
                      alpha: AppTheme.alphaFilterChipBorderSelected,
                    )
                  : context.colorScheme.primaryContainer.withValues(
                      alpha: AppTheme.alphaFilterChipBorderUnselected,
                    ),
            ),
            labelStyle: TextStyle(
              fontSize: AppTheme.filterChipFontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: AppTheme.filterChipLetterSpacing,
              color: isSelected
                  ? context.colorScheme.onPrimaryContainer
                  : context.colorScheme.onSurfaceVariant.withValues(
                      alpha: AppTheme.alphaFilterChipTextUnselected,
                    ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.filterChipPaddingHorizontal,
              vertical: AppTheme.filterChipPaddingVertical,
            ),
            tooltip: context.messages.aiSettingsFilterByCapabilityTooltip(
              label,
            ),
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
            onFilterChanged(
              filterState.copyWith(
                reasoningFilter: selected,
              ),
            );
          },
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: context.colorScheme.surfaceContainerHigh.withValues(
            alpha: AppTheme.alphaFilterChipBackground,
          ),
          selectedColor: context.colorScheme.primaryContainer.withValues(
            alpha: AppTheme.alphaFilterChipSelected,
          ),
          checkmarkColor: context.colorScheme.onPrimaryContainer,
          side: BorderSide(
            color: filterState.reasoningFilter
                ? context.colorScheme.primary.withValues(
                    alpha: AppTheme.alphaFilterChipBorderSelected,
                  )
                : context.colorScheme.primaryContainer.withValues(
                    alpha: AppTheme.alphaFilterChipBorderUnselected,
                  ),
          ),
          labelStyle: TextStyle(
            fontSize: AppTheme.filterChipFontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: AppTheme.filterChipLetterSpacing,
            color: filterState.reasoningFilter
                ? context.colorScheme.onPrimaryContainer
                : context.colorScheme.onSurfaceVariant.withValues(
                    alpha: AppTheme.alphaFilterChipTextUnselected,
                  ),
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
}
