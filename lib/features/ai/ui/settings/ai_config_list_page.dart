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
              return _buildConfigListTile(context, config);
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
