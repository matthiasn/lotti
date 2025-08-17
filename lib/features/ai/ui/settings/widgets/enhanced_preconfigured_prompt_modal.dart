import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/input_data_type_extensions.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/selection/selection.dart';
import 'package:lotti/widgets/selection/selection_modal_base.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

/// Enhanced preconfigured prompt selection modal with Series A quality design
///
/// Features:
/// - Beautiful card-based layout with rich information
/// - Smooth animations and micro-interactions
/// - Clear visual hierarchy with icons and descriptions
/// - Tag chips showing input/output types
/// - Professional hover and selection states
/// - Uses Wolt Modal Sheet infrastructure
class EnhancedPreconfiguredPromptModal extends StatefulWidget {
  const EnhancedPreconfiguredPromptModal({
    required this.onPromptSelected,
    super.key,
  });

  final ValueChanged<PreconfiguredPrompt> onPromptSelected;

  /// Shows the enhanced preconfigured prompt selection modal
  static void show({
    required BuildContext context,
    required ValueChanged<PreconfiguredPrompt> onPromptSelected,
  }) {
    SelectionModalBase.show(
      context: context,
      title: context.messages.promptSelectionModalTitle,
      child: EnhancedPreconfiguredPromptModal(
        onPromptSelected: onPromptSelected,
      ),
    );
  }

  @override
  State<EnhancedPreconfiguredPromptModal> createState() =>
      _EnhancedPreconfiguredPromptModalState();
}

class _EnhancedPreconfiguredPromptModalState
    extends State<EnhancedPreconfiguredPromptModal> {
  void _selectPrompt(PreconfiguredPrompt prompt) {
    widget.onPromptSelected(prompt);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SelectionModalContent(
      children: [
        // Description text
        Text(
          context.messages.enhancedPromptFormPreconfiguredPromptDescription,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurface.withValues(alpha: 0.7),
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Prompt template cards
        ...preconfiguredPrompts.values.map((prompt) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PromptTemplateCard(
                prompt: prompt,
                onTap: () => _selectPrompt(prompt),
              ),
            )),
      ],
    );
  }
}

/// Individual prompt template card with premium styling
class _PromptTemplateCard extends StatefulWidget {
  const _PromptTemplateCard({
    required this.prompt,
    required this.onTap,
  });

  final PreconfiguredPrompt prompt;
  final VoidCallback onTap;

  @override
  State<_PromptTemplateCard> createState() => _PromptTemplateCardState();
}

class _PromptTemplateCardState extends State<_PromptTemplateCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..translateByVector3(Vector3(0, _isHovered ? -2 : 0, 0)),
        decoration: BoxDecoration(
          color: _isHovered
              ? context.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.8)
              : context.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered
                ? context.colorScheme.primary.withValues(alpha: 0.3)
                : context.colorScheme.outline.withValues(alpha: 0.1),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? context.colorScheme.primary.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: _isHovered ? 20 : 8,
              offset: Offset(0, _isHovered ? 8 : 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with icon and title
                  Row(
                    children: [
                      // Icon container
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              context.colorScheme.primary
                                  .withValues(alpha: 0.15),
                              context.colorScheme.primary
                                  .withValues(alpha: 0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: context.colorScheme.primary
                                .withValues(alpha: 0.2),
                          ),
                        ),
                        child: Icon(
                          widget.prompt.aiResponseType.icon,
                          color: context.colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Title
                      Expanded(
                        child: Text(
                          widget.prompt.name,
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: context.colorScheme.onSurface,
                            height: 1.3,
                          ),
                        ),
                      ),

                      // Arrow icon
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        transform: Matrix4.identity()
                          ..translateByVector3(Vector3(_isHovered ? 4 : 0, 0, 0)),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: context.colorScheme.onSurface.withValues(
                            alpha: _isHovered ? 0.7 : 0.4,
                          ),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    widget.prompt.description,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color:
                          context.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Input/Output tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Input data type chips
                      ...widget.prompt.requiredInputData.map(
                        (inputType) => _TagChip(
                          label: inputType.displayName(context),
                          icon: Icons.input_rounded,
                          backgroundColor: context.colorScheme.primaryContainer
                              .withValues(alpha: 0.3),
                          foregroundColor: context.colorScheme.primary,
                        ),
                      ),

                      // Output type chip
                      _TagChip(
                        label:
                            widget.prompt.aiResponseType.localizedName(context),
                        icon: Icons.output_rounded,
                        backgroundColor: context.colorScheme.secondaryContainer
                            .withValues(alpha: 0.3),
                        foregroundColor: context.colorScheme.secondary,
                      ),

                      // Reasoning chip if applicable
                      if (widget.prompt.useReasoning)
                        _TagChip(
                          label:
                              context.messages.aiConfigUseReasoningFieldLabel,
                          icon: Icons.psychology_rounded,
                          backgroundColor: context.colorScheme.tertiaryContainer
                              .withValues(alpha: 0.3),
                          foregroundColor: context.colorScheme.tertiary,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Styled tag chip for displaying metadata
class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: foregroundColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: foregroundColor,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the enhanced preconfigured prompt selection modal
void showEnhancedPreconfiguredPromptModal(
  BuildContext context,
  ValueChanged<PreconfiguredPrompt> onPromptSelected,
) {
  EnhancedPreconfiguredPromptModal.show(
    context: context,
    onPromptSelected: onPromptSelected,
  );
}
