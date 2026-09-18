import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;
import 'package:lotti/features/plaza/ui/plaza_palette.dart';

/// One dark quad on the decal plane: [width] across and [length] along
/// [yaw], centred on ([x], [z]) in world metres, at [alpha] of the hour's
/// shadow colour. Pure geometry — the scene lays it on the ground.
@immutable
class ShadeQuad {
  const ShadeQuad({
    required this.x,
    required this.z,
    required this.width,
    required this.length,
    required this.yaw,
    required this.alpha,
  });

  final double x;
  final double z;
  final double width;
  final double length;

  /// Radians from +Z toward +X, the way the street's yaws are measured.
  final double yaw;
  final double alpha;
}

/// How much of the contact pad's density the cast streak carries. A shadow
/// thrown across open paving is lighter than the dark under the wall
/// itself, and the two overlap where they meet.
const shadeCastShare = 0.7;

/// The contact pad is this much larger than the caster's larger side, so
/// it shows past the wall's foot from every angle.
const shadeContactSpread = 1.25;

/// The cast streak is this much wider than the caster's larger side: the
/// softness of the mask eats the edge.
const shadeStreakSpread = 1.1;

/// The shade a [width] × [depth] × [height] volume standing at ([x], [z])
/// throws across the paving under [palette]'s sun.
///
/// There is no light in this scene and nothing casts anything: shade is
/// two soft dark quads on the ground. It is the one thing that makes an
/// unlit daylight city read as standing on its street rather than pasted
/// onto it, which is why the day palette carries a sun angle at all. An
/// hour with no shadow opacity, no sun, or a caster with no height throws
/// nothing at all.
///
/// Two quads, not one, because they do different jobs. The **contact** pad
/// sits on the footprint and is what says the building meets the ground —
/// it has to be there from every camera angle, including the one looking
/// straight down the sun. The **cast** streak runs away from the sun and is
/// what says where the sun is. One offset quad cannot be both: its falloff
/// peaks half a shadow-length out, leaving the wall's own foot at a third
/// of the density, which reads as a smudge on the paving rather than as
/// contact. A sign on two thin posts meets the ground at two thin posts: it
/// passes `contact: false` and gets the streak its panel throws and no pad,
/// or the pad would read as a slab of shade the structure does not have.
///
/// Both are square to the sun rather than to the caster: a facade turned
/// off-axis gets the larger of its two footprint sides, which at this
/// softness reads correctly and costs no solve.
List<ShadeQuad> shadeQuadsFor(
  PlazaPalette palette, {
  required double x,
  required double z,
  required double width,
  required double depth,
  required double height,
  bool contact = true,
}) {
  final alpha = palette.lights.shadowAlpha;
  final length = palette.sky.shadowLength(height);
  if (alpha <= 0 || length <= 0) return const [];
  // Away from the sun, along the ground.
  final cast = palette.sky.sunAzimuth + math.pi;
  final lateral = math.max(width, depth);
  return [
    if (contact)
      ShadeQuad(
        x: x,
        z: z,
        width: lateral * shadeContactSpread,
        length: lateral * shadeContactSpread,
        yaw: 0,
        alpha: alpha,
      ),
    ShadeQuad(
      x: x + math.sin(cast) * length / 2,
      z: z + math.cos(cast) * length / 2,
      width: lateral * shadeStreakSpread,
      length: lateral + length,
      yaw: cast,
      alpha: alpha * shadeCastShare,
    ),
  ];
}
