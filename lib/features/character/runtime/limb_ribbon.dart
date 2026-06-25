import 'dart:math' as math;
import 'dart:ui';

/// Builds a smooth, tapered **ribbon** that flows through a bone chain's joint
/// positions — the core of mesh-style limb deformation. Where the rigid renderer
/// draws a thigh and a shin as two separate capsules that hinge at a sharp knee
/// (the "cardboard cutout" tell), a ribbon is ONE continuous shape whose
/// centreline is a Catmull-Rom curve through `[hip, knee, ankle]` and whose
/// half-width tapers along it. It bends at the joints instead of folding.
///
/// All points are in the SAME space they will be drawn in (the renderer feeds it
/// canvas-space joint positions from the solved world transforms), so the ribbon
/// is drawn with no per-bone canvas transform.
///
/// [spine] are the joint centres (≥2). [halfWidths] is the half-thickness at each
/// joint (same length as [spine]). [samplesPerSegment] controls smoothness.
Path limbRibbonPath(
  List<Offset> spine,
  List<double> halfWidths, {
  int samplesPerSegment = 10,
}) {
  assert(spine.length == halfWidths.length, 'spine/halfWidths length mismatch');
  if (spine.length < 2) return Path();

  final samples = _sampleCentreline(spine, halfWidths, samplesPerSegment);

  // Left and right edges, offset along the centreline normal by the local
  // half-width. The ends get round caps (semicircles) so joints read as the
  // soft rounded limbs the capsules used to give, without the hinge.
  final path = Path();
  final first = samples.first;
  final last = samples.last;

  // Start cap: semicircle around the first centre, sweeping from the right edge
  // up over the start to the left edge (so the forward left-edge walk continues).
  final startAngle = math.atan2(-first.normal.dy, -first.normal.dx);
  path
    ..moveTo(
      first.centre.dx - first.normal.dx * first.halfWidth,
      first.centre.dy - first.normal.dy * first.halfWidth,
    )
    ..arcTo(
      Rect.fromCircle(center: first.centre, radius: first.halfWidth),
      startAngle,
      -math.pi, // bulge over the BACK of the limb (opposite the tangent)
      false,
    );

  // Forward along the LEFT edge.
  for (var i = 1; i < samples.length; i++) {
    final s = samples[i];
    path.lineTo(
      s.centre.dx + s.normal.dx * s.halfWidth,
      s.centre.dy + s.normal.dy * s.halfWidth,
    );
  }

  // End cap: semicircle around the last centre, from the left edge over the tip
  // to the right edge.
  final endAngle = math.atan2(last.normal.dy, last.normal.dx);
  path.arcTo(
    Rect.fromCircle(center: last.centre, radius: last.halfWidth),
    endAngle,
    -math.pi,
    false,
  );

  // Back along the RIGHT edge.
  for (var i = samples.length - 2; i >= 0; i--) {
    final s = samples[i];
    path.lineTo(
      s.centre.dx - s.normal.dx * s.halfWidth,
      s.centre.dy - s.normal.dy * s.halfWidth,
    );
  }

  path.close();
  return path;
}

class _Sample {
  _Sample(this.centre, this.normal, this.halfWidth);
  final Offset centre;
  final Offset normal; // unit, perpendicular to the tangent (points "left")
  final double halfWidth;
}

/// Resamples [spine] into a Catmull-Rom curve, carrying the per-sample tangent
/// normal and the interpolated half-width.
List<_Sample> _sampleCentreline(
  List<Offset> spine,
  List<double> halfWidths,
  int samplesPerSegment,
) {
  final out = <_Sample>[];
  final n = spine.length;
  for (var i = 0; i < n - 1; i++) {
    // Catmull-Rom control points (clamp at the ends).
    final p0 = spine[i == 0 ? 0 : i - 1];
    final p1 = spine[i];
    final p2 = spine[i + 1];
    final p3 = spine[i + 2 >= n ? n - 1 : i + 2];
    final w1 = halfWidths[i];
    final w2 = halfWidths[i + 1];
    final last = i == n - 2;
    final steps = last ? samplesPerSegment : samplesPerSegment - 1;
    for (var s = 0; s <= steps; s++) {
      final t = s / samplesPerSegment;
      final pt = _catmullRom(p0, p1, p2, p3, t);
      final tan = _catmullRomTangent(p0, p1, p2, p3, t);
      final len = tan.distance;
      final normal = len < 1e-6
          ? Offset.zero
          : Offset(-tan.dy / len, tan.dx / len);
      out.add(_Sample(pt, normal, w1 + (w2 - w1) * t));
    }
  }
  return out;
}

Offset _catmullRom(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
  final t2 = t * t;
  final t3 = t2 * t;
  double c(double a, double b, double cc, double d) =>
      0.5 *
      ((2 * b) +
          (-a + cc) * t +
          (2 * a - 5 * b + 4 * cc - d) * t2 +
          (-a + 3 * b - 3 * cc + d) * t3);
  return Offset(
    c(p0.dx, p1.dx, p2.dx, p3.dx),
    c(p0.dy, p1.dy, p2.dy, p3.dy),
  );
}

Offset _catmullRomTangent(
  Offset p0,
  Offset p1,
  Offset p2,
  Offset p3,
  double t,
) {
  final t2 = t * t;
  double c(double a, double b, double cc, double d) =>
      0.5 *
      ((-a + cc) +
          2 * (2 * a - 5 * b + 4 * cc - d) * t +
          3 * (-a + 3 * b - 3 * cc + d) * t2);
  return Offset(
    c(p0.dx, p1.dx, p2.dx, p3.dx),
    c(p0.dy, p1.dy, p2.dy, p3.dy),
  );
}
