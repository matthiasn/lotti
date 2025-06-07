import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/settings/ai_settings_filter_state.dart';
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

            const SizedBox(height: 12),

            // Capability Filters
            _buildCapabilityFilters(context),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Builds the provider filter section
  Widget _buildProviderFilter(BuildContext context, WidgetRef ref) {
    final providersAsync = ref.watch(
      aiConfigByTypeControllerProvider(
        configType: AiConfigType.inferenceProvider,
      ),
    );

    return providersAsync.when(
      data: (providers) {
        final providerConfigs =
            providers.whereType<AiConfigInferenceProvider>().toList();

        if (providerConfigs.isEmpty) {
          return const SizedBox.shrink();
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Text(
              'Providers:',
              style: context.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            ...providerConfigs.map((provider) {
              final isSelected =
                  filterState.selectedProviders.contains(provider.id);
              return FilterChip(
                label: Text(provider.name),
                selected: isSelected,
                onSelected: (selected) {
                  final newProviders =
                      Set<String>.from(filterState.selectedProviders);
                  if (selected) {
                    newProviders.add(provider.id);
                  } else {
                    newProviders.remove(provider.id);
                  }
                  onFilterChanged(filterState.copyWith(
                    selectedProviders: newProviders,
                  ));
                },
                backgroundColor: context.colorScheme.surfaceContainerHighest,
                selectedColor: context.colorScheme.primaryContainer,
                checkmarkColor: context.colorScheme.primary,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? context.colorScheme.primary
                      : context.colorScheme.onSurfaceVariant,
                ),
                tooltip: 'Filter by ${provider.name}',
              );
            }),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  /// Builds the capability filters section
  Widget _buildCapabilityFilters(BuildContext context) {
    final capabilities = [
      (Modality.text, Icons.text_fields, 'Text'),
      (Modality.image, Icons.visibility, 'Vision'),
      (Modality.audio, Icons.hearing, 'Audio'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Text(
          'Capabilities:',
          style: context.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        ...capabilities.map((capability) {
          final (modality, icon, label) = capability;
          final isSelected =
              filterState.selectedCapabilities.contains(modality);
          return FilterChip(
            avatar: Icon(icon, size: 16),
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
            backgroundColor: context.colorScheme.surfaceContainerHighest,
            selectedColor: context.colorScheme.primaryContainer,
            checkmarkColor: context.colorScheme.primary,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected
                  ? context.colorScheme.primary
                  : context.colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Filter by $label capability',
          );
        }),

        // Reasoning filter
        FilterChip(
          avatar: const Icon(Icons.psychology, size: 16),
          label: const Text('Reasoning'),
          selected: filterState.reasoningFilter,
          onSelected: (selected) {
            onFilterChanged(filterState.copyWith(
              reasoningFilter: selected,
            ));
          },
          backgroundColor: context.colorScheme.surfaceContainerHighest,
          selectedColor: context.colorScheme.primaryContainer,
          checkmarkColor: context.colorScheme.primary,
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: filterState.reasoningFilter
                ? context.colorScheme.primary
                : context.colorScheme.onSurfaceVariant,
          ),
          tooltip: 'Filter by reasoning capability',
        ),

        // Clear filters button
        if (filterState.hasModelFilters)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ActionChip(
              avatar: const Icon(Icons.clear_all, size: 16),
              label: const Text('Clear'),
              onPressed: () {
                onFilterChanged(filterState.resetModelFilters());
              },
              backgroundColor: context.colorScheme.surfaceContainerHighest,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.colorScheme.onSurfaceVariant,
              ),
              tooltip: 'Clear all model filters',
            ),
          ),
      ],
    );
  }
}
