import 'dart:math' as math;
import 'dart:ui';

import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/rig/paint_kit.dart';

/// The two close-cropped styles, in head-local units (origin at the face's
/// centre, y down; the face spans x ±45 and y -58..40): short, a neat cut
/// parted on the left, and balding, a bare crown with a fringe of hair round
/// the back and over the ears. Neither has anything long enough to trail the
/// head's motion, so neither takes the hair lag.

/// Points round the skull from the left temple over the crown to the right
/// one, [r] out from (0, [y]).
List<Offset> _skull(double r, double y, double yaw) => [
  for (var i = 0; i <= 14; i++)
    Offset(
      r * math.cos(math.pi + math.pi * i / 14) + yaw * 4,
      y + r * math.sin(math.pi + math.pi * i / 14),
    ),
];

// ---- Short. ----

/// The short cut behind the head: close over the crown, down to the tops of
/// the ears and the nape.
List<Offset> _shortBack() => [
  ..._skull(52, -16, 0),
  const Offset(48, -2),
  const Offset(38, 6),
  const Offset(-38, 6),
  const Offset(-48, -2),
];

/// The short cut's front: over the crown to a hairline that dips at the
/// parting on the left, with short sideburns in front of the ears.
List<Offset> shortFringe(double yaw) => [
  ..._skull(51, -16, yaw),
  Offset(50 + yaw * 2, 2),
  Offset(45 + yaw * 2, 2),
  Offset(44 + yaw * 3, -24),
  Offset(32 + yaw * 4, -44),
  Offset(10 + yaw * 4, -50),
  Offset(-12 + yaw * 4, -52),
  Offset(-16 + yaw * 4, -48),
  Offset(-30 + yaw * 4, -46),
  Offset(-44 + yaw * 3, -24),
  Offset(-45 + yaw * 2, 2),
  Offset(-50 + yaw * 2, 2),
];

void drawShortBack(Canvas canvas, CompanionPalette c) =>
    fillPath(canvas, smoothClosed(_shortBack(), 0.2), c.hairBack);

/// The short cut over the forehead, combed over from the parting.
void drawShortFront(Canvas canvas, CompanionPalette c, double yaw) {
  final hair = smoothClosed(shortFringe(yaw), 0.2);
  fillPath(canvas, hair, c.hair);
  canvas
    ..save()
    ..clipPath(hair);
  // The far side in shade, the near side of the crown lit.
  fillPath(
    canvas,
    ellipse(Offset(40 + yaw * 4, -30), 22, 34),
    c.hairShade.withValues(alpha: 0.45),
  );
  fillPath(
    canvas,
    ellipse(Offset(-20 + yaw * 4, -58), 22, 8),
    c.hairLight.withValues(alpha: 0.5),
  );
  // The comb's lines, swept from the parting over to the right.
  for (var k = 0; k < 5; k++) {
    final x = -12.0 + yaw * 4 + k * 10;
    strokePath(
      canvas,
      Path()
        ..moveTo(x, -50 + k * 0.6)
        ..cubicTo(x + 6, -60, x + 16, -62, x + 24, -56 + k * 2.5),
      c.hairShade.withValues(alpha: 0.5),
      1.2,
    );
  }
  canvas.restore();
  // The parting.
  strokePath(
    canvas,
    Path()
      ..moveTo(-14 + yaw * 4, -50)
      ..cubicTo(-15 + yaw * 4, -54, -17 + yaw * 4, -58, -20 + yaw * 4, -61),
    c.hairShade,
    1.4,
  );
}

// ---- Balding. ----

/// The fringe of hair behind the head, round the back from ear to ear; the
/// crown above it is bare.
List<Offset> _baldingBack() => [
  const Offset(-50, -26),
  const Offset(-57, -6),
  const Offset(-52, 12),
  const Offset(-38, 22),
  const Offset(0, 26),
  const Offset(38, 22),
  const Offset(52, 12),
  const Offset(57, -6),
  const Offset(50, -26),
  const Offset(40, -10),
  const Offset(-40, -10),
];

/// One tuft over the ear on side [side] (-1 left, +1 right).
List<Offset> _tuft(int side, double yaw) {
  final s = side.toDouble();
  final dx = yaw * 2;
  return [
    Offset(s * 41 + dx, -32),
    Offset(s * 49 + dx, -28),
    Offset(s * 51 + dx, -12),
    Offset(s * 48 + dx, 2),
    Offset(s * 44 + dx, 4),
    Offset(s * 44 + dx, -14),
  ];
}

void drawBaldingBack(Canvas canvas, CompanionPalette c) =>
    fillPath(canvas, smoothClosed(_baldingBack(), 0.2), c.hairBack);

/// The tufts over the ears, and the light on the bare crown.
void drawBaldingFront(Canvas canvas, CompanionPalette c, double yaw) {
  for (final side in [-1, 1]) {
    final tuft = smoothClosed(_tuft(side, yaw), 0.25);
    fillPath(canvas, tuft, c.hair);
    strokePath(canvas, tuft, c.hairShade.withValues(alpha: 0.5), 1);
  }
  fillPath(
    canvas,
    ellipse(Offset(-12 + yaw * 4, -48), 13, 5),
    c.skinLight.withValues(alpha: 0.7),
  );
}
