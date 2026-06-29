import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/runtime/scenery_shaders.dart';

/// Full-screen blue-hour sky: gradient + moon + stars + drifting clouds.
///
/// Draws the `scenery_sky.frag` program when [BackdropContext.skyProgram] is
/// loaded. HARD RULE: there is no CPU fallback — until the GPU program compiles
/// the sky is simply not drawn, so the on-screen artwork is always the real
/// shader, never a divergent stand-in.
class SkyLayer implements BackdropLayer {
  const SkyLayer({
    this.horizon = 0.62,
    this.sunGlowX = 0.66,
    this.moonX = 0.78,
    this.moonY = 0.2,
    this.moonRadius = 0.055,
    this.starDensity = 0.7,
    this.cloudCoverage = 0.5,
    this.cloudSoftness = 0.14,
    this.cloudScale = 1.6,
    this.hazeStrength = 0.45,
    this.grain = 0.035,
    this.speed = 1,
  });

  /// y-fraction of the horizon/waterline.
  final double horizon;

  /// x-fraction of the post-sunset afterglow hotspot on the horizon.
  final double sunGlowX;

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
    // Hard rule: full shader fidelity or nothing — no CPU fallback. Until the
    // GPU program finishes compiling (async) the sky is not drawn; there is no
    // lower-fidelity stand-in that could diverge from the real artwork.
    if (program == null) return;
    final shader = program.fragmentShader();
    final scalars = buildSkyUniforms(ctx.size, time, this);
    for (var i = 0; i < scalars.length; i++) {
      shader.setFloat(i, scalars[i]);
    }
    final p = ctx.palette;
    setSceneryColor(shader, 14, p.skyZenith);
    setSceneryColor(shader, 18, p.skyUpper);
    setSceneryColor(shader, 22, p.skyHorizonCool);
    setSceneryColor(shader, 26, p.sunsetGlow);
    setSceneryColor(shader, 30, p.sunsetHot);
    setSceneryColor(shader, 34, p.cloudBase);
    setSceneryColor(shader, 38, p.moonDisk);
    setSceneryColor(shader, 42, p.moonHalo);
    setSceneryColor(shader, 46, p.star);
    setSceneryColor(shader, 50, p.hazeSmog);
    canvas.drawRect(Offset.zero & ctx.size, Paint()..shader = shader);
  }
}

/// Builds the 14 scalar uniforms (indices 0..13) for `scenery_sky.frag`. The
/// vec4 color uniforms follow at index 14. Pure + deterministic so the wiring
/// can be unit-tested without a GPU.
List<double> buildSkyUniforms(ui.Size size, double time, SkyLayer layer) {
  return <double>[
    size.width, // 0
    size.height, // 1
    time, // 2
    layer.horizon, // 3
    layer.sunGlowX, // 4
    layer.moonX, // 5
    layer.moonY, // 6
    layer.moonRadius, // 7
    layer.starDensity, // 8
    layer.cloudCoverage, // 9
    layer.cloudSoftness, // 10
    layer.cloudScale, // 11
    layer.hazeStrength, // 12
    layer.grain, // 13
  ];
}
