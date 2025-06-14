import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_model_form_state.dart';
import 'package:lotti/features/ai/model/modality_extensions.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/inference_model_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/form_bottom_bar.dart';
import 'package:lotti/features/ai/ui/settings/widgets/form_components/form_components.dart';
import 'package:lotti/features/ai/ui/settings/widgets/form_components/form_error_extension.dart';
import 'package:lotti/features/ai/ui/settings/widgets/modality_selection_modal.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_selection_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class InferenceModelEditPage extends ConsumerStatefulWidget {
  const InferenceModelEditPage({
    this.configId,
    super.key,
  });

  static const String routeName = '/settings/ai/models/edit';

  final String? configId;

  @override
  ConsumerState<InferenceModelEditPage> createState() =>
      _InferenceModelEditPageState();
}

class _InferenceModelEditPageState
    extends ConsumerState<InferenceModelEditPage> {
  @override
  Widget build(BuildContext context) {
    // Listen for the config if editing an existing one
    final configAsync = widget.configId == null
        ? const AsyncData<AiConfig?>(null)
        : ref.watch(aiConfigByIdProvider(widget.configId!));

    // Watch the form state to enable/disable save button
    final formState = ref
        .watch(inferenceModelFormControllerProvider(configId: widget.configId))
        .valueOrNull;

    final isFormValid = formState != null &&
        formState.isValid &&
        formState.inferenceProviderId.isNotEmpty &&
        formState.inputModalities.isNotEmpty &&
        formState.outputModalities.isNotEmpty &&
        (widget.configId == null || formState.isDirty);

    // Create save handler that can be used by both app bar action and keyboard shortcut
    Future<void> handleSave() async {
      if (!isFormValid) return;

      final config = formState.toAiConfig();
      final controller = ref.read(
        inferenceModelFormControllerProvider(
          configId: widget.configId,
        ).notifier,
      );

      if (widget.configId == null) {
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
                            ? context.messages.modelAddPageTitle
                            : context.messages.modelEditPageTitle,
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
    InferenceModelFormState? formState,
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
      inferenceModelFormControllerProvider(configId: widget.configId).notifier,
    );

    // Get provider name for display
    final providerAsync = formState.inferenceProviderId.isNotEmpty
        ? ref.watch(aiConfigByIdProvider(formState.inferenceProviderId))
        : const AsyncData<AiConfig?>(null);

    final providerName = switch (providerAsync) {
      AsyncData(value: final provider) when provider != null => provider.name,
      _ => 'Select a provider',
    };

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Basic Configuration Section
          AiFormSection(
            title: 'Basic Configuration',
            icon: Icons.settings_rounded,
            description: 'Configure your AI model settings',
            children: [
              // Provider Selection
              GestureDetector(
                onTap: () => _showProviderSelectionModal(
                  context,
                  formController,
                  formState.inferenceProviderId,
                ),
                child: AbsorbPointer(
                  child: AiTextField(
                    label: 'Provider',
                    hint: 'Select a provider',
                    readOnly: true,
                    controller: TextEditingController(text: providerName),
                    prefixIcon: Icons.cloud_rounded,
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

              // Provider Model ID
              AiTextField(
                label: 'Provider Model ID',
                hint: 'e.g., gpt-4-turbo',
                controller: formController.providerModelIdController,
                onChanged: formController.providerModelIdChanged,
                validator: (_) =>
                    formState.providerModelId.error?.displayMessage,
                prefixIcon: Icons.fingerprint_rounded,
              ),
              const SizedBox(height: 20),

              // Description
              AiTextField(
                label: 'Description',
                hint: 'Describe this model',
                controller: formController.descriptionController,
                onChanged: formController.descriptionChanged,
                validator: (_) => formState.description.error,
                maxLines: 3,
                minLines: 2,
                prefixIcon: Icons.description_rounded,
              ),
              const SizedBox(height: 20),

              // Max Completion Tokens
              AiTextField(
                label: 'Max Completion Tokens',
                hint: 'Optional - leave empty for unlimited',
                controller: formController.maxCompletionTokensController,
                onChanged: formController.maxCompletionTokensChanged,
                validator: (_) =>
                    formState.maxCompletionTokens.error?.displayMessage,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.numbers_rounded,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Capabilities Section
          AiFormSection(
            title: 'Capabilities',
            icon: Icons.psychology_rounded,
            description: 'Define model input and output modalities',
            children: [
              // Input Modalities
              GestureDetector(
                onTap: () => _showModalitySelectionModal(
                  context,
                  'Input Modalities',
                  formState.inputModalities,
                  formController.inputModalitiesChanged,
                ),
                child: AbsorbPointer(
                  child: AiTextField(
                    label: 'Input Modalities',
                    hint: 'Select input types',
                    readOnly: true,
                    controller: TextEditingController(
                      text: _formatModalities(formState.inputModalities),
                    ),
                    prefixIcon: Icons.input_rounded,
                    suffixIcon: Icon(
                      Icons.arrow_drop_down_rounded,
                      color: context.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Output Modalities
              GestureDetector(
                onTap: () => _showModalitySelectionModal(
                  context,
                  'Output Modalities',
                  formState.outputModalities,
                  formController.outputModalitiesChanged,
                ),
                child: AbsorbPointer(
                  child: AiTextField(
                    label: 'Output Modalities',
                    hint: 'Select output types',
                    readOnly: true,
                    controller: TextEditingController(
                      text: _formatModalities(formState.outputModalities),
                    ),
                    prefixIcon: Icons.output_rounded,
                    suffixIcon: Icon(
                      Icons.arrow_drop_down_rounded,
                      color: context.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Is Reasoning Model Switch
              AiSwitchField(
                label: 'Reasoning Model',
                description: 'This model has advanced reasoning capabilities',
                value: formState.isReasoningModel,
                onChanged: formController.isReasoningModelChanged,
                icon: Icons.psychology_alt_rounded,
              ),
            ],
          ),
          const SizedBox(height: 32),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showProviderSelectionModal(
    BuildContext context,
    InferenceModelFormController controller,
    String selectedProviderId,
  ) {
    ProviderSelectionModal.show(
      context: context,
      onProviderSelected: controller.inferenceProviderIdChanged,
      selectedProviderId: selectedProviderId,
    );
  }

  void _showModalitySelectionModal(
    BuildContext context,
    String title,
    List<Modality> selectedModalities,
    void Function(List<Modality>) onChanged,
  ) {
    ModalitySelectionModal.show(
      context: context,
      title: title,
      selectedModalities: selectedModalities,
      onSave: onChanged,
    );
  }

  String _formatModalities(List<Modality> modalities) {
    if (modalities.isEmpty) return 'None selected';
    return modalities.map((m) => m.displayName(context)).join(', ');
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
              context.messages.modelEditLoadError,
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
            AiFormButton(
              label: 'Go Back',
              onPressed: () => Navigator.of(context).pop(),
              icon: Icons.arrow_back_rounded,
              style: AiButtonStyle.secondary,
            ),
          ],
        ),
      ),
    );
  }
}
