import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_model_form_state.dart';
import 'package:lotti/features/ai/model/modality_extensions.dart';
import 'package:lotti/features/ai/state/inference_model_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_name_widget.dart';
import 'package:lotti/features/ai/ui/settings/provider_selection_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';

class InferenceModelForm extends ConsumerStatefulWidget {
  const InferenceModelForm({
    required this.onSave,
    this.config,
    super.key,
  });

  final AiConfig? config;
  final void Function(AiConfig) onSave;

  @override
  ConsumerState<InferenceModelForm> createState() => _InferenceModelFormState();
}

class _InferenceModelFormState extends ConsumerState<InferenceModelForm> {
  void _showInferenceProviderModal() {
    ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.aiConfigSelectProviderModalTitle,
      builder: (modalContext) =>
          ProviderSelectionModal(configId: widget.config?.id),
    );
  }

  void _showModalitySelectionModal({
    required String title,
    required List<Modality> selectedModalities,
    required void Function(List<Modality>) onSave,
  }) {
    final selectedModalitiesSet = selectedModalities.toSet();

    ModalUtils.showSinglePageModal<void>(
      context: context,
      title: title,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return ListView(
              shrinkWrap: true,
              children: [
                ...Modality.values.map((modality) {
                  final isSelected = selectedModalitiesSet.contains(modality);
                  return CheckboxListTile(
                    title: Text(modality.displayName(context)),
                    subtitle: Text(modality.description(context)),
                    value: isSelected,
                    onChanged: (value) {
                      if (value ?? false) {
                        selectedModalitiesSet.add(modality);
                      } else {
                        selectedModalitiesSet.remove(modality);
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
                      onSave(selectedModalitiesSet.toList());
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
    final formState = ref
        .watch(inferenceModelFormControllerProvider(configId: configId))
        .valueOrNull;
    final formController = ref.read(
      inferenceModelFormControllerProvider(configId: configId).notifier,
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
                        formState.name.error == ModelFormError.tooShort
                    ? context.messages.aiConfigNameTooShortError
                    : null,
              ),
            ),
          ),
          SizedBox(
            height: 90,
            child: TextField(
              onChanged: formController.providerModelIdChanged,
              controller: formController.providerModelIdController,
              decoration: InputDecoration(
                labelText: context.messages.aiConfigProviderModelIdFieldLabel,
                errorText: formState.providerModelId.isNotValid &&
                        !formState.providerModelId.isPure &&
                        formState.providerModelId.error ==
                            ModelFormError.tooShort
                    ? context.messages.aiConfigProviderModelIdTooShortError
                    : null,
              ),
            ),
          ),
          SizedBox(
            height: 90,
            child: InkWell(
              onTap: _showInferenceProviderModal,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: context.messages.aiConfigProviderFieldLabel,
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                ),
                child: formState.inferenceProviderId.isEmpty
                    ? Text(context.messages.aiConfigSelectProviderModalTitle)
                    : InferenceProviderNameWidget(
                        providerId: formState.inferenceProviderId,
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 90,
            child: InkWell(
              onTap: () => _showModalitySelectionModal(
                title: context.messages.aiConfigInputModalitiesTitle,
                selectedModalities: formState.inputModalities,
                onSave: formController.inputModalitiesChanged,
              ),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: context.messages.aiConfigInputModalitiesFieldLabel,
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                ),
                child: Text(
                  formState.inputModalities.isEmpty
                      ? context.messages.aiConfigSelectModalitiesPrompt
                      : formState.inputModalities
                          .map((m) => m.displayName(context))
                          .join(', '),
                  style: context.textTheme.bodyLarge,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 90,
            child: InkWell(
              onTap: () => _showModalitySelectionModal(
                title: context.messages.aiConfigOutputModalitiesTitle,
                selectedModalities: formState.outputModalities,
                onSave: formController.outputModalitiesChanged,
              ),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText:
                      context.messages.aiConfigOutputModalitiesFieldLabel,
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                ),
                child: Text(
                  formState.outputModalities.isEmpty
                      ? context.messages.aiConfigSelectModalitiesPrompt
                      : formState.outputModalities
                          .map((m) => m.displayName(context))
                          .join(', '),
                  style: context.textTheme.bodyLarge,
                ),
              ),
            ),
          ),
          SwitchListTile(
            title: Text(context.messages.aiConfigReasoningCapabilityFieldLabel),
            subtitle:
                Text(context.messages.aiConfigReasoningCapabilityDescription),
            value: formState.isReasoningModel,
            onChanged: formController.isReasoningModelChanged,
          ),
          const SizedBox(height: 30),
          TextField(
            onChanged: formController.descriptionChanged,
            controller: formController.descriptionController,
            decoration: InputDecoration(
              labelText: context.messages.aiConfigCommentFieldLabel,
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
                        formState.inferenceProviderId.isNotEmpty &&
                        formState.inputModalities.isNotEmpty &&
                        formState.outputModalities.isNotEmpty &&
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
