import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/rig/face_painter.dart';
import 'package:lotti/features/companion/rig/paint_kit.dart';

/// An animal's head, in the same head-local units as the grandmother's
/// (origin at the face's centre, y down), so her eyes, brows, mouth and
/// everything she wears on her head sit on it unchanged.
///
/// Where she has hair, the cat and the red panda have ears and fur: a head
/// with fluffed cheeks, the species' markings, a pale muzzle, a nose, a
/// mouth that shows only its opening, and whiskers. The ears trail the head
/// with the hair's lag and flick now and then (`CompanionPose.earFlick`).

/// One side of the head's outline, from the crown round the cheek to the
/// chin, for the right side; the left mirrors it.
const _catSide = [
  Offset(0, -57),
  Offset(26, -54),
  Offset(43, -41),
  Offset(51, -20),
  Offset(53, -2),
  Offset(60, 9),
  Offset(52, 14),
  Offset(57, 22),
  Offset(45, 28),
  Offset(25, 38),
];

const _pandaSide = [
  Offset(0, -56),
  Offset(29, -53),
  Offset(47, -40),
  Offset(56, -19),
  Offset(59, 0),
  Offset(69, 11),
  Offset(59, 16),
  Offset(66, 26),
  Offset(51, 31),
  Offset(28, 41),
];

/// Moves a point of the head with [yaw]: the far side narrows, the chin
/// turns with the face, as the grandmother's face path does.
Offset _turned(Offset p, double yaw) {
  final reach = (p.dx.abs() / 55).clamp(0.0, 1.0);
  return p + Offset(yaw * (3 - 5 * reach), 0);
}

/// The head's outline for [species], turned by [yaw].
Path animalHeadPath(CompanionSpecies species, double yaw) {
  final side = species == CompanionSpecies.redPanda ? _pandaSide : _catSide;
  final chin = species == CompanionSpecies.redPanda ? 44.0 : 41.0;
  return smoothClosed([
    for (final p in side) _turned(p, yaw),
    _turned(Offset(0, chin), yaw),
    for (final p in side.reversed.skip(1)) _turned(Offset(-p.dx, p.dy), yaw),
  ], 0.2);
}

/// An ear's three corners for [side]: inner base, tip, outer base.
List<Offset> _earCorners(CompanionSpecies species, int side) {
  final s = side.toDouble();
  return species == CompanionSpecies.redPanda
      ? [Offset(s * 19, -50), Offset(s * 49, -80), Offset(s * 59, -30)]
      : [Offset(s * 15, -53), Offset(s * 45, -95), Offset(s * 49, -32)];
}

/// The ears, drawn before the head so their bases tuck behind it.
void drawEars(Canvas canvas, CompanionLook look, CompanionPose pose) {
  final c = look.palette;
  final panda = look.species == CompanionSpecies.redPanda;
  for (final side in [-1, 1]) {
    final s = side.toDouble();
    final corners = _earCorners(look.species, side);
    final base = (corners.first + corners.last) / 2;
    // A flick turns the ear outward about its base; the lag trails the tip.
    final flick = side * pose.earFlick > 0 ? pose.earFlick.abs() : 0.0;
    final turn = s * (0.32 * flick) + pose.headYaw * 0.04;
    final lag = pose.hairLag * 0.5;
    final pts = [
      for (final (i, p) in corners.indexed)
        base + _rotate(p - base, turn) + (i == 1 ? lag : Offset.zero),
    ];
    Path ear(double inset) {
      final centre = (pts[0] + pts[1] + pts[2]) / 3;
      final q = [for (final p in pts) Offset.lerp(p, centre, inset)!];
      return Path()
        ..moveToPoint(q[0])
        ..quadraticBezierTo(
          (q[0].dx + q[1].dx) / 2 - s * (panda ? 9 : 4),
          (q[0].dy + q[1].dy) / 2,
          q[1].dx,
          q[1].dy,
        )
        ..quadraticBezierTo(
          (q[1].dx + q[2].dx) / 2 + s * (panda ? 14 : 6),
          (q[1].dy + q[2].dy) / 2,
          q[2].dx,
          q[2].dy,
        )
        ..close();
    }

    if (panda) {
      // White fur rims the whole ear; the rust back shows inside it, and
      // the dark inner fur deepest.
      fillPath(canvas, ear(0), c.muzzleColor);
      fillPath(canvas, ear(0.18), c.skin);
      fillPath(canvas, ear(0.4), c.earInner ?? c.skinDeep);
    } else {
      fillPath(canvas, ear(0), c.skin);
      fillPath(canvas, ear(0.3), c.earInner ?? c.skinLight);
      // A tuft of pale fur at the ear's opening.
      for (var k = 0; k < 3; k++) {
        final from = Offset.lerp(pts[0], pts[2], 0.3 + k * 0.18)!;
        strokePath(
          canvas,
          Path()
            ..moveToPoint(from)
            ..lineToPoint(Offset.lerp(from, pts[1], 0.35)!),
          c.muzzleColor.withValues(alpha: 0.75),
          1,
        );
      }
    }
  }
}

Offset _rotate(Offset p, double a) => Offset(
  p.dx * math.cos(a) - p.dy * math.sin(a),
  p.dx * math.sin(a) + p.dy * math.cos(a),
);

/// The head and the face on it, up to (not including) what is worn on it.
void drawAnimalFace(Canvas canvas, CompanionLook look, CompanionPose p) {
  final c = look.palette;
  final panda = look.species == CompanionSpecies.redPanda;
  final yaw = p.headYaw;
  final fx = yaw * 6.5;
  final fy = p.headPitch * 3.5;
  final head = animalHeadPath(look.species, yaw);
  fillPath(canvas, head, c.skin);
  canvas
    ..save()
    ..clipPath(head);
  // Form shade on the far side and a lighter crown.
  fillPath(
    canvas,
    ellipse(Offset(44 - yaw * 6, 8), 24, 62),
    c.skinShade.withValues(alpha: 0.45),
  );
  fillPath(
    canvas,
    ellipse(Offset(-14 + fx * 0.5, -40), 26, 14),
    c.skinLight.withValues(alpha: 0.4),
  );
  if (panda) {
    _pandaMask(canvas, c, fx, fy);
  } else {
    _tabbyStripes(canvas, c, fx, fy);
  }
  _muzzle(canvas, c, fx, fy, panda: panda);
  for (final s in [-1, 1]) {
    final at = Offset(s * 27 + yaw * 5, 13 + fy * 2);
    canvas.drawCircle(
      at,
      9,
      Paint()
        ..shader = ui.Gradient.radial(at, 9, [
          Color.fromRGBO(226, 120, 128, look.blush),
          const Color.fromRGBO(226, 120, 128, 0),
        ]),
    );
  }
  canvas.restore();

  for (final s in [-1, 1]) {
    drawEye(
      canvas,
      c,
      Offset(s * 20 + fx, -7 + fy),
      s,
      p.blink,
      p.squint,
      p.gaze,
      irisRadius: panda ? 8.6 : 8.4,
      slit: !panda,
      lashes: false,
    );
    drawBrow(
      canvas,
      c,
      Offset(s * 20 + fx, -28 + fy * 1.2),
      s,
      p.browRaise,
      p.browTilt,
    );
  }
  _nose(canvas, c, fx * 1.25, 9 + fy * 1.1, panda: panda);
  canvas
    ..save()
    ..translate(fx * 1.1, 24 + fy)
    ..scale(1.05);
  drawMouth(canvas, c, 0, 0, p.mouth, p.smile);
  canvas.restore();
  _whiskers(canvas, c, fx, fy, panda: panda);
  _crownTuft(canvas, c, p.hairLag, yaw);
}

/// A silver tabby's markings: the "M" on the forehead and two stripes on
/// each cheek.
void _tabbyStripes(Canvas canvas, CompanionPalette c, double fx, double fy) {
  final mark = c.furMarkColor.withValues(alpha: 0.75);
  for (final (x, top, bottom, w) in const [
    (-13.0, -60.0, -41.0, 3.6),
    (0.0, -62.0, -39.0, 4.2),
    (13.0, -60.0, -41.0, 3.6),
  ]) {
    canvas.drawPath(
      tapered(
        Offset(x + fx * 0.6, top + fy),
        Offset(x * 0.8 + fx * 0.7, bottom + fy),
        w,
        0.8,
      ),
      Paint()..color = mark,
    );
  }
  for (final s in [-1, 1]) {
    for (final (y, len) in const [(-3.0, 13.0), (8.0, 11.0)]) {
      canvas.drawPath(
        tapered(
          Offset(s * 56 + fx * 0.3, y + fy),
          Offset(s * (56 - len) + fx * 0.4, y + 2 + fy),
          3.6,
          0.8,
        ),
        Paint()..color = mark,
      );
    }
  }
}

/// A red panda's face: white cheeks and the dark tear marks that run from
/// each eye to the corner of the mouth.
void _pandaMask(Canvas canvas, CompanionPalette c, double fx, double fy) {
  for (final s in [-1, 1]) {
    fillPath(
      canvas,
      ellipse(Offset(s * 47 + fx * 0.4, 19 + fy), 22, 17),
      c.muzzleColor,
    );
    // The white spot above each eye, under the brow that moves on it.
    fillPath(
      canvas,
      ellipse(Offset(s * 22 + fx, -29 + fy), 11, 7),
      c.muzzleColor,
    );
    canvas.drawPath(
      tapered(
        Offset(s * 15 + fx, 2 + fy),
        Offset(s * 21 + fx, 31 + fy),
        7.5,
        5,
      ),
      Paint()..color = c.furMarkColor,
    );
  }
}

/// The pale fur round the mouth and down the chin.
void _muzzle(
  Canvas canvas,
  CompanionPalette c,
  double fx,
  double fy, {
  required bool panda,
}) {
  final x = fx * 1.1;
  final muzzle = Path()
    ..addPath(
      ellipse(Offset(x - 9, 20 + fy), panda ? 15 : 12.5, panda ? 12 : 10),
      Offset.zero,
    )
    ..addPath(
      ellipse(Offset(x + 9, 20 + fy), panda ? 15 : 12.5, panda ? 12 : 10),
      Offset.zero,
    )
    ..addPath(ellipse(Offset(x, 31 + fy), 13, 10), Offset.zero)
    ..addPath(ellipse(Offset(x, 6 + fy), 6, 8), Offset.zero);
  fillPath(canvas, muzzle, c.muzzleColor);
}

/// A rounded triangle of a nose, and the line down to the mouth.
void _nose(
  Canvas canvas,
  CompanionPalette c,
  double x,
  double y, {
  required bool panda,
}) {
  final w = panda ? 7.5 : 5.5;
  final h = panda ? 6.0 : 4.6;
  final nose = c.nose ?? c.skinDeep;
  strokePath(
    canvas,
    Path()
      ..moveTo(x, y + h * 0.6)
      ..lineTo(x, y + 9),
    c.mouthIn.withValues(alpha: 0.75),
    1.1,
  );
  fillPath(
    canvas,
    Path()
      ..moveTo(x - w, y - h * 0.5)
      ..cubicTo(
        x - w * 0.4,
        y - h * 0.9,
        x + w * 0.4,
        y - h * 0.9,
        x + w,
        y - h * 0.5,
      )
      ..cubicTo(x + w * 0.8, y + h * 0.2, x + 1.5, y + h * 0.8, x, y + h * 0.8)
      ..cubicTo(
        x - 1.5,
        y + h * 0.8,
        x - w * 0.8,
        y + h * 0.2,
        x - w,
        y - h * 0.5,
      )
      ..close(),
    nose,
  );
  fillPath(
    canvas,
    ellipse(Offset(x - w * 0.3, y - h * 0.35), w * 0.32, h * 0.18),
    const Color(0x66FFFFFF),
  );
}

/// Three whiskers a side, out from the muzzle.
void _whiskers(
  Canvas canvas,
  CompanionPalette c,
  double fx,
  double fy, {
  required bool panda,
}) {
  final colour = (c.whisker ?? c.muzzleColor).withValues(alpha: 0.9);
  final reach = panda ? 30.0 : 40.0;
  for (final s in [-1, 1]) {
    for (final (k, dy) in const [(0, -5.0), (1, 0.0), (2, 5.0)]) {
      final from = Offset(s * 17 + fx * 1.1, 20 + k * 2.5 + fy);
      strokePath(
        canvas,
        Path()
          ..moveToPoint(from)
          ..quadraticBezierTo(
            from.dx + s * reach * 0.55,
            from.dy + dy * 0.5 - 2,
            from.dx + s * reach,
            from.dy + dy,
          ),
        colour,
        0.9,
      );
    }
  }
}

/// A few hairs standing up on the crown: the fur the lag swings, the way her
/// wisps do.
void _crownTuft(Canvas canvas, CompanionPalette c, Offset lag, double yaw) {
  for (final (dx, h) in const [(-5.0, 8.0), (1.0, 11.0), (6.0, 7.0)]) {
    final from = Offset(dx + yaw * 3, -54);
    strokePath(
      canvas,
      Path()
        ..moveToPoint(from)
        ..quadraticBezierTo(
          from.dx + lag.dx * 0.5,
          from.dy - h * 0.6,
          from.dx + 2 + lag.dx * 1.2,
          from.dy - h + lag.dy * 0.6,
        ),
      c.skin,
      2.4,
    );
  }
}
