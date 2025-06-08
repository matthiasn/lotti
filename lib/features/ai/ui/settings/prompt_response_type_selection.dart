import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/prompt_form_state.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/prompt_form_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/selection/selection.dart';

class PromptResponseTypeSelection extends ConsumerWidget {
  const PromptResponseTypeSelection({super.key, this.configId});

  final String? configId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState =
        ref.watch(promptFormControllerProvider(configId: configId)).valueOrNull;
    final formController =
        ref.read(promptFormControllerProvider(configId: configId).notifier);

    if (formState == null) {
      return const SizedBox.shrink();
    }

    final selectedType = formState.aiResponseType.value;

    return InkWell(
      onTap: () {
        ResponseTypeSelectionModal.show(
          context: context,
          selectedType: selectedType,
          onSave: formController.aiResponseTypeChanged,
        );
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: context.messages.aiConfigResponseTypeFieldLabel,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          errorText: formState.aiResponseType.isNotValid &&
                  // !formState.aiResponseType.isPure &&
                  formState.aiResponseType.error == PromptFormError.notSelected
              ? context.messages.aiConfigResponseTypeNotSelectedError
              : null,
        ),
        child: Text(
          selectedType?.localizedName(context) ??
              context.messages.aiConfigResponseTypeSelectHint,
          style: selectedType == null
              ? context.textTheme.bodyLarge?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                )
              : context.textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Modal for selecting AI response type with modern styling
///
/// This component provides a clean, accessible interface for users to select
/// the type of response they expect from the AI.
///
/// Features:
/// - Wolt Modal Sheet with persistent title section
/// - Radio button style with check marks
/// - Series A quality styling with proper visual feedback
/// - Visual highlighting for current selection
/// - Save button in the content area
/// - Proper accessibility support
class ResponseTypeSelectionModal extends StatefulWidget {
  const ResponseTypeSelectionModal({
    required this.selectedType,
    required this.onSave,
    super.key,
  });

  /// Currently selected response type
  final AiResponseType? selectedType;

  /// Callback when user saves their selection
  final ValueChanged<AiResponseType> onSave;

  /// Shows the response type selection modal using Wolt modal sheet
  static void show({
    required BuildContext context,
    required AiResponseType? selectedType,
    required ValueChanged<AiResponseType> onSave,
  }) {
    SelectionModalBase.show(
      context: context,
      title: context.messages.aiConfigSelectResponseTypeTitle,
      child: ResponseTypeSelectionModal(
        selectedType: selectedType,
        onSave: onSave,
      ),
    );
  }

  @override
  State<ResponseTypeSelectionModal> createState() => _ResponseTypeSelectionModalState();
}

class _ResponseTypeSelectionModalState extends State<ResponseTypeSelectionModal> {
  AiResponseType? _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.selectedType;
  }

  void _selectType(AiResponseType type) {
    setState(() {
      _selectedType = type;
    });
  }

  void _handleSave() {
    if (_selectedType != null) {
      widget.onSave(_selectedType!);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SelectionModalContent(
      children: [
        // Response type options
        SelectionOptionsList(
          itemCount: AiResponseType.values.length,
          itemBuilder: (context, index) {
            final type = AiResponseType.values[index];
            final isSelected = _selectedType == type;

            return SelectionOption(
              title: type.localizedName(context),
              icon: _getTypeIcon(type),
              isSelected: isSelected,
              onTap: () => _selectType(type),
              selectionIndicator: RadioSelectionIndicator(isSelected: isSelected),
            );
          },
        ),

        const SizedBox(height: 24),

        // Save button
        SelectionSaveButton(
          onPressed: _selectedType != null ? _handleSave : null,
        ),
      ],
    );
  }

  /// Returns appropriate icon for each response type
  IconData _getTypeIcon(AiResponseType type) {
    switch (type) {
      case AiResponseType.actionItemSuggestions:
        return Icons.lightbulb_outline_rounded;
      case AiResponseType.taskSummary:
        return Icons.summarize_rounded;
      case AiResponseType.imageAnalysis:
        return Icons.image_search_rounded;
      case AiResponseType.audioTranscription:
        return Icons.transcribe_rounded;
    }
  }
}
