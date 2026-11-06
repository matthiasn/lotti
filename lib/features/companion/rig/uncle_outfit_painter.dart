import 'dart:ui';

import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/rig/paint_kit.dart';
import 'package:lotti/features/companion/rig/ribbon.dart';
import 'package:lotti/features/companion/rig/rig_frame.dart';
import 'package:lotti/features/companion/rig/trousers_painter.dart';

/// The uncle's clothes above the legs, none of them anyone else's: a bomber
/// jacket worn open over a crew-neck tee, its collar, cuffs and hem ribbed,
/// the sleeves to the wrist, and over-ear headphones resting round his neck.
/// His chinos are the shared trousers (`trousers_painter.dart`), turned up.

/// The tee: shoulders to the hip, untucked, its crew neck ribbed.
Path teePath(RigFrame f) {
  final t = f.torso;
  return Path()
    ..moveToPoint(t(-16, -112))
    ..lineToPoint(t(16, -112))
    ..lineToPoint(t(32, -100))
    ..lineToPoint(t(32, 6))
    ..lineToPoint(t(-32, 6))
    ..lineToPoint(t(-32, -100))
    ..close();
}

/// One open front of the jacket on side [side] (-1 left, +1 right): from
/// the shoulder, which rises with its arm, down to the hip, its inner edge
/// leaving the tee showing down the middle.
Path jacketPanelPath(RigFrame f, int side) {
  final t = f.torso;
  final s = side.toDouble();
  final lift = side < 0 ? f.pose.left.lift : f.pose.right.lift;
  return Path()
    ..moveToPoint(t(s * 15, -112))
    ..curve(
      t(s * 28, -114 - lift),
      t(s * 40, -113 - lift),
      t(s * 47, -108 - lift),
    )
    ..curve(t(s * 52, -100), t(s * 49, -86), t(s * 46, -76))
    ..curve(t(s * 44, -50), t(s * 46, -20), t(s * 44, 4))
    ..lineToPoint(t(s * 12, 4))
    ..curve(t(s * 11, -40), t(s * 12, -90), t(s * 15, -112))
    ..close();
}

/// The seat under it all, the tee, the jacket's fronts with their ribbed
/// hem, the collar, and the headphones.
void drawUncleOutfit(Canvas canvas, RigFrame f, CompanionLook look) {
  final c = look.palette;
  final t = f.torso;
  drawTrouserTop(canvas, f, c);
  fillPath(canvas, teePath(f), c.shirt);
  strokePath(
    canvas,
    Path()
      ..moveToPoint(t(-15, -111))
      ..curve(t(-8, -104), t(8, -104), t(15, -111)),
    c.shirtShade,
    2.4,
  );
  for (final side in [-1, 1]) {
    final s = side.toDouble();
    final panel = jacketPanelPath(f, side);
    fillPath(canvas, panel, c.jacket);
    canvas
      ..save()
      ..clipPath(panel);
    fillPath(
      canvas,
      ellipse(t(s * 52, -40), 20, 80),
      c.jacketShade.withValues(alpha: side > 0 ? 0.6 : 0.3),
    );
    fillPath(
      canvas,
      ellipse(t(s * 30, -96), 10, 12),
      c.jacketLight.withValues(alpha: 0.6),
    );
    canvas.restore();
    // The open zip along the inner edge.
    strokePath(
      canvas,
      Path()
        ..moveToPoint(t(s * 15, -110))
        ..curve(t(s * 12, -90), t(s * 11, -40), t(s * 12, 2)),
      c.jacketLight,
      1.4,
    );
    _ribBand(canvas, c, [
      t(s * 12, 0),
      t(s * 44.5, 0),
      t(s * 43, 12),
      t(s * 13, 12),
    ]);
    _ribBand(canvas, c, [
      t(s * 6, -104),
      t(s * 17, -116),
      t(s * 23, -112),
      t(s * 13, -100),
    ]);
  }
  _headphones(canvas, f, c);
}

/// A ribbed band: [corners] filled in the rib colour, crossed by fine ribs.
void _ribBand(Canvas canvas, CompanionPalette c, List<Offset> corners) {
  final band = Path()..addPolygon(corners, true);
  fillPath(canvas, band, c.rib);
  canvas
    ..save()
    ..clipPath(band);
  final a = corners[0];
  final b = corners[1];
  final d = corners[3] - corners[0];
  for (var k = 1; k < 12; k++) {
    final p = Offset.lerp(a, b, k / 12)!;
    strokePath(
      canvas,
      Path()
        ..moveToPoint(p)
        ..lineToPoint(p + d),
      c.jacketShade.withValues(alpha: 0.35),
      0.8,
    );
  }
  canvas.restore();
}

/// Over-ear headphones resting round the neck: a cup on each collarbone,
/// the band rising from each behind the neck.
void _headphones(Canvas canvas, RigFrame f, CompanionPalette c) {
  final t = f.torso;
  final cushion = Color.lerp(c.headphones, const Color(0xFF000000), 0.55)!;
  for (final s in [-1.0, 1.0]) {
    strokePath(
      canvas,
      Path()
        ..moveToPoint(t(s * 24, -120))
        ..curve(t(s * 23, -128), t(s * 16, -132), t(s * 10, -133)),
      c.headphones,
      3.4,
    );
    final cup = t(s * 24, -110);
    fillPath(canvas, ellipse(cup, 9.5, 11.5), cushion);
    fillPath(canvas, ellipse(cup + Offset(s * 2.5, 0), 7.5, 10), c.headphones);
    fillPath(
      canvas,
      ellipse(cup + Offset(s * 1.5, -3.5), 2.8, 3),
      const Color(0x55FFFFFF),
    );
  }
}

/// A bomber sleeve along [spine], the arm's joints: from the shoulder down
/// to the wrist, gathered there in a ribbed cuff.
void drawJacketSleeve(
  Canvas canvas,
  List<Offset> spine,
  int side,
  CompanionPalette c, {
  required List<double> tension,
}) {
  const widths = [12.6, 11.8, 10.4, 8.6];
  const end = 2.9;
  const cuff = 2.74;
  fillPath(
    canvas,
    ribbonPath(spine, widths, 0, cuff, tension: tension, capEnd: false),
    c.jacket,
  );
  fillPath(
    canvas,
    ribbonPath(
      spine,
      widths,
      0.4,
      cuff,
      tension: tension,
      back: [for (final w in widths) -w * 0.45],
      capStart: false,
      capEnd: false,
    ),
    c.jacketShade.withValues(alpha: side > 0 ? 0.5 : 0.3),
  );
  final band = ribbonPath(
    spine,
    [for (final w in widths) w * 0.82],
    cuff,
    end,
    tension: tension,
    capStart: false,
    capEnd: false,
  );
  fillPath(canvas, band, c.rib);
  strokePath(canvas, band, c.jacketShade.withValues(alpha: 0.5), 0.8);
}
