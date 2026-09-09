import 'dart:ui';

import 'package:material_ui/material_ui.dart';

/// A container with a dark glass effect background for overlay icons.
///
/// Used to ensure icons are visible when displayed over images with
/// varying brightness. Provides a semi-transparent dark backdrop with
/// blur effect.
class GlassIconContainer extends StatelessWidget {
  const GlassIconContainer({
    required this.child,
    this.size = 40,
    this.borderRadius = 999,
    this.fill,
    super.key,
  });

  final Widget child;
  final double size;
  final double borderRadius;

  /// The glass's own colour. Null is the default dark glass; a host sitting
  /// on a photograph passes `PhotoNeutralGlass.fill`, which is the same glass
  /// at the strength a picture needs.
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: Clip.hardEdge,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: fill ?? Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}
