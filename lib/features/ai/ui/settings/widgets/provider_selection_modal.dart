import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// Modal for selecting an inference provider with modern styling
///
/// This component provides a clean, accessible interface for users to select
/// which inference provider hosts a model.
///
/// Features:
/// - Clean modal design with proper header and close button
/// - Provider cards with proper visual feedback and selection state
/// - Check marks for selected providers (not arrows)
/// - Visual highlighting for current selection
/// - Empty and error states
/// - Professional loading indicators
/// - Proper accessibility support
class ProviderSelectionModal extends ConsumerWidget {
  const ProviderSelectionModal({
    required this.onProviderSelected,
    required this.selectedProviderId,
    super.key,
  });

  /// Callback when user selects a provider
  final ValueChanged<String> onProviderSelected;
  
  /// Currently selected provider ID (for highlighting)
  final String selectedProviderId;

  /// Shows the provider selection modal using Wolt modal sheet
  static void show({
    required BuildContext context,
    required ValueChanged<String> onProviderSelected,
    required String selectedProviderId,
  }) {
    WoltModalSheet.show<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      pageListBuilder: (modalSheetContext) => [
        _buildMainPage(modalSheetContext, onProviderSelected, selectedProviderId),
      ],
    );
  }

  /// Builds the main page of the Wolt modal sheet
  static WoltModalSheetPage _buildMainPage(
    BuildContext context,
    ValueChanged<String> onProviderSelected,
    String selectedProviderId,
  ) {
    return WoltModalSheetPage(
      hasSabGradient: false,
      backgroundColor: context.colorScheme.surfaceContainerHigh,
      topBarTitle: Text(
        context.messages.aiConfigSelectProviderModalTitle,
        style: context.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: context.colorScheme.onSurface,
        ),
      ),
      trailingNavBarWidget: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(
          Icons.close,
          color: context.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        tooltip: 'Close',
      ),
      isTopBarLayerAlwaysVisible: true,
      child: ProviderSelectionModal(
        onProviderSelected: onProviderSelected,
        selectedProviderId: selectedProviderId,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providersAsync = ref.watch(
      aiConfigByTypeControllerProvider(
        configType: AiConfigType.inferenceProvider,
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: providersAsync.when(
        data: (providers) {
          if (providers.isEmpty) {
            return const _EmptyProvidersState();
          }

          return _ProvidersList(
            providers: providers,
            onProviderSelected: onProviderSelected,
            selectedProviderId: selectedProviderId,
          );
        },
        loading: () => const _LoadingState(),
        error: (error, stackTrace) => const _ErrorState(),
      ),
    );
  }
}

/// List of available providers
class _ProvidersList extends StatelessWidget {
  const _ProvidersList({
    required this.providers,
    required this.onProviderSelected,
    required this.selectedProviderId,
  });

  final List<AiConfig> providers;
  final ValueChanged<String> onProviderSelected;
  final String selectedProviderId;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: providers.map((provider) {
        return provider.maybeMap(
          inferenceProvider: (providerConfig) {
            final isSelected = providerConfig.id == selectedProviderId;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _ProviderCard(
                provider: providerConfig,
                isSelected: isSelected,
                onTap: () {
                  onProviderSelected(providerConfig.id);
                  // Add a brief delay to show selection feedback before closing
                  if (!isSelected) {
                    Future.delayed(const Duration(milliseconds: 150), () {
                      if (context.mounted) {
                        try {
                          Navigator.of(context).pop();
                        } catch (e) {
                          // Ignore navigation errors in test context
                        }
                      }
                    });
                  } else {
                    // If already selected, close immediately
                    try {
                      Navigator.of(context).pop();
                    } catch (e) {
                      // Ignore navigation errors in test context
                    }
                  }
                },
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
      }).toList(),
    );
  }
}

/// Individual provider card
class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.isSelected,
    required this.onTap,
  });

  final AiConfigInferenceProvider provider;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? context.colorScheme.primaryContainer.withValues(alpha: 0.15)
            : context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? context.colorScheme.primary.withValues(alpha: 0.6)
              : context.colorScheme.outline.withValues(alpha: 0.1),
          width: 2, // Keep consistent border width to prevent breathing
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: context.colorScheme.primary.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Provider icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.colorScheme.primary.withValues(alpha: 0.15)
                        : context.colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? context.colorScheme.primary.withValues(alpha: 0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: Icon(
                    Icons.cloud_outlined,
                    color: isSelected
                        ? context.colorScheme.primary
                        : context.colorScheme.onSurface.withValues(alpha: 0.8),
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Provider info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.name,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? context.colorScheme.primary
                              : context.colorScheme.onSurface,
                          height: 1.3,
                        ),
                      ),
                      if (provider.description?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        Text(
                          provider.description!,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Selection indicator - checkmark when selected, empty circle when not
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: context.colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: context.colorScheme.primary
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: context.colorScheme.onPrimary,
                      size: 16,
                    ),
                  )
                else
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: context.colorScheme.outline
                            .withValues(alpha: 0.3),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading state widget
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Error state widget
class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: context.colorScheme.error.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading providers',
            style: context.textTheme.titleMedium?.copyWith(
              color: context.colorScheme.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state widget when no providers are available
class _EmptyProvidersState extends StatelessWidget {
  const _EmptyProvidersState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: context.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No providers found',
            style: context.textTheme.titleMedium?.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create an inference provider first',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
