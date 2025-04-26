import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/settings/api_key_form.dart';
import 'package:lotti/themes/theme.dart';

/// Edit page for API keys
class ApiKeyEditPage extends ConsumerWidget {
  const ApiKeyEditPage({
    this.configId,
    super.key,
  });

  static const String routeName = '/settings/ai/api-keys/edit';

  final String? configId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen for the config if editing an existing one
    final configAsync = configId != null
        ? ref.watch(aiConfigByIdProvider(configId!))
        : const AsyncData<AiConfig?>(null);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          configId == null ? 'Add API Key' : 'Edit API Key',
        ),
      ),
      body: switch (configAsync) {
        AsyncData(value: final config) => _buildForm(context, ref, config),
        AsyncError() => Center(
            child: Text(
              'Failed to load API key configuration',
              style: context.textTheme.bodyLarge?.copyWith(
                color: context.colorScheme.error,
              ),
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _buildForm(BuildContext context, WidgetRef ref, AiConfig? config) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: ApiKeyForm(
          config: config,
          onSave: (updatedConfig) async {
            final controller = ref.read(
              aiConfigByTypeControllerProvider(configType: 'apiKey').notifier,
            );

            if (configId == null) {
              // Add new config
              await controller.addConfig(updatedConfig);
            } else {
              // Update existing config
              await controller.updateConfig(updatedConfig);
            }

            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    );
  }
}
