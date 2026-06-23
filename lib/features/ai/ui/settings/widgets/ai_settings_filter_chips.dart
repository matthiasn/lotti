import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_chip_constants.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_filter_chips_row.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
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
                ? Tooltip(
                    key: const ValueKey('clear_button'),
                    message: context.messages.aiSettingsClearAllFiltersTooltip,
                    child: DesignSystemChip(
                      label: context.messages.aiSettingsClearFiltersButton,
                      leadingIcon: Icons.clear,
                      onPressed: () {
                        onFilterChanged(filterState.resetCurrentTabFilters());
                      },
                    ),
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
          return Tooltip(
            message: context.messages.aiSettingsFilterByCapabilityTooltip(
              label,
            ),
            child: DesignSystemChip(
              leadingIcon: icon,
              label: label,
              selected: isSelected,
              onPressed: () {
                final newCapabilities = Set<Modality>.from(
                  filterState.selectedCapabilities,
                );
                if (isSelected) {
                  newCapabilities.remove(modality);
                } else {
                  newCapabilities.add(modality);
                }
                onFilterChanged(
                  filterState.copyWith(
                    selectedCapabilities: newCapabilities,
                  ),
                );
              },
            ),
          );
        }),

        // Reasoning filter
        Tooltip(
          message: context.messages.aiSettingsFilterByReasoningTooltip,
          child: DesignSystemChip(
            leadingIcon: Icons.psychology,
            label: context.messages.aiSettingsReasoningLabel,
            selected: filterState.reasoningFilter,
            onPressed: () {
              onFilterChanged(
                filterState.copyWith(
                  reasoningFilter: !filterState.reasoningFilter,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
