import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/layers/city_lights_layer.dart'
    show coverFit;
import 'package:lotti/features/scenery/model/backdrop_palette.dart';
import 'package:lotti/features/scenery/model/skyline_manifest.dart';

/// Band-clipped ocean overlay drawn over the painted plate's static water.
///
/// The master plate already paints the lagoon; this layer ADDS animated life —
/// drifting foam crests, a broken vertical moon-glint column, and a very subtle
/// vertical tint — confined to the water band below the [SkylineManifest]
/// waterline. Both the shader and the CPU fallback place that band through the
/// SAME cover-fit mapping the master plate uses ([coverFit]), so the animated
/// water lines up with the painted waterline at any viewport aspect.
///
/// Draws the `scenery_ocean.frag` program additively ([BlendMode.plus]) when
/// [BackdropContext.oceanProgram] is loaded, and a calm CPU band gradient
/// ([paintOceanFallback]) until then so the scene never shows a blank frame.
/// Honors [BackdropContext.reducedMotion] by freezing the clock and the beat.
class OceanLayer implements BackdropLayer {
  const OceanLayer({
    this.moonX = 0.5,
    this.foamDensity = 0.4,
    this.waveScale = 9,
    this.reflection = 0.22,
    this.tint = 0.05,
    this.grain = 0.02,
    this.speed = 1,
  });

  /// Normalized art-x of the moon-reflection glint column (0..1).
  final double moonX;

  /// Crest coverage (0 = no foam .. 1 = busy).
  final double foamDensity;

  /// Base crest spatial frequency.
  final double waveScale;

  /// Moon-glint column strength.
  final double reflection;

  /// Subtle vertical-tint alpha (kept low — the plate already paints water).
  final double tint;

  /// Film-grain amount.
  final double grain;

  /// Multiplier on the scene clock.
  final double speed;

  @override
  void paint(Canvas canvas, BackdropContext ctx) {
    final time = ctx.reducedMotion ? 0.0 : ctx.timeSeconds * speed;
    final beat = ctx.reducedMotion ? 0.0 : ctx.beatPulse;
    final waterline = (ctx.manifest ?? kPlaceholderSkylineManifest).waterline;
    final cover = coverFit(ctx.size);

    final program = ctx.oceanProgram;
    if (program == null) {
      paintOceanFallback(
        canvas,
        ctx.size,
        time,
        ctx.palette,
        this,
        cover: cover,
        waterline: waterline,
        beat: beat,
      );
      return;
    }

    final shader = program.fragmentShader();
    final u = buildOceanUniforms(
      ctx.size,
      time,
      this,
      ctx.palette,
      cover: cover,
      waterline: waterline,
      beat: beat,
    );
    for (var i = 0; i < u.length; i++) {
      shader.setFloat(i, u[i]);
    }
    canvas.drawRect(
      Offset.zero & ctx.size,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = shader,
    );
  }
}

/// Builds the 31 floats (indices 0..30) for `scenery_ocean.frag`: the leading
/// `resolution`/`time` convention, the cover-fit rect + waterline that pin the
/// band to the painted plate, the foam/glint knobs, the beat, and the four
/// palette colors unpacked at offsets 15/19/23/27. Pure + deterministic so the
/// wiring can be unit-tested without a GPU.
List<double> buildOceanUniforms(
  ui.Size size,
  double time,
  OceanLayer layer,
  BackdropPalette palette, {
  required Rect cover,
  required double waterline,
  required double beat,
}) {
  return <double>[
    size.width, // 0
    size.height, // 1
    time, // 2
    cover.left, // 3
    cover.top, // 4
    cover.width, // 5
    cover.height, // 6
    waterline, // 7
    layer.moonX, // 8
    layer.foamDensity, // 9
    layer.waveScale, // 10
    layer.reflection, // 11
    layer.tint, // 12
    layer.grain, // 13
    beat, // 14
    ..._rgba(palette.oceanHorizon), // 15..18
    ..._rgba(palette.oceanNear), // 19..22
    ..._rgba(palette.foam), // 23..26
    ..._rgba(palette.moonGlint), // 27..30
  ];
}

/// CPU approximation used when the ocean program has not loaded: a teal water
/// band (horizon→near gradient) under the cover-mapped waterline, with a few
/// drifting foam crest lines and a broken moon-glint column. Deterministic for
/// a given [time]; confined to the water band (nothing above the waterline).
void paintOceanFallback(
  Canvas canvas,
  ui.Size size,
  double time,
  BackdropPalette palette,
  OceanLayer layer, {
  required Rect cover,
  required double waterline,
  required double beat,
}) {
  if (size.isEmpty) return;
  final foamDensity = layer.foamDensity.clamp(0.0, 1.0);
  final reflection = layer.reflection.clamp(0.0, 1.0);
  final foamBoost = 1.0 + 0.6 * beat.clamp(0.0, 1.0);
  final waterTop = (cover.top + waterline * cover.height).clamp(
    0.0,
    size.height,
  );
  if (waterTop >= size.height) return;
  final bandHeight = size.height - waterTop;
  final bandRect = Rect.fromLTRB(0, waterTop, size.width, size.height);

  canvas
    ..save()
    ..clipRect(bandRect)
    // Vertical water gradient: teal at the waterline → deep near the bottom.
    ..drawRect(
      bandRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width / 2, waterTop),
          Offset(size.width / 2, size.height),
          [palette.oceanHorizon, palette.oceanNear],
        ),
    );

  // Foam crests: a few advected sine ridges, perspective-compressed (denser and
  // thinner near the horizon, broader and brighter near the bottom).
  for (var k = 0; k < 3; k++) {
    final depth = 0.25 + k * 0.22; // band fraction of this crest row
    final y = waterTop + depth * bandHeight;
    final amp = bandHeight * (0.012 + 0.018 * depth);
    final freq = math.pi * 2 * (3.0 - 1.6 * depth);
    // Floor keeps the crest a visible line even on tiny renders; real
    // full-resolution renders compute a wider stroke and ignore the floor.
    final stroke = math.max(
      1.5,
      size.height * 0.004 * (0.5 + depth) * foamBoost,
    );
    final path = Path()..moveTo(0, y);
    const steps = 64;
    for (var s = 0; s <= steps; s++) {
      final fx = s / steps;
      final wob =
          math.sin(fx * freq + time * (0.5 + 0.3 * k) + k * 1.7) +
          0.4 * math.sin(fx * freq * 2.3 - time * 0.4);
      path.lineTo(fx * size.width, y + wob * amp);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = palette.foam.withValues(
          alpha: (0.45 + 0.4 * depth) * foamDensity,
        ),
    );
  }

  // Broken vertical moon-glint column near moonX (warm reflection blobs).
  final glintX = cover.left + layer.moonX * cover.width;
  final glintW = size.width * 0.05;
  for (var b = 0; b < 9; b++) {
    final f = (b + 0.5) / 9;
    final y = waterTop + f * bandHeight;
    // Flicker never fully extinguishes a blob, so the column stays a broken but
    // continuous reflection rather than blinking out.
    final flicker = 0.6 + 0.4 * math.sin(f * 22 + time * 1.3 + b);
    final a = reflection * (0.3 + 0.6 * f) * flicker;
    if (a <= 0.02) continue;
    final r = glintW * (0.5 + 0.5 * f);
    canvas.drawCircle(
      Offset(glintX, y),
      r,
      Paint()
        ..shader = ui.Gradient.radial(Offset(glintX, y), r, [
          palette.moonGlint.withValues(alpha: a),
          palette.moonGlint.withValues(alpha: 0),
        ]),
    );
  }

  canvas.restore();
}

List<double> _rgba(ui.Color c) => [c.r, c.g, c.b, c.a];
