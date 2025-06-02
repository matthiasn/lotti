import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/prompt_form_state.dart';
import 'package:lotti/features/ai/state/prompt_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/preconfigured_prompt_selection_modal.dart';
import 'package:lotti/features/ai/ui/settings/prompt_form_select_model.dart';
import 'package:lotti/features/ai/ui/settings/prompt_input_type_selection.dart';
import 'package:lotti/features/ai/ui/settings/prompt_response_type_selection.dart';
import 'package:lotti/features/ai/ui/widgets/copyable_text_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class PromptForm extends ConsumerStatefulWidget {
  const PromptForm({
    this.configId,
    super.key,
  });

  final String? configId;

  @override
  ConsumerState<PromptForm> createState() => _PromptFormState();
}

class _PromptFormState extends ConsumerState<PromptForm> {
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
      children: <Widget>[
        const SizedBox(height: 5),
        if (configId == null) ...[
          FilledButton.icon(
            onPressed: () async {
              final selectedPrompt =
                  await showPreconfiguredPromptSelectionModal(context);
              if (selectedPrompt != null) {
                formController.populateFromPreconfiguredPrompt(selectedPrompt);
              }
            },
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Use Preconfigured Prompt'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          height: 70,
          child: CopyableTextField(
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
        PromptFormSelectModel(configId: configId),
        const SizedBox(height: 20),
        CopyableTextField(
          onChanged: formController.userMessageChanged,
          controller: formController.userMessageController,
          decoration: InputDecoration(
            labelText: context.messages.aiConfigUserMessageFieldLabel,
            errorText: formState.userMessage.isNotValid &&
                    !formState.userMessage.isPure &&
                    formState.userMessage.error == PromptFormError.empty
                ? context.messages.aiConfigUserMessageEmptyError
                : null,
            alignLabelWithHint: true,
          ),
          maxLines: 6,
        ),
        const SizedBox(height: 20),
        CopyableTextField(
          onChanged: formController.systemMessageChanged,
          controller: formController.systemMessageController,
          decoration: InputDecoration(
            labelText: context.messages.aiConfigSystemMessageFieldLabel,
            alignLabelWithHint: true,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 20),
        PromptInputTypeSelection(configId: configId),
        const SizedBox(height: 20),
        PromptResponseTypeSelection(configId: configId),
        const SizedBox(height: 5),
        SwitchListTile(
          title: Text(context.messages.aiConfigUseReasoningFieldLabel),
          subtitle: Text(context.messages.aiConfigUseReasoningDescription),
          value: formState.useReasoning,
          onChanged: formController.useReasoningChanged,
          contentPadding: const EdgeInsets.symmetric(horizontal: 5),
        ),
        const SizedBox(height: 16),
        CopyableTextField(
          onChanged: formController.descriptionChanged,
          controller: formController.descriptionController,
          decoration: InputDecoration(
            labelText: context.messages.aiConfigDescriptionFieldLabel,
          ),
          maxLines: 2,
        ),
      ],
    );
  }
}
