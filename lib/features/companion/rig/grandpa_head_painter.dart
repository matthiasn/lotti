import 'dart:ui';

import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/rig/paint_kit.dart';

/// What the grandpa has on and about his face, in head-local units (origin
/// at the face's centre, y down; the face spans x ±45 and y -58..40): a
/// trimmed beard along the jaw, a moustache over the lip, both in his hair's
/// colour, and the flat cap of his market outfit.
///
/// The beard is painted under the mouth and the moustache over it, so
/// every mouth shape still opens and reads through them.

/// The beard's outline: from the sideburns down the jaw, a little fuller
/// than the face, round under the chin, and back up the cheeks. [yaw] turns
/// it with the head.
List<Offset> beardOutline(double yaw) => [
  Offset(-46 - yaw * 2, -8),
  Offset(-44 - yaw * 2, 14),
  Offset(-30 + yaw, 38),
  Offset(yaw * 3, 47),
  Offset(30 + yaw, 38),
  Offset(44 - yaw * 2, 14),
  Offset(46 - yaw * 2, -8),
  Offset(39 - yaw * 2, -6),
  Offset(32 + yaw * 3, 13),
  Offset(18 + yaw * 6, 16),
  Offset(yaw * 6.5, 15),
  Offset(-18 + yaw * 6, 16),
  Offset(-32 + yaw * 3, 13),
  Offset(-39 - yaw * 2, -6),
];

/// The trimmed beard, close and soft, short strokes for its grain.
void drawBeard(Canvas canvas, CompanionPalette c, double yaw) {
  final beard = smoothClosed(beardOutline(yaw), 0.2);
  fillPath(canvas, beard, c.hair);
  canvas
    ..save()
    ..clipPath(beard);
  // Shade under the jaw and on the far side.
  fillPath(
    canvas,
    ellipse(Offset(yaw * 3, 50), 40, 12),
    c.hairShade.withValues(alpha: 0.55),
  );
  fillPath(
    canvas,
    ellipse(Offset(42 - yaw * 4, 16), 12, 30),
    c.hairShade.withValues(alpha: 0.35),
  );
  for (var k = 0; k < 9; k++) {
    final x = -32.0 + k * 8 + yaw * 3;
    final y = 36.0 - (k - 4).abs() * 2;
    strokePath(
      canvas,
      Path()
        ..moveTo(x, y)
        ..lineTo(x + 1.5, y + 6),
      c.hairLight.withValues(alpha: 0.55),
      1,
    );
  }
  canvas.restore();
}

/// The moustache: two soft wings from under the nose, their tips at the
/// mouth's corners.
Path moustachePath(double fx, double fy) {
  final x = fx * 1.1;
  final y = 14 + fy;
  return Path()
    ..moveTo(x, y - 2)
    ..cubicTo(x + 8, y - 5, x + 16, y - 1, x + 18, y + 7)
    ..cubicTo(x + 12, y + 4, x + 6, y + 4, x, y + 3)
    ..cubicTo(x - 6, y + 4, x - 12, y + 4, x - 18, y + 7)
    ..cubicTo(x - 16, y - 1, x - 8, y - 5, x, y - 2)
    ..close();
}

void drawMoustache(Canvas canvas, CompanionPalette c, double fx, double fy) {
  final moustache = moustachePath(fx, fy);
  fillPath(canvas, moustache, c.hair);
  strokePath(canvas, moustache, c.hairShade.withValues(alpha: 0.6), 1);
  strokePath(
    canvas,
    Path()
      ..moveTo(fx * 1.1 - 10, 14 + fy)
      ..cubicTo(
        fx * 1.1 - 4,
        12 + fy,
        fx * 1.1 + 4,
        12 + fy,
        fx * 1.1 + 10,
        14 + fy,
      ),
    c.hairLight.withValues(alpha: 0.6),
    1,
  );
}

/// The flat cap's crown: low and rounded, pulled forward over the brow.
Path flatCapPath(double yaw) {
  final x = yaw * 3;
  return Path()
    ..moveTo(x - 54, -36)
    ..cubicTo(x - 58, -70, x - 26, -86, x + 6, -84)
    ..cubicTo(x + 40, -82, x + 60, -66, x + 55, -38)
    ..cubicTo(x + 30, -44, x - 30, -44, x - 54, -36)
    ..close();
}

/// The flat cap: its crown, a seam down the middle, the button on top and
/// the stiff peak jutting over the brow.
void drawFlatCap(Canvas canvas, CompanionPalette c, double yaw) {
  final x = yaw * 3;
  final crown = flatCapPath(yaw);
  fillPath(canvas, crown, c.cap);
  canvas
    ..save()
    ..clipPath(crown);
  fillPath(
    canvas,
    ellipse(Offset(x + 44, -58), 22, 30),
    c.capShade.withValues(alpha: 0.5),
  );
  canvas.restore();
  strokePath(
    canvas,
    Path()
      ..moveTo(x + 4, -84)
      ..cubicTo(x + 2, -70, x - 2, -56, x - 4, -42),
    c.capShade,
    1.2,
  );
  fillCircle(canvas, Offset(x + 5, -83), 2.6, c.capShade);
  final peak = Path()
    ..moveTo(x - 46, -40)
    ..cubicTo(x - 30, -32, x + 30, -32, x + 48, -42)
    ..cubicTo(x + 40, -26, x - 38, -24, x - 46, -40)
    ..close();
  fillPath(canvas, peak, c.capShade);
  strokePath(
    canvas,
    Path()
      ..moveTo(x - 40, -37)
      ..cubicTo(x - 20, -31, x + 20, -31, x + 42, -38),
    c.cap.withValues(alpha: 0.8),
    1,
  );
}
