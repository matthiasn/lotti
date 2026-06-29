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
/// waterline. The band is placed through the SAME cover-fit mapping the master
/// plate uses ([coverFit]), so the animated water lines up with the painted
/// waterline at any viewport aspect.
///
/// Draws the `scenery_ocean.frag` program additively ([BlendMode.plus]) when
/// [BackdropContext.oceanProgram] is loaded. HARD RULE: there is no CPU
/// fallback — until the GPU program compiles the band is simply not drawn (the
/// painted plate shows through), so the on-screen artwork is always the real
/// shader, never a divergent stand-in. Honors [BackdropContext.reducedMotion]
/// by freezing the clock and the beat.
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
    // Hard rule: full shader fidelity or nothing — no CPU fallback. Until the
    // GPU program finishes compiling (async), the band is simply not drawn and
    // the painted plate shows through; there is no lower-fidelity stand-in that
    // could diverge from the real artwork.
    if (program == null) return;

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

List<double> _rgba(ui.Color c) => [c.r, c.g, c.b, c.a];
