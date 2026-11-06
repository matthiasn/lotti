import 'dart:ui';

import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/rig/paint_kit.dart';
import 'package:lotti/features/companion/rig/ribbon.dart';
import 'package:lotti/features/companion/rig/rig_frame.dart';
import 'package:lotti/features/companion/rig/trousers_painter.dart';

/// The aunt's boiler suit above the legs, none of it Lotti's or the
/// grandpa's: one piece in the trousers' colours, zipped from an open
/// utility collar to a belt, with a flapped chest pocket and short sleeves
/// turned up above the elbow. Its legs are the shared trousers
/// (`trousers_painter.dart`), so the suit is one colour head to toe.

/// The buckle's brushed metal.
const _buckle = Color(0xFFC9C3B6);

/// The suit's body, its zip, pocket and collar, then the seat and the belt.
void drawAuntOutfit(Canvas canvas, RigFrame f, CompanionLook look) {
  final c = look.palette;
  final t = f.torso;
  final suit = tuckedTopPath(f);
  fillPath(canvas, suit, c.trousers);
  canvas
    ..save()
    ..clipPath(suit);
  fillPath(
    canvas,
    ellipse(t(50, -60), 26, 80),
    c.trousersShade.withValues(alpha: 0.6),
  );
  fillPath(
    canvas,
    ellipse(t(-40, -80), 10, 40),
    c.trousersLight.withValues(alpha: 0.5),
  );
  // The zip, from the collar's V to the belt.
  strokePath(
    canvas,
    Path()
      ..moveToPoint(t(0, -98))
      ..lineToPoint(t(0, -36)),
    c.trousersShade,
    1.6,
  );
  fillPath(
    canvas,
    roundedRect(t(0, -96).dx - 1.6, t(0, -96).dy, 3.2, 5, 1),
    _buckle,
  );
  // The chest pocket and its flap.
  final pocket = Path()
    ..moveToPoint(t(12, -84))
    ..lineToPoint(t(30, -84))
    ..lineToPoint(t(30, -66))
    ..lineToPoint(t(12, -66))
    ..close();
  strokePath(canvas, pocket, c.trousersShade, 1.2);
  fillPath(
    canvas,
    Path()
      ..moveToPoint(t(11, -86))
      ..lineToPoint(t(31, -86))
      ..lineToPoint(t(30, -79))
      ..lineToPoint(t(12, -79))
      ..close(),
    c.trousersShade,
  );
  canvas.restore();
  _collar(canvas, f, c);
  drawTrouserTop(canvas, f, c);
  _belt(canvas, f, c);
}

/// The open collar: two wide points laid back from the zip's top.
void _collar(Canvas canvas, RigFrame f, CompanionPalette c) {
  final t = f.torso;
  for (final s in [-1.0, 1.0]) {
    final wing = Path()
      ..moveToPoint(t(0, -97))
      ..lineToPoint(t(s * 15, -113))
      ..lineToPoint(t(s * 27, -110))
      ..lineToPoint(t(s * 14, -92))
      ..close();
    fillPath(canvas, wing, c.trousersLight);
    strokePath(canvas, wing, c.trousersShade, 1);
  }
}

/// The belt over the waistband, buckled in the middle.
void _belt(Canvas canvas, RigFrame f, CompanionPalette c) {
  final t = f.torso;
  final belt = Path()
    ..moveToPoint(t(-38.4, -37))
    ..lineToPoint(t(38.4, -37))
    ..lineToPoint(t(38.8, -27))
    ..lineToPoint(t(-38.8, -27))
    ..close();
  fillPath(canvas, belt, c.belt);
  final b = t(0, -32);
  final buckle = roundedRect(b.dx - 6, b.dy - 5.5, 12, 11, 2);
  strokePath(canvas, buckle, _buckle, 2);
}

/// A short sleeve along [spine], the arm's joints: from the shoulder to
/// above the elbow, its end turned up in a cuff.
void drawShortSleeve(
  Canvas canvas,
  List<Offset> spine,
  int side,
  CompanionPalette c, {
  required List<double> tension,
}) {
  const widths = [11.6, 10.8, 9.4, 8.0];
  const end = 1.62;
  const cuff = 1.46;
  fillPath(
    canvas,
    ribbonPath(spine, widths, 0, end, tension: tension, capEnd: false),
    c.trousers,
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
    c.trousersShade.withValues(alpha: side > 0 ? 0.45 : 0.25),
  );
  final band = ribbonPath(
    spine,
    [for (final w in widths) w + 1.6],
    cuff,
    end,
    tension: tension,
    capStart: false,
    capEnd: false,
  );
  fillPath(canvas, band, c.trousersLight);
  strokePath(canvas, band, c.trousersShade, 1);
}
