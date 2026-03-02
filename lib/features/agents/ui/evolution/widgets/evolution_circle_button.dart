import 'package:flutter/material.dart';
import 'package:lotti/themes/gamey/colors.dart';
import 'package:lotti/themes/gamey/gradients.dart';

/// Circular icon button styled with the evolution dark/cyan theme.
///
/// Shows the AI gradient when [onPressed] is non-null, or when [forceActive]
/// is true (e.g. during the waiting/pulsing state).
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

  static const _disabledColor = Color.fromRGBO(255, 255, 255, 0.3);

  @override
  Widget build(BuildContext context) {
    final showActive = onPressed != null || forceActive;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: showActive ? GameyGradients.ai : null,
        color: showActive ? null : GameyColors.surfaceDark,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: iconSize,
          color: showActive ? Colors.white : _disabledColor,
        ),
        padding: EdgeInsets.zero,
        tooltip: tooltip,
      ),
    );
  }
}
