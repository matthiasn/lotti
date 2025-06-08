import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/input_data_type_extensions.dart';
import 'package:lotti/features/ai/state/prompt_form_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

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
    InputDataTypeSelectionModal.show(
      context: context,
      selectedTypes: selectedTypes,
      onSave: onSave,
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

/// Modal for selecting input data types with modern styling
///
/// This component provides a clean, accessible interface for users to select
/// which input data types a prompt expects.
///
/// Features:
/// - Wolt Modal Sheet with persistent title section
/// - Check marks for selected types (not checkboxes)
/// - Series A quality styling with proper visual feedback
/// - Visual highlighting for current selection
/// - Descriptive text for each type option
/// - Save button with sticky actions
/// - Proper accessibility support
class InputDataTypeSelectionModal extends StatefulWidget {
  const InputDataTypeSelectionModal({
    required this.selectedTypes,
    required this.onSave,
    super.key,
  });

  /// Currently selected input data types
  final List<InputDataType> selectedTypes;

  /// Callback when user saves their selection
  final ValueChanged<List<InputDataType>> onSave;

  /// Shows the input data type selection modal using Wolt modal sheet
  static void show({
    required BuildContext context,
    required List<InputDataType> selectedTypes,
    required ValueChanged<List<InputDataType>> onSave,
  }) {
    WoltModalSheet.show<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      pageListBuilder: (modalSheetContext) => [
        _buildMainPage(modalSheetContext, selectedTypes, onSave),
      ],
    );
  }

  /// Builds the main page of the Wolt modal sheet
  static WoltModalSheetPage _buildMainPage(
    BuildContext context,
    List<InputDataType> selectedTypes,
    ValueChanged<List<InputDataType>> onSave,
  ) {
    return WoltModalSheetPage(
      hasSabGradient: false,
      backgroundColor: context.colorScheme.surfaceContainerHigh,
      topBarTitle: Text(
        context.messages.aiConfigInputDataTypesTitle,
        style: context.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: context.colorScheme.onSurface,
        ),
      ),
      trailingNavBarWidget: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: Icon(
          Icons.close,
          color: context.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        tooltip: 'Close',
      ),
      isTopBarLayerAlwaysVisible: true,
      child: InputDataTypeSelectionModal(
        selectedTypes: selectedTypes,
        onSave: onSave,
      ),
    );
  }

  @override
  State<InputDataTypeSelectionModal> createState() => _InputDataTypeSelectionModalState();
}

class _InputDataTypeSelectionModalState extends State<InputDataTypeSelectionModal> {
  late Set<InputDataType> _selectedTypesSet;

  @override
  void initState() {
    super.initState();
    _selectedTypesSet = widget.selectedTypes.toSet();
  }

  void _toggleType(InputDataType type, bool? selected) {
    setState(() {
      if (selected ?? false) {
        _selectedTypesSet.add(type);
      } else {
        _selectedTypesSet.remove(type);
      }
    });
  }

  void _handleSave() {
    widget.onSave(_selectedTypesSet.toList());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Input data type options
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: InputDataType.values.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final type = InputDataType.values[index];
                final isSelected = _selectedTypesSet.contains(type);

                return _InputDataTypeOption(
                  type: type,
                  isSelected: isSelected,
                  onChanged: (selected) => _toggleType(type, selected),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Save button
          _SaveButton(onPressed: _handleSave),
        ],
      ),
    );
  }
}

/// Individual input data type option with checkmark and description
class _InputDataTypeOption extends StatelessWidget {
  const _InputDataTypeOption({
    required this.type,
    required this.isSelected,
    required this.onChanged,
  });

  final InputDataType type;
  final bool isSelected;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? context.colorScheme.primaryContainer.withValues(alpha: 0.15)
            : context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? context.colorScheme.primary.withValues(alpha: 0.6)
              : context.colorScheme.outline.withValues(alpha: 0.1),
          width: 2,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: context.colorScheme.primary.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged(!isSelected),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Type icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.colorScheme.primary.withValues(alpha: 0.15)
                        : context.colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? context.colorScheme.primary.withValues(alpha: 0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: Icon(
                    _getTypeIcon(type),
                    color: isSelected
                        ? context.colorScheme.primary
                        : context.colorScheme.onSurface.withValues(alpha: 0.8),
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Type info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.displayName(context),
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? context.colorScheme.primary
                              : context.colorScheme.onSurface,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        type.description(context),
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Selection indicator - checkmark when selected, empty circle when not
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: context.colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: context.colorScheme.primary
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: context.colorScheme.onPrimary,
                      size: 16,
                    ),
                  )
                else
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: context.colorScheme.outline
                            .withValues(alpha: 0.3),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Returns appropriate icon for each input data type
  IconData _getTypeIcon(InputDataType type) {
    switch (type) {
      case InputDataType.task:
        return Icons.task_alt_rounded;
      case InputDataType.tasksList:
        return Icons.list_alt_rounded;
      case InputDataType.audioFiles:
        return Icons.audio_file_rounded;
      case InputDataType.images:
        return Icons.image_rounded;
    }
  }
}

/// Save button for sticky action bar
class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPressed,
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
            elevation: 3,
            shadowColor: context.colorScheme.primary.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
