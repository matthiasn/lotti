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
    this.center = const Offset(0.5, 0.42),
  });

  /// 0 = none; the fraction of luminance removed at the far corners.
  final double strength;

  /// Normalized focal centre the vignette opens around.
  final Offset center;

  @override
  void paint(Canvas canvas, BackdropContext ctx) {
    final size = ctx.size;
    if (size.isEmpty || strength <= 0) return;
    final c = Offset(center.dx * size.width, center.dy * size.height);
    final radius = size.longestSide * 0.72;
    final edge = (255 * (1.0 - strength.clamp(0.0, 1.0))).round();
    final dark = Color.fromARGB(255, edge, edge, edge);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.multiply
        ..shader = ui.Gradient.radial(
          c,
          radius,
          [const Color(0xFFFFFFFF), const Color(0xFFFFFFFF), dark],
          [0.0, 0.55, 1.0],
        ),
    );
  }
}
