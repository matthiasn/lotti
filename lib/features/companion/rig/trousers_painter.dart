import 'dart:ui';

import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/rig/paint_kit.dart';
import 'package:lotti/features/companion/rig/rig_frame.dart';

/// Trousers, for every character who wears them: the legs from the hips to
/// the shoes, and the seat and waistband, which the torso's garments tuck
/// into. The legs hang from the pelvis, which a bounce of joy never moves;
/// the seat rides on the torso frame, a little lifted by a bounce, and
/// overlaps the legs' tops by far more than a bounce lifts it, so no gap
/// opens between them.

/// The trouser legs, straight from the hip to the hem — the cloth hides the
/// knee, so a leg reads straight even where the bare one bends a little —
/// with a crease down each front, and the brogues over their hems.
void drawTrouserLegs(Canvas canvas, RigFrame f, CompanionLook look) {
  final c = look.palette;
  for (final s in [-1, 1]) {
    final hip = f.hip(s);
    final hem = f.ankle(s) + const Offset(0, 2);
    final leg = tapered(hip, hem, 30, 25);
    fillPath(canvas, leg, c.trousers);
    // The leg turned from the light is in shade.
    if (s > 0) {
      fillPath(canvas, leg, c.trousersShade.withValues(alpha: 0.35));
    }
    strokePath(
      canvas,
      Path()
        ..moveToPoint(hip + const Offset(0, 14))
        ..lineToPoint(hem - const Offset(0, 6)),
      c.trousersLight.withValues(alpha: 0.6),
      1.2,
    );
    _brogue(canvas, c, f.ankle(s), s);
  }
}

/// A brogue: a lace-up with a toe cap, its edge punched with holes.
void _brogue(Canvas canvas, CompanionPalette c, Offset ankle, int s) {
  canvas
    ..save()
    ..translate(ankle.dx + s * 3, ankle.dy + 4)
    ..scale(s * 1.15, 1.15);
  fillPath(
    canvas,
    Path()
      ..moveTo(-15, 8)
      ..cubicTo(-17, 14, 0, 15, 22, 13)
      ..cubicTo(27, 12, 27, 7, 23, 6)
      ..close(),
    c.sole,
  );
  final upper = Path()
    ..moveTo(-14, 8.5)
    ..cubicTo(-15, -5, -6, -9, 2, -7)
    ..cubicTo(10, -5, 16, 0, 22, 3)
    ..cubicTo(25, 5, 24, 8.5, 21, 8.5)
    ..close();
  fillPath(canvas, upper, c.shoe);
  fillPath(
    canvas,
    Path()
      ..moveTo(-14, 8.5)
      ..cubicTo(-15, -5, -8, -9, -4, -8)
      ..cubicTo(-9, -2, -9, 4, -6, 8.5)
      ..close(),
    c.shoeShade,
  );
  // The toe cap's seam and its punched holes.
  strokePath(
    canvas,
    Path()
      ..moveTo(12, -1)
      ..cubicTo(13, 3, 13, 6, 12, 8.5),
    c.shoeShade,
    1.2,
  );
  for (final (x, y) in const [(14.5, 0.5), (15.2, 3.5), (15.2, 6.5)]) {
    fillCircle(canvas, Offset(x, y), 0.7, c.shoeShade);
  }
  // The laces across the instep.
  for (final y in const [-5.0, -2.5, 0.0]) {
    strokePath(
      canvas,
      Path()
        ..moveTo(0, y)
        ..lineTo(6, y + 1.5),
      c.shoeShade,
      1.1,
    );
  }
  canvas.restore();
}

/// The seat and the waistband, in the torso frame: drawn over the shirt's
/// tucked hem, with two pleats falling from the band.
void drawTrouserTop(Canvas canvas, RigFrame f, CompanionPalette c) {
  final t = f.torso;
  final seat = Path()
    ..moveToPoint(t(-38, -36))
    ..lineToPoint(t(38, -36))
    ..curve(t(40, -24), t(40, -8), t(37, 6))
    ..curve(t(35, 16), t(32, 24), t(28, 30))
    ..curve(t(18, 32), t(6, 30), t(0, 24))
    ..curve(t(-6, 30), t(-18, 32), t(-28, 30))
    ..curve(t(-32, 24), t(-35, 16), t(-37, 6))
    ..curve(t(-40, -8), t(-40, -24), t(-38, -36))
    ..close();
  fillPath(canvas, seat, c.trousers);
  canvas
    ..save()
    ..clipPath(seat);
  fillPath(
    canvas,
    ellipse(t(38, 0), 14, 40),
    c.trousersShade.withValues(alpha: 0.5),
  );
  canvas.restore();
  final band = Path()
    ..moveToPoint(t(-38, -36))
    ..lineToPoint(t(38, -36))
    ..lineToPoint(t(38.6, -28))
    ..lineToPoint(t(-38.6, -28))
    ..close();
  fillPath(canvas, band, c.trousersShade);
  for (final x in const [-13.0, 13.0]) {
    strokePath(
      canvas,
      Path()
        ..moveToPoint(t(x, -28))
        ..lineToPoint(t(x * 1.1, -8)),
      c.trousersShade.withValues(alpha: 0.7),
      1.2,
    );
  }
}
