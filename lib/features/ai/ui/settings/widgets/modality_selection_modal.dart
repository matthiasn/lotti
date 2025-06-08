import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/modality_extensions.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

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
    WoltModalSheet.show<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      pageListBuilder: (modalSheetContext) => [
        _buildMainPage(modalSheetContext, title, selectedModalities, onSave),
      ],
    );
  }

  /// Builds the main page of the Wolt modal sheet
  static WoltModalSheetPage _buildMainPage(
    BuildContext context,
    String title,
    List<Modality> selectedModalities,
    ValueChanged<List<Modality>> onSave,
  ) {
    return WoltModalSheetPage(
      hasSabGradient: false,
      backgroundColor: context.colorScheme.surfaceContainerHigh,
      topBarTitle: Text(
        title,
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Modality options
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
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

          const SizedBox(height: 24),

          // Save button
          _SaveButton(onPressed: _handleSave),
        ],
      ),
    );
  }
}

/// Individual modality option with checkmark and description
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
            ? context.colorScheme.primaryContainer.withValues(alpha: 0.15)
            : context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? context.colorScheme.primary.withValues(alpha: 0.6)
              : context.colorScheme.outline.withValues(alpha: 0.1),
          width: 2, // Keep consistent border width to prevent breathing
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
                // Modality icon
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
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    _getModalityIcon(modality),
                    color: isSelected
                        ? context.colorScheme.primary
                        : context.colorScheme.onSurface.withValues(alpha: 0.8),
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Modality info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        modality.displayName(context),
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
                        modality.description(context),
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

/// Save button at the bottom of the modal
class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
    );
  }
}
