import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/inference_provider_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/model_subtitle_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';

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
        return _showDeleteConfirmationDialog(context, config);
      },
      onDismissed: (direction) {
        _deleteConfig(config, ref, context);
      },
      child: _buildConfigListTile(context, config, ref),
    );
  }

  Future<bool> _showDeleteConfirmationDialog(
    BuildContext context,
    AiConfig config,
  ) async {
    return showConfirmationModal(
      context: context,
      title: context.messages.aiConfigListDeleteConfirmTitle,
      message: context.messages.aiConfigListDeleteConfirmMessage(config.name),
      confirmLabel: context.messages.aiConfigListDeleteConfirmDelete,
      cancelLabel: context.messages.aiConfigListDeleteConfirmCancel,
    );
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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Icon(
                  Icons.delete_forever_outlined,
                  size: 48,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  messages.aiConfigProviderDeletedSuccessfully,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (result.deletedModels.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.inversePrimary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.analytics_outlined,
                              size: 16,
                              color: colorScheme.onSurface.withAlpha(230),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              messages.aiConfigAssociatedModelsRemoved(
                                  result.deletedModels.length),
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurface.withAlpha(242),
                              ),
                            ),
                          ],
                        ),
                        if (result.deletedModels.length <= 4) ...[
                          const SizedBox(height: 8),
                          ...result.deletedModels.map((model) => Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 24),
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: colorScheme.onSurface
                                            .withAlpha(179),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        model.name,
                                        style: textTheme.bodySmall?.copyWith(
                                          fontFamily: 'monospace',
                                          color: colorScheme.onSurface
                                              .withAlpha(204),
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
                              color: colorScheme.onSurface.withAlpha(191),
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
            backgroundColor: colorScheme.inversePrimary,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 5),
            dismissDirection: DismissDirection.down,
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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  messages.aiConfigListErrorDeleting(
                      config.name, error.toString()),
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            backgroundColor: colorScheme.inversePrimary,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            dismissDirection: DismissDirection.down,
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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Icon(
                  Icons.delete_forever_outlined,
                  size: 48,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  messages.aiConfigListItemDeleted(config.name),
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            backgroundColor: colorScheme.inversePrimary,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 5),
            dismissDirection: DismissDirection.down,
            action: SnackBarAction(
              label: messages.aiConfigListUndoDelete,
              textColor: colorScheme.primary,
              onPressed: () {
                repository.saveConfig(config);
              },
            ),
          ),
        );
      }).catchError((dynamic error) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  messages.aiConfigListErrorDeleting(
                      config.name, error.toString()),
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            backgroundColor: colorScheme.inversePrimary,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            dismissDirection: DismissDirection.down,
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
