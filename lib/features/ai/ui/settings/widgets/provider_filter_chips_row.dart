import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_chip_constants.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_filter_chip.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Reusable widget for displaying provider filter chips
///
/// This widget is shared between:
/// - AI Settings page (Models and Prompts tabs) - multi-select mode
/// - Model Management Modal - single-select mode
///
/// **Features:**
/// - Dynamically loads available providers
/// - Supports single or multi-selection
/// - Optional "All" chip for clearing selection
/// - Consistent Material Design FilterChip styling
/// - Wrap layout that adapts to available space
///
/// **Usage:**
/// ```dart
/// // Single selection (modal)
/// ProviderFilterChipsRow(
///   selectedProviderIds: _selectedProviderId != null ? {_selectedProviderId!} : {},
///   onChanged: (ids) => setState(() => _selectedProviderId = ids.firstOrNull),
///   allowMultiSelect: false,
///   showAllChip: true,
/// )
///
/// // Multi selection (settings)
/// ProviderFilterChipsRow(
///   selectedProviderIds: filterState.selectedProviders,
///   onChanged: (ids) => onFilterChanged(filterState.copyWith(selectedProviders: ids)),
///   allowMultiSelect: true,
///   showAllChip: false,
/// )
/// ```
class ProviderFilterChipsRow extends ConsumerWidget {
  const ProviderFilterChipsRow({
    required this.selectedProviderIds,
    required this.onChanged,
    this.allowMultiSelect = true,
    this.showAllChip = false,
    this.availableProviderIds,
    this.useStyledChips = false,
    super.key,
  });

  /// Currently selected provider IDs
  final Set<String> selectedProviderIds;

  /// Callback when selection changes
  final ValueChanged<Set<String>> onChanged;

  /// Whether to allow selecting multiple providers
  /// - true: Settings page (multi-select)
  /// - false: Modal (single-select)
  final bool allowMultiSelect;

  /// Whether to show an "All" chip for clearing selection
  /// Typically true for modals, false for settings page
  final bool showAllChip;

  /// Optional list of provider IDs to show chips for
  /// If null, shows chips for all available providers
  /// If provided, only shows chips for providers in this list
  final List<String>? availableProviderIds;

  /// Whether to use styled chips with provider-specific colors and avatars
  /// - true: Use ProviderFilterChip with colors and avatars
  /// - false: Use plain FilterChip (default)
  final bool useStyledChips;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providersAsync = ref.watch(
      aiConfigByTypeControllerProvider(
        configType: AiConfigType.inferenceProvider,
      ),
    );

    return providersAsync.when(
      data: (providers) {
        var providerConfigs = providers
            .whereType<AiConfigInferenceProvider>()
            .toList();

        // Filter to only show available providers if specified
        if (availableProviderIds != null) {
          final availableSet = availableProviderIds!.toSet();
          providerConfigs = providerConfigs
              .where((p) => availableSet.contains(p.id))
              .toList();
        }

        if (providerConfigs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Wrap(
          spacing: ProviderChipConstants.chipSpacing,
          runSpacing: ProviderChipConstants.chipSpacing,
          children: [
            // Optional "All" chip clears the selection.
            if (showAllChip)
              DesignSystemChip(
                label: context.messages.tasksLabelFilterAll,
                selected: selectedProviderIds.isEmpty,
                onPressed: () => onChanged(const {}),
              ),

            // Provider chips — styled (colour-coded avatar) or plain, both
            // sharing the same toggle logic.
            ...providerConfigs.map((provider) {
              final isSelected = selectedProviderIds.contains(provider.id);

              void toggle() {
                final newSelection = Set<String>.from(selectedProviderIds);
                if (allowMultiSelect) {
                  if (isSelected) {
                    newSelection.remove(provider.id);
                  } else {
                    newSelection.add(provider.id);
                  }
                } else {
                  if (isSelected) {
                    newSelection.clear();
                  } else {
                    newSelection
                      ..clear()
                      ..add(provider.id);
                  }
                }
                onChanged(newSelection);
              }

              if (useStyledChips) {
                return ProviderFilterChip(
                  providerId: provider.id,
                  isSelected: isSelected,
                  onTap: toggle,
                );
              }

              return Tooltip(
                message: context.messages.aiSettingsFilterByProviderTooltip(
                  provider.name,
                ),
                child: DesignSystemChip(
                  label: provider.name,
                  selected: isSelected,
                  onPressed: toggle,
                ),
              );
            }),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
