import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/modality_extensions.dart';
import 'package:lotti/widgets/selection/selection.dart';

/// Modal for selecting input or output modalities with modern styling
///
/// This component provides a clean, accessible interface for users to select
/// which modalities (text, images, audio) a model supports for input or output.
///
/// Features:
/// - Wolt Modal Sheet with persistent title section
/// - Check marks for selected modalities (not checkboxes)
/// - Series A quality styling with proper visual feedback
/// - No breathing effect (consistent 2px border widths)
/// - Visual highlighting for current selection
/// - Descriptive text for each modality option
/// - Save button to confirm selection
/// - Proper accessibility support
class ModalitySelectionModal extends StatefulWidget {
  const ModalitySelectionModal({
    required this.title,
    required this.selectedModalities,
    required this.onSave,
    super.key,
  });

  /// Title displayed at the top of the modal
  final String title;

  /// Currently selected modalities
  final List<Modality> selectedModalities;

  /// Callback when user saves their selection
  final ValueChanged<List<Modality>> onSave;

  /// Shows the modality selection modal using Wolt modal sheet
  static void show({
    required BuildContext context,
    required String title,
    required List<Modality> selectedModalities,
    required ValueChanged<List<Modality>> onSave,
  }) {
    SelectionModalBase.show(
      context: context,
      title: title,
      child: ModalitySelectionModal(
        title: title,
        selectedModalities: selectedModalities,
        onSave: onSave,
      ),
    );
  }

  @override
  State<ModalitySelectionModal> createState() => _ModalitySelectionModalState();
}

class _ModalitySelectionModalState extends State<ModalitySelectionModal> {
  late Set<Modality> _selectedModalitiesSet;

  @override
  void initState() {
    super.initState();
    _selectedModalitiesSet = widget.selectedModalities.toSet();
  }

  void _toggleModality(Modality modality) {
    setState(() {
      if (_selectedModalitiesSet.contains(modality)) {
        _selectedModalitiesSet.remove(modality);
      } else {
        _selectedModalitiesSet.add(modality);
      }
    });
  }

  void _handleSave() {
    widget.onSave(_selectedModalitiesSet.toList());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionModalContent(
      children: [
        // Modality options
        SelectionOptionsList(
          itemCount: Modality.values.length,
          itemBuilder: (context, index) {
            final modality = Modality.values[index];
            final isSelected = _selectedModalitiesSet.contains(modality);

            return SelectionOption(
              title: modality.displayName(context),
              description: modality.description(context),
              icon: _getModalityIcon(modality),
              isSelected: isSelected,
              onTap: () => _toggleModality(modality),
            );
          },
        ),

        const SizedBox(height: 24),

        // Save button
        SelectionSaveButton(onPressed: _handleSave),
      ],
    );
  }

  /// Returns appropriate icon for each modality
  IconData _getModalityIcon(Modality modality) {
    switch (modality) {
      case Modality.text:
        return Icons.text_format_rounded;
      case Modality.image:
        return Icons.image_rounded;
      case Modality.audio:
        return Icons.audio_file_rounded;
    }
  }
}
