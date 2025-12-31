import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_provider_extensions.dart';
import 'package:lotti/features/ai/model/inference_provider_form_state.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/settings/inference_provider_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/form_bottom_bar.dart';
import 'package:lotti/features/ai/ui/settings/services/provider_prompt_setup_service.dart';
import 'package:lotti/features/ai/ui/settings/widgets/form_components/form_components.dart';
import 'package:lotti/features/ai/ui/settings/widgets/form_components/form_error_extension.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_type_selection_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';

class InferenceProviderEditPage extends ConsumerStatefulWidget {
  const InferenceProviderEditPage({
    this.configId,
    super.key,
  });

  final String? configId;

  @override
  ConsumerState<InferenceProviderEditPage> createState() =>
      _InferenceProviderEditPageState();
}

class _InferenceProviderEditPageState
    extends ConsumerState<InferenceProviderEditPage> {
  bool _showApiKey = false;

  @override
  Widget build(BuildContext context) {
    // Listen for the config if editing an existing one
    final configAsync = widget.configId != null
        ? ref.watch(aiConfigByIdProvider(widget.configId!))
        : const AsyncData<AiConfig?>(null);

    // Watch the form state to enable/disable save button
    final formState = ref
        .watch(
            inferenceProviderFormControllerProvider(configId: widget.configId))
        .value;

    final isFormValid = formState != null &&
        formState.isValid &&
        (widget.configId == null || formState.isDirty);

    // Create save handler that can be used by both app bar action and keyboard shortcut
    Future<void> handleSave() async {
      if (!isFormValid) return;

      final config = formState.toAiConfig();
      final controller = ref.read(
        inferenceProviderFormControllerProvider(
          configId: widget.configId,
        ).notifier,
      );

      if (widget.configId == null) {
        await controller.addConfig(config);

        // Offer to set up default prompts for supported providers
        if (context.mounted && config is AiConfigInferenceProvider) {
          final setupService = ref.read(providerPromptSetupServiceProvider);
          await setupService.offerPromptSetup(
            context: context,
            ref: ref,
            provider: config,
          );
        }
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
        backgroundColor: context.colorScheme.surface,
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Clean App Bar
                  SliverAppBar(
                    expandedHeight: 100,
                    pinned: true,
                    backgroundColor: context.colorScheme.surface,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: Icon(
                        Icons.chevron_left_rounded,
                        color: context.colorScheme.onSurface,
                        size: 28,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.only(bottom: 16),
                      title: Text(
                        widget.configId == null
                            ? context.messages.apiKeyAddPageTitle
                            : context.messages.apiKeyEditPageTitle,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: context.colorScheme.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  // Form Content
                  SliverToBoxAdapter(
                    child: switch (configAsync) {
                      AsyncData(value: final config) => _buildForm(context, ref,
                          config, formState, isFormValid, handleSave),
                      AsyncError() => _buildErrorState(context),
                      _ => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(48),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    },
                  ),
                ],
              ),
            ),
            // Fixed bottom bar
            FormBottomBar(
              onSave: isFormValid ? handleSave : null,
              onCancel: () => Navigator.of(context).pop(),
              isFormValid: isFormValid,
              isDirty: widget.configId == null || (formState?.isDirty ?? false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    WidgetRef ref,
    AiConfig? config,
    InferenceProviderFormState? formState,
    bool isFormValid,
    Future<void> Function() handleSave,
  ) {
    if (formState == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final formController = ref.read(
      inferenceProviderFormControllerProvider(configId: widget.configId)
          .notifier,
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Provider Configuration Section
          AiFormSection(
            title: 'Provider Configuration',
            icon: Icons.settings_rounded,
            description: 'Configure your AI inference provider settings',
            children: [
              // Provider Type Selection
              GestureDetector(
                onTap: () => _showProviderTypeModal(context),
                child: AbsorbPointer(
                  child: AiTextField(
                    label: 'Provider Type',
                    hint: 'Select a provider type',
                    readOnly: true,
                    controller: TextEditingController(
                      text:
                          formState.inferenceProviderType.displayName(context),
                    ),
                    prefixIcon: formState.inferenceProviderType.icon,
                    suffixIcon: Icon(
                      Icons.arrow_drop_down_rounded,
                      color: context.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Display Name
              AiTextField(
                label: 'Display Name',
                hint: 'Enter a friendly name',
                controller: formController.nameController,
                onChanged: formController.nameChanged,
                validator: (_) => formState.name.error?.displayMessage,
                prefixIcon: Icons.label_outline_rounded,
              ),
              const SizedBox(height: 20),

              // Base URL
              AiTextField(
                label: 'Base URL',
                hint: 'https://api.example.com',
                controller: formController.baseUrlController,
                onChanged: formController.baseUrlChanged,
                validator: (_) => formState.baseUrl.error?.displayMessage,
                keyboardType: TextInputType.url,
                prefixIcon: Icons.link_rounded,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Authentication Section - Only show for providers that require API key
          if (!ProviderConfig.noApiKeyRequired
              .contains(formState.inferenceProviderType)) ...[
            AiFormSection(
              title: 'Authentication',
              icon: Icons.security_rounded,
              description: 'Secure your API connection',
              children: [
                // API Key
                AiTextField(
                  label: 'API Key',
                  hint: 'Enter your API key',
                  controller: formController.apiKeyController,
                  onChanged: formController.apiKeyChanged,
                  validator: (_) => formState.apiKey.error?.displayMessage,
                  obscureText: !_showApiKey,
                  prefixIcon: Icons.key_rounded,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showApiKey
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: context.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.6),
                    ),
                    onPressed: () => setState(() {
                      _showApiKey = !_showApiKey;
                    }),
                    tooltip: _showApiKey ? 'Hide API Key' : 'Show API Key',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  void _showProviderTypeModal(BuildContext context) {
    ProviderTypeSelectionModal.show(
      context: context,
      configId: widget.configId,
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    context.colorScheme.errorContainer.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: context.colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.messages.apiKeyEditLoadError,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please try again or contact support',
              style: TextStyle(
                fontSize: 14,
                color: context.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            LottiSecondaryButton(
              label: 'Go Back',
              onPressed: () => Navigator.of(context).pop(),
              icon: Icons.arrow_back_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
