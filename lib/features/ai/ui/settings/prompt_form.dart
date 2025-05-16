import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/input_data_type_extensions.dart';
import 'package:lotti/features/ai/model/prompt_form_state.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/prompt_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/model_management_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';

class PromptForm extends ConsumerStatefulWidget {
  const PromptForm({
    required this.onSave,
    this.config,
    super.key,
  });

  final AiConfig? config;
  final void Function(AiConfig) onSave;

  @override
  ConsumerState<PromptForm> createState() => _PromptFormState();
}

class _PromptFormState extends ConsumerState<PromptForm> {
  void _showModelManagementModal({
    required List<String> currentSelectedIds,
    required String currentDefaultId,
    required PromptFormController formController,
  }) {
    ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.aiConfigManageModelsButton,
      builder: (modalContext) => ModelManagementModal(
        currentSelectedIds: currentSelectedIds,
        currentDefaultId: currentDefaultId,
        onSave: (List<String> newSelectedIds, String newDefaultIdFromModal) {
          formController.modelIdsChanged(newSelectedIds);

          // After modelIdsChanged, the controller might have already updated defaultModelId in its state.
          // We set the defaultModelId to what the user explicitly chose in the modal,
          // but only if it's part of the newSelectedIds (which should be guaranteed by modal logic).
          // We also check if it actually needs changing.
          final controllerProvider =
              promptFormControllerProvider(configId: widget.config?.id);
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
      ),
    );
  }

  void _showInputDataTypeSelectionModal({
    required List<InputDataType> selectedTypes,
    required void Function(List<InputDataType>) onSave,
  }) {
    final selectedTypesSet = selectedTypes.toSet();

    ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.aiConfigInputDataTypesTitle,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return ListView(
              shrinkWrap: true,
              children: [
                ...InputDataType.values.map((type) {
                  final isSelected = selectedTypesSet.contains(type);
                  return CheckboxListTile(
                    title: Text(type.displayName(context)),
                    subtitle: Text(type.description(context)),
                    value: isSelected,
                    onChanged: (value) {
                      if (value ?? false) {
                        selectedTypesSet.add(type);
                      } else {
                        selectedTypesSet.remove(type);
                      }
                      setState(() {});
                    },
                  );
                }),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FilledButton(
                    onPressed: () {
                      onSave(selectedTypesSet.toList());
                      Navigator.of(modalContext).pop();
                    },
                    child: Text(context.messages.saveButtonLabel),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final configId = widget.config?.id;
    final formState =
        ref.watch(promptFormControllerProvider(configId: configId)).valueOrNull;
    final formController = ref.read(
      promptFormControllerProvider(configId: configId).notifier,
    );

    if (formState == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 90,
            child: TextField(
              onChanged: formController.nameChanged,
              controller: formController.nameController,
              decoration: InputDecoration(
                labelText: context.messages.aiConfigNameFieldLabel,
                errorText: formState.name.isNotValid &&
                        !formState.name.isPure &&
                        formState.name.error == PromptFormError.tooShort
                    ? context.messages.aiConfigNameTooShortError
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.messages.aiConfigModelsTitle,
                  style: context.textTheme.titleMedium,
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
                      final modelDataAsync =
                          ref.watch(aiConfigByIdProvider(modelId));

                      return modelDataAsync.when(
                        data: (config) {
                          final modelName =
                              (config as AiConfigModel?)?.name ?? modelId;
                          return Dismissible(
                            key: ValueKey('selected_model_$modelId'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: context.colorScheme.errorContainer,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
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
                                      context.messages
                                          .aiConfigListDeleteConfirmTitle,
                                    ),
                                    content: Text(
                                      context.messages
                                          .aiConfigListDeleteConfirmMessage(
                                        modelName,
                                      ),
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                        child: Text(
                                          context.messages
                                              .aiConfigListDeleteConfirmCancel,
                                        ),
                                        onPressed: () {
                                          Navigator.of(dialogContext)
                                              .pop(false);
                                        },
                                      ),
                                      TextButton(
                                        child: Text(
                                          context.messages
                                              .aiConfigListDeleteConfirmDelete,
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
                                    context.messages
                                        .aiConfigModelRemovedMessage(
                                      modelName,
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withAlpha(128),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        modelName,
                                        style: context.textTheme.bodyLarge,
                                      ),
                                    ),
                                    if (isDefault) const SizedBox(width: 10),
                                    if (isDefault)
                                      Icon(
                                        Icons.star,
                                        color: context.colorScheme.primary,
                                        size: 20,
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
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    _showModelManagementModal(
                      currentSelectedIds: formState.modelIds,
                      currentDefaultId: formState.defaultModelId,
                      formController: formController,
                    );
                  },
                  child: Text(context.messages.aiConfigManageModelsButton),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: TextField(
              onChanged: formController.templateChanged,
              controller: formController.templateController,
              decoration: InputDecoration(
                labelText: context.messages.aiConfigTemplateFieldLabel,
                errorText: formState.template.isNotValid &&
                        !formState.template.isPure &&
                        formState.template.error == PromptFormError.empty
                    ? context.messages.aiConfigTemplateEmptyError
                    : null,
                alignLabelWithHint: true,
              ),
              maxLines: 8,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 90,
            child: InkWell(
              onTap: () => _showInputDataTypeSelectionModal(
                selectedTypes: formState.requiredInputData,
                onSave: formController.requiredInputDataChanged,
              ),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText:
                      context.messages.aiConfigRequiredInputDataFieldLabel,
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                ),
                child: Text(
                  formState.requiredInputData.isEmpty
                      ? context.messages.aiConfigSelectInputDataTypesPrompt
                      : formState.requiredInputData
                          .map((type) => type.displayName(context))
                          .join(', '),
                  style: context.textTheme.bodyLarge,
                ),
              ),
            ),
          ),
          SwitchListTile(
            title: Text(context.messages.aiConfigUseReasoningFieldLabel),
            subtitle: Text(context.messages.aiConfigUseReasoningDescription),
            value: formState.useReasoning,
            onChanged: formController.useReasoningChanged,
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: formController.descriptionChanged,
            controller: formController.descriptionController,
            decoration: InputDecoration(
              labelText: context.messages.aiConfigDescriptionFieldLabel,
            ),
            maxLines: 3,
          ),
          SizedBox(
            height: 50,
            child: formState.submitFailed
                ? Text(
                    context.messages.aiConfigFailedToSaveMessage,
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: context.colorScheme.error,
                    ),
                  )
                : null,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton(
                onPressed: formState.isValid &&
                        formState.modelIds.isNotEmpty &&
                        formState.defaultModelId.isNotEmpty &&
                        formState.modelIds.contains(formState.defaultModelId) &&
                        (widget.config == null || formState.isDirty)
                    ? () {
                        final config = formState.toAiConfig();
                        widget.onSave(config);
                      }
                    : null,
                child: Text(
                  widget.config == null
                      ? context.messages.aiConfigCreateButtonLabel
                      : context.messages.aiConfigUpdateButtonLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
