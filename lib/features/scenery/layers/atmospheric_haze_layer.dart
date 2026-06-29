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
    this.strength = 0.2,
    this.coolMix = 0.55,
    this.skyReach = 0.16,
    this.waterReach = 0.26,
  });

  /// Peak veil opacity at the waterline (0 = none).
  final double strength;

  /// 0 keeps the raw [BackdropPalette.hazeSmog]; 1 pulls the veil fully to
  /// [BackdropPalette.skyHorizonCool]. Blue-hour air-light is cool, so the
  /// default leans past halfway.
  final double coolMix;

  /// How far the veil bleeds UP into the sky above the waterline, as a fraction
  /// of the cover-fit art height (kept short — open sky is clear).
  final double skyReach;

  /// How far the veil bleeds DOWN into the near water below the waterline, as a
  /// fraction of art height (longer than [skyReach]: the lagoon surface carries
  /// the haze toward the viewer before the clear foreground takes over).
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

    final haze = Color.lerp(palette.hazeSmog, palette.skyHorizonCool, coolMix)!;
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
