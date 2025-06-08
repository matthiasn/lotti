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
          children: [
            // Provider Filter
            _buildProviderFilter(context, ref),

            // Capability Filters
            _buildCapabilityFilters(context),
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

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
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
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: context.colorScheme.surfaceContainerHigh
                      .withValues(alpha: 0.5),
                  selectedColor: context.colorScheme.primaryContainer
                      .withValues(alpha: 0.7),
                  checkmarkColor: context.colorScheme.onPrimaryContainer,
                  side: BorderSide(
                    color: isSelected
                        ? context.colorScheme.primary.withValues(alpha: 0.8)
                        : context.colorScheme.primaryContainer
                            .withValues(alpha: 0.3),
                  ),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    color: isSelected
                        ? context.colorScheme.onPrimaryContainer
                        : context.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  tooltip: 'Filter by ${provider.name}',
                );
              }),

              // Clear filters button - positioned in provider row when there are active filters
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
                child: filterState.hasModelFilters
                    ? ActionChip(
                        key: const ValueKey('clear_button'),
                        avatar: Icon(
                          Icons.clear,
                          size: 14,
                          color:
                              context.colorScheme.error.withValues(alpha: 0.7),
                        ),
                        label: Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: context.colorScheme.error
                                .withValues(alpha: 0.8),
                          ),
                        ),
                        onPressed: () {
                          onFilterChanged(filterState.resetModelFilters());
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: Colors.transparent,
                        side: BorderSide(
                          color:
                              context.colorScheme.error.withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        tooltip: 'Clear all filters',
                      )
                    : const SizedBox.shrink(key: ValueKey('no_clear_button')),
              ),
            ],
          ),
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
      spacing: 6,
      runSpacing: 6,
      children: [
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
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor:
                context.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
            selectedColor:
                context.colorScheme.primaryContainer.withValues(alpha: 0.7),
            checkmarkColor: context.colorScheme.onPrimaryContainer,
            side: BorderSide(
              color: isSelected
                  ? context.colorScheme.primary.withValues(alpha: 0.8)
                  : context.colorScheme.primaryContainer.withValues(alpha: 0.3),
            ),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: isSelected
                  ? context.colorScheme.onPrimaryContainer
                  : context.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor:
              context.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
          selectedColor:
              context.colorScheme.primaryContainer.withValues(alpha: 0.7),
          checkmarkColor: context.colorScheme.onPrimaryContainer,
          side: BorderSide(
            color: filterState.reasoningFilter
                ? context.colorScheme.primary.withValues(alpha: 0.8)
                : context.colorScheme.primaryContainer.withValues(alpha: 0.3),
          ),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: filterState.reasoningFilter
                ? context.colorScheme.onPrimaryContainer
                : context.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          tooltip: 'Filter by reasoning capability',
        ),
      ],
    );
  }
}
