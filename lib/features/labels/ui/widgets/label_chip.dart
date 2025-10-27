import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';

class LabelChip extends StatelessWidget {
  const LabelChip({
    required this.label,
    this.showDot = true,
    super.key,
  });

  final LabelDefinition label;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = colorFromCssHex(label.color, substitute: Colors.blue);
    final isDarkTheme = theme.brightness == Brightness.dark;

    // Make the frame more prominent when we don't show the dot.
    final backgroundColor = showDot
        ? color.withValues(alpha: isDarkTheme ? 0.25 : 0.15)
        : color.withValues(alpha: isDarkTheme ? 0.35 : 0.22);
    final borderColor =
        showDot ? color.withValues(alpha: 0.35) : color.withValues(alpha: 0.55);
    final textColor = isDarkTheme ? Colors.white : Colors.black;
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
          padding: EdgeInsets.only(
            left: AppTheme.statusIndicatorPaddingHorizontal + (showDot ? 0 : 6),
            right: AppTheme.statusIndicatorPaddingHorizontal,
            top: AppTheme.statusIndicatorPaddingVertical,
            bottom: AppTheme.statusIndicatorPaddingVertical,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(
              AppTheme.statusIndicatorBorderRadiusSmall,
            ),
            border: Border.all(
              color: borderColor,
              width: AppTheme.statusIndicatorBorderWidth,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDot) ...[
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        color,
                        color.withValues(alpha: 0.75),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label.name,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: AppTheme.statusIndicatorFontSize,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
