import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/model/scenery_assets.dart';
import 'package:lotti/features/scenery/model/skyline_manifest.dart';
import 'package:lotti/features/scenery/runtime/scenery_shaders.dart';

/// Additive night-lights layer drawn over the painted plate: lit building
/// windows (read from the master-derived `city_windows` field so each glow lands
/// on a real painted window) and warm yacht cabin windows (confined by the
/// `yacht` mask) via the city-lights shader, plus blinking red aircraft warning
/// beacons on the tallest towers and bridge pylons (canvas, from
/// [SkylineManifest] anchors).
///
/// Both the shader's mask sampling and the beacon positions are placed through
/// the SAME cover-fit mapping the master plate uses ([coverFit]), so every light
/// lands exactly on its painted structure at any viewport aspect ratio.
/// Everything blends with [BlendMode.plus] so it only adds glow.
class CityLightsLayer implements BackdropLayer {
  const CityLightsLayer({this.windowAmount = 0.6, this.flicker = 0.3});

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
    final windowField = ctx.images[SceneryAssets.cityWindows];
    final yachtMask = ctx.images[SceneryAssets.yacht];
    final master = ctx.images[SceneryAssets.masterPlate];
    if (program == null ||
        windowField == null ||
        yachtMask == null ||
        master == null) {
      return;
    }
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
      ..setImageSampler(0, windowField)
      ..setImageSampler(1, yachtMask)
      ..setImageSampler(2, master);
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
    // All beacons flash in unison (real obstruction lights are synchronized),
    // so the pulse is computed once for the whole skyline.
    final intensity = beaconIntensity(time);
    if (intensity <= 0) return;
    final r = cover.width * 0.0018;
    final red = ctx.palette.beaconRed;
    for (var i = 0; i < anchors.length; i++) {
      final c = Offset(
        cover.left + anchors[i].dx * cover.width,
        cover.top + anchors[i].dy * cover.height,
      );
      // A real obstruction lamp is a near-point hot core inside a small
      // steep-falloff atmospheric halo — not a soft red bubble. The core clips
      // toward a warm ORANGE-white (not pure/cool white), so at distance the
      // lamp reads as a hazed red-orange aviation light rather than neon pink.
      // Halo (0.34) + core (0.55) stay UNDER 1.0 summed so the centre never
      // blows to a magenta-white disc — it holds a hot red-orange instead.
      final core = Color.lerp(red, const Color(0xFFFFC890), 0.42)!;
      canvas
        ..drawCircle(
          c,
          r * 3.6,
          Paint()
            ..blendMode = BlendMode.plus
            // Steep falloff via an early-fading middle stop so the glow stays a
            // tight halo around the core.
            ..shader = ui.Gradient.radial(
              c,
              r * 3.6,
              [
                red.withValues(alpha: 0.34 * intensity),
                red.withValues(alpha: 0.08 * intensity),
                red.withValues(alpha: 0),
              ],
              [0.0, 0.4, 1.0],
            ),
        )
        ..drawCircle(
          c,
          r * 0.75,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = core.withValues(alpha: 0.55 * intensity),
        )
        // A faint horizontal anamorphic streak so the lamp reads as an emissive
        // SOURCE with a lens signature, not a round gaussian sticker.
        ..save()
        ..translate(c.dx, c.dy)
        ..scale(1, 0.22)
        ..drawCircle(
          Offset.zero,
          r * 5.0,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = ui.Gradient.radial(
              Offset.zero,
              r * 5.0,
              [
                core.withValues(alpha: 0.32 * intensity),
                red.withValues(alpha: 0.07 * intensity),
                red.withValues(alpha: 0),
              ],
              [0.0, 0.45, 1.0],
            ),
        )
        ..restore();
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

/// Blink intensity for the aircraft warning beacons at [time] seconds,
/// modelling a real FAA L-864 red obstruction beacon: one slow pulse per 2.0s
/// cycle (30 flashes/min, the certified standard inside the 20-40 fpm range)
/// with a soft raised-cosine rise/fall — a gentle breath, NOT a strobe. Real
/// obstruction lights are synchronized to flash simultaneously (AC 70/7460-1),
/// so every tower shares this one value. Dark ~78% of the cycle. Pure for
/// unit testing.
double beaconIntensity(double time) {
  const period = 2.0;
  final pos = _frac(time / period);
  const duty = 0.22; // fraction of the cycle the lamp is pulsing
  if (pos > duty) return 0;
  return 0.5 - 0.5 * math.cos(pos / duty * 2 * math.pi);
}

double _frac(double x) => x - x.floorToDouble();
