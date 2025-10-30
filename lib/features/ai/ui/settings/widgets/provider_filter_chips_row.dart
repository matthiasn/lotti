import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
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
          spacing: 6,
          runSpacing: 6,
          children: [
            // Optional "All" chip
            if (showAllChip)
              FilterChip(
                label: const Text('All'),
                selected: selectedProviderIds.isEmpty,
                onSelected: (_) => onChanged({}),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh
                    .withValues(alpha: 0.5),
                selectedColor:
                    Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7),
                checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
                side: BorderSide(
                  color: selectedProviderIds.isEmpty
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)
                      : Theme.of(context).colorScheme.primaryContainer
                          .withValues(alpha: 0.3),
                ),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: selectedProviderIds.isEmpty
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),

            // Provider chips
            ...providerConfigs.map((provider) {
              final isSelected = selectedProviderIds.contains(provider.id);
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
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh
                    .withValues(alpha: 0.5),
                selectedColor:
                    Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7),
                checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.8)
                      : Theme.of(context).colorScheme.primaryContainer
                          .withValues(alpha: 0.3),
                ),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
