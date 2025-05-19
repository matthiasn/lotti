import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/input_data_type_extensions.dart';
import 'package:lotti/features/ai/state/prompt_form_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';

class PromptInputTypeSelection extends ConsumerStatefulWidget {
  const PromptInputTypeSelection({
    this.configId,
    super.key,
  });

  final String? configId;

  @override
  ConsumerState<PromptInputTypeSelection> createState() =>
      _PromptInputTypeSelection();
}

class _PromptInputTypeSelection
    extends ConsumerState<PromptInputTypeSelection> {
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
    final configId = widget.configId;
    final formState =
        ref.watch(promptFormControllerProvider(configId: configId)).valueOrNull;
    final formController = ref.read(
      promptFormControllerProvider(configId: configId).notifier,
    );

    if (formState == null) {
      return const SizedBox.shrink();
    }

    return InkWell(
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
    );
  }
}
