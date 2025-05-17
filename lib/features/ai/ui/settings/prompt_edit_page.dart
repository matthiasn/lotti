import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/prompt_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/prompt_form.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class PromptEditPage extends ConsumerWidget {
  const PromptEditPage({
    this.configId,
    super.key,
  });

  static const String routeName = '/settings/ai/prompts/edit';

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
          configId == null
              ? context.messages.promptAddPageTitle
              : context.messages.promptEditPageTitle,
        ),
      ),
      body: switch (configAsync) {
        AsyncData(value: final config) => _buildForm(context, ref, config),
        AsyncError() => Center(
            child: Text(
              context.messages.promptEditLoadError,
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
        child: PromptForm(
          config: config,
          onSave: (updatedConfig) async {
            final controller = ref.read(
              promptFormControllerProvider(configId: config?.id).notifier,
            );

            if (configId == null) {
              await controller.addConfig(updatedConfig);
            } else {
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
