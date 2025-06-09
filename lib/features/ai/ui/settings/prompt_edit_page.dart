import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/input_data_type_extensions.dart';
import 'package:lotti/features/ai/model/prompt_form_state.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/prompt_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/model_management_modal.dart';
import 'package:lotti/features/ai/ui/settings/prompt_input_type_selection.dart';
import 'package:lotti/features/ai/ui/settings/prompt_response_type_selection.dart';
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
        formState.requiredInputData.isNotEmpty &&
        formState.aiResponseType.value != null &&
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
          // Prompt Details Section
          AiFormSection(
            title: context.messages.promptDetailsTitle,
            icon: Icons.info_rounded,
            description: context.messages.promptDetailsDescription,
            children: [
              // Display Name
              AiTextField(
                label: context.messages.promptDisplayNameLabel,
                hint: context.messages.promptDisplayNameHint,
                controller: formController.nameController,
                onChanged: formController.nameChanged,
                validator: (_) => formState.name.error?.displayMessage,
                prefixIcon: Icons.label_outline_rounded,
              ),
              const SizedBox(height: 20),

              // Description
              AiTextField(
                label: context.messages.promptDescriptionLabel,
                hint: context.messages.promptDescriptionHint,
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
            title: context.messages.promptContentTitle,
            icon: Icons.edit_note_rounded,
            description: context.messages.promptContentDescription,
            children: [
              // System Prompt
              AiTextField(
                label: context.messages.promptSystemPromptLabel,
                hint: context.messages.promptSystemPromptHint,
                controller: formController.systemMessageController,
                onChanged: formController.systemMessageChanged,
                validator: (_) => formState.systemMessage.error?.displayMessage,
                minLines: 3,
              ),
              const SizedBox(height: 20),

              // User Prompt
              AiTextField(
                label: context.messages.promptUserPromptLabel,
                hint: context.messages.promptUserPromptHint,
                controller: formController.userMessageController,
                onChanged: formController.userMessageChanged,
                validator: (_) => formState.userMessage.error?.displayMessage,
                minLines: 3,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Prompt Behavior Section
          AiFormSection(
            title: context.messages.promptBehaviorTitle,
            icon: Icons.tune_rounded,
            description: context.messages.promptBehaviorDescription,
            children: [
              // Required Input Data Selection
              _buildSelectionCard(
                context: context,
                label: context.messages.promptRequiredInputDataLabel,
                description:
                    context.messages.promptRequiredInputDataDescription,
                icon: Icons.input_rounded,
                value: formState.requiredInputData.isEmpty
                    ? context.messages.promptSelectInputTypeHint
                    : formState.requiredInputData
                        .map((type) => type.displayName(context))
                        .join(', '),
                hasError: formState.requiredInputData.isEmpty,
                onTap: () {
                  InputDataTypeSelectionModal.show(
                    context: context,
                    selectedTypes: formState.requiredInputData,
                    onSave: formController.requiredInputDataChanged,
                  );
                },
              ),
              const SizedBox(height: 16),

              // AI Response Type Selection
              _buildSelectionCard(
                context: context,
                label: context.messages.promptAiResponseTypeLabel,
                description: context.messages.promptAiResponseTypeDescription,
                icon: Icons.output_rounded,
                value: formState.aiResponseType.value?.localizedName(context) ??
                    context.messages.promptSelectResponseTypeHint,
                hasError: formState.aiResponseType.error != null,
                errorText: formState.aiResponseType.error?.displayMessage,
                onTap: () {
                  ResponseTypeSelectionModal.show(
                    context: context,
                    selectedType: formState.aiResponseType.value,
                    onSave: formController.aiResponseTypeChanged,
                  );
                },
              ),
              const SizedBox(height: 20),

              // Reasoning Mode Switch
              AiSwitchField(
                label: context.messages.promptReasoningModeLabel,
                description: context.messages.promptReasoningModeDescription,
                value: formState.useReasoning,
                onChanged: formController.useReasoningChanged,
                icon: Icons.psychology_rounded,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Model Selection Section
          AiFormSection(
            title: context.messages.promptModelSelectionTitle,
            icon: Icons.model_training_rounded,
            description: context.messages.promptModelSelectionDescription,
            children: [
              _buildModelManagementButton(context, formState, formController),
            ],
          ),
          const SizedBox(height: 40),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: AiFormButton(
                  label: context.messages.promptCancelButton,
                  onPressed: () => Navigator.of(context).pop(),
                  style: AiButtonStyle.secondary,
                  fullWidth: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AiFormButton(
                  label: context.messages.promptSaveButton,
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
                    context.messages.promptNoModelsSelectedError,
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
          label: modelCount > 0
              ? context.messages.promptAddOrRemoveModelsButton
              : context.messages.promptSelectModelsButton,
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
              context.messages.promptTryAgainMessage,
              style: TextStyle(
                fontSize: 14,
                color: context.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AiFormButton(
              label: context.messages.promptGoBackButton,
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
                            context.messages.promptDefaultModelBadge,
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
                            context.messages.promptSetDefaultButton,
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
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(context.messages.promptLoadingModel),
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
              context.messages.promptErrorLoadingModel,
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

Widget _buildSelectionCard({
  required BuildContext context,
  required String label,
  required String description,
  required IconData icon,
  required String value,
  required VoidCallback onTap,
  bool hasError = false,
  String? errorText,
}) {
  final isPlaceholder = value == context.messages.promptSelectInputTypeHint ||
      value == context.messages.promptSelectResponseTypeHint;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Label
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colorScheme.onSurfaceVariant,
                letterSpacing: 0.3,
              ),
            ),
            if (hasError) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.error_outline_rounded,
                size: 16,
                color: context.colorScheme.error,
              ),
            ],
          ],
        ),
      ),
      // Selection Card
      Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.colorScheme.surfaceContainer.withValues(alpha: 0.3),
                  context.colorScheme.surfaceContainerHigh
                      .withValues(alpha: 0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasError
                    ? context.colorScheme.error.withValues(alpha: 0.5)
                    : context.colorScheme.primaryContainer
                        .withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
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
                    icon,
                    size: 22,
                    color: context.colorScheme.primary.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isPlaceholder
                              ? context.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.6)
                              : context.colorScheme.onSurface,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: context.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
      // Error text
      if (hasError && errorText != null) ...[
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            errorText,
            style: TextStyle(
              fontSize: 12,
              color: context.colorScheme.error,
            ),
          ),
        ),
      ],
    ],
  );
}
