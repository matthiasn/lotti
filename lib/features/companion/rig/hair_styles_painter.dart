import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';
import 'package:lotti/features/companion/rig/hair_painter.dart';
import 'package:lotti/features/companion/rig/paint_kit.dart';

/// Her hair in every style: the bun of the pitch videos (`hair_painter.dart`)
/// and the styles a person may give her instead, in head-local units (origin at the face's centre,
/// y down; the face spans x ±45 and y -58..40).
///
/// Each style has a back layer, drawn behind the head and the body, and a
/// front layer over the forehead, whose outline also casts the forehead's
/// shadow. Like the bun's wisps, the parts that hang — the locs, the bob's
/// ends, the afro's mass — trail the head's motion by the hair lag.

/// How far a point at [y] trails the head: nothing at the crown, the full
/// lag at the ends.
double _hang(double y) =>
    math.pow(((y + 70) / 150).clamp(0.0, 1.0), 1.4).toDouble();

Offset _trail(Offset p, Offset lag) => p + lag * _hang(p.dy);

/// Points on an ellipse round [centre], from angle [a0] to [a1] (radians, y
/// down, 0 pointing right), [n] steps.
List<Offset> _arc(
  Offset centre,
  double rx,
  double ry,
  double a0,
  double a1,
  int n,
) => [
  for (var i = 0; i <= n; i++)
    centre +
        Offset(
          rx * math.cos(a0 + (a1 - a0) * i / n),
          ry * math.sin(a0 + (a1 - a0) * i / n),
        ),
];

/// The hair over the top of the head, from the left temple round the crown
/// to the right one.
List<Offset> _crown(double r, double y) =>
    _arc(Offset(0, y), r, r, math.pi, 2 * math.pi, 16);

void _sheen(Canvas canvas, Path hair, CompanionPalette c) {
  canvas
    ..save()
    ..clipPath(hair)
    ..drawPaint(
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(-60, -110),
          const Offset(60, 0),
          [
            c.hairLight.withValues(alpha: 0.5),
            const Color(0x00FFFFFF),
            c.hairShade.withValues(alpha: 0.45),
          ],
          [0, 0.5, 1],
        ),
    )
    ..restore();
}

/// A repeatable value in -1..1 for the cell ([a], [b]): the jitter that
/// keeps coils and locs from lining up, the same on every frame.
double _noise(int a, int b) {
  var h = (a * 374761393 + b * 668265263) & 0x7FFFFFFF;
  h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF;
  h ^= h >> 16;
  return (h & 0xFFFF) / 0xFFFF * 2 - 1;
}

/// [base] lit as the sheen lights the hair at [at]: brighter towards the
/// top left, deeper towards the bottom right, so a coil standing proud of
/// the outline is shaded like the hair it grows from.
Color _lit(Offset at, Color base, CompanionPalette c) {
  const from = Offset(-60, -110);
  const axis = Offset(120, 110);
  final d = at - from;
  final t = ((d.dx * axis.dx + d.dy * axis.dy) / axis.distanceSquared).clamp(
    0.0,
    1.0,
  );
  return t < 0.5
      ? Color.lerp(c.hairLight, base, 0.5 + t)!
      : Color.lerp(base, c.hairShade, (t - 0.5) * 0.9)!;
}

/// The paints every coil of one layer is drawn with, made once per layer
/// rather than per coil: a layer paints hundreds of coils every frame.
class _CoilPaints {
  _CoilPaints(CompanionPalette c)
    : shade = Paint()..color = c.hairShade.withValues(alpha: 0.5),
      light = Paint()
        ..color = c.hairLight.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

  final Paint shade;
  final Paint fill = Paint();
  final Paint light;
}

/// One coil: a puff of [base] with a crescent of shade under it and a lit
/// rim over it.
void _coil(Canvas canvas, _CoilPaints paints, Offset at, double r, Color base) {
  canvas
    ..drawCircle(at + Offset(r * 0.2, r * 0.32), r, paints.shade)
    ..drawCircle(at, r * 0.92, paints.fill..color = base)
    ..drawArc(
      Rect.fromCircle(center: at, radius: r * 0.58),
      3.5,
      1.8,
      false,
      paints.light..strokeWidth = r * 0.2,
    );
}

/// One coil of a layout: where it sits at rest, and its size.
typedef _Coil = ({Offset at, double r});

/// The coils over [region] and along [rim], at rest: a staggered, jittered
/// grid of puffs inside the region, [step] apart and [r] in radius (none
/// without a region), and one on each rim point, the rim's
/// standing proud of the outline so the silhouette is scalloped rather than
/// smooth. Sorted bottom-up, so painting them in order overlaps each coil
/// with the one above it, which casts its shade on it, like shingles.
///
/// Laid out once per style: in motion a layer only moves, so [_paintCoils]
/// shifts the layout instead of laying it out again each frame — which also
/// keeps a coil near an edge from blinking in and out as she moves.
List<_Coil> _layCoils({
  required List<Offset> rim,
  required double rimR,
  Path? region,
  double step = 0,
  double r = 0,
}) {
  final coils = <_Coil>[
    for (final (i, p) in rim.indexed)
      (at: p, r: rimR * (1 + 0.18 * _noise(i, 91))),
  ];
  if (region == null) return coils..sort(_bottomUp);
  final bounds = region.getBounds();
  var row = 0;
  for (var y = bounds.top + step / 2; y < bounds.bottom; y += step * 0.78) {
    final shift = row.isEven ? 0.0 : step / 2;
    var col = 0;
    for (var x = bounds.left + shift; x < bounds.right; x += step) {
      final at = Offset(
        x + _noise(row, col) * step * 0.3,
        y + _noise(col + 17, row) * step * 0.22,
      );
      if (region.contains(at)) {
        coils.add((at: at, r: r * (1 + 0.2 * _noise(row + 5, col + 29))));
      }
      col++;
    }
    row++;
  }
  return coils..sort(_bottomUp);
}

int _bottomUp(_Coil a, _Coil b) => b.at.dy.compareTo(a.at.dy);

/// Paints [coils] moved by [shift]. With [lit], each coil takes the sheen's
/// light at its place; without, they keep [base], as the hair behind the
/// head does.
void _paintCoils(
  Canvas canvas,
  CompanionPalette c,
  List<_Coil> coils,
  Offset shift,
  Color base, {
  bool lit = true,
}) {
  final paints = _CoilPaints(c);
  for (final coil in coils) {
    final at = coil.at + shift;
    _coil(canvas, paints, at, coil.r, lit ? _lit(at, base, c) : base);
  }
}

// ---- Curls: short and tight, close to the head. ----

/// The curls' mass behind the head: round over the crown, down past the
/// temples to the tops of the ears, and rounded under, never square.
List<Offset> _curlsCap() => [
  ..._crown(56, -34),
  const Offset(63, -18),
  const Offset(60, -2),
  const Offset(50, 8),
  const Offset(-50, 8),
  const Offset(-60, -2),
  const Offset(-63, -18),
];

List<Offset> _curlsFront(double yaw) => [
  for (final p in [
    ..._crown(57, -33),
    const Offset(58, -18),
    const Offset(50, -30),
    const Offset(36, -41),
    const Offset(18, -46),
    const Offset(0, -47),
    const Offset(-18, -46),
    const Offset(-36, -41),
    const Offset(-50, -30),
    const Offset(-58, -18),
  ])
    p + Offset(yaw * 4, 0),
];

final List<_Coil> _curlsBackCoils = _layCoils(
  region: smoothClosed(_curlsCap(), 0.22),
  step: 10,
  r: 5,
  rim: _curlsCap(),
  rimR: 5.5,
);

/// The crown's edge and the hairline both end in coils.
final List<_Coil> _curlsFrontCoils = _layCoils(
  region: smoothClosed(_curlsFront(0), 0.24),
  step: 8.5,
  r: 4.4,
  rim: _curlsFront(0),
  rimR: 5,
);

void _drawCurlsBack(Canvas canvas, CompanionPalette c, Offset lag) {
  final shift = lag * 0.15;
  final cap = [for (final p in _curlsCap()) p + shift];
  fillPath(canvas, smoothClosed(cap, 0.22), c.hairBack);
  _paintCoils(canvas, c, _curlsBackCoils, shift, c.hairBack, lit: false);
}

void _drawCurlsFront(Canvas canvas, CompanionPalette c, double yaw) {
  final hair = smoothClosed(_curlsFront(yaw), 0.24);
  fillPath(canvas, hair, c.hair);
  _sheen(canvas, hair, c);
  _paintCoils(canvas, c, _curlsFrontCoils, Offset(yaw * 4, 0), c.hair);
}

// ---- Afro: full and round. ----

// Wider than tall, and no taller than the bust framing has room for above
// her head: its coils top out near y -99, the bun's at -90.
const _afroCentre = Offset(0, -38);
const _afroRx = 74.0;
const _afroRy = 52.0;
const _afroBump = 8.0;

/// How low the afro's front mass comes down her sides: to the tops of her
/// ears, so only the underside behind them is the hair behind the head.
const _afroSideY = -6.0;

/// Where the afro's outline reaches [_afroSideY], as an angle below its
/// equator.
final double _afroSide = math.asin((_afroSideY - _afroCentre.dy) / _afroRy);

/// The afro's outer edge, a point every few degrees, each pushed in or out a
/// little so the silhouette is a cloud of coils, not an ellipse.
List<Offset> _afroEdge(double a0, double a1, int n, Offset lag) => [
  for (final (i, p) in _arc(_afroCentre, _afroRx, _afroRy, a0, a1, n).indexed)
    p + (p - _afroCentre) / _afroRx * (2.5 * _noise(i, 53)) + lag * 0.25,
];

/// The afro's outer edge over the front of her head, from beside her left
/// ear over the crown to beside her right one.
List<Offset> _afroFrontEdge(Offset lag) =>
    _afroEdge(math.pi - _afroSide, 2 * math.pi + _afroSide, 30, lag);

/// The afro's hairline over her forehead, from the right temple to the
/// left: the part of its front that turns with her head.
const _afroHairline = [
  Offset(50, -22),
  Offset(46, -34),
  Offset(34, -44),
  Offset(16, -49),
  Offset(0, -50),
  Offset(-16, -49),
  Offset(-34, -44),
  Offset(-46, -34),
  Offset(-50, -22),
];

List<Offset> _afroFront(Offset lag, double yaw) => [
  ..._afroFrontEdge(lag),
  // Down the right side beside her temple, then the hairline across.
  for (final p in const [
    Offset(48, _afroSideY),
    ..._afroHairline,
    Offset(-48, _afroSideY),
  ])
    p + Offset(yaw * 4, 0),
];

/// The afro's whole edge, behind the head.
List<Offset> _afroBackEdge(Offset lag) => _afroEdge(0, 2 * math.pi, 36, lag);

final List<_Coil> _afroBackCoils = _layCoils(
  region: smoothClosed(_afroBackEdge(Offset.zero), 0.2),
  step: 13,
  r: 6.5,
  rim: _afroBackEdge(Offset.zero),
  rimR: _afroBump,
);

/// The afro's mass over the front of her head, its outer edge in big coils.
/// It moves with the hair lag; the hairline's own small coils
/// ([_afroHairlineCoils]) turn with her head and cover where the two meet.
final List<_Coil> _afroFrontCoils = _layCoils(
  region: smoothClosed(_afroFront(Offset.zero, 0), 0.2),
  step: 11,
  r: 5.8,
  rim: _afroFrontEdge(Offset.zero),
  rimR: _afroBump,
);

final List<_Coil> _afroHairlineCoils = _layCoils(
  rim: _afroHairline,
  rimR: 4.6,
);

void _drawAfroBack(Canvas canvas, CompanionPalette c, Offset lag) {
  final shift = lag * 0.25;
  fillPath(canvas, smoothClosed(_afroBackEdge(lag), 0.2), c.hairBack);
  _paintCoils(canvas, c, _afroBackCoils, shift, c.hairBack, lit: false);
}

void _drawAfroFront(Canvas canvas, CompanionPalette c, Offset lag, double yaw) {
  final hair = smoothClosed(_afroFront(lag, yaw), 0.2);
  fillPath(canvas, hair, c.hair);
  _sheen(canvas, hair, c);
  _paintCoils(canvas, c, _afroFrontCoils, lag * 0.25, c.hair);
  _paintCoils(canvas, c, _afroHairlineCoils, Offset(yaw * 4, 0), c.hair);
}

// ---- Locs: to below the shoulders, the ends swinging. ----

/// Where each loc behind the head starts, and how far down it hangs.
const _backLocs = [
  (-52.0, -30.0, 88.0),
  (-44.0, -18.0, 98.0),
  (-34.0, -10.0, 94.0),
  (-23.0, -4.0, 102.0),
  (-12.0, -1.0, 97.0),
  (0.0, 0.0, 104.0),
  (12.0, -1.0, 99.0),
  (23.0, -4.0, 95.0),
  (34.0, -10.0, 101.0),
  (44.0, -18.0, 96.0),
  (52.0, -30.0, 86.0),
];

/// One loc from [from] to [to], [width] wide at the root: a rope with a
/// shaded side and a lit one, twisted all the way down.
void _loc(
  Canvas canvas,
  CompanionPalette c,
  Offset from,
  Offset to,
  double width,
  Color fill,
) {
  final d = to - from;
  final n = Offset(-d.dy, d.dx) / d.distance;
  fillPath(canvas, tapered(from, to, width, width * 0.72), fill);
  // The shaded side and the lit one run the loc's length.
  strokePath(
    canvas,
    Path()
      ..moveToPoint(from + n * width * 0.28)
      ..lineToPoint(to + n * width * 0.2),
    c.hairShade.withValues(alpha: 0.6),
    width * 0.22,
  );
  strokePath(
    canvas,
    Path()
      ..moveToPoint(from - n * width * 0.22)
      ..lineToPoint(to - n * width * 0.16),
    c.hairLight.withValues(alpha: 0.45),
    width * 0.14,
  );
  // The twists: slanted grooves down the rope, a little uneven.
  var i = 0;
  for (var t = 0.1; t < 0.94; t += 0.12 + 0.02 * _noise(i, 7)) {
    final at = from + d * t;
    final half = width * (1 - 0.28 * t) * 0.45;
    strokePath(
      canvas,
      Path()
        ..moveToPoint(at - n * half - d / d.distance * 2)
        ..quadraticBezierTo(
          at.dx + d.dx / d.distance * 1.5,
          at.dy + d.dy / d.distance * 1.5,
          at.dx + n.dx * half + d.dx / d.distance * 2.5,
          at.dy + n.dy * half + d.dy / d.distance * 2.5,
        ),
      c.hairShade.withValues(alpha: 0.55),
      0.9,
    );
    i++;
  }
}

void _drawLocsBack(Canvas canvas, CompanionPalette c, Offset lag) {
  fillPath(canvas, smoothClosed(_locsCap(), 0.22), c.hairBack);
  // The outer locs first, so the ones nearer the middle lie over them.
  final order = [..._backLocs]
    ..sort((a, b) => b.$1.abs().compareTo(a.$1.abs()));
  for (final (x, y, end) in order) {
    final from = Offset(x, y);
    final to = _trail(Offset(x * 1.3, end), lag * 1.6);
    _loc(canvas, c, from, to, 11, c.hairBack);
  }
}

List<Offset> _locsCap() => [
  ..._crown(58, -34),
  const Offset(59, -8),
  const Offset(55, 14),
  const Offset(44, 22),
  const Offset(-44, 22),
  const Offset(-55, 14),
  const Offset(-59, -8),
];

/// The locs' hairline over the forehead, from the right temple to the left.
const _locsHairline = [
  Offset(54, -22),
  Offset(46, -36),
  Offset(34, -46),
  Offset(18, -51),
  Offset(4, -52),
  Offset(-10, -50),
  Offset(-24, -47),
  Offset(-40, -39),
  Offset(-54, -24),
];

List<Offset> _locsFront(double yaw) => [
  for (final p in [..._crown(60, -34), ..._locsHairline])
    p + Offset(yaw * 4, 0),
];

void _drawLocsFront(
  Canvas canvas,
  CompanionPalette c,
  Offset lag,
  double yaw,
) {
  final outline = _locsFront(yaw);
  final hair = smoothClosed(outline, 0.24);
  fillPath(canvas, hair, c.hair);
  _sheen(canvas, hair, c);
  // Locs swept back from the hairline over the crown, each to its own place
  // on the back of the head — side by side, never meeting in a point.
  canvas
    ..save()
    ..clipPath(hair);
  final shift = Offset(yaw * 4, 0);
  for (var k = -6; k <= 6; k++) {
    final root = Offset(k * 8.5, -50 + k * k * 0.75) + shift;
    final crown = Offset(k * 6.5 - 4, -104 + k * k * 0.5) + shift;
    final bend = Offset((root.dx + crown.dx) / 2 + k * 2.2, root.dy - 26);
    final rope = Path()
      ..moveToPoint(root)
      ..quadraticBezierTo(bend.dx, bend.dy, crown.dx, crown.dy);
    strokePath(canvas, rope, c.hairShade.withValues(alpha: 0.55), 2.2);
    strokePath(
      canvas,
      rope.shift(const Offset(-2.6, 0.6)),
      c.hairLight.withValues(alpha: 0.4),
      1.6,
    );
  }
  canvas.restore();
  // Two locs each side, hanging in front of the shoulders.
  for (final s in [-1, 1]) {
    for (var k = 0; k < 2; k++) {
      final from = Offset(s * (50 + k * 6) + yaw * 3, -26 + k * 8);
      final to = _trail(
        Offset(s * (56 + k * 8) + yaw * 2, 74 + k * 10),
        lag * 1.5,
      );
      _loc(canvas, c, from, to, 9, c.hair);
    }
  }
}

// ---- Bob: to the chin, with a straight fringe. ----

List<Offset> _bobBack(Offset lag) => [
  ..._crown(59, -34),
  const Offset(61, -8),
  const Offset(62, 14),
  _trail(const Offset(60, 32), lag),
  _trail(const Offset(50, 40), lag),
  const Offset(38, 36),
  const Offset(-38, 36),
  _trail(const Offset(-50, 40), lag),
  _trail(const Offset(-60, 32), lag),
  const Offset(-62, 14),
  const Offset(-61, -8),
];

List<Offset> _bobFront(Offset lag, double yaw) => [
  for (final p in [
    ..._crown(60, -34),
    const Offset(61, -10),
    const Offset(61, 12),
    _trail(const Offset(58, 30), lag),
    _trail(const Offset(48, 38), lag),
    const Offset(46, 22),
    const Offset(46, 0),
    const Offset(45, -24),
    const Offset(38, -36),
    const Offset(20, -39),
    const Offset(0, -40),
    const Offset(-20, -39),
    const Offset(-38, -36),
    const Offset(-45, -24),
    const Offset(-46, 0),
    const Offset(-46, 22),
    _trail(const Offset(-48, 38), lag),
    _trail(const Offset(-58, 30), lag),
    const Offset(-61, 12),
    const Offset(-61, -10),
  ])
    p + Offset(yaw * 4, 0),
];

void _drawBobFront(Canvas canvas, CompanionPalette c, Offset lag, double yaw) {
  final hair = smoothClosed(_bobFront(lag, yaw), 0.18);
  fillPath(canvas, hair, c.hair);
  _sheen(canvas, hair, c);
  // The fringe's strands, and a shine across the crown.
  canvas
    ..save()
    ..clipPath(hair);
  for (var x = -36.0; x <= 36; x += 8) {
    strokePath(
      canvas,
      Path()
        ..moveTo(x + yaw * 4, -62)
        ..lineTo(x + yaw * 4 + 1, -42),
      c.hairShade.withValues(alpha: 0.55),
      1.1,
    );
  }
  strokePath(
    canvas,
    arc(Offset(yaw * 4, -34), 48, 3.7, 5),
    c.hairLight.withValues(alpha: 0.8),
    3,
  );
  canvas.restore();
}

// ---- Every style. ----

/// The hair behind the head, in [style].
void drawBackHair(
  Canvas canvas,
  CompanionPalette c,
  Offset lag,
  CompanionHairStyle style,
) => switch (style) {
  CompanionHairStyle.bun => drawBunBack(canvas, c, lag),
  CompanionHairStyle.curls => _drawCurlsBack(canvas, c, lag),
  CompanionHairStyle.afro => _drawAfroBack(canvas, c, lag),
  CompanionHairStyle.locs => _drawLocsBack(canvas, c, lag),
  CompanionHairStyle.bob => fillPath(
    canvas,
    smoothClosed(_bobBack(lag), 0.2),
    c.hairBack,
  ),
};

/// The hair over the forehead, in [style].
void drawFrontHair(
  Canvas canvas,
  CompanionPalette c,
  Offset lag,
  double yaw,
  CompanionHairStyle style,
) => switch (style) {
  CompanionHairStyle.bun => drawBunFront(canvas, c, lag, yaw),
  CompanionHairStyle.curls => _drawCurlsFront(canvas, c, yaw),
  CompanionHairStyle.afro => _drawAfroFront(canvas, c, lag, yaw),
  CompanionHairStyle.locs => _drawLocsFront(canvas, c, lag, yaw),
  CompanionHairStyle.bob => _drawBobFront(canvas, c, lag, yaw),
};

/// The outline of the front hair in [style]: what shades the forehead below
/// it.
List<Offset> fringeFor(CompanionHairStyle style, Offset lag, double yaw) =>
    switch (style) {
      CompanionHairStyle.bun => bunFringe(lag, yaw),
      CompanionHairStyle.curls => _curlsFront(yaw),
      CompanionHairStyle.afro => _afroFront(lag, yaw),
      CompanionHairStyle.locs => _locsFront(yaw),
      CompanionHairStyle.bob => _bobFront(lag, yaw),
    };

/// The front hair's shadow on the forehead, in [style].
void drawForeheadShadow(
  Canvas canvas,
  CompanionPalette c,
  Offset lag,
  double yaw,
  CompanionHairStyle style,
) => fillPath(
  canvas,
  smoothClosed([
    for (final p in fringeFor(style, lag, yaw)) p + const Offset(0, 3.5),
  ], 0.24),
  c.skinDeep.withValues(alpha: 0.3),
);
