import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/prompt_form_state.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/prompt_form_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

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
    WoltModalSheet.show<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      pageListBuilder: (modalSheetContext) => [
        _buildMainPage(modalSheetContext, selectedType, onSave),
      ],
    );
  }

  /// Builds the main page of the Wolt modal sheet
  static WoltModalSheetPage _buildMainPage(
    BuildContext context,
    AiResponseType? selectedType,
    ValueChanged<AiResponseType> onSave,
  ) {
    return WoltModalSheetPage(
      hasSabGradient: false,
      backgroundColor: context.colorScheme.surfaceContainerHigh,
      topBarTitle: Text(
        context.messages.aiConfigSelectResponseTypeTitle,
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Response type options
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: AiResponseType.values.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final type = AiResponseType.values[index];
                final isSelected = _selectedType == type;

                return _ResponseTypeOption(
                  type: type,
                  isSelected: isSelected,
                  onTap: () => _selectType(type),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Save button
          _SaveButton(
            onPressed: _selectedType != null ? _handleSave : null,
          ),
        ],
      ),
    );
  }
}

/// Individual response type option with radio-style selection
class _ResponseTypeOption extends StatelessWidget {
  const _ResponseTypeOption({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final AiResponseType type;
  final bool isSelected;
  final VoidCallback onTap;

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
          onTap: onTap,
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
                  child: Text(
                    type.localizedName(context),
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? context.colorScheme.primary
                          : context.colorScheme.onSurface,
                      height: 1.3,
                    ),
                  ),
                ),
                
                // Selection indicator - radio button style
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? context.colorScheme.primary
                          : context.colorScheme.outline.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.colorScheme.primary,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
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

/// Save button with disabled state
class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.onPressed,
  });

  final VoidCallback? onPressed;

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
          disabledBackgroundColor: context.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
          disabledForegroundColor: context.colorScheme.onSurface.withValues(alpha: 0.4),
          elevation: onPressed != null ? 3 : 0,
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
