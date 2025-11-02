import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_chip_constants.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_filter_chip.dart';
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
        var providerConfigs =
            providers.whereType<AiConfigInferenceProvider>().toList();

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
            // Optional "All" chip
            if (showAllChip)
              FilterChip(
                label: Text(context.messages.tasksLabelFilterAll),
                selected: selectedProviderIds.isEmpty,
                onSelected: (_) => onChanged({}),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHigh
                    .withValues(alpha: ProviderChipConstants.surfaceAlpha),
                selectedColor:
                    Theme.of(context).colorScheme.primaryContainer.withValues(
                          alpha: ProviderChipConstants.primaryContainerAlpha,
                        ),
                checkmarkColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
                side: BorderSide(
                  color: selectedProviderIds.isEmpty
                      ? Theme.of(context).colorScheme.primary.withValues(
                            alpha: ProviderChipConstants.primaryAlpha,
                          )
                      : Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(
                            alpha: ProviderChipConstants
                                .primaryContainerBorderAlpha,
                          ),
                ),
                labelStyle: TextStyle(
                  fontSize: ProviderChipConstants.chipFontSize,
                  fontWeight: ProviderChipConstants.chipFontWeight,
                  letterSpacing: ProviderChipConstants.chipLetterSpacing,
                  color: selectedProviderIds.isEmpty
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(
                            alpha: ProviderChipConstants.onSurfaceVariantAlpha,
                          ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: ProviderChipConstants.chipHorizontalPadding,
                  vertical: ProviderChipConstants.chipVerticalPadding,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    ProviderChipConstants.chipBorderRadius,
                  ),
                ),
              ),

            // Provider chips - styled or plain based on useStyledChips parameter
            ...providerConfigs.map((provider) {
              final isSelected = selectedProviderIds.contains(provider.id);

              if (useStyledChips) {
                // Use styled ProviderFilterChip with colors and avatars
                return ProviderFilterChip(
                  providerId: provider.id,
                  isSelected: isSelected,
                  onTap: () {
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
                  },
                );
              }

              // Use plain FilterChip
              return FilterChip(
                label: Text(provider.name),
                selected: isSelected,
                onSelected: (selected) {
                  final newSelection = Set<String>.from(selectedProviderIds);
                  if (allowMultiSelect) {
                    // Multi-select mode: toggle provider
                    if (selected) {
                      newSelection.add(provider.id);
                    } else {
                      newSelection.remove(provider.id);
                    }
                  } else {
                    // Single-select mode: replace selection
                    if (selected) {
                      newSelection
                        ..clear()
                        ..add(provider.id);
                    } else {
                      newSelection.clear();
                    }
                  }
                  onChanged(newSelection);
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHigh
                    .withValues(alpha: ProviderChipConstants.surfaceAlpha),
                selectedColor:
                    Theme.of(context).colorScheme.primaryContainer.withValues(
                          alpha: ProviderChipConstants.primaryContainerAlpha,
                        ),
                checkmarkColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withValues(
                            alpha: ProviderChipConstants.primaryAlpha,
                          )
                      : Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(
                            alpha: ProviderChipConstants
                                .primaryContainerBorderAlpha,
                          ),
                ),
                labelStyle: TextStyle(
                  fontSize: ProviderChipConstants.chipFontSize,
                  fontWeight: ProviderChipConstants.chipFontWeight,
                  letterSpacing: ProviderChipConstants.chipLetterSpacing,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(
                            alpha: ProviderChipConstants.onSurfaceVariantAlpha,
                          ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: ProviderChipConstants.chipHorizontalPadding,
                  vertical: ProviderChipConstants.chipVerticalPadding,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    ProviderChipConstants.chipBorderRadius,
                  ),
                ),
                tooltip: context.messages
                    .aiSettingsFilterByProviderTooltip(provider.name),
              );
            }),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
