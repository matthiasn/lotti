import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/prompt_form_state.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/settings/prompt_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/ai_config_card.dart';
import 'package:lotti/features/ai/ui/settings/model_management_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

// Main widget that orchestrates the model selection
class PromptFormSelectModel extends ConsumerStatefulWidget {
  const PromptFormSelectModel({
    this.configId,
    super.key,
  });

  final String? configId;

  @override
  ConsumerState<PromptFormSelectModel> createState() =>
      _PromptFormSelectModelState();
}

class _PromptFormSelectModelState extends ConsumerState<PromptFormSelectModel> {
  void _showModelManagementModal({
    required List<String> currentSelectedIds,
    required String currentDefaultId,
    required PromptFormController formController,
    required PromptFormState formState,
  }) {
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

    showModelManagementModal(
      context: context,
      currentSelectedIds: currentSelectedIds,
      currentDefaultId: currentDefaultId,
      promptConfig: tempPromptConfig,
      onSave: (List<String> newSelectedIds, String newDefaultIdFromModal) {
        formController.modelIdsChanged(newSelectedIds);

        // After modelIdsChanged, the controller might have already updated defaultModelId in its state.
        // We set the defaultModelId to what the user explicitly chose in the modal,
        // but only if it's part of the newSelectedIds (which should be guaranteed by modal logic).
        // We also check if it actually needs changing.
        final controllerProvider =
            promptFormControllerProvider(configId: widget.configId);
        final currentDefaultInState =
            ref.read(controllerProvider).valueOrNull?.defaultModelId;

        if (newSelectedIds.contains(newDefaultIdFromModal)) {
          if (currentDefaultInState != newDefaultIdFromModal) {
            formController.defaultModelIdChanged(newDefaultIdFromModal);
          }
        } else if (newSelectedIds.isEmpty) {
          // If the list became empty, ensure default is cleared.
          // modelIdsChanged should handle this, but as a safeguard:
          if (currentDefaultInState != '') {
            formController.defaultModelIdChanged('');
          }
        }
        // If newDefaultIdFromModal is not in newSelectedIds, but newSelectedIds is not empty,
        // modelIdsChanged will have picked the first item as default. We respect that choice implicitly
        // by not calling defaultModelIdChanged if the modal's default is now invalid.
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final configId = widget.configId;
    final formState =
        ref.watch(promptFormControllerProvider(configId: configId)).valueOrNull;
    final formController = ref.read(
      promptFormControllerProvider(configId: configId).notifier,
    );

    if (formState == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ModelManagementHeader(
          onManageTap: () => _showModelManagementModal(
            currentSelectedIds: formState.modelIds,
            currentDefaultId: formState.defaultModelId,
            formController: formController,
            formState: formState,
          ),
        ),
        const SizedBox(height: 12),
        if (formState.modelIds.isEmpty)
          const EmptyModelsState()
        else
          SelectedModelsList(
            modelIds: formState.modelIds,
            defaultModelId: formState.defaultModelId,
            onModelRemoved: (modelId, modelName) {
              final currentModels = List<String>.from(formState.modelIds)
                ..remove(modelId);
              formController.modelIdsChanged(currentModels);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context.messages.aiConfigModelRemovedMessage(modelName),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

// Header widget with title and manage button
class ModelManagementHeader extends StatelessWidget {
  const ModelManagementHeader({
    required this.onManageTap,
    super.key,
  });

  final VoidCallback onManageTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          context.messages.aiConfigModelsTitle,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: context.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        ElevatedButton.icon(
          onPressed: onManageTap,
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: Text(context.messages.aiConfigManageModelsButton),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                context.colorScheme.primaryContainer.withValues(alpha: 0.7),
            foregroundColor: context.colorScheme.primary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

// Empty state widget when no models are selected
class EmptyModelsState extends StatelessWidget {
  const EmptyModelsState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: context.colorScheme.onSurface.withValues(alpha: 0.6),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.messages.aiConfigNoModelsSelected,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// List of selected models
class SelectedModelsList extends ConsumerWidget {
  const SelectedModelsList({
    required this.modelIds,
    required this.defaultModelId,
    required this.onModelRemoved,
    super.key,
  });

  final List<String> modelIds;
  final String defaultModelId;
  final void Function(String modelId, String modelName) onModelRemoved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: modelIds.asMap().entries.map((entry) {
        final index = entry.key;
        final modelId = entry.value;
        final isDefault = modelId == defaultModelId;
        final modelDataAsync = ref.watch(aiConfigByIdProvider(modelId));

        return modelDataAsync.when(
          data: (config) {
            if (config == null || config is! AiConfigModel) {
              // Model doesn't exist or is wrong type
              return ModelErrorState(modelId: modelId);
            }

            final modelName = config.name;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < modelIds.length - 1 ? 12 : 0,
              ),
              child: DismissibleModelCard(
                modelId: modelId,
                modelName: modelName,
                isDefault: isDefault,
                config: config,
                onDismissed: () => onModelRemoved(modelId, modelName),
              ),
            );
          },
          loading: () => const ModelLoadingState(),
          error: (err, stack) => ModelErrorState(modelId: modelId),
        );
      }).toList(),
    );
  }
}

// Dismissible card wrapper for individual models
class DismissibleModelCard extends StatelessWidget {
  const DismissibleModelCard({
    required this.modelId,
    required this.modelName,
    required this.isDefault,
    required this.config,
    required this.onDismissed,
    super.key,
  });

  final String modelId;
  final String modelName;
  final bool isDefault;
  final AiConfigModel config;
  final VoidCallback onDismissed;

  Future<bool> _confirmDismiss(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return ModelDeleteConfirmationDialog(modelName: modelName);
      },
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('selected_model_$modelId'),
      direction: DismissDirection.endToStart,
      background: _buildDismissBackground(context),
      confirmDismiss: (_) => _confirmDismiss(context),
      onDismissed: (_) => onDismissed(),
      child: Stack(
        children: [
          AiConfigCard(
            config: config,
            onTap: () {}, // Models in this context are not editable directly
            showCapabilities: true,
          ),
          if (isDefault)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: context.colorScheme.shadow.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: 12,
                      color: context.colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.messages.promptDefaultModelBadge,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colorScheme.onPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDismissBackground(BuildContext context) {
    return Container(
      color: context.colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.centerRight,
      child: Icon(
        Icons.delete_sweep_outlined,
        color: context.colorScheme.onErrorContainer,
      ),
    );
  }
}

// Loading state for individual models
class ModelLoadingState extends StatelessWidget {
  const ModelLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
    );
  }
}

// Error state for individual models
class ModelErrorState extends StatelessWidget {
  const ModelErrorState({
    required this.modelId,
    super.key,
  });

  final String modelId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: context.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text('${context.messages.promptErrorLoadingModel}: $modelId'),
        ],
      ),
    );
  }
}

// Delete confirmation dialog
class ModelDeleteConfirmationDialog extends StatelessWidget {
  const ModelDeleteConfirmationDialog({
    required this.modelName,
    super.key,
  });

  final String modelName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.messages.aiConfigListDeleteConfirmTitle),
      content: Text(
        context.messages.aiConfigListDeleteConfirmMessage(modelName),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.messages.aiConfigListDeleteConfirmCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(context.messages.aiConfigListDeleteConfirmDelete),
        ),
      ],
    );
  }
}
