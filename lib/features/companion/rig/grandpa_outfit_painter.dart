import 'dart:ui';

import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/rig/paint_kit.dart';
import 'package:lotti/features/companion/rig/ribbon.dart';
import 'package:lotti/features/companion/rig/rig_frame.dart';
import 'package:lotti/features/companion/rig/trousers_painter.dart';

/// The grandpa's clothes above the legs, none of them Lotti's: a collared
/// shirt tucked into pleated trousers, braces over it, a bow tie at the
/// collar, and sleeves rolled to the forearm. All in the torso frame, so
/// they lean, breathe and bounce with him.

/// The shirt, then the trousers' top over its hem, the braces, the collar
/// and the bow tie.
void drawGrandpaOutfit(Canvas canvas, RigFrame f, CompanionLook look) {
  final c = look.palette;
  final t = f.torso;
  final shirt = tuckedTopPath(f, broad: true);
  fillPath(canvas, shirt, c.shirt);
  canvas
    ..save()
    ..clipPath(shirt);
  fillPath(
    canvas,
    ellipse(t(50, -60), 26, 80),
    c.shirtShade.withValues(alpha: 0.6),
  );
  fillPath(
    canvas,
    ellipse(t(-40, -80), 10, 40),
    c.shirtLight.withValues(alpha: 0.5),
  );
  // The placket, its buttons, and a breast pocket.
  strokePath(
    canvas,
    Path()
      ..moveToPoint(t(0, -104))
      ..lineToPoint(t(0, -30)),
    c.shirtShade,
    1.2,
  );
  for (final y in const [-90.0, -72.0, -54.0]) {
    fillCircle(canvas, t(2.5, y), 1.8, c.shirtLight);
    strokePath(canvas, circle(t(2.5, y), 1.8), c.shirtShade, 0.6);
  }
  strokePath(
    canvas,
    Path()
      ..moveToPoint(t(14, -86))
      ..lineToPoint(t(14, -72))
      ..curve(t(14, -69), t(30, -69), t(30, -72))
      ..lineToPoint(t(30, -86)),
    c.shirtShade,
    1.1,
  );
  canvas.restore();
  drawTrouserTop(canvas, f, c);
  _braces(canvas, f, c);
  _collar(canvas, f, c);
  _bowTie(canvas, f, c);
}

/// Two straps from the waistband over the chest to the shoulders, each
/// buttoned on at the band.
void _braces(Canvas canvas, RigFrame f, CompanionPalette c) {
  final t = f.torso;
  final clip = Color.lerp(c.braces, const Color(0xFF000000), 0.35)!;
  for (final s in [-1.0, 1.0]) {
    strokePath(
      canvas,
      Path()
        ..moveToPoint(t(s * 17, -32))
        ..curve(t(s * 18, -60), t(s * 21, -90), t(s * 25, -113)),
      c.braces,
      6,
      cap: StrokeCap.butt,
    );
    fillPath(
      canvas,
      roundedRect(t(s * 17, -33).dx - 4, t(s * 17, -33).dy - 3, 8, 6, 2),
      clip,
    );
  }
}

/// The collar's two points, turned down either side of the bow tie.
void _collar(Canvas canvas, RigFrame f, CompanionPalette c) {
  final t = f.torso;
  for (final s in [-1.0, 1.0]) {
    final wing = Path()
      ..moveToPoint(t(s * 1, -106))
      ..lineToPoint(t(s * 16, -116))
      ..lineToPoint(t(s * 19, -104))
      ..lineToPoint(t(s * 9, -95))
      ..close();
    fillPath(canvas, wing, c.shirtLight);
    strokePath(canvas, wing, c.shirtShade, 1);
  }
}

/// A bow tie at the collar: two wings and the knot between them.
void _bowTie(Canvas canvas, RigFrame f, CompanionPalette c) {
  final t = f.torso;
  for (final s in [-1.0, 1.0]) {
    final wing = Path()
      ..moveToPoint(t(0, -104))
      ..lineToPoint(t(s * 14, -110))
      ..curve(t(s * 16, -106), t(s * 16, -101), t(s * 14, -97))
      ..close();
    fillPath(canvas, wing, c.bowTie);
    strokePath(canvas, wing, c.bowTieShade, 0.9);
  }
  fillPath(canvas, ellipse(t(0, -104), 3.6, 4.2), c.bowTieShade);
}

/// A shirt sleeve rolled to the forearm along [spine], the arm's joints:
/// the sleeve from the shoulder past the elbow, then the roll, a band a
/// little wider than the sleeve.
void drawShirtSleeve(
  Canvas canvas,
  List<Offset> spine,
  int side,
  CompanionPalette c, {
  required List<double> tension,
}) {
  const widths = [11.0, 10.2, 8.8, 7.6];
  const end = 2.35;
  const roll = 2.12;
  fillPath(
    canvas,
    ribbonPath(spine, widths, 0, end, tension: tension, capEnd: false),
    c.shirt,
  );
  fillPath(
    canvas,
    ribbonPath(
      spine,
      widths,
      0.4,
      roll,
      tension: tension,
      back: [for (final w in widths) -w * 0.45],
      capStart: false,
      capEnd: false,
    ),
    c.shirtShade.withValues(alpha: side > 0 ? 0.45 : 0.25),
  );
  final band = [for (final w in widths) w + 2.4];
  final cuff = ribbonPath(
    spine,
    band,
    roll,
    end,
    tension: tension,
    capStart: false,
    capEnd: false,
  );
  fillPath(canvas, cuff, c.shirtLight);
  strokePath(canvas, cuff, c.shirtShade, 1);
}
