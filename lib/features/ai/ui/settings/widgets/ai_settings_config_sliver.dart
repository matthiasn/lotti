import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/ai_config_card.dart';
import 'package:lotti/features/ai/ui/settings/services/ai_config_delete_service.dart';
import 'package:lotti/themes/theme.dart';

/// A sliver variant of AiSettingsConfigList that preserves all design and functionality
/// while properly propagating scroll events in CustomScrollView
///
/// This widget provides the same beautiful cards and swipe-to-delete functionality
/// as AiSettingsConfigList but returns proper slivers for better scroll behavior.
class AiSettingsConfigSliver<T extends AiConfig> extends ConsumerWidget {
  const AiSettingsConfigSliver({
    required this.configsAsync,
    required this.filteredConfigs,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.onConfigTap,
    this.showCapabilities = false,
    this.isCompact = false,
    this.enableSwipeToDelete = true,
    this.onRetry,
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

  /// Whether to enable swipe-to-delete functionality
  final bool enableSwipeToDelete;

  /// Optional callback for retry button in error state
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return configsAsync.when(
      data: (configs) {
        if (filteredConfigs.isEmpty) {
          return _buildEmptySliver(context);
        }
        return _buildConfigSliver(context, ref);
      },
      loading: _buildLoadingSliver,
      error: (error, stackTrace) => _buildErrorSliver(context, error),
    );
  }

  /// Builds the main configuration sliver
  Widget _buildConfigSliver(BuildContext context, WidgetRef ref) {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= filteredConfigs.length * 2 - 1) return null;
            
            // Add spacing between cards
            if (index.isOdd) {
              return const SizedBox(height: 8);
            }
            
            final configIndex = index ~/ 2;
            final config = filteredConfigs[configIndex];

            if (!enableSwipeToDelete) {
              return AiConfigCard(
                config: config,
                showCapabilities: showCapabilities,
                isCompact: isCompact,
                onTap: () => onConfigTap(config),
              );
            }

            return _buildDismissibleCard(context, ref, config);
          },
          childCount: filteredConfigs.length * 2 - 1,
        ),
      ),
    );
  }

  /// Builds a dismissible card with stylish delete background
  Widget _buildDismissibleCard(
    BuildContext context,
    WidgetRef ref,
    T config,
  ) {
    return Dismissible(
      key: ValueKey(config.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        const deleteService = AiConfigDeleteService();
        return deleteService.deleteConfig(
          context: context,
          ref: ref,
          config: config,
        );
      },
      background: _buildDismissBackground(context),
      child: AiConfigCard(
        config: config,
        showCapabilities: showCapabilities,
        isCompact: isCompact,
        onTap: () => onConfigTap(config),
      ),
    );
  }

  /// Builds the stylish delete background for dismissible cards
  Widget _buildDismissBackground(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            context.colorScheme.errorContainer.withValues(alpha: 0.1),
            context.colorScheme.error.withValues(alpha: 0.9),
            context.colorScheme.error,
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: context.colorScheme.error.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.colorScheme.onError.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.delete_forever_rounded,
                    color: context.colorScheme.onError,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Delete',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colorScheme.onError,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the empty state sliver
  Widget _buildEmptySliver(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.colorScheme.primaryContainer.withValues(alpha: 0.15),
                    context.colorScheme.primaryContainer.withValues(alpha: 0.25),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                emptyIcon,
                size: 40,
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              emptyMessage,
              style: context.textTheme.titleMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add one',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the loading state sliver
  Widget _buildLoadingSliver() {
    return const SliverFillRemaining(
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  /// Builds the error state sliver
  Widget _buildErrorSliver(BuildContext context, Object error) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: context.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading configurations',
              style: context.textTheme.titleMedium?.copyWith(
                color: context.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: context.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
