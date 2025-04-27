import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';

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
                'No configurations found. Add one to get started.',
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
          child: Text('Error loading configurations: $error'),
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
            title: const Text('Confirm Deletion'),
            content: Text('Are you sure you want to delete "${config.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('DELETE'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _deleteConfig(AiConfig config, WidgetRef ref, BuildContext context) {
    final controller = ref.read(
      aiConfigByTypeControllerProvider(configType: configType).notifier,
    );

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    controller.deleteConfig(config.id).then((_) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('${config.name} deleted'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              controller.addConfig(config);
            },
          ),
        ),
      );
    }).catchError((dynamic error) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error deleting ${config.name}: $error'),
          backgroundColor: errorColor,
        ),
      );
    });
  }

  Widget _buildConfigListTile(BuildContext context, AiConfig config) {
    return ListTile(
      title: Text(config.name),
      subtitle: Text(_getConfigSubtitle(config)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onItemTap != null ? () => onItemTap!(config) : null,
    );
  }

  String _getConfigSubtitle(AiConfig config) {
    return config.map(
      apiKey: (apiKey) => apiKey.baseUrl,
      promptTemplate: (promptTemplate) =>
          'Template: ${promptTemplate.template.substring(0, promptTemplate.template.length > 50 ? 50 : promptTemplate.template.length)}...',
    );
  }
}
