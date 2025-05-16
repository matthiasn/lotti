import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/input_data_type_extensions.dart';
import 'package:lotti/features/ai/model/prompt_form_state.dart';
import 'package:lotti/features/ai/state/prompt_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/prompt_form_select_model.dart';
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
            height: 70,
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
          PromptFormSelectModel(config: widget.config),
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
          InkWell(
            onTap: () => _showInputDataTypeSelectionModal(
              selectedTypes: formState.requiredInputData,
              onSave: formController.requiredInputDataChanged,
            ),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: context.messages.aiConfigRequiredInputDataFieldLabel,
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
          const SizedBox(height: 5),
          SwitchListTile(
            title: Text(context.messages.aiConfigUseReasoningFieldLabel),
            subtitle: Text(context.messages.aiConfigUseReasoningDescription),
            value: formState.useReasoning,
            onChanged: formController.useReasoningChanged,
            contentPadding: const EdgeInsets.symmetric(horizontal: 5),
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
