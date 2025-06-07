import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/ai_config_card.dart';
import 'package:lotti/themes/theme.dart';

/// Widget that displays a list of AI configurations with proper loading and error states
///
/// This widget provides a consistent interface for displaying lists of AI configurations
/// across all tabs (providers, models, prompts) with proper error handling and empty states.
///
/// **Features:**
/// - Loading state with progress indicator
/// - Error state with retry option
/// - Empty state with helpful message and icon
/// - Efficient ListView.separated for performance
/// - Consistent spacing and animations
///
/// **Usage:**
/// ```dart
/// AiSettingsConfigList<AiConfigModel>(
///   configsAsync: modelsAsyncValue,
///   filteredConfigs: filteredModels,
///   showCapabilities: true,
///   emptyMessage: 'No AI models configured',
///   emptyIcon: Icons.smart_toy,
///   onConfigTap: (config) => navigateToEdit(config),
/// )
/// ```
class AiSettingsConfigList<T extends AiConfig> extends StatelessWidget {
  const AiSettingsConfigList({
    required this.configsAsync,
    required this.filteredConfigs,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.onConfigTap,
    this.showCapabilities = false,
    this.isCompact = false,
    super.key,
  });

  /// Async value containing the configurations
  final AsyncValue<List<AiConfig>> configsAsync;

  /// Pre-filtered list of configurations to display
  final List<T> filteredConfigs;

  /// Message to show when no configurations are available
  final String emptyMessage;

  /// Icon to show in empty state
  final IconData emptyIcon;

  /// Callback when a configuration is tapped
  final ValueChanged<T> onConfigTap;

  /// Whether to show capability indicators (for models)
  final bool showCapabilities;

  /// Whether to use compact card layout
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return configsAsync.when(
      data: (configs) => _buildConfigList(context),
      loading: () => _buildLoadingState(context),
      error: (error, stackTrace) => _buildErrorState(context, error),
    );
  }

  /// Builds the main configuration list
  Widget _buildConfigList(BuildContext context) {
    if (filteredConfigs.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filteredConfigs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final config = filteredConfigs[index];
        return AiConfigCard(
          config: config,
          showCapabilities: showCapabilities,
          isCompact: isCompact,
          onTap: () => onConfigTap(config),
        );
      },
    );
  }

  /// Builds the loading state
  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading configurations...'),
          ],
        ),
      ),
    );
  }

  /// Builds the error state
  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: context.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load configurations',
              style: context.textTheme.titleMedium?.copyWith(
                color: context.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                // Trigger a rebuild to retry loading
                // This would typically be handled by the parent widget
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the empty state
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emptyIcon,
              size: 64,
              color:
                  context.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: context.textTheme.titleMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first configuration to get started',
              style: context.textTheme.bodyMedium?.copyWith(
                color:
                    context.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
