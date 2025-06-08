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
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              decoration: BoxDecoration(
                color: context.colorScheme.surface.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: context.colorScheme.shadow.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Modal header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: context.colorScheme.outline.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.messages.aiConfigInputDataTypesTitle,
                            style: context.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: context.colorScheme.onSurface.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.close_rounded,
                            color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Input data type options
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: InputDataType.values.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final type = InputDataType.values[index];
                        final isSelected = selectedTypesSet.contains(type);
                        
                        return Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? context.colorScheme.primaryContainer.withValues(alpha: 0.3)
                                : context.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? context.colorScheme.primary
                                  : context.colorScheme.outline.withValues(alpha: 0.2),
                              width: 2, // Keep consistent border width to prevent breathing
                            ),
                          ),
                          child: CheckboxListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            title: Text(
                              type.displayName(context),
                              style: context.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? context.colorScheme.primary
                                    : context.colorScheme.onSurface,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                type.description(context),
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: context.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                            value: isSelected,
                            activeColor: context.colorScheme.primary,
                            checkColor: context.colorScheme.onPrimary,
                            controlAffinity: ListTileControlAffinity.trailing,
                            onChanged: (value) {
                              if (value ?? false) {
                                selectedTypesSet.add(type);
                              } else {
                                selectedTypesSet.remove(type);
                              }
                              setState(() {});
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // Save button
                  Container(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          onSave(selectedTypesSet.toList());
                          Navigator.of(modalContext).pop();
                        },
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: Text(
                          context.messages.saveButtonLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.colorScheme.primary,
                          foregroundColor: context.colorScheme.onPrimary,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
