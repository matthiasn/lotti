import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// A reusable bottom bar for forms with consistent styling and button layout
///
/// This widget provides a standard bottom bar with shadow, proper spacing,
/// and support for left (typically destructive) and right (action) buttons.
class FormBottomBar extends StatelessWidget {
  const FormBottomBar({
    required this.rightButtons,
    super.key,
    this.leftButton,
  });

  /// Optional button on the left side (typically for delete/destructive actions)
  final Widget? leftButton;

  /// List of buttons on the right side (typically cancel/save actions)
  final List<Widget> rightButtons;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: leftButton != null
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.end,
        children: [
          if (leftButton != null) leftButton!,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < rightButtons.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                rightButtons[i],
              ],
            ],
          ),
        ],
      ),
    );
  }
}
