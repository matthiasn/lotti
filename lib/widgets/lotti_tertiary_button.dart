import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// A customizable tertiary (text) button for consistent app theming.
/// Used for text-only buttons with minimal styling, typically for secondary actions.
class LottiTertiaryButton extends StatelessWidget {
  const LottiTertiaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.enabled = true,
    this.fullWidth = false,
    this.isDestructive = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool enabled;
  final bool fullWidth;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled && onPressed != null;

    // Determine text color based on state and destructive flag
    final textColor =
        isDestructive ? context.colorScheme.error : context.colorScheme.primary;

    final disabledColor =
        context.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);
    final effectiveColor = isEnabled ? textColor : disabledColor;

    final buttonChild = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(label),
            ],
          );

    final button = TextButton(
      onPressed: isEnabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: effectiveColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
      child: buttonChild,
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
