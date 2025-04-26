import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/ai_config_list_page.dart';

/// Page to manage API key configurations
class ApiKeysSettingsPage extends ConsumerWidget {
  const ApiKeysSettingsPage({super.key});

  static const String routeName = '/settings/ai/api-keys';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AiConfigListPage(
      configType: 'apiKey',
      title: 'API Keys',
      onAddPressed: () => _navigateToEditPage(context, null),
      onItemTap: (config) => _navigateToEditPage(context, config),
    );
  }

  void _navigateToEditPage(BuildContext context, AiConfig? config) {
    // In a real implementation, navigate to an edit page
    // For now, just show a dialog
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(config == null ? 'Add API Key' : 'Edit API Key'),
        content: const Text('Edit page would go here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
