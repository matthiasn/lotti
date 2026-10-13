import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:lotti/features/companion/model/hand_shape.dart';
import 'package:lotti/features/companion/rig/paint_kit.dart';
import 'package:lotti/features/companion/rig/ribbon.dart';

/// Hands, drawn in a wrist-local frame: +x runs from the wrist to the
/// fingertips, -y is the thumb side. A finger's curl foreshortens and turns
/// it a little, which reads as bending toward the palm in a flat style.

/// Knuckle y, proximal length, distal length, width; index first.
const _fingers = [
  (-4.6, 6.6, 5.6, 4.0),
  (-1.5, 7.2, 6.0, 4.1),
  (1.6, 6.6, 5.4, 3.9),
  (4.5, 5.2, 4.4, 3.4),
];

/// Soft where the thumb grows out of the palm, firmer at the knuckle.
const thumbTension = [0.5, 0.45, 0.3, 0.5];

/// Half widths: the ball of the thumb, its base, the knuckle, the tip.
const thumbWidths = [4.4, 3.1, 2.2, 1.8];

/// The thumb's joints, from a root inside the palm through its base and
/// knuckle to the tip, swinging out with `thumbOut` and folding with `thumb`.
List<Offset> thumbSpine(HandShape h) {
  final ta = -0.25 - 1.15 * h.thumbOut;
  const base = Offset(2.5, -5);
  final l1 = 6.0 * (1 - 0.35 * h.thumb);
  final l2 = 5.0 * (1 - 0.6 * h.thumb);
  final knuckle = base + Offset(l1 * math.cos(ta), l1 * math.sin(ta));
  final a2 = ta + 0.25 + h.thumb * 0.9;
  return [
    const Offset(6, -1.2),
    base,
    knuckle,
    knuckle + Offset(l2 * math.cos(a2), l2 * math.sin(a2)),
  ];
}

void _finger(
  Canvas canvas,
  (double, double, double, double) f,
  double curl,
  double spread, {
  required bool outline,
  required Color skin,
  required Color deep,
}) {
  final (y0, l1, l2, w) = f;
  final a1 = spread + curl * 0.35;
  final vis1 = l1 * (1 - 0.55 * curl);
  final vis2 = l2 * (1 - 0.9 * curl);
  final p0 = Offset(10 - curl * 1.5, y0);
  final p1 = p0 + Offset(vis1 * math.cos(a1), vis1 * math.sin(a1));
  final a2 = a1 + curl * 0.6;
  final l = math.max(0.1, vis2);
  final p2 = p1 + Offset(l * math.cos(a2), l * math.sin(a2));
  if (outline) {
    final c = deep.withValues(alpha: 0.9);
    fillPath(canvas, tapered(p0, p1, w + 1.1, w + 0.9), c);
    if (vis2 > 0.4) {
      fillPath(canvas, tapered(p1, p2, w + 0.9, w * 0.85 + 0.9), c);
    }
  } else {
    fillPath(canvas, tapered(p0, p1, w, w * 0.95), skin);
    if (vis2 > 0.4) {
      fillPath(canvas, tapered(p1, p2, w * 0.95, w * 0.85), skin);
    }
  }
}

Path _palm() => Path()
  ..moveTo(-2, -4.6)
  ..cubicTo(2, -6.6, 9, -7.2, 11.5, -5.6)
  ..cubicTo(13.2, -2, 13.2, 3, 11.5, 6)
  ..cubicTo(8, 7.4, 2, 6.4, -2, 4.6)
  ..close();

/// Draws a hand of shape [h] at the canvas origin, in [skin] with a [deep]
/// rim. Every outline goes first and every fill over it, so the hand reads as
/// one body with only its outer rim dark; the thumb is one ribbon grown out of
/// the palm, never a stick hinged onto it.
void drawHand(
  Canvas canvas,
  HandShape h, {
  required Color skin,
  required Color deep,
}) {
  final curls = h.fingerCurls;
  // Pinky first, index on top.
  final order = [3, 2, 1, 0];
  final spine = thumbSpine(h);
  for (final outline in [true, false]) {
    for (final i in order) {
      final spread = (_fingers[i].$1 / 4.7) * 0.22 * h.spread;
      _finger(
        canvas,
        _fingers[i],
        curls[i],
        spread,
        outline: outline,
        skin: skin,
        deep: deep,
      );
    }
    if (outline) {
      fillPath(
        canvas,
        ribbonPath(
          spine,
          [for (final w in thumbWidths) w + 0.5],
          0.5,
          3,
          tension: thumbTension,
        ),
        deep.withValues(alpha: 0.9),
      );
    }
  }
  fillPath(canvas, _palm(), skin);
  fillPath(
    canvas,
    ribbonPath(spine, thumbWidths, 0, 3, tension: thumbTension),
    skin,
  );
  // The thumb's top joint is outlined where it lies over the hand, fading
  // in from nothing at the knuckle, so its base never shows a seam.
  final a = ribbonCentre(spine, 2, thumbTension).point;
  final b = ribbonCentre(spine, 2.45, thumbTension).point;
  canvas.drawPath(
    ribbonPath(
      spine,
      [for (final w in thumbWidths) w * 0.92],
      2,
      3,
      tension: thumbTension,
      capStart: false,
    ),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..strokeJoin = StrokeJoin.round
      ..shader = ui.Gradient.linear(a, b, [
        deep.withValues(alpha: 0),
        deep.withValues(alpha: 0.8),
      ]),
  );
}
