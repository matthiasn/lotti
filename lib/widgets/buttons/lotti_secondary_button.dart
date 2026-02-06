import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// A customizable secondary (outlined) button for consistent app theming.
class LottiSecondaryButton extends StatelessWidget {
  const LottiSecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.enabled = true,
    this.fullWidth = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool enabled;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled && onPressed != null;
    final textColor = isEnabled
        ? context.colorScheme.primary
        : context.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
    final textStyle = TextStyle(
      color: textColor,
      fontWeight: FontWeight.w600,
      fontSize: 16,
    );

    final buttonChild = icon == null
        ? Text(
            label,
            style: textStyle,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: textColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: textStyle,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          );

    final button = OutlinedButton(
      onPressed: isEnabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: context.colorScheme.primary,
        side: BorderSide(
          color: isEnabled
              ? context.colorScheme.primary.withValues(alpha: 0.5)
              : context.colorScheme.primaryContainer.withValues(alpha: 0.2),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      child: buttonChild,
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
