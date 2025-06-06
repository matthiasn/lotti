import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/prompt_form_state.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/prompt_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/model_management_modal.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_name_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';

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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.messages.aiConfigModelsTitle,
              style: context.textTheme.titleMedium,
            ),
            ElevatedButton(
              onPressed: () {
                _showModelManagementModal(
                  currentSelectedIds: formState.modelIds,
                  currentDefaultId: formState.defaultModelId,
                  formController: formController,
                  formState: formState,
                );
              },
              child: Text(context.messages.aiConfigManageModelsButton),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (formState.modelIds.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              context.messages.aiConfigNoModelsSelected,
              style: context.textTheme.bodyMedium,
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: formState.modelIds.map((modelId) {
              final isDefault = modelId == formState.defaultModelId;
              final modelDataAsync = ref.watch(aiConfigByIdProvider(modelId));

              return modelDataAsync.when(
                data: (config) {
                  final modelName = (config as AiConfigModel?)?.name ?? modelId;
                  return Dismissible(
                    key: ValueKey('selected_model_$modelId'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: context.colorScheme.errorContainer,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.centerRight,
                      child: Icon(
                        Icons.delete_sweep_outlined,
                        color: context.colorScheme.onErrorContainer,
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return AlertDialog(
                            title: Text(
                              context.messages.aiConfigListDeleteConfirmTitle,
                            ),
                            content: Text(
                              context.messages.aiConfigListDeleteConfirmMessage(
                                modelName,
                              ),
                            ),
                            actions: <Widget>[
                              TextButton(
                                child: Text(
                                  context
                                      .messages.aiConfigListDeleteConfirmCancel,
                                ),
                                onPressed: () {
                                  Navigator.of(dialogContext).pop(false);
                                },
                              ),
                              TextButton(
                                child: Text(
                                  context
                                      .messages.aiConfigListDeleteConfirmDelete,
                                ),
                                onPressed: () {
                                  Navigator.of(dialogContext).pop(true);
                                },
                              ),
                            ],
                          );
                        },
                      );
                      return confirmed ?? false;
                    },
                    onDismissed: (direction) {
                      final currentModels =
                          List<String>.from(formState.modelIds)
                            ..remove(modelId);
                      formController.modelIdsChanged(currentModels);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.messages.aiConfigModelRemovedMessage(
                              modelName,
                            ),
                          ),
                        ),
                      );
                    },
                    child: Card(
                      elevation: isDefault ? 4 : 1,
                      shadowColor: isDefault
                          ? context.colorScheme.primary.withOpacity(0.3)
                          : context.colorScheme.shadow.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: isDefault
                              ? context.colorScheme.primary
                              : context.colorScheme.outline.withAlpha(64),
                          width: isDefault ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: isDefault
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    context.colorScheme.primaryContainer
                                        .withOpacity(0.1),
                                    context.colorScheme.primaryContainer
                                        .withOpacity(0.05),
                                  ],
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          modelName,
                                          style: context.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color:
                                                context.colorScheme.onSurface,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isDefault) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: context.colorScheme.primary,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.star,
                                                size: 12,
                                                color: context
                                                    .colorScheme.onPrimary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Default',
                                                style: context
                                                    .textTheme.labelSmall
                                                    ?.copyWith(
                                                  color: context
                                                      .colorScheme.onPrimary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (config != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: context
                                            .colorScheme.surfaceVariant
                                            .withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: InferenceProviderNameWidget(
                                        providerId: (config as AiConfigModel)
                                            .inferenceProviderId,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text('Loading model...'),
                    ],
                  ),
                ),
                error: (err, stack) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: context.colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text('Error: $modelId'),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
