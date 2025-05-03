import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/api_key_form_controller.dart';
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

  final String configType;
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
          child:
              Text(context.messages.aiConfigListErrorLoading(error.toString())),
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
      child: _buildConfigListTile(context, config),
    );
  }

  Future<bool> _showDeleteConfirmationDialog(
    BuildContext context,
    AiConfig config,
  ) async {
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
    final controller =
        ref.read(apiKeyFormControllerProvider(configId: config.id).notifier);

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

  Widget _buildConfigListTile(BuildContext context, AiConfig config) {
    final subtitle = _getConfigSubtitle(context, config);
    return ListTile(
      title: Text(config.name),
      subtitle: subtitle != null && subtitle.isNotEmpty ? Text(subtitle) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      trailing: const Icon(Icons.chevron_right),
      onTap: onItemTap != null ? () => onItemTap!(config) : null,
    );
  }

  String? _getConfigSubtitle(BuildContext context, AiConfig config) {
    return config.map(
      inferenceProvider: (apiKey) => apiKey.description,
      prompt: (prompt) {
        final previewLength =
            prompt.template.length > 50 ? 50 : prompt.template.length;
        final preview = prompt.template.substring(0, previewLength);
        return context.messages.aiConfigListPromptTemplateSubtitle(preview);
      },
      model: (AiConfigModel value) {
        return value.description;
      },
    );
  }
}
