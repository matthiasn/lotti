import 'dart:math' as math;
import 'dart:ui';

import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/rig/arm_solver.dart';
import 'package:lotti/features/companion/rig/hand_painter.dart';
import 'package:lotti/features/companion/rig/paint_kit.dart';
import 'package:lotti/features/companion/rig/ribbon.dart';
import 'package:lotti/features/companion/rig/rig_frame.dart';

/// The body below the head: legs and shoes (an animal's paws), the neck, the
/// dress with its cardigan and scarf, and the arms with their sleeves and
/// hands.

const handScale = 1.45;

/// Soft through the shoulder, firmer at the elbow so a bend still reads.
const armTension = [0.5, 0.45, 0.28, 0.5];

void drawLegs(Canvas canvas, RigFrame f, CompanionLook look) {
  final c = look.palette;
  for (final s in [-1, 1]) {
    final hip = f.hip(s);
    final ankle = f.ankle(s);
    final knee = f.knee(s);
    if (look.species.isAnimal) {
      fillPath(canvas, tapered(hip, knee, 19, 16), c.limbDeepColor);
      fillPath(canvas, tapered(knee, ankle, 16, 13), c.limbColor);
      fillCircle(canvas, knee, 7.8, c.limbColor);
      _paw(canvas, c, ankle, s);
    } else {
      fillPath(canvas, tapered(hip, knee, 17, 14), c.skinShade);
      fillPath(canvas, tapered(knee, ankle, 14, 11), c.skin);
      fillCircle(canvas, knee, 6.8, c.skin);
      _shoe(canvas, c, ankle, s);
    }
  }
}

/// An animal's foot: a soft round paw, toes marked by two short creases.
void _paw(Canvas canvas, CompanionPalette c, Offset ankle, int s) {
  canvas
    ..save()
    ..translate(ankle.dx + s * 4, ankle.dy + 7)
    ..scale(s.toDouble(), 1);
  final paw = Path()
    ..moveTo(-11, 9)
    ..cubicTo(-14, -2, -6, -9, 4, -7)
    ..cubicTo(14, -6, 21, 2, 19, 9)
    ..cubicTo(10, 12, -2, 12, -11, 9)
    ..close();
  fillPath(canvas, paw, c.pawColor);
  canvas
    ..save()
    ..clipPath(paw);
  fillPath(
    canvas,
    ellipse(const Offset(2, 13), 22, 6),
    c.limbDeepColor.withValues(alpha: 0.3),
  );
  canvas.restore();
  for (final x in [7.0, 13.0]) {
    strokePath(
      canvas,
      Path()
        ..moveTo(x, 3)
        ..lineTo(x + 0.6, 9),
      c.limbDeepColor.withValues(alpha: 0.55),
      1.1,
    );
  }
  canvas.restore();
}

/// A Mary Jane: a strap over the instep, a low block heel.
void _shoe(Canvas canvas, CompanionPalette c, Offset ankle, int s) {
  canvas
    ..save()
    ..translate(ankle.dx + s * 3, ankle.dy + 4)
    ..scale(s * 1.15, 1.15);
  fillPath(
    canvas,
    Path()
      ..moveTo(-15, 8)
      ..cubicTo(-17, 14, 0, 15.5, 20, 13)
      ..cubicTo(26, 12, 26, 7, 22, 6)
      ..close()
      ..addRect(const Rect.fromLTWH(-15, 8, 9, 7)),
    c.sole,
  );
  fillPath(
    canvas,
    Path()
      ..moveTo(-14, 8.5)
      ..cubicTo(-15, -4, -8, -9, -1, -8)
      ..cubicTo(8, -6, 14, -1, 21, 3)
      ..cubicTo(24, 5, 23, 8.5, 20, 8.5)
      ..close(),
    c.shoe,
  );
  fillPath(
    canvas,
    Path()
      ..moveTo(-14, 8.5)
      ..cubicTo(-15, -4, -8, -9, -4, -8)
      ..cubicTo(-9, -2, -9, 4, -6, 8.5)
      ..close(),
    c.shoeShade,
  );
  fillPath(
    canvas,
    Path()
      ..moveTo(-6, -4)
      ..cubicTo(0, -1, 6, 0, 11, 2)
      ..cubicTo(6, 3, 0, 2, -5, -1)
      ..close(),
    c.skin,
  );
  strokePath(
    canvas,
    Path()
      ..moveTo(-3, -7)
      ..lineTo(2, 1),
    c.shoe,
    2.6,
  );
  fillCircle(canvas, const Offset(1.5, 0.5), 1.3, const Color(0xFFD9B859));
  canvas.restore();
}

void drawNeck(Canvas canvas, RigFrame f, CompanionLook look) {
  final c = look.palette;
  // An animal's neck is fur, and its chin sits a little lower on a bigger
  // head.
  final chin = 36 * look.species.headScale;
  fillPath(
    canvas,
    tapered(
      f.headPivot + const Offset(0, -14),
      f.neckBase + const Offset(0, 4),
      21,
      24,
    ),
    c.skin,
  );
  fillPath(canvas, ellipse(f.neckBase + const Offset(0, 6), 19, 10), c.skin);
  // The chin's shadow.
  fillPath(
    canvas,
    ellipse(f.head(0, chin) + const Offset(0, 4), 11, 4.5),
    c.skinDeep.withValues(alpha: 0.35),
  );
}

Path _dressPath(RigFrame f) {
  final t = f.torso;
  final p = f.pose;
  final ll = p.left.lift;
  final lr = p.right.lift;
  final lag = p.hemLag;
  return Path()
    ..moveToPoint(t(-15, -112))
    ..curve(t(-11, -103), t(-6, -101), t(0, -101))
    ..curve(t(6, -101), t(11, -103), t(15, -112))
    ..curve(t(28, -114 - lr), t(40, -113 - lr), t(46, -108 - lr))
    ..curve(t(51, -100), t(45, -86), t(41, -76))
    ..curve(t(37, -60), t(34, -44), t(35, -30))
    ..curve(t(36, -5), t(44, 15), t(47 + lag * 0.4, 30))
    ..curve(t(52 + lag * 0.6, 55), t(57 + lag, 80), t(60 + lag, 96))
    ..curve(t(40 + lag, 101), t(20 + lag, 103), t(lag * 0.8, 103))
    ..curve(t(-20 + lag, 103), t(-40 + lag, 101), t(-60 + lag, 96))
    ..curve(t(-57 + lag, 80), t(-52 + lag * 0.6, 55), t(-47 + lag * 0.4, 30))
    ..curve(t(-44, 15), t(-36, -5), t(-35, -30))
    ..curve(t(-34, -44), t(-37, -60), t(-41, -76))
    ..curve(t(-45, -86), t(-51, -100), t(-46, -108 - ll))
    ..curve(t(-40, -113 - ll), t(-28, -114 - ll), t(-15, -112))
    ..close();
}

/// The dress, then the cardigan, the scarf and the beads over it.
void drawDress(Canvas canvas, RigFrame f, CompanionLook look) {
  final c = look.palette;
  final t = f.torso;
  final dress = _dressPath(f);
  fillPath(canvas, dress, c.dress);
  canvas
    ..save()
    ..clipPath(dress);
  fillPath(
    canvas,
    ellipse(t(58, 0), 34, 140),
    c.dressShade.withValues(alpha: 0.75),
  );
  fillPath(
    canvas,
    ellipse(t(-50, -40), 14, 70),
    c.dressLight.withValues(alpha: 0.5),
  );
  // A soft fold falling from the hip.
  final lag = f.pose.hemLag;
  strokePath(
    canvas,
    Path()
      ..moveToPoint(t(-20, 20))
      ..curve(t(-24, 50), t(-28 + lag * 0.5, 75), t(-30 + lag, 98)),
    c.dressShade.withValues(alpha: 0.6),
    2.2,
  );
  canvas.restore();
  _cardigan(canvas, f, c);
  _scarf(canvas, f, c);
  if (look.beads) _beads(canvas, f, c);
}

Path _cardiganPanel(RigFrame f, int side) {
  final t = f.torso;
  final s = side.toDouble();
  final lift = side < 0 ? f.pose.left.lift : f.pose.right.lift;
  return Path()
    ..moveToPoint(t(s * 15, -112))
    ..curve(
      t(s * 28, -114 - lift),
      t(s * 40, -113 - lift),
      t(s * 46, -108 - lift),
    )
    ..curve(t(s * 51, -100), t(s * 45, -86), t(s * 41, -76))
    ..curve(t(s * 37, -60), t(s * 34, -44), t(s * 35, -30))
    ..curve(t(s * 36, -5), t(s * 42, 12), t(s * 46, 26))
    ..lineToPoint(t(s * 14, 30))
    // The open edge: a V from the neckline, widening to the hem.
    ..curve(t(s * 9, -10), t(s * 7, -60), t(s * 15, -112))
    ..close();
}

void _cardigan(Canvas canvas, RigFrame f, CompanionPalette c) {
  final t = f.torso;
  for (final side in [-1, 1]) {
    final s = side.toDouble();
    final panel = _cardiganPanel(f, side);
    fillPath(canvas, panel, c.cardigan);
    canvas
      ..save()
      ..clipPath(panel);
    fillPath(
      canvas,
      ellipse(t(s * 56, -30), 24, 90),
      c.cardiganShade.withValues(alpha: side > 0 ? 0.55 : 0.25),
    );
    final rib = Path()
      ..moveToPoint(t(s * 15, -112))
      ..curve(t(s * 7, -60), t(s * 9, -10), t(s * 14, 30));
    strokePath(canvas, rib, c.cardiganLight.withValues(alpha: 0.8), 5);
    strokePath(canvas, rib, c.cardiganShade.withValues(alpha: 0.7), 1.2);
    strokePath(
      canvas,
      Path()
        ..moveToPoint(t(s * 46, 26))
        ..lineToPoint(t(s * 14, 30)),
      c.cardiganShade.withValues(alpha: 0.8),
      3,
    );
    canvas.restore();
  }
  for (final y in [-70.0, -44.0, -18.0]) {
    final b = t(-11, y);
    fillCircle(canvas, b, 2.6, c.cardiganShade);
    fillCircle(canvas, b + const Offset(-0.5, -0.5), 1.4, c.cardiganLight);
  }
}

/// A small silk scarf knotted at the side of the neck.
void _scarf(Canvas canvas, RigFrame f, CompanionPalette c) {
  final t = f.torso;
  fillPath(
    canvas,
    Path()
      ..moveToPoint(t(-19, -116))
      ..curve(t(-8, -104), t(8, -104), t(19, -116))
      ..curve(t(12, -98), t(-10, -97), t(-19, -116))
      ..close(),
    c.scarf,
  );
  final knot = t(-16, -102);
  fillCircle(canvas, knot, 5, c.scarf);
  fillPath(
    canvas,
    Path()
      ..moveTo(knot.dx - 2, knot.dy + 3)
      ..curve(t(-24, -90), t(-22, -82), t(-18, -78))
      ..curve(t(-16, -84), t(-13, -92), t(-11, -98))
      ..close(),
    c.scarf,
  );
  fillPath(
    canvas,
    Path()
      ..moveTo(knot.dx + 2, knot.dy + 3)
      ..curve(t(-8, -92), t(-6, -86), t(-7, -80))
      ..curve(t(-11, -86), t(-15, -92), t(-17, -98))
      ..close(),
    c.scarf.withValues(alpha: 0.85),
  );
  for (final (dx, dy) in const [
    (-12.0, -110.0),
    (-4.0, -106.0),
    (6.0, -108.0),
    (13.0, -112.0),
    (-20.0, -86.0),
    (-9.0, -88.0),
  ]) {
    fillCircle(canvas, t(dx, dy), 1.1, c.scarfDot);
  }
}

/// Two strands of big beads at the neckline, the longer in front.
void _beads(Canvas canvas, RigFrame f, CompanionPalette c) {
  for (final (n, dip, r) in const [(9, -86.0, 4.6), (7, -94.0, 3.6)]) {
    for (var i = 0; i < n; i++) {
      final u = i / (n - 1);
      final b = f.torso(
        -26 + 52 * u,
        dip + (-104 - dip) * math.pow(2 * u - 1, 2),
      );
      fillCircle(canvas, b, r, c.beads);
      fillCircle(
        canvas,
        b + Offset(-r * 0.3, -r * 0.35),
        r * 0.35,
        c.beadsLight.withValues(alpha: 0.8),
      );
    }
  }
}

/// One arm: the bare arm as one ribbon, the hand at the wrist, and the
/// cardigan's sleeve pushed up short of the elbow.
void drawArm(
  Canvas canvas,
  RigFrame f,
  CompanionLook look,
  ArmPose arm,
  int side,
) {
  final c = look.palette;
  final spine = f.armSpine(arm, side);
  final elbow = spine[2];
  final wrist = spine[3];
  final fur = look.species.isAnimal;
  final limb = fur ? c.limbColor : c.skin;
  final deep = fur ? c.limbDeepColor : c.skinDeep;
  fillPath(
    canvas,
    ribbonPath(spine, [8.7, 8.3, 7.4, 6.3], 1, 3, tension: armTension),
    deep.withValues(alpha: 0.55),
  );
  fillPath(
    canvas,
    ribbonPath(spine, [8.0, 7.6, 6.7, 5.6], 1, 3, tension: armTension),
    limb,
  );
  // A forearm drawn short points at the camera, so its hand is that much
  // nearer and a little bigger.
  final near =
      1.0 + 0.16 * math.max(0, 1.0 - (elbow - wrist).distance / forearm);
  final gloved = look.glove && side > 0;
  canvas
    ..save()
    ..translate(wrist.dx, wrist.dy)
    ..rotate(arm.handAngle + f.pose.lean)
    ..scale(handScale * near, handScale * near * (side < 0 ? -1 : 1));
  drawHand(
    canvas,
    arm.hand,
    skin: gloved ? c.glove : (fur ? c.pawColor : c.skin),
    deep: gloved ? c.gloveDeep : deep,
  );
  canvas.restore();
  _sleeve(canvas, spine, side, c);
}

void _sleeve(Canvas canvas, List<Offset> spine, int side, CompanionPalette c) {
  const widths = [11.6, 10.6, 9.2, 8.0];
  const end = 1.8;
  fillPath(
    canvas,
    ribbonPath(spine, widths, 0, end, tension: armTension, capEnd: false),
    c.cardigan,
  );
  // Shade along the underside, then the cuff.
  fillPath(
    canvas,
    ribbonPath(
      spine,
      widths,
      0.4,
      end,
      tension: armTension,
      back: [for (final w in widths) -w * 0.45],
      capStart: false,
      capEnd: false,
    ),
    c.cardiganShade.withValues(alpha: side > 0 ? 0.45 : 0.25),
  );
  const cuff = end - 0.12;
  final band = [for (final w in widths) w + 1.0];
  fillPath(
    canvas,
    ribbonPath(
      spine,
      band,
      cuff,
      end,
      tension: armTension,
      capStart: false,
      capEnd: false,
    ),
    c.cardiganShade,
  );
  final smp = ribbonEdges(spine, band, cuff, end, tension: armTension);
  final f0 = smp.first.front;
  final b0 = smp.first.back;
  final f1 = smp.last.front;
  final b1 = smp.last.back;
  for (var k = 1; k < 7; k++) {
    final u = k / 7;
    strokePath(
      canvas,
      Path()
        ..moveToPoint(Offset.lerp(f0, b0, u)!)
        ..lineToPoint(Offset.lerp(f1, b1, u)!),
      c.cardiganLight.withValues(alpha: 0.6),
      1,
    );
  }
}
