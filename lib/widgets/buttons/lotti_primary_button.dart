import 'package:flutter/material.dart';

class LottiPrimaryButton extends StatelessWidget {
  const LottiPrimaryButton({
    required this.onPressed,
    required this.label,
    this.icon,
    this.style,
    this.semanticsLabel,
    this.isDestructive = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final ButtonStyle? style;
  final String? semanticsLabel;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final backgroundColor =
        isDestructive ? colorScheme.error : colorScheme.primary;
    final foregroundColor =
        isDestructive ? colorScheme.onError : colorScheme.onPrimary;

    final defaultStyle = FilledButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      textStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
    );

    final effectiveStyle = defaultStyle.merge(style);

    final labelWidget = Text(
      label,
      semanticsLabel: semanticsLabel,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );

    Widget? iconWidget;
    if (icon != null) {
      iconWidget = Icon(icon, size: 20);
    }

    // FilledButton.icon doesn't support text overflow well, so build custom
    if (iconWidget != null) {
      return FilledButton(
        onPressed: onPressed,
        style: effectiveStyle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(width: 8),
            Flexible(child: labelWidget),
          ],
        ),
      );
    }

    return FilledButton(
      onPressed: onPressed,
      style: effectiveStyle,
      child: labelWidget,
    );
  }
}
