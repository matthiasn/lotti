import 'package:flutter/material.dart';
import 'package:lotti/widgets/app_bar/glass_action_button.dart';
import 'package:lotti/widgets/app_bar/glass_icon_container.dart';

/// A glass-styled back button for use over images.
///
/// Combines [GlassIconContainer] with Material and InkWell for tap feedback.
/// By default navigates back using [Navigator.maybePop], but accepts a custom
/// [onPressed] callback.
class GlassBackButton extends StatelessWidget {
  const GlassBackButton({
    this.onPressed,
    this.iconColor = Colors.white,
    this.iconSize = 24,
    this.containerSize = 34,
    super.key,
  });

  /// Callback when button is pressed. Defaults to [Navigator.maybePop].
  final VoidCallback? onPressed;

  /// Color of the chevron icon. Defaults to white.
  final Color iconColor;

  /// Size of the chevron icon. Defaults to 24.
  final double iconSize;

  /// Size of the glass container. Defaults to 34.
  final double containerSize;

  @override
  Widget build(BuildContext context) {
    return GlassActionButton(
      onTap: onPressed ?? () => Navigator.of(context).maybePop(),
      size: containerSize,
      child: Icon(
        Icons.chevron_left,
        size: iconSize,
        color: iconColor,
      ),
    );
  }
}
