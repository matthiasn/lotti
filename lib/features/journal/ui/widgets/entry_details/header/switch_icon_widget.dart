import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

class SwitchIconWidget extends StatelessWidget {
  const SwitchIconWidget({
    required this.tooltip,
    required this.onPressed,
    required this.value,
    required this.icon,
    required this.activeIcon,
    required this.activeColor,
    this.iconSize,
    super.key,
  });

  final String tooltip;
  final void Function() onPressed;
  final bool value;

  final IconData icon;
  final IconData activeIcon;
  final Color activeColor;

  /// Glyph size; defaults to the [IconButton] default when null.
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 48px to match the other header controls' tap target so the favorite
      // toggle is not the one cramped, harder-to-hit control in the cluster.
      width: 48,
      child: IconButton(
        splashColor: Colors.transparent,
        focusColor: Colors.transparent,
        padding: EdgeInsets.zero,
        splashRadius: 1,
        tooltip: tooltip,
        onPressed: () {
          if (value) {
            HapticFeedback.lightImpact();
          } else {
            HapticFeedback.heavyImpact();
          }
          onPressed();
        },
        icon: value
            ? Icon(
                activeIcon,
                size: iconSize,
                color: activeColor,
              )
            : Icon(
                icon,
                size: iconSize,
                // mediumEmphasis (white @ 80%, ~10:1) keeps the OFF control
                // quiet so it does not out-compete the card's value for first
                // fixation. Perceptibility for low-vision users is carried by
                // the larger glyph size (headerActionIconSize), not brightness.
                color: context.designTokens.colors.text.mediumEmphasis,
              ),
      ),
    );
  }
}
