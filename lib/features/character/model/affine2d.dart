import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// An immutable 2D affine transform.
///
/// Maps a point `(x, y)` to:
/// ```text
/// x' = a * x + c * y + tx
/// y' = b * x + d * y + ty
/// ```
///
/// This is the core math primitive for the skeletal engine: bone world
/// transforms are computed by composing parent and local transforms
/// ([multiply]). It is pure Dart (no Flutter) so the engine stays trivially
/// testable; the runtime layer converts it to a 4x4 storage buffer via
/// [toMatrix4Storage] for `Canvas.transform`.
@immutable
class Affine2D {
  const Affine2D(this.a, this.b, this.c, this.d, this.tx, this.ty);

  /// Pure translation by [tx], [ty].
  factory Affine2D.translation(double tx, double ty) =>
      Affine2D(1, 0, 0, 1, tx, ty);

  /// Pure rotation by `radians` (a positive angle is a clockwise visual
  /// rotation, matching the Flutter canvas convention).
  factory Affine2D.rotation(double radians) {
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return Affine2D(cos, sin, -sin, cos, 0, 0);
  }

  /// Pure (possibly non-uniform) scale.
  factory Affine2D.scale(double sx, double sy) => Affine2D(sx, 0, 0, sy, 0, 0);

  /// Translate-rotate-scale about a pivot, applied in TRS order:
  /// `Translate(pivot) ∘ Rotate(rotation) ∘ Scale(scale)`.
  ///
  /// This is how a bone's local transform is authored: the bone rotates and
  /// scales about its `pivotX`/`pivotY` joint, expressed in the parent's space.
  factory Affine2D.trs({
    required double pivotX,
    required double pivotY,
    required double rotation,
    double scaleX = 1,
    double scaleY = 1,
  }) {
    final cos = math.cos(rotation);
    final sin = math.sin(rotation);
    final a = cos * scaleX;
    final b = sin * scaleX;
    final c = -sin * scaleY;
    final d = cos * scaleY;
    return Affine2D(a, b, c, d, pivotX, pivotY);
  }

  /// The identity transform.
  static const Affine2D identity = Affine2D(1, 0, 0, 1, 0, 0);

  final double a;
  final double b;
  final double c;
  final double d;
  final double tx;
  final double ty;

  /// Returns `this ∘ o`, i.e. the transform that applies [o] first and then
  /// `this`. For forward kinematics: `worldChild = worldParent * local`.
  Affine2D multiply(Affine2D o) => Affine2D(
    a * o.a + c * o.b,
    b * o.a + d * o.b,
    a * o.c + c * o.d,
    b * o.c + d * o.d,
    a * o.tx + c * o.ty + tx,
    b * o.tx + d * o.ty + ty,
  );

  /// Maps the point [x], [y] through this transform, returning `(x', y')`.
  ({double x, double y}) transformPoint(double x, double y) =>
      (x: a * x + c * y + tx, y: b * x + d * y + ty);

  /// The translation component (where the local origin lands).
  ({double x, double y}) get origin => (x: tx, y: ty);

  /// Fills a column-major 4x4 [Float64List] (length 16) suitable for
  /// `Canvas.transform`. Reuses [storage] when provided to keep the per-frame
  /// hot path allocation-free.
  Float64List toMatrix4Storage([Float64List? storage]) {
    final m = storage ?? Float64List(16);
    m[0] = a;
    m[1] = b;
    m[2] = 0;
    m[3] = 0;
    m[4] = c;
    m[5] = d;
    m[6] = 0;
    m[7] = 0;
    m[8] = 0;
    m[9] = 0;
    m[10] = 1;
    m[11] = 0;
    m[12] = tx;
    m[13] = ty;
    m[14] = 0;
    m[15] = 1;
    return m;
  }

  @override
  bool operator ==(Object other) =>
      other is Affine2D &&
      other.a == a &&
      other.b == b &&
      other.c == c &&
      other.d == d &&
      other.tx == tx &&
      other.ty == ty;

  @override
  int get hashCode => Object.hash(a, b, c, d, tx, ty);

  @override
  String toString() => 'Affine2D(a:$a, b:$b, c:$c, d:$d, tx:$tx, ty:$ty)';
}
