import 'dart:ui' as ui;

import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The chrome every floating glass chip wears: the floating-surface shadow,
/// a clip to [radius], and — for translucent chips — the backdrop blur that
/// lets the page show through the glass.
///
/// The blur lives here, inside each chip's own clip, rather than around the
/// row a chip sits in: a filter spanning a row would also blur the
/// transparent gap between chips and smear the page content the glass
/// exists to leave visible. An opaque chip (a solid accent fill) passes
/// `blurred: false` and skips the filter — there is nothing to see through.
///
/// Shared by the mobile navigation launcher's chips and the activity island
/// that floats above the bottom navigation, so every glass row in the app has
/// one silhouette and one treatment instead of a per-widget dialect.
class DsGlassChipSurface extends StatelessWidget {
  const DsGlassChipSurface({
    required this.radius,
    required this.blurred,
    required this.child,
    super.key,
  });

  final BorderRadius radius;

  /// Whether the child is translucent and needs the page blurred behind it.
  final bool blurred;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: DsShadows.floatingSurface,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: blurred
            ? BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: DesignSystemGlassStrip.blurSigma,
                  sigmaY: DesignSystemGlassStrip.blurSigma,
                ),
                child: child,
              )
            : child,
      ),
    );
  }
}
