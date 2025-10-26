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

    final backgroundColor = color.withValues(
      alpha: isDarkTheme ? 0.25 : 0.15,
    );
    final borderColor = color.withValues(alpha: 0.35);
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.statusIndicatorPaddingHorizontal,
            vertical: AppTheme.statusIndicatorPaddingVertical,
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
              _LabelDot(color: color),
              const SizedBox(width: 6),
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

class _LabelDot extends StatelessWidget {
  const _LabelDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
