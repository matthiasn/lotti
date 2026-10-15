import 'dart:math' as math;
import 'dart:ui';

/// A limb as one soft surface, not capsules hinged at the joints.
///
/// A smooth centre line runs through the joints (a cardinal spline), and the
/// outline is that line pushed out to each side by a width that blends from
/// joint to joint. It is rebuilt from the joints every frame, so it can never
/// come loose from them, and the shoulder and the elbow bend through the
/// silhouette instead of showing a seam.
///
/// A position along the ribbon is a joint index plus a fraction, so `1.8` is
/// 80 % of the way from joint 1 to joint 2. A sleeve is the same ribbon cut
/// short at the cuff.

/// Samples per segment.
const ribbonSteps = 10;

/// One sample along a ribbon: the centre point, the unit tangent, and the
/// two edges.
typedef RibbonSample = ({
  Offset centre,
  Offset tangent,
  Offset front,
  Offset back,
});

List<Offset> _tangents(List<Offset> pts, List<double> tension) {
  final n = pts.length;
  return [
    for (var i = 0; i < n; i++)
      (pts[math.min(n - 1, i + 1)] - pts[math.max(0, i - 1)]) *
          (tension[i] * (i == 0 || i == n - 1 ? 2.0 : 1.0)),
  ];
}

/// The point at position [s] along [pts] and the unit tangent there.
({Offset point, Offset tangent}) ribbonCentre(
  List<Offset> pts,
  double s,
  List<double> tension,
) {
  final m = _tangents(pts, tension);
  final i = math.min(s.floor(), pts.length - 2);
  final u = s - i;
  final p0 = pts[i];
  final p1 = pts[i + 1];
  final m0 = m[i];
  final m1 = m[i + 1];
  final u2 = u * u;
  final u3 = u2 * u;
  final point =
      p0 * (2 * u3 - 3 * u2 + 1) +
      m0 * (u3 - 2 * u2 + u) +
      p1 * (-2 * u3 + 3 * u2) +
      m1 * (u3 - u2);
  var tg =
      p0 * (6 * u2 - 6 * u) +
      m0 * (3 * u2 - 4 * u + 1) +
      p1 * (-6 * u2 + 6 * u) +
      m1 * (3 * u2 - 2 * u);
  if (tg.distance < 1e-9) {
    tg = p1 - p0;
    if (tg.distance < 1e-9) tg = const Offset(1, 0);
  }
  return (point: point, tangent: tg / tg.distance);
}

double _width(List<double> widths, double s) {
  final i = math.min(s.floor(), widths.length - 2);
  final u = s - i;
  return widths[i] + (widths[i + 1] - widths[i]) * u;
}

/// Samples from [start] to [end]. [widths] are half widths per joint on the
/// side the normal points to, [back] the other side's (the same unless
/// given). A negative half width puts that edge across the centre line,
/// which is how a band on one side of the limb is drawn.
List<RibbonSample> ribbonEdges(
  List<Offset> pts,
  List<double> widths,
  double start,
  double end, {
  List<double>? tension,
  List<double>? back,
}) {
  final t = tension ?? List.filled(pts.length, 0.5);
  final b = back ?? widths;
  final n = math.max(2, ((end - start) * ribbonSteps).ceil() + 1);
  return [
    for (var k = 0; k < n; k++)
      () {
        final s = start + (end - start) * k / (n - 1);
        final c = ribbonCentre(pts, s, t);
        final normal = Offset(-c.tangent.dy, c.tangent.dx);
        return (
          centre: c.point,
          tangent: c.tangent,
          front: c.point + normal * _width(widths, s),
          back: c.point - normal * _width(b, s),
        );
      }(),
  ];
}

void _halfTurn(Path path, Offset from, Offset to) {
  final mid = (from + to) / 2;
  final r = (from - to).distance / 2;
  if (r < 1e-6) {
    path.lineTo(to.dx, to.dy);
    return;
  }
  final a0 = math.atan2(from.dy - mid.dy, from.dx - mid.dx);
  path.arcTo(Rect.fromCircle(center: mid, radius: r), a0, -math.pi, false);
}

/// The ribbon's outline as one closed path: down the front edge, round (or
/// flat across) the end, back up the back edge.
Path ribbonPath(
  List<Offset> pts,
  List<double> widths,
  double start,
  double end, {
  List<double>? tension,
  List<double>? back,
  bool capStart = true,
  bool capEnd = true,
}) {
  final smp = ribbonEdges(
    pts,
    widths,
    start,
    end,
    tension: tension,
    back: back,
  );
  final path = Path()..moveTo(smp.first.front.dx, smp.first.front.dy);
  for (final s in smp.skip(1)) {
    path.lineTo(s.front.dx, s.front.dy);
  }
  final last = smp.last;
  if (capEnd) _halfTurn(path, last.front, last.back);
  path.lineTo(last.back.dx, last.back.dy);
  for (final s in smp.reversed.skip(1)) {
    path.lineTo(s.back.dx, s.back.dy);
  }
  final first = smp.first;
  if (capStart) _halfTurn(path, first.back, first.front);
  return path..close();
}
