import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/inference_provider_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/model_subtitle_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// A page that displays a list of AI configurations of a specific type.
/// Used in settings to manage configurations like API keys, etc.
class AiConfigListPage extends ConsumerWidget {
  const AiConfigListPage({
    required this.configType,
    required this.title,
    this.onAddPressed,
    this.onItemTap,
    super.key,
  });

  final AiConfigType configType;
  final String title;
  final VoidCallback? onAddPressed;
  final void Function(AiConfig config)? onItemTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configsAsyncValue = ref.watch(
      aiConfigByTypeControllerProvider(configType: configType),
    );

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: configsAsyncValue.when(
        data: (configs) {
          if (configs.isEmpty) {
            return Center(
              child: Text(
                context.messages.aiConfigListEmptyState,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            itemCount: configs.length,
            itemBuilder: (context, index) {
              final config = configs[index];
              return _buildDismissibleConfig(context, config, ref);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            '${context.messages.aiConfigListErrorLoading}: $error',
          ),
        ),
      ),
      floatingActionButton: onAddPressed != null
          ? FloatingActionButton(
              onPressed: onAddPressed,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildDismissibleConfig(
    BuildContext context,
    AiConfig config,
    WidgetRef ref,
  ) {
    return Dismissible(
      key: Key(config.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        final shouldDelete =
            await _showDeleteConfirmationDialog(context, config);
        if (shouldDelete && context.mounted) {
          _deleteConfig(config, ref, context);
        }
        return false;
      },
      child: _buildConfigListTile(context, config, ref),
    );
  }

  Future<bool> _showDeleteConfirmationDialog(
    BuildContext context,
    AiConfig config,
  ) async {
    // Special handling for inference providers
    if (config is AiConfigInferenceProvider) {
      return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(context.messages.aiConfigListDeleteConfirmTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.messages
                        .aiConfigListDeleteConfirmMessage(config.name),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_outlined,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.messages.aiConfigListCascadeDeleteWarning,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(context.messages.aiConfigListDeleteConfirmCancel),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: Text(context.messages.aiConfigListDeleteConfirmDelete),
                ),
              ],
            ),
          ) ??
          false;
    }

    // Regular confirmation for other config types
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.messages.aiConfigListDeleteConfirmTitle),
            content: Text(
              context.messages.aiConfigListDeleteConfirmMessage(config.name),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.messages.aiConfigListDeleteConfirmCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.messages.aiConfigListDeleteConfirmDelete),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _deleteConfig(AiConfig config, WidgetRef ref, BuildContext context) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final messages = context.messages;

    // Use appropriate deletion method based on config type
    if (config is AiConfigInferenceProvider) {
      // For inference providers, use the cascade deletion
      final controller = ref.read(
        inferenceProviderFormControllerProvider(configId: config.id).notifier,
      );

      controller.deleteConfig(config.id).then((result) {
        // Show snackbar for the provider deletion
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 12, top: 4),
                    child: Icon(
                      Icons.delete_outline,
                      color: colorScheme.onInverseSurface,
                      size: 24,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.name,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onInverseSurface,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          messages.aiConfigProviderDeletedSuccessfully,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onInverseSurface
                                .withValues(alpha: 0.85),
                            height: 1.3,
                          ),
                        ),
                        if (result.deletedModels.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.inverseSurface
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    colorScheme.outline.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.analytics_outlined,
                                      size: 16,
                                      color: colorScheme.onInverseSurface
                                          .withValues(alpha: 0.9),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      messages.aiConfigAssociatedModelsRemoved(
                                          result.deletedModels.length),
                                      style: textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: colorScheme.onInverseSurface
                                            .withValues(alpha: 0.95),
                                      ),
                                    ),
                                  ],
                                ),
                                if (result.deletedModels.length <= 4) ...[
                                  const SizedBox(height: 8),
                                  ...result.deletedModels.map((model) =>
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 3),
                                        child: Row(
                                          children: [
                                            const SizedBox(width: 24),
                                            Container(
                                              width: 4,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: colorScheme
                                                    .onInverseSurface
                                                    .withValues(alpha: 0.7),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                model.name,
                                                style: textTheme.bodySmall
                                                    ?.copyWith(
                                                  fontFamily: 'monospace',
                                                  color: colorScheme
                                                      .onInverseSurface
                                                      .withValues(alpha: 0.8),
                                                  height: 1.3,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                ] else ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Including: ${result.deletedModels.take(2).map((m) => m.name).join(', ')}${result.deletedModels.length > 2 ? ', and ${result.deletedModels.length - 2} more' : ''}',
                                    style: textTheme.bodySmall?.copyWith(
                                      fontFamily: 'monospace',
                                      color: colorScheme.onInverseSurface
                                          .withValues(alpha: 0.75),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: colorScheme.inverseSurface,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: messages.aiConfigListUndoDelete,
              textColor: colorScheme.primary,
              onPressed: () {
                ref
                    .read(
                      inferenceProviderFormControllerProvider(
                              configId: config.id)
                          .notifier,
                    )
                    .addConfig(config);
              },
            ),
          ),
        );
      }).catchError((dynamic error) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              messages.aiConfigListErrorDeleting(config.name, error.toString()),
            ),
            backgroundColor: colorScheme.error,
          ),
        );
      });
    } else {
      // For models and prompts, use the regular delete method
      final repository = ref.read(aiConfigRepositoryProvider);

      repository.deleteConfig(config.id).then((_) {
        // Show simple success snackbar
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              messages.aiConfigListItemDeleted(config.name),
            ),
            action: SnackBarAction(
              label: messages.aiConfigListUndoDelete,
              onPressed: () {
                repository.saveConfig(config);
              },
            ),
          ),
        );
      }).catchError((dynamic error) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              messages.aiConfigListErrorDeleting(config.name, error.toString()),
            ),
            backgroundColor: colorScheme.error,
          ),
        );
      });
    }
  }

  Widget _buildConfigListTile(
      BuildContext context, AiConfig config, WidgetRef ref) {
    final subtitle = config.map(
      inferenceProvider: (_) => Text(
        config.description ?? '',
        maxLines: 2,
      ),
      model: (model) => ModelSubtitleWidget(model: model),
      prompt: (prompt) => Text(
        prompt.description ?? '',
        maxLines: 2,
      ),
    );

    // Check if this is a prompt with invalid models
    var hasInvalidModels = false;
    if (config is AiConfigPrompt) {
      // Check if any of the model IDs don't have corresponding model configs
      hasInvalidModels = _promptHasInvalidModels(config, ref);
    }

    return ListTile(
      title: Text(config.name),
      subtitle: subtitle,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasInvalidModels) ...[
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onItemTap != null ? () => onItemTap!(config) : null,
    );
  }

  /// Checks if a prompt has any invalid model references
  bool _promptHasInvalidModels(AiConfigPrompt prompt, WidgetRef ref) {
    for (final modelId in prompt.modelIds) {
      final modelAsync = ref.watch(aiConfigByIdProvider(modelId));

      // If the model config is not found or has an error, it's invalid
      if (modelAsync.hasError ||
          (modelAsync.hasValue && modelAsync.value == null)) {
        return true;
      }
    }
    return false;
  }
}
