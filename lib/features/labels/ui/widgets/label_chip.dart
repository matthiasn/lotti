import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';

class LabelChip extends StatelessWidget {
  const LabelChip({
    required this.label,
    super.key,
  });

  final LabelDefinition label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = colorFromCssHex(label.color, substitute: Colors.blue);
    final isDarkTheme = theme.brightness == Brightness.dark;

    // Linear-style: subtle neutral background and border, colored dot only
    final backgroundColor = isDarkTheme
        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
    final borderColor = isDarkTheme
        ? theme.colorScheme.outline.withValues(alpha: 0.25)
        : theme.colorScheme.outline.withValues(alpha: 0.2);
    final textColor = theme.colorScheme.onSurface.withValues(alpha: 0.85);
    final description = label.description?.trim();
    final tooltipMessage = (description != null && description.isNotEmpty)
        ? description
        : label.name;

    return Semantics(
      label: 'Label ${label.name}',
      tooltip: tooltipMessage,
      container: true,
      explicitChildNodes: true,
      child: Tooltip(
        message: tooltipMessage,
        waitDuration: const Duration(milliseconds: 400),
        excludeFromSemantics: true,
        child: Container(
          padding: const EdgeInsets.only(
            left: AppTheme.labelChipPaddingLeft,
            right: AppTheme.labelChipPaddingRight,
            top: AppTheme.labelChipPaddingVertical,
            bottom: AppTheme.labelChipPaddingVertical,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(
              AppTheme.statusIndicatorBorderRadiusSmall,
            ),
            border: Border.all(
              color: borderColor,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Always show the colored dot (Linear style)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label.name,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: AppTheme.statusIndicatorFontSize,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
