import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/model/scenery_assets.dart';
import 'package:lotti/features/scenery/model/skyline_manifest.dart';
import 'package:lotti/features/scenery/runtime/scenery_shaders.dart';

/// Additive night-lights layer drawn over the painted plate: lit building
/// windows (confined to the city silhouette by the `city_bridge` mask) and warm
/// yacht cabin windows (confined by the `yacht` mask) via the city-lights
/// shader, plus blinking red aircraft warning beacons on the tallest towers and
/// bridge pylons (canvas, from [SkylineManifest] anchors).
///
/// Both the shader's mask sampling and the beacon positions are placed through
/// the SAME cover-fit mapping the master plate uses ([coverFit]), so every light
/// lands exactly on its painted structure at any viewport aspect ratio.
/// Everything blends with [BlendMode.plus] so it only adds glow.
class CityLightsLayer implements BackdropLayer {
  const CityLightsLayer({this.windowAmount = 0.35, this.flicker = 0.3});

  /// Fraction of city windows that are lit.
  final double windowAmount;

  /// Flicker depth (0 = steady).
  final double flicker;

  @override
  void paint(Canvas canvas, BackdropContext ctx) {
    final cover = coverFit(ctx.size);
    _paintWindows(canvas, ctx, cover);
    _paintBeacons(canvas, ctx, cover);
  }

  void _paintWindows(Canvas canvas, BackdropContext ctx, Rect cover) {
    final program = ctx.cityLightsProgram;
    final cityMask = ctx.images[SceneryAssets.cityBridge];
    final yachtMask = ctx.images[SceneryAssets.yacht];
    if (program == null || cityMask == null || yachtMask == null) return;
    final p = ctx.palette;
    final shader = program.fragmentShader()
      ..setFloat(0, ctx.size.width)
      ..setFloat(1, ctx.size.height)
      ..setFloat(2, ctx.timeSeconds)
      ..setFloat(3, windowAmount)
      ..setFloat(4, ctx.reducedMotion ? 0 : flicker)
      ..setFloat(5, ctx.beatPulse)
      ..setFloat(6, cover.left)
      ..setFloat(7, cover.top)
      ..setFloat(8, cover.width)
      ..setFloat(9, cover.height);
    setSceneryColor(shader, 10, p.windowSodium);
    setSceneryColor(shader, 14, p.windowLed);
    setSceneryColor(shader, 18, p.yachtCabinGlow);
    shader
      ..setImageSampler(0, cityMask)
      ..setImageSampler(1, yachtMask);
    canvas.drawRect(
      Offset.zero & ctx.size,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = shader,
    );
  }

  void _paintBeacons(Canvas canvas, BackdropContext ctx, Rect cover) {
    final manifest = ctx.manifest ?? kPlaceholderSkylineManifest;
    final anchors = [...manifest.buildingTops, ...manifest.bridgeTowerTops];
    if (anchors.isEmpty) return;
    final time = ctx.reducedMotion ? 0.0 : ctx.timeSeconds;
    final r = cover.width * 0.0018;
    final red = ctx.palette.beaconRed;
    for (var i = 0; i < anchors.length; i++) {
      final intensity = beaconIntensity(i, time);
      if (intensity <= 0) continue;
      final c = Offset(
        cover.left + anchors[i].dx * cover.width,
        cover.top + anchors[i].dy * cover.height,
      );
      canvas
        ..drawCircle(
          c,
          r * 3,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = ui.Gradient.radial(c, r * 3, [
              red.withValues(alpha: 0.6 * intensity),
              red.withValues(alpha: 0),
            ]),
        )
        ..drawCircle(
          c,
          r,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = red.withValues(alpha: intensity),
        );
    }
  }
}

/// The rect the [kSceneryCanvasSize] art occupies when cover-fit into
/// [viewport] (matching `BoxFit.cover`): same scale + centering the master
/// plate uses, so normalized art anchors map to screen via
/// `cover.topLeft + anchor * cover.size`.
Rect coverFit(Size viewport) {
  const art = kSceneryCanvasSize;
  final scale = math.max(
    viewport.width / art.width,
    viewport.height / art.height,
  );
  final w = art.width * scale;
  final h = art.height * scale;
  return Rect.fromLTWH(
    (viewport.width - w) / 2,
    (viewport.height - h) / 2,
    w,
    h,
  );
}

/// Blink schedule for aircraft beacon [index] at [time] seconds, modelling a
/// real FAA L-864 red obstruction beacon: a single slow pulse per cycle at
/// ~20-40 flashes/min (here ~2.5s, i.e. ~24 fpm) with a soft raised-cosine
/// rise/hold/fall — a gentle breath, NOT a strobe. Each tower is lightly phase-
/// staggered so they don't pulse in lockstep. Returns 0 between flashes (the
/// lamp is dark ~75% of the cycle). Pure for unit testing.
double beaconIntensity(int index, double time) {
  final period = 2.4 + 0.4 * _frac(index * 0.37 + 0.11);
  final phase = _frac(index * 0.613);
  final pos = _frac(time / period + phase);
  const duty = 0.25; // fraction of the cycle the lamp is pulsing
  if (pos > duty) return 0;
  return 0.5 - 0.5 * math.cos(pos / duty * 2 * math.pi);
}

double _frac(double x) => x - x.floorToDouble();
