import 'package:flutter/material.dart';

/// Small circular icon button that floats over a message bubble's corner
/// (e.g. the copy affordance on assistant bubbles).
class BubbleCornerAction extends StatelessWidget {
  const BubbleCornerAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        elevation: 2,
        shape: const CircleBorder(),
        shadowColor: Colors.black.withValues(alpha: 0.3),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 16, color: theme.colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}
