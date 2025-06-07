import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/prompt_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/enhanced_prompt_form.dart';
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
        backgroundColor: context.colorScheme.surfaceContainer,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: context.colorScheme.onSurface,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            configId == null
                ? context.messages.promptAddPageTitle
                : context.messages.promptEditPageTitle,
            style: context.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colorScheme.onSurface,
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: AnimatedScale(
                scale: isFormValid ? 1.0 : 0.9,
                duration: const Duration(milliseconds: 200),
                child: AnimatedOpacity(
                  opacity: isFormValid ? 1.0 : 0.6,
                  duration: const Duration(milliseconds: 200),
                  child: ElevatedButton.icon(
                    onPressed: isFormValid ? handleSave : null,
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: Text(
                      context.messages.saveButtonLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colorScheme.primary,
                      foregroundColor: context.colorScheme.onPrimary,
                      disabledBackgroundColor: context.colorScheme.outline.withValues(alpha: 0.3),
                      elevation: isFormValid ? 2 : 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: switch (configAsync) {
          AsyncData(value: final config) => _buildForm(context, ref, config),
          AsyncError() => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: context.colorScheme.error.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.messages.promptEditLoadError,
                    style: context.textTheme.titleMedium?.copyWith(
                      color: context.colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, WidgetRef ref, AiConfig? config) {
    return EnhancedPromptForm(
      configId: config?.id,
    );
  }
}
