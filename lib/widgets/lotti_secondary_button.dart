import 'package:flutter/material.dart';

class LottiSecondaryButton extends StatelessWidget {
  const LottiSecondaryButton({
    required this.onPressed,
    required this.label,
    this.icon,
    this.style,
    this.semanticsLabel,
    super.key,
  });

  final VoidCallback? onPressed;
  final dynamic label; // String or Widget
  final dynamic icon; // IconData, Widget, or null
  final ButtonStyle? style;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final defaultStyle = OutlinedButton.styleFrom(
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurfaceVariant,
      textStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      side: BorderSide(
        color: colorScheme.outline.withValues(alpha: 0.5),
        width: 1.5,
      ),
    );

    final effectiveStyle = defaultStyle.merge(style);

    final labelWidget = label is Widget
        ? label as Widget
        : Text(
            label.toString(),
            semanticsLabel: semanticsLabel,
          );

    Widget? iconWidget;
    if (icon != null) {
      if (icon is Widget) {
        iconWidget = icon as Widget;
      } else if (icon is IconData) {
        iconWidget = Icon(icon as IconData, size: 20);
      } else {
        throw ArgumentError('Icon must be either Widget or IconData, got ${icon.runtimeType}');
      }
    }

    if (iconWidget != null) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: iconWidget,
        label: labelWidget,
        style: effectiveStyle,
      );
    } else {
      return OutlinedButton(
        onPressed: onPressed,
        style: effectiveStyle,
        child: labelWidget,
      );
    }
  }
} 
