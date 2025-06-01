import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
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
                            'This will also delete all models associated with this provider.',
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
    final controller = ref.read(
      inferenceProviderFormControllerProvider(configId: config.id).notifier,
    );

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final messages = context.messages;

    controller.deleteConfig(config.id).then((_) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(messages.aiConfigListItemDeleted(config.name)),
          action: SnackBarAction(
            label: messages.aiConfigListUndoDelete,
            onPressed: () {
              controller.addConfig(config);
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
          backgroundColor: errorColor,
        ),
      );
    });
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
