import 'package:flutter/material.dart';

/// Circular icon button used by the evolution composer controls.
///
/// Shows a prominent filled state when [onPressed] is non-null, or when
/// [forceActive] is true (for waiting/recording states).
class EvolutionCircleButton extends StatelessWidget {
  const EvolutionCircleButton({
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 40,
    this.iconSize = 20,
    this.forceActive = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;

  /// When true, shows the active gradient even if [onPressed] is null.
  /// Useful for pulsing/waiting states where the button should look active
  /// but not be tappable.
  final bool forceActive;

  @override
  Widget build(BuildContext context) {
    final showActive = onPressed != null || forceActive;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: showActive
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
        border: Border.all(
          color: showActive
              ? colorScheme.primary.withValues(alpha: 0.2)
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(
              alpha: showActive ? 0.22 : 0.1,
            ),
            blurRadius: showActive ? 14 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: iconSize,
          color: showActive
              ? colorScheme.onPrimary
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
        ),
        padding: EdgeInsets.zero,
        tooltip: tooltip,
      ),
    );
  }
}
