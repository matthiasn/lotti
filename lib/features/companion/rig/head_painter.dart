import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/rig/animal_head_painter.dart';
import 'package:lotti/features/companion/rig/face_painter.dart';
import 'package:lotti/features/companion/rig/grandpa_head_painter.dart';
import 'package:lotti/features/companion/rig/hair_styles_painter.dart';
import 'package:lotti/features/companion/rig/paint_kit.dart';
import 'package:lotti/features/companion/rig/rig_frame.dart';

/// The head, in its own frame: the face and its shading, the features, the
/// glasses, the earrings, the hair over it and what she wears on top. An
/// animal's face comes from `animal_head_painter.dart`; what is worn on it is
/// shared.

void _enterHead(Canvas canvas, RigFrame f, CompanionLook look) {
  final k = look.species.headScale;
  canvas
    ..save()
    ..translate(f.head.origin.dx, f.head.origin.dy)
    ..rotate(f.head.angle)
    ..scale(k);
}

/// What sits behind the head and everything else: her bun and the cap of
/// hair, or an animal's ears.
void drawBackOfHead(Canvas canvas, RigFrame f, CompanionLook look) {
  _enterHead(canvas, f, look);
  if (look.species.isAnimal) {
    drawEars(canvas, look, f.pose);
  } else {
    drawBackHair(canvas, look.palette, f.pose.hairLag, look.hairStyle);
  }
  canvas.restore();
}

/// The face's outline, turned by [yaw]. [jaw] squares it: 0 is the soft,
/// rounded chin Lotti has, 1 a man's squarer jaw, wider at its corners and
/// a little lower at the chin.
Path facePath(double yaw, {double jaw = 0}) {
  double l(double soft, double square) => soft + (square - soft) * jaw;
  return Path()
    ..moveTo(0, -58)
    ..cubicTo(26, -58, 45 - yaw * 2, -40, 45 - yaw * 2, -8)
    ..cubicTo(
      45 - yaw * 2,
      l(16, 28),
      l(26, 39) + yaw,
      l(38, 44),
      yaw * 3,
      l(40, 45),
    )
    ..cubicTo(
      l(-26, -39) + yaw,
      l(38, 44),
      -45 - yaw * 2,
      l(16, 28),
      -45 - yaw * 2,
      -8,
    )
    ..cubicTo(-45 - yaw * 2, -40, -26, -58, 0, -58)
    ..close();
}

/// The face, the features and everything worn on the head.
void drawHead(Canvas canvas, RigFrame f, CompanionLook look) {
  final c = look.palette;
  final p = f.pose;
  final yaw = p.headYaw;
  final pitch = p.headPitch;
  _enterHead(canvas, f, look);
  final fx = yaw * 6.5;
  final fy = pitch * 3.5;
  if (look.species.isAnimal) {
    drawAnimalFace(canvas, look, p);
  } else {
    _humanFace(canvas, look, p);
  }
  if (look.sunglasses) {
    _sunglasses(canvas, c, fx, fy, yaw);
  } else if (look.readingGlasses) {
    _readingGlasses(canvas, c, fx, fy, yaw);
  } else if (look.glasses) {
    _glasses(canvas, c, fx, fy, yaw);
  }
  if (look.earring != EarringKind.none) {
    for (final s in [-1, 1]) {
      _earring(canvas, c, Offset(s * (44 - yaw * 2 * s), 15), look.earring);
    }
  }
  if (!look.species.isAnimal) {
    drawFrontHair(canvas, c, p.hairLag, yaw, look.hairStyle);
  }
  if (look.headband) _headband(canvas, c, yaw);
  // A hat sits on the hair, as high and as wide as the hair needs; an
  // animal's head wears it as the plain head does.
  final hair = look.species.isAnimal ? CompanionHairStyle.bun : look.hairStyle;
  if (look.beret) seatHat(canvas, hair, yaw, () => _beret(canvas, c, yaw));
  if (look.flatCap) {
    seatHat(canvas, hair, yaw, () => drawFlatCap(canvas, c, yaw));
  }
  if (look.beanie) seatHat(canvas, hair, yaw, () => _beanie(canvas, c, yaw));
  canvas.restore();
}

/// A human face: its shading, the features, and for an older face the laugh
/// lines; for a younger one fuller brows; for a bearded character, the beard
/// under the mouth and the moustache over it.
void _humanFace(Canvas canvas, CompanionLook look, CompanionPose p) {
  final c = look.palette;
  final yaw = p.headYaw;
  final pitch = p.headPitch;
  for (final s in [-1, 1]) {
    fillPath(
      canvas,
      ellipse(Offset(s * (44 - yaw * 2 * s), 0), 6.5, 9),
      c.skinShade,
    );
  }
  final masculine = look.species.masculine;
  final face = facePath(yaw, jaw: masculine ? 1 : 0);
  fillPath(canvas, face, c.skin);
  canvas
    ..save()
    ..clipPath(face);
  // Form shade on the far side of the face and under the jaw; a man's
  // cheeks carry no blush.
  fillPath(
    canvas,
    ellipse(Offset(38 - yaw * 6, 6), 22, 60),
    c.skinShade.withValues(alpha: 0.38),
  );
  drawForeheadShadow(canvas, c, p.hairLag, yaw, look.hairStyle);
  if (masculine) {
    // The jaw as bone: a band of shade along its lower edge and under the
    // chin, and the hollow under each cheekbone.
    fillPath(
      canvas,
      ellipse(Offset(yaw * 3, 47), 44, 9),
      c.skinDeep.withValues(alpha: 0.35),
    );
    for (final s in [-1, 1]) {
      strokePath(
        canvas,
        Path()
          ..moveTo(s * 36 + yaw * 4, 6)
          ..quadraticBezierTo(s * 31 + yaw * 4, 16, s * 33 + yaw * 4, 24),
        c.skinShade.withValues(alpha: 0.55),
        2.4,
      );
    }
  }
  for (final s in masculine ? const <int>[] : const [-1, 1]) {
    final at = Offset(s * 25 + yaw * 5, 11 + pitch * 2);
    canvas.drawCircle(
      at,
      9,
      Paint()
        ..shader = ui.Gradient.radial(at, 9, [
          Color.fromRGBO(217, 107, 102, look.blush),
          const Color.fromRGBO(217, 107, 102, 0),
        ]),
    );
  }
  canvas.restore();

  final fx = yaw * 6.5;
  final fy = pitch * 3.5;
  for (final s in [-1, 1]) {
    drawEye(
      canvas,
      c,
      Offset(s * 19 + fx, -6 + fy),
      s,
      p.blinkOf(s),
      p.squint,
      p.gaze,
      lashes: look.species.lashes,
      // A man's eye is narrower, its iris smaller, its lash line lighter.
      open: masculine ? 0.68 : 1,
      irisRadius: masculine ? 6.4 : 7.6,
      lashLine: masculine ? 1.3 : 2.1,
    );
    // A man's brow sits lower, nearer the eye, heavy and nearly straight.
    drawBrow(
      canvas,
      c,
      Offset(s * 20 + fx, (masculine ? -22 : -27) + fy * 1.2),
      s,
      p.browRaise + s * p.browSkew,
      p.browTilt,
      fullness: (look.species.aged ? 1 : 1.5) + (masculine ? 0.7 : 0),
      arch: masculine ? 0.25 : 1,
    );
  }
  drawNose(canvas, c, fx * 1.25, 8 + fy * 1.1, broad: masculine);
  if (look.species.aged) _laughLines(canvas, c, fx, fy, p.smile);
  if (look.species.bearded) drawBeard(canvas, c, yaw);
  if (look.species.stubble) drawStubble(canvas, c, fx, fy, yaw);
  canvas
    ..save()
    ..translate(fx * 1.1, 22 + fy)
    ..scale(1.25);
  // A man's lips are thin: the mouth's line, not a woman's full lips.
  drawMouth(
    canvas,
    c,
    0,
    0,
    p.mouth,
    p.smile,
    skew: p.smileSkew,
    lipWeight: masculine ? 0.4 : 1,
  );
  canvas.restore();
  if (look.species.bearded) drawMoustache(canvas, c, fx, fy);
}

/// Soft creases beside the mouth and under the eyes: a face that has smiled
/// for ninety years. They deepen a little with the smile.
void _laughLines(
  Canvas canvas,
  CompanionPalette c,
  double fx,
  double fy,
  double smile,
) {
  for (final s in [-1, 1]) {
    strokePath(
      canvas,
      Path()
        ..moveTo(fx * 1.1 + s * 16, 14 + fy)
        ..cubicTo(
          fx * 1.1 + s * 21,
          20 + fy,
          fx * 1.1 + s * 21,
          27 + fy,
          fx * 1.1 + s * 17,
          32 + fy,
        ),
      c.skinDeep.withValues(alpha: 0.28 + 0.2 * smile),
      1.2,
    );
    strokePath(
      canvas,
      Path()
        ..moveTo(fx + s * 12, 6 + fy)
        ..cubicTo(
          fx + s * 17,
          7.5 + fy,
          fx + s * 22,
          6.5 + fy,
          fx + s * 27,
          3 + fy,
        ),
      c.skinDeep.withValues(alpha: 0.2),
      1.2,
    );
  }
}

void _templeArm(
  Canvas canvas,
  Color color,
  double ax,
  double cy,
  int s,
  double fx,
  double yaw,
  double width,
  double rise,
) {
  strokePath(
    canvas,
    Path()
      ..moveTo(ax, cy - rise)
      ..cubicTo(
        ax + s * 8,
        cy - rise - 3,
        s * (40 - yaw * 2 * s) + fx * 0.3,
        cy - rise - 5,
        s * (44 - yaw * 2 * s),
        cy - rise - 2,
      ),
    color,
    width,
  );
}

/// Round tortoiseshell frames, their arms back to the ears.
void _glasses(
  Canvas canvas,
  CompanionPalette c,
  double fx,
  double fy,
  double yaw,
) {
  const r = 14.5;
  for (final s in [-1, 1]) {
    final centre = Offset(s * 19 + fx, -5 + fy);
    fillCircle(canvas, centre, r - 1.5, const Color(0x1AFFFFFF));
    fillCircle(
      canvas,
      centre + const Offset(-4, -5),
      5,
      const Color(0x29FFFFFF),
    );
    strokePath(canvas, circle(centre, r), c.glasses, 3);
    strokePath(
      canvas,
      circle(centre, r - 1.2),
      c.glassesLight.withValues(alpha: 0.6),
      0.9,
    );
    _templeArm(
      canvas,
      c.glasses,
      centre.dx + s * r,
      centre.dy,
      s,
      fx,
      yaw,
      2.4,
      1,
    );
  }
  strokePath(
    canvas,
    Path()
      ..moveTo(-19 + fx + r, -7 + fy)
      ..cubicTo(-6 + fx, -11 + fy, 6 + fx, -11 + fy, 19 + fx - r, -7 + fy),
    c.glasses,
    2.8,
  );
}

/// Half-moon reading frames, low on the nose: a straight top edge under the
/// eyes' centres and a round rim below, their arms back to the ears.
void _readingGlasses(
  Canvas canvas,
  CompanionPalette c,
  double fx,
  double fy,
  double yaw,
) {
  const r = 13.0;
  for (final s in [-1, 1]) {
    final centre = Offset(s * 19 + fx, 1 + fy);
    final lens = Path()
      ..moveTo(centre.dx - r, centre.dy)
      ..lineTo(centre.dx + r, centre.dy)
      ..arcTo(Rect.fromCircle(center: centre, radius: r), 0, math.pi, false)
      ..close();
    fillPath(canvas, lens, const Color(0x1AFFFFFF));
    strokePath(canvas, lens, c.glasses, 2.2);
    strokePath(
      canvas,
      arc(centre, r - 1.4, 0.4, 1.6),
      c.glassesLight.withValues(alpha: 0.7),
      0.9,
    );
    _templeArm(
      canvas,
      c.glasses,
      centre.dx + s * r,
      centre.dy,
      s,
      fx,
      yaw,
      1.8,
      -2,
    );
  }
  strokePath(
    canvas,
    Path()
      ..moveTo(-19 + fx + r, 1 + fy)
      ..cubicTo(-6 + fx, -3 + fy, 6 + fx, -3 + fy, 19 + fx - r, 1 + fy),
    c.glasses,
    2,
  );
}

/// Square frames with dark lenses, worn in place of the glasses.
void _sunglasses(
  Canvas canvas,
  CompanionPalette c,
  double fx,
  double fy,
  double yaw,
) {
  const w = 33.0;
  const h = 24.0;
  for (final s in [-1, 1]) {
    final cx = s * 19.5 + fx;
    final cy = -5 + fy;
    final x = cx - w / 2;
    final y = cy - h / 2;
    final lens = roundedRect(x, y, w, h, 5);
    fillPath(canvas, lens, c.lens.withValues(alpha: 0.93));
    strokePath(
      canvas,
      Path()
        ..moveTo(x + 4, y + h - 3)
        ..lineTo(x + w - 10, y + 3),
      const Color(0x29FFFFFF),
      4,
    );
    strokePath(canvas, lens, c.glasses, 4.6);
    _templeArm(canvas, c.glasses, cx + s * w / 2, cy, s, fx, yaw, 3.4, 4);
  }
  strokePath(
    canvas,
    Path()
      ..moveTo(-19.5 + fx + w / 2, -8 + fy)
      ..lineTo(19.5 + fx - w / 2, -8 + fy),
    c.glasses,
    4.2,
  );
}

/// A pearl on a short hook, a flat coloured disc, or a hoop.
void _earring(
  Canvas canvas,
  CompanionPalette c,
  Offset at,
  EarringKind kind,
) {
  strokePath(
    canvas,
    Path()
      ..moveTo(at.dx, at.dy - 6)
      ..lineTo(at.dx, at.dy - 1),
    const Color(0xFFD9B859),
    1,
  );
  if (kind == EarringKind.hoop) {
    strokePath(canvas, circle(at + const Offset(0, 6), 6), c.earring, 1.8);
    return;
  }
  if (kind == EarringKind.disc) {
    fillCircle(canvas, at + const Offset(0, 4), 5.2, c.earring);
    fillCircle(
      canvas,
      at + const Offset(-1.5, 2.5),
      1.6,
      const Color(0x80FFFFFF),
    );
    return;
  }
  fillCircle(canvas, at + const Offset(0, 3), 3.6, c.pearlShade);
  fillCircle(canvas, at + const Offset(-0.6, 2.4), 2.8, c.pearl);
  fillCircle(canvas, at + const Offset(-1.4, 1.4), 1, const Color(0xFFFFFFFF));
}

/// A wide band over the crown, behind the hairline, with a thin light
/// stripe along it.
void _headband(Canvas canvas, CompanionPalette c, double yaw) {
  final centre = Offset(yaw * 4, -16);
  strokePath(canvas, arc(centre, 50, 3.6, 5.82), c.headband, 9);
  strokePath(
    canvas,
    arc(centre, 52, 3.75, 5.67),
    const Color(0x55FFFFFF),
    1.4,
  );
}

/// A knitted beanie over the crown: a soft dome with ribs running up it,
/// its brim folded up over the brow, in the cap's colours.
void _beanie(Canvas canvas, CompanionPalette c, double yaw) {
  final x = yaw * 3;
  final dome = Path()
    ..moveTo(x - 52, -38)
    ..cubicTo(x - 56, -80, x - 24, -100, x, -100)
    ..cubicTo(x + 24, -100, x + 56, -80, x + 52, -38)
    ..close();
  fillPath(canvas, dome, c.cap);
  canvas
    ..save()
    ..clipPath(dome);
  for (var k = -4; k <= 4; k++) {
    strokePath(
      canvas,
      Path()
        ..moveTo(x + k * 11, -38)
        ..quadraticBezierTo(x + k * 9, -80, x + k * 3, -100),
      c.capShade.withValues(alpha: 0.6),
      1.2,
    );
  }
  canvas.restore();
  final brim = Path()
    ..moveTo(x - 53, -50)
    ..cubicTo(x - 20, -56, x + 20, -56, x + 53, -50)
    ..lineTo(x + 52, -34)
    ..cubicTo(x + 20, -40, x - 20, -40, x - 52, -34)
    ..close();
  fillPath(canvas, brim, c.capShade);
  strokePath(canvas, brim, Color.lerp(c.capShade, c.cap, 0.5)!, 1);
}

/// A red beret pulled down to the left, its stalk on top.
void _beret(Canvas canvas, CompanionPalette c, double yaw) {
  final x = yaw * 3;
  final hat = Path()
    ..moveTo(x - 54, -52)
    ..cubicTo(x - 56, -82, x - 10, -102, x + 36, -92)
    ..cubicTo(x + 60, -86, x + 64, -66, x + 50, -54)
    ..cubicTo(x + 20, -46, x - 20, -46, x - 54, -52)
    ..close();
  fillPath(canvas, hat, c.hat);
  canvas
    ..save()
    ..clipPath(hat)
    ..drawRect(
      Rect.fromLTWH(x - 60, -58, 130, 14),
      Paint()..color = c.hatShade.withValues(alpha: 0.7),
    );
  fillPath(
    canvas,
    ellipse(Offset(x + 48, -70), 22, 30),
    c.hatShade.withValues(alpha: 0.45),
  );
  canvas.restore();
  fillCircle(canvas, Offset(x + 4, -97), 3.2, c.hatShade);
}
