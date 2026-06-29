import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/layers/city_lights_layer.dart'
    show coverFit;

/// Drifts one full-frame transparent cloud plate over the cloudless backdrop.
///
/// The source WebP stays in the same 2560x1440 coordinate space as the master
/// plate; this layer only shifts the cover-fitted draw rect by a small cyclic
/// offset. The skyline/yacht/foreground structure layers are drawn above it, so
/// clouds stay behind the city even while drifting.
class CloudParallaxLayer implements BackdropLayer {
  const CloudParallaxLayer(
    this.assetKey, {
    this.opacity = 1,
    this.dxPerSecond = 0.001,
    this.dyAmplitude = 0.002,
    this.dyCycleSeconds = 44,
    this.phase = 0,
  });

  /// Key into [BackdropContext.images] — an asset path from `SceneryAssets`.
  final String assetKey;

  /// 0..1 multiplier applied to the layer's alpha.
  final double opacity;

  /// One-way horizontal drift speed as a fraction of the cover-fitted art width
  /// per second. `0.001` means 12% of the frame over a two-minute track.
  final double dxPerSecond;

  /// Vertical drift amplitude as a fraction of the cover-fitted art height.
  final double dyAmplitude;

  /// Seconds per gentle vertical breathing cycle.
  final double dyCycleSeconds;

  /// Vertical phase offset (0..1) so cloud bands do not breathe in lockstep.
  final double phase;

  @override
  void paint(Canvas canvas, BackdropContext ctx) {
    final image = ctx.images[assetKey];
    if (image == null) return;

    final cover = coverFit(ctx.size);
    final time = ctx.reducedMotion ? 0.0 : ctx.timeSeconds;
    final offset = cloudParallaxOffset(cover, time, this);

    canvas
      ..save()
      ..clipRect(Offset.zero & ctx.size);
    for (final wrap in const [-1, 0, 1]) {
      paintImage(
        canvas: canvas,
        rect: cover.shift(
          offset + Offset(cover.width * wrap, 0),
        ),
        image: image,
        fit: BoxFit.fill,
        opacity: opacity.clamp(0.0, 1.0),
      );
    }
    canvas.restore();
  }
}

/// Pure offset calculation so cloud drift can be tested without a canvas.
Offset cloudParallaxOffset(
  Rect cover,
  double timeSeconds,
  CloudParallaxLayer layer,
) {
  final horizontalPhase = _fraction(timeSeconds * layer.dxPerSecond);
  final dx = horizontalPhase <= 0.5
      ? horizontalPhase * cover.width
      : (horizontalPhase - 1.0) * cover.width;
  final safeCycle = math.max(1, layer.dyCycleSeconds);
  final t = (timeSeconds / safeCycle) * math.pi * 2 + layer.phase * math.pi * 2;
  return Offset(
    dx,
    math.sin(t * 0.71 + layer.phase * 0.37) * cover.height * layer.dyAmplitude,
  );
}

double _fraction(double value) => value - value.floorToDouble();
