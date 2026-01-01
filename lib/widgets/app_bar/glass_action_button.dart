import 'package:flutter/material.dart';
import 'package:lotti/widgets/app_bar/glass_icon_container.dart';

/// A glass-styled action button for use over images.
///
/// Combines [GlassIconContainer] with Material and InkWell for tap feedback.
/// Accepts any child widget (typically an Icon) and an onTap callback.
class GlassActionButton extends StatelessWidget {
  const GlassActionButton({
    required this.child,
    required this.onTap,
    this.size = 40,
    super.key,
  });

  /// The widget to display inside the glass container.
  final Widget child;

  /// Callback when button is tapped.
  final VoidCallback onTap;

  /// Size of the glass container. Defaults to 40.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      clipBehavior: Clip.hardEdge,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        child: GlassIconContainer(
          size: size,
          child: child,
        ),
      ),
    );
  }
}
