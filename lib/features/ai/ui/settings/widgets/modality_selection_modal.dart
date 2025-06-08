import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/modality_extensions.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Modal for selecting input or output modalities with modern styling
///
/// This component provides a clean, accessible interface for users to select
/// which modalities (text, images, audio) a model supports for input or output.
///
/// Features:
/// - Clean modal design with proper header and close button
/// - Checkbox list tiles with visual feedback
/// - Selected state highlighting with primary color
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

  void _toggleModality(Modality modality, bool? selected) {
    setState(() {
      if (selected ?? false) {
        _selectedModalitiesSet.add(modality);
      } else {
        _selectedModalitiesSet.remove(modality);
      }
    });
  }

  void _handleSave() {
    widget.onSave(_selectedModalitiesSet.toList());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Modal header
          _ModalHeader(
            title: widget.title,
            onClose: () => Navigator.of(context).pop(),
          ),

          // Modality options
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              itemCount: Modality.values.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final modality = Modality.values[index];
                final isSelected = _selectedModalitiesSet.contains(modality);

                return _ModalityOption(
                  modality: modality,
                  isSelected: isSelected,
                  onChanged: (selected) => _toggleModality(modality, selected),
                );
              },
            ),
          ),

          // Save button
          _SaveButton(onPressed: _handleSave),
        ],
      ),
    );
  }
}

/// Header section of the modality selection modal
class _ModalHeader extends StatelessWidget {
  const _ModalHeader({
    required this.title,
    required this.onClose,
  });

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              title,
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.colorScheme.onSurface,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(
              Icons.close_rounded,
              color: context.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual modality option with checkbox and description
class _ModalityOption extends StatelessWidget {
  const _ModalityOption({
    required this.modality,
    required this.isSelected,
    required this.onChanged,
  });

  final Modality modality;
  final bool isSelected;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
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
          width: isSelected ? 2 : 1,
        ),
      ),
      child: CheckboxListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 8,
        ),
        title: Text(
          modality.displayName(context),
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
            modality.description(context),
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        value: isSelected,
        onChanged: onChanged,
        controlAffinity: ListTileControlAffinity.trailing,
        activeColor: context.colorScheme.primary,
        checkColor: context.colorScheme.onPrimary,
      ),
    );
  }
}

/// Save button at the bottom of the modal
class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
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
            elevation: 2,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}
