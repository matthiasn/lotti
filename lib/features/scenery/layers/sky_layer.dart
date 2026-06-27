import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/model/backdrop_palette.dart';
import 'package:lotti/features/scenery/runtime/scenery_shaders.dart';

/// Full-screen blue-hour sky: gradient + moon + stars + drifting clouds.
///
/// Draws the `scenery_sky.frag` program when [BackdropContext.skyProgram] is
/// loaded, and a calm CPU approximation ([paintSkyFallback]) until then so the
/// scene never shows a blank frame.
class SkyLayer implements BackdropLayer {
  const SkyLayer({
    this.horizon = 0.62,
    this.moonX = 0.74,
    this.moonY = 0.22,
    this.moonRadius = 0.07,
    this.starDensity = 0.6,
    this.cloudCoverage = 0.52,
    this.cloudSoftness = 0.18,
    this.cloudScale = 2.2,
    this.hazeStrength = 0.5,
    this.grain = 0.04,
    this.speed = 1,
  });

  /// y-fraction of the horizon/waterline.
  final double horizon;

  /// Moon center (0..1, top-left origin).
  final double moonX;
  final double moonY;

  /// Moon radius as a fraction of the smaller dimension.
  final double moonRadius;

  /// Star coverage (0..1).
  final double starDensity;

  /// Cloud threshold (higher => sparser clouds) and edge feather.
  final double cloudCoverage;
  final double cloudSoftness;

  /// Cloud spatial frequency.
  final double cloudScale;

  /// Smog/haze band strength and film-grain amount.
  final double hazeStrength;
  final double grain;

  /// Multiplier on the scene clock.
  final double speed;

  @override
  void paint(Canvas canvas, BackdropContext ctx) {
    final time = ctx.timeSeconds * speed;
    final program = ctx.skyProgram;
    if (program == null) {
      paintSkyFallback(canvas, ctx.size, time, ctx.palette, this);
      return;
    }
    final shader = program.fragmentShader();
    final scalars = buildSkyUniforms(ctx.size, time, this);
    for (var i = 0; i < scalars.length; i++) {
      shader.setFloat(i, scalars[i]);
    }
    final p = ctx.palette;
    setSceneryColor(shader, 13, p.skyZenith);
    setSceneryColor(shader, 17, p.skyUpper);
    setSceneryColor(shader, 21, p.skyHorizonCool);
    setSceneryColor(shader, 25, p.moonDisk);
    setSceneryColor(shader, 29, p.moonHalo);
    setSceneryColor(shader, 33, p.star);
    setSceneryColor(shader, 37, p.cloudLit);
    setSceneryColor(shader, 41, p.cloudBase);
    setSceneryColor(shader, 45, p.hazeSmog);
    canvas.drawRect(Offset.zero & ctx.size, Paint()..shader = shader);
  }
}

/// Builds the 13 scalar uniforms (indices 0..12) for `scenery_sky.frag`. The
/// vec4 color uniforms follow at index 13. Pure + deterministic so the wiring
/// can be unit-tested without a GPU.
List<double> buildSkyUniforms(ui.Size size, double time, SkyLayer layer) {
  return <double>[
    size.width, // 0
    size.height, // 1
    time, // 2
    layer.horizon, // 3
    layer.moonX, // 4
    layer.moonY, // 5
    layer.moonRadius, // 6
    layer.starDensity, // 7
    layer.cloudCoverage, // 8
    layer.cloudSoftness, // 9
    layer.cloudScale, // 10
    layer.hazeStrength, // 11
    layer.grain, // 12
  ];
}

/// CPU approximation used when the sky program has not loaded. Deterministic
/// for a given [time]: blue gradient, a bloomed moon, a capped twinkling star
/// field, and a couple of soft clouds.
void paintSkyFallback(
  Canvas canvas,
  ui.Size size,
  double time,
  BackdropPalette palette,
  SkyLayer layer,
) {
  if (size.isEmpty) return;
  final rect = Offset.zero & size;
  final shortest = math.min(size.width, size.height);
  final horizonY = layer.horizon.clamp(0.0, 1.0) * size.height;

  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, horizonY),
        [palette.skyZenith, palette.skyUpper, palette.skyHorizonCool],
        const [0, 0.72, 1],
      ),
  );

  // Stars (capped, deterministic positions + twinkle).
  final starPaint = Paint();
  for (var i = 0; i < 44; i++) {
    final hx = _hash01(i * 2 + 1);
    final hy = _hash01(i * 2 + 2);
    final x = hx * size.width;
    final y = hy * horizonY * 0.92;
    final twinkle = 0.5 + 0.5 * math.sin(time * (1.4 + 2.6 * hx) + i * 1.7);
    starPaint.color = palette.star.withValues(alpha: 0.25 + 0.55 * twinkle);
    canvas.drawCircle(Offset(x, y), shortest * 0.0016, starPaint);
  }

  // Moon: halo bloom then warm disc.
  final moonCenter = Offset(
    layer.moonX * size.width,
    layer.moonY * size.height,
  );
  final r = layer.moonRadius * shortest;
  final haloPaint = Paint()
    ..shader = ui.Gradient.radial(moonCenter, r * 3.2, [
      palette.moonHalo.withValues(alpha: 0.42),
      palette.moonHalo.withValues(alpha: 0),
    ]);
  final discPaint = Paint()..color = palette.moonDisk;
  canvas
    ..drawCircle(moonCenter, r * 3.2, haloPaint)
    ..drawCircle(moonCenter, r, discPaint);

  // A couple of soft drifting clouds + a haze band lifting the horizon.
  final drift = (time * 6) % (size.width + 200) - 100;
  final cloudPaint = Paint()
    ..color = palette.cloudLit.withValues(alpha: 0.22)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
  final hazePaint = Paint()
    ..shader = ui.Gradient.linear(
      Offset(0, horizonY * 0.7),
      Offset(0, horizonY),
      [
        palette.hazeSmog.withValues(alpha: 0),
        palette.hazeSmog.withValues(alpha: 0.36),
      ],
    );
  canvas
    ..drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.32 + drift, horizonY * 0.46),
        width: size.width * 0.36,
        height: shortest * 0.10,
      ),
      cloudPaint,
    )
    ..drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.62 + drift * 0.6, horizonY * 0.62),
        width: size.width * 0.30,
        height: shortest * 0.08,
      ),
      cloudPaint,
    )
    ..drawRect(
      Rect.fromLTRB(0, horizonY * 0.7, size.width, horizonY),
      hazePaint,
    );
}

/// Deterministic 0..1 hash for the fallback's star placement.
double _hash01(int n) {
  final x = math.sin(n * 12.9898) * 43758.5453;
  return x - x.floorToDouble();
}
