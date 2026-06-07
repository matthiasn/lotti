import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:lotti/widgets/cards/modern_icon_container.dart';

/// Stateful binary choice prompt card with confirm/dismiss buttons.
class BinaryChoicePromptCard extends StatefulWidget {
  const BinaryChoicePromptCard({
    required this.question,
    required this.detail,
    required this.confirmLabel,
    required this.dismissLabel,
    required this.confirmValue,
    required this.dismissValue,
    required this.onSelect,
    super.key,
  });

  final String question;
  final String detail;
  final String confirmLabel;
  final String dismissLabel;
  final String confirmValue;
  final String dismissValue;
  final ValueChanged<String> onSelect;

  @override
  State<BinaryChoicePromptCard> createState() => _BinaryChoicePromptCardState();
}

class _BinaryChoicePromptCardState extends State<BinaryChoicePromptCard> {
  bool _submitted = false;

  @override
  void didUpdateWidget(covariant BinaryChoicePromptCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final promptChanged =
        oldWidget.question != widget.question ||
        oldWidget.confirmValue != widget.confirmValue ||
        oldWidget.dismissValue != widget.dismissValue;
    if (promptChanged) {
      _submitted = false;
    }
  }

  void _handleSelect(String value) {
    if (_submitted) return;
    setState(() => _submitted = true);
    widget.onSelect(value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ModernBaseCard(
        backgroundColor: colorScheme.surfaceContainerLow,
        borderColor: colorScheme.outlineVariant.withValues(alpha: 0.45),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ModernIconContainer(
                  icon: Icons.help_outline_rounded,
                  isCompact: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.question,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.detail.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                widget.detail,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.end,
              children: [
                DesignSystemButton(
                  onPressed: _submitted
                      ? null
                      : () => _handleSelect(widget.dismissValue),
                  label: widget.dismissLabel,
                  variant: DesignSystemButtonVariant.secondary,
                  size: DesignSystemButtonSize.medium,
                ),
                DesignSystemButton(
                  onPressed: _submitted
                      ? null
                      : () => _handleSelect(widget.confirmValue),
                  label: widget.confirmLabel,
                  size: DesignSystemButtonSize.medium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
