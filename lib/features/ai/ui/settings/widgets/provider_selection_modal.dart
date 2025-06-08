import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Modal for selecting an inference provider with modern styling
///
/// This component provides a clean, accessible interface for users to select
/// which inference provider hosts a model.
///
/// Features:
/// - Clean modal design with proper header and close button
/// - Provider cards with proper visual feedback
/// - Empty and error states
/// - Professional loading indicators
/// - Proper accessibility support
class ProviderSelectionModal extends ConsumerWidget {
  const ProviderSelectionModal({
    required this.onProviderSelected,
    super.key,
  });

  /// Callback when user selects a provider
  final ValueChanged<String> onProviderSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providersAsync = ref.watch(
      aiConfigByTypeControllerProvider(
        configType: AiConfigType.inferenceProvider,
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: context.colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Modal header
          _ModalHeader(
            title: context.messages.aiConfigSelectProviderModalTitle,
            subtitle: 'Choose which provider hosts this model',
            onClose: () => Navigator.of(context).pop(),
          ),

          // Provider list
          Flexible(
            child: providersAsync.when(
              data: (providers) {
                if (providers.isEmpty) {
                  return const _EmptyProvidersState();
                }

                return _ProvidersList(
                  providers: providers,
                  onProviderSelected: onProviderSelected,
                );
              },
              loading: () => const _LoadingState(),
              error: (error, stackTrace) => const _ErrorState(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Header section of the provider selection modal
class _ModalHeader extends StatelessWidget {
  const _ModalHeader({
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: context.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.onSurface.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(
              Icons.close_rounded,
              color: context.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// List of available providers
class _ProvidersList extends StatelessWidget {
  const _ProvidersList({
    required this.providers,
    required this.onProviderSelected,
  });

  final List<AiConfig> providers;
  final ValueChanged<String> onProviderSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.all(20),
      itemCount: providers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final provider = providers[index];

        return provider.maybeMap(
          inferenceProvider: (providerConfig) {
            return _ProviderCard(
              provider: providerConfig,
              onTap: () {
                onProviderSelected(providerConfig.id);
                Navigator.of(context).pop();
              },
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Individual provider card
class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.onTap,
  });

  final AiConfigInferenceProvider provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.cloud_outlined,
            color: context.colorScheme.primary,
            size: 24,
          ),
        ),
        title: Text(
          provider.name,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colorScheme.onSurface,
          ),
        ),
        subtitle: (provider.description?.isNotEmpty ?? false)
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  provider.description!,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : null,
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.arrow_forward_rounded,
            color: context.colorScheme.primary,
            size: 18,
          ),
        ),
        onTap: onTap,
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
