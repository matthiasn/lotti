import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/prompt_form_state.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/prompt_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/model_management_modal.dart';
import 'package:lotti/features/ai/ui/settings/widgets/form_components/form_components.dart';
import 'package:lotti/features/ai/ui/settings/widgets/form_components/form_error_extension.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class PromptEditPage extends ConsumerStatefulWidget {
  const PromptEditPage({
    this.configId,
    super.key,
  });

  static const String routeName = '/settings/ai/prompts/edit';

  final String? configId;

  @override
  ConsumerState<PromptEditPage> createState() => _PromptEditPageState();
}

class _PromptEditPageState extends ConsumerState<PromptEditPage> {
  @override
  Widget build(BuildContext context) {
    // Listen for the config if editing an existing one
    final configAsync = widget.configId != null
        ? ref.watch(aiConfigByIdProvider(widget.configId!))
        : const AsyncData<AiConfig?>(null);

    // Watch the form state to enable/disable save button
    final formState = ref
        .watch(promptFormControllerProvider(configId: widget.configId))
        .valueOrNull;

    final isFormValid = formState != null &&
        formState.isValid &&
        formState.modelIds.isNotEmpty &&
        formState.defaultModelId.isNotEmpty &&
        formState.modelIds.contains(formState.defaultModelId) &&
        (widget.configId == null || formState.isDirty);

    // Create save handler that can be used by both app bar action and keyboard shortcut
    Future<void> handleSave() async {
      if (!isFormValid) return;

      final config = formState.toAiConfig();
      final controller = ref.read(
        promptFormControllerProvider(configId: widget.configId).notifier,
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
        backgroundColor: context.colorScheme.scrim,
        body: CustomScrollView(
          slivers: [
            // Modern App Bar
            SliverAppBar(
              expandedHeight: 120,
              pinned: true,
              backgroundColor: context.colorScheme.scrim,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: Icon(
                  Icons.chevron_left_rounded,
                  color: context.colorScheme.onSurface,
                  size: 28,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
                title: Text(
                  widget.configId == null
                      ? context.messages.promptAddPageTitle
                      : context.messages.promptEditPageTitle,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: context.colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.colorScheme.primaryContainer
                            .withValues(alpha: 0.1),
                        context.colorScheme.scrim,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
            // Form Content
            SliverToBoxAdapter(
              child: switch (configAsync) {
                AsyncData(value: final config) => _buildForm(
                    context, ref, config, formState, isFormValid, handleSave),
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
    );
  }

  Widget _buildForm(
    BuildContext context,
    WidgetRef ref,
    AiConfig? config,
    PromptFormState? formState,
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
      promptFormControllerProvider(configId: widget.configId).notifier,
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Basic Information Section
          AiFormSection(
            title: 'Basic Information',
            icon: Icons.info_rounded,
            description: 'Configure prompt details and behavior',
            children: [
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

              // Description
              AiTextField(
                label: 'Description',
                hint: 'Describe this prompt',
                controller: formController.descriptionController,
                onChanged: formController.descriptionChanged,
                validator: (_) => formState.description.error?.displayMessage,
                maxLines: 3,
                minLines: 2,
                prefixIcon: Icons.description_rounded,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Prompt Content Section
          AiFormSection(
            title: 'Prompt Content',
            icon: Icons.edit_note_rounded,
            description: 'Define the system and user prompts',
            children: [
              // System Prompt
              AiTextField(
                label: 'System Prompt',
                hint: 'Enter the system prompt...',
                controller: formController.systemMessageController,
                onChanged: formController.systemMessageChanged,
                validator: (_) => formState.systemMessage.error?.displayMessage,
                minLines: 3,
              ),
              const SizedBox(height: 20),

              // User Prompt
              AiTextField(
                label: 'User Prompt',
                hint: 'Enter the user prompt...',
                controller: formController.userMessageController,
                onChanged: formController.userMessageChanged,
                validator: (_) => formState.userMessage.error?.displayMessage,
                minLines: 3,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Model Configuration Section
          AiFormSection(
            title: 'Model Configuration',
            icon: Icons.model_training_rounded,
            description: 'Select compatible models and default',
            children: [
              _buildModelManagementButton(context, formState, formController),
            ],
          ),
          const SizedBox(height: 32),

          // Settings Section
          AiFormSection(
            title: 'Settings',
            icon: Icons.tune_rounded,
            description: 'Configure prompt behavior',
            children: [
              // Reasoning Mode Switch
              AiSwitchField(
                label: 'Reasoning Mode',
                description: 'Enable for prompts requiring deep thinking',
                value: formState.useReasoning,
                onChanged: formController.useReasoningChanged,
                icon: Icons.psychology_rounded,
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: AiFormButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                  style: AiButtonStyle.secondary,
                  fullWidth: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AiFormButton(
                  label: 'Save Prompt',
                  onPressed: isFormValid ? handleSave : null,
                  icon: Icons.save_rounded,
                  fullWidth: true,
                  enabled: isFormValid,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40), // Extra padding at bottom
        ],
      ),
    );
  }

  Widget _buildModelManagementButton(
    BuildContext context,
    PromptFormState formState,
    PromptFormController controller,
  ) {
    final modelCount = formState.modelIds.length;

    // Create a temporary prompt config to check model suitability
    final tempPromptConfig = AiConfigPrompt(
      id: 'temp',
      name: 'temp',
      systemMessage: '',
      userMessage: '',
      defaultModelId: '',
      modelIds: [],
      createdAt: DateTime.now(),
      useReasoning: formState.useReasoning,
      requiredInputData: formState.requiredInputData,
      aiResponseType:
          formState.aiResponseType.value ?? AiResponseType.taskSummary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected models list
        if (modelCount > 0) ...[
          ...formState.modelIds.map((modelId) {
            final isDefault = modelId == formState.defaultModelId;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ModelListItem(
                modelId: modelId,
                isDefault: isDefault,
                onSetDefault: () => controller.defaultModelIdChanged(modelId),
                onRemove: () {
                  final updatedIds =
                      formState.modelIds.where((id) => id != modelId).toList();
                  controller.modelIdsChanged(updatedIds);

                  // If removing the default model, set a new default
                  if (isDefault && updatedIds.isNotEmpty) {
                    controller.defaultModelIdChanged(updatedIds.first);
                  }
                },
              ),
            );
          }),
        ] else ...[
          // Empty state
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colorScheme.errorContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.colorScheme.error.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_rounded,
                  color: context.colorScheme.error,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No models selected. Select at least one model.',
                    style: TextStyle(
                      color: context.colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Manage Models Button
        AiFormButton(
          label: modelCount > 0 ? 'Add or Remove Models' : 'Select Models',
          onPressed: () {
            showModelManagementModal(
              context: context,
              currentSelectedIds: formState.modelIds,
              currentDefaultId: formState.defaultModelId,
              promptConfig: tempPromptConfig,
              onSave: (List<String> newSelectedIds, String newDefaultId) {
                controller.modelIdsChanged(newSelectedIds);
                if (newSelectedIds.contains(newDefaultId)) {
                  controller.defaultModelIdChanged(newDefaultId);
                }
              },
            );
          },
          icon: Icons.tune_rounded,
          fullWidth: true,
          style: modelCount > 0 ? AiButtonStyle.text : AiButtonStyle.primary,
        ),
      ],
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
              context.messages.promptEditLoadError,
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

// Widget to display individual model in the selected models list
class _ModelListItem extends ConsumerWidget {
  const _ModelListItem({
    required this.modelId,
    required this.isDefault,
    required this.onSetDefault,
    required this.onRemove,
  });

  final String modelId;
  final bool isDefault;
  final VoidCallback onSetDefault;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelAsync = ref.watch(aiConfigByIdProvider(modelId));

    return modelAsync.when(
      data: (model) {
        if (model == null) return const SizedBox.shrink();

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                if (isDefault)
                  context.colorScheme.primaryContainer.withValues(alpha: 0.15)
                else
                  context.colorScheme.surfaceContainer.withValues(alpha: 0.3),
                if (isDefault)
                  context.colorScheme.primaryContainer.withValues(alpha: 0.1)
                else
                  context.colorScheme.surfaceContainerHigh
                      .withValues(alpha: 0.2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDefault
                  ? context.colorScheme.primary.withValues(alpha: 0.3)
                  : context.colorScheme.primaryContainer.withValues(alpha: 0.2),
              width: isDefault ? 1.5 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Model icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.colorScheme.primaryContainer
                              .withValues(alpha: 0.3),
                          context.colorScheme.primaryContainer
                              .withValues(alpha: 0.2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            context.colorScheme.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Icon(
                      _getModelIcon(model.name),
                      size: 20,
                      color: context.colorScheme.primary.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Model info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                        if (model.description != null &&
                            model.description!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            model.description!,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Default button/indicator
                  if (isDefault) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: context.colorScheme.primary
                                .withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: context.colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Default',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: onSetDefault,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: context.colorScheme.primaryContainer
                                  .withValues(alpha: 0.5),
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Set Default',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: context.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),

                  // Remove button
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: onRemove,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: context.colorScheme.errorContainer
                              .withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: context.colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Loading model...'),
          ],
        ),
      ),
      error: (_, __) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colorScheme.errorContainer.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.colorScheme.error.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 20,
              color: context.colorScheme.error,
            ),
            const SizedBox(width: 12),
            Text(
              'Error loading model',
              style: TextStyle(color: context.colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getModelIcon(String modelName) {
    final name = modelName.toLowerCase();
    if (name.contains('gpt')) return Icons.psychology_rounded;
    if (name.contains('claude')) return Icons.auto_awesome_rounded;
    if (name.contains('gemini')) return Icons.diamond_rounded;
    if (name.contains('opus')) return Icons.workspace_premium_rounded;
    if (name.contains('sonnet')) return Icons.edit_note_rounded;
    if (name.contains('haiku')) return Icons.flash_on_rounded;
    return Icons.smart_toy_rounded;
  }
}
