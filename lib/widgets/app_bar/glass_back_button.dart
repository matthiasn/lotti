import 'package:flutter/material.dart';
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
    this.iconSize = 26,
    super.key,
  });

  /// Callback when button is pressed. Defaults to [Navigator.maybePop].
  final VoidCallback? onPressed;

  /// Color of the chevron icon. Defaults to white.
  final Color iconColor;

  /// Size of the chevron icon. Defaults to 26.
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Material(
        type: MaterialType.transparency,
        clipBehavior: Clip.hardEdge,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onPressed ?? () => Navigator.of(context).maybePop(),
          child: GlassIconContainer(
            child: Icon(
              Icons.chevron_left,
              size: iconSize,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
