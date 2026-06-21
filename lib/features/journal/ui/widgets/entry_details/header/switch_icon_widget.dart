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
    super.key,
  });

  final String tooltip;
  final void Function() onPressed;
  final bool value;

  final IconData icon;
  final IconData activeIcon;
  final Color activeColor;

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
                color: activeColor,
              )
            : Icon(
                icon,
                // highEmphasis (pure white, ~15:1) for the OFF state: the thin
                // outline glyph (e.g. the unfavorited star) read as a faint
                // hairline at mediumEmphasis for low-vision users, so it was
                // hard to tell the control was present and tappable.
                color: context.designTokens.colors.text.highEmphasis,
              ),
      ),
    );
  }
}
