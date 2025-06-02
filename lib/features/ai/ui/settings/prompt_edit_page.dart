import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    // Watch the form state to enable/disable save button
    final formState =
        ref.watch(promptFormControllerProvider(configId: configId)).valueOrNull;

    final isFormValid = formState != null &&
        formState.isValid &&
        formState.modelIds.isNotEmpty &&
        formState.defaultModelId.isNotEmpty &&
        formState.modelIds.contains(formState.defaultModelId) &&
        (configId == null || formState.isDirty);

    // Create save handler that can be used by both app bar action and keyboard shortcut
    Future<void> handleSave() async {
      if (!isFormValid) return;

      final config = formState.toAiConfig();
      final controller = ref.read(
        promptFormControllerProvider(configId: configId).notifier,
      );

      if (configId == null) {
        await controller.addConfig(config);
      } else {
        await controller.updateConfig(config);
      }

      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
          if (isFormValid) {
            handleSave();
          }
        },
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            configId == null
                ? context.messages.promptAddPageTitle
                : context.messages.promptEditPageTitle,
          ),
          actions: [
            if (isFormValid)
              TextButton(
                onPressed: handleSave,
                child: Text(
                  context.messages.saveButtonLabel,
                  style: TextStyle(
                    color: context.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
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
      ),
    );
  }

  Widget _buildForm(BuildContext context, WidgetRef ref, AiConfig? config) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: PromptForm(
          configId: config?.id,
        ),
      ),
    );
  }
}
