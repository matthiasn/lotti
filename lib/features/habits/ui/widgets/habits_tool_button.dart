import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// A compact, circular icon toggle for the Habits header tools (search, …).
///
/// Built from design-system tokens so it sits beside the category pie filter
/// and the status toggle as one quiet family: an accent-tinted fill + accent
/// ink when active, transparent + medium-emphasis ink when off. Material +
/// InkWell + [Semantics] so it is focusable, keyboard-activatable, and
/// announced as a selected/unselected button.
class HabitsToolButton extends StatelessWidget {
  const HabitsToolButton({
    required this.icon,
    required this.active,
    required this.onPressed,
    required this.semanticLabel,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onPressed;
  final String semanticLabel;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final diameter = tokens.spacing.step8; // 40dp touch target

    final button = Semantics(
      button: true,
      selected: active,
      label: semanticLabel,
      child: Material(
        color: active ? tokens.colors.surface.active : Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          hoverColor: tokens.colors.surface.hover,
          child: SizedBox(
            width: diameter,
            height: diameter,
            child: Icon(
              icon,
              size: tokens.spacing.step5,
              color: active
                  ? tokens.colors.interactive.enabled
                  : tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }
}
