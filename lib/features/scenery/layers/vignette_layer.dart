import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';

/// Cinematic vignette: a soft radial darkening toward the frame edges, opening
/// around a focal centre placed slightly above the middle (on the skyline band).
/// Multiplied over the fully composed scene so the corners sink and the eye is
/// held on the lit city — the classic establishing-shot containment. Static and
/// allocation-light (one gradient rect per frame).
class VignetteLayer implements BackdropLayer {
  const VignetteLayer({
    this.strength = 0.22,
    this.dim = 0,
    this.center = const Offset(0.5, 0.42),
  });

  /// 0 = none; the fraction of luminance removed at the far corners.
  final double strength;

  /// 0 = none; a flat fraction of luminance removed across the WHOLE frame
  /// (a global exposure pull-down), on top of which [strength] adds the radial
  /// edge falloff. Keeps the blue-hour scene reading as twilight, not daylight.
  final double dim;

  /// Normalized focal centre the vignette opens around.
  final Offset center;

  @override
  void paint(Canvas canvas, BackdropContext ctx) {
    final size = ctx.size;
    final d = dim.clamp(0.0, 1.0);
    if (size.isEmpty || (strength <= 0 && d <= 0)) return;
    final c = Offset(center.dx * size.width, center.dy * size.height);
    final radius = size.longestSide * 0.72;
    // Flat dim is the inner luminance (centre + mid); the edge sinks further by
    // [strength] on top of it.
    final inner = (255 * (1.0 - d)).round();
    final edge = (255 * (1.0 - (d + strength).clamp(0.0, 1.0))).round();
    final innerColor = Color.fromARGB(255, inner, inner, inner);
    final dark = Color.fromARGB(255, edge, edge, edge);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.multiply
        ..shader = ui.Gradient.radial(
          c,
          radius,
          [innerColor, innerColor, dark],
          [0.0, 0.55, 1.0],
        ),
    );
  }
}
