import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/input_data_type_extensions.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/selection/selection.dart';

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
    SelectionModalBase.show(
      context: context,
      title: context.messages.aiConfigInputDataTypesTitle,
      child: InputDataTypeSelectionModal(
        selectedTypes: selectedTypes,
        onSave: onSave,
      ),
    );
  }

  @override
  State<InputDataTypeSelectionModal> createState() =>
      _InputDataTypeSelectionModalState();
}

class _InputDataTypeSelectionModalState
    extends State<InputDataTypeSelectionModal> {
  late Set<InputDataType> _selectedTypesSet;

  @override
  void initState() {
    super.initState();
    _selectedTypesSet = widget.selectedTypes.toSet();
  }

  void _toggleType(InputDataType type) {
    setState(() {
      if (_selectedTypesSet.contains(type)) {
        _selectedTypesSet.remove(type);
      } else {
        _selectedTypesSet.add(type);
      }
    });
  }

  void _handleSave() {
    widget.onSave(_selectedTypesSet.toList());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionModalContent(
      children: [
        // Input data type options
        SelectionOptionsList(
          itemCount: InputDataType.values.length,
          itemBuilder: (context, index) {
            final type = InputDataType.values[index];
            final isSelected = _selectedTypesSet.contains(type);

            return SelectionOption(
              title: type.displayName(context),
              description: type.description(context),
              icon: _getTypeIcon(type),
              isSelected: isSelected,
              onTap: () => _toggleType(type),
            );
          },
        ),

        const SizedBox(height: 24),

        // Save button
        SelectionSaveButton(onPressed: _handleSave),
      ],
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
