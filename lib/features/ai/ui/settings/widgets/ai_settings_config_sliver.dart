import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/ai_config_card.dart';
import 'package:lotti/features/ai/ui/settings/widgets/config_empty_state.dart';
import 'package:lotti/features/ai/ui/settings/widgets/config_error_state.dart';
import 'package:lotti/features/ai/ui/settings/widgets/config_loading_state.dart';
import 'package:lotti/features/ai/ui/settings/widgets/dismissible_config_card.dart';

/// A sliver-based configuration list for AI settings
///
/// This widget provides a performant, sliver-based list implementation that works
/// seamlessly with [CustomScrollView] and properly propagates scroll events.
/// It replaces the previous box-based AiSettingsConfigList to solve scroll
/// propagation issues in the new sliver-based layout architecture.
///
/// Features:
/// - Proper sliver implementation for smooth scrolling
/// - Beautiful card design with swipe-to-delete functionality
/// - Loading, error, and empty states
/// - Generic type support for all AI configuration types
/// - Optional capability indicators for models
///
/// The widget uses extracted state components for better maintainability:
/// - [ConfigLoadingState] for loading UI
/// - [ConfigErrorState] for error UI with retry
/// - [ConfigEmptyState] for empty list UI
/// - [DismissibleConfigCard] for swipeable cards
class AiSettingsConfigSliver<T extends AiConfig> extends ConsumerWidget {
  const AiSettingsConfigSliver({
    required this.configsAsync,
    required this.filteredConfigs,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.onConfigTap,
    this.showCapabilities = false,
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
                onTap: () => onConfigTap(config),
              );
            }

            return DismissibleConfigCard(
              config: config,
              showCapabilities: showCapabilities,
              onTap: () => onConfigTap(config),
            );
          },
          childCount: filteredConfigs.length * 2 - 1,
        ),
      ),
    );
  }

  /// Builds the empty state sliver
  Widget _buildEmptySliver(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: ConfigEmptyState(
        message: emptyMessage,
        icon: emptyIcon,
      ),
    );
  }

  /// Builds the loading state sliver
  Widget _buildLoadingSliver() {
    return const SliverFillRemaining(
      child: ConfigLoadingState(),
    );
  }

  /// Builds the error state sliver
  Widget _buildErrorSliver(BuildContext context, Object error) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: ConfigErrorState(
        error: error,
        onRetry: onRetry,
      ),
    );
  }
}
