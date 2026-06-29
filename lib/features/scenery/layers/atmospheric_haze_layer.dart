import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/layers/city_lights_layer.dart'
    show coverFit;
import 'package:lotti/features/scenery/model/backdrop_palette.dart';
import 'package:lotti/features/scenery/model/skyline_manifest.dart';

/// Aerial-perspective haze: a soft cool veil banded on the [SkylineManifest]
/// waterline, painted OVER the distant structures (skyline, bridge, yacht) but
/// UNDER the foreground deck/palms and the dancers.
///
/// Blue-hour air over a lagoon is full of scattered light + low smog, so the
/// farther a surface is the more its contrast is washed toward the cool horizon
/// tone (Rayleigh air-light). The painted plate bakes the structures at near
/// full contrast, which reads as a flat cardboard cut-out competing with the
/// foreground performers. This layer re-introduces the depth cue an "expensive
/// establishing shot" relies on: it lifts the blacks and desaturates the
/// midground sitting on the waterline, so the city/bridge/yacht recede and the
/// crisp, un-hazed deck + trio in front of them pop forward — the cheap cousin
/// of a true defocus, without a per-frame blur.
///
/// The veil is a vertical band: transparent up in the open sky, peaking right at
/// the waterline where the most distant bases (far-shore, bridge piers, hull
/// waterline) sit, then fading back out into the near water so the foreground
/// (drawn after this layer) stays clear. Static + allocation-light (one
/// gradient rect). The colour is mixed from the palette's
/// [BackdropPalette.hazeSmog] (the low warm-grey pollution band) toward
/// [BackdropPalette.skyHorizonCool] so the lift reads as cool twilight air, not
/// a grey smear.
class AtmosphericHazeLayer implements BackdropLayer {
  const AtmosphericHazeLayer({
    this.strength = 0.3,
    this.coolMix = 0.55,
    this.paleLift = 0.4,
    this.skyReach = 0.18,
    this.waterReach = 0.09,
  });

  /// Peak veil opacity at the waterline (0 = none).
  final double strength;

  /// 0 keeps the raw [BackdropPalette.hazeSmog]; 1 pulls the veil fully to
  /// [BackdropPalette.skyHorizonCool]. Blue-hour air-light is cool, so the
  /// default leans past halfway.
  final double coolMix;

  /// After the warm-grey→cool mix, how far the veil lifts toward the pale
  /// cloud-top tone ([BackdropPalette.cloudLit]). A real aerial-haze band reads
  /// as a *bright, pale* fog line dissolving the distant bases — not a dark
  /// tint — so the lift raises both value and the "fog" read.
  final double paleLift;

  /// How far the veil bleeds UP into the sky above the waterline, as a fraction
  /// of the cover-fit art height — this is the side that matters: it dissolves
  /// the BASES of the skyline / bridge / yacht sitting just above the waterline.
  final double skyReach;

  /// How far the veil bleeds DOWN into the near water below the waterline, as a
  /// fraction of art height. Kept SHORT so the band hugs the structure bases and
  /// does not wash over the broken reflection columns the ocean shader paints in
  /// the water just below the waterline.
  final double waterReach;

  @override
  void paint(Canvas canvas, BackdropContext ctx) {
    final size = ctx.size;
    if (size.isEmpty || strength <= 0) return;
    final palette = ctx.palette;
    final waterline = (ctx.manifest ?? kPlaceholderSkylineManifest).waterline;
    final cover = coverFit(size);

    // Map the normalized art waterline + reaches into screen space through the
    // SAME cover-fit the plate/ocean use, so the band tracks the painted horizon
    // at any viewport aspect.
    final waterY = cover.top + waterline * cover.height;
    final topY = waterY - skyReach * cover.height;
    final botY = waterY + waterReach * cover.height;

    final cool = Color.lerp(palette.hazeSmog, palette.skyHorizonCool, coolMix)!;
    // Lift the cool smog toward the pale cloud-top so the band reads as a
    // bright fog line (aerial perspective dissolves the far bases), not a dark
    // veil that just muddies the midground.
    final haze = Color.lerp(cool, palette.cloudLit, paleLift.clamp(0.0, 1.0))!;
    final a = strength.clamp(0.0, 1.0);
    // Peak at the waterline; transparent at both reaches. Stops are placed by
    // where the waterline falls between top/bot so the peak stays pinned on the
    // horizon even though the up/down reaches differ.
    final peak = ((waterY - topY) / (botY - topY)).clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTRB(0, topY, size.width, botY),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, topY),
          Offset(0, botY),
          [
            haze.withValues(alpha: 0),
            haze.withValues(alpha: a),
            haze.withValues(alpha: 0),
          ],
          [0.0, peak, 1.0],
        ),
    );
  }
}
