import 'dart:math' as math;
import 'dart:ui';

import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/rig/paint_kit.dart';
import 'package:lotti/features/companion/rig/ribbon.dart';
import 'package:lotti/features/companion/rig/rig_frame.dart';

/// An animal's tail: one ribbon from behind the hip, out past the dress and
/// curling up beside it, drawn before the legs and the dress so it grows
/// from behind them.
///
/// It swings with `CompanionPose.tail`: each joint turns a little further
/// than the one before it, so the swing travels to the tip like a swish,
/// not a stick pivoting on the hip. The cat's is thin with faint rings and
/// a dark tip; the red panda's is thick, bushy and ringed.

/// The tail's joints in the torso frame, at rest.
const _catJoints = [
  Offset(12, 8),
  Offset(56, 26),
  Offset(90, 2),
  Offset(96, -50),
  Offset(80, -94),
];

const _pandaJoints = [
  Offset(12, 10),
  Offset(58, 34),
  Offset(98, 14),
  Offset(110, -36),
  Offset(96, -84),
];

/// Half widths per joint.
const catTailWidths = [5.0, 6.0, 5.6, 5.0, 3.8];
const pandaTailWidths = [9.0, 15.0, 18.0, 17.0, 12.0];

const _tension = [0.5, 0.5, 0.5, 0.5, 0.5];

/// The tail's joints in world space for the pose in [f].
List<Offset> tailSpine(RigFrame f, CompanionSpecies species) {
  final rest = species == CompanionSpecies.redPanda ? _pandaJoints : _catJoints;
  final base = rest.first;
  final swing = f.pose.tail;
  return [
    for (final (i, p) in rest.indexed)
      f.torso.of(base + _rotate(p - base, -swing * 0.07 * i)),
  ];
}

Offset _rotate(Offset p, double a) => Offset(
  p.dx * math.cos(a) - p.dy * math.sin(a),
  p.dx * math.sin(a) + p.dy * math.cos(a),
);

void drawTail(Canvas canvas, RigFrame f, CompanionLook look) {
  if (!look.species.isAnimal) return;
  final c = look.palette;
  final panda = look.species == CompanionSpecies.redPanda;
  final spine = tailSpine(f, look.species);
  final widths = panda ? pandaTailWidths : catTailWidths;
  final last = (spine.length - 1).toDouble();
  final tail = ribbonPath(spine, widths, 0, last, tension: _tension);
  fillPath(canvas, tail, c.tailColor);
  canvas
    ..save()
    ..clipPath(tail);
  // Shade along the underside.
  fillPath(
    canvas,
    ribbonPath(
      spine,
      widths,
      0,
      last,
      tension: _tension,
      back: [for (final w in widths) -w * 0.4],
    ),
    c.skinShade.withValues(alpha: 0.6),
  );
  // Rings across the tail: bold on the red panda, faint on the cat.
  final rings = panda ? 5 : 4;
  for (var k = 0; k < rings; k++) {
    final start = 0.7 + k * (last - 0.7) / rings;
    fillPath(
      canvas,
      ribbonPath(
        spine,
        [for (final w in widths) w + 2],
        start,
        start + (panda ? 0.32 : 0.16),
        tension: _tension,
        capStart: false,
        capEnd: false,
      ),
      c.tailRingColor.withValues(alpha: panda ? 0.95 : 0.6),
    );
  }
  if (!panda) {
    // A dark tip.
    fillPath(
      canvas,
      ribbonPath(
        spine,
        [for (final w in widths) w + 2],
        last - 0.35,
        last,
        tension: _tension,
        capStart: false,
      ),
      c.furMarkColor,
    );
  } else {
    // Fur along the edge, so the tail reads as bushy, not as a tube.
    for (final s in ribbonEdges(
      spine,
      widths,
      0.4,
      last,
      tension: _tension,
    ).indexed.where((e) => e.$1.isOdd).map((e) => e.$2)) {
      final out = s.front - s.centre;
      strokePath(
        canvas,
        Path()
          ..moveToPoint(s.front - out * 0.25)
          ..lineToPoint(s.front + s.tangent * 3),
        c.skinLight.withValues(alpha: 0.35),
        1.2,
      );
    }
  }
  canvas.restore();
}
